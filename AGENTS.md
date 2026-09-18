# AGENTS.md

Rules for working on the Tundra pilot configuration tree. The design this implements lives in the
sibling `planning` repo, in `docs/PHASE1.md`. Read it before changing anything structural; it
carries the reasoning, and this file carries only the rules that govern the code.

## What this repo is

A version-controlled set of configuration artifacts, validated on Fedora KDE Plasma Desktop 44,
that Tundra consumes as its default profile. It is not an operating system and it is not a
dotfiles repo. The pilot machine is scaffolding. This tree is the deliverable.

The line is the init system. Everything above it belongs here: desktop configuration, theming,
applications, containers, virtualization, the shell. Everything below it — init, service
supervision, seat and session management, the image, the update transport — belongs to Phase 2 and
must not appear here, including as a simulation of its absence.

## Artifacts take the Alpine shape

Where Fedora and Alpine disagree on where a file goes or what reads it, the artifact is written the
way Alpine wants it and `scripts/apply.sh` does whatever Fedora needs to load it. The adaptation
lives in the apply script and never in the artifact.

The zsh configuration is the case that forced the rule. Alpine's `zsh` sources
`/etc/zsh/zshrc.d/*.zsh`; Fedora's has no such directory. So the artifact is a drop-in file, and
the pilot gets a sourcing hook appended to `/etc/zshrc`. Writing it Fedora's way and translating it
later is how a pilot produces work that has to be done twice.

Two consequences worth stating outright:

- No Fedora tooling, RPM-specific path or distribution-specific helper appears in an artifact.
- No systemd mechanism appears in an artifact. No `systemctl --user` units; autostart goes through
  `~/.config/autostart/` per the XDG spec. This is a rule about what gets captured, not about how
  the pilot boots — the pilot runs systemd and is left alone.

## Two directions, two scripts

Nothing moves between the tree and a machine except through these:

- `scripts/apply.sh` puts the tree on a machine. Runs as root, takes no arguments in the default
  path, changes nothing on a second run, and never writes to any `~/.config`.
- `scripts/capture.sh` pulls live configuration back into the tree. Runs as the user. It is the
  only thing that writes into the tree from a running system.

A setting changed by hand in System Settings and never captured is work that has to be done twice,
and it is invisible, because the machine looks right. `capture.sh` exists so that capturing is
cheaper than not capturing.

## Shell rules

`scripts/` is pilot-only. It runs on Fedora, calls `dnf` and `rpm`, and will never run on Tundra.

`target/` ships on Tundra and runs under BusyBox. Scripts there may use only applets Alpine's
BusyBox provides, and only the flags BusyBox implements. `sed -i` exists there and `grep -P` does
not; `find` has no `-printf`; `date -d` takes far less than GNU's version. Fedora's `busybox` is
the wrong oracle for this — its build enables about ninety applets Alpine's does not and omits a
dozen Alpine ships — so the check runs inside a stock `alpine` container instead.

`scripts/lint.sh` enforces both halves and the pre-commit hook runs it. A check run by hand is a
check that stops being run.

Every script is `#!/bin/sh`, POSIX, and passes `shellcheck -s sh`, `checkbashisms` and
`busybox ash -n`. Do not repoint `/bin/sh` on the pilot: Fedora's RPM scriptlets assume bash, the
`bash` package owns the symlink, and updates revert it anyway.

## Provenance

KDE config keys move between releases, and a file with no provenance cannot be safely replayed.
Every captured key is recorded in `docs/provenance.md` against the Plasma version it came from,
whether it was captured or hand-seeded, whether it takes effect from `/etc/xdg` or needs
`/etc/skel`, and which host cleared it.

Provenance does not go in a comment header inside the config file. KConfig rewrites these files
whenever Plasma touches them and does not reliably preserve comments, so an inline note disappears
on the first capture round-trip without anyone noticing.

## Two places a default can live, and only one of them stays live

This is the trap in this tree, and it costs a debugging session every time someone falls into it.

Put the key in `/etc/xdg`. Put nothing in the Look-and-Feel package's `contents/defaults` except
the wallpaper and the default containment.

Plasma copies `contents/defaults` into the user's `~/.config/kdedefaults/` the first time they log
in, and that directory sits ahead of `/etc/xdg` in the session's `XDG_CONFIG_DIRS`. A key delivered
through the package is therefore frozen per-account at first login and stops following the image
from then on. Fixing the package and the system default afterwards changes nothing, and the symptom
gives no hint where to look.

If a key delivered that way ever needs re-testing, delete `~/.config/kdedefaults/` and log in
again. Nothing else clears it.

Name things by what is installed, not by the family they belong to. The Breeze desktop theme ships
as `default`; there is no `breeze`, and naming one gets a silent fallback and a line in the journal.
The same care applies to a MIME association, where a desktop ID that is not installed resolves to
nothing and reports nothing.

`baseline/` is stock configuration pulled off the pilot before any change was made. It is never
edited and never applied. It exists so shortcut changes can ship as a delta rather than as a full
copy of a file that would otherwise freeze unrelated Plasma defaults.

## Before committing

Run `scripts/lint.sh` — the hook does it, but only after `scripts/apply.sh` has installed the hook,
which a fresh clone has not.

Run `scripts/translate-check.sh`. Every file outside `baseline/` and `docs/` needs an entry in
`docs/translation.md` naming its Alpine destination. That record is what makes the Phase 2 handoff
mechanical instead of a reading exercise.

Cite what was verified. A version number, a package repository or an upstream behaviour gets an
inline note of where it came from and when it was read. A later reader needs to know what to
re-check, not to trust a bare number.

Do not cite `planning`'s identifiers (`P1-D07` and the like) from this repo. They are positional
and renumber whenever that document is reorganised, so a reference from outside rots silently.
Describe the rule instead; it is what this file does throughout.
