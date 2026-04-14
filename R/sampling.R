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
  points_df <- map2_dfr(points, tracts$ct_code, ~ {
    if (is.null(.x)) return(NULL) # Skip if sampling failed
    tibble(
      tract_id = .y,
      point_id = seq_along(.x),
      geometry = .x
    )
  }) %>%
    st_as_sf()

  return(points_sf)
}