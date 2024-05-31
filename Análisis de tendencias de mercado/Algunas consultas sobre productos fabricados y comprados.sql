--https://www.codeproject.com/Articles/1177401/Work-with-the-AdventureWorks-Bill-of-Materials-usi

--Componentes comprados para fabricar
SELECT DISTINCT ComponentID  
FROM AdventureWorks2019.Production.BillOfMaterials
INTERSECT 
SELECT DISTINCT ProductID
FROM AdventureWorks2019.Purchasing.ProductVendor 

--Componentes de fabricación propia que no se compran afuera
SELECT DISTINCT ComponentID  
FROM AdventureWorks2019.Production.BillOfMaterials
EXCEPT
SELECT DISTINCT ProductID
FROM AdventureWorks2019.Purchasing.ProductVendor 

--Productos fabricados que también se compran
SELECT DISTINCT ProductAssemblyID
FROM AdventureWorks2019.Production.BillOfMaterials 
INTERSECT
SELECT DISTINCT ProductID
FROM AdventureWorks2019.Purchasing.ProductVendor 

