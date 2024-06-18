WITH 
	ventas_reseller(trim_anio,
	               salesterritoryregion,
	                salesamount,OrderQuantity,totalProductCost,
                  canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritoryregion
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
	                    salesterritoryregion,
	                    salesamount,OrderQuantity,totalProductCost,
                      canal, gananciaTotal) AS
                      (SELECT 
                            concat(CalendarYear,'_',CalendarQuarter) as trim_anio
                            ,salesterritoryregion
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
                       
    Sales(trim_anio,salesterritoryregion,
	            salesamount,OrderQuantity,totalProductCost,
              canal, gananciaTotal) AS
                      (SELECT * FROM ventas_online
                      UNION ALL
                      SELECT * FROM ventas_reseller),
                      
    RegionFull(salesterritoryregion) AS
                      (SELECT DISTINCT salesterritoryregion
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
            ,CASE WHEN r.salesterritoryregion = 'France' THEN 'Francia'
                  WHEN r.salesterritoryregion = 'Germany' THEN 'Alemania'
                  WHEN r.salesterritoryregion = 'Northeast' THEN 'EEUU - NE'
                  WHEN r.salesterritoryregion = 'Northwest' THEN 'EEUU - NO'
                  WHEN r.salesterritoryregion = 'Southwest' THEN 'EEUU - SO'
                  WHEN r.salesterritoryregion = 'Southeast' THEN 'EEUU - SE'
                  WHEN r.salesterritoryregion = 'Central' THEN 'EEUU - Centro'
                  WHEN r.salesterritoryregion = 'United Kingdom' THEN 'Reino Unido'
                  ELSE r.salesterritoryregion END as region
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
    ON m.trim_anio = c.trim_anio and cf.canal = c.canal and r.SalesTerritoryregion = c.SalesTerritoryregion
    GROUP BY ROLLUP(m.trim_anio,r.SalesTerritoryregion,cf.canal)
    )
    
    
    SELECT a.*
    ,AVG(ingreso_ventas_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ventas
          ,AVG(ganancia_canal) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_ganancia
          ,AVG(margenGananciaPc) OVER (PARTITION BY region,canal ORDER BY trim_anio ROWS BETWEEN 6 PRECEDING AND CURRENT ROW) AS mmovil_margen
    
    FROM agrupado1 a
    WHERE trim_anio <> 'Total' and region <> 'Total'
    ORDER BY trim_anio,region