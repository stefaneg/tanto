_gh_open_url() {
  local opener="$1" url="$2"
  "$opener" "$url" >/dev/null 2>&1 &
}

_gh_url_opener() {
  if command -v xdg-open >/dev/null 2>&1; then
    echo "xdg-open"
  elif command -v open >/dev/null 2>&1; then
    echo "open"
  elif command -v cygstart >/dev/null 2>&1; then
    echo "cygstart"
  else
    return 1
  fi
}

_gh_origin_repo_url() {
  local remote_url repo_url

  remote_url="$(git remote get-url origin 2>/dev/null)" || return 1

  case "$remote_url" in
    git@github.com:*.git)
      repo_url="https://github.com/${remote_url#git@github.com:}"
      repo_url="${repo_url%.git}"
      ;;
    git@github.com:*)
      repo_url="https://github.com/${remote_url#git@github.com:}"
      ;;
    https://github.com/*.git)
      repo_url="${remote_url%.git}"
      ;;
    https://github.com/*)
      repo_url="$remote_url"
      ;;
    http://github.com/*.git)
      repo_url="https://github.com/${remote_url#http://github.com/}"
      repo_url="${repo_url%.git}"
      ;;
    http://github.com/*)
      repo_url="https://github.com/${remote_url#http://github.com/}"
      ;;
    *)
      return 1
      ;;
  esac

  echo "$repo_url"
}

ghrepo() {
  local repo_url opener

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ghrepo: not inside a git repository" >&2
    return 1
  fi

  repo_url="$(_gh_origin_repo_url)" || {
    echo "ghrepo: origin is not a github.com remote or is missing" >&2
    return 1
  }

  opener="$(_gh_url_opener)" || {
    echo "ghrepo: no URL opener found (tried xdg-open, open, cygstart)" >&2
    return 1
  }

  _gh_open_url "$opener" "$repo_url"
}

ghpr() {
  local repo_url opener branch pr_url repo_path owner branch_q head_q search_url

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "ghpr: not inside a git repository" >&2
    return 1
  fi

  branch="$(git branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "ghpr: detached HEAD; switch to a branch first" >&2
    return 1
  fi

  opener="$(_gh_url_opener)" || {
    echo "ghpr: no URL opener found (tried xdg-open, open, cygstart)" >&2
    return 1
  }

  if command -v gh >/dev/null 2>&1; then
    pr_url="$(gh pr view --json url -q .url 2>/dev/null)"
    if [[ -n "$pr_url" ]]; then
      _gh_open_url "$opener" "$pr_url"
      return 0
    fi
  fi

  repo_url="$(_gh_origin_repo_url)" || {
    echo "ghpr: origin is not a github.com remote or is missing" >&2
    return 1
  }

  repo_path="${repo_url#https://github.com/}"
  owner="${repo_path%%/*}"
  branch_q="${branch//\//%2F}"
  head_q="${owner}%3A${branch_q}"
  search_url="${repo_url}/pulls?q=is%3Apr+is%3Aopen+head%3A${head_q}"

  _gh_open_url "$opener" "$search_url"
}

function mkcd() {
    # Create a directory and enter it
    mkdir -p "$1" && cd "$1"
}

function up() {
    # Go up n directories
    local d=""
    limit=$1
    for ((i=1 ; i <= limit ; i++))
    do
        d=$d/..
    done
    d=$(echo $d | sed 's/^\///')
    if [ -z "$d" ]; then
        d=..
    fi
    cd $d
}

function run_with_timing() {
    start_time=$(date +%s.%N)
    "$@"
    end_time=$(date +%s.%N)
    duration=$(echo "$end_time - $start_time" | bc)
    echo "\nCommand completed in $duration seconds"
}
alias rwt=run_with_timing

