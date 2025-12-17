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
allocate_by_rsd <- function(data, capacity = NULL, seed = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }

  # Setup
  topics <- unique(na.omit(unlist(data %>% select(starts_with("pref")))))

  if (is.null(capacity)) {
    # Each topic gets enough seats so that total capacity ≈ number of students
    capacity <- max(1L, ceiling(nrow(data) / length(topics)))
    print(paste0("Each topic has a capacity of ", capacity, " students."))
  }

  usage <- setNames(rep(0, length(topics)), topics)
  results <- list()

  # Total Slots / Students = Max topics needed per person to fill everything
  rounds <- ceiling((length(topics) * capacity) / nrow(data))

  for (r in 1:rounds) {
    # Rule 1: Sort randomly per round
    queue <- sample(data$student_id)
    held_back <- c()

    # --- Phase A: Priority Pick ---
    for (id in queue) {
      my_topics <- results[[as.character(id)]]
      # Get valid prefs (ignoring NAs)
      prefs <- na.omit(as.character(unlist(data[data$student_id == id, -1])))

      picked <- NA
      for (p in prefs) {
        # Check: Spot free? AND Not duplicate for this student?
        if (usage[p] < capacity && !(p %in% my_topics)) {
          picked <- p
          break
        }
      }

      if (!is.na(picked)) {
        results[[as.character(id)]] <- c(my_topics, picked)
        usage[picked] <- usage[picked] + 1
      } else {
        # Rule 3: Hold back
        held_back <- c(held_back, id)
      }
    }

    # --- Phase B: Held Back Allocation (Leftovers) ---
    if (length(held_back) > 0) {
      # Create pool of empty chairs ( Topic A, A, B, C...)
      pool <- rep(names(usage), pmax(capacity - usage, 0))

      for (hb in sample(held_back)) {
        # Randomize waiting room
        if (length(pool) == 0) {
          break
        }
        my_topics <- results[[as.character(hb)]]

        # Select from pool, forbidding duplicates
        valid_pool <- pool[!(pool %in% my_topics)]

        if (length(valid_pool) > 0) {
          # Random assignment from leftovers
          pick <- sample(valid_pool, 1)
          results[[as.character(hb)]] <- c(my_topics, pick)

          # Update usage and remove chair from pool
          usage[pick] <- usage[pick] + 1
          pool <- pool[-match(pick, pool)]
        }
      }
    }
  }

  # Output: Convert to Wide Tibble
  enframe(results, name = "student_id", value = "topic") %>%
    unnest(topic) %>%
    group_by(student_id) %>%
    mutate(n = paste0("assigned_", row_number())) %>%
    ungroup() %>%
    pivot_wider(names_from = n, values_from = topic)
}
