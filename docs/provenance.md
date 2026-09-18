# Provenance

Which Plasma version each key was read against, whether it was captured or hand-written, and
whether it takes effect from `/etc/xdg` or has to fall back to `/etc/skel`.

KDE config keys move between releases. A file with no provenance cannot be safely replayed on
a different version, and the gap this record closes is not academic: the pilot runs a minor
Plasma release ahead of Alpine on some components and a release behind on others, so a key
that works here may not exist on the target, or may have moved.

Provenance does not live in comment headers inside the config files themselves. KConfig
rewrites those files whenever Plasma touches them and does not reliably preserve comments, so
an inline note disappears on the first capture round-trip without anyone noticing.

## Reference platform

| | Installed on the pilot | Available in `updates` |
|---|---|---|
| Distribution | Fedora KDE Plasma Desktop 44 | |
| `plasma-desktop` | 6.6.4-1.fc44 | **6.7.5-1.fc44** |
| `plasma-workspace` | 6.6.4-1.fc44 | **6.7.5-1.fc44** |
| `kwin-common` | 6.6.4-2.fc44 | |
| `breeze-gtk-common` | 6.7.5-1.fc44 | |
| KDE Frameworks | 6.25.0-1.fc44 | |
| KDE Gear | 25.12.3 | |
| `/bin/sh` | `/usr/bin/bash` | |
| Host | VMware Workstation guest, EFI, 4 vCPU, 8 GB, 3D acceleration and audio present | |

Read on the pilot on 2026-09-18 with `rpm -q` and `dnf list --available`. Enabled repositories are
`fedora`, `updates` and `fedora-cisco-openh264`; `updates-testing` is not enabled.

**The pilot is behind its own repository and the stack is currently mixed.** The machine was
installed and never fully updated, so Plasma sits at 6.6.4 while `updates` offers 6.7.5 — and
`breeze-gtk` came in at 6.7.5 as a dependency of the package delta, so two halves of the same
release are now installed side by side. Nothing should be captured in this state: a key recorded
here is a claim about a system that matches neither the reference platform nor any shipped Fedora.
Run `dnf upgrade` and re-read this table before the first capture.

Query the package manager, never the running shell. `plasmashell --version` aborts without a
display, which is exactly the condition when working over ssh.

## Status of each key

`seed` means the value was written by hand from a design decision and has not yet been
confirmed against a running Plasma. `captured` means it came off the machine. `takes` records
whether Plasma honours the key when it is supplied from `/etc/xdg` as a system default — some
KCMs write keys they do not read back that way, and a value that does not take has to fall
back to `/etc/skel`, where it reaches new accounts only.

Nothing is `captured` yet and nothing has been tested for `takes`. Both columns get filled by
running a fresh-user login against seeded defaults and diffing the result.

| File | Key | Status | Takes from `/etc/xdg` | Plasma |
|---|---|---|---|---|
| `kdeglobals` | `[KDE] LookAndFeelPackage` | seed | untested | 6.7.5 (target) |
| `kdeglobals` | `[KDE] widgetStyle` | seed | untested | 6.7.5 (target) |
| `kdeglobals` | `[General] ColorScheme` | seed | untested | 6.7.5 (target) |
| `dolphinrc` | `[General] EditableUrlNavigator` | seed | untested | 6.7.5 (target) |
| `dolphinrc` | `[General] ShowFullPath` | seed | untested | 6.7.5 (target) |
| `plasmarc` | `[Theme] name` | seed | untested | 6.7.5 (target) |
| `kwinrc` | `[Windows] ElectricBorderMaximize` | seed | untested | 6.7.5 (target) |
| `kwinrc` | `[Windows] ElectricBorderTiling` | seed | untested | 6.7.5 (target) |
| `mimeapps.list` | all | seed | untested | 6.7.5 (target) |
| `gtk-3.0/settings.ini` | all | seed | untested | n/a |
| `gtk-4.0/settings.ini` | all | seed | untested | n/a |
| `kglobalshortcutsrc` | the three `[services]` entries below | seed | untested | 6.7.5 (target) |

