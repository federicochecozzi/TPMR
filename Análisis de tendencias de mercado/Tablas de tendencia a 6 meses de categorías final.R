library(odbc)
library(DBI)
library(gt)
library(tidyverse)

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
SELECT dpc.SpanishProductCategoryName AS [Nombre categoría], ROUND(t.Trend,2) AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE t.Category = dpc.ProductCategoryKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_internet <- dbGetQuery(on,queryinternet) 

table_internet <- df_internet %>% 
  gt::gt() %>%  
  gt::tab_header(
    title = "Ventas online"
  ) %>% 
  gt::tab_options(
    column_labels.font.size = gt::px(8),
    column_labels.font.weight = 'bold',
    table.font.size = gt::px(7),
    data_row.padding = gt::px(0),
    table.width = gt::px(190)
  )

table_internet

gt::gtsave(table_internet,"Tendencia categoría internet.png")

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
SELECT dpc.SpanishProductCategoryName AS [Nombre categoría], ROUND(t.Trend,2) AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE t.Category = dpc.ProductCategoryKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_reseller <- dbGetQuery(on,queryreseller) 

table_reseller <- df_reseller %>% 
  gt::gt() %>%  
  gt::tab_header(
    title = "Reventas"
  ) %>% 
  gt::tab_options(
    column_labels.font.size = gt::px(8),
    column_labels.font.weight = 'bold',
    table.font.size = gt::px(7),
    data_row.padding = gt::px(0),
    table.width = gt::px(190)
  )

table_reseller

gt::gtsave(table_reseller,"Tendencia categoría reventa.png")

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
SELECT dpc.SpanishProductCategoryName AS [Nombre categoría], ROUND(t.Trend,2) AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE t.Category = dpc.ProductCategoryKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_total <- dbGetQuery(on,querytotal) 

table_total <- df_total %>% 
  gt() %>%  
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "Categorías con mayor tasa de crecimiento, ambos canales"
  )

table_total

gtsave(table_total,"Tendencia categoría total.png")
