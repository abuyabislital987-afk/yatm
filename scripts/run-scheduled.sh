#!/bin/zsh

set -euo pipefail

ROOT_DIR="/Users/lingsu011900/Documents/yatm"
NODE_BIN="/opt/homebrew/bin/node"
LOG_DIR="$ROOT_DIR/logs"
PID_FILE="$LOG_DIR/yatm.pid"
STDOUT_LOG="$LOG_DIR/yatm.out.log"
STDERR_LOG="$LOG_DIR/yatm.err.log"
RUN_SECONDS=5400

mkdir -p "$LOG_DIR"
cd "$ROOT_DIR"

if [[ -f "$PID_FILE" ]]; then
  existing_pid="$(cat "$PID_FILE")"
  if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
    echo "$(date '+%F %T') yatm is already running with pid $existing_pid" >> "$STDOUT_LOG"
    exit 0
  fi
fi

EXIT_ON_QR=1 "$NODE_BIN" "$ROOT_DIR/dist/index.js" >> "$STDOUT_LOG" 2>> "$STDERR_LOG" &
child_pid=$!
echo "$child_pid" > "$PID_FILE"

(
  sleep "$RUN_SECONDS"
  if kill -0 "$child_pid" 2>/dev/null; then
    echo "$(date '+%F %T') yatm reached scheduled timeout, stopping pid $child_pid" >> "$STDOUT_LOG"
    kill "$child_pid" 2>/dev/null || true
  fi
) &
timeout_pid=$!

cleanup() {
  if [[ -n "${timeout_pid:-}" ]] && kill -0 "$timeout_pid" 2>/dev/null; then
    kill "$timeout_pid" 2>/dev/null || true
    wait "$timeout_pid" 2>/dev/null || true
  fi
  if kill -0 "$child_pid" 2>/dev/null; then
    kill "$child_pid" 2>/dev/null || true
    wait "$child_pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
}

trap cleanup EXIT INT TERM

wait "$child_pid" 2>/dev/null || true
