overview_ui <- function(id) {
  ns <- NS(id)
  page_fluid(
    class = "app-page",
    uiOutput(ns("value_boxes")),
    layout_columns(
      col_widths = c(6, 6),
      card(full_screen = TRUE, card_header("Events by Source Class"), plotOutput(ns("source_plot"), height = 320)),
      card(full_screen = TRUE, card_header("Top Event Countries"), plotOutput(ns("country_plot"), height = 320)),
      card(full_screen = TRUE, card_header("Stations by Country"), plotOutput(ns("station_country_plot"), height = 320)),
      card(full_screen = TRUE, card_header("Motions by Component"), plotOutput(ns("component_plot"), height = 320))
    )
  )
}

overview_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$value_boxes <- renderUI({
      counts <- db_get_query(
        "SELECT 'Events' AS label, count(*) AS n FROM events
         UNION ALL SELECT 'Stations', count(*) FROM stations
         UNION ALL SELECT 'Sites', count(*) FROM sites
         UNION ALL SELECT 'Motions', count(*) FROM motions
         UNION ALL SELECT 'Components', count(DISTINCT component) FROM intensity_measures"
      )
      layout_column_wrap(
        width = "180px",
        fill = FALSE,
        lapply(seq_len(nrow(counts)), function(i) {
          value_box(title = counts$label[i], value = format_count(counts$n[i]), theme = "primary")
        })
      )
    })

    output$source_plot <- renderPlot({
      dat <- db_get_query(paste0("SELECT ", source_class_expr(""), " AS source_class, event_type, count(*) AS n FROM events GROUP BY source_class, event_type"))
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(source_class, n, fill = event_type)) +
          ggplot2::geom_col() +
          ggplot2::labs(x = NULL, y = "Events", fill = "Event type") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        barplot(tapply(dat$n, dat$source_class, sum), las = 2, ylab = "Events")
      }
    })

    output$country_plot <- renderPlot({
      dat <- db_get_query("SELECT COALESCE(event_country, 'Unknown') AS country, count(*) AS n FROM events GROUP BY country ORDER BY n DESC LIMIT 12")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        dat$country <- stats::reorder(dat$country, dat$n)
        ggplot2::ggplot(dat, ggplot2::aes(country, n)) +
          ggplot2::geom_col(fill = "#246a73") +
          ggplot2::coord_flip() +
          ggplot2::labs(x = NULL, y = "Events") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        barplot(setNames(dat$n, dat$country), horiz = TRUE, las = 1)
      }
    })

    output$station_country_plot <- renderPlot({
      dat <- db_get_query("SELECT COALESCE(site_country, 'Unknown') AS country, count(*) AS n FROM sites GROUP BY country ORDER BY n DESC LIMIT 12")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        dat$country <- stats::reorder(dat$country, dat$n)
        ggplot2::ggplot(dat, ggplot2::aes(country, n)) +
          ggplot2::geom_col(fill = "#4f46e5") +
          ggplot2::coord_flip() +
          ggplot2::labs(x = NULL, y = "Sites") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        barplot(setNames(dat$n, dat$country), horiz = TRUE, las = 1)
      }
    })

    output$component_plot <- renderPlot({
      dat <- db_get_query("SELECT component, count(*) AS n FROM intensity_measures GROUP BY component ORDER BY component")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(component, n)) +
          ggplot2::geom_col(fill = "#2f855a") +
          ggplot2::labs(x = NULL, y = "Motions") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        barplot(setNames(dat$n, dat$component), las = 2)
      }
    })
  })
}
