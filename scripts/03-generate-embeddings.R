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

# Test API connection with a sample image
test_file <- image_files[1] # Adjust the number as needed for testing
test_embedding <- embed_image(test_file, VOYAGE_API_KEY)
if (!is.null(test_embedding)) {
  print("API connection successful. Sample embedding generated.\n")
} else {
  stop("API connection failed. Check the API key and endpoint.\n")
}

# Generate embeddings for all images in batches
BATCH_SIZE <- 50
embedding_and_manifest <- embed_images_batch(image_files, VOYAGE_API_KEY, batch_size = BATCH_SIZE, delay=3)

# Edit and save manifest
manifest <- embedding_and_manifest[[2]] %>%
  mutate(embedding_id = row_number()) %>% # Add an ID column for easier referencing
  mutate(tract_id = str_extract(file_path,"(?<=/)\\d+(?=_)")) # Extract tract ID from file paths
write_rds(manifest %>%
    select(tract_id, embedding_id), here("data/processed/embedding_manifest.rds"))

# Quality checks
length(embeddings) # Check dimensions of the embeddings matrix
num_embedded <- sum(!sapply(embeddings, is.null))
print(paste("Successfully embedded", num_embedded, "out of", length(embeddings), "images."))
print(paste("Number of unique tracts represented:", length(unique(manifest$tract_id))))