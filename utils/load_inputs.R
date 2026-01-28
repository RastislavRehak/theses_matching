library(readr)
library(here)

#' #' Load and Validate Topics
#' #'
#' #' Reads a txt file without headers.
#' #' Validates that there are exactly 2 columns and unique topic IDs.
#' #'
#' #' @param file_path String. The full path to the file.
#' #' @return A tibble with columns `id` and `label`.
#' #' @examples
#' #' topics <- load_topics(here("data/topics.txt"))
#' load_topics <- function(file_path) {
#'   # Check if file exists to avoid obscure readr errors
#'   if (!file.exists(file_path)) {
#'     stop(paste("File not found at:", file_path))
#'   }
#'
#'   # Read data (col_names = FALSE because the file has no header)
#'   df <- read_csv(
#'     file_path,
#'     col_names = FALSE,
#'     col_types = "cc",
#'     show_col_types = FALSE
#'   )
#'
#'   # Sanity Check 1: Dimensions
#'   if (ncol(df) != 2) {
#'     stop(paste0(
#'       "Structure Error: The file must have exactly 2 columns. ",
#'       "Found ",
#'       ncol(df),
#'       " columns. ",
#'       "Check if you have extra commas in your text values."
#'     ))
#'   }
#'
#'   # Rename for consistency
#'   names(df) <- c("topic_id", "label")
#'
#'   # Sanity Check 2: Unique IDs
#'   if (any(duplicated(df$topic_id))) {
#'     dupes <- unique(df$topic_id[duplicated(df$topic_id)])
#'     stop(paste0(
#'       "Integrity Error: Topic IDs must be unique.\n",
#'       "The following IDs are duplicated: ",
#'       paste(dupes, collapse = ", ")
#'     ))
#'   }
#'
#'   print(paste(nrow(df), "topics loaded successfully."))
#'
#'   return(df)
#' }

#' Load and Validate Student Preferences (Wide Format)
#'
#' Reads a ragged CSV file. Validates inputs and returns a wide dataframe
#' where columns accommodate the maximum number of choices made by any student.
#'
#' @param file_path String. The full path to the file.
#' @param valid_topic_ids Vector. Bachelor only: A list of acceptable topic IDs. Leave NULL for MA.
#' @return A tibble with `student_name`, `pref1`, `pref2`, etc.
#'         Indifferent students (no prefs) will have NAs in choice columns.
load_student_preferences <- function(
  file_path
) {
  # 1. Setup and Read
  if (!file.exists(file_path)) {
    stop(paste("File not found at:", file_path))
  }

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

  # C. Check for Self-Duplication (Same topic chosen twice by one student)
  # Check row-by-row if there are duplicates among non-NA values
  has_row_dupes <- apply(select(raw, starts_with("pref")), 1, function(x) {
    choices <- na.omit(x)
    any(duplicated(choices)) # returns TRUE if duplicates exist
  })

  if (any(has_row_dupes)) {
    stop(paste(
      "Student(s) selected the same topic/supervisor twice:",
      paste(raw$student_id[has_row_dupes], collapse = ", ")
    ))
  }

  # 3. Summary and Return
  print(paste(nrow(raw), "students loaded."))
  return(raw)
}

