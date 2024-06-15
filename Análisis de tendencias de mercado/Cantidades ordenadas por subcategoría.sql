--Por internet
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
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)		
),
FactorTable(Subcat,YearMonth,[Year],[Month],MonthNumber) AS (
	SELECT c.Subcat,YEAR([Date])*100+MONTH([Date]),YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,YearMonth,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.YearMonth,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SELECT dpc.EnglishProductCategoryName, dps.EnglishProductSubcategoryName, 
	   eoqpm.YearMonth, eoqpm.[Year],eoqpm.[Month],eoqpm.MonthNumber,eoqpm.OrderQty
FROM ExtendedOrderQtyPerMonth eoqpm, AdventureWorksDW2019.dbo.DimProductSubcategory dps, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey 

--Reventa
WITH OrderQtyPerMonth([Year],[Month],Subcat,OrderQty) AS(
	SELECT dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey,
	SUM(frs.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimProductSubcategory dps,
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE frs.ProductKey = dp.ProductKey AND 
		dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		frs.OrderDateKey = dd.DateKey 
	GROUP BY dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey
),
MinMaxDate(OldestDate,NewestDate) AS (
	SELECT MIN(frs.OrderDate), MAX(frs.OrderDate)
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
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
FactorTable(Subcat,YearMonth,[Year],[Month],MonthNumber) AS (
	SELECT c.Subcat,YEAR([Date])*100+MONTH([Date]),YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,YearMonth,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.YearMonth,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SELECT dpc.EnglishProductCategoryName, dps.EnglishProductSubcategoryName, 
	   eoqpm.YearMonth, eoqpm.[Year],eoqpm.[Month],eoqpm.MonthNumber,eoqpm.OrderQty
FROM ExtendedOrderQtyPerMonth eoqpm, AdventureWorksDW2019.dbo.DimProductSubcategory dps, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey 

--Total
WITH FactSales(ProductID,OrderDateKey,OrderQty) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
	UNION ALL
	SELECT frs.ProductKey,frs.OrderDateKey, frs.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs
),
OrderQtyPerMonth([Year],[Month],Subcat,OrderQty) AS(
	SELECT dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey,
	SUM(fs.OrderQty) AS OrderQty
	FROM FactSales fs, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimProductSubcategory dps,
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.ProductID = dp.ProductKey AND 
		dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		fs.OrderDateKey = dd.DateKey 
	GROUP BY dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey
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
FactorTable(Subcat,YearMonth,[Year],[Month],MonthNumber) AS (
	SELECT c.Subcat,YEAR([Date])*100+MONTH([Date]),YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,YearMonth,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.YearMonth,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SELECT dpc.EnglishProductCategoryName, dps.EnglishProductSubcategoryName, 
	   eoqpm.YearMonth, eoqpm.[Year],eoqpm.[Month],eoqpm.MonthNumber,eoqpm.OrderQty
FROM ExtendedOrderQtyPerMonth eoqpm, AdventureWorksDW2019.dbo.DimProductSubcategory dps, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey 