#' Allocate Students to Topics using Global Cost Optimization
#'
#' @description
#' This function assigns students to topics by minimizing a global "dissatisfaction cost".
#' Unlike iterative algorithms (like Serial Dictatorship), this method considers all
#' students and constraints simultaneously using Integer Linear Programming (ILP).
#'
#' @section Algorithm Logic:
#' The problem is modeled as a mathematical optimization task:
#'
#' 1. **Cost Matrix**: A grid is created where rows are students and columns are topics.
#'    - If a student ranks a topic 1st, the cost is low (e.g., 1).
#'    - If they rank it 2nd, the cost is higher (e.g., 2).
#'    - If they do not rank it (indifference), the cost is very high (penalty).
#'
#' 2. **Constraints**:
#'    - **Student Constraint**: Each student must be assigned exactly `n` topics.
#'      (Since the solution is binary, a student cannot be assigned the same topic twice).
#'    - **Topic Balancing**: Each topic must have a total count between a calculated
#'      minimum and maximum capacity to ensure even distribution.
#'
#' 3. **Solver**: The `lpSolve` package finds the combination of assignments that
#'    satisfies all rules while resulting in the lowest total cost (highest overall happiness).
#'
#' @param student_preferences A dataframe or tibble.
#'   * Must contain a column named `student_id`.
#'   * All other columns are treated as ranked preferences (e.g., `pref1`, `pref2`...).
#'   * `NA` values indicate indifference.
#' @param topic_ids A character vector containing the unique names of all valid topics.
#' @param n_topics_per_student Integer. The number of distinct topics to assign each student (default: 2).
#' @param penalty_value Integer. The "cost" applied to a topic a student did not list.
#'   Should be higher than the maximum number of preferences (default: 100).
#'
#' @return A wide-format tibble where each row represents a student, and columns
#'   (`topic1`, `topic2`...) represent their assigned topics.
#'
#' @importFrom lpSolve lp
#' @importFrom dplyr mutate select arrange row_number group_by ungroup
#' @importFrom tidyr pivot_longer pivot_wider
#' @importFrom tibble tibble enframe
#' @export
allocate_optimally <- function(
  student_preferences,
  topic_ids,
  n_topics_per_student = 2,
  penalty_value = 100
) {
  # --- 1. VALIDATION & SETUP ---
  if (!requireNamespace("lpSolve", quietly = TRUE)) {
    stop(
      "Package 'lpSolve' is required. Please install it with install.packages('lpSolve')."
    )
  }

  if (!"student_id" %in% names(student_preferences)) {
    stop("Error: Input data must contain a 'student_id' column.")
  }

  n_students <- nrow(student_preferences)
  n_topics <- length(topic_ids)

  message("----------------------------------------------------------")
  message(" ALGORITHM START: Global Cost Optimization (ILP)")
  message("----------------------------------------------------------")

  # --- 2. CALCULATE CAPACITIES ---
  # We want topics to be as balanced as possible.
  total_seats_needed <- n_students * n_topics_per_student

  # Min capacity: The baseline everyone gets
  min_cap <- floor(total_seats_needed / n_topics)

  # Max capacity: The baseline + 1 (for the remainder)
  # Some topics will have min_cap, others min_cap + 1.
  # We set the strict limit to ceiling() to allow this flexibility.
  max_cap <- ceiling(total_seats_needed / n_topics)

  message(sprintf(
    "[DEBUG] Students: %d | Topics: %d | Seats Needed: %d",
    n_students,
    n_topics,
    total_seats_needed
  ))
  message(sprintf(
    "[DEBUG] Constraints: Each topic must have between %d and %d students.",
    min_cap,
    max_cap
  ))

  # --- 3. BUILD COST MATRIX ---
  # Rows = Students, Cols = Topics.
  # We need a flat vector for the solver, but we build it as a matrix first for sanity.

  # Initialize with high penalty (assumes student doesn't want the topic)
  cost_matrix <- matrix(penalty_value, nrow = n_students, ncol = n_topics)
  colnames(cost_matrix) <- topic_ids
  rownames(cost_matrix) <- student_preferences$student_id

  # Identify preference columns (everything except student_id)
  pref_cols <- setdiff(names(student_preferences), "student_id")

  message("[DEBUG] Building Cost Matrix based on preferences...")

  # Fill in the costs based on ranks
  # (Rank 1 = Cost 1, Rank 2 = Cost 2, etc.)
  for (i in 1:n_students) {
    # Extract this student's row as a character vector
    s_prefs <- as.character(unlist(student_preferences[i, pref_cols]))

    # Loop through their preferences
    for (rank_idx in seq_along(s_prefs)) {
      topic <- s_prefs[rank_idx]

      # Only process if it is a valid topic and not NA
      if (!is.na(topic) && topic %in% topic_ids) {
        # Assign rank as cost
        # If a student lists same topic twice, we keep the better rank (min)
        current_cost <- cost_matrix[i, topic]
        cost_matrix[i, topic] <- min(current_cost, rank_idx)
      }
    }
  }

  # Flatten matrix for lpSolve (it takes a single long vector of costs)
  # R flattens column-major by default, but lpSolve usually expects variables
  # ordered as x_1,1, x_1,2... (row by row). We transpose before c() to align.
  cost_vec <- c(t(cost_matrix))

  # --- 4. BUILD CONSTRAINT MATRIX ---
  # This is the mathematical "grid" that tells the solver the rules.
  # We have:
  #   A. Student Constraints (Rows): Each student must have exactly n_topics_per_student
  #   B. Topic Min Constraints (Cols): Each topic must have >= min_cap
  #   C. Topic Max Constraints (Cols): Each topic must have <= max_cap

  # Using efficient matrix construction instead of slow loops
  # Each variable corresponds to a (Student, Topic) pair.

  # A. Student Constraints
  # Structure: Block diagonal of 1s.
  # "Sum of all topics for Student 1" ... "Sum of all topics for Student N"
  student_constraint_mat <- kronecker(diag(n_students), t(rep(1, n_topics)))

  # B. Topic Constraints (Used for both Min and Max)
  # Structure: Repeating identity matrices.
  # "Sum of Student 1..N for Topic A", "Sum of Student 1..N for Topic B"...
  topic_constraint_mat <- kronecker(t(rep(1, n_students)), diag(n_topics))

  # Combine all constraints
  all_constraints <- rbind(
    student_constraint_mat, # Student must have exactly n topics
    topic_constraint_mat, # Topic must have >= min
    topic_constraint_mat # Topic must have <= max
  )

  # Directions
  const_dirs <- c(
    rep("=", n_students),
    rep(">=", n_topics),
    rep("<=", n_topics)
  )

  # Right Hand Side (The limits)
  const_rhs <- c(
    rep(n_topics_per_student, n_students),
    rep(min_cap, n_topics),
    rep(max_cap, n_topics)
  )

  message(
    "[DEBUG] Constraints built. Running Solver (this may take a moment for large datasets)..."
  )

  # --- 5. RUN SOLVER ---
  # all.bin = TRUE forces variables to be 0 or 1.
  # This mathematically guarantees a student cannot get a topic 0.5 times
  # or 2 times (since max value is 1).
  sol <- lpSolve::lp(
    direction = "min",
    objective.in = cost_vec,
    const.mat = all_constraints,
    const.dir = const_dirs,
    const.rhs = const_rhs,
    all.bin = TRUE
  )

  # --- 6. PROCESS RESULTS ---

  if (sol$status != 0) {
    # Status 0 = Success. Status 2 = No Feasible Solution.
    stop(
      "Solver failed to find a valid allocation. This usually means specific constraints cannot be met (e.g., too few topics for the number of students)."
    )
  }

  message(sprintf(
    "[SUCCESS] Optimal solution found. Total Objective Cost: %s",
    sol$objval
  ))

  # Reshape the binary solution vector back into a matrix
  # Dimensions: Rows = Students, Cols = Topics
  result_matrix <- matrix(sol$solution, nrow = n_students, byrow = TRUE)
  colnames(result_matrix) <- topic_ids
  rownames(result_matrix) <- student_preferences$student_id

  # Convert binary matrix to the requested list format
  # We iterate rows and pick column names where value is 1
  output_list <- apply(
    result_matrix,
    1,
    function(row) {
      names(row)[row == 1]
    },
    simplify = FALSE
  )

  # --- 7. FORMAT OUTPUT ---
  # Convert list to wide tibble
  output_tibble <- tibble::enframe(
    output_list,
    name = "student_id",
    value = "topic"
  ) |>
    tidyr::unnest(topic) |>
    dplyr::group_by(student_id) |>
    dplyr::mutate(col_name = paste0("topic", dplyr::row_number())) |>
    dplyr::ungroup() |>
    tidyr::pivot_wider(names_from = col_name, values_from = topic)

  return(output_tibble)
}


