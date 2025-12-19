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

#' Load and Validate Supervisor Preferences (Wide Format)
#'
#' Reads a ragged CSV file where the first column is the Topic ID and subsequent
#' columns are ranked Students. Validates that topics and students exist.
#'
#' @param file_path String. The full path to the file.
#' @param valid_topic_ids Vector. A list of valid topic IDs (from load_topics).
#' @param valid_student_ids Vector. A list of valid student IDs (from load_student_preferences).
#' @return A tibble with `topic_id`, `pref1`, `pref2`, etc.
#' @importFrom dplyr as_tibble select starts_with
#' @importFrom stringr str_trim
load_supervisor_preferences <- function(
  file_path,
  valid_topic_ids,
  valid_student_ids
) {
  # 1. Setup and Read
  if (!file.exists(file_path)) {
    stop(paste("File not found at:", file_path))
  }

  # Ensure constraints are character vectors
  valid_topic_ids <- as.character(valid_topic_ids)
  valid_student_ids <- as.character(valid_student_ids)

  # Use read.table because lines have variable lengths (ragged)
  raw <- read.table(
    file_path,
    sep = ",",
    header = FALSE,
    fill = TRUE, # Allows ragged rows
    na.strings = c("", "NA"),
    colClasses = "character",
    strip.white = TRUE,
    stringsAsFactors = FALSE
  )

  # Rename columns: Col 1 is Topic, others are Student Ranks
  colnames(raw) <- c("topic_id", paste0("pref", 1:(ncol(raw) - 1)))
  raw <- as_tibble(raw)

  # 2. Validation

  # A. Check for Duplicate Topics (One topic cannot be configured on two lines)
  if (any(duplicated(raw$topic_id))) {
    dupes <- unique(raw$topic_id[duplicated(raw$topic_id)])
    stop(paste(
      "Duplicate entries for the same Topic ID found:",
      paste(dupes, collapse = ", ")
    ))
  }

  # B. Check for Unknown Topic IDs (Col 1)
  unknown_topics <- setdiff(raw$topic_id, valid_topic_ids)
  if (length(unknown_topics) > 0) {
    stop(paste(
      "Supervisor references unknown Topic IDs:",
      paste(unknown_topics, collapse = ", ")
    ))
  }

  # C. Check for Unknown Student IDs (Cols 2+)
  # Gather all preferences, remove NAs, and check against valid list
  all_ranked_students <- raw %>%
    select(starts_with("pref")) %>%
    unlist() %>%
    na.omit() %>%
    str_trim()

  unknown_students <- setdiff(all_ranked_students, valid_student_ids)

  if (length(unknown_students) > 0) {
    stop(paste(
      "Supervisor references unknown Student IDs (check for typos):",
      paste(unknown_students, collapse = ", ")
    ))
  }

  # D. Check for Self-Duplication (Same student ranked twice for one topic)
  has_row_dupes <- apply(select(raw, starts_with("pref")), 1, function(x) {
    choices <- na.omit(x)
    any(duplicated(choices))
  })

  if (any(has_row_dupes)) {
    stop(paste(
      "Topic(s) where the same student was ranked twice:",
      paste(raw$topic_id[has_row_dupes], collapse = ", ")
    ))
  }

  # 3. Summary and Return
  print(paste(nrow(raw), "supervisor preference rules loaded."))
  return(raw)
}
