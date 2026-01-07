# Goal

With this R project, we want to implement a two-stage thesis allocation system. It works in the following way:

1. Students hand in preferences for topics that were proposed by the supervisors.
2. An algorithm assigns students to topics on which they can write proposals.
3. Students submit proposals and submit preferences for the topics they wrote proposals on. Supervisors rank the proposals by quality.
4. An algorithm assigns students to topics for the final allocation.


# Round 1

## Input
- BA_01_Preferences_Students.txt (txt instead of csv because the preferences may not be complete---indifference)

## Code
- BA_02_Allocation.R (randomized serial dictatorship?)

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

Hey Rasto!
