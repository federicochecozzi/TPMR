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
                            ,'reseller (mayorista)' as canal
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
            ,ISNULL(sum(cast(salesAmount as float)),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal),0) as ganancia_canal
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

str(total_ganancia_mes)

# Grafico 

library(ggplot2)

graf_mes_ventas <- ggplot(data = total_ganancia_mes,aes(x = anio_mes)
                          
) +
  geom_line(aes(y = ingreso_ventas_canal/1000000,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ventas/1000000,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
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
  xlab("periodo (año - mes)") +
  ylab("Millones de US$")

graf_mes_ventas  

### Graf ganancia
graf_mes_ganancia <- ggplot(data = total_ganancia_mes,aes(x = anio_mes)
                            
) +
  geom_line(aes(y = ganancia_canal/1000,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia/1000,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
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
  xlab("periodo (año - mes)") +
  ylab("Miles de US$")

graf_mes_ganancia  






### Márgenes de rentabilidad anual por region -----------


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
                            ,'reseller (mayorista)' as canal
                            ,cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
      				   FROM FactResellerSales s
      				   LEFT JOIN DimSalesTerritory t
                      on s.SalesTerritoryKey = t.SalesTerritoryKey
                  LEFT JOIN DimDate d 
                      on s.OrderDateKey = d.DateKey 
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
            ,ISNULL(r.SalesTerritoryGroup,'Total') AS region
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal),0) as ganancia_canal
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
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 3 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and region <> 'Total'
    ORDER BY trim_anio,region
    "



total_ganancia_region <- dbGetQuery(conn = on,q_total_ganancia_region)


# Grafico 

library(ggplot2)

graf_region_ventas <- ggplot(data = total_ganancia_region,aes(x = trim_anio)
                          
) +
  geom_line(aes(y = ingreso_ventas_canal/1000000,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ventas/1000000,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
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
  ylab("Millones de US$") +
  facet_wrap(~region,nrow = 2, ncol = 4)

graf_region_ventas

### Graf ganancia
graf_region_ganancia <- ggplot(data = total_ganancia_region,aes(x = trim_anio)
                               
) +
  geom_line(aes(y = ganancia_canal/1000,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia/1000,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
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
  ylab("Miles de US$") +
  facet_wrap(~region,nrow = 2, ncol = 4)

graf_region_ganancia  

### Por categoria de producto -----

q_total_ganancia_producto <- "

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
                            ,'reseller (mayorista)' as canal
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
            ,ISNULL(r.SalesTerritoryGroup,'Total') AS region
            ,ISNULL(cp.cat_producto,'Total') AS cat_producto
            ,ISNULL(cf.canal,'Total') as canal
            ,ISNULL(sum(cast(salesAmount as float)),0) as ingreso_ventas_canal
            ,ISNULL(sum(gananciaTotal),0) as ganancia_canal
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
    WHERE trim_anio <> 'Total' and region <> 'Total' and cat_producto <> 'Total'
    ORDER BY trim_anio,region,cat_producto
    "



total_ganancia_producto <- dbGetQuery(conn = on,q_total_ganancia_producto)



# Grafico 

library(ggplot2)


### Graf ganancia
graf_producto_ganancia <- ggplot(data = total_ganancia_producto,aes(x = trim_anio)
                               
) +
  geom_line(aes(y = ganancia_canal/1000,
                colour = canal,
                group = canal),
            linewidth = 1.1) +
  geom_line(aes(y = mmovil_ganancia/1000,
                colour = canal,
                group = canal),
            linetype = 'dotted',
            linewidth = 1.1) +
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
  ylab("Miles de US$") +
  facet_grid(cat_producto ~ region)

graf_producto_ganancia  


