#!/usr/bin/env bash
set -euo pipefail

required_vars=(
  RELEASE_HOST
  RELEASE_USER
  RELEASE_REMOTE_DIR
  RELEASE_PUBLIC_BASE_URL
  APK_PATHS
  VERSION_NAME
  VERSION_CODE
  RELEASE_NOTES_FILE
)

for name in "${required_vars[@]}"; do
  if [ -z "${!name:-}" ]; then
    echo "Missing required environment variable: ${name}" >&2
    exit 1
  fi
done

if [ ! -f "$RELEASE_NOTES_FILE" ]; then
  echo "Release notes file does not exist: $RELEASE_NOTES_FILE" >&2
  exit 1
fi

apk_paths=()
while IFS= read -r apk_path; do
  apk_paths+=("$apk_path")
done < <(printf '%s\n' "$APK_PATHS" | tr ' ' '\n' | sed '/^[[:space:]]*$/d')
if [ "${#apk_paths[@]}" -eq 0 ]; then
  echo "APK_PATHS did not contain any APK files." >&2
  exit 1
fi

for apk_path in "${apk_paths[@]}"; do
  if [ ! -f "$apk_path" ]; then
    echo "APK path does not exist: $apk_path" >&2
    exit 1
  fi
done

RELEASE_CHANNEL="${RELEASE_CHANNEL:-stable}"
RELEASE_ENVIRONMENT="${RELEASE_ENVIRONMENT:-prod}"
FORCE_UPDATE="${FORCE_UPDATE:-false}"
MIN_SUPPORTED_VERSION_CODE="${MIN_SUPPORTED_VERSION_CODE:-1}"
ROLLOUT_PERCENTAGE="${ROLLOUT_PERCENTAGE:-100}"
GIT_TAG="${GIT_TAG:-v${VERSION_NAME}}"
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
RUN_ID="${GITHUB_RUN_ID:-local-$(date +%Y%m%d%H%M%S)}"

version_key="${VERSION_NAME}+${VERSION_CODE}"
manifest_name="release-android-${version_key}.json"

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT

assets_json="$work_dir/assets.json"
printf '[\n' > "$assets_json"
first_asset=true
primary_download_url=""
primary_file_size=""
primary_sha256=""

infer_abi() {
  case "$1" in
    *arm64-v8a*) echo "arm64-v8a" ;;
    *armeabi-v7a*) echo "armeabi-v7a" ;;
    *x86_64*) echo "x86_64" ;;
    *) echo "universal" ;;
  esac
}

json_escape() {
  node -e 'process.stdout.write(JSON.stringify(process.argv[1]))' "$1"
}

for apk_path in "${apk_paths[@]}"; do
  source_name="$(basename "$apk_path")"
  abi="$(infer_abi "$source_name")"
  if [ "$abi" = "universal" ]; then
    apk_name="wordsnap-${version_key}-${RELEASE_CHANNEL}.apk"
    sha_name="wordsnap-${version_key}-${RELEASE_CHANNEL}.sha256"
  else
    apk_name="wordsnap-${version_key}-${abi}-${RELEASE_CHANNEL}.apk"
    sha_name="wordsnap-${version_key}-${abi}-${RELEASE_CHANNEL}.sha256"
  fi

  cp "$apk_path" "$work_dir/$apk_name"
  file_size="$(wc -c < "$work_dir/$apk_name" | tr -d ' ')"
  sha256="$(shasum -a 256 "$work_dir/$apk_name" | awk '{print $1}')"
  printf '%s  %s\n' "$sha256" "$apk_name" > "$work_dir/$sha_name"
  download_url="${RELEASE_PUBLIC_BASE_URL%/}/${version_key}/${apk_name}"

  if [ "$first_asset" = true ]; then
    first_asset=false
  else
    printf ',\n' >> "$assets_json"
  fi
  printf '  {"name":%s,"abi":%s,"downloadUrl":%s,"fileSizeBytes":%s,"sha256":%s}' \
    "$(json_escape "$apk_name")" \
    "$(json_escape "$abi")" \
    "$(json_escape "$download_url")" \
    "$file_size" \
    "$(json_escape "$sha256")" >> "$assets_json"

  if [ "$abi" = "arm64-v8a" ] || [ -z "$primary_download_url" ]; then
    primary_download_url="$download_url"
    primary_file_size="$file_size"
    primary_sha256="$sha256"
  fi
