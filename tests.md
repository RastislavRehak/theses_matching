# Test Cases for Thesis Allocation

## Test Case 1: BA Round 1 (ILP Proposal Distribution)

### Scenario
8 students, 4 topics, each student gets 2 topic assignments.
Expected: 16 total assignments, 4 per topic (balanced distribution).

### Input Files

**input/student_preferences_ba_round1.txt**
```
S001,T1,T2,T3,T4
S002,T1,T2,T3,T4
S003,T2,T1,T4,T3
S004,T2,T3,T1,T4
S005,T3,T4,T1,T2
S006,T3,T4,T2,T1
S007,T4,T1,T2,T3
S008,T4,T3,T2,T1
```

**input/topics_ba.txt**
```
T1,Machine Learning Applications
T2,Data Visualization
T3,Natural Language Processing
T4,Computer Vision
```

### Expected Behavior
- Each student receives exactly 2 topics
- Each topic receives exactly 4 students (8 students × 2 assignments ÷ 4 topics)
- Algorithm minimizes total preference cost

### Expected Output

**output/allocations_ba_round1_students.csv**
```
student_id,topic_1,topic_2
S001,T1,T2
S002,T1,T2
S003,T2,T1
S004,T2,T3
S005,T3,T4
S006,T3,T4
S007,T4,T1
S008,T4,T3
```

**output/allocations_ba_round1_topics.csv**
```
topic_id,topic_name,student_1,student_2,student_3,student_4
T1,Machine Learning Applications,S001,S002,S003,S007
T2,Data Visualization,S001,S002,S003,S004
T3,Natural Language Processing,S004,S005,S006,S008
T4,Computer Vision,S005,S006,S007,S008
```

---

## Test Case 2: BA Round 2 (Deferred Acceptance)

### Scenario
6 students, 6 topics (1:1 matching). Each student wrote proposals for 2 topics from Round 1.
Tests two-sided matching with supervisor preferences.

### Input Files

**input/student_preferences_ba_round2.txt**
```
S001,T1,T2
S002,T1,T2
S003,T2,T3
S004,T3,T4
S005,T4,T5
S006,T5,T6
```

**input/supervisor_preferences_ba.txt**
```
T1,S002,S001
T2,S001,S003,S002
T3,S003,S004
T4,S005,S004
T5,S006,S005
T6,S006
```

**input/topics_ba.txt**
```
T1,Machine Learning Applications
T2,Data Visualization
T3,Natural Language Processing
T4,Computer Vision
T5,Blockchain Technology
T6,Cybersecurity
```

### Expected Behavior
- Supervisor-proposing DA finds stable matching
- No blocking pairs exist
- Each matched student gets exactly 1 topic

### Expected Output

**output/allocations_ba_round2.csv**
```
topic_id,topic_name,student_id
T1,Machine Learning Applications,S002
T2,Data Visualization,S001
T3,Natural Language Processing,S003
T4,Computer Vision,S005
T5,Blockchain Technology,S006
T6,Cybersecurity,NA
```

**output/unassigned_ba_round2.csv**
```
type,id,name
student,S004,NA
topic,T6,Cybersecurity
```

### Verification of Stability

Check no blocking pairs exist:
- S001 matched with T2. S001 prefers T1, but T1 prefers S002 (its match). ✓
- S004 unmatched. T3 prefers S003 (its match) over S004. T4 prefers S005 (its match) over S004. ✓

---

## Test Case 3: MA Allocation (Direct Deferred Acceptance)

### Scenario
5 students, 4 supervisors with varying capacities.
Tests supervisor capacity constraints and unmatched participants.

### Input Files

**input/student_preferences_ma.txt**
```
M001,SUP1,SUP2,SUP3
M002,SUP1,SUP3,SUP2
M003,SUP2,SUP1,SUP4
M004,SUP3,SUP2,SUP1
M005,SUP4,SUP3,SUP2
```

**input/supervisor_preferences_ma.txt**
```
SUP1,M001,M002,M003,M004
SUP2,M003,M004,M001,M005
SUP3,M004,M002,M005
SUP4,M005,M003
```

**input/supervisors_ma.txt**
```
SUP1,Prof. Smith
SUP2,Prof. Johnson
SUP3,Prof. Williams
SUP4,Prof. Brown
```

### Expected Behavior (Capacity = 1 each)
- Supervisor-proposing DA with capacity constraints
- Stable matching achieved
- One student may be unmatched (5 students, 4 supervisors)

### Expected Output

**output/allocations_ma.csv**
```
supervisor_id,supervisor_name,student_id
SUP1,Prof. Smith,M001
SUP2,Prof. Johnson,M003
SUP3,Prof. Williams,M004
SUP4,Prof. Brown,M005
```

**output/unassigned_ma.csv**
```
type,id,name
student,M002,NA
```

### Verification of Stability

