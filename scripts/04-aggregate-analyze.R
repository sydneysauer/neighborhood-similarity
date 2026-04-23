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

# ------------------------------------------------------------------------------------#
# 3.1 Dimensionality reduction 
# Reduce the 1024-dimensional tract embeddings to 2-3 dimensions for visualization
# ------------------------------------------------------------------------------------#

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

# Let's merge with Census tract-level data to see if we can identify any patterns in the PCA clusters.
census_data <- read.csv(here("data/census/nyc_tract_data.csv")) %>%
  mutate(tract_id = as.character(GeoID))
# Merge with PCA graph data to color points by borough
pca_graph <- pca_graph %>%
  left_join(census_data, by = "tract_id")
pca_graph$Borough[is.na(pca_graph$Borough)] <- "Other" # Handle any missing boroughs
ggplot(pca_graph, aes(x = PC1, y = PC2, color = Borough)) +
  geom_point() +
  labs(title = "PCA Projection of Tract Embeddings Colored by Borough", 
        x = "Principal Component 1", y = "Principal Component 2") +
  theme_minimal()
ggsave(here("output/figures/pca_projection_borough.png"), width = 8, height = 6)
# Shows some clear clustering by borough!

# ------------------------------------------------------------------------------------#
# 3.2 Clustering
# Group tracts by visual similarity (k-means clustering on the tract embeddings)
# ------------------------------------------------------------------------------------#

# Try a few k-values
set.seed(317) # Set seed for reproducibility
km <- kmeans(tract_embeddings, centers = 6)
table(km$cluster) # Relatively unbalanced across clusters
# Try another k value
km <- kmeans(tract_embeddings, centers = 4)
table(km$cluster) # This puts over 200 tracts in group 2, so maybe I want a larger k
km <- kmeans(tract_embeddings, centers = 8)
table(km$cluster) # This is more balanced, so I'll go with this!

# I made a graph of this mapped to the PCA chart, but a lot was going on with k=8.
# So I decided to overwrite this and simplify down to k=4.
km <- kmeans(tract_embeddings, centers = 4)
table(km$cluster) # This is more balanced, so I'll go with this!
pca_graph <- pca_graph %>%
  mutate(cluster = factor(km$cluster))
ggplot(pca_graph, aes(x = PC1, y = PC2, color = cluster)) +
  geom_point() +
  labs(title = "PCA Projection of Tract Embeddings Colored by Cluster", 
        x = "Principal Component 1", y = "Principal Component 2") +
  theme_minimal()
ggsave(here("output/figures/pca_projection_cluster.png"), width = 8, height = 6)
# This is MUCH clearer to me and matches what I would have noticed visually.

# Now I want to compare the built environment in each cluster. 
# First, clean Census data into a smaller dataset
housing_comp <- census_data %>%
  # Total housing units, vacant units, owner-occupied units, renter-occupied units
  select(tract_id, HUnits, VacHUs, OOcHU_1, ROcHU_1) %>%
  mutate(
    HUnits = as.numeric(HUnits),
    VacHUs = as.numeric(VacHUs),
    OOcHU_1 = as.numeric(OOcHU_1),
    ROcHU_1 = as.numeric(ROcHU_1)
  )
# See how many missing after NA coercion (wow, a lot!)
colSums(is.na(housing_comp))
# A lot missing. Will carry on to see how this pans out once we average across tracts in the cluster.
housing_comp <- housing_comp %>%
  mutate(
    vacancy_rate = VacHUs / HUnits,
    own_rate = OOcHU_1 / HUnits,
    rent_rate = ROcHU_1 / HUnits
  ) %>%
  select(tract_id, vacancy_rate, own_rate, rent_rate)
head(housing_comp)
# Link to tracts and summarize
cluster_means <- pca_graph %>%
  left_join(housing_comp, by = "tract_id") %>%
  group_by(cluster) %>%
  summarize(
    mean_vacancy_rate = mean(vacancy_rate, na.rm = TRUE),
    mean_own_rate = mean(own_rate, na.rm = TRUE),
    mean_rent_rate = mean(rent_rate, na.rm = TRUE)
  )
# Visualize: Stacked bar chart of mean rates by cluster
cluster_means_long <- cluster_means %>%
  pivot_longer(cols = starts_with("mean_"), names_to = "rate_type", values_to = "mean_rate") %>%
  mutate(rate_type = recode(rate_type,
                            "mean_vacancy_rate" = "Vacancy Rate",
                            "mean_own_rate" = "Ownership Rate",
                            "mean_rent_rate" = "Rentership Rate"))
ggplot(cluster_means_long, aes(x = cluster, y = mean_rate, fill = rate_type)) +
  geom_bar(stat = "identity", position = "stack") +
  labs(title = "Housing Unit Status by Cluster", x = "Cluster", y = "Mean Rate", fill="Housing Unit Status") +
  theme_minimal() +
  scale_fill_manual(values = c("steelblue", "salmon", "lightgreen"))
ggsave(here("output/figures/cluster_housing_rates.png"), width = 8, height = 6)
# This visualization is super interesting! 
    # Cluster 1: Clearly high home ownership, likely the wealthiest cluster.
    # Cluster 2: High rentership, low vacancy, feels like working-class neighborhoods.
    # Clusters 3 and 4: Not easily distinguishable. Seems like the lower-class -- high vacancy.