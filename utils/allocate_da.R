library(tidyverse)
library(matchingR)
#'
#' #' Allocate Students to Topics via Deferred Acceptance (Gale-Shapley)
#' #'
#' #' Implements the Gale-Shapley "Marriage Market" algorithm to assign students to
#' #' dissertation topics (supervisors). In this specific implementation,
#' #' **Supervisors (Topics) are the Proposers** and **Students are the Reviewers**.
#' #'
#' #' @description
#' #' This function takes rank-ordered preference lists from students and supervisors,
#' #' converts them into utility matrices, and performs a one-to-one matching.
#' #' It guarantees a stable matching, meaning there is no pair  (Student A, Topic B)
#' #' where both would prefer each other over their current assignment.
#' #'
#' #' @param student_prefs A dataframe containing student preferences.
#' #'   \itemize{
#' #'     \item Column 1: \code{student_id} (Unique identifier).
#' #'     \item Columns 2..N: Ranked preferences (Topic IDs). First column after ID is Rank 1.
#' #'   }
#' #' @param supervisor_prefs A dataframe containing supervisor/topic preferences.
#' #'   \itemize{
#' #'     \item Column 1: \code{topic_id} (Unique identifier).
#' #'     \item Columns 2..N: Ranked preferences (Student IDs). First column after ID is Rank 1.
#' #'   }
#' #' @param topics_df A dataframe containing the master list of topics.
#' #'   \itemize{
#' #'     \item Must contain a column \code{topic_id}.
#' #'   }
#' #'
#' #' @details
#' #' The function converts the dataframe rankings into utility scores.
#' #' \itemize{
#' #'   \item For a supervisor, their 1st choice student gets the highest score (N students),
#' #'   2nd choice gets (N-1), etc. Unlisted students get 0.
#' #'   \item For a student, their 1st choice topic gets the highest score, etc.
#' #' }
#' #'
#' #' Any \code{NA} or empty strings in the preference columns are ignored.
#' #'
#' #' @return A list containing three elements:
#' #' \item{matches}{A tibble with two columns: \code{topic_id} and \code{student_id}, representing the successful pairings.}
#' #' \item{unassigned}{A tibble with two columns: \code{type} ("Topic" or "Student") and \code{id}, listing any participants who did not get a match.}
#' #' \item{is_stable}{A logical (TRUE/FALSE) indicating if the resulting matching is stable according to the Gale-Shapley definition.}
#' #'
#' #' @examples
#' #' \dontrun{
#' #' # 1. Define Topics
#' #' topics_df <- tibble(topic_id = c("T1", "T2", "T3"))
#' #'
#' #' # 2. Student Preferences (S1 wants T1, S2 wants T2, S3 wants T1)
#' #' student_choices <- tibble(
#' #'   student_id = c("S1", "S2", "S3"),
#' #'   pref1 = c("T1", "T2", "T1"),
#' #'   pref2 = c("T2", "T1", "T2")
#' #' )
#' #'
#' #' # 3. Supervisor Preferences (T1 completes for S1 and S3)
#' #' supervisor_choices <- tibble(
#' #'   topic_id = c("T1", "T2", "T3"),
#' #'   pref1 = c("S3", "S2", NA), # T3 has no preferences (will go unassigned)
#' #'   pref2 = c("S1", NA, NA)
#' #' )
#' #'
#' #' # 4. Run Allocation
#' #' result <- allocate_by_da(student_choices, supervisor_choices, topics_df)
#' #'
#' #' # 5. Inspect
#' #' print(result$matches)
#' #' print(result$unassigned)
#' #' }
#' #'
#' #' @import tidyverse
#' #' @import matchingR
#' #' @export
#'
#' allocate_by_da <- function(student_prefs, supervisor_prefs, topics_df) {
#'   # --- 1. Setup ---
#'   student_list <- student_prefs$student_id
#'   topic_list <- topics_df$topic_id
#'
#'   n_students <- length(student_list)
#'   n_topics <- length(topic_list)
#'
#'   # --- 2. Supervisor Utils (Proposers) ---
#'   # Rows = Students (Reviewers), Cols = Topics (Proposers)
#'   u_supervisors <- matrix(0, nrow = n_students, ncol = n_topics)
#'
#'   for (i in 1:nrow(supervisor_prefs)) {
#'     t_id <- supervisor_prefs$topic_id[i]
#'     col_idx <- match(t_id, topic_list)
#'
#'     pref_cols <- grep("^pref", names(supervisor_prefs))
#'     prefs <- as.character(supervisor_prefs[i, pref_cols])
#'     prefs <- prefs[!is.na(prefs) & prefs != ""]
#'
#'     scores <- seq(from = n_students, by = -1, length.out = length(prefs))
#'     row_idxs <- match(prefs, student_list)
#'
#'     valid_mask <- !is.na(row_idxs)
#'     if (any(valid_mask)) {
#'       u_supervisors[row_idxs[valid_mask], col_idx] <- scores[valid_mask]
#'     }
#'   }
#'
#'   # --- 3. Student Utils (Reviewers) ---
#'   # Rows = Topics, Cols = Students
#'   u_students <- matrix(0, nrow = n_topics, ncol = n_students)
#'
#'   for (i in 1:nrow(student_prefs)) {
#'     s_id <- student_prefs$student_id[i]
#'     col_idx <- match(s_id, student_list)
#'
#'     prefs <- as.character(student_prefs[i, -1])
#'     prefs <- prefs[!is.na(prefs) & prefs != ""]
#'
#'     scores <- seq(from = n_topics, by = -1, length.out = length(prefs))
#'     row_idxs <- match(prefs, topic_list)
#'
#'     valid_mask <- !is.na(row_idxs)
#'     if (any(valid_mask)) {
#'       u_students[row_idxs[valid_mask], col_idx] <- scores[valid_mask]
#'     }
#'   }
#'
#'   # --- 4. Run Matching (DA Algorithm) ---
#'   results <- galeShapley.marriageMarket(
#'     proposerUtils = u_supervisors,
#'     reviewerUtils = u_students
#'   )
#'
#'   # --- 5. Format 'Matches' Tibble ---
#'   matches <- tibble(
#'     topic_id = topic_list,
#'     student_idx = results$proposals
#'   ) %>%
#'     mutate(
#'       student_id = student_list[student_idx]
#'     ) %>%
#'     select(topic_id, student_id) %>%
#'     filter(!is.na(student_id)) # Exclude topics that found no student here
#'
#'   # --- 6. Format 'Unassigned' Tibble ---
#'   # Get names of unmatched items
#'   unmatched_topics <- topic_list[results$single.proposers]
#'   unmatched_students <- student_list[results$single.reviewers]
#'
#'   # Combine into one tibble
#'   unassigned_df <- bind_rows(
#'     tibble(type = "Topic", id = unmatched_topics),
#'     tibble(type = "Student", id = unmatched_students)
#'   )
#'
#'   # Check stability
#'   is_stable <- galeShapley.checkStability(
#'     u_supervisors,
#'     u_students,
#'     results$proposals,
#'     results$engagements
#'   )
#'
#'   # --- 7. Return Results ---
#'   return(list(
#'     matches = matches,
#'     unassigned = unassigned_df,
#'     is_stable = is_stable
#'   ))
#' }

