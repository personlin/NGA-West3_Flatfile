`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

suppressPackageStartupMessages({
  stopifnot(requireNamespace("DBI", quietly = TRUE))
  stopifnot(requireNamespace("RSQLite", quietly = TRUE))
})

script_args <- commandArgs(trailingOnly = FALSE)
file_arg <- script_args[grepl("^--file=", script_args)]
script_file <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "shiny-app/tests/test_app_smoke.R"
root <- normalizePath(file.path(dirname(script_file), "..", ".."), mustWork = TRUE)
sqlite <- file.path(root, "output", "sqlite", "nga_west3_20250919.sqlite")
stopifnot(file.exists(sqlite))

source(file.path(root, "shiny-app", "R", "db.R"))
source(file.path(root, "shiny-app", "R", "filters.R"))
source(file.path(root, "shiny-app", "R", "cache.R"))

health <- db_health()
stopifnot(isTRUE(health$ok))

counts <- db_get_query(
  "SELECT 'events' AS table_name, count(*) AS n FROM events
   UNION ALL SELECT 'stations', count(*) FROM stations
   UNION ALL SELECT 'sites', count(*) FROM sites
   UNION ALL SELECT 'motions', count(*) FROM motions"
)
stopifnot(all(counts$n > 0))

input <- list(
  source_class = "crustal",
  event_type = character(),
  event_country = character(),
  site_country = character(),
  network_code = character(),
  network_type = character(),
  magnitude = c(5, 9),
  date_range = as.Date(c("1900-01-01", "2100-01-01")),
  motion_min = 0
)
events <- events_map_query(input, cap = 50)
stations <- stations_map_query(input, cap = 50)
stopifnot(nrow(events) > 0)
stopifnot(nrow(stations) > 0)

message("Shiny app smoke tests passed.")
