#!/bin/sh
# Put this repo on a Fedora KDE Plasma Desktop 44 machine.
#
# The only supported way to do that. Runs as root, takes no arguments in the default path,
# and changes nothing on a second run. It never writes to any ~/.config: a script that edits
# the live user's configuration hides exactly the failures a fresh-user login exists to find.
#
# Pilot-only. Calls dnf and rpm and will never run on Tundra; exempt from the BusyBox
# vocabulary rule. Everything Fedora-specific in this repo lives here by design, so that the
# artifacts themselves keep their Alpine shape.
#
# Usage:
#   doas ./scripts/apply.sh --dry-run    print what would change
#   doas ./scripts/apply.sh              apply

set -eu

_tundra_dir=$(dirname -- "$0")
# shellcheck source=scripts/common.sh
. "$_tundra_dir/common.sh"

usage() {
	cat <<'USAGE'
usage: apply.sh [--dry-run] [--skip-packages] [--skip-flatpak]

  --dry-run         print what would change and exit without changing anything
  --skip-packages   leave the package delta alone (dnf is slow; useful when iterating)
  --skip-flatpak    leave Flatpak alone (the first install pulls gigabytes)
USAGE
}

SKIP_PACKAGES=0
SKIP_FLATPAK=0

for arg in "$@"; do
	case $arg in
		--dry-run)       DRY_RUN=1 ;;
		--skip-packages) SKIP_PACKAGES=1 ;;
		--skip-flatpak)  SKIP_FLATPAK=1 ;;
		-h|--help)       usage; exit 0 ;;
		*)               usage >&2; die "unknown argument: $arg" ;;
	esac
done

need_root

# The unprivileged user this machine belongs to. Group membership and the login shell are
# about that account, not about root. doas and sudo both name it in the environment; fall
# back to whoever owns the checkout, which on a pilot is the same person.
target_user() {
	if [ -n "${TUNDRA_USER:-}" ]; then printf '%s\n' "$TUNDRA_USER"; return; fi
	if [ -n "${DOAS_USER:-}" ];   then printf '%s\n' "$DOAS_USER";   return; fi
	if [ -n "${SUDO_USER:-}" ];   then printf '%s\n' "$SUDO_USER";   return; fi
	stat -c '%U' "$REPO_ROOT"
}

USER_NAME=$(target_user)
[ "$USER_NAME" != root ] || die "cannot determine the unprivileged user; set TUNDRA_USER"

# Read the first field of a package list, dropping comments, blank lines and metadata.
package_names() {
	sed -e 's/#.*//' -e 's/|.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"
}

# --- 1. package delta -------------------------------------------------------------------

stage_packages() {
	[ "$SKIP_PACKAGES" = 0 ] || { log "skipping packages"; return 0; }
	log "== packages"

	install_missing=
	for pkg in $(package_names "$REPO_ROOT/packages/install.txt"); do
		rpm -q "$pkg" >/dev/null 2>&1 || install_missing="$install_missing $pkg"
	done
	if [ -n "$install_missing" ]; then
		# shellcheck disable=SC2086
		would "dnf install$install_missing" || dnf install -y $install_missing
	fi

	remove_present=
	for pkg in $(package_names "$REPO_ROOT/packages/remove.txt"); do
		if rpm -q "$pkg" >/dev/null 2>&1; then
			remove_present="$remove_present $pkg"
		fi
	done
	if [ -n "$remove_present" ]; then
		# shellcheck disable=SC2086
		would "dnf remove$remove_present" || dnf remove -y $remove_present
	fi
}

# --- 2. /etc/xdg ------------------------------------------------------------------------

stage_xdg() {
	log "== /etc/xdg"
	install_tree "$REPO_ROOT/xdg" /etc/xdg
}

# --- 3. Look-and-Feel package -----------------------------------------------------------

stage_lookandfeel() {
	log "== look-and-feel"
	# Exclusive: this directory is Tundra's alone, so a renamed layout script should not leave
	# its old name behind for plasmashell to find.
	install_tree_exclusive "$REPO_ROOT/look-and-feel/org.tundra.desktop" \
		/usr/share/plasma/look-and-feel/org.tundra.desktop
}

# --- 4. fontconfig ----------------------------------------------------------------------

stage_fontconfig() {
	log "== fontconfig"
	install_file "$REPO_ROOT/fontconfig/60-tundra.conf" /etc/fonts/conf.d/60-tundra.conf
}

