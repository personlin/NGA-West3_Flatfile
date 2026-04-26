#!/usr/bin/env Rscript

# Build RDS files for R users from the NGA-West3 public flatfiles.
# The RDS layer intentionally keeps the component flatfiles wide because this
# is the fastest shape for model-development workflows in R/data.table.

suppressPackageStartupMessages({
  library(data.table)
  library(readxl)
})

`%||%` <- function(x, y) if (is.null(x)) y else x

cmd_args <- commandArgs(trailingOnly = FALSE)
file_arg <- cmd_args[grepl("^--file=", cmd_args)]
script_path <- if (length(file_arg)) sub("^--file=", "", file_arg[[1]]) else "scripts/build_nga_west3_rds.R"
root <- normalizePath(file.path(dirname(script_path), ".."), mustWork = TRUE)
out_dir <- file.path(root, "output", "rds")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

csv_file <- function(name) file.path(root, name)
out_file <- function(name) file.path(out_dir, name)

read_release_docs <- function() {
  xlsx <- file.path(root, "NGA_West3_Flatfile_Documentation_20250919.xlsx")
  sheets <- excel_sheets(xlsx)
  docs <- list()
  for (sheet in intersect(
    c("PSA Field Descriptions", "EAS Field Descriptions", "Source Metadata", "Station Metadata"),
    sheets
  )) {
    docs[[sheet]] <- as.data.table(read_excel(xlsx, sheet = sheet, .name_repair = "unique", col_types = "text"))
  }
  docs$housing <- as.data.table(read_excel(xlsx, sheet = "Housing", .name_repair = "unique", col_types = "text"))
  docs$cosmos_station_type <- as.data.table(read_excel(xlsx, sheet = "COSMOS Station Type", .name_repair = "unique", col_types = "text"))
  docs$vs30_codes <- as.data.table(read_excel(xlsx, sheet = "VS30 Codes", .name_repair = "unique", col_types = "text"))
  docs$z_codes <- as.data.table(read_excel(xlsx, sheet = "Z Codes", .name_repair = "unique", col_types = "text"))
  docs$citations <- as.data.table(read_excel(xlsx, sheet = "Citations", .name_repair = "unique", col_types = "text"))
  docs
}

normalize_source <- function(source) {
  event_cols <- names(source)[1:37]
  finite_cols <- c("event_id", "finite_fault_id", "ztor", "fault_length", "fault_width",
                   "fault_area", "ffm_model", "ffm_complexity", "finite_fault_citation_id",
                   "finite_fault_kinematic_parameter_id")
  kin_cols <- c("event_id", "finite_fault_id", "finite_fault_kinematic_parameter_id",
                "average_fault_displacement", "rise_time", "average_slip_velocity",
                "preferred_rupture_velocity", "average_vr_vs", "percent_moment_release",
                "existence_of_shallow_asperity", "depth_to_shallowest_asperity")
  segs <- rbindlist(lapply(seq_len(16), function(i) {
    cols <- c(
      sprintf("seg_sub_rupture_number_%d", i),
      sprintf("ULC_latitude_%d", i),
      sprintf("ULC_longitude_%d", i),
      sprintf("ULC_depth_%d", i),
      sprintf("seg_length_%d", i),
      sprintf("seg_width_%d", i),
      sprintf("seg_area_%d", i),
      sprintf("seg_strike_%d", i),
      sprintf("seg_dip_%d", i),
      sprintf("seg_rake_%d", i)
    )
    dt <- source[, c("event_id", "finite_fault_id", cols), with = FALSE]
    setnames(dt, cols, c("seg_sub_rupture_number", "ulc_latitude", "ulc_longitude",
                         "ulc_depth", "seg_length", "seg_width", "seg_area",
                         "seg_strike", "seg_dip", "seg_rake"))
    dt[, segment_index := i]
    dt
  }), use.names = TRUE, fill = TRUE)
  segs <- segs[!is.na(seg_sub_rupture_number) & seg_sub_rupture_number != -999]
  list(
    events = unique(source[, ..event_cols], by = "event_id"),
    event_types = unique(source[, .(event_type_id, event_type)]),
    finite_faults = unique(source[!is.na(finite_fault_id), ..finite_cols], by = "finite_fault_id"),
    finite_fault_kinematic_parameters = unique(source[!is.na(finite_fault_kinematic_parameter_id), ..kin_cols],
                                              by = "finite_fault_kinematic_parameter_id"),
    finite_fault_segments = segs
  )
}

