about_ui <- function(id) {
  ns <- NS(id)
  page_fluid(
    class = "app-page",
    layout_columns(
      col_widths = c(7, 5),
      card(
        card_header("Data Product"),
        tags$p("NGA-West3 derived data products, release date 2025-09-19."),
        tags$p("SQLite is the canonical backend for interactive browsing. RDS files are used for cached map/statistics data and lazy analysis workflows."),
        tags$ul(
          tags$li(tags$a(href = "../docs/sqlite_usage.md", "SQLite usage notes")),
          tags$li(tags$a(href = "../docs/rds_usage.md", "RDS usage notes")),
          tags$li(tags$a(href = "../docs/google_drive_release.md", "Google Drive release notes")),
          tags$li(tags$a(href = "../docs/shiny_app_development_plan.md", "Shiny development plan"))
        )
      ),
      card(
        card_header("Local Status"),
        verbatimTextOutput(ns("status"))
      )
    )
  )
}

about_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$status <- renderText({
      sqlite_status <- db_health()
      rds_files <- if (dir.exists(rds_dir())) list.files(rds_dir(), pattern = "\\.rds$") else character()
      cache_files <- if (dir.exists(cache_dir())) list.files(cache_dir(), pattern = "\\.rds$") else character()
      paste(
        "SQLite:",
        db_path(),
        paste("Integrity:", sqlite_status$message),
        "",
        "RDS directory:",
        rds_dir(),
        paste("RDS files:", length(rds_files)),
        "",
        "App cache directory:",
        cache_dir(),
        paste("Cache files:", length(cache_files)),
        "",
        "Checksum verification:",
        "shasum -a 256 -c manifests/nga_west3_20250919_SHA256SUMS.txt",
        sep = "\n"
      )
    })
  })
}
