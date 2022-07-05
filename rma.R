library(affy)
library(arrayQualityMetrics)
library(here)

Sys.setenv(OPENBLAS_NUM_THREADS = 1)

data_dir <- here("data")
data <- ReadAffy(filenames = list.celfiles(data_dir, full.names = TRUE))
normalized <- rma(data)
arrayQualityMetrics(expressionset = normalized, force = TRUE)