#' Reshape Allocation Data to Topic Perspective
#'
#' This function pivots allocation data from a student-centric view (one row per student)
#' to a topic-centric view (one row per topic). It is primarily used to generate
#' class lists or supervisor dashboards from raw allocation tables.
#'
#' @section Transformation Logic:
#' The function transforms the data based on the following three steps:
#'
#' 1. **Pivot to Long Format**: It consolidates multiple topic columns (e.g., `topic1`,
#'    `topic2`) into vertical entries, creating one row per student-topic pair.
#'
#' 2. **Clean Assignments**: Rows containing `NA` values (where a student had fewer
#'    assignments than the maximum columns) are removed to ensure only valid
#'    allocations remain.
#'
#' 3. **Aggregation**: The data is grouped by `topic_id`, and all students assigned
#'    to that topic are combined into a single comma-separated text string.
#'
#' @param data A dataframe or tibble containing allocation data.
#' @param student_col The column containing student identifiers (default: `student_id`).
#' @param topic_cols A tidyselect expression to choose columns containing topic assignments
#'   (default: `starts_with("topic")`).
#'
#' @return A tibble with two columns:
#'   * `topic_id`: The unique identifier for the topic.
#'   * `students`: A character string listing all students assigned to that topic,
#'     separated by commas.
#'
#' @importFrom tidyverse pivot_longer drop_na group_by summarise arrange
#' @export
pivot_to_topic_perspective <- function(
  data,
  student_col = student_id,
  topic_cols = starts_with("topic")
) {
  data %>%
    # Pivot columns defined by topic_cols (default is "starts_with('topic')")
    pivot_longer(
      cols = {{ topic_cols }},
      names_to = "original_col_name", # Temporary column name, won't be in final output
      values_to = "topic_id"
    ) %>%
    # Remove NAs (students without a 2nd topic)
    drop_na(topic_id) %>%
    # Group by the topic ID
    group_by(topic_id) %>%
    # Summarise the student column (dynamically selected) into a string
    summarise(
      students = paste({{ student_col }}, collapse = ", "),
      .groups = "drop" # Ungroup after summarizing
    ) %>%
    # Sort for readability
    arrange(topic_id)
}
