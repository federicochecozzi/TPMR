library(odbc)

setwd("C:/Users/malen/Dropbox/MAESTRIA_CDD/MRCD/TPMR/Análisis de rentabilidad")

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")


### Márgenes de rentabilidad mensual



q_total_ganancia_mes <- "
                      WITH 
	ventas_reseller(anio_mes,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal) AS
                      (SELECT 
                            cast(left(OrderDateKey,6) as integer) as anio_mes
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
                      ),
                      
    ventas_online(anio_mes,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal) AS
                                            
                      (SELECT cast(left(OrderDateKey,6) as integer) AS anio_mes
                              ,salesamount
                              ,OrderQuantity
                              ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                      FROM FactInternetSales s
                      ),
                       
    Sales(anio_mes,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    MinMaxAnioMes(min_aniomes,max_aniomes) AS
                      (SELECT min(anio_mes) as min_aniomes, 
                              max(anio_mes) as max_aniomes
                      FROM sales),

    MesesFull(anio_mes) AS
       (
       SELECT min_aniomes as anio_mes
       from MinMaxAnioMes
            
       UNION ALL

       SELECT 
       CASE WHEN anio_mes % 100 = 12 THEN anio_mes + 100 - 11
       ELSE anio_mes + 1 END AS anio_mes
       FROM mesesfull
       WHERE anio_mes < (select max_aniomes from MinMaxAnioMes)
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.anio_mes AS CHAR),'Total') AS anio_mes
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal)/1000,0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM mesesfull m
    CROSS JOIN canalfull cf
    LEFT JOIN sales AS c 
    ON m.anio_mes = c.anio_mes and cf.canal = c.canal
    GROUP BY ROLLUP(m.anio_mes,cf.canal))
    
    SELECT a.*
          ,AVG(ingreso_ventas_canal) OVER (PARTITION BY canal ORDER BY anio_mes ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY canal ORDER BY anio_mes ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY canal ORDER BY anio_mes ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE anio_mes <> 'Total'
    "
                      


total_ganancia_mes <- dbGetQuery(conn = on,q_total_ganancia_mes)


# Grafico 

library(ggplot2)

graf_mes_ventas <- ggplot(data = total_ganancia_mes,aes(x = anio_mes)
                          
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        axis.title = element_text(size = 9),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) +
  ylab("Ingreso por ventas\n (millones de US$)") +
  xlab("periodo (año - mes)")

graf_mes_ventas  



### Graf ganancia
graf_mes_ganancia <- ggplot(data = total_ganancia_mes,aes(x = anio_mes)
                            
) +
  geom_line(aes(y = ganancia_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        axis.title = element_text(size = 9),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - mes)") +
  ylab("Ganancia\n(Miles de US$)")

graf_mes_ganancia  

graf_tiempo <- egg::ggarrange(graf_mes_ventas,graf_mes_ganancia,nrow = 2)




### Ventas y ganancias por region -----------


q_total_ganancia_region <- "

                      WITH 
	ventas_reseller(trim_anio,
	               salesterritorygroup,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                      
    ventas_online(trim_anio,
	                    salesterritorygroup,
	                    salesamount,OrderQuantity,totalProductCost,
                      canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                      FROM FactInternetSales s
                      LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                      LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                      WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                       
    Sales(trim_anio,salesterritorygroup,
	            salesamount,OrderQuantity,totalProductCost,
              canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    RegionFull(salesterritorygroup) AS
                      (SELECT DISTINCT salesterritorygroup
                      FROM Sales),

    AnioFull(trim_anio) AS
       (
       SELECT DISTINCT trim_anio
                      FROM Sales
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.trim_anio AS CHAR),'Total') AS trim_anio
            ,CASE WHEN r.salesterritorygroup = 'Europe' THEN 'Europa'
                  WHEN r.salesterritorygroup = 'North America' THEN 'América del Norte'
                  WHEN r.salesterritorygroup = 'Pacific' THEN 'Pacífico' 
                  ELSE 'Total' END AS region
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM AnioFull m
    CROSS JOIN canalfull cf
    CROSS JOIN regionfull r
    LEFT JOIN sales AS c 
    ON m.trim_anio = c.trim_anio and cf.canal = c.canal and r.SalesTerritoryGroup = c.SalesTerritoryGroup
    GROUP BY ROLLUP(m.trim_anio,r.SalesTerritoryGroup,cf.canal)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and region <> 'Total'
    ORDER BY trim_anio,region
    "



total_ganancia_region <- dbGetQuery(conn = on,q_total_ganancia_region)


# Grafico 

library(ggplot2)


graf_region_ventas <- ggplot(data = total_ganancia_region,aes(x = trim_anio)
                          
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 0.9) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 0.9) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        axis.title = element_text(size = 9),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  ylab("Ingreso por ventas\n(Millones de US$)") +
  xlab("periodo (año - trimestre)") +
  facet_wrap(~region,ncol = 3)

graf_region_ventas

### Graf ganancia
graf_region_ganancia <- ggplot(data = total_ganancia_region,aes(x = trim_anio)
                               
) +
  geom_line(aes(y = ganancia_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        axis.title = element_text(size = 9),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - trimestre)") +
  ylab("Ganancia\n(Miles de US$)") +
  facet_wrap(~region)

graf_region_ganancia

graf_tiempo_region <- egg::ggarrange(graf_region_ventas,
                                     graf_region_ganancia,
                                     nrow = 2)  

### Por categoria de producto 

q_total_ganancia_catproducto <- "

                      WITH 
	ventas_reseller(trim_anio,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                      
    ventas_online(trim_anio,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                       
    Sales AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    CatFull(cat_producto) AS
                      (SELECT DISTINCT cat_producto
                      FROM Sales),

    AnioFull(trim_anio) AS
       (
       SELECT DISTINCT trim_anio
                      FROM Sales
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.trim_anio AS CHAR),'Total') AS trim_anio
            ,ISNULL(cp.cat_producto,'Total') AS cat_producto
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM AnioFull m
    CROSS JOIN canalfull cf
    CROSS JOIN catfull cp
    LEFT JOIN sales AS s 
    ON m.trim_anio = s.trim_anio and 
       cf.canal = s.canal and 
       cp.cat_producto = s.cat_producto
    GROUP BY ROLLUP(m.trim_anio,cp.cat_producto,cf.canal)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and cat_producto <> 'Total'
    ORDER BY trim_anio,cat_producto
    "

total_ganancia_catproducto <- dbGetQuery(conn = on,q_total_ganancia_catproducto)


graf_producto_ventas <- ggplot(data = total_ganancia_catproducto,aes(x = trim_anio)
                                      
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 0.8) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 0.8) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - trimestre)") +
  ylab("Ingresos por ventas\n(Millones de US$)") +
  facet_wrap(~cat_producto, ncol = 2)

graf_producto_ventas 



### Por categoria de producto y region -----

q_total_ganancia_producto_region <- "

                      WITH 
	ventas_reseller(trim_anio,
	               salesterritorygroup,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                      
    ventas_online(trim_anio,
	               salesterritorygroup,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                       
    Sales(trim_anio,salesterritorygroup,
          cat_producto,
	            salesamount,OrderQuantity,totalProductCost,
              canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    CatFull(cat_producto) AS
                      (SELECT DISTINCT cat_producto
                      FROM Sales),
                      
    RegionFull(salesterritorygroup) AS
                      (SELECT DISTINCT salesterritorygroup
                      FROM Sales),

    AnioFull(trim_anio) AS
       (
       SELECT DISTINCT trim_anio
                      FROM Sales
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.trim_anio AS CHAR),'Total') AS trim_anio
            ,CASE WHEN r.salesterritorygroup = 'Europe' THEN 'Europa'
                  WHEN r.salesterritorygroup = 'North America' THEN 'América del Norte'
                  WHEN r.salesterritorygroup = 'Pacific' THEN 'Pacífico' 
                  ELSE 'Total' END AS region
            ,ISNULL(cp.cat_producto,'Total') AS cat_producto
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM AnioFull m
    CROSS JOIN canalfull cf
    CROSS JOIN regionfull r
    CROSS JOIN catfull cp
    LEFT JOIN sales AS s 
    ON m.trim_anio = s.trim_anio and 
       cf.canal = s.canal and 
       r.SalesTerritoryGroup = s.SalesTerritoryGroup and
       cp.cat_producto = s.cat_producto
    GROUP BY ROLLUP(m.trim_anio,r.SalesTerritoryGroup,cf.canal,cp.cat_producto)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY region,canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY region,canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY region,canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and cat_producto <> 'Total'
    ORDER BY trim_anio,region,cat_producto
    "


total_ganancia_producto_region <- dbGetQuery(conn = on,q_total_ganancia_producto_region)


# Grafico 


graf_producto_region_ventas <- ggplot(data = total_ganancia_producto_region,aes(x = trim_anio)
                                 
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 0.8) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 0.8) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - trimestre)") +
  ylab("Ingresos por ventas\n(Millones de US$)") +
  facet_grid(cat_producto ~ region)

graf_producto_region_ventas 


### Ventas y ganancias totales por categoría de producto, región y canal, últimos 6 meses

q_total_ventas_cat_producto_region <- "

                      WITH 
	ventas_reseller AS
                      (SELECT 
                            
                            CASE 
                              WHEN salesterritorygroup = 'Europe' THEN 'Europa'
                              WHEN salesterritorygroup = 'North America' THEN 'América del Norte'
                              ELSE 'Pacífico' END as salesterritorygroup 
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                      ),
                      
    ventas_online AS
                      (SELECT 
                             CASE 
                              WHEN salesterritorygroup = 'Europe' THEN 'Europa'
                              WHEN salesterritorygroup = 'North America' THEN 'América del Norte'
                              ELSE 'Pacífico' END as salesterritorygroup
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                      ),
                       
    Sales AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    CatFull(cat_producto) AS
                      (SELECT DISTINCT cat_producto
                      FROM Sales),
                      
    RegionFull(salesterritorygroup) AS
                      (SELECT DISTINCT salesterritorygroup
                      FROM Sales),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales)
                    

      SELECT  
            r.SalesTerritoryGroup AS region
            ,cp.cat_producto 
            ,cf.canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM canalfull cf
    CROSS JOIN regionfull r
    CROSS JOIN catfull cp
    LEFT JOIN sales AS s 
    ON
       cf.canal = s.canal and 
       r.SalesTerritoryGroup = s.SalesTerritoryGroup and
       cp.cat_producto = s.cat_producto
    GROUP BY r.SalesTerritoryGroup
            ,cp.cat_producto 
            ,cf.canal
    "


total_ventas_cat_producto_region <- dbGetQuery(conn = on,q_total_ventas_cat_producto_region)


# Grafico 

graf_cat_producto_region_ventas <- ggplot(data = total_ventas_cat_producto_region,
                                          aes(x = cat_producto,
                                              y = ingreso_ventas_canal,
                                              fill = canal)
                                      
) +
  geom_bar(position = 'dodge',
           stat = 'identity',
           show.legend = F) +
  theme(
    axis.text.x = element_blank()
    ,
    axis.title.x = element_blank(),
    axis.title.y = element_text(size = 9),
        #legend.position = 'bottom',
        #legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  ylab("Ingreso por ventas\n(Millones de US$)") +
  facet_wrap(~region)

graf_cat_producto_region_ventas


graf_cat_producto_region_ganancia <- ggplot(data = total_ventas_cat_producto_region,
                                          aes(x = cat_producto,
                                              y = ganancia_canal,
                                              fill = canal)
                                          
) +
  geom_bar(position = 'dodge',
           stat = 'identity') +
  theme(
    axis.text.x = element_text(angle = 90,
                               vjust = 0.5,
                               hjust = 1
    ),
    axis.title = element_text(size = 9),
    legend.position = 'bottom',
    legend.title = element_blank(),
    panel.background = element_blank(),
    panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                    colour = "gray"), 
    panel.grid.minor = element_blank()) + 
  xlab("Categoría de producto") +
  ylab("Ganancia neta\n(Miles de US$)") +
  facet_wrap(~region)

graf_cat_producto_region_ganancia


graf_cat_producto <- egg::ggarrange(graf_cat_producto_region_ventas,
                                    graf_cat_producto_region_ganancia, 
                                    nrow = 2)





### Margen de ganancias por subcategoría --------------


q_margen_ganancias_productos <- "

                      WITH
                      
    ventas_online AS
                      (SELECT 

                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,salesamount
                            ,totalProductCost
                            ,'online (minorista)' AS canal
                            ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                            ,CASE 
                              WHEN ISNULL(cast(salesAmount as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(salesamount as float) - CAST(totalProductCost as float) ,0)/ISNULL(cast(salesAmount as float),0),1) 
                              ELSE 0.0 END as margenGananciaPc
                  FROM FactInternetSales s
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                  
                      ),
                      
        ventas_reseller AS
                      (SELECT 
                            
                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,salesamount
                            ,totalProductCost
                            ,'mayorista (reseller)' AS canal
                            ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                            ,CASE 
                              WHEN ISNULL(cast(salesAmount as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(salesamount as float) - CAST(totalProductCost as float) ,0)/ISNULL(cast(salesAmount as float),0),1) 
                              ELSE 0.0 END as margenGananciaPc
                  FROM FactResellerSales s
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                      ),
    
    Sales AS
      (SELECT * 
      FROM ventas_online
      
      UNION ALL
      
      SELECT *
      FROM ventas_reseller)
      
      
      SELECT  
            canal
            ,cat_producto
            ,subcat_producto
            ,AVG(margengananciapc) as promedio_margen_gan

      FROM Sales 
      GROUP BY canal,cat_producto,subcat_producto 
      ORDER BY promedio_margen_gan
      
    
    

    "

margen_ganancias_por_productos <- dbGetQuery(conn = on,q_margen_ganancias_productos)


graf_producto_margen <- ggplot(data = margen_ganancias_por_productos,
                                            aes(x = reorder(subcat_producto,-promedio_margen_gan),
                                                y = promedio_margen_gan,
                                                fill = cat_producto)
                                            
) +
  geom_bar(position = 'dodge',
           stat = 'identity') +
  theme(
    axis.text.x = element_text(angle = 60,
                               vjust = 1,
                               hjust = 1
    ),
    axis.title = element_text(size = 9),
    legend.position = 'bottom',
    legend.title = element_blank(),
    panel.background = element_blank(),
    panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                    colour = "gray"), 
    panel.grid.minor = element_blank()) + 
  xlab("Subcategoría de producto") +
  ylab("Promedio margen de ganancia (%)") +
  facet_wrap(~canal, ncol = 1)

graf_producto_margen


### Subcategorías de productos: margen de ganancia y precio promedio por canal --------------


q_ganancias_por_productos <- "

                      WITH
                      
    ventas_online AS
                      (SELECT 
                            
                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,unitPrice as precio_online
                            ,CASE 
                              WHEN ISNULL(cast(unitPrice as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(unitPrice as float) - CAST(ProductStandardCost as float) ,0)/ISNULL(cast(unitPrice as float),0),1) 
                              ELSE 0.0 END as margen_online
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130700 and s.orderDateKey <= 20140000
                      ),
                      
        ventas_resellers AS
                      (SELECT 
                            
                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,unitPrice * (1 - unitPriceDiscountPct) as precio_reventa
                            ,CASE 
                              WHEN ISNULL(cast(unitPrice * (1 - unitPriceDiscountPct) as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(unitPrice * (1 - unitPriceDiscountPct) as float) - CAST(ProductStandardCost as float) ,0)/ISNULL(cast(unitPrice * (1 - unitPriceDiscountPct) as float),0),1) 
                              ELSE 0.0 END as margen_reventa
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130700 and s.orderDateKey <= 20140000
                      ),
    
    totalproductos as
    (SELECT DISTINCT cat_producto,subcat_producto 
         FROM (SELECT cat_producto,subcat_producto FROM ventas_resellers
                UNION ALL
              SELECT cat_producto,subcat_producto FROM ventas_online) p)
    
   SELECT c.cat_producto as [categoría]
        ,c.subcat_producto as [subcategoría]
        ,ISNULL(AVG(o.precio_online),0) as [precio online medio]
        ,ISNULL(AVG(r.precio_reventa),0) as [precio reventa medio]
        ,ISNULL(AVG(o.margen_online),0) as [margen online medio]
        ,ISNULL(AVG(r.margen_reventa),0) as [margen reventa medio]
    FROM totalproductos c
    LEFT JOIN ventas_online o
      on c.subcat_producto = o.subcat_producto
    LEFT JOIN ventas_resellers r
      on c.subcat_producto = R.subcat_producto
    GROUP BY c.cat_producto,c.subcat_producto
    ORDER BY c.cat_producto,c.subcat_producto
    "

### Esto se puede mostrar como tabla directamente.
ganancias_por_productos <- dbGetQuery(conn = on,q_ganancias_por_productos)

gt_margen_products <- gt::gt(ganancias_por_productos,
                         groupname_col = 'categoría')
library(odbc)

setwd("C:/Users/malen/Dropbox/MAESTRIA_CDD/MRCD/TPMR/Análisis de rentabilidad")

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")

query1 <- 'select top 5 s.productkey,s.salesterritorykey,s.salesamount, s.standardproductcost,s.totalproductcost, s.salesamount - s.totalproductcost as totalincome  
            from FactInternetSales s'
query2 <- "SELECT cast(left(OrderDateKey,6) as integer) AS anio_mes
                              ,salesamount
                              ,OrderQuantity
                              ,totalProductCost
                              ,'reseller (mayorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                      FROM FactInternetSales s"

query3 <- 'select top 5 * from DimDate'

prueba2 <- dbGetQuery(conn = on,query2)
prueba3 <- dbGetQuery(conn = on,query3)

### Márgenes de rentabilidad mensual



q_total_ganancia_mes <- "

                      WITH 
	ventas_reseller(anio_mes,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal) AS
                      (SELECT 
                            cast(left(OrderDateKey,6) as integer) as anio_mes
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
                      ),
                      
    ventas_online(anio_mes,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal) AS
                                            
                      (SELECT cast(left(OrderDateKey,6) as integer) AS anio_mes
                              ,salesamount
                              ,OrderQuantity
                              ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                      FROM FactInternetSales s
                      ),
                       
    Sales(anio_mes,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    MinMaxAnioMes(min_aniomes,max_aniomes) AS
                      (SELECT min(anio_mes) as min_aniomes, 
                              max(anio_mes) as max_aniomes
                      FROM sales),

    MesesFull(anio_mes) AS
       (
       SELECT min_aniomes as anio_mes
       from MinMaxAnioMes
            
       UNION ALL

       SELECT 
       CASE WHEN anio_mes % 100 = 12 THEN anio_mes + 100 - 11
       ELSE anio_mes + 1 END AS anio_mes
       FROM mesesfull
       WHERE anio_mes < (select max_aniomes from MinMaxAnioMes)
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.anio_mes AS CHAR),'Total') AS anio_mes
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal)/1000,0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM mesesfull m
    CROSS JOIN canalfull cf
    LEFT JOIN sales AS c 
    ON m.anio_mes = c.anio_mes and cf.canal = c.canal
    GROUP BY ROLLUP(m.anio_mes,cf.canal))
    
    SELECT a.*
          ,AVG(ingreso_ventas_canal) OVER (PARTITION BY canal ORDER BY anio_mes ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY canal ORDER BY anio_mes ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY canal ORDER BY anio_mes ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE anio_mes <> 'Total'
    "
                      


total_ganancia_mes <- dbGetQuery(conn = on,q_total_ganancia_mes)


# Grafico 

library(ggplot2)

graf_mes_ventas <- ggplot(data = total_ganancia_mes,aes(x = anio_mes)
                          
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1,
            show.legend = F) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1,
            show.legend = F) +
  theme(axis.text.x = element_blank(),
        axis.title.x = element_blank(),
        axis.title.y = element_text(size = 9),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  ylab("Ingreso por ventas\n (millones de US$)")

graf_mes_ventas  



### Graf ganancia
graf_mes_ganancia <- ggplot(data = total_ganancia_mes,aes(x = anio_mes)
                            
) +
  geom_line(aes(y = ganancia_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        axis.title = element_text(size = 9),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - mes)") +
  ylab("Ganancia\n(Miles de US$)")

graf_mes_ganancia  

graf_tiempo <- egg::ggarrange(graf_mes_ventas,graf_mes_ganancia,nrow = 2)




### Ventas y ganancias por region -----------


q_total_ganancia_region <- "

                      WITH 
	ventas_reseller(trim_anio,
	               salesterritorygroup,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                      
    ventas_online(trim_anio,
	                    salesterritorygroup,
	                    salesamount,OrderQuantity,totalProductCost,
                      canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                      FROM FactInternetSales s
                      LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                      LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                      WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                       
    Sales(trim_anio,salesterritorygroup,
	            salesamount,OrderQuantity,totalProductCost,
              canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    RegionFull(salesterritorygroup) AS
                      (SELECT DISTINCT salesterritorygroup
                      FROM Sales),

    AnioFull(trim_anio) AS
       (
       SELECT DISTINCT trim_anio
                      FROM Sales
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.trim_anio AS CHAR),'Total') AS trim_anio
            ,CASE WHEN r.salesterritorygroup = 'Europe' THEN 'Europa'
                  WHEN r.salesterritorygroup = 'North America' THEN 'América del Norte'
                  WHEN r.salesterritorygroup = 'Pacific' THEN 'Pacífico' 
                  ELSE 'Total' END AS region
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM AnioFull m
    CROSS JOIN canalfull cf
    CROSS JOIN regionfull r
    LEFT JOIN sales AS c 
    ON m.trim_anio = c.trim_anio and cf.canal = c.canal and r.SalesTerritoryGroup = c.SalesTerritoryGroup
    GROUP BY ROLLUP(m.trim_anio,r.SalesTerritoryGroup,cf.canal)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and region <> 'Total'
    ORDER BY trim_anio,region
    "



total_ganancia_region <- dbGetQuery(conn = on,q_total_ganancia_region)


# Grafico 

library(ggplot2)


graf_region_ventas <- ggplot(data = total_ganancia_region,aes(x = trim_anio)
                          
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1,
            show.legend = F) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1,
            show.legend = F) +
  theme(axis.text.x = element_blank(),
        axis.title.y = element_text(size = 9),
        axis.title.x = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  ylab("Ingreso por ventas\n(Millones de US$)") +
  facet_wrap(~region,ncol = 3)

graf_region_ventas

### Graf ganancia
graf_region_ganancia <- ggplot(data = total_ganancia_region,aes(x = trim_anio)
                               
) +
  geom_line(aes(y = ganancia_canal,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        axis.title = element_text(size = 9),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - trimestre)") +
  ylab("Ganancia\n(Miles de US$)") +
  facet_wrap(~region)

graf_region_ganancia

graf_tiempo_region <- egg::ggarrange(graf_region_ventas,
                                     graf_region_ganancia,
                                     nrow = 2)  

### Por categoria de producto 

q_total_ganancia_catproducto <- "

                      WITH 
	ventas_reseller(trim_anio,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                      
    ventas_online(trim_anio,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                       
    Sales AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    CatFull(cat_producto) AS
                      (SELECT DISTINCT cat_producto
                      FROM Sales),

    AnioFull(trim_anio) AS
       (
       SELECT DISTINCT trim_anio
                      FROM Sales
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.trim_anio AS CHAR),'Total') AS trim_anio
            ,ISNULL(cp.cat_producto,'Total') AS cat_producto
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM AnioFull m
    CROSS JOIN canalfull cf
    CROSS JOIN catfull cp
    LEFT JOIN sales AS s 
    ON m.trim_anio = s.trim_anio and 
       cf.canal = s.canal and 
       cp.cat_producto = s.cat_producto
    GROUP BY ROLLUP(m.trim_anio,cp.cat_producto,cf.canal)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and cat_producto <> 'Total'
    ORDER BY trim_anio,cat_producto
    "

total_ganancia_catproducto <- dbGetQuery(conn = on,q_total_ganancia_catproducto)


graf_producto_ventas <- ggplot(data = total_ganancia_catproducto,aes(x = trim_anio)
                                      
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 0.8) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 0.8) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - trimestre)") +
  ylab("Ingresos por ventas\n(Millones de US$)") +
  facet_wrap(~cat_producto, ncol = 2)

graf_producto_ventas 



### Por categoria de producto y region -----

q_total_ganancia_producto_region <- "

                      WITH 
	ventas_reseller(trim_anio,
	               salesterritorygroup,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                      
    ventas_online(trim_anio,
	               salesterritorygroup,
	               cat_producto,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritorygroup
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,OrderQuantity
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20110101 and s.orderDateKey <= 20131231
                      ),
                       
    Sales(trim_anio,salesterritorygroup,
          cat_producto,
	            salesamount,OrderQuantity,totalProductCost,
              canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    CatFull(cat_producto) AS
                      (SELECT DISTINCT cat_producto
                      FROM Sales),
                      
    RegionFull(salesterritorygroup) AS
                      (SELECT DISTINCT salesterritorygroup
                      FROM Sales),

    AnioFull(trim_anio) AS
       (
       SELECT DISTINCT trim_anio
                      FROM Sales
       ),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales),
                    
    Agrupado1 AS
      (SELECT  ISNULL(CAST(m.trim_anio AS CHAR),'Total') AS trim_anio
            ,CASE WHEN r.salesterritorygroup = 'Europe' THEN 'Europa'
                  WHEN r.salesterritorygroup = 'North America' THEN 'América del Norte'
                  WHEN r.salesterritorygroup = 'Pacific' THEN 'Pacífico' 
                  ELSE 'Total' END AS region
            ,ISNULL(cp.cat_producto,'Total') AS cat_producto
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(SUM(orderQuantity),0) as unidades_vendidas_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM AnioFull m
    CROSS JOIN canalfull cf
    CROSS JOIN regionfull r
    CROSS JOIN catfull cp
    LEFT JOIN sales AS s 
    ON m.trim_anio = s.trim_anio and 
       cf.canal = s.canal and 
       r.SalesTerritoryGroup = s.SalesTerritoryGroup and
       cp.cat_producto = s.cat_producto
    GROUP BY ROLLUP(m.trim_anio,r.SalesTerritoryGroup,cf.canal,cp.cat_producto)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY region,canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY region,canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY region,canal,cat_producto ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and cat_producto <> 'Total'
    ORDER BY trim_anio,region,cat_producto
    "


total_ganancia_producto_region <- dbGetQuery(conn = on,q_total_ganancia_producto_region)


# Grafico 


graf_producto_region_ventas <- ggplot(data = total_ganancia_producto_region,aes(x = trim_anio)
                                 
) +
  geom_line(aes(y = ingreso_ventas_canal,
                colour = canal,
                group = canal),
            linewidth = 0.8) +
  geom_line(aes(y = mmovil_ventas,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 0.8) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'bottom',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("periodo (año - trimestre)") +
  ylab("Ingresos por ventas\n(Millones de US$)") +
  facet_grid(cat_producto ~ region)

graf_producto_region_ventas 


### Ventas y ganancias totales por categoría de producto, región y canal, últimos 6 meses

q_total_ventas_cat_producto_region <- "

                      WITH 
	ventas_reseller AS
                      (SELECT 
                            
                            CASE 
                              WHEN salesterritorygroup = 'Europe' THEN 'Europa'
                              WHEN salesterritorygroup = 'North America' THEN 'América del Norte'
                              ELSE 'Pacífico' END as salesterritorygroup 
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,totalProductCost
                            ,'reventa (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                      ),
                      
    ventas_online AS
                      (SELECT 
                             CASE 
                              WHEN salesterritorygroup = 'Europe' THEN 'Europa'
                              WHEN salesterritorygroup = 'North America' THEN 'América del Norte'
                              ELSE 'Pacífico' END as salesterritorygroup
                            ,spanishproductcategoryname as cat_producto
                            ,salesamount
                            ,totalProductCost
                              ,'online (minorista)' AS canal
                              ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                  FROM FactInternetSales s
                  LEFT JOIN DimSalesTerritory t
                  on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                  on s.OrderDateKey = d.DateKey
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                      ),
                       
    Sales AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    CatFull(cat_producto) AS
                      (SELECT DISTINCT cat_producto
                      FROM Sales),
                      
    RegionFull(salesterritorygroup) AS
                      (SELECT DISTINCT salesterritorygroup
                      FROM Sales),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales)
                    

      SELECT  
            r.SalesTerritoryGroup AS region
            ,cp.cat_producto 
            ,cf.canal
            ,ISNULL(sum(cast(salesAmount as float)/1000000),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal/1000),0) as ganancia_canal
            ,ISNULL(CASE WHEN 
                        ISNULL(SUM(cast(salesAmount as float)),0) > 0 
                        THEN round(100 * ISNULL(sum(gananciaTotal),0)/ISNULL(sum(cast(salesAmount as float)),0),1) ELSE 0 END,0) as margenGananciaPc

    FROM canalfull cf
    CROSS JOIN regionfull r
    CROSS JOIN catfull cp
    LEFT JOIN sales AS s 
    ON
       cf.canal = s.canal and 
       r.SalesTerritoryGroup = s.SalesTerritoryGroup and
       cp.cat_producto = s.cat_producto
    GROUP BY r.SalesTerritoryGroup
            ,cp.cat_producto 
            ,cf.canal
    "


total_ventas_cat_producto_region <- dbGetQuery(conn = on,q_total_ventas_cat_producto_region)


# Grafico 

graf_cat_producto_region_ventas <- ggplot(data = total_ventas_cat_producto_region,
                                          aes(x = cat_producto,
                                              y = ingreso_ventas_canal,
                                              fill = canal)
                                      
) +
  geom_bar(position = 'dodge',
           stat = 'identity',
           show.legend = F) +
  theme(
    axis.text.x = element_blank()
    ,
    axis.title.x = element_blank(),
    axis.title.y = element_text(size = 9),
        #legend.position = 'bottom',
        #legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  ylab("Ingreso por ventas\n(Millones de US$)") +
  facet_wrap(~region)

graf_cat_producto_region_ventas


graf_cat_producto_region_ganancia <- ggplot(data = total_ventas_cat_producto_region,
                                          aes(x = cat_producto,
                                              y = ganancia_canal,
                                              fill = canal)
                                          
) +
  geom_bar(position = 'dodge',
           stat = 'identity') +
  theme(
    axis.text.x = element_text(angle = 90,
                               vjust = 0.5,
                               hjust = 1
    ),
    axis.title = element_text(size = 9),
    legend.position = 'bottom',
    legend.title = element_blank(),
    panel.background = element_blank(),
    panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                    colour = "gray"), 
    panel.grid.minor = element_blank()) + 
  xlab("Categoría de producto") +
  ylab("Ganancia neta\n(Miles de US$)") +
  facet_wrap(~region)

graf_cat_producto_region_ganancia


graf_cat_producto <- egg::ggarrange(graf_cat_producto_region_ventas,
                                    graf_cat_producto_region_ganancia, 
                                    nrow = 2)





### Margen de ganancias por subcategoría --------------


q_margen_ganancias_productos <- "

                      WITH
                      
    ventas_online AS
                      (SELECT 

                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,salesamount
                            ,totalProductCost
                            ,'online (minorista)' AS canal
                            ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                            ,CASE 
                              WHEN ISNULL(cast(salesAmount as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(salesamount as float) - CAST(totalProductCost as float) ,0)/ISNULL(cast(salesAmount as float),0),1) 
                              ELSE 0.0 END as margenGananciaPc
                  FROM FactInternetSales s
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                  
                      ),
                      
        ventas_reseller AS
                      (SELECT 
                            
                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,salesamount
                            ,totalProductCost
                            ,'mayorista (reseller)' AS canal
                            ,CAST(salesamount as float) - CAST(totalProductCost as float) as gananciaTotal
                            ,CASE 
                              WHEN ISNULL(cast(salesAmount as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(salesamount as float) - CAST(totalProductCost as float) ,0)/ISNULL(cast(salesAmount as float),0),1) 
                              ELSE 0.0 END as margenGananciaPc
                  FROM FactResellerSales s
                  LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                  LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                  LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130701 and s.orderDateKey < 20140000
                      ),
    
    Sales AS
      (SELECT * 
      FROM ventas_online
      
      UNION ALL
      
      SELECT *
      FROM ventas_reseller)
      
      
      SELECT  
            canal
            ,cat_producto
            ,subcat_producto
            ,AVG(margengananciapc) as promedio_margen_gan

      FROM Sales 
      GROUP BY canal,cat_producto,subcat_producto 
      ORDER BY promedio_margen_gan
      
    
    

    "

margen_ganancias_por_productos <- dbGetQuery(conn = on,q_margen_ganancias_productos)


graf_producto_margen <- ggplot(data = margen_ganancias_por_productos,
                                            aes(x = reorder(subcat_producto,-promedio_margen_gan),
                                                y = promedio_margen_gan,
                                                fill = cat_producto)
                                            
) +
  geom_bar(position = 'dodge',
           stat = 'identity') +
  theme(
    axis.text.x = element_text(angle = 60,
                               vjust = 1,
                               hjust = 1
    ),
    axis.title = element_text(size = 9),
    legend.position = 'bottom',
    legend.title = element_blank(),
    panel.background = element_blank(),
    panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                    colour = "gray"), 
    panel.grid.minor = element_blank()) + 
  xlab("Subcategoría de producto") +
  ylab("Promedio margen de ganancia (%)") +
  facet_wrap(~canal, ncol = 1)

graf_producto_margen


### Subcategorías de productos: margen de ganancia y precio promedio por canal --------------


q_ganancias_por_productos <- "

                      WITH
                      
    ventas_online AS
                      (SELECT 
                            
                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,unitPrice as precio_online
                            ,CASE 
                              WHEN ISNULL(cast(unitPrice as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(unitPrice as float) - CAST(ProductStandardCost as float) ,0)/ISNULL(cast(unitPrice as float),0),1) 
                              ELSE 0.0 END as margen_online
                  FROM FactInternetSales s
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130700 and s.orderDateKey <= 20140000
                      ),
                      
        ventas_resellers AS
                      (SELECT 
                            
                            spanishproductcategoryname as cat_producto
                            ,spanishproductsubcategoryname as subcat_producto
                            ,unitPrice * (1 - unitPriceDiscountPct) as precio_reventa
                            ,CASE 
                              WHEN ISNULL(cast(unitPrice * (1 - unitPriceDiscountPct) as float),0) > 0 
                              THEN round(100 * ISNULL(CAST(unitPrice * (1 - unitPriceDiscountPct) as float) - CAST(ProductStandardCost as float) ,0)/ISNULL(cast(unitPrice * (1 - unitPriceDiscountPct) as float),0),1) 
                              ELSE 0.0 END as margen_reventa
                  FROM FactResellerSales s
                      LEFT JOIN DimProduct p
                      on s.ProductKey = p.ProductKey
                      LEFT JOIN DimProductSubCategory ps
                      on p.ProductSubCategoryKey = ps.ProductSubCategoryKey
                      LEFT JOIN DimProductCategory pc
                      on ps.ProductCategoryKey = pc.ProductCategoryKey
                  WHERE s.orderDateKey >= 20130700 and s.orderDateKey <= 20140000
                      ),
    
    totalproductos as
    (SELECT DISTINCT cat_producto,subcat_producto 
         FROM (SELECT cat_producto,subcat_producto FROM ventas_resellers
                UNION ALL
              SELECT cat_producto,subcat_producto FROM ventas_online) p),
              
  tabladatos as
    
   (SELECT c.cat_producto
        ,c.subcat_producto
        ,CAST(round(AVG(o.precio_online),0) AS CHAR) as precio_online
        ,CAST(round(AVG(r.precio_reventa),0) AS CHAR) as precio_reventa
        ,CAST(round(AVG(o.margen_online),1) AS CHAR) as margen_online
        ,CAST(round(AVG(r.margen_reventa),1) AS CHAR) as margen_reventa
        ,CAST(round(100*(1-AVG(r.precio_reventa)/AVG(o.precio_online)),1) AS CHAR) as reventa_online
    FROM totalproductos c
    LEFT JOIN ventas_online o
      on c.subcat_producto = o.subcat_producto
    LEFT JOIN ventas_resellers r
      on c.subcat_producto = r.subcat_producto
    GROUP BY c.cat_producto,c.subcat_producto
    )
    
    SELECT cat_producto as [categoría],
          subcat_producto as [subcategoría], 
          ISNULL(precio_online,'-') AS [precio online medio (US$)],
          ISNULL(precio_reventa,'-') AS [precio reventa medio (US$)],
          ISNULL(margen_online,'-') AS [margen online medio (%)],
          ISNULL(margen_reventa,'-') AS [margen reventa medio (%)],
          ISNULL(reventa_online,'-') AS [dif precio reventa/precio online (%)]
    FROM tabladatos
    ORDER BY cat_producto,subcat_producto
    "

### Esto se puede mostrar como tabla directamente.
ganancias_por_productos <- dbGetQuery(conn = on,q_ganancias_por_productos)

gt_margen_products <- gt::gt(ganancias_por_productos) %>% 
  gt::tab_options(
    column_labels.font.size = gt::px(8),
    column_labels.font.weight = 'bold',
    table.font.size = gt::px(7),
    data_row.padding = gt::px(0),
    table.width = gt::px(400)
  )



gt::gtsave(gt_margen_products,
           'C:/Users/malen/Dropbox/MAESTRIA_CDD/MRCD/TPMR/Análisis de rentabilidad/tabla1_margen_productos.png'
           )


### Cantidad de clientes, distribución geográfica y comportamiento de compra





### Perfiles de clientes más rentables

q_rentabilidad_clientes <- "
                    SELECT customerkey,
                            salesterritoryregion as territorio,
                            SUM(SalesAmount)- SUM(TotalProductCost) as ganancia,
                            COUNT(distinct SalesOrderNumber) as cant_compras,
                            COUNT(distinct ProductKey) as cant_productos
                    FROM FactInternetSales s
                    LEFT JOIN DimSalesTerritory t
                    on s.SalesTerritoryKey = t.SalesTerritoryKey
                    WHERE s.orderDateKey >= 20130100 and s.orderDateKey < 20140000
                    GROUP BY customerkey,
                             salesterritoryregion
      "

  
rentabilidad_clientes <- dbGetQuery(conn = on,q_rentabilidad_clientes)


# Gráfico de distribución rentabilidad en general

bp_rentabilidad_clientes <- ggplot(rentabilidad_clientes, aes(x=ganancia)) + 
                             geom_histogram(bins = 20) +
                            xlab("Ganancia (US$)") +
                            ylab("n") +
                            theme_minimal() +
                            geom_vline(xintercept = max(rentabilidad_clientes$ganancia),
                                       linetype = 2,
                                       color = 'red')

bp_rentabilidad_clientes


q_rentabilidad_clientes_total <- "

        WITH ganancia_clientes_2013 AS
        
        (
                    SELECT customerkey,
                            salesterritoryregion as territorio,
                            SUM(SalesAmount)- SUM(TotalProductCost) as ganancia,
                            COUNT(distinct SalesOrderNumber) as cant_compras,
                            COUNT(distinct ProductKey)  as cant_productos
                    FROM FactInternetSales s
                    LEFT JOIN DimSalesTerritory t
                    on s.SalesTerritoryKey = t.SalesTerritoryKey
                    WHERE s.orderDateKey >= 20130100 and s.orderDateKey < 20140000
                    GROUP BY customerkey,
                             salesterritoryregion
          ),
          clientes_percentil as (
                    
            SELECT c.*,
                    PERCENT_RANK() OVER(ORDER BY ganancia DESC) as percentil
                    FROM ganancia_clientes_2013 as c
                    
        ),
        
        clientes_top as (
        
        SELECT *,
               '1° veintil'as grupo 
        FROM clientes_percentil
        WHERE percentil <= 0.05 
    ),
    
      clientes_global AS
      
      (SELECT *
        FROM (SELECT
                customerkey,
                territorio,
                ganancia,
                cant_compras,
                cant_productos,
                'general' as grupo
                
              FROM ganancia_clientes_2013) gc

        UNION ALL

        SELECT 
                customerkey,
                territorio,
                ganancia,
                cant_compras,
                cant_productos,
                grupo
                FROM clientes_top
      ),
      
    sum_grupo AS
    (
    SELECT grupo, 
            sum(ganancia) as sum_grupo_gan
      FROM clientes_global
      GROUP BY grupo
   )
  SELECT c.*,
        sum_grupo_gan 
  FROM clientes_global c
  LEFT JOIN sum_grupo s
    ON c.grupo = s.grupo
   
"
      

rentabilidad_clientes_total <- dbGetQuery(conn = on,q_rentabilidad_clientes_total)


### GráficoS de comparación top 5% clientes vs. clientes general


graf_comp_clientes_territorio <- ggplot(rentabilidad_clientes_total, 
                                        aes(x= territorio,  group=grupo)) + 
  geom_bar(aes(y = ..prop.., fill = factor(..x..)), stat="count",
           show.legend = F) +
  facet_grid(~grupo) +
  scale_y_continuous(labels = scales::percent) +
  theme(
    axis.text.x = element_text(angle = 60,
                               vjust = 1,
                               hjust = 1
    ),
    axis.title = element_blank(),
    legend.title = element_blank(),
    panel.background = element_blank(),
    panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                    colour = "gray"), 
    panel.grid.minor = element_blank()) +
  scale_fill_brewer(palette="Paired")




graf_comp_clientes_territorio


hist_clientes_productos <- ggplot(rentabilidad_clientes_total, aes(x=cant_productos)) + 
  geom_density() +
  xlab("Cantidad de productos distintos comprados") +
  ylab("n") +
  theme_minimal() +
  facet_wrap(~grupo)

hist_clientes_productos




graf_comp_clientes_compras
        
