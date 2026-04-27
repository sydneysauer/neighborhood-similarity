library(here)
library(tidyverse)

source(here("R/streetview.R"))

# ------------------------------------------------------------------------------------#
# DATA CLEANING AND PREPROCESSING
# ------------------------------------------------------------------------------------#

# Load census data 
census_data <- read_csv(here("data/census/nyc_tract_data.csv")) 
census_data <- census_data %>%
  select(tract_id = GeoID, spouse = Spouse, spouse_opp = OpSxS, spouse_same = SmSxS, 
                          partner = UMrdPtnr, partner_opp = OpSxUMrd, partner_same = SmSxUMrd) %>%
  # Make these all numeric (imported as characters)
  mutate_if(is.character, as.numeric) %>%
  mutate(tract_id = as.character(tract_id))
# Examine missingness
colSums(is.na(census_data)) 
# None NA seems too good to be true, but these are key vars, so maybe? Manual inspection looks good.

# Create outcome variable: Percentage of partnerships (married or unmarried) that are same-sex
census_data <- census_data %>%
  mutate(total_partnerships = spouse + partner,
         same_sex_partnerships = spouse_same + partner_same,
         pct_same_sex = same_sex_partnerships / total_partnerships)
summary(census_data$pct_same_sex)
# Histogram to see distribution of outcome
ggplot(census_data, aes(x = pct_same_sex)) +
  geom_histogram(binwidth = 0.01, fill = "blue", color = "black") +
  labs(title = "Distribution of Percentage of Same-Sex Partnerships by Tract",
       x = "Percentage of Same-Sex Partnerships",
       y = "Count") +
  theme_minimal() 
# There are a few outliers on round numbers: 0.5, 0.75, and 1.0. Remove if > 0.25.
# Otherwise, decent variation in outcome.
census_data <- census_data %>%
  filter(pct_same_sex <= 0.25)

# ------------------------------------------------------------------------------------#
# ANALYSIS
# ------------------------------------------------------------------------------------#

# Q1a: How visually distinct is a historically LGBTQ neighborhood?
# Reference neighborhood: Greenwich Village (36061007300)
ref_tract <- "36061007300" # Greenwich Village

# Compute cosine similarity between reference tract and all others
ref_embedding <- tract_embeddings[which(tract_ids == ref_tract), ]
similarities <- tract_embeddings %*% ref_embedding # Can't use my function since not comparing all tracts
similarity_df <- data.frame(tract_id = tract_ids, similarity = similarities) %>%
  arrange(desc(similarity)) %>%
  filter(tract_id != ref_tract) %>% # Drop self-similarity
  left_join(census_data %>% select(tract_id, pct_same_sex), by = "tract_id")
head(similarity_df)

# Map: Gradient of similarity to Greenwich Village
all_tracts <- get_nyc_tracts() %>% rename(tract_id = ct_code) # Get geometries
similarity_map <- all_tracts %>%
  left_join(similarity_df, by = "tract_id")
greenwich_village_geom <- all_tracts %>% filter(tract_id == ref_tract)
ggplot(similarity_map) +
  geom_sf(aes(fill = similarity), color = "white", size = 0.1) +
  geom_sf(data = greenwich_village_geom, fill = "green", color = "black", size = 0.5) +
  labs(title = "Similarity of NYC Tracts to Greenwich Village (Green)",
       fill = "Similarity") +
  # Make it darker when more similar
  scale_fill_gradient(low = "lightblue", high = "darkblue", na.value = "lightgray") +
  theme_void() +
  theme(legend.position = "bottom")
ggsave(here("output/maps/greenwich_village_similarity_map.png"), width = 8, height = 10)
# This map is a bit unclear because so many tracts are so similar to Greenwich Village.

# Q1b: Do tracts that are more similar to Greenwich Village have higher percentages of same-sex couples?
cor(similarity_df$similarity, similarity_df$pct_same_sex, use = "complete.obs")
# Pretty low correlation of 0.2. Some association between this "look" and LGBTQ concentration.
# Let's graph the relationship.
ggplot(similarity_df, aes(x = similarity, y = pct_same_sex)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(title = "Similarity to Greenwich Village and LGBTQ+ Population",
       x = "Similarity to Greenwich Village",
       y = "Percentage of Same-Sex Couples") + 
  theme_minimal()
ggsave(here("output/figures/similarity_vs_lgbtq_population.png"), width = 8, height = 6)
# Conclusion: A slight positive relationship between this visual "feel" and queer population.

# Q2: Regardless of a specific reference tract, do LGBTQ neighborhoods cluster together visually?
# PCA analysis
pca_result <- prcomp(tract_embeddings, center = TRUE, scale. = TRUE)
# Create scree plot to see how much variance is explained by each component
scree_data <- data.frame(
  PC = paste0("PC", 1:length(pca_variance)),
  Variance_Explained = pca_variance_explained
) %>% arrange(desc(Variance_Explained)) %>% 
  mutate(PC = factor(PC, levels = PC)) 
head(scree_data) # PC1 and PC2 much larger than the rest! Stick with 2D analysis.
pca_df <- data.frame(tract_id = tract_ids, PC1 = pca_result$x[, 1], PC2 = pca_result$x[, 2]) %>%
  left_join(census_data %>% select(tract_id, pct_same_sex), by = "tract_id") %>%
  # Hard to see with continuous, so make categorical with cutpoint of top quartile
  mutate(lgbtq_category = case_when(
    pct_same_sex >= quantile(pct_same_sex, 0.75, na.rm = TRUE) ~ "High LGBTQ+",
    pct_same_sex >= quantile(pct_same_sex, 0.5, na.rm = TRUE) ~ "Medium LGBTQ+",
    TRUE ~ "Low LGBTQ+"
  )) %>%
  # Set levels for better color ordering
  mutate(lgbtq_category = factor(lgbtq_category, levels = c("Low LGBTQ+", "Medium LGBTQ+", "High LGBTQ+")))
ggplot(pca_df, aes(x = PC1, y = PC2, color = lgbtq_category)) +
  geom_point() +
  labs(title = "PCA of Tract Embeddings Colored by LGBTQ+ Population",
       x = "Principal Component 1",
       y = "Principal Component 2",
       color = "LGBTQ+ Category") +
  theme_minimal()
ggsave(here("output/figures/pca_colored_by_lgbtq_population.png"), width = 8, height = 6)
# Conclusion: There is some separation of Low and High among PC1. PC2 does not seem to matter for this.
