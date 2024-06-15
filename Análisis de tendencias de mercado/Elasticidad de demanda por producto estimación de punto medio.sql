--Por internet
WITH FactSales(ProductID,OrderDateKey,OrderQty,Price) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity, fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty), AVG(fs.Price)
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
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)		
),
FactorTable(ProductID,[Year],[Month],MonthNumber) AS (
	SELECT c.ProductID,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.ProductID ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT ProductID FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,Price) AS (
	SELECT ft.ProductID,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0), ISNULL(oqpm.Price,0) 
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.ProductID = oqpm.ProductID AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
LagOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,Price,PreviousOrderQty,PreviousPrice) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,OrderQty,Price,
		   LAG(OrderQty,1) OVER(PARTITION BY ProductID ORDER BY MonthNumber),
		   LAG(Price,1) OVER(PARTITION BY ProductID ORDER BY MonthNumber)
	FROM ExtendedOrderQtyTable
),
ElasticityTable(ProductID,[Year],[Month],MonthNumber,Elasticity) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,
		   (OrderQty - PreviousOrderQty)*(Price + PreviousPrice)/NULLIF((Price - PreviousPrice)*(OrderQty + PreviousOrderQty),0)
	FROM LagOrderQtyTable
)
SELECT *
FROM ElasticityTable

--Reventa
WITH FactSales(ProductID,OrderDateKey,OrderQty,Price) AS (
	SELECT frs.ProductKey,frs.OrderDateKey, frs.OrderQuantity, frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty), AVG(fs.Price)
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
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)		
),
FactorTable(ProductID,[Year],[Month],MonthNumber) AS (
	SELECT c.ProductID,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.ProductID ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT ProductID FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,Price) AS (
	SELECT ft.ProductID,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0), ISNULL(oqpm.Price,0) 
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.ProductID = oqpm.ProductID AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
LagOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,Price,PreviousOrderQty,PreviousPrice) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,OrderQty,Price,
		   LAG(OrderQty,1) OVER(PARTITION BY ProductID ORDER BY MonthNumber),
		   LAG(Price,1) OVER(PARTITION BY ProductID ORDER BY MonthNumber)
	FROM ExtendedOrderQtyTable
),
ElasticityTable(ProductID,[Year],[Month],MonthNumber,Elasticity) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,
		   (OrderQty - PreviousOrderQty)*(Price + PreviousPrice)/NULLIF((Price - PreviousPrice)*(OrderQty + PreviousOrderQty),0)
	FROM LagOrderQtyTable
)
SELECT *
FROM ElasticityTable

--Total
WITH FactSales(ProductID,OrderDateKey,OrderQty,Price) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity, fis.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
	UNION ALL
	SELECT frs.ProductKey,frs.OrderDateKey, frs.OrderQuantity, frs.UnitPrice
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
),
OrderQtyTable(ProductID,[Year],[Month],OrderQty,Price) AS(
	SELECT fs.ProductID,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty), AVG(fs.Price)
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
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)		
),
FactorTable(ProductID,[Year],[Month],MonthNumber) AS (
	SELECT c.ProductID,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.ProductID ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT ProductID FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,Price) AS (
	SELECT ft.ProductID,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0), ISNULL(oqpm.Price,0) 
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.ProductID = oqpm.ProductID AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
LagOrderQtyTable(ProductID,[Year],[Month],MonthNumber,OrderQty,Price,PreviousOrderQty,PreviousPrice) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,OrderQty,Price,
		   LAG(OrderQty,1) OVER(PARTITION BY ProductID ORDER BY MonthNumber),
		   LAG(Price,1) OVER(PARTITION BY ProductID ORDER BY MonthNumber)
	FROM ExtendedOrderQtyTable
),
ElasticityTable(ProductID,[Year],[Month],MonthNumber,Elasticity) AS (
	SELECT ProductID,[Year],[Month],MonthNumber,
		   (OrderQty - PreviousOrderQty)*(Price + PreviousPrice)/NULLIF((Price - PreviousPrice)*(OrderQty + PreviousOrderQty),0)
	FROM LagOrderQtyTable
)
SELECT *
FROM ElasticityTable