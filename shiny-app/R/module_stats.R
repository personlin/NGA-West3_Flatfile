stats_ui <- function(id) {
  ns <- NS(id)
  page_fluid(
    class = "app-page",
    layout_columns(
      col_widths = c(6, 6),
      card(full_screen = TRUE, card_header("Event Count by Year"), plotOutput(ns("events_year"), height = 320)),
      card(full_screen = TRUE, card_header("Magnitude Distribution"), plotOutput(ns("magnitude_hist"), height = 320)),
      card(full_screen = TRUE, card_header("RRUP Distribution"), plotOutput(ns("rrup_hist"), height = 320)),
      card(full_screen = TRUE, card_header("VS30 Distribution"), plotOutput(ns("vs30_hist"), height = 320)),
      card(full_screen = TRUE, card_header("Motion Count by Component"), plotOutput(ns("motion_component"), height = 320)),
      card(full_screen = TRUE, card_header("Motion Count by Network Type"), plotOutput(ns("motion_network"), height = 320))
    )
  )
}

stats_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    output$events_year <- renderPlot({
      dat <- db_get_query("SELECT substr(datetime, 1, 4) AS year, count(*) AS n FROM events WHERE datetime IS NOT NULL GROUP BY year ORDER BY year")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(as.integer(year), n)) +
          ggplot2::geom_line(color = "#246a73") +
          ggplot2::geom_point(color = "#246a73", size = 1) +
          ggplot2::labs(x = NULL, y = "Events") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        plot(as.integer(dat$year), dat$n, type = "l", xlab = "Year", ylab = "Events")
      }
    })

    output$magnitude_hist <- renderPlot({
      dat <- db_get_query("SELECT magnitude FROM events WHERE magnitude IS NOT NULL")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(magnitude)) +
          ggplot2::geom_histogram(binwidth = 0.25, fill = "#c2410c", color = "white") +
          ggplot2::labs(x = "Magnitude", y = "Events") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        hist(dat$magnitude, xlab = "Magnitude", main = "")
      }
    })

    output$rrup_hist <- renderPlot({
      dat <- db_get_query("SELECT rrup FROM paths WHERE rrup IS NOT NULL AND rrup >= 0 AND rrup <= 500 LIMIT 200000")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(rrup)) +
          ggplot2::geom_histogram(binwidth = 10, fill = "#2563eb", color = "white") +
          ggplot2::labs(x = "RRUP (km)", y = "Motions") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        hist(dat$rrup, breaks = 50, xlab = "RRUP", main = "")
      }
    })

    output$vs30_hist <- renderPlot({
      dat <- db_get_query("SELECT vs30 FROM sites WHERE vs30 IS NOT NULL AND vs30 > 0 AND vs30 < 3000")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(vs30)) +
          ggplot2::geom_histogram(binwidth = 50, fill = "#2f855a", color = "white") +
          ggplot2::labs(x = "VS30 (m/s)", y = "Sites") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        hist(dat$vs30, breaks = 50, xlab = "VS30", main = "")
      }
    })

    output$motion_component <- renderPlot({
      dat <- db_get_query("SELECT component, count(*) AS n FROM intensity_measures GROUP BY component ORDER BY component")
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        ggplot2::ggplot(dat, ggplot2::aes(component, n)) +
          ggplot2::geom_col(fill = "#4f46e5") +
          ggplot2::labs(x = NULL, y = "Rows") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        barplot(setNames(dat$n, dat$component), las = 2)
      }
    })

    output$motion_network <- renderPlot({
      dat <- db_get_query(
        "SELECT COALESCE(n.network_type, 'Unknown') AS network_type, count(*) AS n
         FROM motions m
         JOIN stations st USING (station_id)
         LEFT JOIN networks n USING (network_id)
         GROUP BY network_type ORDER BY n DESC LIMIT 12"
      )
      if (requireNamespace("ggplot2", quietly = TRUE)) {
        dat$network_type <- stats::reorder(dat$network_type, dat$n)
        ggplot2::ggplot(dat, ggplot2::aes(network_type, n)) +
          ggplot2::geom_col(fill = "#0f766e") +
          ggplot2::coord_flip() +
          ggplot2::labs(x = NULL, y = "Motions") +
          ggplot2::theme_minimal(base_size = 13)
      } else {
        barplot(setNames(dat$n, dat$network_type), horiz = TRUE, las = 1)
      }
    })
  })
}
