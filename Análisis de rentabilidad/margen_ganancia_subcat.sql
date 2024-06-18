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