#' #' Load and Validate Supervisor Preferences (Wide Format)
#' #'
#' #' Reads a ragged CSV file where the first column is the Topic ID and subsequent
#' #' columns are ranked Students. Validates that topics and students exist.
#' #'
#' #' @param file_path String. The full path to the file.
#' #' @param valid_topic_ids Vector. A list of valid topic IDs (from load_topics).
#' #' @param valid_student_ids Vector. A list of valid student IDs (from load_student_preferences).
#' #' @return A tibble with `topic_id`, `pref1`, `pref2`, etc.
#' #' @importFrom dplyr as_tibble select starts_with
#' #' @importFrom stringr str_trim
#' load_supervisor_preferences <- function(
#'   file_path,
#'   valid_topic_ids,
#'   valid_student_ids
#' ) {
#'   # 1. Setup and Read
#'   if (!file.exists(file_path)) {
#'     stop(paste("File not found at:", file_path))
#'   }
#'
#'   # Ensure constraints are character vectors
#'   valid_topic_ids <- as.character(valid_topic_ids)
#'   valid_student_ids <- as.character(valid_student_ids)
#'
#'   # Use read.table because lines have variable lengths (ragged)
#'   raw <- read.table(
#'     file_path,
#'     sep = ",",
#'     header = FALSE,
#'     fill = TRUE, # Allows ragged rows
#'     na.strings = c("", "NA"),
#'     colClasses = "character",
#'     strip.white = TRUE,
#'     stringsAsFactors = FALSE
#'   )
#'
#'   # Rename columns: Col 1 is Topic, others are Student Ranks
#'   colnames(raw) <- c("topic_id", paste0("pref", 1:(ncol(raw) - 1)))
#'   raw <- as_tibble(raw)
#'
#'   # 2. Validation
#'
#'   # A. Check for Duplicate Topics (One topic cannot be configured on two lines)
#'   if (any(duplicated(raw$topic_id))) {
#'     dupes <- unique(raw$topic_id[duplicated(raw$topic_id)])
#'     stop(paste(
#'       "Duplicate entries for the same Topic ID found:",
#'       paste(dupes, collapse = ", ")
#'     ))
#'   }
#'
#'   # B. Check for Unknown Topic IDs (Col 1)
#'   unknown_topics <- setdiff(raw$topic_id, valid_topic_ids)
#'   if (length(unknown_topics) > 0) {
#'     stop(paste(
#'       "Supervisor references unknown Topic IDs:",
#'       paste(unknown_topics, collapse = ", ")
#'     ))
#'   }
#'
#'   # C. Check for Unknown Student IDs (Cols 2+)
#'   # Gather all preferences, remove NAs, and check against valid list
#'   all_ranked_students <- raw %>%
#'     select(starts_with("pref")) %>%
#'     unlist() %>%
#'     na.omit() %>%
#'     str_trim()
#'
#'   unknown_students <- setdiff(all_ranked_students, valid_student_ids)
#'
#'   if (length(unknown_students) > 0) {
#'     stop(paste(
#'       "Supervisor references unknown Student IDs (check for typos):",
#'       paste(unknown_students, collapse = ", ")
#'     ))
#'   }
#'
#'   # D. Check for Self-Duplication (Same student ranked twice for one topic)
#'   has_row_dupes <- apply(select(raw, starts_with("pref")), 1, function(x) {
#'     choices <- na.omit(x)
#'     any(duplicated(choices))
#'   })
#'
#'   if (any(has_row_dupes)) {
#'     stop(paste(
#'       "Topic(s) where the same student was ranked twice:",
#'       paste(raw$topic_id[has_row_dupes], collapse = ", ")
#'     ))
#'   }
#'
#'   # 3. Summary and Return
#'   print(paste(nrow(raw), "supervisor preference rules loaded."))
#'   return(raw)
#' }

