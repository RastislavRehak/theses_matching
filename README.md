# Optimal Allocation of Theses

## Overview

This R project delivers a robust, automated framework for assigning theses using **matching market mechanisms**. It supports both **Bachelor (BA)** and **Master (MA)** thesis allocation, each with its own workflow tailored to institutional requirements.

| Program | Rounds | Mechanism |
|-----------------------|---------------------|----------------------------|
| **Bachelor** | 2 rounds | ILP (proposal distribution) → Deferred Acceptance (final match) |
| **Master** | 1 round | Deferred Acceptance (direct match) |

------------------------------------------------------------------------

## Bachelor Thesis Allocation

Allocating BA thesis topics involves balancing student interests, supervisor capacities, and academic merit. This tool solves this complexity by splitting the process into a **Proposal Phase** and a **Final Match Phase**.

### The Workflow

**Round 1: Proposal Distribution** \* **Goal:** Assign every student a fixed number of topics (e.g., 2) to explore and write proposals for. \* **Mechanism:** Students submit a ranked list of preferred topics. \* **Algorithm:** The system uses **Integer Linear Programming (ILP)** to comply with constraints as outlined below.

**Round 2: Final Allocation (Matching)** \* **Goal:** Determine the final, one-to-one Student-Topic pairs. \* **Mechanism:** \* **Students** submit preferences for the topics they wrote proposals on. \* **Supervisors** rank the received proposals based on quality. \* **Algorithm:** The system applies the **Deferred Acceptance (DA)** algorithm (Gale-Shapley).

### Algorithm Justification

#### Round 1

For **Round 1**, we utilize **Integer Linear Programming (ILP)** instead of standard sequential algorithms (like Random Serial Dictatorship or greedy selection). This decision was driven by three strict constraints that iterative algorithms frequently fail to satisfy simultaneously:

-   **Strict Topic Balancing (Fair Distribution):** To ensure fairness for supervisors, the workload must be distributed evenly. We calculate dynamic `Min` and `Max` capacities for every topic (e.g., if there are 200 slots and 10 topics, every topic must have exactly 20 students). Standard algorithms often overfill popular topics early, violating the strict `Max` constraint for the group.
-   **Guaranteed Assignment Quotas:** Every student **must** be assigned exactly $n$ distinct topics for their proposals. Iterative algorithms often "paint themselves into a corner"—satisfying the first 90% of students perfectly but leaving the last 10% with no valid topics left to choose from.
-   **Global Optimization vs. Sequential Bias:** Sequential algorithms solve the problem one student at a time. If a student early in the queue takes a spot that is the *only* valid option for a student later in the queue, the system breaks. ILP looks at all students, all preferences, and all constraints simultaneously to find the global optimum that minimizes the total "cost" (dissatisfaction) of the cohort.

#### Round 2

For **Round 2**, the system implements the **Supervisor-Proposing Deferred Acceptance Algorithm (Gale-Shapley)**. This configuration handles the matching based on the following structural constraints and optimization criteria:

-   **Two-Sided Preference Integration:** The allocation functions as a two-sided matching market. It must integrate inputs from two distinct sets of ordinal rankings: **Student Preferences** (ranking of topics) and **Supervisor Preferences** (ranking of proposal quality/suitability).
-   **Stability Condition:** The solution implies a strict validity constraint known as **Stability**. The algorithm ensures that no "blocking pair" exists—a scenario where a Supervisor and a Student both prefer each other over their assigned matches.
-   **Supervisor-Optimality:** The choice of the Supervisor-Proposing variant enforces a specific optimization constraint. Among the set of all mathematically possible stable matchings, this algorithm selects the **Supervisor-Optimal** solution. This maximizes the assignment quality from the supervisors' perspective according to their submitted rankings.

------------------------------------------------------------------------

## Master Thesis Allocation

MA thesis allocation uses a simpler single-round process since students apply directly to supervisors rather than to predefined topics.

### The Workflow

**Single Round: Direct Matching** \* **Goal:** Match students to supervisors based on mutual preferences. \* **Mechanism:** \* **Students** submit a ranked list of preferred supervisors. \* **Supervisors** rank interested students based on fit and qualifications. \* **Algorithm:** The system applies the **Deferred Acceptance (DA)** algorithm (Gale-Shapley).

### Algorithm Justification

The **Supervisor-Proposing Deferred Acceptance Algorithm** is used for the same reasons as BA Round 2:

-   **Two-Sided Preferences:** Both students and supervisors have rankings that must be respected.
-   **Stability:** No student-supervisor pair should prefer each other over their assigned matches.
-   **Supervisor-Optimality:** The algorithm prioritizes supervisor preferences, selecting the supervisor-optimal stable matching.

------------------------------------------------------------------------

## Preparations

