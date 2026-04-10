#' Sample random points within Census tract polygons
#'
#' Generates random geographic coordinates within each Census tract.
#' Uses sf::st_sample() to create spatially random points within polygons.
#'
#' @param tracts sf object with Census tract polygons
#' @param n_per_tract Integer, number of points to sample per tract (default: 4)
#' @param seed Integer, random seed for reproducibility
#' @return sf object with columns: tract_id, point_id, geometry (POINT)
#'
#' @examples
#' tracts <- get_nyc_tracts()
#' sample_pts <- sample_tract_points(tracts, n_per_tract = 4, seed = 42)
sample_tract_points <- function(tracts, n_per_tract = 4, seed = 123) {
  set.seed(seed)
  points <- map(tracts$geometry, ~ {
    tryCatch({
      st_sample(.x, size = n_per_tract)
    }, error = function(e) {
      # If sampling fails (e.g., due to small area), return NULL
      NULL
      stop("Sampling failed for tract.")
    })
  })
  # Combine points into a single sf object
  points_sf <- do.call(rbind, points)
  # Create tract_id and point_id columns
  points_sf <- st_sf(
    tract_id = rep(tracts$tract_id, each = n_per_tract),
    point_id = rep(1:n_per_tract, times = nrow(tracts)),
    geometry = st_sfc(points_sf)
  )
  return(points_sf)
  # Your code here
  # Hints:
  # - Set seed for reproducibility
  # - Loop or map over tracts, calling st_sample(tract, size = n_per_tract)
  # - Combine results into a single sf object
  # - Add tract_id and point_id columns
  # - Some tracts may be very small (parks, water) --- handle failures gracefully
}