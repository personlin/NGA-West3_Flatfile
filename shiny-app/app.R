suppressPackageStartupMessages({
  library(shiny)
  library(bslib)
})

`%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x

script_file <- tryCatch(sys.frame(1)$ofile, error = function(e) NA_character_)
if (is.null(script_file) || is.na(script_file) || !nzchar(script_file)) {
  script_args <- commandArgs(trailingOnly = FALSE)
  file_arg <- script_args[grepl("^--file=", script_args)]
  script_file <- if (length(file_arg)) {
    sub("^--file=", "", file_arg[[1]])
  } else if (file.exists("app.R") && dir.exists("R")) {
    "app.R"
  } else {
    "shiny-app/app.R"
  }
}
app_dir <- normalizePath(dirname(script_file), mustWork = FALSE)
if (!dir.exists(app_dir)) {
  app_dir <- normalizePath("shiny-app", mustWork = TRUE)
}

source_app <- function(file) {
  source(file.path(app_dir, "R", file), local = parent.frame())
}

source_app("db.R")
source_app("filters.R")
source_app("cache.R")
source_app("module_overview.R")
source_app("module_map.R")
source_app("module_tables.R")
source_app("module_stats.R")
source_app("module_analysis.R")
source_app("module_about.R")

required_packages <- c("DBI", "RSQLite")
optional_packages <- c("DT", "leaflet", "ggplot2", "thematic")
missing_required <- required_packages[!vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)]

if (requireNamespace("thematic", quietly = TRUE)) {
  thematic::thematic_shiny()
}

app_theme <- bs_theme(
  version = 5,
  bootswatch = "flatly",
  primary = "#246a73",
  secondary = "#6b7280",
  success = "#2f855a",
  info = "#2563eb",
  base_font = font_google("Source Sans 3")
)

missing_package_ui <- function() {
  page_fluid(
    theme = app_theme,
    tags$h1("NGA-West3 Explorer"),
    tags$p("The Shiny app needs these R packages before it can start:"),
    tags$pre(paste(missing_required, collapse = "\n")),
    tags$p("Install them in the R environment used to run this app, then restart Shiny.")
  )
}

ui <- if (length(missing_required)) {
  missing_package_ui()
} else {
  page_navbar(
    title = "NGA-West3 Explorer",
    theme = app_theme,
    nav_panel("Overview", overview_ui("overview")),
    nav_panel("Map", map_ui("map")),
    nav_panel("Tables", tables_ui("tables")),
    nav_panel("Statistics", stats_ui("stats")),
    nav_panel("Analysis", analysis_ui("analysis")),
    nav_panel("About", about_ui("about")),
    header = tags$head(tags$link(rel = "stylesheet", href = "app.css"))
  )
}

server <- function(input, output, session) {
  if (length(missing_required)) {
    return(invisible(NULL))
  }

  db_status <- db_health()
  if (!isTRUE(db_status$ok)) {
    showNotification(db_status$message, type = "error", duration = NULL)
    return(invisible(NULL))
  }

  overview_server("overview")
  map_server("map")
  tables_server("tables")
  stats_server("stats")
  analysis_server("analysis")
  about_server("about")
}

shinyApp(ui, server)
