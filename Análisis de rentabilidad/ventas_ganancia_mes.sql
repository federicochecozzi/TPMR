
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
    