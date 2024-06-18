 WITH 
	ventas_reseller AS
                      (SELECT 
                            
                            salesterritoryregion 
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
                             salesterritoryregion
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
                      
    RegionFull(salesterritoryregion) AS
                      (SELECT DISTINCT salesterritoryregion
                      FROM Sales),
       
    CanalFull(canal) AS
      (SELECT DISTINCT canal FROM sales)
                    

      SELECT  
            CASE WHEN r.salesterritoryregion = 'France' THEN 'Francia'
                  WHEN r.salesterritoryregion = 'Germany' THEN 'Alemania'
                  WHEN r.salesterritoryregion = 'Northeast' THEN 'EEUU - NE'
                  WHEN r.salesterritoryregion = 'Northwest' THEN 'EEUU - NO'
                  WHEN r.salesterritoryregion = 'Southwest' THEN 'EEUU - SO'
                  WHEN r.salesterritoryregion = 'Southeast' THEN 'EEUU - SE'
                  WHEN r.salesterritoryregion = 'Central' THEN 'EEUU - Centro'
                  WHEN r.salesterritoryregion = 'United Kingdom' THEN 'Reino Unido'
                  ELSE r.salesterritoryregion END as region
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
       r.SalesTerritoryRegion = s.SalesTerritoryRegion and
       cp.cat_producto = s.cat_producto
    GROUP BY r.SalesTerritoryRegion
            ,cp.cat_producto 
            ,cf.canal