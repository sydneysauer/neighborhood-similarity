library(here)
library(tidyverse)
library(uwot)
library(sf)

source(here("R/embeddings.R"))
source(here("R/sampling.R"))

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

# ------------------------------------------------------------------------------------#
# 3.3 Maps
# Join your analysis results back to tract geometries and create maps
# ------------------------------------------------------------------------------------#

# Create crosswalk that links tract ID, PC1, PC2, and cluster to geometry
# Uses functions defined for sampling.R
all_tracts <- get_nyc_tracts()
tract_crosswalk <- all_tracts %>%
  select(tract_id = ct_code, geometry) %>%
  right_join(pca_graph %>% select(tract_id, cluster, PC1, PC2), by = "tract_id") # Join cluster info to crosswalk

# Create required maps
# 1. Cluster map: color each Census tract by its visual similarity cluster
ggplot(tract_crosswalk, aes(fill = factor(cluster))) +
  geom_sf(color = "white", size = 0.1) +
  labs(title = "Map of Census Tracts Colored by Cluster", fill = "Cluster") +
  theme_void() +
  scale_fill_manual(values = c("steelblue", "salmon", "lightgreen", "goldenrod"))
ggsave(here("output/maps/cluster_map.png"), width = 8, height = 6)
# Whoa! The clusters are pretty spatially coherent. It strikes me that group 1, which I thought based on 
# housing composition would be the wealthiest, is clustered way out of the city.

# 2. PCA map: color tracts by their score on the first principal component
ggplot(tract_crosswalk, aes(fill = PC1)) +
  geom_sf(color = "white", size = 0.1) +
  labs(title = "Map of Census Tracts Colored by PC1 Score", fill = "PC1 Score") +
  theme_void() +
  scale_fill_viridis_c()
ggsave(here("output/maps/pca_map.png"), width = 8, height = 6)
# This strikes me as pretty similar to the cluster map, especially the high contrast between the 
# cluster 1 area and the cluster 2 area versus the relatively low contrast/not many observable patterns
# between the others. It's cool that this is so consistent.

# 3. My choice: Map of tracts colored by vacancy rate (from the census data)
vacancy_map_data <- tract_crosswalk %>%
  left_join(housing_comp %>% select(tract_id, vacancy_rate), by = "tract_id")
ggplot(vacancy_map_data, aes(fill = vacancy_rate)) +
  geom_sf(color = "white", size = 0.1) +
  labs(title = "Map of Census Tracts Colored by Vacancy Rate", fill = "Vacancy Rate") +
  theme_void() +
  scale_fill_viridis_c()
ggsave(here("output/maps/vacancy_map.png"), width = 8, height = 6)
# Whoa. I knew there was a lot of missing data, but seeing this map shows me just how few tracts actually
# have vacancy data. This makes me less excited about the graph I made above. For my own project, then, I think 
# I'll pivot to a different demographic variable.

# ------------------------------------------------------------------------------------#
# 3.4 Face validity
# Required validation exercises
# ------------------------------------------------------------------------------------#

# Note: For "displaying" these, I just opened them on my computer and looked. Wasn't sure if that was supposed 
# to be part of the code, but it ended up being a lot of images so I decided just to browse manually

# 1. Most similar pairs: Find the 5 pairs of tracts with the highest cosine similarity. 
similarity_matrix[lower.tri(similarity_matrix, diag = TRUE)] <- NA # Avoid duplicates
similarity_df <- as.data.frame(as.table(similarity_matrix)) %>%
  filter(!is.na(Freq)) %>% # get rid of duplicates (since comparing all to all)
  arrange(desc(Freq)) %>%
  slice(1:5) %>% # take just the top five
  rename(tract1 = Var1, tract2 = Var2, similarity = Freq)
print("Top 5 most similar tract pairs:")
print(similarity_df)
# Notes on each of the tract's images:
    # Pair 1:
      # 36005008400: Brown, square brick 2-story apt buildings with gated yard/driveway in front. Lots of cars.
      # 36005038800: Same architecture with gated driveway in front of short brown brick homes!! Strkingly similar!!
    # Pair 2:
      # 36005031400: Cute little single-family homes, often with stone detailing amongst brick, long driveway to street
      # 36005031600: Many homes have same triangular roof above entryway, but not as similar as Pair 1.
    # Pair 3:
      # 36005038800: Same from Pair 1
      # 36005039800: Honestly looks like a mix between Pair 1 and Pair 2. 
        # I wonder if these three would all have been pretty similar if I could do a matrix comparing 3 ways.
