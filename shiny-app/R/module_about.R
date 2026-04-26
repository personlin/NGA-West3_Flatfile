about_documents <- list(
  sqlite = list(title = "SQLite usage notes", path = file.path("docs", "sqlite_usage.md")),
  rds = list(title = "RDS usage notes", path = file.path("docs", "rds_usage.md")),
  google_drive = list(title = "Google Drive release notes", path = file.path("docs", "google_drive_release.md")),
  shiny_plan = list(title = "Shiny development plan", path = file.path("docs", "shiny_app_development_plan.md"))
)

about_document_buttons <- function(ns) {
  tags$div(
    class = "about-doc-links",
    lapply(names(about_documents), function(key) {
      actionButton(
        inputId = ns(paste0("view_doc_", key)),
        label = about_documents[[key]]$title,
        class = "btn btn-link about-doc-link"
      )
    })
  )
}

about_markdown_ui <- function(relative_path) {
  path <- normalizePath(file.path(project_root(), relative_path), mustWork = FALSE)
  if (!file.exists(path)) {
    return(tags$p(class = "text-danger", paste("Document not found:", relative_path)))
  }

  markdown_text <- paste(readLines(path, warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  if (requireNamespace("commonmark", quietly = TRUE)) {
    return(tags$div(class = "markdown-view", HTML(commonmark::markdown_html(markdown_text))))
  }

  tags$pre(class = "markdown-view markdown-view-plain", markdown_text)
}

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
        about_document_buttons(ns)
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
    lapply(names(about_documents), function(key) {
      local({
        document <- about_documents[[key]]
        input_id <- paste0("view_doc_", key)
        observeEvent(input[[input_id]], {
          showModal(modalDialog(
            title = document$title,
            size = "l",
            easyClose = TRUE,
            footer = modalButton("Close"),
            tags$div(class = "about-doc-modal", about_markdown_ui(document$path))
          ))
        }, ignoreInit = TRUE)
      })
    })

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
