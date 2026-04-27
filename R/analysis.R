#' Take top or bottom n from similarity matrix
#' 
#' Given a similarity matrix, this function extracts the top n most similar or dissimilar pairs of tracts. 
#' It returns a tibble with the tract pairs and their similarity scores.
#' 
#' @param similarity_matrix Matrix of pairwise similarities between tracts
#' @param n Integer, number of pairs to return
#' @param similar Boolean, if TRUE returns most similar pairs, if FALSE returns most dissimilar pairs
#' @return Tibble with columns: tract1, tract2, similarity
#' 
#' Note: This function assumes that the similarity matrix is symmetric and that the diagonal 
#' (self-similarity) is NA and should be ignored.
slice_similarity <- function(similarity_matrix, n, similar = TRUE) {
  # Validation 
  if (!is.matrix(similarity_matrix)) {
    stop("Similarity_matrix must be a matrix.")
  }
  if (!is.numeric(n) || n <= 0) {
    stop("N must be a positive integer.")
  }
  if (!is.logical(similar)) {
    stop("Similar must be a boolean value.")
  }
  if (n > nrow(similarity_matrix)) {
    stop("N is too large for the number of unique pairs in the similarity matrix.")
  }
  # Filter out NA rows (such as the diagonal)
  similarity <- as.data.frame(as.table(similarity_matrix)) %>%
    filter(!is.na(Freq)) 
  # Sort by similarity if TRUE or dissimilarity if FALSE, and take the top n
  if (similar) {
    similarity <- similarity %>%
      arrange(desc(Freq)) %>%
      slice(1:n) %>% # take just the top n
      rename(tract1 = Var1, tract2 = Var2, similarity = Freq)
  } else {
    similarity <- similarity %>%
      arrange(Freq) %>%
      slice(1:n) %>% # take just the top n
      rename(tract1 = Var1, tract2 = Var2, similarity = Freq)
  }
  return(similarity)
}