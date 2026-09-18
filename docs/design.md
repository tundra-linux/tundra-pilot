# The Tundra desktop design

The design as rules, stated independently of the configuration that implements it.

This document exists because the config files are disposable and the design is not. A
Look-and-Feel package, a `kdeglobals` and a `kglobalshortcutsrc` are worthless the moment
Plasma is replaced, which is the explicit intent for a later phase of this project. What
survives is the reasoning here. Writing it down costs an afternoon now and saves
rediscovering the design from a screenshot years later.

So: no KDE keys below, and no file names. If a rule cannot be stated without naming a
Plasma setting, it is an implementation detail and belongs in the config, not here.

## Who this is for

Someone technically literate who is leaving Windows. They know what a filesystem is, they
have used a terminal, and they are not looking for a tutorial. They are also not looking for
a puzzle: the cost of an unfamiliar desktop is paid in the first week, and most people stop
paying before the week is out.

The design target is that the first week contains no moment where the user cannot find
something they know exists.

## Rules

**The taskbar is at the bottom and always visible.** One panel, no auto-hide, no second
panel. Auto-hide trades a permanent orientation cue for screen space nobody asked for.

**Left to right: launcher, running applications, status, clock.** This is the Windows
arrangement and it is load-bearing, because it is the one spatial habit every migrant has.
The launcher is at the far left corner. The clock is at the far right.

**Task buttons are icons, not labelled buttons.** Windows 11 does this and current Windows
users expect it. Hovering identifies a window; the label is redundant at the cost of fitting
four windows on a panel instead of a dozen.

**The far right edge shows the desktop when clicked.** A behaviour people reach for without
knowing they learned it.

**Double-click opens, single-click selects.** Plasma has defaulted to this since 6.0, for
exactly this reason, so it is a rule this design inherits rather than imposes.

**The file manager shows an editable path box.** A Windows user types a path into the
location bar. A breadcrumb that cannot be typed into reads as a missing feature, not as a
different design.

**The file manager shows the full path.** Ambiguity about where you are is the single most
common way a migrant loses a file.

**A terminal opens inside the file manager, at the current directory.** The audience is
technically literate; this is the shortcut they will actually use, and it costs one keystroke
to expose.

**The Windows key is a modifier, not a menu button.** It opens the launcher on its own, and
carries the window-management shortcuts in combination: explorer, run, show desktop, and
snapping windows to screen halves with the arrow keys.

**The task manager is on the three-finger salute.** Ctrl+Shift+Esc. The keystroke is muscle
memory and there is no reason to spend it on anything else.

**Shortcuts ship as a delta.** The desktop inherits whatever its shell already binds, and
only the bindings that differ are stated. Shipping a full shortcut set freezes every
unrelated default at the version it was captured on and fights every future release.

**One visual theme, chosen once, applied to everything.** Qt applications and GTK
applications look the same because both are told the same thing at install time. No theme
engine, no syncing daemon, no process running to keep two toolkits agreed. A theme engine is
a dependency and a running process; a static choice is a config key.

**Fonts are named as families, never as packages.** The face that provides a family differs
per distribution and the design does not care which package it came from.

**Nothing is locked.** No immutable settings, no greyed-out controls. The audience is
technically literate, and locking a setting converts a user who would have changed it into a
support request.

**Defaults are updatable.** Anything the system keeps controlling ships where a later update
can still reach it. Copying defaults into a new user's home directory at account creation
reaches nobody who already has an account, which for a system that ships updates is a bug
rather than a mechanism.

## What is deliberately not decided here

Window decoration details, animation timing, and the specific colour values. These are
theming rather than design: they can change without any user having to relearn anything, and
pinning them here would give a later implementation a set of constraints that carry no
reasoning.

## Validation

The design is validated against the task checklist in [`checklist.md`](checklist.md), not
against a claim of daily use. The pilot is a VM on a Windows host and would not honestly get
that use, and a checklist survives being handed to a second person in a way an impression
does not.
