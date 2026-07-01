#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
Usage: scripts/notarytool-store-credentials.sh PROFILE_NAME

Required environment:
  APPLE_ID
  APPLE_TEAM_ID
  APPLE_APP_SPECIFIC_PASSWORD

Example:
  APPLE_ID=you@example.com \\
  APPLE_TEAM_ID=ABCDE12345 \\
  APPLE_APP_SPECIFIC_PASSWORD=xxxx-xxxx-xxxx-xxxx \\
  scripts/notarytool-store-credentials.sh virt-connector-notary
EOF
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 2
fi

: "${APPLE_ID:?APPLE_ID is required}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required}"
: "${APPLE_APP_SPECIFIC_PASSWORD:?APPLE_APP_SPECIFIC_PASSWORD is required}"

xcrun notarytool store-credentials "$1" \
  --apple-id "$APPLE_ID" \
  --team-id "$APPLE_TEAM_ID" \
  --password "$APPLE_APP_SPECIFIC_PASSWORD"
