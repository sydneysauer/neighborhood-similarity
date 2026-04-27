#' Generate an embedding for a single image
#'
#' Sends an image to the Voyage AI API and returns the embedding vector.
#'
#' @param image_path Character, path to a JPEG image file
#' @param api_key Character, Voyage AI API key
#' @param model Character, model name (default: "voyage-multimodal-3.5")
#' @return Numeric vector (the embedding), or NULL on failure
#'
#' @examples
#' emb <- embed_image("data/images/061000100_1.jpg", api_key)
#' length(emb)  # Embedding dimension (1024 for voyage-multimodal-3.5)
embed_image <- function(image_path, api_key, model = "voyage-multimodal-3.5") {

  # Validation
  if (!file.exists(image_path)) {
    warning(paste("File does not exist:", image_path))
    return(NULL)
  }

  # Read and encode the image
  img_base64 <- tryCatch({
    paste0("data:image/jpeg;base64,", base64enc::base64encode(image_path))
  }, error = function(e) {    warning(paste("Failed to read/encode image:", image_path, "-", e$message))
    return(NULL)
  })

  # Prepare API request using httr2
  VOYAGE_ENDPOINT <- "https://api.voyageai.com/v1/multimodalembeddings"
  body <- list(
    inputs = list(
    list(
      content = list(
        list(type = "image_base64", image_base64 = img_base64)
      )
    )
  ),
    model = model
  )
  # Preview body as JSON (print for debug)
  # jsonbody <- jsonlite::toJSON(body, auto_unbox = TRUE, pretty = TRUE)
  # print(jsonbody) # Debug: print the JSON body

  req <- request(VOYAGE_ENDPOINT) |>
    req_headers(
      Authorization = paste("Bearer", api_key),
      `content-type` = "application/json",
    ) |> 
    req_body_json(body, auto_unbox = TRUE)
  resp <- req |> 
    req_error(is_error = \(resp) FALSE) |> # Suppress error so we can handle it manually below
    req_perform()

  # Check response status
  if (resp_status(resp) == 200) {
   # Parse the response to extract the embedding vector
    resp_content <- resp_body_json(resp)
    embedding <- resp_content$data[[1]]$embedding
    return(embedding)
  } else if (resp_status(resp) == 404) {
    print(paste("Image not found:", image_path))
    return(NULL)
  } else if (resp_status(resp) == 429) {
    print(resp_body_string(resp)) # Print the error message from the API
    stop("Rate limit exceeded: Consider adding a delay between requests.")
    return(NULL)
  } else {
    stop(paste("API call failed for image:", image_path, "- Status code:", resp_status(resp)))
    return(NULL)
  }
}

#' Generate embeddings for a batch of images
#'
#' Processes multiple images and returns a matrix of embeddings.
#' Includes rate limiting and progress tracking.
#'
#' @param image_paths Character vector of file paths
#' @param api_key Character, Voyage AI API key
#' @param batch_size Integer, images per API call (default: 1)
#' @param delay Numeric, seconds between API calls (default: 0.5)
#' @return List with: embeddings (matrix), manifest (tibble mapping rows to files)
embed_images_batch <- function(image_paths, api_key, batch_size = 1,
                                delay = 0.5) {
  results <- list()
  # Process images in batches
  for (i in seq(1, length(image_paths), by = batch_size)) {
    batch_paths <- image_paths[i:min(i + batch_size - 1, length(image_paths))]
    print(paste("Processing batch:", i, "to", min(i + batch_size - 1, length(image_paths))))
    batch_embeddings <- lapply(batch_paths, embed_image, api_key = api_key)
    
    # Store results
    for (j in seq_along(batch_paths)) {
      results[[batch_paths[j]]] <- batch_embeddings[[j]]
    }
    write_rds(results, here("data/embeddings/embeddings.rds")) # Save intermediate results
    
    # Print progress
    cat(sprintf("Processed %d/%d images\n", min(i + batch_size - 1, length(image_paths)), length(image_paths)))
    
    # Delay to respect rate limits
    Sys.sleep(delay)
  }
  # Create a manifest tibble mapping file paths to embeddings
  manifest <- tibble(
    file_path = names(results),
    embedding = results
  )

  return(list(results, manifest)) # this is redundant -- whoops!!!
}

#' Aggregate image embeddings to Census tract level
#'
#' Computes a tract-level embedding by averaging the image-level
#' embeddings for all images within each tract.
#'
#' @param embeddings Matrix, one row per image (from embed_images_batch)
#' @param manifest Tibble with tract_id for each row of embeddings
#' @param min_images Integer, minimum number of images required to compute a tract embedding (default: 5)
#' @return List with: tract_embeddings (matrix), tract_ids (character vector)
aggregate_tract_embeddings <- function(embeddings, manifest, min_images = 5) {
  # Validation
  if (!is.matrix(embeddings) || !is.numeric(embeddings)) {
    stop("`embeddings` must be a numeric matrix.")
  }
  if (nrow(embeddings) != nrow(manifest)) {
    stop("Number of rows in `embeddings` must match number of rows in `manifest`.")
  }
  if (!"tract_id" %in% names(manifest)) {
    stop("`manifest` must contain a `tract_id` column.")
  }
  # Match up embeddings with tract_ids
  idx_by_tract <- split(seq_len(nrow(manifest)), manifest$tract_id)
  idx_by_tract <- idx_by_tract[lengths(idx_by_tract) >= 5]

  # NOTE:
  # I realize now that I made a mistake early in data collection that I cannot fix due to 
  # resource constraints. By setting the number of images per tract based on the ntile, some tracts
  # have very few images, which is not ideal for averaging across! This means dropping rows with less 
  # than 5 images filters out the smallest tracts (by land area). This has taught me in the future to 
  # really understand all steps of the analysis process when making big design decisions--especially 
  # when I have a limited number of API credits to go back and fix mistakes down the line.
  # In the end, this only dropped 89 of the 625 tracts, but again, this introduces a systematic bias
  # against small land area tracts (which might have great population density).

  tract_embeddings <- do.call(
    rbind,
    lapply(
      idx_by_tract,
      \(idx) colMeans(embeddings[idx, , drop = FALSE], na.rm = TRUE)
    )
  )
  tract_ids <- names(idx_by_tract)

  # L2 normalize the tract embeddings to facilitate cosine similarity comparisons later on
  tract_embeddings <- tract_embeddings / sqrt(rowSums(tract_embeddings^2))

  list(
    tract_embeddings = tract_embeddings,
    tract_ids = tract_ids
  )
}

#' Compute cosine similarity matrix between tract embeddings
#'
#' @param embeddings Matrix, one row per tract (L2-normalized)
#' @return Matrix of pairwise cosine similarities
tract_similarity <- function(embeddings) {
  # Cosine similarity between L2-normalized vectors is just the dot product
  similarity_matrix <- embeddings %*% t(embeddings) # Compare each tract embedding to every other tract embedding
  return(similarity_matrix)
}