# --- 5. zsh ------------------------------------------------------------------------------
#
# The artifact is a drop-in, because that is what Alpine reads. Fedora builds zsh with
# --enable-etcdir=/etc and has no drop-in directory at all, so the pilot creates one and
# appends a sourcing loop to /etc/zshrc.
#
# That append is the single deliberate modification to a package-owned file in this repo.
# /etc/zshrc is %config(noreplace), so an update leaves it alone and drops an .rpmnew beside
# it rather than breaking quietly. The guard is what keeps a second run from appending twice.

ZSHRC_MARKER='# tundra: source /etc/zshrc.d/*.zsh'

stage_zsh() {
	log "== zsh"
	install_file "$REPO_ROOT/shell/tundra.zsh" /etc/zshrc.d/tundra.zsh

	if [ -f /etc/zshrc ] && grep -Fq "$ZSHRC_MARKER" /etc/zshrc; then
		return 0
	fi
	would "append the tundra sourcing hook to /etc/zshrc" && return 0

	# Single quotes throughout: this is shell source being written into another file, so the
	# variable must survive into /etc/zshrc rather than being expanded here.
	# shellcheck disable=SC2016
	{
		printf '\n%s\n' "$ZSHRC_MARKER"
		printf 'if [ -d /etc/zshrc.d ]; then\n'
		printf '  for _tundra_f in /etc/zshrc.d/*.zsh; do\n'
		printf '    [ -r "$_tundra_f" ] && . "$_tundra_f"\n'
		printf '  done\n'
		printf '  unset _tundra_f\n'
		printf 'fi\n'
	} >>/etc/zshrc
	log "appended the tundra sourcing hook to /etc/zshrc"
}

# --- 6. /etc/skel ------------------------------------------------------------------------

stage_skel() {
	log "== /etc/skel"
	install_file "$REPO_ROOT/skel/.zshrc" /etc/skel/.zshrc
}

# --- 7. doas -----------------------------------------------------------------------------

stage_doas() {
	log "== doas"
	install_file "$REPO_ROOT/doas/doas.conf" /etc/doas.conf 0400
}

# --- 8. Flatpak --------------------------------------------------------------------------

stage_flatpak() {
	[ "$SKIP_FLATPAK" = 0 ] || { log "skipping flatpak"; return 0; }
	log "== flatpak"
	have flatpak || die "flatpak is not installed; run the package stage first"

	if ! flatpak remotes --system --columns=name 2>/dev/null | grep -qx flathub; then
		would "add the flathub remote" || flatpak remote-add --system --if-not-exists \
			flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	fi

	installed=$(flatpak list --system --app --columns=application 2>/dev/null || true)
	sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$REPO_ROOT/flatpak/apps.txt" |
	while read -r app; do
		printf '%s\n' "$installed" | grep -qx "$app" && continue
		would "flatpak install $app" || \
			flatpak install --system --noninteractive flathub "$app"
	done
}

# --- 9. services and groups --------------------------------------------------------------
#
# The user goes in libvirt and not in kvm. udev handles /dev/kvm permissions on modern Fedora
# and the kvm membership is noise. libvirt-daemon-common ships the polkit rule that makes
# libvirt membership grant password-less access, so there is no polkit artifact to install.
# Whether Alpine ships the same rule is a Phase 2 question, recorded in the translation record.

stage_services() {
	log "== services and groups"

	for svc in libvirtd cups bluetooth; do
		systemctl is-enabled "$svc" >/dev/null 2>&1 && continue
		would "enable $svc" || systemctl enable --now "$svc"
	done

	for grp in libvirt wheel; do
		id -nG "$USER_NAME" | tr ' ' '\n' | grep -qx "$grp" && continue
		would "add $USER_NAME to $grp" || usermod -aG "$grp" "$USER_NAME"
	done

	# The login shell. Do not trust $SHELL for this; it reflects the login environment and
	# lies in an already-open terminal.
	if [ "$(getent passwd "$USER_NAME" | cut -d: -f7)" != /usr/bin/zsh ]; then
		would "chsh $USER_NAME to zsh" || chsh -s /usr/bin/zsh "$USER_NAME"
	fi
}

