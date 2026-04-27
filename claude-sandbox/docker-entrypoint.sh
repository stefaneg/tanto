#!/bin/sh
set -eu

# Allow passing raw Claude flags via `docker run ... <flags>`.
# - No args: run Claude with the default sandbox flag.
# - First arg is a flag: treat all args as Claude args.
# - First arg is a command (e.g. `bash`): run it as-is.
default_claude_flag="--dangerously-skip-permissions"

if [ "$#" -eq 0 ]; then
    set -- claude "$default_claude_flag"
elif [ "$1" = "claude" ]; then
    :
elif [ "${1#-}" != "$1" ]; then
    set -- claude "$default_claude_flag" "$@"
fi

exec "$@"
