#!/bin/bash
# Start bin/dev in a tmux session and wait for the server to be ready.

set -e

SESSION_NAME="APPNAME-dev"
PROJECT_DIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SERVER_URL="http://localhost:${PORT:-APPNAME_PORT}"
TIMEOUT=20
POLL_INTERVAL=1

if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "ALREADY_RUNNING"
else
    cd "$PROJECT_DIR"
    tmux new-session -d -s "$SESSION_NAME" "cd $PROJECT_DIR && bin/dev"
    echo "STARTED"
fi

elapsed=0
while [ $elapsed -lt $TIMEOUT ]; do
    if curl -s -o /dev/null -w "%{http_code}" "$SERVER_URL" 2>/dev/null | grep -q "200\|302"; then
        echo "READY"
        exit 0
    fi
    sleep $POLL_INTERVAL
    elapsed=$((elapsed + POLL_INTERVAL))
done

echo "TIMEOUT"
exit 1
