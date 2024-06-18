library(odbc)
library(DBI)
library(gridExtra)
library(tidyverse)

#sort(unique(odbcListDrivers()[[1]]))

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")

querytotal <- 
  "WITH FactSales(ProductID,OrderDateKey,OrderQty) AS (
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
	SELECT c.Subcat,CAST((YEAR([Date])*100+MONTH([Date])) AS CHAR),YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,YearMonth,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.YearMonth,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SELECT dpc.SpanishProductCategoryName, dps.SpanishProductSubcategoryName, 
	   eoqpm.YearMonth, eoqpm.[Year],eoqpm.[Month],eoqpm.MonthNumber,eoqpm.OrderQty
FROM ExtendedOrderQtyPerMonth eoqpm, AdventureWorksDW2019.dbo.DimProductSubcategory dps, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey "

df_total <- dbGetQuery(on,querytotal) %>% 
  mutate(SpanishProductCategoryName = as.factor(SpanishProductCategoryName),
         SpanishProductSubcategoryName = as.factor(SpanishProductSubcategoryName))


# df %>% ggplot(aes(x = YearMonth)) +
#   geom_line(aes(y = OrderQty, color = SpanishProductSubcategoryName, group = SpanishProductSubcategoryName)) +
#   facet_wrap(vars(SpanishProductCategoryName),ncol=2)+
#   theme(axis.text.x = element_text(angle = 90,
#                                    vjust = 0.5,
#                                    hjust = 1,
#                                    margin = margin(t = -50)),
#         legend.position = 'bottom',
#         legend.title = element_blank(),
#         panel.background = element_blank(),
#         panel.grid.major = element_line(size = 0.25, linetype = 'solid',
#                                         colour = "gray"), 
#         panel.grid.minor = element_blank()) + 
#   xlab("Periodo (Año - Mes)") +
#   ylab("Cantidad Ordenada")

#https://stackoverflow.com/questions/14840542/place-a-legend-for-each-facet-wrap-grid-in-ggplot2

#Genero una paleta por cada categoría para obtener colores más distintivos
#https://stackoverflow.com/questions/19068432/ggplot2-how-to-use-same-colors-in-different-plots-for-same-factor
csc <- unique(df_total %>% select(SpanishProductCategoryName,SpanishProductSubcategoryName))
sc1 <- csc %>% filter(SpanishProductCategoryName == "Accesorio") %>% select(SpanishProductSubcategoryName)
sc2 <- csc %>% filter(SpanishProductCategoryName == "Bicicleta") %>% select(SpanishProductSubcategoryName)
sc3 <- csc %>% filter(SpanishProductCategoryName == "Prenda") %>% select(SpanishProductSubcategoryName)
sc4 <- csc %>% filter(SpanishProductCategoryName == "Componente") %>% select(SpanishProductSubcategoryName)
sc.col1 <- hue_pal()(nrow(sc1))
sc.col2 <- hue_pal()(nrow(sc2))
sc.col3 <- hue_pal()(nrow(sc3))
sc.col4 <- hue_pal()(nrow(sc4))
sc.col <- c(sc.col1,sc.col2,sc.col3,sc.col4)
sc<-bind_rows(sc1,sc2,sc3,sc4)
names(sc.col) <- sc$SpanishProductSubcategoryName

