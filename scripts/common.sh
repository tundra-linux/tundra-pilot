#!/bin/sh
# Shared helpers for the pilot scripts. Sourced, never executed.
#
# Pilot-only: this runs on Fedora and is exempt from the BusyBox vocabulary rule. See AGENTS.md.

# Repo root, derived from this file's location so a script works from any cwd.
REPO_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
export REPO_ROOT

DRY_RUN=${DRY_RUN:-0}

log()  { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die()  { printf 'error: %s\n' "$*" >&2; exit 1; }

# Print what would change instead of changing it. Every mutating helper below routes through
# this, which is what makes --dry-run trustworthy rather than a separate code path that drifts.
would() {
	if [ "$DRY_RUN" = 1 ]; then
		printf 'would: %s\n' "$*"
		return 0
	fi
	return 1
}

need_root() {
	[ "$(id -u)" = 0 ] || die "must run as root"
}

need_not_root() {
	[ "$(id -u)" != 0 ] || die "must not run as root; it writes into the repo and reads \$HOME"
}

have() {
	command -v "$1" >/dev/null 2>&1
}

# Copy only when the destination differs. Idempotence here is by content, not by a marker file:
# a marker lies the moment someone edits the destination by hand, which on a pilot is exactly
# what happens.
install_file() {
	src=$1 dest=$2 mode=${3:-0644}
	[ -f "$src" ] || die "missing source file: $src"
	if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
		return 0
	fi
	would "install $src -> $dest" && return 0
	mkdir -p "$(dirname -- "$dest")"
	cp -- "$src" "$dest"
	chmod "$mode" -- "$dest"
	log "installed $dest"
}

# Mirror a directory. Same content comparison, applied per file, plus removal of files the tree
# no longer carries so a rename does not leave the old name behind on the target.
install_tree() {
	src=$1 dest=$2
	[ -d "$src" ] || die "missing source directory: $src"
	find "$src" -type f | while read -r f; do
		rel=${f#"$src"/}
		install_file "$f" "$dest/$rel"
	done
	[ -d "$dest" ] || return 0
	find "$dest" -type f | while read -r f; do
		rel=${f#"$dest"/}
		[ -f "$src/$rel" ] && continue
		would "remove stale $f" && continue
		rm -f -- "$f"
		log "removed stale $f"
	done
}
