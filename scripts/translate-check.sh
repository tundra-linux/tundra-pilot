#!/bin/sh
# Every file in the tree has a stated Alpine destination.
#
# This is what makes "artifacts take the Alpine shape" enforceable rather than aspirational.
# The translation record is the Phase 2 handoff: without it, moving this tree onto Tundra is a
# reading exercise over the whole repo, and a file nobody remembers the purpose of gets either
# dropped or carried for years.
#
# baseline/ is excluded because it is never installed anywhere, and docs/ because it is the
# record itself. Everything else needs a row.
#
# Pilot-only. Exempt from the BusyBox vocabulary rule.

set -eu

_tundra_dir=$(dirname -- "$0")
# shellcheck source=scripts/common.sh
. "$_tundra_dir/common.sh"

RECORD=$REPO_ROOT/docs/translation.md
[ -f "$RECORD" ] || die "missing $RECORD"

STATUS=0

# Files that need a row. Dotfiles at the repo root are repo mechanics rather than artifacts:
# .gitignore does not install anywhere and listing it would be noise in the record.
tracked_files() {
	find "$REPO_ROOT" -type f \
		-not -path "$REPO_ROOT/.git/*" \
		-not -path "$REPO_ROOT/.lint-cache/*" \
		-not -path "$REPO_ROOT/baseline/*" \
		-not -path "$REPO_ROOT/docs/*" \
		-not -name '.git*' \
		-not -name '.editorconfig' \
		-not -name 'README.md' \
		-not -name 'AGENTS.md' \
		-not -name 'LICENSE' \
		-print | sed -e "s|^$REPO_ROOT/||" | sort
}

missing=0
for rel in $(tracked_files); do
	# A row names the path in the first column. Match on the literal path inside backticks so
	# a prose mention elsewhere in the document does not count as a row.
	if grep -Fq "\`$rel\`" "$RECORD"; then
		continue
	fi
	printf 'FAIL no entry in docs/translation.md for %s\n' "$rel" >&2
	missing=$((missing + 1))
	STATUS=1
done

# The other direction. A row for a file that no longer exists is how the record rots: it reads
# as complete while describing a tree that has moved on.
stale=0
# The backticks are markdown delimiters being matched, not command substitution.
# shellcheck disable=SC2016
for path in $(grep -oE '`[A-Za-z0-9._/-]+`' "$RECORD" | tr -d '`' | sort -u); do
	case $path in
		*/) continue ;;
		/*) continue ;;                      # an install destination, not a repo path
		baseline/*|docs/*) continue ;;
	esac
	# Only things with a directory component. Every file in this tree lives in a subdirectory,
	# so a bare name in backticks is prose referring to a script by name, not a row.
	case $path in
		*/*) ;;
		*) continue ;;
	esac
	[ -e "$REPO_ROOT/$path" ] && continue
	printf 'FAIL docs/translation.md names %s, which is not in the tree\n' "$path" >&2
	stale=$((stale + 1))
	STATUS=1
done

if [ "$STATUS" = 0 ]; then
	log "translation record covers the tree"
else
	log "$missing file(s) with no entry, $stale entry(s) with no file" >&2
fi
exit "$STATUS"