# --- 10. the Flatpak update mechanism ----------------------------------------------------
#
# The artifact takes the Alpine shape: a script plus a daily periodic entry, which BusyBox
# crond runs. Fedora has no /etc/periodic and no cron daemon installed by default, so the
# pilot adaptation is a systemd timer generated here. The timer is not an artifact and does
# not exist in the tree, which is what keeps systemd out of anything Phase 2 consumes.

stage_update_timer() {
	log "== flatpak update mechanism"
	install_file "$REPO_ROOT/target/tundra-update" /usr/local/bin/tundra-update 0755
	install_file "$REPO_ROOT/target/tundra-update-notify" \
		/usr/local/bin/tundra-update-notify 0755
	# The autostart entry names /usr/bin, because that is where these land on Tundra. Fedora
	# reserves /usr/bin for RPM-owned files, so the pilot puts them in /usr/local/bin and
	# rewrites the Exec line to match. The artifact keeps its Alpine shape either way.
	autostart=/etc/xdg/autostart/tundra-update-notify.desktop
	if ! would "install the autostart entry, Exec rewritten to /usr/local/bin"; then
		sed -e 's|^Exec=/usr/bin/|Exec=/usr/local/bin/|' \
			"$REPO_ROOT/target/tundra-update-notify.desktop" >"$autostart.new"
		if [ -f "$autostart" ] && cmp -s "$autostart.new" "$autostart"; then
			rm -f "$autostart.new"
		else
			mv "$autostart.new" "$autostart"
			chmod 0644 "$autostart"
			log "installed $autostart"
		fi
	fi

	would "write and enable the pilot systemd timer for tundra-update" && return 0

	# Generated into a temp file and then compared, so a second run is silent. Writing the units
	# unconditionally and re-running `systemctl enable` works, but it reports a change on every
	# run, and a stage that always claims to have done something makes the idempotency gate
	# unreadable — which is the whole point of that gate.
	tmp=$(mktemp -d)

	printf '%s\n' \
		'[Unit]' \
		'Description=Update Flatpak applications' \
		'After=network-online.target' \
		'Wants=network-online.target' \
		'' \
		'[Service]' \
		'Type=oneshot' \
		'ExecStart=/usr/local/bin/tundra-update' \
		>"$tmp/tundra-update.service"

	printf '%s\n' \
		'[Unit]' \
		'Description=Daily Flatpak application update' \
		'' \
		'[Timer]' \
		'OnCalendar=daily' \
		'Persistent=true' \
		'RandomizedDelaySec=1h' \
		'' \
		'[Install]' \
		'WantedBy=timers.target' \
		>"$tmp/tundra-update.timer"

	units_changed=0
	for unit in tundra-update.service tundra-update.timer; do
		if [ -f "/etc/systemd/system/$unit" ] &&
			cmp -s "$tmp/$unit" "/etc/systemd/system/$unit"; then
			continue
		fi
		cp -- "$tmp/$unit" "/etc/systemd/system/$unit"
		chmod 0644 "/etc/systemd/system/$unit"
		log "installed /etc/systemd/system/$unit"
		units_changed=1
	done
	rm -rf "$tmp"

	if [ "$units_changed" = 1 ]; then
		systemctl daemon-reload
	fi

	if ! systemctl is-enabled tundra-update.timer >/dev/null 2>&1; then
		systemctl enable --now tundra-update.timer
		log "enabled tundra-update.timer"
	fi
}

# --- 11. the pre-commit hook -------------------------------------------------------------
#
# Installed here so a fresh clone gets it without a separate instruction. A check run by hand
# is a check that stops being run.

stage_hook() {
	log "== pre-commit hook"
	[ -d "$REPO_ROOT/.git" ] || { warn "not a git checkout; skipping the hook"; return 0; }
	install_file "$REPO_ROOT/scripts/hooks/pre-commit" "$REPO_ROOT/.git/hooks/pre-commit" 0755
	would "chown the hook to $USER_NAME" && return 0
	chown "$USER_NAME" "$REPO_ROOT/.git/hooks/pre-commit"
}

# ----------------------------------------------------------------------------------------

[ "$DRY_RUN" = 1 ] && log "dry run: nothing will be changed"

stage_packages
stage_xdg
stage_lookandfeel
stage_fontconfig
stage_zsh
stage_skel
stage_doas
stage_flatpak
stage_services
stage_update_timer
stage_hook

log ""
log "done. Log out and back in for group membership and the shell change to take effect."
