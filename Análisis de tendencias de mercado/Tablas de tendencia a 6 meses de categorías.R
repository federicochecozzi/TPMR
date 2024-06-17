library(odbc)
library(DBI)
library(gt)

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")

queryinternet <-
  "WITH FactSales(Category,OrderDateKey,OrderQty) AS (
	SELECT dps.ProductCategoryKey,fis.OrderDateKey, fis.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE fis.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Category,[Year],[Month],OrderQty) AS(
	SELECT fs.Category,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY Category,dd.CalendarYear, dd.MonthNumberOfYear
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
FactorTable(Category,[Year],[Month],MonthNumber) AS (
	SELECT c.Category,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Category ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Category FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(Category,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Category,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.Category = oqpm.Category AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
SumOrderQtyTable(Category,[Year],[Month],MonthNumber,OrderQty,sumx,sumy,sumxx,sumxy) AS (
	SELECT Category,[Year],[Month],MonthNumber,OrderQty, 
		   SUM(MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(MonthNumber*MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty*MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
	FROM ExtendedOrderQtyTable
),
SixMonthTrendOrderQty(Category,[Year],[Month],MonthNumber,OrderQty,Trend) AS (
	SELECT Category,[Year],[Month],MonthNumber,OrderQty,(6*sumxy-sumx*sumy)/(6.0*sumxx-sumx*sumx)
	FROM SumOrderQtyTable
)
SELECT t.Category, dp.SpanishProductCategoryName AS [Español], dp.EnglishProductCategoryName AS [Inglés], 
t.Trend AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE t.Category = dpc.ProductCategoryKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_internet <- dbGetQuery(on,queryinternet) 

table_internet <- df_internet %>% 
  gt(rowname_col = "Category") %>%  
  tab_stubhead(label = "ProductCategoryID") %>%
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "Categorías con mayor tasa de crecimiento, vendidos por internet"
  ) %>%
  tab_spanner(
    label = "Nombre Categoría",
    columns = c("Español","Inglés")
  )

table_internet

queryreseller <-
  "WITH FactSales(Category,OrderDateKey,OrderQty) AS (
	SELECT dps.ProductCategoryKey,frs.OrderDateKey, frs.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE frs.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Category,[Year],[Month],OrderQty) AS(
	SELECT fs.Category,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY Category,dd.CalendarYear, dd.MonthNumberOfYear
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
FactorTable(Category,[Year],[Month],MonthNumber) AS (
	SELECT c.Category,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Category ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Category FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(Category,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Category,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.Category = oqpm.Category AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
SumOrderQtyTable(Category,[Year],[Month],MonthNumber,OrderQty,sumx,sumy,sumxx,sumxy) AS (
	SELECT Category,[Year],[Month],MonthNumber,OrderQty, 
		   SUM(MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(MonthNumber*MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty*MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
	FROM ExtendedOrderQtyTable
),
SixMonthTrendOrderQty(Category,[Year],[Month],MonthNumber,OrderQty,Trend) AS (
	SELECT Category,[Year],[Month],MonthNumber,OrderQty,(6*sumxy-sumx*sumy)/(6.0*sumxx-sumx*sumx)
	FROM SumOrderQtyTable
)
SELECT t.Category, dp.SpanishProductCategoryName AS [Español], dp.EnglishProductCategoryName AS [Inglés], 
t.Trend AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE t.Category = dpc.ProductCategoryKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_reseller <- dbGetQuery(on,queryreseller) 

table_reseller <- df_reseller %>% 
  gt(rowname_col = "Category") %>%  
  tab_stubhead(label = "ProductCategoryID") %>%
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "Categorías con mayor tasa de crecimiento, reventa"
  ) %>%
  tab_spanner(
    label = "Nombre Categoría",
    columns = c("Español","Inglés")
  )

table_reseller

querytotal <-
  "WITH FactSales(Category,OrderDateKey,OrderQty) AS (
  SELECT dps.ProductCategoryKey,fis.OrderDateKey, fis.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE fis.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
  UNION ALL
	SELECT dps.ProductCategoryKey,frs.OrderDateKey, frs.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps
	WHERE frs.ProductKey = dp.ProductKey AND dp.ProductSubcategoryKey = dps.ProductSubcategoryKey
),
OrderQtyTable(Category,[Year],[Month],OrderQty) AS(
	SELECT fs.Category,dd.CalendarYear, dd.MonthNumberOfYear, SUM(fs.OrderQty) AS OrderQty
	FROM FactSales fs, AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fs.OrderDateKey = dd.DateKey  
	GROUP BY Category,dd.CalendarYear, dd.MonthNumberOfYear
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
FactorTable(Category,[Year],[Month],MonthNumber) AS (
	SELECT c.Category,YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Category ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Category FROM OrderQtyTable) AS c
),
ExtendedOrderQtyTable(Category,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Category,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyTable oqpm ON 
	ft.Category = oqpm.Category AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
),
SumOrderQtyTable(Category,[Year],[Month],MonthNumber,OrderQty,sumx,sumy,sumxx,sumxy) AS (
	SELECT Category,[Year],[Month],MonthNumber,OrderQty, 
		   SUM(MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(MonthNumber*MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW),
		   SUM(OrderQty*MonthNumber) OVER(PARTITION BY Category ORDER BY MonthNumber ROWS BETWEEN 5 PRECEDING AND CURRENT ROW)
	FROM ExtendedOrderQtyTable
),
SixMonthTrendOrderQty(Category,[Year],[Month],MonthNumber,OrderQty,Trend) AS (
	SELECT Category,[Year],[Month],MonthNumber,OrderQty,(6*sumxy-sumx*sumy)/(6.0*sumxx-sumx*sumx)
	FROM SumOrderQtyTable
)
SELECT t.Category, dp.SpanishProductCategoryName AS [Español], dp.EnglishProductCategoryName AS [Inglés], 
t.Trend AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE t.Category = dpc.ProductCategoryKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_total <- dbGetQuery(on,querytotal) 

table_total <- df_total %>% 
  gt(rowname_col = "Category") %>%  
  tab_stubhead(label = "ProductCategoryID") %>%
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "Categorías con mayor tasa de crecimiento, ambos canales"
  ) %>%
  tab_spanner(
    label = "Nombre Categoría",
    columns = c("Español","Inglés")
  )

table_total