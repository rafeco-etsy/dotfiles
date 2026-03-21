#!/bin/bash
# SessionStart hook: capture --name from claude process args
# and write it to a file the statusline script can read.

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // empty')

if [ -z "$session_id" ]; then
    exit 0
fi

# Extract --name value by walking up the process tree to find the claude process
pid=$$
for _ in 1 2 3 4 5; do
    pid=$(ps -p "$pid" -o ppid= 2>/dev/null | tr -d ' ')
    [ -z "$pid" ] || [ "$pid" = "1" ] && break
    args=$(ps -p "$pid" -o args= 2>/dev/null)
    name=$(echo "$args" | sed -n 's/.*--name[= ]\([^ ]*\).*/\1/p')
    [ -n "$name" ] && break
done

if [ -n "$name" ]; then
    echo -n "$name" > "/tmp/claude-session-${session_id}.name"
fi
