#!/usr/bin/env bash
set -euo pipefail

CREDENTIALS=$(
  /usr/bin/security find-generic-password \
    -s "Claude Code-credentials" \
    -w
)

TOKEN=$(
  jq -er '.claudeAiOauth.accessToken' <<<"$CREDENTIALS"
)

curl --fail --silent --show-error \
  "https://api.anthropic.com/api/oauth/usage" \
  -H "Authorization: Bearer $TOKEN" \
  -H "anthropic-beta: oauth-2025-04-20" |
  jq
