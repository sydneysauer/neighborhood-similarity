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
} else {
  stop("Failed to download test image. Check API key and parameters.")
}

# Download all images


