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
#
# Every variable here is prefixed. POSIX sh has no `local`, so a plain `src` set inside this
# function is the same `src` the caller is standing on — which silently corrupted every
# destination path the first time install_tree called this in a loop.
install_file() {
	_if_src=$1 _if_dest=$2 _if_mode=${3:-0644}
	[ -f "$_if_src" ] || die "missing source file: $_if_src"
	if [ -f "$_if_dest" ] && cmp -s "$_if_src" "$_if_dest"; then
		return 0
	fi
	would "install $_if_src -> $_if_dest" && return 0
	mkdir -p "$(dirname -- "$_if_dest")"
	cp -- "$_if_src" "$_if_dest"
	chmod "$_if_mode" -- "$_if_dest"
	log "installed $_if_dest"
}

# Copy a directory into a destination shared with other packages. Files the tree does not carry
# are left alone, because the destination is not ours.
#
# /etc/xdg is the case that matters: it belongs to every KDE package on the system. Deleting
# what Tundra does not manage there would take out the plasmashell autostart entry, the
# application menus and the session env scripts, which is a broken desktop rather than a clean
# one. The cost of not deleting is that a renamed artifact leaves its old name behind, and that
# is the right trade for a directory with other owners.
install_tree() {
	_it_src=$1 _it_dest=$2
	[ -d "$_it_src" ] || die "missing source directory: $_it_src"
	find "$_it_src" -type f | while read -r _it_f; do
		install_file "$_it_f" "$_it_dest/${_it_f#"$_it_src"/}"
	done
}

# Mirror a directory Tundra owns outright, removing anything the tree no longer carries so a
# rename does not leave the old name behind.
#
# Only safe where nothing else writes to the destination. The Look-and-Feel package directory
# qualifies; a shared directory never does.
install_tree_exclusive() {
	_ite_src=$1 _ite_dest=$2
	install_tree "$_ite_src" "$_ite_dest"
	[ -d "$_ite_dest" ] || return 0
	find "$_ite_dest" -type f | while read -r _ite_f; do
		[ -f "$_ite_src/${_ite_f#"$_ite_dest"/}" ] && continue
		would "remove stale $_ite_f" && continue
		rm -f -- "$_ite_f"
		log "removed stale $_ite_f"
	done
}
