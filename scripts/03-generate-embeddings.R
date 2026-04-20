library(here)
library(tidyverse)
library(base64enc)
library(jsonlite)
library(httr2)

source(here("R/embeddings.R"))

# Set constants for API call
VOYAGE_API_KEY <- Sys.getenv("VOYAGE_API_KEY")

# Load image file paths
image_dir <- "data/images"
image_files <- list.files(image_dir, pattern = "\\.jpg$", full.names = TRUE)

# Test a subset of images 
test_files <- image_files[1:3] # Adjust the number as needed for testing
embeddings_list <- lapply(test_files, function(img_path) {
  embed_image(img_path, VOYAGE_API_KEY)
})

# This seems to be working! Next up, change this test to run in the full function.