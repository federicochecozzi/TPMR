library(odbc)
library(DBI)
library(tidyverse)

sort(unique(odbcListDrivers()[[1]]))

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")

query <- 
 "WITH OrderQtyPerMonth([Year],[Month],Subcat,OrderQty) AS(
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
FactorTable(Subcat,YearMonth,[Year],[Month],MonthNumber) AS (
	SELECT c.Subcat,YEAR([Date])*100+MONTH([Date])/12*100,YEAR([Date]),MONTH([Date]),
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
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey "

df <- dbGetQuery(on,query) %>% 
  mutate(EnglishProductCategoryName = as.factor(EnglishProductCategoryName),
         EnglishProductSubcategoryName = as.factor(EnglishProductSubcategoryName))

df %>% ggplot(aes(x = YearMonth)) +
  geom_line(aes(y = OrderQty, color = EnglishProductSubcategoryName)) +
  facet_wrap(vars(EnglishProductCategoryName),ncol=2)
