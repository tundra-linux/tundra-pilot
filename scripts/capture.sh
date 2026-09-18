#!/bin/sh
# Pull live configuration off the pilot and back into this tree.
#
# The other direction from apply.sh, and the only thing that writes into the tree from a
# running system. It runs as the user, not as root: the files it reads live in ~/.config, and
# running it under doas would read root's configuration and silently capture nothing useful.
#
# Two modes:
#
#   --baseline   write baseline/, the stock configuration from before any change was made.
#                Write-once, and it refuses to overwrite. This is what makes the shortcut
#                delta possible, and it cannot be recovered once the machine is configured.
#
#   (default)    capture the configured set into the tree, diff the shortcuts against
#                baseline/, and record the Plasma version in docs/provenance.md.
#
# Pilot-only. Exempt from the BusyBox vocabulary rule.

set -eu

_tundra_dir=$(dirname -- "$0")
# shellcheck source=scripts/common.sh
. "$_tundra_dir/common.sh"

usage() {
	cat <<'USAGE'
usage: capture.sh [--baseline]

  --baseline   capture stock configuration into baseline/. Refuses if it already exists.
USAGE
}

MODE=configured

for arg in "$@"; do
	case $arg in
		--baseline) MODE=baseline ;;
		-h|--help)  usage; exit 0 ;;
		*)          usage >&2; die "unknown argument: $arg" ;;
	esac
done

need_not_root

CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}

# The capture set. The panel layout appears here only in baseline/: it is captured to be read
# and compared, never to be shipped. What ships is the Look-and-Feel package's layout script,
# because a copied appletsrc freezes one account's panel state and reproduces on no other.
CAPTURE_FILES='kdeglobals dolphinrc kwinrc plasmarc kglobalshortcutsrc'
BASELINE_EXTRA='plasma-org.kde.plasma.desktop-appletsrc kcminputrc'

# Ask the package manager first. `plasmashell --version` needs a display and aborts with a
# core dump over ssh, which is exactly how this script gets run when capturing from a host
# that is not the one sitting in front of you.
plasma_version() {
	if have rpm && rpm -q plasma-desktop >/dev/null 2>&1; then
		rpm -q --qf '%{VERSION}-%{RELEASE}\n' plasma-desktop
		return
	fi
	if have plasmashell && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
		plasmashell --version 2>/dev/null | awk '{print $NF}'
		return
	fi
	printf 'unknown\n'
}

capture_baseline() {
	dest=$REPO_ROOT/baseline
	if [ -n "$(find "$dest" -type f -not -name 'README.md' 2>/dev/null | head -n 1)" ]; then
		die "baseline/ already has content. It is captured once, from a machine that has not
been changed, and overwriting it destroys the only record of what stock Plasma looked like.
Delete it deliberately if that is really what you want."
	fi
	mkdir -p "$dest"

	for f in $CAPTURE_FILES $BASELINE_EXTRA; do
		if [ -f "$CONFIG_DIR/$f" ]; then
			cp -- "$CONFIG_DIR/$f" "$dest/$f"
			log "captured $f"
		else
			warn "no $f in $CONFIG_DIR; skipped"
		fi
	done

	# The provenance anchor. Everything in baseline/ is a statement about this exact system,
	# and without these two files that statement cannot be checked later.
	plasma_version >"$dest/PLASMA_VERSION"
	if have rpm; then
		rpm -qa --qf '%{NAME} %{VERSION}-%{RELEASE}\n' | sort >"$dest/rpm-qa.txt"
	fi
	printf '%s\n' "$(date -u '+%Y-%m-%d')" >"$dest/CAPTURED_ON"

	log ""
	log "baseline captured at Plasma $(cat "$dest/PLASMA_VERSION")"
}

capture_configured() {
	version=$(plasma_version)
	log "capturing against Plasma $version"

	for f in $CAPTURE_FILES; do
		[ -f "$CONFIG_DIR/$f" ] || { warn "no $f in $CONFIG_DIR; skipped"; continue; }

		# Shortcuts ship as a delta, never as a whole file. A full copy freezes every
		# unrelated Plasma default at today's values and fights every future release.
		if [ "$f" = kglobalshortcutsrc ]; then
			base=$REPO_ROOT/baseline/kglobalshortcutsrc
			[ -f "$base" ] || { warn "no baseline shortcuts; cannot build a delta"; continue; }
			shortcut_delta "$base" "$CONFIG_DIR/$f" >"$REPO_ROOT/xdg/kglobalshortcutsrc"
			log "captured $f as a delta"
			continue
		fi

		cp -- "$CONFIG_DIR/$f" "$REPO_ROOT/xdg/$f"
		log "captured $f"
	done

	record_provenance "$version"
}

# Emit the entries present in the live file that the baseline does not already have, keeping
# the section header each one belongs to. Section-aware because a bare line diff produces a
# file that KConfig reads as belonging to whatever section came before it in the diff.
shortcut_delta() {
	awk -v basefile="$1" '
		BEGIN {
			while ((getline line < basefile) > 0) {
				if (line ~ /^\[/) { bsec = line; continue }
				if (line ~ /^[[:space:]]*$/) continue
				eq = index(line, "=")
				if (eq == 0) continue
				key = substr(line, 1, eq - 1)
				val = substr(line, eq + 1)
				split(val, f, ",")
				active[bsec "\036" key] = f[1]
			}
		}
		/^\[/ { sec = $0; next }
		/^[[:space:]]*$/ { next }
		{
			eq = index($0, "=")
			if (eq == 0) next
			key = substr($0, 1, eq - 1)
			val = substr($0, eq + 1)
			split(val, f, ",")
			# Compare only the active binding. The second and third fields are the shipped
			# default and the friendly name, and Plasma rewrites both on its own schedule;
			# including them turns every incidental churn into a fake delta.
			if (f[1] == active[sec "\036" key]) next
			# A key bound to nothing is not a customisation worth shipping.
			if (f[1] == "none" || f[1] == "") next
			if (sec != emitted) { if (emitted != "") print ""; print sec; emitted = sec }
			print
		}
	' "$2"
}

# Append to the provenance record rather than rewriting it. The per-key detail is written by
# hand as keys are understood; what this adds is the dated line saying which version and which
# host a capture came from, which is the part nobody remembers to write down.
record_provenance() {
	rec=$REPO_ROOT/docs/provenance.md
	[ -f "$rec" ] || die "missing $rec"
	# The backticks are markdown, not command substitution.
	# shellcheck disable=SC2016
	printf '\n- %s — captured on `%s` at Plasma %s by `scripts/capture.sh`\n' \
		"$(date -u '+%Y-%m-%d')" "$(hostname)" "$1" >>"$rec"
	log "appended to docs/provenance.md"
}

case $MODE in
	baseline)   capture_baseline ;;
	configured) capture_configured ;;
esac
