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
# First, test with one coordinate
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

# Download all images
download_status <- download_streetview_batch(coords, API_KEY, OUTPUT_DIR)

# Save a manifest mapping each image file to its tract and coordinates
manifest <- coords %>%
  mutate(
    file_name = sprintf("%s_%s.jpg", tract_id, point_id),
    success = download_status$success
  ) %>%
  filter(success) %>% # only keep successful downloads in manifest
  select(tract_id, point_id, lat, lon, file_name)
saveRDS(manifest, here("data/processed/image_manifest.rds"))

# Quality checks and status report
# Overall success rate
success_rate <- mean(download_status$success) * 100
cat(sprintf("Downloaded %d out of %d images successfully (%.1f%% success rate).", 
            sum(download_status$success), nrow(coords), success_rate))
# Table of number of images and success rate by tract
success_by_tract <- download_status %>%
  group_by(tract_id) %>%
  summarize(
    total_images = n(),
    success_rate = mean(success) * 100,
    .groups = "drop"
  ) %>%
  arrange(success_rate)
print(sprintf("%d tracts without any successful downloads: %s", 
              sum(success_by_tract$success_rate == 0), 
              paste(success_by_tract$tract_id[success_by_tract$success_rate == 0], collapse = ", ")))
# Diagnostic visualization: histogram of success rates by tract
ggplot(success_by_tract, aes(x = success_rate)) +
  geom_histogram(binwidth = 10, fill = "blue", color = "black") +
  labs(title = "Image Download Success Rates by Tract",
       x = "Success Rate (%)",
       y = "Number of Tracts") +
  theme_minimal()
ggsave(here("output/figures/success_rate_histogram.png"), width = 6, height = 4)
