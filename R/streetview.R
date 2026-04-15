#' Download a single Street View image
#'
#' Fetches a street-level image from Google's Street View Static API
#' for a given latitude/longitude coordinate.
#'
#' @param lat Numeric, latitude
#' @param lon Numeric, longitude
#' @param api_key Character, Google API key
#' @param size Character, image dimensions (default: "640x640")
#' @param fov Integer, field of view in degrees (default: 90)
#' @param heading Integer, compass heading (default: NULL for auto)
#' @param output_path Character, file path to save the image
#' @return Logical, TRUE if image was successfully downloaded
#'
#' @examples
#' download_streetview(40.7128, -74.0060, api_key, output_path = "data/images/test.jpg")
download_streetview <- function(lat, lon, api_key, size = "640x640",
                                fov = 90, heading = NULL, output_path) {
  # Validate inputs
  if (!(is.numeric(lat) && is.numeric(lon))) {
    stop("Latitude and longitude must be numeric.")
  }
  if (!(is.character(api_key) && nchar(api_key) > 0)) {
    stop("API key must be a non-empty string.")
  }
  if (!(is.character(output_path) && nchar(output_path) > 0)) {
    stop("Output path must be a non-empty string.")
  }
  if (!(grepl("^\\d+x\\d+$", size))) {
    stop("Size must be in the format 'WIDTHxHEIGHT', e.g., '640x640'.")
  }
  if (!(is.numeric(fov) && fov >= 0 && fov <= 120)) {
    stop("Field of view (fov) must be a numeric value between 0 and 120.")
  }
  
  BASE_URL <- "https://maps.googleapis.com/maps/api/streetview"
  # Make the request to the Street View API
  # Sample query from API documentation: 
  # ?size=600x300&location=46.414382,10.013988&heading=151.78&pitch=-0.76&key=YOUR_API_KEY&signature=YOUR_SIGNATURE
  req <- request(BASE_URL) |>
    req_url_query(
      size = size,
      location = paste(lat, lon, sep = ","),
      fov = fov,
      heading = heading,
      key = api_key,
      return_error_code = "true" # Returns 404 rather than placeholder image.
    )
  resp <- req |>
    req_error(is_error = \(resp) FALSE) |> # Suppress error so we can handle it manually below
    req_perform()
  print(resp_status(resp))
  
  # Check the response status
  if (resp_status(resp) == 200) {
    # Save the image to output_path
    writeBin(resp_body_raw(resp), output_path)
    return(TRUE)
  } else {
    # Print error message for debugging
    print(sprintf("Error: %s", resp_status_desc(resp)))
    return(FALSE)
  }
}

#' Download Street View images for multiple locations
#'
#' Iterates over a tibble of coordinates, downloads images, and tracks
#' which downloads succeeded. Includes rate limiting to respect API quotas.
#'
#' @param coords Tibble with columns: tract_id, point_id, lat, lon
#' @param api_key Character, Google API key
#' @param output_dir Character, directory to save images
#' @param delay Numeric, seconds to wait between requests (default: 0.1)
#' @return Tibble with download status for each location
download_streetview_batch <- function(coords, api_key, output_dir,
                                      delay = 0.1) {
  # Validate inputs
  # TODO fill in
  # Create output directory if it doesn't exist
  print(output_dir)
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  if(!dir.exists(output_dir)) {
    stop("Output directory does not exist and could not be created.")
  } 
  # Create a results tibble to track success/failure
  results <- tibble(
    tract_id = coords$tract_id,
    point_id = coords$point_id,
    success = rep(FALSE, nrow(coords)) # set all false to begin, then change to true as images downloaded
  )
  # Download images
  for (i in 1:nrow(coords)) {
    coord <- coords[i, ]
    # Construct output path
    output_path <- file.path(output_dir, sprintf("%s_%s.jpg", coord$tract_id, coord$point_id))
    # Download image
    results$success[i] <- download_streetview(
      lat = coord$lat,
      lon = coord$lon,
      api_key = api_key,
      output_path = output_path
    )
    # Sleep and provide status update every 10 images [TODO: INCREASE tO 100(?) FOR PRODUCTION] 
    # An extremely conservative approach given the 30,000 queries/min rate limit, but allows me to monitor progress.
    if (i %% 10 == 0) {
      Sys.sleep(delay)
      print(sprintf("Downloaded %d images so far; success rate: %.1f%%", i, mean(results$success[1:i]) * 100))
    }
  }  
  
  return(results)
  # - Consider: what if the script crashes halfway? How do you resume?
}