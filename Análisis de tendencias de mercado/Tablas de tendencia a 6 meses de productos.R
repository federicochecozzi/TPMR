library(odbc)
library(DBI)
library(tidyverse)
library(gt)

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")

queryinternet <-
"WITH FactSales(ProductID,OrderDateKey,OrderQty) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
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
SELECT TOP(10) dp.SpanishProductName AS [Español], dp.EnglishProductName AS [Inglés], 
ROUND(t.Trend,2) AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE t.ProductID = dp.ProductKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_internet <- dbGetQuery(on,queryinternet) 

table_internet <- df_internet %>% 
  gt() %>%  
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "10 productos con mayor tasa de crecimiento, vendidos por internet"
  ) %>%
  tab_spanner(
    label = "Nombre del producto",
    columns = c("Español","Inglés")
  )

table_internet

gtsave(table_internet,"Tendencia producto internet.png", vwidth = 675, vheight = 2000)

queryreseller <-
  "WITH FactSales(ProductID,OrderDateKey,OrderQty) AS (
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
SELECT TOP(10) dp.SpanishProductName AS [Español], dp.EnglishProductName AS [Inglés], 
ROUND(t.Trend,2) AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE t.ProductID = dp.ProductKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_reseller <- dbGetQuery(on,queryreseller) 

table_reseller <- df_reseller %>%
  gt() %>% 
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "10 productos con mayor tasa de crecimiento, reventa"
  ) %>%
  tab_spanner(
    label = "Nombre del producto",
    columns = c("Español","Inglés")
  )

table_reseller

gtsave(table_reseller,"Tendencia producto reventa.png", vwidth = 675, vheight = 2000)

querytotal <-
  "WITH FactSales(ProductID,OrderDateKey,OrderQty) AS (
	SELECT fis.ProductKey,fis.OrderDateKey, fis.OrderQuantity
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis
	UNION ALL
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
SELECT TOP(10) dp.SpanishProductName AS [Español], dp.EnglishProductName AS [Inglés], 
ROUND(t.Trend,2) AS [β]
FROM SixMonthTrendOrderQty t, AdventureWorksDW2019.dbo.DimProduct dp 
WHERE t.ProductID = dp.ProductKey AND [Year] = 2013 AND [Month] = 11
ORDER BY Trend DESC"

df_total <- dbGetQuery(on,querytotal) 

table_total <- df_total %>%
  gt() %>%
  tab_header(
    title = "Tendencia cantidad ordenada en los últimos 6 meses",
    subtitle = "10 productos con mayor tasa de crecimiento, ambos canales"
  ) %>%
  tab_spanner(
    label = "Nombre del producto",
    columns = c("Español","Inglés")
  )

table_total

gtsave(table_total,"Tendencia producto total.png", vwidth = 675, vheight = 2000)