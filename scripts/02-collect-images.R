library(here)
library(tidyverse)
library(httr2)
source(here("R/streetview.R"))

# Get sampled coordinates from step 1
coords <- readRDS(here("data/processed/coordinates.rds"))

# Set relevant static variables
API_KEY <- Sys.getenv("GOOGLE_STREETVIEW_KEY")
OUTPUT_DIR <- here("data/images")

# Retrieve street view images for all coordinates
# First, test with one coordinate.
test_coord <- coords %>% slice(1)
test <- download_streetview(
  lat = test_coord$lat,
  lon = test_coord$lon,
  api_key = API_KEY,
  output_path = file.path(OUTPUT_DIR, "test.jpg")
)
if (test) {
  print("Test image downloaded successfully. Proceeding to download all images.")
  # Delete image after test
  file.remove(file.path(OUTPUT_DIR, "test.jpg"))
} else {
  stop("Failed to download test image. Check API key and parameters.")
}

# Test on one of the missing images to debug
test_missing <- coords %>% filter(tract_id =="36005011000" & point_id == "1")
missing <- download_streetview(
  lat = test_missing$lat,
  lon = test_missing$lon,
  api_key = API_KEY,
  output_path = file.path(OUTPUT_DIR, "test_missing.jpg")
)

# Download all images
download_status <- download_streetview_batch(coords, API_KEY, OUTPUT_DIR)

