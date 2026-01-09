# Optimal Allocation of Bachelor Theses

## Overview

This R project delivers a robust, automated framework for assigning bachelor theses using a **two-stage matching market mechanism**.

Allocating thesis topics involves balancing student interests, supervisor capacities, and academic merit. This tool solves this complexity by splitting the process into a **Proposal Phase** and a **Final Match Phase**.

### The Workflow

**Round 1: Proposal Distribution**
*   **Goal:** Assign every student a fixed number of topics (e.g., 2) to explore and write proposals for.
*   **Mechanism:** Students submit a ranked list of preferred topics.
*   **Algorithm:** The system uses a **Integer Linear Programming (ILP)** algorithm to comply with a number of restrictions as outlined below.

**Round 2: Final Allocation (Matching)**
*   **Goal:** Determine the final, one-to-one Student-Supervisor pairs.
*   **Mechanism:**
    *   **Students** submit preferences for the topics they wrote proposals on.
    *   **Supervisors** rank the received proposals based on quality.
*   **Algorithm:** The system applies the **Deferred Acceptance (DA)** algorithm (Gale-Shapley).

## Algorithm Justification

### Round 1

For **Round 1**, we utilize **Integer Linear Programming (ILP)** instead of standard sequential algorithms (like Random Serial Dictatorship or greedy selection). This decision was driven by three strict constraints that iterative algorithms frequently fail to satisfy simultaneously:

*   **Strict Topic Balancing (Fair Distribution):** To ensure fairness for supervisors, the workload must be distributed evenly. We calculate dynamic `Min` and `Max` capacities for every topic (e.g., if there are 200 slots and 10 topics, every topic must have exactly 20 students). Standard algorithms often overfill popular topics early, violating the strict `Max` constraint for the group.
*   **Guaranteed Assignment Quotas:** Every student **must** be assigned exactly $n$ distinct topics for their proposals. Iterative algorithms often "paint themselves into a corner"—satisfying the first 90% of students perfectly but leaving the last 10% with no valid topics left to choose from.
*   **Global Optimization vs. Sequential Bias:** Sequential algorithms solve the problem one student at a time. If a student early in the queue takes a spot that is the *only* valid option for a student later in the queue, the system breaks. ILP looks at all students, all preferences, and all constraints simultaneously to find the global optimum that minimizes the total "cost" (dissatisfaction) of the cohort.

### Round 2

For **Round 2**, the system implements the **Supervisor-Proposing Deferred Acceptance Algorithm (Gale-Shapley)**. This configuration handles the matching based on the following structural constraints and optimization criteria:

*   **Two-Sided Preference Integration:** The allocation functions as a two-sided matching market. It must integrate inputs from two distinct sets of ordinal rankings: **Student Preferences** (ranking of topics) and **Supervisor Preferences** (ranking of proposal quality/suitability).
*   **Stability Condition:** The solution implies a strict validity constraint known as **Stability**. The algorithm ensures that no "blocking pair" exists—a scenario where a Supervisor and a Student both prefer each other over their assigned matches.
*   **Supervisor-Optimality:** The choice of the Supervisor-Proposing variant enforces a specific optimization constraint. Among the set of all mathematically possible stable matchings, this algorithm selects the **Supervisor-Optimal** solution. This maximizes the assignment quality from the supervisors' perspective according to their submitted rankings.

## Preparations

Follow these steps to download the project and synchronize your R environment using the RStudio interface.

### 1. Prerequisites

Before starting, ensure you have the following installed on your computer:
*   [R](https://cran.r-project.org/)
*   [RStudio Desktop](https://posit.co/download/rstudio-desktop/)
*   [Git](https://git-scm.com/downloads) (Required for RStudio to download the files)

### 2. Download the Project (Cloning via RStudio)

You do not need to use the command line. You can download the project directly through RStudio:

1.  **Copy the Repository URL:**
    Go to the main page of this repository on GitHub. Click the green **Code** button and copy the HTTPS URL (e.g., `https://github.com/username/repo.git`).

2.  **Open New Project Wizard:**
    Open RStudio. Go to the menu bar at the top and select:
    **File** $\to$ **New Project...**

3.  **Select Version Control:**
    In the "New Project" wizard, click the option **Version Control**.

4.  **Select Git:**
    Click on **Git**.

5.  **Paste and Create:**
    *   **Repository URL:** Paste the URL you copied in step 1.
    *   **Project Directory Name:** This will automatically fill in (you can leave it as is).
    *   **Create project as subdirectory of:** Choose where you want the folder saved on your computer (e.g., Desktop or Documents).
    *   Click **Create Project**.

You might be prompted to enter your GitHub credentials. RStudio will now download all files and automatically open the project for you.

### 3. Setup the R Environment (`renv`)

This project uses `renv` to ensure you have the exact correct versions of the required packages.

1.  **Wait for Automatic Activation:**
    Once the project opens, look at the **Console** (usually the bottom-left pane). You should see a message stating that the project has been loaded.
    *   *Note: If you see a yellow banner at the top of the screen saying "Project environment is out of sync," that is normal.*

2.  **Restore Packages:**
    In the **Console** pane, type the following command and press **Enter**:

    ```r
    renv::restore()
    ```

3.  **Confirm Installation:**
    The system will ask you to confirm the installation of the required packages. Type `y` and press **Enter**.

Once this completes, your environment is perfectly synchronized and ready to run the allocation tool.

## Round 1 Allocation

### Input
The following files are required to be in the input folder. For all files there are examples in the respective folder.

1. student_preferences_round1.txt -> a comma-separated txt file with no headings. First columns contains the student_id, the other columns contain the topic_ids in descending order of preferences (first topic is highest rank). Indifference is allowed.
2. topics.txt -> same format as student_preferences. First column contains the topic_id, second column contains a name.

### Running the Allocation

Open the file allocation_round1.Rmd and run all chunks. It should proceed without errors, given that the input files are correct. 

### Output

In the output folder, you find two files with basically the same information but optimized for better readability:

1. allocations_round1_students.csv -> One row for each student with the assigned topics.
2. allocations_round1_supervisors.csv -> One row for each topic with the assigned students.

## Round 2 Allocation

### Input
The following files are required to be in the input folder.

1. student_preferences_round2.txt -> as above.
2. supervisor_preferences.txt -> same format as student_preferences. First column contains the topic_id, other columns contain the student_ids in descending quality of their proposals (highest quality is first column).
3. topics.txt -> as above, can be the same file.

### Running the Allocation

Open the file allocation_round2.Rmd and run all chunks.

### Output

In the output folder, you find these files:

1. allocations_round2.csv -> One row for each matched topic/student combination.
2. unassigned_round2.csv -> Contains all students or topics that could not get matched.

## ToDo
- [x] talk to rasto if the currently implemented rsd and da logics are as intended
- [x] refactor everything
- [x] make readme really helpful
- [x] refactor examples
- [x] add algorithm choice considerations to README
- [ ] test with real data
- [ ] do an audit by a second person