library(here)
library(tidyverse)
library(uwot)

source(here("R/embeddings.R"))

# CREATE AGGREGATE EMBEDDINGS

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
# Brief summary of tract-level embeddings
print("Tract-level embeddings generated successfully.")
print(paste("Number of tracts:", nrow(tract_embeddings)))

# ANALYZE AGGREGATE EMBEDDINGS 

# Compute cosine similarity matrix between tract embeddings
similarity_matrix <- tract_similarity(tract_embeddings)

# 3.1 Dimensionality reduction 
# Reduce the 1024-dimensional tract embeddings to 2-3 dimensions for visualization

# Linear approach: PCA
pca_result <- prcomp(tract_embeddings, center = TRUE, scale. = TRUE)
summary(pca_result)
# PC1 and PC2 seem to capture a significant portion of the variance, so we can use them for visualization
# After PC2, it drops off significantly.
# Create a scree plot showing variance explained by PCA components
pca_variance <- pca_result$sdev^2
pca_variance_explained <- pca_variance / sum(pca_variance)
scree_data <- data.frame(
  PC = paste0("PC", 1:length(pca_variance)),
  Variance_Explained = pca_variance_explained
) %>% arrange(desc(Variance_Explained)) %>% 
  mutate(PC = factor(PC, levels = PC)) # Ensure PCs are ordered by variance explained
# Filter to just the top 30 components for a clearer visualization (I started with everything, which was a mess!)
scree_data <- scree_data[1:30, ]
ggplot(scree_data, aes(x = PC, y = Variance_Explained)) +
  geom_bar(stat = "identity", fill = "steelblue") +
  labs(title = "Scree Plot of PCA Components", x = "Principal Component", y = "Proportion of Variance Explained") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
# Again, this shows that PC1 and PC2 are in a league of their own! 
ggsave(here("output/figures/pca_scree_plot.png"), width = 8, height = 6)
# Plot the PCA results based on the first two principal components
pca_graph <- as.data.frame(pca_result$x) |>
  mutate(tract_id = tract_ids)
ggplot(pca_graph, aes(x = PC1, y = PC2)) +
  geom_point() +
  labs(title = "PCA Projection of Tract Embeddings", x = "Principal Component 1", y = "Principal Component 2") +
  theme_minimal()
ggsave(here("output/figures/pca_projection.png"), width = 8, height = 6) # Shows some clusters!

# Nonlinear approach: UMAP
umap_result <- umap(tract_embeddings, n_neighbors = 15, min_dist = 0.1)
# plot this to visualize using ggplot
umap_graph <- as.data.frame(umap_result) |>
  mutate(tract_id = tract_ids)
ggplot(umap_graph, aes(x = V1, y = V2)) +
  geom_point() +
  labs(title = "UMAP Projection of Tract Embeddings", x = "UMAP Dimension 1", y = "UMAP Dimension 2") +
  theme_minimal()
ggsave(here("output/figures/umap_projection.png"), width = 8, height = 6) # Shows some clusters!

# The UMAP projection shows more distinct clusers, so let's dig in here.

