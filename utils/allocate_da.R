library(dplyr)
library(matchingR)

#' Allocate Students to Supervisors via Deferred Acceptance (Gale-Shapley)
#'
#' Implements the college admissions variant of Gale-Shapley where supervisors
#' can accept multiple students up to their capacity. Supervisors propose,
#' students review - yielding a supervisor-optimal stable matching.
#'
#' @param student_prefs A tibble with columns:
#'   \describe{
#'     \item{student_id}{Unique student identifier (character)}
#'     \item{pref1, pref2, ...}{Ranked supervisor IDs, best first}
#'   }
#' @param supervisor_prefs A tibble with columns:
#'   \describe{
#'     \item{supervisor_id}{Unique supervisor identifier (character)}
#'     \item{capacity}{Integer, number of students this supervisor can take}
#'     \item{pref1, pref2, ...}{Ranked student IDs, best first}
#'   }
#' @param debug Logical. If TRUE, prints progress via cli. Default FALSE.
#'
#' @return A list with three elements:
#'   \describe{
#'     \item{matches}{Tibble with columns \code{supervisor_id} and \code{student_id}}
#'     \item{unassigned}{Tibble with columns \code{type} ("Supervisor"/"Student") and \code{id}}
#'     \item{is_stable}{Logical indicating matching stability}
#'   }
#'
#' @details
#' Utility scores are assigned as: 1st choice = N, 2nd = N-1, etc.
#' Unranked participants receive 0 (acceptable but least preferred).
#'
#' The matching is stable: no student-supervisor pair mutually prefer
#' each other over their current assignment.
#'
#' @examples
#' \dontrun{
#' students <- tibble(
#'   student_id = c("S1", "S2", "S3"),
#'   pref1 = c("Alice", "Bob", "Alice"),
#'   pref2 = c("Bob", "Alice", "Bob")
#' )
#'
#' supervisors <- tibble(
#'   supervisor_id = c("Alice", "Bob"),
#'   capacity = c(2, 1),
#'   pref1 = c("S1", "S2"),
#'   pref2 = c("S3", "S1")
#' )
#'
#' result <- allocate_by_da(students, supervisors)
#' }
#'
#' @import dplyr
#' @importFrom matchingR galeShapley.collegeAdmissions galeShapley.checkStability
#' @export

allocate_by_da <- function(
  student_prefs,
  supervisor_prefs,
  debug = FALSE
) {
  # --- 1. Setup ---
  student_list <- student_prefs$student_id
  supervisor_list <- supervisor_prefs$supervisor_id

  n_students <- length(student_list)
  n_supervisors <- length(supervisor_list)

  if (debug) {
    cli::cli_h2("DA Allocation Setup")
    cli::cli_alert_info("Students: {n_students}")
    cli::cli_alert_info("Supervisors/Topics: {n_supervisors}")
  }

  # --- 2. Supervisor Utils (Proposers) ---
  # Rows = Students (Reviewers), Cols = Supervisors (Proposers)
  u_supervisors <- matrix(0, nrow = n_students, ncol = n_supervisors)

  pref_cols_sup <- grep("^pref", names(supervisor_prefs), value = TRUE)

  for (i in seq_len(nrow(supervisor_prefs))) {
    su_id <- supervisor_prefs$supervisor_id[i]
    col_idx <- match(su_id, supervisor_list)

    prefs <- as.character(supervisor_prefs[i, pref_cols_sup])

    scores <- seq(from = n_students, by = -1, length.out = length(prefs))
    row_idxs <- match(prefs, student_list)

    valid_mask <- !is.na(row_idxs)
    if (any(valid_mask)) {
      u_supervisors[row_idxs[valid_mask], col_idx] <- scores[valid_mask]
    }

    if (debug && length(prefs) > 0) {
      cli::cli_alert(
        "Supervisor {su_id}: {sum(valid_mask)}/{length(prefs)} preferences valid"
      )
    }
  }

  # --- 3. Student Utils (Reviewers) ---
  # Rows = Supervisors, Cols = Students
  u_students <- matrix(0, nrow = n_supervisors, ncol = n_students)

  pref_cols_stu <- grep("^pref", names(student_prefs), value = TRUE)

  for (i in seq_len(nrow(student_prefs))) {
    s_id <- student_prefs$student_id[i]
    col_idx <- match(s_id, student_list)

    prefs <- as.character(student_prefs[i, pref_cols_stu])

    scores <- seq(from = n_supervisors, by = -1, length.out = length(prefs))
    row_idxs <- match(prefs, supervisor_list)

    valid_mask <- !is.na(row_idxs)
    if (any(valid_mask)) {
      u_students[row_idxs[valid_mask], col_idx] <- scores[valid_mask]
    }
  }

  if (debug) {
    students_with_prefs <- sum(colSums(u_students) > 0)
    cli::cli_alert_info(
      "Students with valid preferences: {students_with_prefs}/{n_students}"
    )
  }

  # Extract capacities
  capacities <- supervisor_prefs$capacity

  if (debug) {
    cli::cli_h2("Capacity Summary")
    cli::cli_alert_info("Total slots: {sum(capacities)}")
    cli::cli_alert_info("Capacity range: {min(capacities)}-{max(capacities)}")
    if (sum(capacities) < n_students) {
      cli::cli_alert_warning(
        "Fewer slots ({sum(capacities)}) than students ({n_students})"
      )
    }
  }

  # --- 4. Run Matching (DA Algorithm) ---
  if (debug) {
    cli::cli_h2("Running Gale-Shapley Algorithm")
  }

  results <- galeShapley.collegeAdmissions(
    collegeUtils = u_supervisors,
    studentUtils = u_students,
    slots = capacities,
    studentOptimal = FALSE
  )

  # --- 6. Format Matches ---
  # matched.students[i] = college index that student i matched to (or NA)
  matches <- tibble(
    student_id = student_list,
    supervisor_idx = results$matched.students
  ) %>%
    filter(!is.na(supervisor_idx)) %>%
    mutate(supervisor_id = supervisor_list[supervisor_idx]) %>%
    select(supervisor_id, student_id)

  if (debug) {
    cli::cli_h2("Results")
    cli::cli_alert_success("Matched pairs: {nrow(matches)}")
  }

  # --- 7. Format 'Unassigned' Tibble ---
  # Get names of unmatched items
  unmatched_supervisors <- supervisor_list[results$unmatched.colleges]
  unmatched_students <- student_list[results$unmatched.students]

  # Combine into one tibble
  unassigned_df <- bind_rows(
    tibble(type = "Supervisor", id = unmatched_supervisors),
    tibble(type = "Student", id = unmatched_students)
  )

  if (debug) {
    cli::cli_alert_warning("Unmatched students: {length(unmatched_students)}")
    cli::cli_alert_warning(
      "Supervisors with open slots: {length(unmatched_supervisors)}"
    )
  }

  # Check stability
  is_stable <- galeShapley.checkStability(
    proposerUtils = u_supervisors,
    reviewerUtils = u_students,
    proposals = results$matched.colleges,
    engagements = results$matched.students
  )

  if (debug) {
    if (is_stable) {
      cli::cli_alert_success("Matching is stable")
    } else {
      cli::cli_alert_danger("Matching is NOT stable")
    }
  }

  # --- 7. Return Results ---
  return(list(
    matches = matches,
    unassigned = unassigned_df,
    is_stable = is_stable
  ))
}
