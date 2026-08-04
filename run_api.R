library(plumber)

api <- plumb("model_api.R")

api$run(
  host = "0.0.0.0",
  port = 8000
)