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
		  fis.OrderDateKey = dd.DateKey 
	GROUP BY fis.ProductKey, dd.CalendarYear, dp.ProductSubcategoryKey
	UNION
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
		  fis.OrderDateKey = dd.DateKey  
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
)
SELECT *
FROM ExtendedOrderQtyPerYearAndType
ORDER BY [Year],Subcat