normalize_station <- function(station) {
  networks <- unique(station[, .(
    network_id, network_code, network_name, network_type, start_date, end_date,
    operation_org, network_citation_id
  )], by = "network_id")
  stations <- unique(station[, .(
    station_id, NGA_West2_SSN, site_id, network_id, station_name,
    station_latitude, station_longitude, station_code, housing,
    cosmos_station_type, sensor_depth, installation_date, removal_date
  )], by = "station_id")
  site_cols <- c("site_id", "site_longitude", "site_latitude", "site_elevation",
                 "site_country", "site_subdivision", "site_name", "vs30", "vs30_lnstd",
                 "vs30_code_id", "vs30_ref", "geological_unit", "geological_citation_id",
                 "slope_gradient", "slope_resolution", "terrain_class", "terrain_citation_id",
                 "z1p0_preferred", "z1p0_preferred_lnstd", "z1p0_code_id",
                 "z2p5_preferred", "z2p5_preferred_lnstd", "z2p5_code_id",
                 "basin_geomorphic_category", "basin_geospatial_category", "gmx_c2",
                 "gmx_c3", "rsbe", "rcebe", "DIVISION", "PROVINCE", "SECTION",
                 "geological_unit_cgs")
  sites <- unique(station[, ..site_cols], by = "site_id")
  models <- c("measured", "extrapolated", "CAGeo", "CVMS4", "CVMS4.26",
              "CVMS4.26.M01", "CVMH15.1", "SFCVM21.1", "GreatValley", "WFCVM",
              "USGSNCM", "NCREE", "NIED", "JSHIS", "NZGeo", "NZVM")
  basin <- rbindlist(lapply(models, function(model) {
    cols <- c(
      sprintf("z1p0_%s", model), sprintf("z1p0_lnstd_%s", model),
      sprintf("z2p5_%s", model), sprintf("z2p5_lnstd_%s", model)
    )
    dt <- station[, c("site_id", cols), with = FALSE]
    setnames(dt, cols, c("z1p0", "z1p0_lnstd", "z2p5", "z2p5_lnstd"))
    dt[, model_name := model]
    dt
  }), use.names = TRUE, fill = TRUE)
  basin <- basin[!(is.na(z1p0) & is.na(z1p0_lnstd) & is.na(z2p5) & is.na(z2p5_lnstd))]
  list(networks = networks, stations = stations, sites = sites, basin_depth_estimates = unique(basin))
}

read_c1c2 <- function() {
  xlsx <- file.path(root, "NGA_West3_C1C2_North_America_20250919.xlsx")
  raw <- as.data.table(read_excel(xlsx, sheet = 1, col_names = FALSE, .name_repair = "minimal"))
  cutoffs <- as.numeric(unlist(raw[1, seq(2, ncol(raw), by = 11), with = FALSE], use.names = FALSE))
  blocks <- vector("list", length(cutoffs))
  for (i in seq_along(cutoffs)) {
    start <- 1 + (i - 1) * 11
    dt <- raw[5:nrow(raw), start:(start + 9), with = FALSE]
    setnames(dt, c("event_id", "rrup", "rjb", "rx", "rcutoff_km", "delta_time",
                   "time_window", "class", "cluster_num", "magnitude"))
    dt[, rcutoff_km := cutoffs[i]]
    blocks[[i]] <- dt[!is.na(event_id)]
  }
  rbindlist(blocks, use.names = TRUE, fill = TRUE)
}

message("Reading metadata flatfiles")
source <- fread(csv_file("NGA_West3_Source_Metadata_20250919.csv"), showProgress = TRUE)
station <- fread(csv_file("NGA_West3_Station_Metadata_20250919.csv"), showProgress = TRUE)
h1_header <- names(fread(csv_file("NGA_West3_H1_Flatfile_20250919.csv"), nrows = 0))
h1_core <- fread(
  csv_file("NGA_West3_H1_Flatfile_20250919.csv"),
  select = h1_header[1:159],
  showProgress = TRUE
)
h1_core <- h1_core[motion_id != -999]

core <- c(
  normalize_source(source),
  normalize_station(station),
  list(
    motion_path_processing = h1_core,
    c1c2_classifications = read_c1c2(),
    documentation = read_release_docs()
  )
)
saveRDS(core, out_file("nga_west3_core_normalized.rds"), compress = "gzip")
rm(core, source, station, h1_core)
gc()

components <- c(
  H1 = "NGA_West3_H1_Flatfile_20250919.csv",
  H2 = "NGA_West3_H2_Flatfile_20250919.csv",
  V = "NGA_West3_V_Flatfile_20250919.csv",
  RotD0 = "NGA_West3_RotD0_Flatfile_20250919.csv",
  RotD50 = "NGA_West3_RotD50_Flatfile_20250919.csv",
  RotD100 = "NGA_West3_RotD100_Flatfile_20250919.csv",
  EAS = "NGA_West3_EAS_Flatfile_20250919.csv"
)

manifest_rows <- list()
for (component in names(components)) {
  message("Writing RDS for ", component)
  dt <- fread(csv_file(components[[component]]), showProgress = TRUE)
  dt <- dt[motion_id != -999]
  rds_name <- sprintf("nga_west3_%s_flatfile.rds", tolower(component))
  saveRDS(dt, out_file(rds_name), compress = "gzip")
  manifest_rows[[component]] <- data.table(component = component, file = rds_name, rows = nrow(dt), cols = ncol(dt))
  rm(dt)
  gc()
}

manifest <- rbindlist(manifest_rows, use.names = TRUE)
saveRDS(manifest, out_file("nga_west3_rds_manifest.rds"), compress = "gzip")
fwrite(manifest, out_file("nga_west3_rds_manifest.csv"))
message("RDS outputs written to: ", out_dir)