# NEW
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
    cli::cli_alert_info("Supervisors: {n_supervisors}")
  }

  # --- 2. Supervisor Utils (Proposers) ---
  # Rows = Students (Reviewers), Cols = Supervisors (Proposers)
  u_supervisors <- matrix(0, nrow = n_students, ncol = n_supervisors)

  for (i in 1:nrow(supervisor_prefs)) {
    su_id <- supervisor_prefs$supervisor_id[i]
    col_idx <- match(su_id, supervisor_list)

    prefs <- as.character(supervisor_prefs[i, -1])
    prefs <- prefs[!is.na(prefs) & prefs != ""]

    scores <- seq(from = n_students, by = -1, length.out = length(prefs))
    row_idxs <- match(prefs, student_list)

    valid_mask <- !is.na(row_idxs)
    if (any(valid_mask)) {
      u_supervisors[row_idxs[valid_mask], col_idx] <- scores[valid_mask]
    }

    if (debug && length(prefs) > 0) {
      cli::cli_alert("Supervisor {su_id}: {length(prefs)} preferences loaded")
    }
  }

  # --- 3. Student Utils (Reviewers) ---
  # Rows = Supervisors, Cols = Students
  u_students <- matrix(0, nrow = n_supervisors, ncol = n_students)

  for (i in 1:nrow(student_prefs)) {
    s_id <- student_prefs$student_id[i]
    col_idx <- match(s_id, student_list)

    prefs <- as.character(student_prefs[i, -1])
    prefs <- prefs[!is.na(prefs) & prefs != ""]

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

  # # Check stability
  # is_stable <- galeShapley.checkStability(
  #   proposerUtils = u_supervisors,
  #   reviewerUtils = u_students,
  #   proposals = results$matched.colleges,
  #   engagements = results$matched.students
  # )

  # --- 7. Return Results ---
  return(list(
    matches = matches,
    unassigned = unassigned_df
    #is_stable = is_stable
  ))
}
