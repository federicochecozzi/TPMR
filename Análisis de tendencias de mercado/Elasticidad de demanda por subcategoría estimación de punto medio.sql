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
	SELECT c.Subcategory,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcategory ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcategory FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price) AS (
	SELECT ft.Subcategory,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0), ISNULL(oqpm.Price,0) 
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.Subcategory = oqpm.Subcategory AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
LagOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price,PreviousOrderQty,PreviousPrice) AS (
	SELECT Subcategory,[Year],[Month],MonthNumber,OrderQty,Price,
		   LAG(OrderQty,1) OVER(PARTITION BY Subcategory ORDER BY MonthNumber),
		   LAG(Price,1) OVER(PARTITION BY Subcategory ORDER BY MonthNumber)
	FROM ExtendedOrderQtyTable
),
ElasticityTable(Subcategory,[Year],[Month],MonthNumber,Elasticity) AS (
	SELECT Subcategory,[Year],[Month],MonthNumber,
		   (OrderQty - PreviousOrderQty)*(Price + PreviousPrice)/NULLIF((Price - PreviousPrice)*(OrderQty + PreviousOrderQty),0)
	FROM LagOrderQtyTable
)
SELECT *
FROM ElasticityTable

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
	SELECT c.Subcategory,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcategory ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcategory FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price) AS (
	SELECT ft.Subcategory,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0), ISNULL(oqpm.Price,0) 
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.Subcategory = oqpm.Subcategory AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
LagOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price,PreviousOrderQty,PreviousPrice) AS (
	SELECT Subcategory,[Year],[Month],MonthNumber,OrderQty,Price,
		   LAG(OrderQty,1) OVER(PARTITION BY Subcategory ORDER BY MonthNumber),
		   LAG(Price,1) OVER(PARTITION BY Subcategory ORDER BY MonthNumber)
	FROM ExtendedOrderQtyTable
),
ElasticityTable(Subcategory,[Year],[Month],MonthNumber,Elasticity) AS (
	SELECT Subcategory,[Year],[Month],MonthNumber,
		   (OrderQty - PreviousOrderQty)*(Price + PreviousPrice)/NULLIF((Price - PreviousPrice)*(OrderQty + PreviousOrderQty),0)
	FROM LagOrderQtyTable
)
SELECT *
FROM ElasticityTable

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
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
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
	SELECT c.Subcategory,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcategory ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcategory FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price) AS (
	SELECT ft.Subcategory,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0), ISNULL(oqpm.Price,0) 
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.Subcategory = oqpm.Subcategory AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
LagOrderQtyTable(Subcategory,[Year],[Month],MonthNumber,OrderQty,Price,PreviousOrderQty,PreviousPrice) AS (
	SELECT Subcategory,[Year],[Month],MonthNumber,OrderQty,Price,
		   LAG(OrderQty,1) OVER(PARTITION BY Subcategory ORDER BY MonthNumber),
		   LAG(Price,1) OVER(PARTITION BY Subcategory ORDER BY MonthNumber)
	FROM ExtendedOrderQtyTable
),
ElasticityTable(Subcategory,[Year],[Month],MonthNumber,Elasticity) AS (
	SELECT Subcategory,[Year],[Month],MonthNumber,
		   (OrderQty - PreviousOrderQty)*(Price + PreviousPrice)/NULLIF((Price - PreviousPrice)*(OrderQty + PreviousOrderQty),0)
	FROM LagOrderQtyTable
)
SELECT *
FROM ElasticityTable