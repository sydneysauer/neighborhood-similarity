library(here)
library(tidyverse)

source(here("R/embeddings.R"))

# Load embeddings and manifest
raw_embeddings <- read_rds(here("data/embeddings/embeddings.rds"))
embeddings <- raw_embeddings |>
  purrr::map(~ as.numeric(unlist(.x, use.names = FALSE))) |>
  do.call(what = rbind)
storage.mode(embeddings) <- "double"
manifest <- read_rds(here("data/processed/embedding_manifest.rds"))

# Calculate aggregate embeddings at the tract level
# NOTE: This takes a while to run because the function is inefficient, but I could not figure out a 
# faster solution. This would be an area to improve in the future!
aggregate_results <- aggregate_tract_embeddings(embeddings, manifest)
tract_embeddings <- aggregate_results[[1]]
tract_ids <- aggregate_results[[2]]

# Push tract-level embeddings and tract IDs to disk for use in later steps of the pipeline
write_rds(
  aggregate_results,
  here("data/processed/tract_embeddings.rds")
)

# Compute cosine similarity matrix between tract embeddings
similarity_matrix <- tract_similarity(tract_embeddings)