- M002 unmatched. Check all supervisors:
  - SUP1 prefers M001 (match) over M002 ✓
  - SUP2 prefers M003 (match) over M002 (M002 not in SUP2's list) ✓
  - SUP3 prefers M004 (match) over M002 ✓
  - SUP4 doesn't list M002 ✓

---

## Test Case 4: BA Round 1 Edge Case (Ties in Preferences)

### Scenario
4 students with indifference (ties) in preferences.

### Input Files

**input/student_preferences_ba_round1.txt**
```
S001,T1,T2,T2,T3
S002,T1,T1,T3,T2
S003,T2,T3,T1,T1
S004,T3,T2,T1,T1
```

Note: Repeated topic indicates indifference at that rank level.

**input/topics_ba.txt**
```
T1,Topic Alpha
T2,Topic Beta
T3,Topic Gamma
```

### Expected Behavior
- Ties are handled correctly (same cost assigned to tied preferences)
- Each student gets 2 topics
- Distribution: 8 slots across 3 topics ≈ 2-3 per topic

### Expected Output

Exact output depends on tie-breaking, but must satisfy:
- Each student: exactly 2 distinct topics
- Topic counts: between 2 and 3 students each
- Total assignments: 8

---

## Test Case 5: BA Round 2 Edge Case (Mutual Top Preferences)

### Scenario
Perfect alignment - every student is their topic's top choice.

### Input Files

**input/student_preferences_ba_round2.txt**
```
S001,T1,T2
S002,T2,T1
S003,T3,T4
S004,T4,T3
```

**input/supervisor_preferences_ba.txt**
```
T1,S001,S002
T2,S002,S001
T3,S003,S004
T4,S004,S003
```

**input/topics_ba.txt**
```
T1,Topic One
T2,Topic Two
T3,Topic Three
T4,Topic Four
```

### Expected Output

**output/allocations_ba_round2.csv**
```
topic_id,topic_name,student_id
T1,Topic One,S001
T2,Topic Two,S002
T3,Topic Three,S003
T4,Topic Four,S004
```

**output/unassigned_ba_round2.csv**
```
type,id,name
```

Everyone matched with their first choice. No unassigned.

---

## Test Case 6: MA Edge Case (Supervisor with No Acceptable Students)

### Scenario
One supervisor lists no students (or students don't list them).

### Input Files

**input/student_preferences_ma.txt**
```
M001,SUP1,SUP2
M002,SUP1,SUP2
M003,SUP2,SUP1
```

**input/supervisor_preferences_ma.txt**
```
SUP1,M001,M002,M003
SUP2,M003,M002,M001
SUP3,M001,M002,M003
```

Note: No student lists SUP3 in their preferences.

**input/supervisors_ma.txt**
```
SUP1,Prof. Alpha
SUP2,Prof. Beta
SUP3,Prof. Gamma
```

### Expected Behavior
- SUP3 cannot be matched (no student wants them)
- Stable matching among remaining participants

### Expected Output

**output/allocations_ma.csv**
```
supervisor_id,supervisor_name,student_id
SUP1,Prof. Alpha,M001
SUP2,Prof. Beta,M003
```

**output/unassigned_ma.csv**
```
type,id,name
student,M002,NA
supervisor,SUP3,Prof. Gamma
```

---

## Test Case 7: BA Round 1 Large Scale Validation

### Scenario
20 students, 5 topics, 2 assignments each.
Tests ILP scalability and strict balancing.

### Input Files

**input/student_preferences_ba_round1.txt**
```
S01,T1,T2,T3,T4,T5
S02,T1,T2,T3,T4,T5
S03,T1,T2,T3,T4,T5
S04,T1,T2,T3,T4,T5
S05,T2,T3,T4,T5,T1
S06,T2,T3,T4,T5,T1
S07,T2,T3,T4,T5,T1
S08,T2,T3,T4,T5,T1
S09,T3,T4,T5,T1,T2
S10,T3,T4,T5,T1,T2
S11,T3,T4,T5,T1,T2
S12,T3,T4,T5,T1,T2
S13,T4,T5,T1,T2,T3
S14,T4,T5,T1,T2,T3
S15,T4,T5,T1,T2,T3
S16,T4,T5,T1,T2,T3
S17,T5,T1,T2,T3,T4
S18,T5,T1,T2,T3,T4
S19,T5,T1,T2,T3,T4
S20,T5,T1,T2,T3,T4
```

**input/topics_ba.txt**
```
T1,Artificial Intelligence
T2,Big Data Analytics
T3,Cloud Computing
T4,DevOps Practices
T5,Edge Computing
```

### Expected Behavior
- 40 total assignments (20 × 2)
- 8 students per topic (40 ÷ 5)
- Strict balance maintained

### Validation Checks
```r
# After running allocation
allocations <- read_csv("output/allocations_ba_round1_students.csv")

# Each student has exactly 2 topics
stopifnot(all(rowSums(!is.na(allocations[,-1])) == 2))

# Count per topic
topic_counts <- allocations |>
  pivot_longer(-student_id) |>
  count(value) |>
  filter(!is.na(value))

# Each topic has exactly 8 students
stopifnot(all(topic_counts$n == 8))