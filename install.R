#!/usr/bin/env Rscript
# Install all packages required to run the NGA-West3 Shiny app.
#
# Usage:
#   Rscript install.R

required <- c(
  "shiny",     # web app framework
  "bslib",     # Bootstrap 5 theming
  "DBI",       # database interface
  "RSQLite"    # SQLite driver
)

optional <- c(
  "DT",          # interactive tables
  "leaflet",     # interactive map
  "ggplot2",     # polished plots
  "thematic",    # automatic plot theming
  "commonmark"   # Markdown rendering in the About tab
)

install_missing <- function(pkgs, label) {
  missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(missing) == 0L) {
    message(label, ": all installed")
    return(invisible(NULL))
  }
  message(label, ": installing ", paste(missing, collapse = ", "))
  install.packages(missing, repos = "https://cloud.r-project.org")
}

install_missing(required, "Required")
install_missing(optional, "Optional")

message("Done. Run the app with:  shiny::runApp(\"shiny-app\")")
