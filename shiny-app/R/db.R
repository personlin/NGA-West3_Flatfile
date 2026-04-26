if (!exists("%||%", mode = "function")) {
  `%||%` <- function(x, y) if (is.null(x) || length(x) == 0 || all(is.na(x))) y else x
}

app_root <- function() {
  if (exists("app_dir", inherits = TRUE)) {
    return(normalizePath(get("app_dir", inherits = TRUE), mustWork = TRUE))
  }
  normalizePath(file.path(getwd(), "shiny-app"), mustWork = FALSE)
}

project_root <- function() {
  if (exists("app_dir", inherits = TRUE)) {
    return(normalizePath(file.path(get("app_dir", inherits = TRUE), ".."), mustWork = TRUE))
  }
  normalizePath(getwd(), mustWork = TRUE)
}

db_path <- function() {
  candidates <- c(
    Sys.getenv("NGA_WEST3_SQLITE", unset = NA_character_),
    file.path(project_root(), "output", "sqlite", "nga_west3_20250919.sqlite"),
    file.path(app_root(), "..", "output", "sqlite", "nga_west3_20250919.sqlite")
  )
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  hit <- candidates[file.exists(candidates)][1]
  hit %||% candidates[1]
}

rds_dir <- function() {
  candidates <- c(
    Sys.getenv("NGA_WEST3_RDS_DIR", unset = NA_character_),
    file.path(project_root(), "output", "rds"),
    file.path(app_root(), "..", "output", "rds")
  )
  candidates <- candidates[!is.na(candidates) & nzchar(candidates)]
  hit <- candidates[dir.exists(candidates)][1]
  hit %||% candidates[1]
}

db_connect <- function() {
  DBI::dbConnect(RSQLite::SQLite(), db_path(), flags = RSQLite::SQLITE_RO)
}

with_db <- function(fun) {
  con <- db_connect()
  on.exit(DBI::dbDisconnect(con), add = TRUE)
  fun(con)
}

db_get_query <- function(sql, params = NULL) {
  with_db(function(con) DBI::dbGetQuery(con, sql, params = params))
}

db_scalar <- function(sql, params = NULL) {
  value <- db_get_query(sql, params = params)[1, 1]
  if (length(value) == 0) NA else value
}

db_health <- function() {
  path <- db_path()
  if (!file.exists(path)) {
    return(list(ok = FALSE, message = paste("SQLite database not found:", path)))
  }
  required <- c("events", "stations", "sites", "motions", "intensity_measures")
  result <- tryCatch({
    present <- with_db(function(con) {
      DBI::dbGetQuery(con, sprintf(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name IN (%s)",
        paste(DBI::dbQuoteString(con, required), collapse = ", ")
      ))$name
    })
    missing <- setdiff(required, present)
    if (length(missing)) paste("Missing tables:", paste(missing, collapse = ", ")) else "ok"
  }, error = function(e) e)
  if (inherits(result, "error") || !identical(as.character(result), "ok")) {
    detail <- if (inherits(result, "error")) conditionMessage(result) else as.character(result)
    return(list(ok = FALSE, message = detail))
  }
  list(ok = TRUE, message = "ok")
}

db_table_names <- function() {
  db_get_query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")$name
}

db_table_fields <- function(table) {
  with_db(function(con) DBI::dbListFields(con, table))
}

format_count <- function(x) {
  format(as.numeric(x %||% 0), big.mark = ",", scientific = FALSE, trim = TRUE)
}

empty_data <- function() {
  data.frame()
}
