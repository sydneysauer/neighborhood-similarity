library(tidyverse)
library(sf)
source("R/sampling.R")
source("R/spatial_functions.R")

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
points <- sample_tract_points(tracts, 5, SEED)


# Look in spatial assignment to see how to do this. Can grab them all, then select a subset.