done
printf '\n]\n' >> "$assets_json"

published_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

export RELEASE_CHANNEL RELEASE_ENVIRONMENT FORCE_UPDATE MIN_SUPPORTED_VERSION_CODE
export ROLLOUT_PERCENTAGE GIT_TAG COMMIT_SHA VERSION_NAME VERSION_CODE
export DOWNLOAD_URL="$primary_download_url"
export FILE_SIZE="$primary_file_size"
export SHA256="$primary_sha256"
export PUBLISHED_AT="$published_at"

node - "$RELEASE_NOTES_FILE" "$assets_json" "$work_dir/$manifest_name" <<'NODE'
const fs = require('node:fs');
const [
  notesFile,
  assetsFile,
  manifestFile,
] = process.argv.slice(2);

const rawNotes = fs.readFileSync(notesFile, 'utf8');
const notes = rawNotes
  .split(/\r?\n/)
  .map((line) => line.trim())
  .filter((line) => line.startsWith('- ') || line.startsWith('* '))
  .map((line) => line.slice(2).trim())
  .filter(Boolean);

const env = process.env;
const versionName = env.VERSION_NAME;
const versionCode = Number(env.VERSION_CODE);
const assets = JSON.parse(fs.readFileSync(assetsFile, 'utf8'));
const manifest = {
  id: `android-${env.RELEASE_CHANNEL}-${versionCode}`,
  platform: 'android',
  channel: env.RELEASE_CHANNEL,
  environment: env.RELEASE_ENVIRONMENT,
  versionName,
  versionCode,
  minSupportedVersionCode: Number(env.MIN_SUPPORTED_VERSION_CODE),
  forceUpdate: env.FORCE_UPDATE === 'true',
  status: 'active',
  title: `发现新版本 ${versionName}`,
  releaseNotes: notes.length ? notes : [rawNotes.trim()].filter(Boolean),
  downloadUrl: env.DOWNLOAD_URL,
  fileSizeBytes: Number(env.FILE_SIZE),
  sha256: env.SHA256,
  assets,
  gitTag: env.GIT_TAG,
  commitSha: env.COMMIT_SHA,
  publishedAt: env.PUBLISHED_AT,
  rollout: {
    enabled: true,
    percentage: Number(env.ROLLOUT_PERCENTAGE),
  },
};
fs.writeFileSync(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
NODE

ssh_target="${RELEASE_USER}@${RELEASE_HOST}"
remote_tmp="${RELEASE_REMOTE_DIR%/}/.tmp/${RUN_ID}-${version_key}"
remote_version_dir="${RELEASE_REMOTE_DIR%/}/android/${version_key}"
remote_manifest_dir="${RELEASE_REMOTE_DIR%/}/manifests"

ssh "$ssh_target" "mkdir -p '$remote_tmp' '$remote_version_dir' '$remote_manifest_dir'"
scp "$work_dir"/*.apk "$work_dir"/*.sha256 "$work_dir/$manifest_name" "$ssh_target:$remote_tmp/"
ssh "$ssh_target" "cd '$remote_tmp' && for sum in *.sha256; do sha256sum -c \"\$sum\"; done"
ssh "$ssh_target" "\
  set -euo pipefail; \
  mv '$remote_tmp'/*.apk '$remote_version_dir/'; \
  mv '$remote_tmp'/*.sha256 '$remote_version_dir/'; \
  mv '$remote_tmp/$manifest_name' '$remote_manifest_dir/$manifest_name'; \
  cp '$remote_manifest_dir/$manifest_name' '$remote_manifest_dir/latest-android-${RELEASE_CHANNEL}.json'; \
  rmdir '$remote_tmp'"

for url in $(node -e "const a=require(process.argv[1]); for (const asset of a) console.log(asset.downloadUrl)" "$assets_json"); do
  curl --fail --location --head "$url" >/dev/null
done

{
  echo "### WordSnap Android release"
  echo
  echo "- Version: ${version_key}"
  echo "- Tag: ${GIT_TAG}"
  echo "- Primary APK: ${primary_download_url}"
  echo "- SHA-256: ${primary_sha256}"
  echo "- Manifest: ${remote_manifest_dir}/${manifest_name}"
  echo "- APK count: ${#apk_paths[@]}"
} >> "${GITHUB_STEP_SUMMARY:-/dev/stdout}"
