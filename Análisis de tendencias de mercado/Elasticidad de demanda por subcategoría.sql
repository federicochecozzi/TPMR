--Por internet
WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
	SELECT dps.ProductSubcategoryKey,fis.OrderDateKey, fis.OrderQuantity,fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE fis.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Subcategory,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.Subcategory,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY Subcategory,dd.CalendarYear, dd.MonthNumberOfYear
),
SumOrderQtyTable(Subcategory,[Year],sumx,sumy,sumxx,sumxy,N) AS (
	SELECT Subcategory,[Year], 
		   SUM(LOG(Price)),
		   SUM(LOG(OrderQty)),
		   SUM(LOG(Price)*LOG(Price)),
		   SUM(LOG(OrderQty)*LOG(Price)), --OVER(PARTITION BY Subcategory,[Year])
		   1.0*COUNT(*)
	FROM OrderQtyTable
	GROUP BY Subcategory,[Year]
),
ElasticityTable(Subcategory,[Year],Elasticity) AS (
	SELECT Subcategory,[Year],(N*sumxy-sumx*sumy)/NULLIF(N*sumxx-sumx*sumx,0)
	FROM SumOrderQtyTable
),
PivotedElasticityTable(Subcategory,Elasticity_2010,Elasticity_2011,Elasticity_2012,Elasticity_2013,Elasticity_2014) AS (
	SELECT Subcategory,[2010],[2011],[2012],[2013],[2014]
	FROM ElasticityTable AS SourceTable
	PIVOT
	(
		MAX(Elasticity)
		FOR [Year] IN ([2010],[2011],[2012],[2013],[2014])
	) AS PivotTable
)
SELECT pet.Subcategory,dps.EnglishProductSubcategoryName, pet.Elasticity_2011, pet.Elasticity_2012, pet.Elasticity_2013
FROM PivotedElasticityTable pet, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE pet.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory

--Reventa
WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
	SELECT dps.ProductSubcategoryKey,frs.OrderDateKey, frs.OrderQuantity,frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE frs.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Subcategory,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.Subcategory,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY Subcategory,dd.CalendarYear, dd.MonthNumberOfYear
),
SumOrderQtyTable(Subcategory,[Year],sumx,sumy,sumxx,sumxy,N) AS (
	SELECT Subcategory,[Year], 
		   SUM(LOG(Price)),
		   SUM(LOG(OrderQty)),
		   SUM(LOG(Price)*LOG(Price)),
		   SUM(LOG(OrderQty)*LOG(Price)), --OVER(PARTITION BY Subcategory,[Year])
		   1.0*COUNT(*)
	FROM OrderQtyTable
	GROUP BY Subcategory,[Year]
),
ElasticityTable(Subcategory,[Year],Elasticity) AS (
	SELECT Subcategory,[Year],(N*sumxy-sumx*sumy)/NULLIF(N*sumxx-sumx*sumx,0)
	FROM SumOrderQtyTable
),
PivotedElasticityTable(Subcategory,Elasticity_2010,Elasticity_2011,Elasticity_2012,Elasticity_2013,Elasticity_2014) AS (
	SELECT Subcategory,[2010],[2011],[2012],[2013],[2014]
	FROM ElasticityTable AS SourceTable
	PIVOT
	(
		MAX(Elasticity)
		FOR [Year] IN ([2010],[2011],[2012],[2013],[2014])
	) AS PivotTable
)
SELECT pet.Subcategory,dps.EnglishProductSubcategoryName, pet.Elasticity_2011, pet.Elasticity_2012, pet.Elasticity_2013
FROM PivotedElasticityTable pet, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE pet.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory

--Total
WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
	SELECT dps.ProductSubcategoryKey,fis.OrderDateKey, fis.OrderQuantity,fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE fis.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
	UNION ALL
	SELECT dps.ProductSubcategoryKey,frs.OrderDateKey, frs.OrderQuantity,frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE frs.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Subcategory,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.Subcategory,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs,AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY Subcategory,dd.CalendarYear, dd.MonthNumberOfYear
),
SumOrderQtyTable(Subcategory,[Year],sumx,sumy,sumxx,sumxy,N) AS (
	SELECT Subcategory,[Year], 
		   SUM(LOG(Price)),
		   SUM(LOG(OrderQty)),
		   SUM(LOG(Price)*LOG(Price)),
		   SUM(LOG(OrderQty)*LOG(Price)), --OVER(PARTITION BY Subcategory,[Year])
		   1.0*COUNT(*)
	FROM OrderQtyTable
	GROUP BY Subcategory,[Year]
),
ElasticityTable(Subcategory,[Year],Elasticity) AS (
	SELECT Subcategory,[Year],(N*sumxy-sumx*sumy)/NULLIF(N*sumxx-sumx*sumx,0)
	FROM SumOrderQtyTable
),
PivotedElasticityTable(Subcategory,Elasticity_2010,Elasticity_2011,Elasticity_2012,Elasticity_2013,Elasticity_2014) AS (
	SELECT Subcategory,[2010],[2011],[2012],[2013],[2014]
	FROM ElasticityTable AS SourceTable
	PIVOT
	(
		MAX(Elasticity)
		FOR [Year] IN ([2010],[2011],[2012],[2013],[2014])
	) AS PivotTable
)
SELECT pet.Subcategory,dps.EnglishProductSubcategoryName, pet.Elasticity_2011, pet.Elasticity_2012, pet.Elasticity_2013
FROM PivotedElasticityTable pet, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE pet.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory