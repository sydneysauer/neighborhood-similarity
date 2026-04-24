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

# Goal: Manually select a gayborhood tract and see if most similar tracts are also gayborhoods.
# Reference neighborhood: Chelsea (36061008900)
# According to this map: https://www.nyc.gov/html/mancb4/downloads/pdf/censustracts.PDF
# Reason: Chelsea is historically a gay area, but people can now disperse! Does the same style travel?
ref_tract <- "36061008900"

# Compute cosine similarity between reference tract and all others
ref_embedding <- tract_embeddings[which(tract_ids == ref_tract), ]
similarities <- tract_embeddings %*% ref_embedding # Can't use my function since not comparing all tracts
similarity_df <- data.frame(tract_id = tract_ids, similarity = similarities) %>%
  arrange(desc(similarity)) %>%
  filter(tract_id != ref_tract) %>% # Drop self-similarity
  left_join(census_data %>% select(tract_id, pct_same_sex), by = "tract_id")
head(similarity_df)

# Correlation between similarity to Chelsea and percentage of same-sex couples
cor(similarity_df$similarity, similarity_df$pct_same_sex, use = "complete.obs")
# Strikingly low correlation of 0.02! 

# Map: Gradient of similarity to Chelsea
all_tracts <- get_nyc_tracts() %>% rename(tract_id = ct_code) # Get geometries
similarity_map <- all_tracts %>%
  left_join(similarity_df, by = "tract_id")
chelsea_geom <- all_tracts %>% filter(tract_id == ref_tract)
ggplot(similarity_map) +
  geom_sf(aes(fill = similarity), color = "white", size = 0.1) +
  geom_sf(data = chelsea_geom, fill = "green", color = "black", size = 0.5) +
  labs(title = "Similarity of NYC Tracts to Chelsea",
       fill = "Similarity") +
  # Make it darker when more similar
  scale_fill_gradient(low = "lightblue", high = "darkblue", na.value = "lightgray") +
  theme_void() +
  theme(legend.position = "bottom")
ggsave(here("output/maps/chelsea_similarity_map.png"), width = 8, height = 10)
# This map is a bit unclear because so many tracts are so similar to Chelsea.