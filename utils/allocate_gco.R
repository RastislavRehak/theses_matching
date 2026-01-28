#' Allocate Students to Topics using Global Cost Optimization
#'
#' @description
#' Assigns students to topics by minimizing global "dissatisfaction cost"
#' using Integer Linear Programming (ILP). Unlike iterative algorithms,
#' this considers all students and constraints simultaneously.
#'
#' @section Algorithm Logic:
#' 1. **Cost Matrix**: Rank 1 = cost 1, Rank 2 = cost 2, unranked = penalty
#' 2. **Constraints**: Each student gets exactly n topics; topics are balanced
#' 3. **Solver**: ILP finds minimum total cost assignment
#'
#' @param student_prefs Tibble with `student_id` and preference columns (`pref1`, `pref2`, ...).
#' @param topic_ids Character vector of valid topic IDs.
#' @param n_topics_per_student Integer. Topics to assign each student (default: 2).
#' @param penalty_value Integer. Cost for unranked topics (default: 100).
#' @param debug Logical. If TRUE, prints diagnostic messages.
#'
#' @return A tibble with `student_id`, `topic1`, `topic2`, etc.
#'
#' @examples
#' \dontrun
#' student_prefs <- tibble(
#'
#'   student_id = c("S1", "S2", "S3"),
#'   pref1 = c("TopicA", "TopicB", "TopicA"),
#'   pref2 = c("TopicB", "TopicA", "TopicC")
#' )
#' topics <- c("TopicA", "TopicB", "TopicC")
#'
#' result <- allocate_gco(student_prefs, topics, n_topics_per_student = 2)
#' }
#'
#' @importFrom lpSolve lp
#' @importFrom dplyr mutate group_by ungroup row_number
#' @importFrom tidyr unnest pivot_wider
#' @importFrom tibble tibble enframe
#' @importFrom cli cli_h1 cli_alert_info cli_alert_success cli_abort
#' @export
allocate_gco <- function(
  student_prefs,
  topic_ids,
  n_topics_per_student = 2,
  penalty_value = 100,
  debug = TRUE
) {
  # --- 1. Validation ---
  if (!requireNamespace("lpSolve", quietly = TRUE)) {
    cli::cli_abort(
      "Package {.pkg lpSolve} is required. Install with {.code install.packages('lpSolve')}"
    )
  }

  if (!"student_id" %in% names(student_prefs)) {
    cli::cli_abort("Input must contain a {.field student_id} column")
  }

  student_ids <- student_prefs$student_id
  n_students <- length(student_ids)
  n_topics <- length(topic_ids)

  if (debug) {
    cli::cli_h1("Global Cost Optimization (ILP)")
  }

  # --- 2. Calculate Capacities ---
  total_slots <- n_students * n_topics_per_student
  min_cap <- floor(total_slots / n_topics)
  max_cap <- ceiling(total_slots / n_topics)

  if (debug) {
    cli::cli_alert_info("Students: {n_students} | Topics: {n_topics}")
    cli::cli_alert_info("Slots needed: {total_slots}")
    cli::cli_alert_info(
      "Topic capacity: {min_cap}-{max_cap} students each
"
    )
  }

  # --- 3. Build Cost Matrix ---
  cost_matrix <- build_cost_matrix(
    student_prefs = student_prefs,
    student_ids = student_ids,
    topic_ids = topic_ids,
    penalty_value = penalty_value
  )

  cost_vec <- c(t(cost_matrix)) # Row-major for lpSolve

  # --- 4. Build Constraints ---
  constraints <- build_ilp_constraints(
    n_students = n_students,
    n_topics = n_topics,
    n_topics_per_student = n_topics_per_student,
    min_cap = min_cap,
    max_cap = max_cap
  )

  if (debug) {
    cli::cli_alert_info("Running ILP solver...")
  }

  # --- 5. Solve ---
  solution <- lpSolve::lp(
    direction = "min",
    objective.in = cost_vec,
    const.mat = constraints$matrix,
    const.dir = constraints$directions,
    const.rhs = constraints$rhs,
    all.bin = TRUE
  )

  if (solution$status != 0) {
    cli::cli_abort(c(
      "Solver failed to find valid allocation",
      "i" = "Status code: {solution$status}",
      "i" = "This usually means constraints are infeasible"
    ))
  }

  if (debug) {
    cli::cli_alert_success("Solution found (total cost: {solution$objval})")
  }

  # --- 6. Format Results ---
  result <- format_ilp_results(
    solution_vec = solution$solution,
    student_ids = student_ids,
    topic_ids = topic_ids,
    n_students = n_students
  )

  result
}


# ============================================================================
# Internal Helper Functions
# ============================================================================

