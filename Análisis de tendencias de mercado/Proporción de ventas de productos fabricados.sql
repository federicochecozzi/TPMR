WITH SubcategoriesWithCompetitors(ProductSubcategoryID) AS (--Usado para filtrar subcategorías sin productos comprados
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
		  dd.CalendarYear IN (2012,2013) 
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
PivotedOrderQtyPerYearAndType([Year],Subcat,Percentage) AS(
	SELECT [Year],Subcat,
		   100.0*[NO]/NULLIF([YES]+[NO],0)
	FROM ExtendedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(OrderQty)
		FOR Purchased IN ([YES],[NO])
	) AS PivotTable
),
PivotedOrderQtyPerType(Subcat,Percentage_2012,Percentage_2013) AS (
	SELECT Subcat,[2012],[2013]
	FROM PivotedOrderQtyPerYearAndType AS SourceTable
	PIVOT
	(
		MAX(Percentage)
		FOR [Year] IN ([2012],[2013])
	) AS PivotTable
)
SELECT dps.EnglishProductSubcategoryName,Percentage_2012,Percentage_2013 
FROM PivotedOrderQtyPerType p, AdventureWorksDW2019.dbo.DimProductSubcategory dps 
WHERE p.Subcat = dps.ProductSubcategoryKey