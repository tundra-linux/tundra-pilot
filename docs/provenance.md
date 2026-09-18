# Provenance

Which Plasma version each key was read against, whether it was captured or hand-written, and
whether it takes effect from `/etc/xdg` or has to fall back to `/etc/skel`.

KDE config keys move between releases. A file with no provenance cannot be safely replayed on
a different version, and the gap this record closes is not academic: the pilot runs ahead of
Alpine on both Plasma and KDE Gear, so a key that works here may simply not exist on the target
yet.

It also runs ahead of where it started. This machine was installed at Plasma 6.6.4 and upgraded to
6.7.5 partway through, which is why every version below is written down rather than inferred. An
installed system can sit behind its own repository indefinitely and the running desktop gives no
sign of it.

Provenance does not live in comment headers inside the config files themselves. KConfig
rewrites those files whenever Plasma touches them and does not reliably preserve comments, so
an inline note disappears on the first capture round-trip without anyone noticing.

## Reference platform

| | Version |
|---|---|
| Distribution | Fedora KDE Plasma Desktop 44, fully updated |
| Plasma | 6.7.5-1.fc44 |
| KDE Frameworks | 6.30.0-1.fc44 |
| KDE Gear | 26.08.1-1.fc44 |
| Kernel | 7.2.5-200.fc44 |
| `/bin/sh` | `/usr/bin/bash` |
| Host | VMware Workstation guest, EFI, 4 vCPU, 8 GB, 3D acceleration and audio present |

Read with `rpm -q` on 2026-09-18, after `dnf upgrade` and a reboot. Enabled repositories are
`fedora`, `updates` and `fedora-cisco-openh264`; `updates-testing` is not enabled.

The machine was installed at Plasma 6.6.4 with Gear 25.12.3 and sat there until it was upgraded,
which is worth knowing because nothing about the running desktop makes that visible. Read the
version before a capture rather than inferring it from the release, and re-read it after any
upgrade.

Query the package manager, never the running shell. `plasmashell --version` aborts without a
display, which is exactly the condition when working over ssh.

## Status of each key

`seed` means the value was written by hand from a design decision and has not yet been
confirmed against a running Plasma. `captured` means it came off the machine. `takes` records
whether Plasma honours the key when it is supplied from `/etc/xdg` as a system default — some
KCMs write keys they do not read back that way, and a value that does not take has to fall
back to `/etc/skel`, where it reaches new accounts only.

Nothing is `captured` yet. The `takes` column has been measured: a user account was created after
seeding `/etc/xdg`, and every key was read back with `kreadconfig6` running as that user, which is
the same KConfig cascade Plasma itself reads. Every seeded key came back with the intended value.

The existing pilot account demonstrates the other half of the model at the same time. It resolves
`LookAndFeelPackage` to `org.fedoraproject.fedoradark.desktop` — its own `~/.config` value, set
before any of this existed, beating the `/etc/xdg` default. Yet it resolves `ColorScheme` to
`BreezeLight`, which came from `/etc/xdg`, because that key was never set locally. A change the
user made wins, and an untouched key still follows the image, on one account at one moment rather
than argued from the specification.

That settles the mechanism and not the whole question. It proves the value reaches the user, which
is what the delivery model depends on. It does not prove each Plasma component acts on the value at
session start, and the components that read a default once at first run are the ones to re-check
when the desktop is driven by hand.

| File | Key | Status | Takes from `/etc/xdg` | Plasma |
|---|---|---|---|---|
| `kdeglobals` | `[KDE] LookAndFeelPackage` | seed | yes | 6.7.5 |
| `kdeglobals` | `[KDE] widgetStyle` | seed | yes | 6.7.5 |
| `kdeglobals` | `[General] ColorScheme` | seed | yes | 6.7.5 |
| `dolphinrc` | `[General] EditableUrlNavigator` | seed | yes | 6.7.5 |
| `dolphinrc` | `[General] ShowFullPath` | seed | yes | 6.7.5 |
| `plasmarc` | `[Theme] name` | seed | yes | 6.7.5 |
| `kdeglobals` | `[Icons] Theme` | seed | yes | 6.7.5 |
| `kcminputrc` | `[Mouse] cursorTheme` | seed | yes | 6.7.5 |
| `kwinrc` | `[Windows] ElectricBorderMaximize` | seed | yes | 6.7.5 |
| `kwinrc` | `[Windows] ElectricBorderTiling` | seed | yes | 6.7.5 |
| `mimeapps.list` | all | seed | yes | 6.7.5 |
| `gtk-3.0/settings.ini` | all | seed | yes | n/a |
| `gtk-4.0/settings.ini` | all | seed | yes | n/a |
| `kglobalshortcutsrc` | the three `[services]` entries below | seed | yes | 6.7.5 |

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