#' Load and Validate Supervisor Preferences for MA Allocation
#'
#' Reads a CSV where each row is a supervisor with their capacity and ranked students.
#' Format: supervisor_id, capacity, student1, student2, ...
#' Or if implicit_capacity_1 = TRUE: supervisor_id, student1, student2, ...
#'
#' @param file_path String. The full path to the file.
#' @param implicit_capacity_1 Logical. If TRUE, assumes no capacity column and sets all to 1.
#' @return A tibble with `supervisor_id`, `capacity`, `pref1`, `pref2`, etc.
#' @importFrom dplyr as_tibble select starts_with
#' @importFrom stringr str_trim
load_supervisor_preferences <- function(
  file_path,
  implicit_capacity_1 = FALSE
) {
  # 1. Setup and Read
  if (!file.exists(file_path)) {
    stop(paste("File not found at:", file_path))
  }

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

  # 2. Handle column naming based on implicit_capacity_1
  if (implicit_capacity_1) {
    # No capacity column: supervisor_id, pref1, pref2, ...
    colnames(raw) <- c(
      "supervisor_id",
      paste0("pref", 1:(ncol(raw) - 1))
    )
    raw <- as_tibble(raw)
    raw$capacity <- 1L
    # Reorder so capacity is second column
    raw <- raw %>% select(supervisor_id, capacity, starts_with("pref"))
  } else {
    # Has capacity column: supervisor_id, capacity, pref1, pref2, ...
    colnames(raw) <- c(
      "supervisor_id",
      "capacity",
      paste0("pref", 1:(ncol(raw) - 2))
    )
    raw <- as_tibble(raw)
  }

  # 2. Validation

  # A. Duplicate supervisors
  if (any(duplicated(raw$supervisor_id))) {
    dupes <- unique(raw$supervisor_id[duplicated(raw$supervisor_id)])
    stop(paste(
      "Duplicate Supervisor IDs found:",
      paste(dupes, collapse = ", ")
    ))
  }

  # B. Validate capacity is an integer >= 0
  capacities <- as.integer(raw$capacity)
  if (any(is.na(capacities)) || any(capacities < 0)) {
    bad_rows <- raw$supervisor_id[is.na(capacities) | capacities < 0]
    stop(paste(
      "Invalid capacity (must be an integer of at least 0) for:",
      paste(bad_rows, collapse = ", ")
    ))
  }
  raw$capacity <- capacities

  # C. Same student ranked twice by one supervisor
  has_row_dupes <- apply(select(raw, starts_with("pref")), 1, function(x) {
    choices <- na.omit(x)
    any(duplicated(choices))
  })

  if (any(has_row_dupes)) {
    stop(paste(
      "Supervisor(s) ranked the same student twice:",
      paste(raw$supervisor_id[has_row_dupes], collapse = ", ")
    ))
  }

  # 3. Summary and Return
  print(paste(
    nrow(raw),
    "supervisors loaded. Total capacity:",
    sum(raw$capacity)
  ))
  return(raw)
}


#' Cross-Validate Student and Supervisor Preferences
#'
#' Ensures referential integrity between the two preference files:
#' - Every supervisor mentioned by students must exist in the supervisor list
#' - Every student mentioned by supervisors must exist in the student list
#'
#' @param student_prefs Tibble. Output from load_student_preferences().
#' @param supervisor_prefs Tibble. Output from load_supervisor_preferences_ma().
#' @return None. Stops with error if validation fails, prints success message otherwise.
crossvalidate_preferences <- function(student_prefs, supervisor_prefs) {
  student_ids <- student_prefs$student_id
  supervisor_ids <- supervisor_prefs$supervisor_id

  # Supervisors mentioned in student preferences
  sups_in_student_prefs <- student_prefs %>%
    select(starts_with("pref")) %>%
    unlist() %>%
    na.omit() %>%
    unique()

  # Students mentioned in supervisor preferences
  students_in_sup_prefs <- supervisor_prefs %>%
    select(starts_with("pref")) %>%
    unlist() %>%
    na.omit() %>%
    unique()

  # Find unknowns
  unknown_supervisors <- setdiff(sups_in_student_prefs, supervisor_ids)
  unknown_students <- setdiff(students_in_sup_prefs, student_ids)

  # Collect errors

  errors <- c()

  if (length(unknown_supervisors) > 0) {
    errors <- c(
      errors,
      paste(
        "Students reference unknown supervisors:",
        paste(unknown_supervisors, collapse = ", ")
      )
    )
  }

  if (length(unknown_students) > 0) {
    errors <- c(
      errors,
      paste(
        "Supervisors reference unknown students:",
        paste(unknown_students, collapse = ", ")
      )
    )
  }

  if (length(errors) > 0) {
    stop(paste(errors, collapse = "\n"))
  }

  print("Cross-validation passed: all references are valid.")
}
