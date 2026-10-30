#!/usr/bin/env bash
# The agent's supervised loop for the overnight run (docs/agent.md): restarts it after a crash, but stops
# on a config error (exit 2) or when another agent already holds the state directory (exit 3).
# Settings come from the environment or api3/agent/.env. Two contracts at once, for example:
#   api3/agent/run-forever.sh                                              # v2 (PULSE_PLUS_ADDRESS from .env)
#   AGENT_CONTRACT_VERSION=v1 PULSE_PLUS_ADDRESS=0x91d7… api3/agent/run-forever.sh   # the v1 hedge
# Needs cast, node and jq on PATH (on Julien's laptop: run it from a login shell, zsh -lic).
set -uo pipefail
cd "$(dirname "$0")/../.."
while true; do
  python3 api3/agent/pulse_agent.py run --quiet "$@"
  code=$?
  case $code in
    2) echo "config error, not restarting" >&2; exit 2 ;;
    3) echo "another agent holds this state directory, not restarting" >&2; exit 3 ;;
  esac
  echo "agent exited $code at $(date +%H:%M:%S), restarting in 5 s" >&2
  sleep 5
done
