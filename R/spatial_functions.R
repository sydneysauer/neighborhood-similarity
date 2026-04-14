
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
  codes <- c("061", "047", "081", "005", "085")
  tracts_list <- lapply(codes, function(code) {
    tigris::tracts(state = "NY", county = code, year = year, class = "sf") %>%
      select(ct_code = GEOID10, area_land = ALAND10, area_water = AWATER10) %>%
      st_transform(crs)
  })
  do.call(rbind, tracts_list)
}