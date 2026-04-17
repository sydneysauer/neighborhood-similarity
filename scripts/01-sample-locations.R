library(tidyverse)
library(sf)
library(here)
source(here("R/sampling.R"))

# Set seed for uniformity 
SEED <- 317

# Get Census tract polygons for NYC and the Bronx
# Note: Limiting to just these two counties so I can get a denser sample for this project.
tracts <- get_nyc_tracts()
  # For development: Choose 10 random tracts to sample points from
  # set.seed(SEED)
  # tracts <- tracts %>% slice_sample(n = 10)

# Sample points 
# Design decisions: 
  # 01. Weight number of points by land area ntile. This will give me several points per tract where there 
  # might be substantial variation in in the built environment.
  # 02. Max number of points per tract is set by the max_per_tract parameter. Working backwards from having
  # approx 50k free Street View API calls, I want a total of 10,000 images (ample space to mess up, even though
  # I tested my development on a subset!). Thus, for 627 tracts, I set max_per_tract to 30, which gives me a total
  # of roughly 10,000 points.
points <- sample_tract_points(tracts, 30, SEED)

# Convert points to WGS84 and extract lat/lon for API
coords <- prepare_api_coords(points)

# Save coords for next pipeline step
saveRDS(coords, here("data/processed/coordinates.rds"))

