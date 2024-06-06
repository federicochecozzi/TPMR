library(odbc)
library(DBI)
library(tidyverse)

sort(unique(odbcListDrivers()[[1]]))

on <- dbConnect(odbc(),
                Driver = "SQL Server",
                Server = "localhost,1443;",
                Database = "AdventureWorksDW2019",
                uid = "Alumno",
                pwd = "mrcd2023")