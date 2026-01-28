#' Load and Validate Topic List
#'
#' Reads a single-column CSV file containing topic IDs.
#'
#' @param file_path String. Path to the CSV file.
#' @param debug Logical. If TRUE, prints diagnostic messages.
#'
#' @return A tibble with a single `topic_id` column.
#'
#' @examples
#' \dontrun{
#' topics <- load_topics("data/topics.csv")
#' }
#'
#' @importFrom dplyr as_tibble
#' @importFrom cli cli_abort cli_alert_success
#' @export
load_topics <- function(file_path, debug = TRUE) {
  # 1. Validate file exists
  if (!file.exists(file_path)) {
    cli::cli_abort("File not found: {.path {file_path}}")
  }

  # 2. Read CSV
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

  # 3. Structure output

  raw <- dplyr::as_tibble(raw, .name_repair = "minimal")
  colnames(raw) <- "topic_id"

  # 4. Validate

  validate_no_duplicate_ids(raw$topic_id, "topic")

  # 5. Summary
  if (debug) {
    cli::cli_alert_success("{nrow(raw)} topic{?s} loaded")
  }

  raw
}


#' Load and Validate Student Preferences (Wide Format)
#'
#' Reads a ragged CSV file. Validates inputs and returns a wide dataframe
#' where columns accommodate the maximum number of choices made by any student.
#'
#' @param file_path String. The full path to the file.
#' @param debug Logical. If TRUE, prints diagnostic messages.
#' @return A tibble with `student_id`, `pref1`, `pref2`, etc.
#' @export
load_student_preferences <- function(file_path, debug = TRUE) {
  # 1. File check

  if (!file.exists(file_path)) {
    cli::cli_abort("File not found: {file_path}")
  }

  # 2. Read ragged CSV
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

  colnames(raw) <- c("student_id", paste0("pref", seq_len(ncol(raw) - 1)))
  raw <- as_tibble(raw)

  # 3. Validation
  validate_no_duplicate_ids(raw$student_id, "student")
  validate_no_row_duplicates(raw, "student")

  # 4. Summary
  if (debug) {
    cli::cli_alert_success("{nrow(raw)} students loaded")
  }

  raw
}


#' Load and Validate Supervisor Preferences
#'
#' Reads a CSV where each row is a supervisor with their capacity and ranked students.
#'
#' @param file_path String. The full path to the file.
#' @param implicit_capacity_1 Logical. If TRUE, assumes no capacity column and sets all to 1.
#' @param debug Logical. If TRUE, prints diagnostic messages.
#' @return A tibble with `supervisor_id`, `capacity`, `pref1`, `pref2`, etc.
#' @export
load_supervisor_preferences <- function(
  file_path,
  implicit_capacity_1 = FALSE,
  debug = TRUE
) {
  # 1. File check
  if (!file.exists(file_path)) {
    cli::cli_abort("File not found: {file_path}")
  }

  # 2. Read ragged CSV
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

  # 3. Handle column naming
  if (implicit_capacity_1) {
    colnames(raw) <- c("supervisor_id", paste0("pref", seq_len(ncol(raw) - 1)))
    raw <- as_tibble(raw)
    raw$capacity <- 1L
    raw <- select(raw, supervisor_id, capacity, starts_with("pref"))
  } else {
    colnames(raw) <- c(
      "supervisor_id",
      "capacity",
      paste0("pref", seq_len(ncol(raw) - 2))
    )
    raw <- as_tibble(raw)
  }

  # 4. Validation
  validate_no_duplicate_ids(raw$supervisor_id, "supervisor")
  validate_capacity(raw)
  validate_no_row_duplicates(raw, "supervisor")

  # 5. Convert capacity to integer
  raw$capacity <- as.integer(raw$capacity)

  # 6. Summary
  if (debug) {
    cli::cli_alert_success(
      "{nrow(raw)} supervisors loaded (total capacity: {sum(raw$capacity)})"
    )
  }

  raw
}


#' Cross-Validate Student and Supervisor Preferences
#'
#' Ensures referential integrity between the two preference files.
#'
#' @param student_prefs Tibble. Output from load_student_preferences().
#' @param supervisor_prefs Tibble. Output from load_supervisor_preferences().
#' @param debug Logical. If TRUE, prints diagnostic messages.
#' @return Invisible TRUE if validation passes. Stops with error otherwise.
#' @export
crossvalidate_preferences <- function(
  student_prefs,
  supervisor_prefs,
  debug = TRUE
) {
  student_ids <- student_prefs$student_id
  supervisor_ids <- supervisor_prefs$supervisor_id

  # Extract all referenced IDs
  sups_in_student_prefs <- extract_all_preferences(student_prefs)
  students_in_sup_prefs <- extract_all_preferences(supervisor_prefs)

  # Find unknowns
  unknown_supervisors <- setdiff(sups_in_student_prefs, supervisor_ids)
  unknown_students <- setdiff(students_in_sup_prefs, student_ids)

  # Collect errors

  errors <- character(0)

  if (length(unknown_supervisors) > 0) {
    errors <- c(
      errors,
      cli::format_inline(
        "Students reference unknown supervisors: {.val {unknown_supervisors}}"
      )
    )
  }

  if (length(unknown_students) > 0) {
    errors <- c(
      errors,
      cli::format_inline(
        "Supervisors reference unknown students: {.val {unknown_students}}"
      )
    )
  }

  if (length(errors) > 0) {
    cli::cli_abort(paste(errors, collapse = "\n"))
  }

  if (debug) {
    cli::cli_alert_success("Cross-validation passed: all references valid")
  }

  invisible(TRUE)
}


# ============================================================================
# Internal Helper Functions
# ============================================================================

#' Validate No Duplicate IDs
#' @keywords internal
validate_no_duplicate_ids <- function(ids, entity_type) {
  if (any(duplicated(ids))) {
    dupes <- unique(ids[duplicated(ids)])
    cli::cli_abort(
      "Duplicate {entity_type} IDs found: {.val {dupes}}"
    )
  }
}

#' Validate Capacity Column
#' @keywords internal
validate_capacity <- function(df) {
  capacities <- suppressWarnings(as.integer(df$capacity))

  invalid <- is.na(capacities) | capacities < 0

  if (any(invalid)) {
    bad_ids <- df$supervisor_id[invalid]
    cli::cli_abort(
      "Invalid capacity (must be integer >= 0) for: {.val {bad_ids}}"
    )
  }
}

#' Validate No Row Duplicates (same choice twice)
#' @keywords internal
validate_no_row_duplicates <- function(df, entity_type) {
  pref_cols <- select(df, starts_with("pref"))

  has_dupes <- apply(pref_cols, 1, function(x) {
    choices <- na.omit(x)
    any(duplicated(choices))
  })

  if (any(has_dupes)) {
    id_col <- if (entity_type == "student") "student_id" else "supervisor_id"
    bad_ids <- df[[id_col]][has_dupes]
    cli::cli_abort(
      "{entity_type}(s) listed the same choice twice: {.val {bad_ids}}"
    )
  }
}

#' Extract All Preferences from a Dataframe
#' @keywords internal
extract_all_preferences <- function(df) {
  df %>%
    select(starts_with("pref")) %>%
    unlist(use.names = FALSE) %>%
    na.omit() %>%
    unique() %>%
    as.character()
}
