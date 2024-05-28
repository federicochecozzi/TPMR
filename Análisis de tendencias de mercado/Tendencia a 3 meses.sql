WITH OrderQtyPerMonth([Year],[Month],Subcat,OrderQty) AS(
	SELECT dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey,
	SUM(fis.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimProductSubcategory dps,
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fis.ProductKey = dp.ProductKey AND 
		dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		fis.OrderDateKey = dd.DateKey 
	GROUP BY dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey
),
MinMaxDate(OldestDate,NewestDate) AS (
	SELECT MIN(fis.OrderDate), MAX(fis.OrderDate)
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
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
FactorTable(Subcat,[Year],[Month],MonthNumber) AS (
	SELECT c.Subcat,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SumsOrderQtyPerMonth(Subcat,[Year],[Month],MonthNumber,sumx,sumy,sumxx,sumxy) AS (
	SELECT DISTINCT 
	FROM 
)
SELECT *
FROM ExtendedOrderQtyPerMonth

--SELECT dd.CalendarYear, dd.MonthNumberOfYear, fis.OrderDate, dp.ProductSubcategoryKey,
--REGR_SLOPE(fis.OrderQuantity,dd.MonthNumberOfYear) OVER(PARTITION dp.ProductSubcategoryKey ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeMonthTrendOrderQty 
--FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
--	AdventureWorksDW2019.dbo.DimProduct dp, 
--	AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
--	AdventureWorksDW2019.dbo.DimProductCategory dpc,
--	AdventureWorksDW2019.dbo.DimDate dd 
--WHERE fis.ProductKey = dp.ProductKey AND 
--dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
--dps.ProductCategoryKey = dpc.ProductCategoryKey AND 
--fis.OrderDateKey = dd.DateKey 

