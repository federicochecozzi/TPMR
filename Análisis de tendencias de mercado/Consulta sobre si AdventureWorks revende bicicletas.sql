SELECT p.ProductID 
FROM AdventureWorks2019.Production.Product p, AdventureWorks2019.Production.ProductSubcategory ps, 
AdventureWorks2019.Production.ProductCategory pc 
WHERE p.ProductSubcategoryID = ps.ProductSubcategoryID AND ps.ProductCategoryID = pc.ProductCategoryID 
AND pc.Name = 'Bikes'
INTERSECT
SELECT DISTINCT ProductID
FROM AdventureWorks2019.Purchasing.ProductVendor 