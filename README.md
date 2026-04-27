# Neighborhood Similarity Project

### Sydney Sauer

## Project Overview

This project aims to explore the visual similarity of neighborhoods in New York City and investigate how these visual characteristics relate to social outcomes, particularly the distribution of LGBTQ+ populations. It uses random sampling of Google Street View images, which are then processed using a multimodal embedding model from Voyage AI, to create a new kind of neighborhood measure based on visual appearance.

**Required packages:** `here`, `tidyverse`, `uwot`, `sf`, `httr2`, `base64enc`, `jsonlite`

**Required APIs:** Google Street View, Voyage AI

## File Structure

The analysis pipeline is split into five parts in the 'scripts' directory, with helper functions defined in the 'R' directory. The 'data' directory (much of which is not included in this repository due to size) contains the raw data and intermediate outputs from each step of the analysis. Finally, the 'output' directory contains the final results and visualizations, including several maps.

Note that all file paths in the code are relative to the root directory (using the required `here` package).

*Scripts Processing Pipeline:*

1.  `01-sample-locations.R`: Samples coordinates within specified NYC boundaries
2.  `02-collect-images.R`: Downloads images from coordinates using Google Street View API
3.  `03-generate-embeddings.R`: Generates image embeddings using Voyage AI multimodal 3.5 model
4.  `04-aggregate-analyze.R`: Aggregates embeddings to the tract level and analyzes results
5.  `05-validate-extend.R`: Extends analysis to specific questions about LGBTQ population

*R source files for helper functions:*

1.  `embeddings.R`: Contains functions for processing and manipulating embeddings
2.  `sampling.R`: Contains functions for downloading NYC tracts and sampling coordinates
3.  `streetview.R`: Contains functions for processing Google Street View API calls

## Reproducing the Pipeline

To reproduce the pipeline:

1.  Ensure the required packages (listed above) are installed.
2.  Download the 2020 NYC Census Tract data (clipped to shoreline) [here](https://www.nyc.gov/content/planning/pages/resources/datasets/census-tracts).
3.  Edit your .Renviron file to include the necessary environment variables for API keys. (Note: all analyses in the pipeline are designed to not exceed the free quotas for the Google Street View and Voyage APIs.)
4.  Run the data processing scripts in the 'scripts' directory in order, from 01 to 05.