The three unbound ones are what `xdg/kglobalshortcutsrc` supplies, and all three reach a fresh user
from `/etc/xdg`: `kreadconfig6` run as that user returns each `_launch` value intact. This was the
entry in the file most likely to need an `/etc/skel` fallback, and it does not.

`SingleClick` is deliberately absent. It lives in `kdeglobals` under `[KDE]`, not in
`dolphinrc`, and Plasma has defaulted to double-click since 6.0 — so the setting is already
what a Windows migrant wants and an explicit override would only add a key to maintain.

## Which host cleared which gate

The virtualization gate runs on a vSphere guest and everything else on the Workstation pilot,
because nested virtualization is unavailable under Workstation on this development host.
Record the host against each gate here as they are cleared, so that a pass is never a
statement about a machine that is not the pilot.

All results below were re-run after the upgrade, against Plasma 6.7.5. An earlier pass on 6.6.4 was
discarded rather than carried forward: a pass on a version the pilot no longer runs is not a pass.

| Gate | Host | Result |
|---|---|---|
| `/bin/sh` is bash | Workstation pilot | pass — `/usr/bin/bash` |
| `busybox --list` has `ash` | Workstation pilot | pass |
| login shell is zsh | Workstation pilot | pass — `/usr/bin/zsh` from `getent passwd` |
| removals held, libraries kept | Workstation pilot | pass — `PackageKit`, `plasma-discover` and `kf6-baloo-file` absent; `PackageKit-Qt6` and `kf6-baloo-libs` present, so `plasma-desktop` survived |
| zsh hook applied exactly once | Workstation pilot | pass — marker count 1, and `rpm -Va zsh` reports only `/etc/zshrc` and `/etc/skel/.zshrc` |
| `doas.conf` parses | Workstation pilot | pass — `doas -C` clean as root |
| `doas` escalates for a `wheel` member | Workstation pilot | pass — a throwaway `wheel` account authenticated once through a pty and ran as uid 0. A non-`wheel` account got `doas: Operation not permitted`, so both halves of the rule hold |
| `doas` `persist` suppresses the second prompt | — | **not demonstrated.** The build supports it (the timestamp strings are in the binary, and Fedora builds with `--with-timestamp`), but each scripted invocation gets a fresh pty session, and the timestamp is keyed to the session. Needs a real terminal |
| Flatpak portals work | Workstation pilot | pass — `org.freedesktop.portal.FileChooser` version 4 answers from inside a running Flatpak sandbox, not just from the host session |
| theming applies with no fallback | Workstation pilot | pass — after clearing the frozen per-user defaults and restarting the shell, plasmashell logs no theme-resolution errors and every theming key resolves to its intended value |
| rootless containers | Workstation pilot | pass — podman reports cgroups v2 and rootless true, a container ran, and distrobox created and entered a Debian box whose ldd names glibc 2.41. Note the pilot cannot exercise the point of this on Tundra, since both host and container are glibc here |
| Flatpak update mechanism | Workstation pilot | pass — timer scheduled, the updater wrote its state file, and exactly one Notify call reached the bus with the app name, summary and the changed applications. A second run is silent |
| MIME defaults | Workstation pilot | pass — all fifteen associations resolve to the intended desktop id |
| printing | Workstation pilot | pass — `lpstat -r` reports the scheduler running |
| bluetooth | Workstation pilot | pass — the service is enabled and skips cleanly on `ConditionPathIsDirectory=/sys/class/bluetooth`, which is the correct behaviour on a machine with no adapter rather than a failure |
| `capture.sh` default path | Workstation pilot | pass — runs clean, records the Plasma version, writes a delta and appends to this record |
| host applications removed | Workstation pilot | pass — firefox, libreoffice-core and okular gone with about a gigabyte of dependencies, Plasma and Dolphin still installed, plasmashell still running, and the PDF, HTML and ODT associations now resolve to the Flatpaks with no host application competing |
| Flatpak audio works | Workstation pilot | pass — `pactl` inside the sandbox reports the PipeWire server and default sink, and `paplay` of a real sample exited 0 with the sink moving `SUSPENDED` to `IDLE` |
| services enabled | Workstation pilot | pass — `libvirtd`, `cups`, `bluetooth`, `tundra-update.timer` all enabled |
| group membership | Workstation pilot | pass — `bmeyer` in `wheel` and `libvirt` |
| Flatpak set installed | Workstation pilot | pass — all six references present in `flatpak list --system --app` |
| `virsh -c qemu:///system list --all` unprivileged | Workstation pilot | pass — returns a list with no permission error and no password prompt. Note `/dev/kvm` is absent here, which is what makes this gate insufficient on its own |
| removals survive `dnf upgrade` | Workstation pilot | pass — a full upgrade pulled none of the three back in |
| apply from a git checkout, twice | Workstation pilot | pass — first run installs the pre-commit hook, second run reports no changes at all |
| `/etc/xdg` cascade reaches a fresh user | Workstation pilot | pass — every seeded key, including the three shortcut entries, read back intact with `kreadconfig6` as a newly created account |
| Look-and-Feel package is valid | Workstation pilot | pass — `kpackagetool6 --type Plasma/LookAndFeel --show org.tundra.desktop` resolves name, plugin id and path. Note `plasma-apply-lookandfeel --list` prints nothing over ssh, including for the stock packages, so it is not a usable check without a session |
| MIME targets exist | Workstation pilot | **failed, then fixed** — `org.kde.kate.desktop` is not installed on the KDE spin, which ships KWrite. The association pointed at nothing and reported nothing |

