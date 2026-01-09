# Allocation of Bachelor Theses

With this R project, we want to implement a two-stage thesis allocation system. It works in the following way:

Round 1
1. Students hand in preferences for topics that were proposed by the supervisors.
2. An algorithm assigns students to topics on which they can write proposals. Every student gets the same number of topics to write proposals on.

Round 2
3. Students submit proposals and submit preferences for the topics they wrote proposals on. Supervisors rank the proposals by quality.
4. An algorithm assigns students to topics for the final allocation.


## Usage

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






## Input
- BA_01_Preferences_Students.txt (txt instead of csv because the preferences may not be complete---indifference)

## Code
- BA_02_Allocation.R (randomized serial dictatorship?)

### RSD intuition
there are s students and t topics. We will have s*2 allocations. The number of topic capacity for all topics is floor(s*2/t). The remaining allocation slots will be determined at random. Therefore, there will be as many topic slots as allocation slots. 

## Output
- BA_03_Allocations.txt (allocation of students to topics on which they can write proposals; default capacity of topics is 2, but adaptive to the number of students)


# Round 2

## Inputs
- BA_04_Preferences_Students.txt (txt instead of csv because the preferences may not be complete---indifference; some students may drop at this stage---failure to submit any proposal)
- BA_05_Preferences_Supervisors.txt (txt instead of csv because the preferences may not be complete---indifference)

## Code
- BA_06_Allocation.R (a modification of supervisor-proposing DA?)

## Output
- BA_07_Allocations.txt (final allocation of students to topics; list all students who submitted something, even the unassigned ones with topic NA; list all topics, even the unassigned ones with student NA)

# Open ToDos
- talk to rasto if the currently implemented rsd and da logics are as intended
- refactor everything
- make readme really helpful