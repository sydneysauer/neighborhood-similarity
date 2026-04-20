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
  } else {
    warning(paste("API call failed for image:", image_path, "- Status code:", resp_status(resp)))
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
  # Your code here
  # Hints:
  # - Process images one at a time (or in small batches if the API supports it)
  # - Store results in a list, then rbind into a matrix at the end
  # - Track which images succeeded/failed
  # - Save intermediate results periodically (every 100 images)
  #   so you don't lose everything on a crash
  # - Print progress
}