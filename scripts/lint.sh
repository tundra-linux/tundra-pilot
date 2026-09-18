#!/bin/sh
# Shell linting for the whole tree. Run by the pre-commit hook.
#
# Two halves, because shell portability has two halves and no single tool covers both.
#
# The parser half runs over every script here: shellcheck -s sh, checkbashisms, and
# busybox ash -n. Fedora's busybox is a fair stand-in for Alpine's as a parser — the two
# builds differ in four ash options, none of which changes how a script parses — but note
# what this half cannot do. Both distributions build busybox with CONFIG_ASH_BASH_COMPAT=y,
# so `busybox ash -n` accepts [[ and source without complaint. checkbashisms and shellcheck
# are the tools actually rejecting bashisms; the parse step catches syntax errors.
#
# The vocabulary half runs only over target/, inside a stock alpine container. It is the half
# no parser checks: sed -i exists in BusyBox and grep -P does not, find has no -printf, and
# date -d takes far less than GNU's version. Fedora's busybox is the wrong oracle for this —
# its build enables about ninety applets Alpine's does not, including ar, patch, xz, ed, man
# and w, and omits a dozen Alpine ships, including lsblk, nsenter, fallocate and uuidgen — so
# a check against the local binary passes scripts that break on the target and fails scripts
# that are fine there. The container is BusyBox, musl and apk with no GNU coreutils present,
# which makes the applet list the target's.
#
# Exits nonzero on the first failure.

set -eu

_tundra_dir=$(dirname -- "$0")
# shellcheck source=scripts/common.sh
. "$_tundra_dir/common.sh"

STATUS=0
ALPINE_IMAGE=${ALPINE_IMAGE:-docker.io/library/alpine:latest}

fail() {
	printf 'FAIL %s\n' "$*" >&2
	STATUS=1
}

# Every file in the tree whose first line names /bin/sh. Found by content, not by extension,
# because target/ scripts ship without one.
sh_scripts() {
	find "$REPO_ROOT" -type f \
		-not -path "$REPO_ROOT/.git/*" \
		-not -path "$REPO_ROOT/baseline/*" \
		-print | while read -r f; do
		head -n 1 "$f" 2>/dev/null | grep -q '^#!/bin/sh' && printf '%s\n' "$f"
	done
}

# Pilot-only scripts run on Fedora and are exempt from the vocabulary check. The exemption is
# by directory and it is recorded here rather than assumed, so that adding a directory is a
# decision someone makes on purpose.
is_pilot_only() {
	case ${1#"$REPO_ROOT"/} in
		scripts/*) return 0 ;;
		*)         return 1 ;;
	esac
}

# --- the parser half --------------------------------------------------------------------

check_parsers() {
	log "== parsers"
	found=0
	for f in $(sh_scripts); do
		found=$((found + 1))
		rel=${f#"$REPO_ROOT"/}

		if have shellcheck; then
			# -x follows sourced files, so common.sh is analysed as part of each caller
			# rather than reported as an unfollowable source on every single script.
			shellcheck -x -s sh "$f" || fail "shellcheck: $rel"
		else
			warn "shellcheck not installed; skipping"
		fi

		if have checkbashisms; then
			checkbashisms -f "$f" || fail "checkbashisms: $rel"
		else
			warn "checkbashisms not installed; skipping"
		fi

		if have busybox; then
			busybox ash -n "$f" || fail "busybox ash -n: $rel"
		else
			warn "busybox not installed; skipping"
		fi
	done
	log "checked $found script(s)"
}

# --- the vocabulary half ----------------------------------------------------------------

check_vocabulary() {
	log "== vocabulary (target/ only)"

	targets=
	for f in $(sh_scripts); do
		is_pilot_only "$f" && continue
		targets="$targets $f"
	done

	if [ -z "$targets" ]; then
		log "no target-bound scripts yet; nothing to check"
		return 0
	fi

	# podman is what the pilot installs and what Tundra ships, so it is what this expects.
	# docker is accepted because a developer machine that is not the pilot often has only
	# that, and the check is about the Alpine image's contents rather than about the runtime.
	if have podman; then
		runtime=podman
	elif have docker; then
		runtime=docker
	else
		warn "no container runtime; cannot check the applet vocabulary against a real Alpine"
		fail "vocabulary check skipped, and target/ scripts exist"
		return 0
	fi

	mkdir -p "$REPO_ROOT/.lint-cache"
	allow=$REPO_ROOT/.lint-cache/busybox-applets
	if [ ! -s "$allow" ]; then
		log "generating the applet allowlist from $ALPINE_IMAGE via $runtime"
		"$runtime" run --rm "$ALPINE_IMAGE" busybox --list | sort >"$allow"
	fi

	# Commands the container provides outside BusyBox, plus the shell keywords and builtins a
	# command-word scan would otherwise flag. apk is listed because an Alpine system has it;
	# flatpak and notify-send are listed because Tundra installs them as real packages, and
	# the point of this check is BusyBox-versus-GNU, not an inventory of the whole image.
	extra_allowed='apk flatpak notify-send doas if then else elif fi for while until do done
case esac in function return exit local export readonly set unset shift eval exec trap
printf echo read test true false cd umask wait command hash type pwd getopts times ulimit
alias unalias break continue'

	for f in $targets; do
		rel=${f#"$REPO_ROOT"/}
		# Command words: the first word of a line, and the first word after a pipe, && or ;.
		# The trailing character is captured so that an assignment can be told apart from a
		# command — `status=ok` starts a line the same way `sort -u` does, and without this
		# every variable in the script is reported as a missing applet.
		words=$(sed -e 's/#.*//' "$f" |
			grep -oE '(^|[|;&]|\$\()[[:space:]]*[a-z][a-z0-9_.-]*=?' |
			sed -e 's/^[^a-z]*//' |
			grep -v '=$' | sort -u)
		for w in $words; do
			grep -qx "$w" "$allow" && continue
			printf '%s\n' "$extra_allowed" | tr ' ' '\n' | grep -qx "$w" && continue
			# A function defined in the script itself is not a command.
			grep -qE "^[[:space:]]*${w}[[:space:]]*\(\)" "$f" && continue
			fail "vocabulary: $rel uses '$w', which is not a BusyBox applet on Alpine"
		done
	done
}

check_parsers
check_vocabulary

if [ "$STATUS" = 0 ]; then
	log ""
	log "lint clean"
fi
exit "$STATUS"
