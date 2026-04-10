# Neighborhood Similarity Project 
### Sydney Sauer

**How can we use visual data from street view images to understand neighborhood character and how it relates to social outcomes?**

Urban sociology has long theorized about neighborhood "character" or the way physical environments shape social life. But traditional measures of neighborhoods rely on census data (income, demographics, housing), which miss the visual and aesthetic dimensions that residents actually experience. A tree-lined block of brownstones *feels* different from a block of public housing towers, even if the census tracts have similar demographics. Can we capture this?

Recent advances in multimodal AI models make it possible to convert images into dense numerical vectors (embeddings) that encode visual information. Images that look similar end up close together in embedding space; images that look different end up far apart. By collecting street view images across New York City and embedding them, we can create a new kind of neighborhood measure that is based on what places *look like* rather than who lives there.