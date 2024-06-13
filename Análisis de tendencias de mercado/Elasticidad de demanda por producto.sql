--Por internet
WITH FactSales(ProductID,OrderDateKey,OrderQty,Price) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity,fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs,  
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY ProductID,dd.CalendarYear, dd.MonthNumberOfYear
),
SumOrderQtyTable(ProductID,[Year],sumx,sumy,sumxx,sumxy,N) AS (
	SELECT ProductID,[Year], 
		   SUM(LOG(Price)),
		   SUM(LOG(OrderQty)),
		   SUM(LOG(Price)*LOG(Price)),
		   SUM(LOG(OrderQty)*LOG(Price)), --OVER(PARTITION BY Subcategory,[Year])
		   1.0*COUNT(*)
	FROM OrderQtyTable
	GROUP BY ProductID,[Year]
),
ElasticityTable(ProductID,[Year],Elasticity) AS (
	SELECT ProductID,[Year],(N*sumxy-sumx*sumy)/NULLIF(N*sumxx-sumx*sumx,0)
	FROM SumOrderQtyTable
)
SELECT et.ProductID, et.[Year],dp.EnglishProductName , et.Elasticity
FROM ElasticityTable et, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE et.ProductID = dp.ProductKey 
ORDER BY ProductID,[Year]

--Reventa
WITH FactSales(ProductID,OrderDateKey,OrderQty,Price) AS (
	SELECT frs.ProductKey,frs.OrderDateKey, frs.OrderQuantity,frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs,  
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY ProductID,dd.CalendarYear, dd.MonthNumberOfYear
),
SumOrderQtyTable(ProductID,[Year],sumx,sumy,sumxx,sumxy,N) AS (
	SELECT ProductID,[Year], 
		   SUM(LOG(Price)),
		   SUM(LOG(OrderQty)),
		   SUM(LOG(Price)*LOG(Price)),
		   SUM(LOG(OrderQty)*LOG(Price)), --OVER(PARTITION BY Subcategory,[Year])
		   1.0*COUNT(*)
	FROM OrderQtyTable
	GROUP BY ProductID,[Year]
),
ElasticityTable(ProductID,[Year],Elasticity) AS (
	SELECT ProductID,[Year],(N*sumxy-sumx*sumy)/NULLIF(N*sumxx-sumx*sumx,0)
	FROM SumOrderQtyTable
)
SELECT et.ProductID, et.[Year],dp.EnglishProductName , et.Elasticity
FROM ElasticityTable et, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE et.ProductID = dp.ProductKey 
ORDER BY ProductID,[Year]

--Total
WITH FactSales(ProductID,OrderDateKey,OrderQty,Price) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity,fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
	UNION ALL
	SELECT frs.ProductKey,frs.OrderDateKey, frs.OrderQuantity,frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs,  
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY ProductID,dd.CalendarYear, dd.MonthNumberOfYear
),
SumOrderQtyTable(ProductID,[Year],sumx,sumy,sumxx,sumxy,N) AS (
	SELECT ProductID,[Year], 
		   SUM(LOG(Price)),
		   SUM(LOG(OrderQty)),
		   SUM(LOG(Price)*LOG(Price)),
		   SUM(LOG(OrderQty)*LOG(Price)), --OVER(PARTITION BY Subcategory,[Year])
		   1.0*COUNT(*)
	FROM OrderQtyTable
	GROUP BY ProductID,[Year]
),
ElasticityTable(ProductID,[Year],Elasticity) AS (
	SELECT ProductID,[Year],(N*sumxy-sumx*sumy)/NULLIF(N*sumxx-sumx*sumx,0)
	FROM SumOrderQtyTable
)
SELECT et.ProductID, et.[Year],dp.EnglishProductName , et.Elasticity
FROM ElasticityTable et, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE et.ProductID = dp.ProductKey 
ORDER BY ProductID,[Year]