Reaching Flathub needed the corporate TLS-interception root CA in the guest's trust store. Without
it `flatpak remote-add` fails with `[60] SSL peer certificate or SSH remote key was not OK`. The
intercepting CA is the one the network actually presents, which is worth reading off the wire with
`openssl s_client` rather than guessing from what is in the host's certificate store.

## Capture log

Appended by `scripts/capture.sh`. Each line is one run.

## The Look-and-Feel package freezes what it sets

At first login, Plasma copies the Look-and-Feel package's `contents/defaults` into the user's
`~/.config/kdedefaults/`, one file per config file it mentions, plus a `package` file naming the
source. That directory sits between `~/.config` and `/etc/xdg` in the cascade, so from then on the
copied values shadow the system defaults.

The consequence is sharp enough to state plainly: **any key the Look-and-Feel package sets stops
following `/etc/xdg` the moment a user first logs in.** It is frozen per-user at whatever value the
package held that day. Updating the image later does not reach that account.

This was found the expensive way. `contents/defaults` and `xdg/plasmarc` both carried the Plasma
desktop theme, the name was wrong, and fixing both files plus restarting the shell changed nothing
for an account that had already logged in — because `~/.config/kdedefaults/plasmarc` still held the
old value and won.

So the two mechanisms are not interchangeable and must not overlap:

| Deliver through | For | Because |
|---|---|---|
| `contents/defaults` | wallpaper, splash, the default containment | Consumed once when the account and its desktop are created. Nothing later can change them anyway |
| `/etc/xdg` | every theming and behaviour key | Stays live. A later image update still reaches accounts that never touched the key |

A key in both places gets the worse of the two, which is why `contents/defaults` now carries only
the wallpaper and the containment.

To re-test a key that was delivered this way, delete `~/.config/kdedefaults/` and log in again.
Nothing else clears it.

## The baseline is bound to a Plasma version

`baseline/` was captured on Plasma 6.6.4, before the machine was upgraded. The pilot now runs
6.7.5, and a shortcut delta taken against that baseline reports sixteen lines of bindings nobody
here touched — `Walk Through Windows` gaining a `Meta+Tab` alternate, the desktop-switch keys
gaining `Meta+F1` through `Meta+F4`, `Lock Session` gaining `Screensaver`. Those are upstream
changes between the two releases, faithfully reported.

So a baseline is only meaningful against the Plasma version it was taken on. Used across an
upgrade it silently converts someone else's release notes into Tundra's customisations, and the
result looks exactly like a legitimate delta.

`baseline/` is still correct as a record of stock Fedora KDE 44 at 6.6.4, which is what it says it
is. What it can no longer do is produce a trustworthy delta on this machine.

Re-capturing it is not a matter of re-running the script, because `/etc/xdg` is now seeded and a
new account would inherit Tundra's defaults rather than stock ones. The sequence is: revert to the
pre-apply snapshot, `dnf upgrade`, create an account, capture the baseline, then apply. Until that
is done, treat any captured shortcut delta as contaminated and keep shipping the three hand-written
entries.