#' Build Cost Matrix for ILP
#' @keywords internal
build_cost_matrix <- function(
  student_prefs,
  student_ids,
  topic_ids,
  penalty_value
) {
  n_students <- length(student_ids)
  n_topics <- length(topic_ids)

  # Initialize with penalty (unranked = high cost)
  cost_matrix <- matrix(
    penalty_value,
    nrow = n_students,
    ncol = n_topics,
    dimnames = list(student_ids, topic_ids)
  )

  # Get preference columns
  pref_cols <- grep("^pref", names(student_prefs), value = TRUE)

  # Fill costs based on ranks (Rank k = Cost k)
  for (i in seq_len(n_students)) {
    prefs <- as.character(unlist(student_prefs[i, pref_cols]))

    for (rank in seq_along(prefs)) {
      topic <- prefs[rank]

      if (!is.na(topic) && topic %in% topic_ids) {
        # Keep better rank if listed twice
        cost_matrix[i, topic] <- min(cost_matrix[i, topic], rank)
      }
    }
  }

  cost_matrix
}


#' Build ILP Constraint Matrices
#' @keywords internal
build_ilp_constraints <- function(
  n_students,
  n_topics,
  n_topics_per_student,
  min_cap,
  max_cap
) {
  # Student constraints: each student gets exactly n_topics_per_student
  # Block diagonal structure
  student_constraints <- kronecker(diag(n_students), t(rep(1, n_topics)))

  # Topic constraints: each topic has between min_cap and max_cap students
  # Repeated identity structure
  topic_constraints <- kronecker(t(rep(1, n_students)), diag(n_topics))

  # Combine all constraints
  constraint_matrix <- rbind(
    student_constraints,
    topic_constraints, # For >= min
    topic_constraints # For <= max
  )

  directions <- c(
    rep("=", n_students), # Exactly n topics per student
    rep(">=", n_topics), # At least min_cap per topic
    rep("<=", n_topics) # At most max_cap per topic
  )

  rhs <- c(
    rep(n_topics_per_student, n_students),
    rep(min_cap, n_topics),
    rep(max_cap, n_topics)
  )

  list(
    matrix = constraint_matrix,
    directions = directions,
    rhs = rhs
  )
}


#' Format ILP Solution into Tibble
#' @keywords internal
format_ilp_results <- function(
  solution_vec,
  student_ids,
  topic_ids,
  n_students
) {
  # Reshape binary vector to matrix
  result_matrix <- matrix(
    solution_vec,
    nrow = n_students,
    byrow = TRUE,
    dimnames = list(student_ids, topic_ids)
  )

  # Extract assigned topics for each student
  assignments <- apply(
    result_matrix,
    1,
    function(row) {
      names(row)[row == 1]
    },
    simplify = FALSE
  )

  # Convert to wide tibble
  tibble::enframe(assignments, name = "student_id", value = "topics") |>
    tidyr::unnest(topics) |>
    dplyr::group_by(student_id) |>
    dplyr::mutate(col = paste0("topic", dplyr::row_number())) |>
    dplyr::ungroup() |>
    tidyr::pivot_wider(names_from = col, values_from = topics)
}

#' Reshape Allocation Data to Topic Perspective
#'
#' Pivots allocation data from student-centric (one row per student)
#' to topic-centric (one row per topic). Useful for generating
#' class lists or supervisor dashboards.
#'
#' @param data Tibble with allocation data.
#' @param student_col Column containing student IDs (default: `student_id`).
#' @param topic_cols Tidyselect expression for topic columns (default: `starts_with("topic")`).
#' @param collapse_sep String separator for student list (default: `", "`).
#'
#' @return A tibble with:
#'   * `topic_id`: Unique topic identifier
#'   * `n_students`: Count of assigned students
#'   * `students`: Comma-separated list of assigned students
#'
#' @examples
#' \dontrun{
#' allocations <- tibble(
#'   student_id = c("S1", "S2", "S3"),
#'   topic1 = c("TopicA", "TopicB", "TopicA"),
#'   topic2 = c("TopicB", "TopicA", NA)
#' )
#'
#' pivot_to_topic_perspective(allocations)
#' # Returns:
#' # topic_id | n_students | students
#' # TopicA   | 3          | S1, S2, S3
#' # TopicB   | 2          | S1, S2
#' }
#'
#' @importFrom dplyr group_by summarise arrange n
#' @importFrom tidyr pivot_longer drop_na
#' @export
pivot_to_topic_perspective <- function(
  data,
  student_col = student_id,
  topic_cols = starts_with("topic"),
  collapse_sep = ", "
) {
  data |>
    tidyr::pivot_longer(
      cols = {{ topic_cols }},
      names_to = NULL,
      values_to = "topic_id"
    ) |>
    tidyr::drop_na(topic_id) |>
    dplyr::group_by(topic_id) |>
    dplyr::summarise(
      n_students = dplyr::n(),
      students = paste({{ student_col }}, collapse = collapse_sep),
      .groups = "drop"
    ) |>
    dplyr::arrange(topic_id)
}
