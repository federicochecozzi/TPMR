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
  "WITH SubcategoriesWithCompetitors(ProductSubcategoryID) AS (--Usado para filtrar subcategorías sin productos comprados
	SELECT DISTINCT p.ProductSubcategoryID
	FROM AdventureWorks2019.Purchasing.ProductVendor pv, AdventureWorks2019.Production.Product p 
	WHERE pv.ProductID = p.ProductID AND p.ProductSubcategoryID IS NOT NULL
),
PurchasedProducts(ProductID) AS(--Usado para dividir productos dependiendo en si fueron comprados o fabricados
	SELECT DISTINCT pv.ProductID
	FROM AdventureWorks2019.Purchasing.ProductVendor pv 
),
OrderQtyTable(ProductID,[Year],Subcat,Purchased,OrderQty) AS (--Podría haber usado CASE pero quizás era más lento
	SELECT fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'YES',SUM(fis.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fis.ProductKey = dp.ProductKey AND 
		  fis.ProductKey = pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  fis.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013) --Los últimos dos años completos, ver la consulta de rangos de fechas
	GROUP BY fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
	UNION ALL
	SELECT fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'NO',SUM(fis.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fis.ProductKey = dp.ProductKey AND 
		  fis.ProductKey <> pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  fis.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013)  
	GROUP BY fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
),
OrderQtyPerYearAndType([Year],Subcat,Purchased,OrderQty) AS (
	SELECT [Year],Subcat,Purchased,SUM(OrderQty) AS OrderQty
	FROM OrderQtyTable
	GROUP BY [Year],Subcat,Purchased
),
FactorTable([Year],Subcat,Purchased) AS (
	SELECT y.[Year],s.Subcat,p.Purchased
	FROM (SELECT DISTINCT [Year] FROM OrderQtyPerYearAndType) y CROSS JOIN
		 (SELECT DISTINCT Subcat FROM OrderQtyPerYearAndType) s CROSS JOIN
		 (SELECT DISTINCT Purchased FROM OrderQtyPerYearAndType) p 
),
ExtendedOrderQtyPerYearAndType([Year],Subcat,Purchased,OrderQty) AS (--Aparentemente no era necesario
	SELECT ft.[Year], ft.Subcat, ft.Purchased, ISNULL(oq.OrderQty,0)
	FROM FactorTable ft LEFT JOIN OrderQtyPerYearAndType oq
	ON ft.[Year] = oq.[Year] AND ft.Subcat = oq.Subcat AND ft.Purchased = oq.Purchased 
),
PivotedOrderQtyPerYearAndType([Year],Subcat,Proportion) AS(
	SELECT [Year],Subcat,
		   1.0*[NO]/NULLIF([YES]+[NO],0)
	FROM ExtendedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(OrderQty)
		FOR Purchased IN ([YES],[NO])
	) AS PivotTable
),
PivotedOrderQtyPerType(Subcat,[2012],[2013]) AS (
	SELECT Subcat,[2012],[2013]
	FROM PivotedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(Proportion)
		FOR [Year] IN ([2012],[2013])
	) AS PivotTable
)
SELECT dps.SpanishProductSubcategoryName AS [Subcategoría],FORMAT([2012],'P2') AS [2012],FORMAT([2013],'P2') AS [2013]
FROM PivotedOrderQtyPerType p, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE p.Subcat = dps.ProductSubcategoryKey"

df_internet <- dbGetQuery(on,queryinternet) 

table_internet <- df_internet %>% 
  gt() %>%  
  tab_header(
    title = "Porcentaje de ventas de productos fabricados",
    subtitle = "En aquellas subcategorías donde Adventure Works vende productos de la competencia, internet"
  ) 

table_internet

gtsave(table_internet,"Proporción de ventas de productos fabricados internet.png", vwidth = 675, vheight = 2000)