# OK, this is hurting my eyes a bit to look through all these, so I'll skip the last two pairs because I feel 
# confident that there's face validity here. I am shocked how similar the images look, especially in Pair 1.

# 2. Most dissimilar pairs: Find the 5 pairs with the lowest similarity. Display and describe.
dissimilarity_df <- as.data.frame(as.table(similarity_matrix)) %>%
  filter(!is.na(Freq)) %>% # get rid of duplicates (since comparing all to all)
  arrange(Freq) %>%
  slice(1:5) %>% # take just the top five worst
  rename(tract1 = Var1, tract2 = Var2, similarity = Freq)
print("Top 5 most dissimilar tract pairs:")
print(dissimilarity_df)
# Notes on each of the tract's images:
    # Pair 1:
      # 36005016300: Grassy green parks with a sidewalk in front! All so similar here
      # 36061010900: Storefronts or inside stores! Colorful restaurants, boutiques, etc. So different from green grass
    # Pair 2:
      # 36005011000: All are a sidewalk/road, then a barrier (fence, median), then an open space (park, cemetery)
      # 36061010900: Same from Pair 1. This shows up a couple times, and when I looked at these photos, they were
      # also surprising to me! I should have done more validation because these are crazy photos that should not be
      # on street view -- like one is literally a bowl of lollipops in what looks like a doctor's office...
# The other top pairs all have 36061010900. I should have done this manual inspection earlier in the process and 
# dropped this tract, because it seems like a clear outlier in terms of what's in the image... weird.

# 3. Within-cluster examples: For 2-3 clusters, show representative images and describe the "character" of each
# I will do this for clusters 1 and 2, which are the most distinct.
# Print a list of 3 tracts for each cluster so I can look through:
print("Cluster 1 tracts:")
print(pca_graph %>% filter(cluster == 1) %>% slice(1:3) %>% select(tract_id))
print("Cluster 2 tracts:")
print(pca_graph %>% filter(cluster == 2) %>% slice(1:3) %>% select(tract_id))

# Cluster 1 tract manually selected representative images: 36005000200_3, 36005000400_28, 36005002000_21
    # Single fmaily homes or large apartment buildings with lots of trees, grass, open space
    # Sociological description: Spacious suburbs
# Cluster 2 tract manually selected representative images: 36061000700_17, 36061001300_21, 36061001402_3
    # Dense, downtown, coastal, commercial areas
    # Sociological description: Urban commercial districts
# These really align with the cluster map I created above -- Manhattan versus out there in the boroughs

# 4. Surprising results: Find at least one case where the embedding similarity is surprising
# The most promising place to look for this might be towards the top of the similarity list but not quite at the top
somewhat_similar_df <- as.data.frame(as.table(similarity_matrix)) %>%
  filter(!is.na(Freq)) %>% # get rid of duplicates (since comparing all to all)
  arrange(desc(Freq)) %>%
  slice(10:15) %>% # take some that are near the top buttttt not quite at the top
  rename(tract1 = Var1, tract2 = Var2, similarity = Freq)
print(somewhat_similar_df) # This similarity is still pretty high (similar to top 5) but let's inspect manually

# Manual inspection: 36005008400 vs 36005031400 (similarity = 0.669)
    # 36005008400: Even more of those homes that are offset from the street with a gated yard/driveway in front.
    # 36005031400: More of the same. Not surprising.
# Manual inspection of the least similar of this group: 36005037000 vs 36005038800 (similarity = 0.662)
    # 36005037000: More of that same architecture, but with more storefronts mixed in
    # 36005038800: OK, here's a difference! This is a much less commercial area than the one above. Where there
    # are residences, they are that same style, but there is much less variability here.

# What might explain this?? Perhaps this is a difference betweeen human perception and machine perception. To me, 
# the storefronts in the first tract of this pair really stood out as surprising, since I was seeing so much 
# homogeneity in the tract architecture. But maybe the model wouldn't be so thrown by these outliers/would get rid
# of them when I average and normalize the embeddings across the tract.