ds_total <- split(df_total,f=df_total$SpanishProductCategoryName)
p1 <- ggplot(ds_total$Accesorio,aes(x = YearMonth)) + 
  geom_line(aes(y = OrderQty, color = SpanishProductSubcategoryName, group = SpanishProductSubcategoryName),
            linewidth = 1.1) + 
  facet_wrap(vars(SpanishProductCategoryName), ncol=1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'right',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("Periodo (Año - Mes)") +
  ylab("Cantidad Ordenada") +
  scale_color_manual("Subcategoría", values = sc.col)

p2 <- p1 %+% ds_total$Bicicleta
p3 <- p1 %+% ds_total$Prenda
p4 <- p1 %+% ds_total$Componente

graph_total <- grid.arrange(p1,p2,p3,p4, ncol = 1)
graph_total

png(filename = "Cantidad ordenada total.png",width = 600, height = 1000, units = "px")
grid.arrange(p1,p2,p3,p4, ncol = 1)
dev.off()

queryinternet <- 
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
	WHERE YEAR([Date]) < (SELECT YEAR(NewestDate)
						  FROM MinMaxDate)	
		  OR MONTH([Date]) < (SELECT MONTH(NewestDate)
						  FROM MinMaxDate)		
),
FactorTable(Subcat,YearMonth,[Year],[Month],MonthNumber) AS (
	SELECT c.Subcat,CAST((YEAR([Date])*100+MONTH([Date])) AS CHAR),YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,YearMonth,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.YearMonth,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SELECT dpc.SpanishProductCategoryName, dps.SpanishProductSubcategoryName, 
	   eoqpm.YearMonth, eoqpm.[Year],eoqpm.[Month],eoqpm.MonthNumber,eoqpm.OrderQty
FROM ExtendedOrderQtyPerMonth eoqpm, AdventureWorksDW2019.dbo.DimProductSubcategory dps, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey "

df_internet <- dbGetQuery(on,queryinternet) %>% 
  mutate(SpanishProductCategoryName = as.factor(SpanishProductCategoryName),
         SpanishProductSubcategoryName = as.factor(SpanishProductSubcategoryName))

ds_internet <- split(df_internet,f=df_internet$SpanishProductCategoryName)
p1 <- ggplot(ds_internet$Accesorio,aes(x = YearMonth)) + 
  geom_line(aes(y = OrderQty, color = SpanishProductSubcategoryName, group = SpanishProductSubcategoryName),
            linewidth = 1.1) + 
  facet_wrap(vars(SpanishProductCategoryName), ncol=1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'right',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("Periodo (Año - Mes)") +
  ylab("Cantidad Ordenada") +
  scale_color_manual("Subcategoría", values = sc.col)

p2 <- p1 %+% ds_internet$Bicicleta
p3 <- p1 %+% ds_internet$Prenda

graph_internet <- grid.arrange(p1,p2,p3, ncol = 1)
graph_internet

png(filename = "Cantidad ordenada internet.png",width = 600, height = 750, units = "px")
grid.arrange(p1,p2,p3, ncol = 1)
dev.off()

queryreseller <- 
  "WITH OrderQtyPerMonth([Year],[Month],Subcat,OrderQty) AS(
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
	SELECT c.Subcat,CAST((YEAR([Date])*100+MONTH([Date])) AS CHAR),YEAR([Date]),MONTH([Date]),
	   	   ROW_NUMBER() OVER(PARTITION BY c.Subcat ORDER BY YEAR([Date]),MONTH([Date])) 
	FROM DateRange CROSS JOIN (SELECT DISTINCT Subcat FROM OrderQtyPerMonth) AS c
),
ExtendedOrderQtyPerMonth(Subcat,YearMonth,[Year],[Month],MonthNumber,OrderQty) AS (
	SELECT ft.Subcat,ft.YearMonth,ft.[Year],ft.[Month], ft.MonthNumber, ISNULL(oqpm.OrderQty,0) AS OrderQty
	FROM FactorTable ft LEFT JOIN OrderQtyPerMonth oqpm ON 
	ft.Subcat = oqpm.Subcat AND ft.[Year] = oqpm.[Year] AND ft.[Month] = oqpm.[Month] 
)
SELECT dpc.SpanishProductCategoryName, dps.SpanishProductSubcategoryName, 
	   eoqpm.YearMonth, eoqpm.[Year],eoqpm.[Month],eoqpm.MonthNumber,eoqpm.OrderQty
FROM ExtendedOrderQtyPerMonth eoqpm, AdventureWorksDW2019.dbo.DimProductSubcategory dps, AdventureWorksDW2019.dbo.DimProductCategory dpc 
WHERE eoqpm.Subcat = dps.ProductSubcategoryKey AND dps.ProductCategoryKey = dpc.ProductCategoryKey "

df_reseller <- dbGetQuery(on,queryreseller) %>% 
  mutate(SpanishProductCategoryName = as.factor(SpanishProductCategoryName),
         SpanishProductSubcategoryName = as.factor(SpanishProductSubcategoryName))


ds_reseller <- split(df_reseller,f=df_reseller$SpanishProductCategoryName)
p1 <- ggplot(ds_reseller$Accesorio,aes(x = YearMonth)) + 
  geom_line(aes(y = OrderQty, color = SpanishProductSubcategoryName, group = SpanishProductSubcategoryName),
            linewidth = 1.1) + 
  facet_wrap(vars(SpanishProductCategoryName), ncol=1) +
  theme(axis.text.x = element_text(angle = 90,
                                   vjust = 0.5,
                                   hjust = 1,
                                   margin = margin(t = -50)),
        legend.position = 'right',
        legend.title = element_blank(),
        panel.background = element_blank(),
        panel.grid.major = element_line(size = 0.25, linetype = 'solid',
                                        colour = "gray"), 
        panel.grid.minor = element_blank()) + 
  xlab("Periodo (Año - Mes)") +
  ylab("Cantidad Ordenada") +
  scale_color_manual("Subcategoría", values = sc.col)

p2 <- p1 %+% ds_reseller$Bicicleta
p3 <- p1 %+% ds_reseller$Prenda
p4 <- p1 %+% ds_reseller$Componente

graph_reseller <- grid.arrange(p1,p2,p3,p4, ncol = 1)
graph_reseller

png(filename = "Cantidad ordenada reventa.png",width = 600, height = 1000, units = "px")
grid.arrange(p1,p2,p3,p4, ncol = 1)
dev.off()