queryreseller <-
  "WITH SubcategoriesWithCompetitors(ProductSubcategoryID) AS (--Usado para filtrar subcategorías sin productos comprados
	SELECT DISTINCT p.ProductSubcategoryID
	FROM AdventureWorks2019.Purchasing.ProductVendor pv, AdventureWorks2019.Production.Product p 
	WHERE pv.ProductID = p.ProductID AND p.ProductSubcategoryID IS NOT NULL
),
PurchasedProducts(ProductID) AS(--Usado para dividir productos dependiendo en si fueron comprados o fabricados
	SELECT DISTINCT pv.ProductID
	FROM AdventureWorks2019.Purchasing.ProductVendor pv 
),
OrderQtyTable(ProductID,[Year],Subcat,Purchased,OrderQty) AS (--Podría haber usado CASE pero quizás era más lento
	SELECT frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'YES',SUM(frs.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE frs.ProductKey = dp.ProductKey AND 
		  frs.ProductKey = pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  frs.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013) --Los últimos dos años completos, ver la consulta de rangos de fechas
	GROUP BY frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
	UNION ALL
	SELECT frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'NO',SUM(frs.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE frs.ProductKey = dp.ProductKey AND 
		  frs.ProductKey <> pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  frs.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013)  
	GROUP BY frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
),
OrderQtyPerYearAndType([Year],Subcat,Purchased,OrderQty) AS (
	SELECT [Year],Subcat,Purchased,SUM(OrderQty) AS OrderQty
	FROM OrderQtyTable
	GROUP BY [Year],Subcat,Purchased
),
FactorTable([Year],Subcat,Purchased) AS (
	SELECT y.[Year],s.Subcat,p.Purchased
	FROM (SELECT DISTINCT [Year] FROM OrderQtyPerYearAndType) y CROSS JOIN
		 (SELECT DISTINCT Subcat FROM OrderQtyPerYearAndType) s CROSS JOIN
		 (SELECT DISTINCT Purchased FROM OrderQtyPerYearAndType) p 
),
ExtendedOrderQtyPerYearAndType([Year],Subcat,Purchased,OrderQty) AS (--Aparentemente no era necesario
	SELECT ft.[Year], ft.Subcat, ft.Purchased, ISNULL(oq.OrderQty,0)
	FROM FactorTable ft LEFT JOIN OrderQtyPerYearAndType oq
	ON ft.[Year] = oq.[Year] AND ft.Subcat = oq.Subcat AND ft.Purchased = oq.Purchased 
),
PivotedOrderQtyPerYearAndType([Year],Subcat,Proportion) AS(
	SELECT [Year],Subcat,
		   1.0*[NO]/NULLIF([YES]+[NO],0)
	FROM ExtendedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(OrderQty)
		FOR Purchased IN ([YES],[NO])
	) AS PivotTable
),
PivotedOrderQtyPerType(Subcat,[2012],[2013]) AS (
	SELECT Subcat,[2012],[2013]
	FROM PivotedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(Proportion)
		FOR [Year] IN ([2012],[2013])
	) AS PivotTable
)
SELECT dps.SpanishProductSubcategoryName AS [Subcategoría],FORMAT([2012],'P2') AS [2012],FORMAT([2013],'P2') AS [2013]
FROM PivotedOrderQtyPerType p, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE p.Subcat = dps.ProductSubcategoryKey"

df_reseller <- dbGetQuery(on,queryreseller) 

table_reseller <- df_reseller %>% 
  gt() %>%  
  tab_header(
    title = "Porcentaje de ventas de productos fabricados",
    subtitle = "En aquellas subcategorías donde Adventure Works vende productos de la competencia, reventa"
  ) 

table_reseller

gtsave(table_reseller,"Proporción de ventas de productos fabricados reventa.png", vwidth = 675, vheight = 2000)

