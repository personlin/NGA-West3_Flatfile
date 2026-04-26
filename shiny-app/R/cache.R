cache_dir <- function() {
  root <- if (exists("app_dir", inherits = TRUE)) get("app_dir", inherits = TRUE) else file.path(project_root(), "shiny-app")
  dir <- file.path(root, "data", "cache")
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  dir
}

cache_file <- function(name) {
  file.path(cache_dir(), name)
}

read_cache <- function(name) {
  path <- cache_file(name)
  if (file.exists(path)) readRDS(path) else NULL
}

write_cache <- function(data, name) {
  saveRDS(data, cache_file(name), compress = "gzip")
  invisible(cache_file(name))
}

events_map_query <- function(input, cap = 5000) {
  with_db(function(con) {
    where <- event_where_clauses(con, input)
    where <- c(where, network_exists_clause(con, input), site_exists_clause(con, input))
    where <- Filter(Negate(is.null), where)
    having <- if (!is.null(input$motion_min) && input$motion_min > 0) {
      paste("HAVING motion_count >=", as.integer(input$motion_min))
    } else {
      ""
    }
    sql <- paste0(
      "SELECT e.event_id, COALESCE(e.event_name, 'Event ' || e.event_id) AS label, ",
      "e.hypocenter_longitude AS longitude, e.hypocenter_latitude AS latitude, ",
      "e.event_type, ", source_class_expr("e"), " AS source_class, ",
      "e.event_country, e.event_subdivision, e.magnitude, e.datetime, ",
      "COUNT(m.motion_id) AS motion_count ",
      "FROM events e LEFT JOIN motions m USING (event_id) ",
      "WHERE ", paste(where, collapse = " AND "),
      " GROUP BY e.event_id ", having,
      " ORDER BY motion_count DESC, e.event_id LIMIT ", as.integer(cap)
    )
    DBI::dbGetQuery(con, sql)
  })
}

stations_map_query <- function(input, cap = 5000) {
  with_db(function(con) {
    clauses <- list(
      "COALESCE(si.site_longitude, st.station_longitude) IS NOT NULL",
      "COALESCE(si.site_latitude, st.station_latitude) IS NOT NULL"
    )
    clauses <- c(
      clauses,
      sql_in(con, "si.site_country", input$site_country),
      sql_in(con, "n.network_code", input$network_code),
      sql_in(con, "n.network_type", input$network_type)
    )
    event_clauses <- event_where_clauses(con, input, alias = "e2")
    event_clauses <- event_clauses[!grepl("hypocenter_", event_clauses)]
    if (length(event_clauses)) {
      clauses <- c(
        clauses,
        paste0(
          "EXISTS (SELECT 1 FROM motions m2 JOIN events e2 USING (event_id) ",
          "WHERE m2.station_id = st.station_id AND ",
          paste(event_clauses, collapse = " AND "),
          ")"
        )
      )
    }
    clauses <- Filter(Negate(is.null), clauses)
    having <- if (!is.null(input$motion_min) && input$motion_min > 0) {
      paste("HAVING motion_count >=", as.integer(input$motion_min))
    } else {
      ""
    }
    sql <- paste0(
      "SELECT st.station_id, COALESCE(st.station_code, st.station_name, 'Station ' || st.station_id) AS label, ",
      "COALESCE(si.site_longitude, st.station_longitude) AS longitude, ",
      "COALESCE(si.site_latitude, st.station_latitude) AS latitude, ",
      "st.station_code, n.network_code, n.network_name, n.network_type, ",
      "si.site_country, si.site_subdivision, si.vs30, COUNT(m.motion_id) AS motion_count ",
      "FROM stations st ",
      "LEFT JOIN sites si USING (site_id) ",
      "LEFT JOIN networks n USING (network_id) ",
      "LEFT JOIN motions m USING (station_id) ",
      "WHERE ", paste(clauses, collapse = " AND "),
      " GROUP BY st.station_id ", having,
      " ORDER BY motion_count DESC, st.station_id LIMIT ", as.integer(cap)
    )
    DBI::dbGetQuery(con, sql)
  })
}

build_app_caches <- function() {
  empty_input <- list(
    source_class = character(),
    event_type = character(),
    event_country = character(),
    site_country = character(),
    network_code = character(),
    network_type = character(),
    magnitude = range_or_default("SELECT min(magnitude), max(magnitude) FROM events", c(0, 10)),
    date_range = date_range_or_default(),
    motion_min = 0
  )
  write_cache(events_map_query(empty_input, cap = 20000), "events_map.rds")
  write_cache(stations_map_query(empty_input, cap = 20000), "stations_map.rds")
  write_cache(db_get_query("SELECT event_type, count(*) AS n FROM events GROUP BY event_type"), "event_summary.rds")
  write_cache(db_get_query("SELECT site_country, count(*) AS n FROM sites GROUP BY site_country"), "station_summary.rds")
  write_cache(db_get_query("SELECT network_type, operation_org, count(*) AS networks FROM networks GROUP BY network_type, operation_org"), "network_summary.rds")
  write_cache(db_get_query("SELECT event_id, station_id, count(*) AS motions, min(rrup) AS min_rrup, max(rrup) AS max_rrup FROM motions JOIN paths USING (path_id) GROUP BY event_id, station_id"), "motion_summary_by_event_station.rds")
  invisible(cache_dir())
}