Follow these steps to download the project and synchronize your R environment using the RStudio interface.

### 1. Prerequisites

Before starting, ensure you have the following installed on your computer: \* [R](https://cran.r-project.org/) \* [RStudio Desktop](https://posit.co/download/rstudio-desktop/) \* [Git](https://git-scm.com/downloads) (Required for RStudio to download the files) \* [Rtools](https://cran.r-project.org/bin/windows/Rtools/) (Required for building some R packages that are not available as a binary)

### 2. Download the Project (Cloning via RStudio)

You do not need to use the command line. You can download the project directly through RStudio:

1.  **Copy the Repository URL:** Go to the main page of this repository on GitHub. Click the green **Code** button and copy the HTTPS URL (e.g., `https://github.com/username/repo.git`).

2.  **Open New Project Wizard:** Open RStudio. Go to the menu bar at the top and select: **File** → **New Project...**

3.  **Select Version Control:** In the "New Project" wizard, click the option **Version Control**.

4.  **Select Git:** Click on **Git**.

5.  **Paste and Create:**

    -   **Repository URL:** Paste the URL you copied in step 1.
    -   **Project Directory Name:** This will automatically fill in (you can leave it as is).
    -   **Create project as subdirectory of:** Choose where you want the folder saved on your computer (e.g., Desktop or Documents).
    -   Click **Create Project**.

You might be prompted to enter your GitHub credentials. RStudio will now download all files and automatically open the project for you.

### 3. Setup the R Environment (`renv`)

This project uses `renv` to ensure you have the exact correct versions of the required packages.

1.  **Wait for Automatic Activation:** Once the project opens, look at the **Console** (usually the bottom-left pane). You should see a message stating that the project has been loaded.

    -   *Note: If you see a yellow banner at the top of the screen saying "Project environment is out of sync," that is normal.*

2.  **Restore Packages:** In the **Console** pane, type the following command and press **Enter**:

    ``` r
    renv::restore()
    ```

3.  **Confirm Installation:** The system will ask you to confirm the installation of the required packages. Type `y` and press **Enter**.

Once this completes, your environment is perfectly synchronized and ready to run the allocation tool.

------------------------------------------------------------------------

## Running Allocations

### BA Round 1: Proposal Distribution

#### Input

Place the following files in the `input/` folder (see examples in folder):

| File | Format | Description |
|------------------|---------------------|----------------------------------|
| `student_preferences_ba_round1.txt` | TXT, no header | Column 1: `student_id`. Remaining columns: `topic_id`s in preference order (best first). |
| `topics_ba.txt` | TXT, no header | Column 1: `topic_id`. |

#### Running

Open `allocation_ba_round1.Rmd` and adjust `n_topics_per_student` if necessary (default: 2). Then run all chunks. If the algorithm finds multiple solutions, it exports them to an Excel sheet in the `output/` folder. Choose a solution by adjusting `pref_solution` (default: solution 1).

#### Output

| File | Description |
|-----------------------|-------------------------------------------------|
| `allocations_ba_round1_students.csv` | One row per student with assigned topics |
| `allocations_ba_round1_topics.csv` | One row per topic with assigned students |

------------------------------------------------------------------------

### BA Round 2: Final Matching

#### Input

| File | Format | Description |
|------------------|---------------------|----------------------------------|
| `student_preferences_ba_round2.txt` | TXT, no header | Column 1: `student_id`. Remaining columns: `supervisor_id`s (i.e. topic ids) in preference order. |
| `supervisor_preferences_ba.txt` | TXT, no header | Column 1: `supervisor_id`. Remaining columns: `student_id`s ranked by proposal quality (best first). |

#### Running

Open `allocation_ba_round2.Rmd` and run all chunks.

#### Output

| File                        | Description                              |
|-----------------------------|------------------------------------------|
| `allocations_ba_round2.csv` | One row per matched student-topic pair   |
| `unassigned_ba_round2.csv`  | Unmatched students or supervisors/topics |

------------------------------------------------------------------------

### MA: Direct Matching

#### Input

| File | Format | Description |
|------------------|---------------------|----------------------------------|
| `student_preferences_ma.txt` | TXT, no header | Column 1: `student_id`. Remaining columns: `supervisor_id`s in preference order (best first). |
| `supervisor_preferences_ma.txt` | TXT, no header | Column 1: `supervisor_id`. Column 2: `capacity` of the supervisor. Remaining columns: `student_id`s ranked by preference (best first). |

#### Running

Open `allocation_ma.Rmd` and run all chunks.

#### Output

| File                 | Description                                 |
|----------------------|---------------------------------------------|
| `allocations_ma.csv` | One row per matched student-supervisor pair |
| `unassigned_ma.csv`  | Unmatched students and supervisors          |
