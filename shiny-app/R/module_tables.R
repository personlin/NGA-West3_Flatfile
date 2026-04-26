table_groups <- function() {
  list(
    "Earthquakes" = c("events", "event_types"),
    "Stations and sites" = c("stations", "sites", "basin_depth_estimates"),
    "Networks" = c("networks"),
    "Ground motions" = c("motions", "paths", "time_series_metadata", "intensity_measures"),
    "Spectra metadata" = c("spectral_axes", "response_spectra", "effective_amplitude_spectra"),
    "Documentation" = c("release_files", "field_catalog", "code_definitions", "citations")
  )
}

common_columns <- function(table, fields) {
  preferred <- switch(
    table,
    events = c("event_id", "event_name", "event_type", "event_country", "datetime", "magnitude", "hypocenter_longitude", "hypocenter_latitude"),
    stations = c("station_id", "station_code", "station_name", "network_id", "site_id", "station_longitude", "station_latitude"),
    sites = c("site_id", "site_name", "site_country", "site_subdivision", "vs30", "terrain_class", "site_longitude", "site_latitude"),
    networks = c("network_id", "network_code", "network_name", "network_type", "operation_org"),
    motions = c("motion_id", "event_id", "station_id", "path_id", "nga_west2_rsn", "nyquist_frequency"),
    paths = c("path_id", "motion_id", "rrup", "rjb", "rx", "ry", "epicentral_distance", "hypocentral_distance"),
    intensity_measures = c("motion_id", "component", "pga", "pgv", "cav", "ia"),
    spectral_axes = c("spectrum_type", "component", "ordinate_index", "axis_value"),
    release_files = c("file_name", "file_role", "component", "row_count", "column_count", "sha256"),
    fields[seq_len(min(8, length(fields)))]
  )
  intersect(preferred, fields)
}

tables_ui <- function(id) {
  ns <- NS(id)
  page_sidebar(
    class = "app-page",
    sidebar = sidebar(
      width = 330,
      selectInput(ns("group"), "Group", choices = names(table_groups())),
      selectInput(ns("table"), "Table", choices = table_groups()[[1]]),
      textInput(ns("search"), "Search", placeholder = "Optional text filter"),
      selectizeInput(ns("columns"), "Columns", choices = NULL, multiple = TRUE),
      numericInput(ns("limit"), "Rows to fetch", value = 1000, min = 50, max = 50000, step = 50),
      downloadButton(ns("download"), "Download CSV")
    ),
    card(
      full_screen = TRUE,
      card_header(uiOutput(ns("table_title"))),
      uiOutput(ns("table_view"))
    )
  )
}

tables_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    observeEvent(input$group, {
      updateSelectInput(session, "table", choices = table_groups()[[input$group]])
    }, ignoreInit = FALSE)

    observeEvent(input$table, {
      fields <- db_table_fields(input$table)
      updateSelectizeInput(session, "columns", choices = fields, selected = common_columns(input$table, fields), server = TRUE)
    }, ignoreInit = FALSE)

    table_data <- reactive({
      req(input$table)
      fields <- db_table_fields(input$table)
      cols <- intersect(input$columns %||% common_columns(input$table, fields), fields)
      if (!length(cols)) cols <- common_columns(input$table, fields)
      with_db(function(con) {
        quoted_cols <- paste(DBI::dbQuoteIdentifier(con, cols), collapse = ", ")
        table_id <- DBI::dbQuoteIdentifier(con, input$table)
        where <- sql_like_any(con, paste(DBI::dbQuoteIdentifier(con, cols)), input$search)
        sql <- paste0("SELECT ", quoted_cols, " FROM ", table_id)
        if (!is.null(where)) sql <- paste(sql, "WHERE", where)
        sql <- paste(sql, "LIMIT", as.integer(input$limit %||% 1000))
        DBI::dbGetQuery(con, sql)
      })
    })

    output$table_title <- renderUI({
      tags$span(input$table %||% "", tags$small(class = "text-muted ms-2", paste(format_count(nrow(table_data())), "rows fetched")))
    })

    output$table_view <- renderUI({
      if (requireNamespace("DT", quietly = TRUE)) {
        DT::DTOutput(session$ns("table"))
      } else {
        tableOutput(session$ns("table_base"))
      }
    })

    if (requireNamespace("DT", quietly = TRUE)) {
      output$table <- DT::renderDT({
        DT::datatable(table_data(), rownames = FALSE, filter = "top", options = list(pageLength = 25, scrollX = TRUE))
      }, server = FALSE)
    }

    output$table_base <- renderTable({
      utils::head(table_data(), 200)
    })

    output$download <- downloadHandler(
      filename = function() paste0(input$table %||% "nga_west3_table", ".csv"),
      content = function(file) utils::write.csv(table_data(), file, row.names = FALSE)
    )
  })
}
