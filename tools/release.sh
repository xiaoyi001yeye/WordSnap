#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  tools/release.sh [patch|minor|major|VERSION] [--build BUILD] [--remote REMOTE]

Examples:
  tools/release.sh
  tools/release.sh patch
  tools/release.sh minor
  tools/release.sh 0.2.0
  tools/release.sh 0.2.0 --build 12

This script updates pubspec.yaml, commits the release version, pushes main,
creates an annotated v* tag, and pushes the tag. GitHub Actions then builds and
publishes the release assets. It intentionally does not run local Flutter
validation or packaging commands.
USAGE
}

die() {
  echo "release: $*" >&2
  exit 1
}

remote="origin"
requested="patch"
build_override=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --build)
      [[ $# -ge 2 ]] || die "--build requires a number."
      build_override="$2"
      shift 2
      ;;
    --remote)
      [[ $# -ge 2 ]] || die "--remote requires a remote name."
      remote="$2"
      shift 2
      ;;
    -*)
      die "unknown option: $1"
      ;;
    *)
      [[ "$requested" == "patch" ]] || die "only one release target can be provided."
      requested="$1"
      shift
      ;;
  esac
done

[[ "$build_override" =~ ^$|^[0-9]+$ ]] || die "--build must be a positive integer."

repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" ||
  die "this script must be run inside a git repository."
cd "$repo_root"

[[ -f pubspec.yaml ]] || die "pubspec.yaml was not found."
app_version_file="lib/core/app_version.dart"
[[ -f "$app_version_file" ]] || die "$app_version_file was not found."
[[ "$(git branch --show-current)" == "main" ]] ||
  die "switch to the main branch before releasing."

git diff --quiet || die "working tree has uncommitted changes."
git diff --cached --quiet || die "index has staged changes."

git fetch "$remote" main --tags

local_head="$(git rev-parse main)"
remote_head="$(git rev-parse "$remote/main")"
if [[ "$local_head" != "$remote_head" ]]; then
  if git merge-base --is-ancestor "$local_head" "$remote_head"; then
    git pull --ff-only "$remote" main
  elif git merge-base --is-ancestor "$remote_head" "$local_head"; then
    echo "main is ahead of $remote/main; the release push will include local commits."
  else
    die "main and $remote/main have diverged; resolve that before releasing."
  fi
fi

current_line="$(grep -E '^version:[[:space:]]*' pubspec.yaml | head -n 1)"
[[ -n "$current_line" ]] || die "pubspec.yaml does not contain a version line."

current_version="${current_line#version:}"
current_version="${current_version#"${current_version%%[![:space:]]*}"}"
current_version="${current_version%"${current_version##*[![:space:]]}"}"

visible_version="${current_version%%+*}"
current_build="0"
if [[ "$current_version" == *"+"* ]]; then
  current_build="${current_version##*+}"
fi

[[ "$visible_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
  die "current visible version must be x.y.z, got: $visible_version"
[[ "$current_build" =~ ^[0-9]+$ ]] ||
  die "current build number must be numeric, got: $current_build"

IFS=. read -r major minor patch <<<"$visible_version"

case "$requested" in
  patch)
    patch=$((patch + 1))
    ;;
  minor)
    minor=$((minor + 1))
    patch=0
    ;;
  major)
    major=$((major + 1))
    minor=0
    patch=0
    ;;
  v[0-9]*.[0-9]*.[0-9]*)
    requested="${requested#v}"
    [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
      die "release version must be x.y.z or vx.y.z."
    IFS=. read -r major minor patch <<<"$requested"
    ;;
  [0-9]*.[0-9]*.[0-9]*)
    [[ "$requested" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] ||
      die "release version must be x.y.z or vx.y.z."
    IFS=. read -r major minor patch <<<"$requested"
    ;;
  *)
    die "release target must be patch, minor, major, or an explicit x.y.z version."
    ;;
esac

next_version="$major.$minor.$patch"
next_build="${build_override:-$((current_build + 1))}"
full_version="$next_version+$next_build"
tag_name="v$next_version"

[[ "$next_build" -gt "$current_build" ]] ||
  die "build number must increase above $current_build."

if git rev-parse "$tag_name" >/dev/null 2>&1; then
  die "tag already exists locally: $tag_name"
fi
if git ls-remote --exit-code --tags "$remote" "refs/tags/$tag_name" >/dev/null 2>&1; then
  die "tag already exists on $remote: $tag_name"
fi

echo "Releasing $full_version as $tag_name"

perl -0pi -e "s/^version:\\s*.*$/version: $full_version/m" pubspec.yaml
perl -0pi -e "s/static const String version = '[^']+';/static const String version = '$next_version';/" "$app_version_file"
perl -0pi -e "s/static const String buildNumber = '[^']+';/static const String buildNumber = '$next_build';/" "$app_version_file"

git diff -- pubspec.yaml "$app_version_file"
git add pubspec.yaml "$app_version_file"
git commit -m "Release $tag_name"
git push "$remote" main
git tag -a "$tag_name" -m "Release $tag_name"
git push "$remote" "$tag_name"

cat <<EOF

Release tag pushed: $tag_name
Release commit: $(git rev-parse --short HEAD)
GitHub Actions will build and publish the release assets.
EOF
