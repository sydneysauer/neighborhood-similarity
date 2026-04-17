#' Download and prepare NYC Census tract boundaries
#'
#' Downloads tract shapefiles from the US Census Bureau via the tigris
#' package and standardizes column names. NYC spans five counties
#' (Manhattan=061, Brooklyn=047, Queens=081, Bronx=005, Staten Island=085).
#'
#' @param year Integer, Census year for tract boundaries (default: 2010)
#' @param crs Integer, EPSG code for coordinate reference system (default: 2263)
#' @return sf object with columns: ct_code, area_land, area_water, geometry
#'
#' @examples
#' tracts <- get_nyc_tracts()
#' plot(st_geometry(tracts))
get_nyc_tracts <- function(year = 2010, crs = 2263) {
  # Note: Limiting to just New York and the Bronx so I can get a denser sample for this project. 
  codes <- c("061", "005") # All counties: c("061", "047", "081", "005", "085")
  tracts_list <- lapply(codes, function(code) {
    tigris::tracts(state = "NY", county = code, year = year, class = "sf") %>%
      select(ct_code = GEOID10, area_land = ALAND10, area_water = AWATER10) %>%
      st_transform(crs)
  })
  do.call(rbind, tracts_list)
}

#' Sample random points within Census tract polygons
#'
#' Generates random geographic coordinates within each Census tract.
#' The number of points per tract is determined by the land area ntile, 
#' where n is set by the parameter max_per_tract.
#' Uses sf::st_sample() to create spatially random points within polygons.
#'
#' @param tracts sf object with Census tract polygons
#' @param max_per_tract Integer, max number of points to sample per tract
#' @param seed Integer, random seed for reproducibility
#' @return sf object with columns: tract_id, point_id, geometry (POINT)
#'
#' @examples
#' tracts <- get_nyc_tracts()
#' sample_pts <- sample_tract_points(tracts, max_per_tract = 4, seed = 42)
sample_tract_points <- function(tracts, max_per_tract = 5, seed = 123) {
  # TODO: Validation here? Is there a max value for max_per_tract? Make sure tracts is sf?
  set.seed(seed)
  # Generate number of points for each tract based on the specified max_per_tract
  tracts <- tracts %>%
    mutate(n_points = ntile(area_land, max_per_tract))
  # Sample points
  points <- map2(tracts$geometry, tracts$n_points, ~ {
    tryCatch(
      st_sample(.x, size = .y),
      error = function(e) {
        message(sprintf("Error sampling points for tract %s: %s", 
        tracts$ct_code[which(tracts$geometry == .x)], e$message))
        return(NULL) # Return NULL on error to avoid breaking the loop
      }
    )
  })
  # Convert rows (currently one row per tract, with a list of points) into one row per point with tract and point IDs
  points_sf <- map2_dfr(points, tracts$ct_code, ~ {
    if (is.null(.x)) return(NULL) # Skip if sampling failed
    tibble(
      tract_id = .y,
      point_id = seq_along(.x),
      geometry = .x
    )
  }) %>%
    st_as_sf() 
  # %>% st_set_crs(st_crs(tracts))

  st_crs(points_sf) <- st_crs(tracts)
  return(points_sf)
}

#' Prepare sample points for Street View API
#'
#' Transforms spatial points to WGS84 and extracts lat/lon as a tibble.
#'
#' @param points sf object with POINT geometry
#' @return Tibble with columns: tract_id, point_id, lat, lon
prepare_api_coords <- function(points) {
  # Get the coordinates
  points <- st_transform(points, 4326) # Convert to WGS84
  coords <- st_coordinates(points) 
  # Bind columns back to the tract/point IDs
  api_coords <- points %>%
    st_drop_geometry() %>%
    bind_cols(as_tibble(coords)) %>%
    rename(lon = X, lat = Y)
  return(api_coords)
}