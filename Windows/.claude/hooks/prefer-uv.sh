#!/usr/bin/bash
# PreToolUse hook (matcher: Bash): block bare python/pip invocations, point to uv.
# Mirrors the CLAUDE.md rule this replaces: "uv over pip", "uv run over python3".
#
# Uses the shared anchor lib so `sudo pip install`, `bash -c "pip install"`,
# etc. are also caught, not just bare command-start invocations — mirrors
# no-pip-npm.sh in the upstream reference this was modeled on. SSH-wrapped
# forms (`ssh host pip install x`) are deliberately NOT covered — see
# lib/anchors.sh: pip/python have no local substitute on the remote end, so
# blocking would leave no alternative.
set -euo pipefail

source "$(dirname "$0")/lib/bypass.sh"
source "$(dirname "$0")/lib/emit.sh"
source "$(dirname "$0")/lib/read_input.sh"
source "$(dirname "$0")/lib/anchors.sh"

read_bash_command

# No point suggesting a tool that isn't installed.
command -v uv >/dev/null 2>&1 || exit 0

ANCHORS="(${CMD_ANCHOR_SUDO}|${CMD_WRAPPER})"

# Skip inside an active conda env — conda users may need pip for
# conda-managed interpreters.
if [ -z "${CONDA_PREFIX:-}" ] \
   && echo "$command" | grep -qP "${ANCHORS}pip3?${CMD_TRAIL}" \
   && ! has_bypass_marker BYPASS_UV_PIP_CHECK; then
    emit_pre_tool_deny_bypassable BYPASS_UV_PIP_CHECK 'Use uv instead of pip.
  pip install pkg  ->  uv add pkg (project) or uv pip install pkg (venv)
  pip freeze       ->  uv pip freeze'
    exit 0
fi

# Skip the common informational flags and an active venv/conda env (bare
# python3 is already correctly scoped there) — no reason to block those.
if echo "$command" | grep -qP "${ANCHORS}python3?${CMD_TRAIL}" \
   && ! echo "$command" | grep -qP 'python3?\s+(-V|--version|--help|-c\s)' \
   && [ -z "${VIRTUAL_ENV:-}" ] && [ -z "${CONDA_PREFIX:-}" ] \
   && ! has_bypass_marker BYPASS_UV_PYTHON_CHECK; then
    emit_pre_tool_deny_bypassable BYPASS_UV_PYTHON_CHECK 'Use uv run instead of bare python.
  python script.py  ->  uv run python script.py'
    exit 0
fi

exit 0
