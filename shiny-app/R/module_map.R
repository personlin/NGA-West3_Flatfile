map_ui <- function(id) {
  ns <- NS(id)
  page_sidebar(
    class = "app-page map-page",
    sidebar = sidebar(
      width = 340,
      radioButtons(ns("mode"), "Layer", choices = c("Epicenters" = "events", "Stations" = "stations", "Both" = "both"), selected = "events"),
      selectizeInput(ns("source_class"), "Source class", choices = NULL, multiple = TRUE),
      selectizeInput(ns("event_type"), "Event type", choices = NULL, multiple = TRUE),
      selectizeInput(ns("event_country"), "Event country", choices = NULL, multiple = TRUE),
      selectizeInput(ns("site_country"), "Site country", choices = NULL, multiple = TRUE),
      selectizeInput(ns("network_code"), "Network code", choices = NULL, multiple = TRUE),
      selectizeInput(ns("network_type"), "Network type", choices = NULL, multiple = TRUE),
      sliderInput(ns("magnitude"), "Magnitude", min = 0, max = 10, value = c(0, 10), step = 0.1),
      dateRangeInput(ns("date_range"), "Date range"),
      numericInput(ns("motion_min"), "Minimum motions", value = 0, min = 0, step = 10),
      checkboxInput(ns("show_all"), "Show all matching points", value = FALSE)
    ),
    card(
      full_screen = TRUE,
      card_header(uiOutput(ns("map_title"))),
      uiOutput(ns("map_view"))
    )
  )
}

map_server <- function(id) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    choices <- reactiveVal(NULL)

    observe({
      ch <- map_filter_choices()
      choices(ch)
      updateSelectizeInput(session, "source_class", choices = ch$source_class, server = TRUE)
      updateSelectizeInput(session, "event_type", choices = ch$event_type, server = TRUE)
      updateSelectizeInput(session, "event_country", choices = ch$event_country, server = TRUE)
      updateSelectizeInput(session, "site_country", choices = ch$site_country, server = TRUE)
      updateSelectizeInput(session, "network_code", choices = ch$network_code, server = TRUE)
      updateSelectizeInput(session, "network_type", choices = ch$network_type, server = TRUE)
      updateSliderInput(session, "magnitude", min = floor(ch$magnitude[1]), max = ceiling(ch$magnitude[2]), value = ch$magnitude)
      updateDateRangeInput(session, "date_range", start = ch$date[1], end = ch$date[2], min = ch$date[1], max = ch$date[2])
    })

    point_cap <- reactive(if (isTRUE(input$show_all)) 100000 else 5000)

    map_data <- reactive({
      cap <- point_cap()
      mode <- input$mode %||% "events"
      dat <- list(events = empty_data(), stations = empty_data())
      if (mode %in% c("events", "both")) {
        dat$events <- events_map_query(input, cap = cap)
      }
      if (mode %in% c("stations", "both")) {
        dat$stations <- stations_map_query(input, cap = cap)
      }
      dat
    })

    output$map_title <- renderUI({
      dat <- map_data()
      total <- nrow(dat$events) + nrow(dat$stations)
      cap_note <- if (!isTRUE(input$show_all) && total >= point_cap()) " capped" else ""
      tags$span("Map Results", tags$small(class = "text-muted ms-2", paste0(format_count(total), " points", cap_note)))
    })

    output$map_view <- renderUI({
      if (requireNamespace("leaflet", quietly = TRUE)) {
        leaflet::leafletOutput(ns("map"), height = "72vh")
      } else {
        tags$div(class = "p-4", "Install the leaflet package to enable the interactive map.")
      }
    })

    if (requireNamespace("leaflet", quietly = TRUE)) {
      output$map <- leaflet::renderLeaflet({
        dat <- map_data()
        m <- leaflet::leaflet() |>
          leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron)

        if (nrow(dat$events)) {
          event_popup <- paste0(
            "<strong>", dat$events$label, "</strong><br>",
            "M ", dat$events$magnitude, " ", dat$events$event_type, "<br>",
            dat$events$event_country, "<br>",
            "Motions: ", dat$events$motion_count
          )
          m <- leaflet::addCircleMarkers(
            m, data = dat$events, lng = ~longitude, lat = ~latitude,
            radius = 5, stroke = FALSE, fillOpacity = 0.72, color = "#c2410c",
            popup = event_popup, group = "Epicenters",
            clusterOptions = leaflet::markerClusterOptions()
          )
        }
        if (nrow(dat$stations)) {
          station_popup <- paste0(
            "<strong>", dat$stations$label, "</strong><br>",
            dat$stations$network_code, " ", dat$stations$network_name, "<br>",
            dat$stations$site_country, "<br>",
            "VS30: ", dat$stations$vs30, "<br>",
            "Motions: ", dat$stations$motion_count
          )
          m <- leaflet::addCircleMarkers(
            m, data = dat$stations, lng = ~longitude, lat = ~latitude,
            radius = 4, stroke = FALSE, fillOpacity = 0.62, color = "#2563eb",
            popup = station_popup, group = "Stations",
            clusterOptions = leaflet::markerClusterOptions()
          )
        }
        m
      })
    }
  })
}
