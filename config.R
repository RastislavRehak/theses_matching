# USER PREFERENCES
n_topics_per_student <- 2 # the number of students that shall be assigned to each topic. Leave NULL for automatic calculation that ensures every student gets at least one topic.

# PROGRAM DEFAULTS - usually do not change them
## Paths
### Input
topics_path <- "input/topics.txt"
student_preferences_round1_path <- "input/student_preferences_round1.txt"
allocations_round1_path <- "output/allocations_round1.txt"
student_preferences_round2_path <- "input/student_preferences_round2.txt"
supervisor_preferences_path <- "input/supervisor_preferences.txt"
### Output
allocations_round1_students_path <- "output/allocations_round1_students.csv"
allocations_round1_supervisors_path <- "output/allocations_round1_supervisors.csv"
allocations_round2_path <- "output/allocations_round2.csv"
unassigned_round2_path <- "output/unassigned_round2.csv"

## Seed
allocation_seed_round1 <- 20250101
