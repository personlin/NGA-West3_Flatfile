analysis_ui <- function(id) {
  ns <- NS(id)
  page_sidebar(
    class = "app-page",
    sidebar = sidebar(
      width = 330,
      selectInput(ns("component"), "Component", choices = c("H1", "H2", "V", "RotD0", "RotD50", "RotD100", "EAS"), selected = "RotD50"),
      actionButton(ns("load_component"), "Load RDS"),
      sliderInput(ns("mag"), "Magnitude", min = 0, max = 10, value = c(0, 10), step = 0.1),
      sliderInput(ns("rrup"), "RRUP", min = 0, max = 500, value = c(0, 200), step = 5),
      sliderInput(ns("vs30"), "VS30", min = 0, max = 2000, value = c(0, 1500), step = 25),
      selectInput(ns("measure"), "Measure", choices = c("PGA" = "pga", "PGV" = "pgv"), selected = "pga"),
      numericInput(ns("preview_rows"), "Preview rows", value = 500, min = 50, max = 5000, step = 50),
      downloadButton(ns("download_subset"), "Download subset")
    ),
    layout_columns(
      col_widths = c(12, 12),
      card(full_screen = TRUE, card_header(uiOutput(ns("status"))), uiOutput(ns("preview"))),
      card(full_screen = TRUE, card_header("Distribution"), plotOutput(ns("distribution"), height = 320))
    )
  )
}

component_file <- function(component) {
  file.path(rds_dir(), sprintf("nga_west3_%s_flatfile.rds", tolower(component)))
}

analysis_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    loaded <- eventReactive(input$load_component, {
      path <- component_file(input$component)
      validate(need(file.exists(path), paste("RDS file not found:", path)))
      readRDS(path)
    }, ignoreInit = TRUE)

    filtered <- reactive({
      dat <- loaded()
      if (!is.data.frame(dat)) dat <- as.data.frame(dat)
      keep <- rep(TRUE, nrow(dat))
      if ("magnitude" %in% names(dat)) keep <- keep & dat$magnitude >= input$mag[1] & dat$magnitude <= input$mag[2]
      if ("rrup" %in% names(dat)) keep <- keep & dat$rrup >= input$rrup[1] & dat$rrup <= input$rrup[2]
      if ("vs30" %in% names(dat)) keep <- keep & dat$vs30 >= input$vs30[1] & dat$vs30 <= input$vs30[2]
      dat[keep %in% TRUE, , drop = FALSE]
    })

    measure_col <- reactive({
      dat <- filtered()
      candidates <- grep(paste0("^", input$measure, "(_|$)"), names(dat), value = TRUE, ignore.case = TRUE)
      candidates[1] %||% NA_character_
    })

    output$status <- renderUI({
      dat <- filtered()
      tags$span(
        input$component,
        tags$small(class = "text-muted ms-2", paste(format_count(nrow(dat)), "filtered rows"))
      )
    })

    output$preview <- renderUI({
      if (requireNamespace("DT", quietly = TRUE)) {
        DT::DTOutput(session$ns("preview_table"))
      } else {
        tableOutput(session$ns("preview_table_base"))
      }
    })

    if (requireNamespace("DT", quietly = TRUE)) {
      output$preview_table <- DT::renderDT({
        dat <- filtered()
        cols <- intersect(c("motion_id", "event_id", "event_name", "magnitude", "event_type", "network_code", "station_code", "site_country", "rrup", "rjb", "vs30", measure_col()), names(dat))
        DT::datatable(utils::head(dat[, cols, drop = FALSE], input$preview_rows), rownames = FALSE, options = list(pageLength = 25, scrollX = TRUE))
      }, server = FALSE)
    }

    output$preview_table_base <- renderTable({
      dat <- filtered()
      cols <- intersect(c("motion_id", "event_id", "event_name", "magnitude", "event_type", "network_code", "station_code", "site_country", "rrup", "rjb", "vs30", measure_col()), names(dat))
      utils::head(dat[, cols, drop = FALSE], min(input$preview_rows, 200))
    })

    output$distribution <- renderPlot({
      dat <- filtered()
      col <- measure_col()
      validate(need(!is.na(col) && col %in% names(dat), "Selected measure is not available in this RDS file."))
      x <- dat[[col]]
      x <- x[is.finite(x) & x > 0]
      validate(need(length(x), "No positive values after filtering."))
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(data.frame(value = x), ggplot2::aes(value)) +
          ggplot2::geom_histogram(bins = 50, fill = "#246a73", color = "white") +
          ggplot2::scale_x_log10() +
          ggplot2::labs(x = paste0(toupper(input$measure), " (log scale)"), y = "Rows") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        hist(log10(x), breaks = 50, xlab = paste0("log10 ", toupper(input$measure)), main = "")
      }
    })

    output$download_subset <- downloadHandler(
      filename = function() paste0("nga_west3_", tolower(input$component), "_subset.csv"),
      content = function(file) utils::write.csv(filtered(), file, row.names = FALSE)
    )
  })
}
