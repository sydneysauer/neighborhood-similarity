library(tidyverse)
library(sf)
source("R/sampling.R")

# Set seed for uniformity 
SEED <- 317

# Get Census tract polygons for NYC
tracts <- get_nyc_tracts()

# For development: Choose 10 random tracts to sample points from
set.seed(SEED)
tracts <- tracts %>% slice_sample(n = 10)

# Sample points 
# Design decision: Weight number of points by land area ntile. This gives me what (I hope) will be a 
# reasonable number of images to store on my computer while still having several points per tract where there 
# might be substantial variation in in the built environment.
# Will come back and increase this from 5 to more.
points <- sample_tract_points(tracts, 5, SEED)

# Convert points to WGS84 and extract lat/lon for API
coords <- prepare_api_coords(points)

