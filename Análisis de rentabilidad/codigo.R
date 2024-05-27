library(odbc)

setwd("C:/Users/malen/Dropbox/MAESTRIA_CDD/MRCD/TPMR/Análisis de rentabilidad")

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "157.92.26.17,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")

query1 <- 'select top 5 s.productkey,s.salesterritorykey,s.salesamount, s.standardproductcost,s.totalproductcost, s.salesamount - s.totalproductcost as totalincome  
            from FactInternetSales s'
query2 <- 'select top 5 s.*, p.standardcost, p.listprice from FactResellerSales s 
          left join DimProduct p
          on s.productkey = p.productkey
          where s.discountamount <> 0 and
          s.productkey = 346
          order by orderdatekey'

query3 <- 'select top 5 * from DimDate'

prueba2 <- dbGetQuery(conn = on,query2)
prueba3 <- dbGetQuery(conn = on,query3)

### Márgenes de rentabilidad mensual

q_total_ganancia_mes <- "
                      
                      with ventas_online(OrderDateKey,CalendarYear,SpanishMonthName,MonthNumberofYear,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal)
                      as
                      (select OrderDateKey,CalendarYear,SpanishMonthName,MonthNumberofYear,salesamount,OrderQuantity,totalProductCost,
                      'online (minorista)' as canal,
                      cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                      
                      from FactResellerSales s
                      left join DimDate d
                      on s.orderDateKey = d.DateKey),
                      
                      ventas_reseller(OrderDateKey,CalendarYear,SpanishMonthName,MonthNumberofYear,salesamount,OrderQuantity,totalProductCost,
                                            canal, gananciaTotal)
                      as
                      (select OrderDateKey,CalendarYear,SpanishMonthName,MonthNumberofYear,salesamount,OrderQuantity,totalProductCost,
                      'reseller (mayorista)' as canal,
                      cast(salesamount as float) - cast(totalProductCost as float) as gananciaTotal
                       
                      from FactResellerSales s
                      left join DimDate d
                      on s.orderDateKey = d.DateKey)
                      
                      select CalendarYear as anio,
                              SpanishMonthName as mes,
                              MonthNumberofYear as mes_num,
                              left(OrderDateKey,6) as anio_mes,
                              sum(cast(salesAmount as float)) as ingreso_ventas_total,
                              sum(gananciaTotal) as ganancia_total,
                              sum(orderQuantity) as unidades_vendidas,
                              round(100 * sum(gananciaTotal)/sum(cast(totalProductCost as float)),1) as margenGananciaPc 
                      from (select * from ventas_online
                            union all
                            select * from ventas_reseller
                            ) as c 
                      group by CalendarYear,SpanishMonthName,MonthNumberofYear,left(OrderDateKey,6)
                      order by CalendarYear,MonthNumberofYear
                      "
                      
UNPIVOT  
(Orders FOR Employee IN   
  (Emp1, Emp2, Emp3, Emp4, Emp5) 


total_ganancia_mes <- dbGetQuery(conn = on,q_total_ganancia_mes)


# Grafico 

library(ggplot2)

graf_mes <- ggplot(data = total_ganancia_mes,aes(x = anio_mes, group = 1)) + 
            geom_line(aes(y = ingreso_ventas_total/1000000), color = "darkred") + 
            geom_line(aes(y = ganancia_total/1000000), color="steelblue") +
            theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1)) +
            scale_colour_manual("", 
                      breaks = c("ingreso_ventas_total", "ganancia_total"),
                      values = c("darkred", "steelblue"),
                      guide = 'legend') +
            xlab("periodo (año - mes") +
            ylab("Millones de US$")
  
  

graf_mes
                      

