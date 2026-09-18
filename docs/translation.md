# Translation record

Every file in this tree, where it goes on Tundra, and what has to change on the way.

This is the Phase 2 handoff. Without it, moving this tree onto Alpine is a reading exercise
over the whole repo, and a file whose purpose nobody remembers gets either dropped or carried
for years. `scripts/translate-check.sh` enforces that the record and the tree agree, in both
directions, and the pre-commit hook runs it.

Alpine package availability was read from `pkgs.alpinelinux.org` against v3.24 on 2026-09-18.

## Desktop configuration

| File | Alpine destination | Adaptation |
|---|---|---|
| `xdg/kdeglobals` | `/etc/xdg/kdeglobals` | none. `XDG_CONFIG_DIRS` works the same on both |
| `xdg/dolphinrc` | `/etc/xdg/dolphinrc` | none |
| `xdg/kglobalshortcutsrc` | `/etc/xdg/kglobalshortcutsrc` | none to the file, but it is a delta against Fedora 44's stock bindings and Alpine's Plasma is a different release. Re-measure the stock set on the target before assuming the delta is still three entries |
| `xdg/kwinrc` | `/etc/xdg/kwinrc` | none |
| `xdg/plasmarc` | `/etc/xdg/plasmarc` | none |
| `xdg/mimeapps.list` | `/etc/xdg/mimeapps.list` | none, but the desktop IDs must match the Flatpaks actually installed, and the set is a Phase 2 decision as much as this one |
| `xdg/gtk-3.0/settings.ini` | `/etc/xdg/gtk-3.0/settings.ini` | none. Requires `breeze-gtk`, which is in Alpine `community` |
| `xdg/gtk-4.0/settings.ini` | `/etc/xdg/gtk-4.0/settings.ini` | none |

Plasma on Alpine v3.24 is a different minor release from the pilot's, so every key here is
re-checked against the target's version before Phase 2 consumes it rather than copied on
trust. The per-key status is in [`provenance.md`](provenance.md).

## Look and Feel package

| File | Alpine destination | Adaptation |
|---|---|---|
| `look-and-feel/org.tundra.desktop/metadata.json` | `/usr/share/plasma/look-and-feel/org.tundra.desktop/metadata.json` | none |
| `look-and-feel/org.tundra.desktop/contents/defaults` | same directory | none |
| `look-and-feel/org.tundra.desktop/contents/layouts/org.kde.plasma.desktop-layout.js` | same directory | none, provided the applet IDs still exist at the target's Plasma version. They are the stock ones, so this is a check rather than an expected problem |

The whole package is a candidate for the `tundra-base` overlay package rather than a file
copy, since it is exactly the kind of thing an image build wants to own.

## Presentation

| File | Alpine destination | Adaptation |
|---|---|---|
| `fontconfig/60-tundra.conf` | `/etc/fonts/conf.d/60-tundra.conf` | none. The file names font families and never packages, so what changes is which Alpine package provides Noto, not this file |

## Shell

| File | Alpine destination | Adaptation |
|---|---|---|
| `shell/tundra.zsh` | `/etc/zsh/zshrc.d/tundra.zsh` | none, and this is the point. Alpine's `zsh` sources `/etc/zsh/zshrc.d/*.zsh` from its own `/etc/zsh/zshrc`, so on Tundra this is a plain file copy. The pilot is the side that adapts: Fedora has no drop-in directory, so `apply.sh` creates `/etc/zshrc.d/` and appends a sourcing loop to the RPM-owned `/etc/zshrc`. That append does not exist on Tundra |
| `skel/.zshrc` | `/etc/skel/.zshrc` | none. It is a stub and carries no settings, which is what keeps it honest: `/etc/skel` reaches only accounts created after it was seeded |

## Privilege escalation

| File | Alpine destination | Adaptation |
|---|---|---|
| `doas/doas.conf` | `/etc/doas.conf` | none. `doas` is in Alpine `main`; the pilot gets the same file through Fedora's `opendoas`. Requires a `wheel` group to exist on the target, which Alpine provides |

## Applications and updates

| File | Alpine destination | Adaptation |
|---|---|---|
| `flatpak/apps.txt` | not installed. Consumed by the image build | The list is input to whatever installs applications into the image, not a file that ships |
| `target/tundra-update` | `/usr/bin/tundra-update`, plus a link from `/etc/periodic/daily/tundra-update` | none to the script. The schedule is the adaptation: BusyBox `crond` runs `/etc/periodic/daily` on Tundra, and the Fedora pilot has no cron daemon installed, so `apply.sh` generates a systemd timer instead. Nothing systemd-shaped is in the artifact |
| `target/tundra-update-notify` | `/usr/bin/tundra-update-notify` | none |
| `target/tundra-update-notify.desktop` | `/etc/xdg/autostart/tundra-update-notify.desktop` | none on Tundra, where the `Exec` path is already correct. The pilot rewrites `Exec` to `/usr/local/bin`, because Fedora reserves `/usr/bin` for RPM-owned files |

## Package lists

| File | Alpine destination | Adaptation |
|---|---|---|
| `packages/install.txt` | not installed. Consumed by Phase 2's package selection | Translated, never copied. Every row carries an Alpine counterpart and the repository it lives in, which is what makes the translation mechanical. Note that most of the desktop stack is in `community`, which is supported only on the newest stable branch |
| `packages/remove.txt` | not installed | On Tundra these are never installed in the first place, so the list becomes a set of things to leave out of the image rather than a removal step |

## Pilot-only

None of these reach Tundra. They run on Fedora, call `dnf` and `rpm`, and are exempt from the
BusyBox vocabulary rule for that reason.

| File | Alpine destination | Why not |
|---|---|---|
| `scripts/apply.sh` | none | The installer for a machine that has a package manager. Tundra's equivalent is the image build |
| `scripts/capture.sh` | none | Pulls configuration off a live system into this tree. There is nothing to capture on an image-based host, and its root filesystem is read-only |
| `scripts/common.sh` | none | Helpers for the above |
| `scripts/lint.sh` | none | Development tooling |
| `scripts/translate-check.sh` | none | Development tooling, and specifically the thing that checks this document |
| `scripts/hooks/pre-commit` | none | Development tooling |

## Open questions carried to Phase 2

- Fedora's `libvirt-daemon-common` ships a polkit rule that makes `libvirt` group membership
  grant password-less access, so the pilot needs no polkit artifact of its own. Whether
  Alpine's `libvirt` packaging ships the same rule is unverified, and if it does not, Tundra
  needs one written.
- Rootless Podman depends on cgroup v2 delegation and on `/etc/subuid` and `/etc/subgid`
  being provisioned at user creation. systemd does the first on the pilot; OpenRC needs
  `rc_cgroup_mode=unified` set explicitly. BusyBox `adduser` does not provision subuid and
  subgid ranges at all, which is a real gap rather than a configuration difference.
- `mimeapps.list` names `org.kde.gwenview.desktop` and `org.kde.kwrite.desktop`, which are host
  applications on the pilot. On an image-based host with Flatpak as the only application
  channel, either those become Flatpaks or the associations change. The editor is KWrite and not
  Kate, because Fedora's KDE spin ships KWrite and no Kate. Check every desktop ID exists on the
  target before shipping the association: a MIME entry naming an absent application resolves to
  nothing and reports nothing, which is the worst way for a default to be wrong.
