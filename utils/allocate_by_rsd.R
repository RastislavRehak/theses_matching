#' Allocate Students to Topics using Random Serial Dictatorship
#'
#' This function allocates students to topics based on ranked preferences, capacity
#' constraints, and a randomized fairness algorithm. It iterates through assignment
#' rounds automatically until the total capacity of all topics is filled.
#'
#' @section Assignment Rules:
#' The function operates based on the following three logic rules:
#'
#' 1. **Round-Based Selection**: Assignments occur in rounds. For each round, a
#'    random lottery determines the order in which students pick a topic.
#'
#' 2. **Filling Capacities**: The assignment rounds continue until every available
#'    spot in every topic is filled.
#'
#' 3. **Handling Unmatched Students**: If a student's preferred topics are full—or
#'    they have no preferences left—they are placed on a waitlist for that round.
#'    Once the round finishes, waitlisted students are randomly assigned to any
#'    remaining leftover spots before the next round begins.
#'
#' 4. **Availability of topics**:
#'
#' @param data A dataframe or tibble containing student data.
#'   * Must contain a column named `student_id`.
#'   * All other columns are treated as ranked preferences.
#' @param capacity An integer representing the maximum number of students allowed per topic.
#' @param seed (Optional) An integer to set the random seed for reproducibility.
#'
#' @return A wide-format tibble where each row represents a student, and columns
#'   (`assigned_1`, `assigned_2`, etc.) represent their assigned topics across the rounds.
#'
#' @importFrom tidyverse enframe unnest group_by mutate ungroup pivot_wider
#' @export
allocate_by_rsd <- function(
  student_preferences,
  topic_ids,
  n_topics_per_student = 2,
  seed = NULL
) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Setup
  ## adjust student_preferences

  student_preferences <- student_preferences |>
    rowwise() |>
    mutate(
      prefs = list(na.omit(c_across(starts_with("pref")))), # c(pref1, pref2, ...)
      assigned = list(character())
    ) |>
    ungroup() |>
    select(student_id, prefs, assigned)

  ## Numbers
  n_students <- nrow(student_preferences)

  n_topics <- length(topic_ids)

  topic_capacity_min <- floor(n_topics_per_student * n_students / n_topics)

  n_bonus_topics <- (n_topics_per_student * n_students) %% n_topics

  print(paste(
    "[DEBUG] There are",
    n_students,
    "students,",
    n_topics,
    "topics and each topic has at least a capacity of",
    topic_capacity_min,
    ". This means that",
    n_bonus_topics,
    "topics need to be allocated one additional time."
  ))

  ## Create topic pool

  # 1. Base pool: each topic repeated topic_capacity_min times
  base_pool <- rep(topic_ids, each = topic_capacity_min)

  # 2. Draw by lot which topics get +1 capacity (distinct topics)
  bonus_topics <- sample(topic_ids, size = n_bonus_topics, replace = FALSE)

  # 3. Build the full topic pool
  topic_pool <- c(base_pool, bonus_topics)

  # (Optional) Randomize order of the pool
  topic_pool <- sample(topic_pool)

  print("[DEBUG] Topic pool:")
  print(topic_pool)

  ## Create Student Pool

  student_queue <- rep(
    student_preferences$student_id,
    each = n_topics_per_student
  )

  # randomize order:
  student_queue <- sample(student_queue)

  print("[DEBUG] Student queue:")
  print(student_queue)

  # create lookup for id to row

  id_to_row <- setNames(
    seq_len(nrow(student_preferences)),
    student_preferences$student_id
  )

  # pref_cols <- c("pref1", "pref2", "pref3")
  #
  # student_prefs <- lapply(seq_len(nrow(student_preferences)), function(i) {
  #   prefs <- as.integer(unlist(student_preferences[i, pref_cols]))
  #   prefs <- prefs[!is.na(prefs)]
  #   prefs
  # })
  # names(student_prefs) <- student_preferences$student_id

  # TODO: Think about how to manage the "topic only once per student" thing. Maybe have one central register of students where their topics get removed as they got a topic assigned.

  # the student df needs one column with prefs and one with assignments vectors. if something is assigned, it gets removed from the prefs and placed to assigned.

  hold_back <- vector(mode(student_queue), 0) # same type as student_queue

  for (s_id in student_queue) {
    # row index for this student
    row_idx <- id_to_row[as.character(s_id)]

    # current prefs and assigned topics for this student
    prefs <- student_preferences$prefs[[row_idx]]
    assigned <- student_preferences$assigned[[row_idx]]

    # filter prefs: still in topic_pool and not already assigned
    available <- prefs[prefs %in% topic_pool & !(prefs %in% assigned)]

    if (length(available) == 0L) {
      # nothing left from their prefs -> put student on hold
      hold_back <- c(hold_back, s_id)
      next
    }

    # highest-ranked available topic is the first one
    chosen <- available[1]

    # remove one occurrence of chosen from topic_pool
    rem_idx <- match(chosen, topic_pool) # first position
    if (!is.na(rem_idx)) {
      topic_pool <- topic_pool[-rem_idx]
    } else {
      # should not happen if available was computed correctly
      next
    }

    # remove chosen from this student's prefs (so they can't get it again)
    prefs_new <- prefs[prefs != chosen]
    student_preferences$prefs[[row_idx]] <- prefs_new

    # add chosen to this student's assigned list
    student_preferences$assigned[[row_idx]] <- c(assigned, chosen)
  }

  return(list(student_preferences, hold_back, topic_pool))

  # # Assign Topics
  # queue <- sample(student_pool$student_id)
  # held_back <- c()
  #
  # for (id in queue) {
  #   my_topics <- results[[as.character(id)]]
  #   # Get valid prefs (ignoring NAs)
  #   prefs <- na.omit(as.character(unlist(data[data$student_id == id, -1])))
  #
  #   picked <- NA
  #   for (p in prefs) {
  #     # Check: Spot free? AND Not duplicate for this student?
  #     if (usage[p] < capacity && !(p %in% my_topics)) {
  #       picked <- p
  #       break
  #     }
  #   }
  #
  #   if (!is.na(picked)) {
  #     results[[as.character(id)]] <- c(my_topics, picked)
  #     usage[picked] <- usage[picked] + 1
  #   } else {
  #     # Rule 3: Hold back
  #     held_back <- c(held_back, id)
  #   }
  # }
  #
  # # --- Phase B: Held Back Allocation (Leftovers) ---
  # if (length(held_back) > 0) {
  #   # Create pool of empty chairs ( Topic A, A, B, C...)
  #   pool <- rep(names(usage), pmax(capacity - usage, 0))
  #
  #   for (hb in sample(held_back)) {
  #     # Randomize waiting room
  #     if (length(pool) == 0) {
  #       break
  #     }
  #     my_topics <- results[[as.character(hb)]]
  #
  #     # Select from pool, forbidding duplicates
  #     valid_pool <- pool[!(pool %in% my_topics)]
  #
  #     if (length(valid_pool) > 0) {
  #       # Random assignment from leftovers
  #       pick <- sample(valid_pool, 1)
  #       results[[as.character(hb)]] <- c(my_topics, pick)
  #
  #       # Update usage and remove chair from pool
  #       usage[pick] <- usage[pick] + 1
  #       pool <- pool[-match(pick, pool)]
  #     }
  #   }
  # }
}


