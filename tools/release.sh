#!/usr/bin/env bash
# Release = tag + push. The tag (v1.2.3) makes GitHub test, build the images
# with that version, deploy to the server and build the Windows game
# (.github/workflows/online.yml). Run from the repo, on main, nothing uncommitted:
#
#   bash tools/release.sh            # next patch: v0.1.0 -> v0.1.1
#   bash tools/release.sh minor      # v0.1.1 -> v0.2.0
#   bash tools/release.sh major      # v0.2.0 -> v1.0.0
#   bash tools/release.sh v2.0.0     # exactly this version
#   bash tools/release.sh -y ...     # don't ask before pushing
#   bash tools/release.sh -n ...     # dry run: show what would happen, change nothing
#
# Roll back: GitHub > Actions > "Online: build & deploy" > Run workflow, pick
# the older tag in "Use workflow from".
set -euo pipefail

YES=0
DRY=0
BUMP=patch
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES=1 ;;
    -n|--dry-run) DRY=1 ;;
    -h|--help) sed -n '2,15p' "$0"; exit 0 ;;
    patch|minor|major) BUMP="$arg" ;;
    v[0-9]*) BUMP="$arg" ;;
    *) echo "Unknown argument: $arg (try --help)"; exit 1 ;;
  esac
done

die() { echo "release: $*" >&2; exit 1; }

cd "$(git rev-parse --show-toplevel)"
[[ "$(git symbolic-ref --short HEAD 2>/dev/null)" == main ]] || die "switch to main first (git checkout main)"
[[ -z "$(git status --porcelain)" ]] || die "commit or stash your changes first (git status)"

echo "== checking GitHub"
git fetch --quiet --tags origin main
if ! git merge-base --is-ancestor origin/main HEAD; then
  die "GitHub's main has commits you don't have: git pull first"
fi

last="$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -1)"
if [[ "$BUMP" == v* ]]; then
  next="$BUMP"
  [[ "$next" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || die "version must look like v1.2.3"
elif [[ -z "$last" ]]; then
  [[ "$BUMP" == major ]] && next=v1.0.0 || next=v0.1.0
else
  IFS=. read -r ma mi pa <<<"${last#v}"
  case "$BUMP" in
    major) next="v$((ma + 1)).0.0" ;;
    minor) next="v$ma.$((mi + 1)).0" ;;
    patch) next="v$ma.$mi.$((pa + 1))" ;;
  esac
fi
if git rev-parse -q --verify "refs/tags/$next" >/dev/null; then
  die "tag $next already exists"
fi
if [[ -n "$last" ]] && [[ "$(git rev-parse "$last^{commit}")" == "$(git rev-parse HEAD)" ]]; then
  die "nothing new since $last"
fi

range="${last:+$last..}HEAD"
changes="$(git log --no-merges --format='- %s' "$range")"
ahead="$(git rev-list --count origin/main..HEAD)"

echo
echo "Release:   ${last:-(first release)} -> $next"
echo "Commit:    $(git log -1 --format='%h %s')"
echo "Unpushed:  $ahead commit(s) on main (pushed together with the tag)"
echo "Changes:"
echo "${changes:-  (none)}" | head -40
echo

if [[ "$DRY" == 1 ]]; then
  echo "Dry run: nothing tagged or pushed."
  exit 0
fi
if [[ "$YES" != 1 ]]; then
  read -r -p "Tag $next and deploy? [y/N] " answer
  [[ "$answer" =~ ^[Yy]$ ]] || die "cancelled"
fi

msg="$(mktemp)"
trap 'rm -f "$msg"' EXIT
{ echo "board2D $next"; echo; echo "${changes:-No changes listed.}"; } > "$msg"
git tag -a "$next" -F "$msg"

# One push for both: main and the tag land together or not at all.
if ! git push --atomic origin main "refs/tags/$next"; then
  git tag -d "$next" >/dev/null
  die "push failed; tag $next removed again (nothing was published)"
fi

url="$(git remote get-url origin | sed -E 's#^git@github.com:#https://github.com/#; s#\.git$##')"
echo
echo "Released $next. Deploy running: $url/actions"
