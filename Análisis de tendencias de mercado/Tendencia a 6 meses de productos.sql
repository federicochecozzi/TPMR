WITH FactSales(ProductID,OrderDateKey,OrderQty) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
	UNION
	SELECT frs.ProductKey,frs.OrderDateKey, frs.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty
	FROM FactSales fs, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.ProductID = dp.ProductKey AND
		fs.OrderDateKey = dd.DateKey  
	GROUP BY ProductID,dd.CalendarYear, dd.MonthNumberOfYear
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
FactorTable(ProductID,[Year],[Month],MonthNumber) AS (
	SELECT c.ProductID,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.ProductID ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT ProductID FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.ProductID,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.ProductID = oqpm.ProductID AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
SumOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,sumx,sumy,sumxx,sumxy) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,OrderQty, 
		   SUM(MonthNumber) OVER(PARTITION BY ProductID ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty) OVER(PARTITION BY ProductID ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(MonthNumber*MonthNumber) OVER(PARTITION BY ProductID ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty*MonthNumber) OVER(PARTITION BY ProductID ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
	FROM ExtendedOrderQtyTable
),
SixMonthTrendOrderQty(ProductID,[Year],[Month],MonthNumber,OrderQty,Trend) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,OrderQty,(6*sumxy-sumx*sumy)/(6.0*sumxx-sumx*sumx)
	FROM SumOrderQtyTable
)
SELECT TOP(20) t.ProductID, dp.EnglishProductName , t.Trend
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE t.ProductID = dp.ProductKey AND MonthNumber = 38
ORDER BY Trend DESC