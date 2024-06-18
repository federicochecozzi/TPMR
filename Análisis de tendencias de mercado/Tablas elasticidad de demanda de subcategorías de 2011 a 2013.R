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
  "WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
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
PivotedElasticityTable(Subcategory,[2010],[2011],[2012],[2013],[2014]) AS (
	SELECT Subcategory,[2010],[2011],[2012],[2013],[2014]
	FROM ElasticityTable AS SourceTable
	PIVOT
	(
		MAX(Elasticity)
		FOR [Year] IN ([2010],[2011],[2012],[2013],[2014])
	) AS PivotTable
)
SELECT dps.SpanishProductSubcategoryName AS [Subcategoría],ROUND(pet.[2011],2) AS [2011], ROUND(pet.[2012],2) AS [2012], 
ROUND(pet.[2013],2) AS [2013]
FROM PivotedElasticityTable pet, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE pet.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory"

df_internet <- dbGetQuery(on,queryinternet) 

table_internet <- df_internet %>% 
  gt() %>% 
  #tab_header(
  #  title = "Elasticidad de demanda de 2011 a 2013",
  #  subtitle = "En base a la demanda mensual de cada subcategoría, vendidos por internet"
  #) %>%
  tab_spanner(
    label = html("E<sub>d</sub>"),
    columns = c("2011","2012","2013")
  ) %>% 
  tab_options(
    column_labels.font.size = px(8),
    column_labels.font.weight = 'bold',
    table.font.size = px(7),
    data_row.padding = px(0),
    table.width = px(400)
  )

table_internet

gtsave(table_internet,"Elasticidad demanda por subcategoría internet.png", vwidth = 675, vheight = 2000)

queryreseller <-
  "WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
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
PivotedElasticityTable(Subcategory,[2010],[2011],[2012],[2013],[2014]) AS (
	SELECT Subcategory,[2010],[2011],[2012],[2013],[2014]
	FROM ElasticityTable AS SourceTable
	PIVOT
	(
		MAX(Elasticity)
		FOR [Year] IN ([2010],[2011],[2012],[2013],[2014])
	) AS PivotTable
)
SELECT dps.SpanishProductSubcategoryName AS [Subcategoría],ROUND(pet.[2011],2) AS [2011], ROUND(pet.[2012],2) AS [2012], 
ROUND(pet.[2013],2) AS [2013]
FROM PivotedElasticityTable pet, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE pet.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory"

df_reseller <- dbGetQuery(on,queryreseller) 

table_reseller <- df_reseller %>% 
  gt() %>% 
  #tab_header(
  #  title = "Elasticidad de demanda de 2011 a 2013",
  #  subtitle = "En base a la demanda mensual de cada subcategoría, reventa"
  #) %>%
  tab_spanner(
    label = html("E<sub>d</sub>"),
    columns = c("2011","2012","2013")
  ) %>% 
  tab_options(
    column_labels.font.size = px(8),
    column_labels.font.weight = 'bold',
    table.font.size = px(7),
    data_row.padding = px(0),
    table.width = px(400)
  )

table_reseller

gtsave(table_reseller,"Elasticidad demanda por subcategoría reventa.png", vwidth = 675, vheight = 2000)

querytotal <-
  "WITH FactSales(Subcategory,OrderDateKey,OrderQty,Price) AS (
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
PivotedElasticityTable(Subcategory,[2010],[2011],[2012],[2013],[2014]) AS (
	SELECT Subcategory,[2010],[2011],[2012],[2013],[2014]
	FROM ElasticityTable AS SourceTable
	PIVOT
	(
		MAX(Elasticity)
		FOR [Year] IN ([2010],[2011],[2012],[2013],[2014])
	) AS PivotTable
)
SELECT dps.SpanishProductSubcategoryName AS [Subcategoría],ROUND(pet.[2011],2) AS [2011], ROUND(pet.[2012],2) AS [2012], 
ROUND(pet.[2013],2) AS [2013]
FROM PivotedElasticityTable pet, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE pet.Subcategory = dps.ProductSubcategoryKey 
ORDER BY Subcategory"

df_total <- dbGetQuery(on,querytotal) 

table_total <- df_total %>% 
  gt() %>% 
  #tab_header(
  #  title = "Elasticidad de demanda de 2011 a 2013",
  #  subtitle = "En base a la demanda mensual de cada subcategoría, ambos canales"
  #) %>%
  tab_spanner(
    label = html("E<sub>d</sub>"),
    columns = c("2011","2012","2013")
  ) %>% 
  tab_options(
    column_labels.font.size = px(8),
    column_labels.font.weight = 'bold',
    table.font.size = px(7),
    data_row.padding = px(0),
    table.width = px(400)
  )

table_total

gtsave(table_total,"Elasticidad demanda por subcategoría total.png", vwidth = 675, vheight = 2000)
