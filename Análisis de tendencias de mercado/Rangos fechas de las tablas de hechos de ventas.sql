SELECT MIN(fis.OrderDate), MAX(fis.OrderDate)
FROM AdventureWorksDW2019.dbo.FactInternetSales fis

SELECT MIN(frs.OrderDate), MAX(frs.OrderDate)
FROM AdventureWorksDW2019.dbo.FactResellerSales frs

SELECT MIN(f.OrderDate), MAX(f.OrderDate)
FROM (SELECT OrderDate FROM AdventureWorksDW2019.dbo.FactResellerSales 
	  UNION 
	  SELECT OrderDate FROM AdventureWorksDW2019.dbo.FactInternetSales) AS f