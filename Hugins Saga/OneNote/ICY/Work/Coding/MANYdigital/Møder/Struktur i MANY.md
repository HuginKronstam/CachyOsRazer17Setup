Dev-Ops

- Backlog
- Sprints  
Dokumentation
 
Nye Klubber
 
Teams

DevOps guidelines  
Epics:  
This represents a grouping of assignments, examples are:

- Onboarding a new club
- Launching a new major version
- A dump for all issues that have not yet been assigned to a specific epic.

Epics will be controlled by ManyDigital.
 
Issues:  
These are specific problems or desired features that have been identified by ManyDigital. This does NOT represent the specific actions that are required to solve the issue. An example could be:

- Implement push messages in different languages

When an issue has been created, ManyDigital will tag someone who is then responsible for trying to break the issue down into specific tasks.
 
Task:  
The actions and assignments required the fix the issues are tasks. Please aim to be specific in describing the tasks. When creating a task it is required you write a description for the task.  
After a task has been added to the backlog, await someone from ManyDigital to tag a person who is then responsible for estimating the required work to complete the task, then do the following:

- Write a comment on the task with the estimation.
- Set "Remaining Work" equal to the estimate.
 
When the task has been added to DevOps please await for it to be added to the weekly sprint before commencing work on it.  
Scrum meetings will be held every Friday morning at 10 o'clock, at this meeting tasks will be added to the sprint, ManyDigital will then assign the task to the relevant SoftLab programmer or "Nemanja Đoković" for re-assignment.  
When working on the task, remember to update the "remaining work" before the end of the day, and keep relevant people to the task tagged.
 
After completing a task. Please set its state to "review" and tag a relevant ManyDigital employee. When in doubt tag the ManyDigital project manager, "Frederik Winstrup Johansen" by default.  
ManyDigital will then test the solution and move it done if tests are successful.
 
Git  
Feature Branch :[https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/feature-branch-workflow)  
We follow the feature branch workflow when working on tasks, if a commit directly relates to a task in DevOps, please name the branch feature/"#TaskNo"  
Gitflow : [https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow](https://www.atlassian.com/git/tutorials/comparing-workflows/gitflow-workflow)  
The overall flow of Gitflow is:

1. A develop branch is created from master
2. A release branch is created from develop
3. Feature branches are created from develop
4. When a feature is complete it is merged into the develop branch
5. When the release branch is done it is merged into master then develop
6. Release branches and feature branches are deleted once they have been merged into develop
7. If an issue in master is detected a hotfix branch is created from master
8. Once the hotfix is complete it is merged to both develop and master

Secondkey = TMCL  
ThirdKey = COMP

VI tagger ham i de tasks han skal estimere. Han skal ikke bekymre sig om andet end det
 
Try to avoid private chat unless its absolutely nessesary