## Shortcuts: what is already stock

Read from `baseline/kglobalshortcutsrc`, captured from an unmodified Fedora KDE 44 account on
2026-09-18. This is the measurement the delta approach depends on, and it is why the shipped
file has three entries rather than thirty.

| Intended binding | Already stock? | Where it lives |
|---|---|---|
| `Super+D` show desktop | yes | `[kwin] Show Desktop` |
| `Super`+arrows quick tiling | yes, all four | `[kwin] Window Quick Tile Left/Right/Top/Bottom` |
| `Super` alone opens the launcher | yes | `[plasmashell] activate application launcher`, bound to `Meta` and `Alt+F1` |
| `Super+E` Dolphin | **no** | nothing binds it; no Dolphin entry exists in a stock file |
| `Super+R` KRunner | **no** | nothing binds it |
| `Ctrl+Shift+Esc` task manager | **no** | nothing binds it. `Meta+Ctrl+Esc` is Kill Window, which is a different thing |

Worth noting as a design freebie: `Meta+1` through `Meta+9` already activate task manager
entries by position, which is Windows behaviour nobody had to ask for.

The three unbound ones are what `xdg/kglobalshortcutsrc` supplies. Whether Plasma honours a
`[services][…] _launch=` entry supplied from `/etc/xdg` rather than from `~/.config` is
untested and is the single most likely thing in this file to need a `/etc/skel` fallback.

`SingleClick` is deliberately absent. It lives in `kdeglobals` under `[KDE]`, not in
`dolphinrc`, and Plasma has defaulted to double-click since 6.0 — so the setting is already
what a Windows migrant wants and an explicit override would only add a key to maintain.

## Which host cleared which gate

The virtualization gate runs on a vSphere guest and everything else on the Workstation pilot,
because nested virtualization is unavailable under Workstation on this development host.
Record the host against each gate here as they are cleared, so that a pass is never a
statement about a machine that is not the pilot.

All results below are from the first `apply.sh` run, against Plasma 6.6.4 before the machine was
upgraded. They are re-run after the upgrade, because a pass on a version the pilot no longer runs
is not a pass.

| Gate | Host | Result |
|---|---|---|
| `/bin/sh` is bash | Workstation pilot | pass — `/usr/bin/bash` |
| `busybox --list` has `ash` | Workstation pilot | pass |
| login shell is zsh | Workstation pilot | pass — `/usr/bin/zsh` from `getent passwd` |
| removals held, libraries kept | Workstation pilot | pass — `PackageKit`, `plasma-discover` and `kf6-baloo-file` absent; `PackageKit-Qt6` and `kf6-baloo-libs` present, so `plasma-desktop` survived |
| zsh hook applied exactly once | Workstation pilot | pass — marker count 1, and `rpm -Va zsh` reports only `/etc/zshrc` and `/etc/skel/.zshrc` |
| `doas.conf` parses | Workstation pilot | pass — `doas -C` clean as root |
| `doas` escalates for a `wheel` member | — | **not yet run.** Needs an interactive session: `doas` prompts for a password and a non-interactive ssh command has no tty, so it reports `Authentication failed` regardless of whether the rule is right |
| services enabled | Workstation pilot | pass — `libvirtd`, `cups`, `bluetooth`, `tundra-update.timer` all enabled |
| group membership | Workstation pilot | pass — `bmeyer` in `wheel` and `libvirt` |
| Flatpak set installed | Workstation pilot | pass — all six references present in `flatpak list --system --app` |

Reaching Flathub needed the corporate TLS-interception root CA in the guest's trust store. Without
it `flatpak remote-add` fails with `[60] SSL peer certificate or SSH remote key was not OK`. The
intercepting CA is the one the network actually presents, which is worth reading off the wire with
`openssl s_client` rather than guessing from what is in the host's certificate store.

## Capture log

Appended by `scripts/capture.sh`. Each line is one run.
