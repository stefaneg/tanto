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

alias gr='ghrepo'
alias ghr='ghrepo'
alias gpr='ghpr'
