library(readr)
library(here)

#' Load and Validate Topics
#'
#' Reads a txt file without headers.
#' Validates that there are exactly 2 columns and unique topic IDs.
#'
#' @param file_path String. The full path to the file.
#' @return A tibble with columns `id` and `label`.
#' @examples
#' topics <- load_topics(here("data/topics.txt"))
load_topics <- function(file_path) {
  # Check if file exists to avoid obscure readr errors
  if (!file.exists(file_path)) {
    stop(paste("File not found at:", file_path))
  }

  # Read data (col_names = FALSE because the file has no header)
  df <- read_csv(
    file_path,
    col_names = FALSE,
    col_types = "cc",
    show_col_types = FALSE
  )

  # Sanity Check 1: Dimensions
  if (ncol(df) != 2) {
    stop(paste0(
      "Structure Error: The file must have exactly 2 columns. ",
      "Found ",
      ncol(df),
      " columns. ",
      "Check if you have extra commas in your text values."
    ))
  }

  # Rename for consistency
  names(df) <- c("topic_id", "label")

  # Sanity Check 2: Unique IDs
  if (any(duplicated(df$topic_id))) {
    dupes <- unique(df$topic_id[duplicated(df$topic_id)])
    stop(paste0(
      "Integrity Error: Topic IDs must be unique.\n",
      "The following IDs are duplicated: ",
      paste(dupes, collapse = ", ")
    ))
  }

  print(paste(nrow(df), "topics loaded successfully."))

  return(df)
}

# read_student_preferences <- function(filepath) {
#   raw <- read.table(
#     filepath,
#     sep = ",",
#     header = FALSE,
#     fill = TRUE,
#     na.strings = c("", "NA"),
#     stringsAsFactors = FALSE
#   )
#   colnames(raw) <- c("student_id", paste0("pref", 1:(ncol(raw) - 1)))
#
#   as_tibble(raw)
# }

#' Load and Validate Student Preferences (Wide Format)
#'
#' Reads a ragged CSV file. Validates inputs and returns a wide dataframe
#' where columns accommodate the maximum number of choices made by any student.
#'
#' @param file_path String. The full path to the file.
#' @param valid_topic_ids Vector. A list of acceptable topic IDs.
#' @return A tibble with `student_name`, `choice_1`, `choice_2`, etc.
#'         Indifferent students (no prefs) will have NAs in choice columns.
load_student_preferences <- function(file_path, valid_topic_ids) {
  # 1. Setup and Read
  if (!file.exists(file_path)) {
    stop(paste("File not found at:", file_path))
  }
  valid_topic_ids <- as.character(valid_topic_ids)

  raw <- read.table(
    file_path,
    sep = ",",
    header = FALSE,
    fill = TRUE,
    na.strings = c("", "NA"),
    colClasses = "character",
    strip.white = TRUE,
    stringsAsFactors = FALSE
  )
  colnames(raw) <- c("student_id", paste0("pref", 1:(ncol(raw) - 1)))

  raw <- as_tibble(raw)

  # Sanity Checks

  # A. Check for Duplicate Student Names
  if (any(duplicated(raw$student_id))) {
    dupes <- raw$student_id[duplicated(raw$student_id)]
    stop(paste("Duplicate student names found:", paste(dupes, collapse = ", ")))
  }

  # B. Check for Invalid Topic IDs
  # Unlist all 'pref' columns, remove NAs, and compare to valid list
  all_choices <- raw %>%
    select(starts_with("pref")) %>%
    unlist() %>%
    na.omit() %>%
    stringr::str_trim()
  invalid_topics <- setdiff(as.character(all_choices), valid_topic_ids)

  if (length(invalid_topics) > 0) {
    stop(paste(
      "Invalid Topic IDs found:",
      paste(invalid_topics, collapse = ", ")
    ))
  }

  # C. Check for Self-Duplication (Same topic chosen twice by one student)
  # Check row-by-row if there are duplicates among non-NA values
  has_row_dupes <- apply(select(raw, starts_with("pref")), 1, function(x) {
    choices <- na.omit(x)
    any(duplicated(choices)) # returns TRUE if duplicates exist
  })

  if (any(has_row_dupes)) {
    stop(paste(
      "Student(s) selected the same topic twice:",
      paste(raw$student_id[has_row_dupes], collapse = ", ")
    ))
  }

  # 3. Summary and Return
  print(paste(nrow(raw), "students loaded."))
  return(raw)
}
