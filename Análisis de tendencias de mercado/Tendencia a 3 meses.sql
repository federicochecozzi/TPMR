WITH OrderQtyPerMonth([Year],[Month],MonthNumber,Subcat,OrderQty) AS(
	SELECT DISTINCT dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey,
	ROW_NUMBER() OVER(PARTITION BY dp.ProductSubcategoryKey ORDER BY dd.CalendarYear, dd.MonthNumberOfYear) AS MonthNumber,
	SUM(fis.OrderQuantity) OVER(PARTITION BY dp.ProductSubcategoryKey ORDER BY dd.CalendarYear, dd.MonthNumberOfYear) AS OrderQty
	FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
		AdventureWorksDW2019.dbo.DimProduct dp, 
		AdventureWorksDW2019.dbo.DimProductSubcategory dps,
		AdventureWorksDW2019.dbo.DimDate dd 
	WHERE fis.ProductKey = dp.ProductKey AND 
		dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
		fis.OrderDateKey = dd.DateKey 
	--GROUP BY dd.CalendarYear, dd.MonthNumberOfYear, dp.ProductSubcategoryKey
)
SELECT *	
FROM OrderQtyPerMonth
ORDER BY Subcat,[Year],[Month]

SELECT dd.CalendarYear, dd.MonthNumberOfYear, fis.OrderDate, dp.ProductSubcategoryKey,
REGR_SLOPE(fis.OrderQuantity,dd.MonthNumberOfYear) OVER(PARTITION dp.ProductSubcategoryKey ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ThreeMonthTrendOrderQty 
FROM AdventureWorksDW2019.dbo.FactInternetSales fis, 
	AdventureWorksDW2019.dbo.DimProduct dp, 
	AdventureWorksDW2019.dbo.DimProductSubcategory dps, 
	AdventureWorksDW2019.dbo.DimProductCategory dpc,
	AdventureWorksDW2019.dbo.DimDate dd 
WHERE fis.ProductKey = dp.ProductKey AND 
dp.ProductSubcategoryKey = dps.ProductSubcategoryKey AND 
dps.ProductCategoryKey = dpc.ProductCategoryKey AND 
fis.OrderDateKey = dd.DateKey 

