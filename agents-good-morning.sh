#!/bin/sh
# Good morning cron script to agent sessions early.
export PATH=/Users/gulli/.local/bin:/Users/gulli/.nvm/versions/node/v24.13.1/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin

# Use live IDs, so closing the workspace or an agent does not break the next run.
exec /usr/bin/python3 - <<'PY'
import fcntl
import json
from pathlib import Path
import subprocess
import sys

HERDR = "/Users/gulli/.local/bin/herdr"
CWD = "/Users/gulli/src/github.com/stefaneg/axis"
LOG_DIR = Path("/Users/gulli/.local/state/axis-morning")
LOG_DIR.mkdir(parents=True, exist_ok=True)


def command(*args, log=None):
    result = subprocess.run(
        [HERDR, "--session", "default", *args],
        capture_output=True, text=True,
    )
    if log:
        log.write(result.stdout + result.stderr)
        log.flush()
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or result.stdout.strip())
    return json.loads(result.stdout)["result"]


def unique(items, description):
    if len(items) > 1:
        raise RuntimeError("Multiple " + description + "; refusing to guess")
    return items[0] if items else None


def ensure_agent(workspace, kind, label, log):
    panes = command("pane", "list", "--workspace", workspace)["panes"]
    # Reuse agents even if their tab has been renamed or they have no agent name.
    agent = unique([p for p in panes if p.get("agent") == kind], kind + " agents")
    if agent:
        return agent["pane_id"]

    tabs = command("tab", "list", "--workspace", workspace)["tabs"]
    tab = unique([t for t in tabs if t.get("label") == label], label + " tabs")
    if not tab:
        # Reuse the initial shell tab, including after an interrupted setup.
        tab = next((t for t in tabs if t.get("label") == "shell"
                    and any(p["tab_id"] == t["tab_id"] for p in panes)
                    and all(not p.get("agent") for p in panes
                            if p["tab_id"] == t["tab_id"])), None)
    if tab:
        pane = unique([p for p in panes if p["tab_id"] == tab["tab_id"]],
                      "panes in " + label + " tab")
        if not pane or pane.get("agent"):
            raise RuntimeError(label + " tab has no available shell pane")
        pane_id = pane["pane_id"]
        command("tab", "rename", tab["tab_id"], label, log=log)
    else:
        created = command("tab", "create", "--workspace", workspace,
                          "--cwd", CWD, "--label", label, "--no-focus", log=log)
        pane_id = created["root_pane"]["pane_id"]

    # Herdr validates that the pane is a free shell and waits for agent readiness.
    command("agent", "start", "good-morning-" + kind,
            "--kind", kind, "--pane", pane_id, log=log)
    return pane_id


def main():
    workspaces = command("workspace", "list")["workspaces"]
    workspace = unique([w for w in workspaces if w.get("label") == "Good Morning"],
                       "Good Morning workspaces")
    if not workspace:
        workspace = command("workspace", "create", "--cwd", CWD,
                            "--label", "Good Morning", "--no-focus")["workspace"]
    workspace_id = workspace["workspace_id"]

    status = 0
    for kind, label in (("claude", "Claude"), ("codex", "Codex")):
        with (LOG_DIR / (kind + ".log")).open("a") as log:
            try:
                pane_id = ensure_agent(workspace_id, kind, label, log)
                agent = command("agent", "get", pane_id)["agent"]
                state = agent["agent_status"]
                if state == "working":
                    log.write("Agent is already working; skipping this morning prompt.\n")
                    continue
                if state not in ("idle", "done"):
                    raise RuntimeError(kind + " is " + state + "; needs attention before prompting")
                command("agent", "prompt", pane_id, "good morning", log=log)
            except (RuntimeError, OSError, KeyError, ValueError) as error:
                log.write(str(error) + "\n")
                print(kind + ": " + str(error), file=sys.stderr)
                status = 1
    return status


# Serialize scheduled/manual invocations so they cannot create duplicate tabs.
with (LOG_DIR / "run.lock").open("a") as lock:
    try:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        sys.exit(0)
    try:
        sys.exit(main())
    except (RuntimeError, OSError, KeyError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
PY
