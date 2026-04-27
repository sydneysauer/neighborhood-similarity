# Research Report: LGBTQ+ Diffusion and Neighborhood Feel

### Sydney Sauer

------------------------------------------------------------------------

### Introduction

The 1969 Stonewall riots in New York City's Greenwich Village were a major turning point for LGBTQ+ history. In the intervening 50 years, societal acceptance of gay, lesbian, and other queer couples has increased dramatically. Once confined to neighborhoods like Greenwich Village and their clandestine bars, queer spaces have opened up in neighborhoods across the country. While full acceptance is yet to come, LGBTQ+ Americans today experience far greater freedom of expression, visibility, and cultural diffusion than two generations ago.

My research project explores whether queer neighborhoods (sometimes called "gayborhoods") retain a distinct visual feel despite the wider spread of queer people and culture. I tackle this in two interrelated questions. First, how visually distinct from other nearby neighborhoods are historically significant gayborhoods today? My analysis centers on the case of Greenwich Village and compares its visual similarity in embedding space to 535 other Census tracts in New York and The Bronx. Second, are any identifiable visual components of neighborhoods correlated with the density of their queer population? For this analysis, I use principal components analysis (PCA) on the same dataset of 536 neighborhoods across New York and The Bronx to chart how certain neighborhood characteristics correlate with LGBTQ+ population density.

When marginalized groups become more accepted in society, this produces a tension in urban areas between achieving spatial integration and retaining the group's distinctive culture. My descriptive questions aim to clarify the balance of these two factors for queer residents of NYC.

### Data and Methods

I answer these research questions using image embeddings of randomly sampled Google Street View locations throughout New York and The Bronx. I selected these two subregions of the greater NYC area, rather than including other boroughs like Brookyln and Queens, to get a richer density of sample images within my API resource constraints and to avoid sampling across large geographic discontinuities (i.e., water between Manhattan and Brooklyn) that might introduce noise into the data collection. This yielded 627 Census tracts.

I then used Google Street View to sample between 1 and 30 street-level images per tract, weighted by the tract's land area ntile (n=30). I chose to weight by ntile to get more points for larger areas, which might have greater geographic variation in neighborhood "feel," and avoid oversampling in small areas. I back-calculated from a desired sample size of around 10,000 images (based on conservative estimates of API usage) to set the ntile/maximum number of images per tract to 30. While this approach allowed me to carefully control and weight the number of images per tract, it had a significant design flaw of pulling an inadequate number of images for the smallest tracts. Additionally, since coordinates were randomly sampled, some locations did not have a Google Street View image available. Two tracts had no successful downloads, but most tracts had a near-perfect image download success rate (Figure 1), leading to an overall success rate of pulling 8,440 total Street View images for 87.2% of randomly sampled coordinates. After dropping 91 tracts for which I had less than five images (due to either the sampling criteria or missing Street View data), this yielded a final analytic sample of 8,219 images across 536 tracts.

**Figure 1.** Google Street View Image Sampling Success Rate

![](output/figures/success_rate_histogram.png)