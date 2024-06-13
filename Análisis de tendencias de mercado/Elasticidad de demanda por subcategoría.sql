--Por internet
WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
	SELECT dps.ProductSubcategoryKey,fis.OrderDateKey, fis.OrderQuantity,fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE fis.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Subcategory,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.Subcategory,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.Subcategory = dp.ProductKey AND
		fs.OrderDateKey = dd.DateKey  
	GROUP BY Subcategory,dd.CalendarYear, dd.MonthNumberOfYear
),
MinMaxDate(OldestDate,NewestDate) AS (
	SELECT MIN(dd.FullDateAlternateKey), MAX(dd.FullDateAlternateKey)
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd
	WHERE fs.OrderDateKey = dd.DateKey  
),
DateRange([Date]) AS (
	SELECT OldestDate AS [Date]
	FROM MinMaxDate
	UNION ALL
	SELECT DATEADD( m , 1 , [Date]) AS [Date]
	FROM DateRange
	WHERE [Date] < (SELECT NewestDate
					FROM MinMaxDate)		
),
FactorTable(Subcategory,[Year],[Month],MonthNumber) AS (
	SELECT st.Subcategory,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY st.Subcategory ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcategory FROM OrderQtyTable) AS st
),
ExtendedOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price) AS (--¿Lo necesito?
	SELECT ft.Subcategory,ft.[Year],ft.[Month], ft.MonthNumber, 
	ISNULL(oqt.OrderQty,0) AS OrderQty, ISNULL(oqt.Price,0) AS Price
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqt ON 
	ft.Subcategory = oqt.Subcategory AND ft.[Year] = oqt.[Year] AND ft.[Month] = oqt.[Month] 
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
)
SELECT et.Subcategory, et.[Year],dps.EnglishProductSubcategoryName , et.Elasticity
FROM ElasticityTable et, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE et.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory,[Year]

--Reventa
WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
	SELECT dps.ProductSubcategoryKey,frs.OrderDateKey, frs.OrderQuantity,frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE frs.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Subcategory,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.Subcategory,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty, AVG(fs.Price) AS Price
	FROM FactSales fs, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.Subcategory = dp.ProductKey AND
		fs.OrderDateKey = dd.DateKey  
	GROUP BY Subcategory,dd.CalendarYear, dd.MonthNumberOfYear
),
MinMaxDate(OldestDate,NewestDate) AS (
	SELECT MIN(dd.FullDateAlternateKey), MAX(dd.FullDateAlternateKey)
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd
	WHERE fs.OrderDateKey = dd.DateKey  
),
DateRange([Date]) AS (
	SELECT OldestDate AS [Date]
	FROM MinMaxDate
	UNION ALL
	SELECT DATEADD( m , 1 , [Date]) AS [Date]
	FROM DateRange
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)
),
FactorTable(Subcategory,[Year],[Month],MonthNumber) AS (
	SELECT st.Subcategory,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY st.Subcategory ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcategory FROM OrderQtyTable) AS st
),
ExtendedOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price) AS (--¿Lo necesito?
	SELECT ft.Subcategory,ft.[Year],ft.[Month], ft.MonthNumber, 
	ISNULL(oqt.OrderQty,0) AS OrderQty, ISNULL(oqt.Price,0) AS Price
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqt ON 
	ft.Subcategory = oqt.Subcategory AND ft.[Year] = oqt.[Year] AND ft.[Month] = oqt.[Month] 
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
)
SELECT et.Subcategory, et.[Year],dps.EnglishProductSubcategoryName , et.Elasticity
FROM ElasticityTable et, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE et.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory,[Year]

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
	FROM FactSales fs, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.Subcategory = dp.ProductKey AND
		fs.OrderDateKey = dd.DateKey  
	GROUP BY Subcategory,dd.CalendarYear, dd.MonthNumberOfYear
),
MinMaxDate(OldestDate,NewestDate) AS (
	SELECT MIN(dd.FullDateAlternateKey), MAX(dd.FullDateAlternateKey)
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd
	WHERE fs.OrderDateKey = dd.DateKey  
),
DateRange([Date]) AS (
	SELECT OldestDate AS [Date]
	FROM MinMaxDate
	UNION ALL
	SELECT DATEADD( m , 1 , [Date]) AS [Date]
	FROM DateRange
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)
),
FactorTable(Subcategory,[Year],[Month],MonthNumber) AS (
	SELECT st.Subcategory,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY st.Subcategory ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcategory FROM OrderQtyTable) AS st
),
ExtendedOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price) AS (--¿Lo necesito?
	SELECT ft.Subcategory,ft.[Year],ft.[Month], ft.MonthNumber, 
	ISNULL(oqt.OrderQty,0) AS OrderQty, ISNULL(oqt.Price,0) AS Price
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqt ON 
	ft.Subcategory = oqt.Subcategory AND ft.[Year] = oqt.[Year] AND ft.[Month] = oqt.[Month] 
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
)
SELECT et.Subcategory, et.[Year],dps.EnglishProductSubcategoryName , et.Elasticity
FROM ElasticityTable et, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE et.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory,[Year]