source_class_expr <- function(alias = "e") {
  prefix <- if (nzchar(alias)) paste0(alias, ".") else ""
  paste0(
    "CASE ",
    "WHEN ", prefix, "event_type IN ('Shallow Crustal', 'Stable Continental') THEN 'crustal' ",
    "WHEN ", prefix, "event_type IN ('Interface', 'Intraslab', 'Outer-rise') THEN 'subduction' ",
    "WHEN ", prefix, "event_type = 'Induced' THEN 'induced' ",
    "ELSE 'undetermined' END"
  )
}

sql_in <- function(con, column, values) {
  values <- values[!is.na(values) & nzchar(values)]
  if (!length(values)) {
    return(NULL)
  }
  paste(column, "IN (", paste(DBI::dbQuoteString(con, values), collapse = ", "), ")")
}

sql_like_any <- function(con, columns, text) {
  if (!nzchar(text %||% "")) {
    return(NULL)
  }
  pattern <- paste0("%", text, "%")
  parts <- paste(columns, "LIKE", DBI::dbQuoteString(con, pattern), collapse = " OR ")
  paste0("(", parts, ")")
}

select_choices <- function(sql) {
  values <- db_get_query(sql)[[1]]
  values <- values[!is.na(values) & nzchar(values)]
  sort(unique(values))
}

range_or_default <- function(sql, default = c(0, 1)) {
  rng <- db_get_query(sql)
  values <- as.numeric(rng[1, ])
  if (any(is.na(values))) default else values
}

date_range_or_default <- function() {
  rng <- db_get_query("SELECT min(substr(datetime, 1, 10)) AS min_date, max(substr(datetime, 1, 10)) AS max_date FROM events")
  as.Date(unlist(rng[1, ]))
}

safe_date_range <- function(default = as.Date(c("1900-01-01", "2100-01-01"))) {
  rng <- tryCatch(date_range_or_default(), error = function(e) default)
  if (length(rng) != 2 || any(is.na(rng))) default else rng
}

map_filter_choices <- function() {
  list(
    source_class = c("crustal", "subduction", "induced", "undetermined"),
    event_type = select_choices("SELECT DISTINCT event_type FROM events ORDER BY event_type"),
    event_country = select_choices("SELECT DISTINCT event_country FROM events ORDER BY event_country"),
    site_country = select_choices("SELECT DISTINCT site_country FROM sites ORDER BY site_country"),
    network_code = select_choices("SELECT DISTINCT network_code FROM networks ORDER BY network_code"),
    network_type = select_choices("SELECT DISTINCT network_type FROM networks ORDER BY network_type"),
    magnitude = range_or_default("SELECT min(magnitude), max(magnitude) FROM events", c(0, 10)),
    date = safe_date_range()
  )
}

event_where_clauses <- function(con, input, alias = "e") {
  p <- if (nzchar(alias)) paste0(alias, ".") else ""
  clauses <- list(
    paste0(p, "hypocenter_longitude IS NOT NULL"),
    paste0(p, "hypocenter_latitude IS NOT NULL")
  )
  if (length(input$source_class)) {
    clauses <- c(clauses, sql_in(con, source_class_expr(alias), input$source_class))
  }
  clauses <- c(clauses, sql_in(con, paste0(p, "event_type"), input$event_type))
  clauses <- c(clauses, sql_in(con, paste0(p, "event_country"), input$event_country))
  if (length(input$magnitude) == 2) {
    clauses <- c(clauses, sprintf("%smagnitude BETWEEN %s AND %s", p, input$magnitude[1], input$magnitude[2]))
  }
  if (length(input$date_range) == 2 && all(!is.na(input$date_range))) {
    clauses <- c(
      clauses,
      paste0("date(substr(", p, "datetime, 1, 10)) BETWEEN ",
             DBI::dbQuoteString(con, as.character(input$date_range[1])),
             " AND ",
             DBI::dbQuoteString(con, as.character(input$date_range[2])))
    )
  }
  Filter(Negate(is.null), clauses)
}

network_exists_clause <- function(con, input, event_alias = "e") {
  network_bits <- c(
    sql_in(con, "n2.network_code", input$network_code),
    sql_in(con, "n2.network_type", input$network_type)
  )
  network_bits <- Filter(Negate(is.null), network_bits)
  if (!length(network_bits)) {
    return(NULL)
  }
  paste0(
    "EXISTS (SELECT 1 FROM motions m2 ",
    "JOIN stations st2 USING (station_id) ",
    "JOIN networks n2 USING (network_id) ",
    "WHERE m2.event_id = ", event_alias, ".event_id AND ",
    paste(network_bits, collapse = " AND "),
    ")"
  )
}

site_exists_clause <- function(con, input, event_alias = "e") {
  clause <- sql_in(con, "si2.site_country", input$site_country)
  if (is.null(clause)) {
    return(NULL)
  }
  paste0(
    "EXISTS (SELECT 1 FROM motions m3 ",
    "JOIN stations st3 USING (station_id) ",
    "JOIN sites si2 USING (site_id) ",
    "WHERE m3.event_id = ", event_alias, ".event_id AND ",
    clause,
    ")"
  )
}
