# Task checklist

What a Windows migrant does in the first week. Each task is performed on the pilot from a
fresh user account, and the result is recorded: the steps actually taken, and whether the
design got in the way.

This replaces "used it daily long enough to know it works" for two reasons. The pilot is a VM
on a Windows host and would not honestly get that use. And a checklist survives being handed
to a second person, where an impression does not.

Run it end to end at least twice, on separate iterations of the design, and record the
results both times. The first run finds the obvious problems. The second finds whether fixing
them broke something else.

## How to record a run

Copy the table into a new `## Run N` section, fill in the two right-hand columns, and leave
the previous runs in place. This is the one document in the repo that accumulates rather than
being rewritten, because the value is in comparing runs.

Verdict is one of:

- **clean** — did it without hesitating, no surprises
- **friction** — got there, but the path was not the obvious one
- **blocked** — could not do it without looking something up outside the machine

Write what actually happened in the notes, including the wrong turns. A task marked *friction*
with no note explaining the friction is not a result.

## Tasks

| # | Task | Verdict | Notes |
|---|---|---|---|
| 1 | Find a file by name, when you know roughly what it is called and not where it is | | |
| 2 | Extract an archive someone sent you | | |
| 3 | Connect to a network share, and reconnect to it the next day | | |
| 4 | Take a screenshot of one window and paste it into a document | | |
| 5 | Switch between two windows of the same application | | |
| 6 | Change the default browser | | |
| 7 | Connect to wifi | | |
| 8 | Mount a USB stick, copy a file to it, and eject it safely | | |
| 9 | Install an application you have heard of but which is not already there | | |
| 10 | Find out why the machine is running slowly | | |
| 11 | Open a PDF, a spreadsheet and a video | | |
| 12 | Change the desktop wallpaper | | |

Tasks 10 through 12 are additions to the original list. Task 10 is here because "what is
eating my CPU" is the first thing a technically literate user does when something feels
wrong, and it is the task that justifies binding the task manager to its Windows keystroke.
Tasks 11 and 12 exist because the default application set and the theming are both design
decisions that no other task exercises end to end.

## Runs

No runs recorded yet. The design has to stop changing before the first one is worth anything
— a checklist run against a moving design measures nothing.
