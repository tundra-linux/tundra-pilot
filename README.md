# tundra-pilot

Configuration artifacts for **Tundra**, an image-based Alpine-derived KDE Plasma desktop aimed at
technically literate people leaving Windows.

This tree is validated on Fedora KDE Plasma Desktop 44 and consumed by Tundra as its default
profile. Fedora is scaffolding: it supplies a working Plasma stack for free so the only variable is
the desktop design. Nothing here is Fedora-shaped, and the one place that adapts to Fedora is
`scripts/apply.sh`.

The plan this implements is in the sibling `planning` repo, `docs/PHASE1.md`. Rules for working in
this tree are in [`AGENTS.md`](AGENTS.md).

## Install

```sh
git clone https://github.com/tundra-linux/tundra-pilot.git
cd tundra-pilot
doas ./scripts/apply.sh --dry-run    # prints what it would change
doas ./scripts/apply.sh
```

The apply script is the only supported way to put this repo on a machine. It is idempotent: a
second run reports no changes. It never writes to any `~/.config`, because a script that edits the
live user's configuration hides exactly the failures a fresh-user login is meant to find.

### On a network that intercepts TLS

The Flatpak stage fails on a corporate network unless the interception CA is in the machine's trust
store:

```
error: Can't load uri https://dl.flathub.org/repo/flathub.flatpakrepo:
[60] SSL peer certificate or SSH remote key was not OK
```

The apply script does not install that certificate and should not: which CA a machine trusts is a
property of the network it sits on, not of this configuration, and a repo that shipped one would be
shipping a decision about whose traffic inspection to accept.

Read the certificate off the wire rather than guessing which product is doing the intercepting. A
managed workstation often carries several plausible-looking roots, and picking the wrong one costs
an afternoon:

```sh
openssl s_client -connect dl.flathub.org:443 -servername dl.flathub.org </dev/null 2>/dev/null |
	grep issuer
```

Then install that root and re-run:

```sh
doas cp theroot.crt /etc/pki/ca-trust/source/anchors/
doas update-ca-trust
openssl s_client -connect dl.flathub.org:443 -servername dl.flathub.org </dev/null 2>&1 |
	grep -E '^(Verification|verify)'
```

The same certificate is what lets `podman pull` reach a registry, so the container work needs it
too. None of this applies on Tundra, where there is no `dnf`, no interception in the picture, and
the image build supplies its own trust store.

## Layout

The tree mirrors its install destinations, so applying it is a copy rather than a translation.

```
baseline/             stock config pulled off the pilot before any change. Never edited
xdg/                → /etc/xdg                system-wide KDE defaults
look-and-feel/
  org.tundra.desktop/ → /usr/share/plasma/look-and-feel/
fontconfig/         → /etc/fonts/conf.d/
shell/tundra.zsh    → /etc/zsh/zshrc.d/ on Tundra; /etc/zshrc.d/ on the pilot
skel/.zshrc         → /etc/skel/            customization stub only
doas/doas.conf      → /etc/
flatpak/apps.txt      one Flatpak reference per line
packages/             the Fedora package delta, with an Alpine counterpart per entry
scripts/              pilot-only. Runs on Fedora, calls dnf and rpm
target/               ships on Tundra. BusyBox vocabulary only
docs/                 provenance, the design as rules, the translation record, the task checklist
```

## Where defaults come from

Anything Tundra keeps controlling ships in the image. `/etc/skel` carries stubs only, because it
applies at user creation and reaches nobody who already has an account — which is a real problem
for a system that ships updates.

So the panel and desktop layout ship as a Look-and-Feel package, and the rest of the KDE
configuration goes to `/etc/xdg`, where KDE reads it through `XDG_CONFIG_DIRS` as defaults that
`~/.config` overrides. A user's change wins, and a later image update still reaches everyone who
has not touched that key. Nothing is locked with Kiosk immutability markers: the audience is
technically literate and locking settings generates support load.

## Status

This tree has been applied to the pilot and most of it is verified. The package delta, the
`/etc/xdg` defaults, the Look-and-Feel package, the shell, `doas`, the Flatpak set and the update
mechanism are all in place; a freshly created account gets the intended panel from the layout
script, and `apply.sh` reports no changes on a second run. What passed, and on which host, is in
[`docs/provenance.md`](docs/provenance.md).

What is not done: the task checklist in [`docs/checklist.md`](docs/checklist.md) has never been
run, so nobody has judged the design by using it. The Look-and-Feel package names a wallpaper that
does not exist yet. And the baseline was captured on an older Plasma than the machine now runs, so
a captured shortcut delta is not currently trustworthy.

No decision here has survived contact with hardware — the pilot is a VM, so suspend and resume,
backlight, wifi, discrete graphics, real printers and real Bluetooth adapters are all out of reach
and belong to Phase 2's hardware matrix. Virtualization is out of reach on this host too, which
runs locked virtualization-based security, so `/dev/kvm` never appears in the guest.

## Licence

MIT. See [`LICENSE`](LICENSE).

The Look-and-Feel package declares the same licence in its own `metadata.json`, because it is
installed as a standalone Plasma package and gets read on its own once it leaves this tree.