# Add to your shell configuration
function proj() {
    # Define your project directories
    local projects=(
        ~/src/
    )

    # Use fzf to select only git projects (.git can be a dir or file)
    local selected=$(
        find "${projects[@]}" -maxdepth 4 \( -name .git -type d -o -name .git -type f \) -print 2>/dev/null \
            | sed 's#/\.git$##' \
            | sort -u \
            | fzf --preview '
                dir={}
                readme=""
                for candidate in \
                    "$dir/README.md" \
                    "$dir/readme.md" \
                    "$dir/README" \
                    "$dir/readme" \
                    "$dir/README.txt" \
                    "$dir/readme.txt"
                do
                    if [ -f "$candidate" ]; then
                        readme="$candidate"
                        echo readme found
                        break
                    fi
                done
                if [ -n "$readme" ]; then
                    if command -v bat >/dev/null 2>&1; then
                        bat --style=plain --color=always --line-range=1:40 "$readme"
                    else
                        head -n 40 "$readme"
                    fi
                else
                    echo "No README found in $dir"
                fi
            ' --preview-window=right:60%
    )

    if [[ -n "$selected" ]]; then
        cd "$selected"
        goland .
    fi
}

function build-claude-sandbox(){
  docker build -t claude-sandbox $TANTO_HOME/claude-sandbox
}

function claude-in-sandbox(){
    echo "Running claude in sandbox with params $@"
    local project_name project_path
    project_name="$(basename "$(pwd)")"
    project_path="/home/claude/projects/$project_name"
    echo Project path: "$project_path"
    # The sandbox authenticates with its own long-lived token rather than a copy
    # of the host login. Sharing one credential means both sides refresh it, and
    # a rotated refresh token logs the loser out.
    # Mint one with `claude setup-token`, then either export
    # CLAUDE_CODE_OAUTH_TOKEN or stash it in the keychain:
    #   security add-generic-password -s tanto-claude-oauth-token -a "$USER" -w <token>
    local claude_token
    claude_token="$CLAUDE_CODE_OAUTH_TOKEN"
    [ -n "$claude_token" ] || claude_token="$(security find-generic-password -s tanto-claude-oauth-token -w 2>/dev/null || true)"
    if [ -z "$claude_token" ]; then
        echo "Warning: no sandbox token found; claude will prompt for /login in the container." >&2
        echo "         Run 'claude setup-token', then export CLAUDE_CODE_OAUTH_TOKEN or add it to the keychain as tanto-claude-oauth-token." >&2
    fi
    # gh keeps its token in the macOS keyring, not in hosts.yml, so hand it over explicitly.
    local gh_token
    gh_token="$(gh auth token 2>/dev/null || true)"
    [ -n "$gh_token" ] || echo "Warning: no gh token on host; gh will be unauthenticated in the sandbox."
    # Hand the host daemon to the sandbox so e2e suites that need docker run
    # instead of skipping. The socket appears inside the container as root:root
    # 0660, so claude needs group 0 to talk to it. Note this gives the sandbox
    # full control of the host daemon — set TANTO_NO_DOCKER_SOCK=1 to opt out.
    local -a docker_sock_args
    docker_sock_args=()
    if [ -z "$TANTO_NO_DOCKER_SOCK" ] && [ -S /var/run/docker.sock ]; then
        docker_sock_args=(-v /var/run/docker.sock:/var/run/docker.sock --group-add 0)
    fi
  	docker run --rm -it \
  		"${docker_sock_args[@]}" \
  		-v "$(pwd)":"$project_path" \
  		-v "$HOME/.claude":/home/claude/.claude \
  		-v "$HOME/.claude.json":/home/claude/.claude.json \
  		-v "$HOME/.config/ccstatusline":/home/claude/.config/ccstatusline \
  		-v "$HOME/.config/gh":/home/claude/.config/gh:ro \
  		-v "$HOME/.gitconfig":/home/claude/.gitconfig:ro \
  		-e GH_TOKEN="$gh_token" \
  		-e CLAUDE_CODE_OAUTH_TOKEN="$claude_token" \
  		-e CURRENT_DIR_NAME="$project_name" \
  		-w "$project_path" \
  		claude-sandbox $@
}

function claude-usage {
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
      jq -r '
        "five_hour: \(.five_hour.utilization)% (resets \(.five_hour.resets_at))",
        "seven_day: \(.seven_day.utilization)% (resets \(.seven_day.resets_at))"
      '
}


alias gr='ghrepo'
alias ghr='ghrepo'
alias gpr='ghpr'
