#!/bin/sh
set -eu

default_claude_flag="--dangerously-skip-permissions"

echo "In $(pwd)"

if [ "$#" -eq 0 ]; then
    set -- claude "$default_claude_flag"
elif [ "$1" = "claude" ]; then
    :
elif [ "${1#-}" != "$1" ]; then
    set -- claude "$default_claude_flag" "$@"
fi

exec "$@"
