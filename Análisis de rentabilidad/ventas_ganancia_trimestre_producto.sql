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