# results <- list()
#
# # Total Slots / Students = Max topics needed per person to fill everything
# # rounds <- ceiling((length(topics) * capacity) / nrow(data))
#
# for (r in 1:rounds) {
#   # Rule 1: Sort randomly per round
#   queue <- sample(data$student_id)
#   held_back <- c()
#
#   # --- Phase A: Priority Pick ---
#   for (id in queue) {
#     my_topics <- results[[as.character(id)]]
#     # Get valid prefs (ignoring NAs)
#     prefs <- na.omit(as.character(unlist(data[data$student_id == id, -1])))
#
#     picked <- NA
#     for (p in prefs) {
#       # Check: Spot free? AND Not duplicate for this student?
#       if (usage[p] < capacity && !(p %in% my_topics)) {
#         picked <- p
#         break
#       }
#     }
#
#     if (!is.na(picked)) {
#       results[[as.character(id)]] <- c(my_topics, picked)
#       usage[picked] <- usage[picked] + 1
#     } else {
#       # Rule 3: Hold back
#       held_back <- c(held_back, id)
#     }
#   }
#
#   # --- Phase B: Held Back Allocation (Leftovers) ---
#   if (length(held_back) > 0) {
#     # Create pool of empty chairs ( Topic A, A, B, C...)
#     pool <- rep(names(usage), pmax(capacity - usage, 0))
#
#     for (hb in sample(held_back)) {
#       # Randomize waiting room
#       if (length(pool) == 0) {
#         break
#       }
#       my_topics <- results[[as.character(hb)]]
#
#       # Select from pool, forbidding duplicates
#       valid_pool <- pool[!(pool %in% my_topics)]
#
#       if (length(valid_pool) > 0) {
#         # Random assignment from leftovers
#         pick <- sample(valid_pool, 1)
#         results[[as.character(hb)]] <- c(my_topics, pick)
#
#         # Update usage and remove chair from pool
#         usage[pick] <- usage[pick] + 1
#         pool <- pool[-match(pick, pool)]
#       }
#     }
#   }
# }
#
# # Output: Convert to Wide Tibble
# enframe(results, name = "student_id", value = "topic") %>%
#   unnest(topic) %>%
#   group_by(student_id) %>%
#   mutate(n = paste0("topic", row_number())) %>%
#   ungroup() %>%
#   pivot_wider(names_from = n, values_from = topic)
# }

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