querytotal <-
  "WITH SubcategoriesWithCompetitors(ProductSubcategoryID) AS (--Usado para filtrar subcategorías sin productos comprados
	SELECT DISTINCT p.ProductSubcategoryID
	FROM AdventureWorks2019.Purchasing.ProductVendor pv, AdventureWorks2019.Production.Product p 
	WHERE pv.ProductID = p.ProductID AND p.ProductSubcategoryID IS NOT NULL
),
PurchasedProducts(ProductID) AS(--Usado para dividir productos dependiendo en si fueron comprados o fabricados
	SELECT DISTINCT pv.ProductID
	FROM AdventureWorks2019.Purchasing.ProductVendor pv 
),
OrderQtyTable(ProductID,[Year],Subcat,Purchased,OrderQty) AS (--Podría haber usado CASE pero quizás era más lento
	SELECT fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'YES',SUM(fis.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fis.ProductKey = dp.ProductKey AND 
		  fis.ProductKey = pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  fis.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013) --Los últimos dos años completos, ver la consulta de rangos de fechas
	GROUP BY fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
	UNION ALL
	SELECT fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'NO',SUM(fis.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fis.ProductKey = dp.ProductKey AND 
		  fis.ProductKey <> pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  fis.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013)  
	GROUP BY fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
	UNION ALL
	SELECT frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'YES',SUM(frs.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE frs.ProductKey = dp.ProductKey AND 
		  frs.ProductKey = pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  frs.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013) --Los últimos dos años completos, ver la consulta de rangos de fechas
	GROUP BY frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
	UNION ALL
	SELECT frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey,
	'NO',SUM(frs.OrderQuantity) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactResellerSales frs, 
		 AdventureWorksDW2019.dbo.DimProduct dp, 
		 AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
		 PurchasedProducts pp,
		 SubcategoriesWithCompetitors swc,
		 AdventureWorksDW2019.dbo.DimDate dd 
	WHERE frs.ProductKey = dp.ProductKey AND 
		  frs.ProductKey <> pp.ProductID AND
		  dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		  dp.ProductSubcategoryKey = swc.ProductSubcategoryID AND
		  frs.OrderDateKey = dd.DateKey AND
		  dd.CalendarYear IN (2012,2013)  
	GROUP BY frs.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
),
OrderQtyPerYearAndType([Year],Subcat,Purchased,OrderQty) AS (
	SELECT [Year],Subcat,Purchased,SUM(OrderQty) AS OrderQty
	FROM OrderQtyTable
	GROUP BY [Year],Subcat,Purchased
),
FactorTable([Year],Subcat,Purchased) AS (
	SELECT y.[Year],s.Subcat,p.Purchased
	FROM (SELECT DISTINCT [Year] FROM OrderQtyPerYearAndType) y CROSS JOIN
		 (SELECT DISTINCT Subcat FROM OrderQtyPerYearAndType) s CROSS JOIN
		 (SELECT DISTINCT Purchased FROM OrderQtyPerYearAndType) p 
),
ExtendedOrderQtyPerYearAndType([Year],Subcat,Purchased,OrderQty) AS (--Aparentemente no era necesario
	SELECT ft.[Year], ft.Subcat, ft.Purchased, ISNULL(oq.OrderQty,0)
	FROM FactorTable ft LEFT JOIN OrderQtyPerYearAndType oq
	ON ft.[Year] = oq.[Year] AND ft.Subcat = oq.Subcat AND ft.Purchased = oq.Purchased 
),
PivotedOrderQtyPerYearAndType([Year],Subcat,Proportion) AS(
	SELECT [Year],Subcat,
		   1.0*[NO]/NULLIF([YES]+[NO],0)
	FROM ExtendedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(OrderQty)
		FOR Purchased IN ([YES],[NO])
	) AS PivotTable
),
PivotedOrderQtyPerType(Subcat,[2012],[2013]) AS (
	SELECT Subcat,[2012],[2013]
	FROM PivotedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(Proportion)
		FOR [Year] IN ([2012],[2013])
	) AS PivotTable
)
SELECT dps.SpanishProductSubcategoryName AS [Subcategoría],FORMAT([2012],'P2') AS [2012],FORMAT([2013],'P2') AS [2013]
FROM PivotedOrderQtyPerType p, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE p.Subcat = dps.ProductSubcategoryKey"

df_total <- dbGetQuery(on,querytotal) 

table_total <- df_total %>% 
  gt::gt() %>%  
  gt::tab_options(
    column_labels.font.size = gt::px(8),
    column_labels.font.weight = 'bold',
    table.font.size = gt::px(7),
    data_row.padding = gt::px(0),
    table.width = gt::px(400)
  )


gt::gtsave(table_total,"Proporción de ventas de productos fabricados  total.png")
