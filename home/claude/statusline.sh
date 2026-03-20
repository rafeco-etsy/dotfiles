#!/bin/bash
# Claude Code Status Line
# Fields: session, model, git, context, cost, duration, clock, gcloud

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD_GREEN='\033[1;32m'
LABEL='\033[1;37m'
RESET='\033[0m'

input=$(cat)
jqr() { echo "$input" | jq -r "$1"; }

session_id=$(jqr '.session_id // empty')
transcript_path=$(jqr '.transcript_path // empty')
cwd=$(jqr '.workspace.current_dir // .cwd // empty')
model=$(jqr '.model.display_name // "unknown"')
pct=$(jqr '.context_window.used_percentage // 0')
cost=$(jqr '.cost.total_cost_usd // 0')
duration_ms=$(jqr '.cost.total_duration_ms // 0')

# --- Session ---
# NOTE: --name doesn't expose the name to statusline scripts yet.
# This catches names set via /rename (writes custom-title to transcript).
session=""
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    session=$(grep '"type":"custom-title"' "$transcript_path" 2>/dev/null | tail -1 | jq -r '.customTitle // empty' 2>/dev/null)
fi
if [ -z "$session" ]; then
    session_field=$(printf "%bunnamed%b" "$YELLOW" "$RESET")
else
    session_field=$(printf "%b%s%b" "$BOLD_GREEN" "$session" "$RESET")
fi

# --- Git ---
git_field=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    repo=$(basename "$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)")
    if [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
        git_field=$(printf "%b%s/%s *%b" "$YELLOW" "$repo" "$branch" "$RESET")
    else
        git_field=$(printf "%b%s/%s%b" "$GREEN" "$repo" "$branch" "$RESET")
    fi
fi

# --- Context ---
pct_int=${pct%.*}
if [ "$pct_int" -lt 50 ] 2>/dev/null; then
    ctx_color="$GREEN"
elif [ "$pct_int" -lt 80 ] 2>/dev/null; then
    ctx_color="$YELLOW"
else
    ctx_color="$RED"
fi
context_field=$(printf "%b%d%%%b" "$ctx_color" "$pct_int" "$RESET")

# --- Cost ---
cost_field=$(printf "\$%.2f" "$cost")

# --- Duration ---
ms=${duration_ms%.*}
if [ "$ms" -ge 60000 ] 2>/dev/null; then
    duration_field="$((ms / 60000))m"
elif [ "$ms" -gt 0 ] 2>/dev/null; then
    duration_field="$((ms / 1000))s"
else
    duration_field="0s"
fi

# --- Clock ---
hour=$((10#$(date +%H)))
time_str=$(date +%H:%M)
dow=$(date +%u)
if [ "$dow" -ge 6 ]; then
    clock_color="$RED"
elif [ "$hour" -lt 6 ]; then
    clock_color="$RED"
elif [ "$hour" -lt 7 ]; then
    clock_color="$YELLOW"
elif [ "$hour" -ge 18 ]; then
    clock_color="$RED"
elif [ "$hour" -ge 16 ]; then
    clock_color="$YELLOW"
else
    clock_color="$GREEN"
fi
clock_field=$(printf "%b%s%b" "$clock_color" "$time_str" "$RESET")

# --- GCloud ---
gcloud_field=""
creds_file="$HOME/.config/gcloud/credentials.db"
if [ -f "$creds_file" ]; then
    auth_epoch=$(stat -c %Y "$creds_file" 2>/dev/null || stat -f %m "$creds_file" 2>/dev/null)
    if [ -n "$auth_epoch" ]; then
        now=$(date +%s)
        diff=$(( (auth_epoch + 86400) - now ))
        if [ "$diff" -le 0 ]; then
            gcloud_field=$(printf "%bEXPIRED%b" "$RED" "$RESET")
        else
            hours=$((diff / 3600))
            mins=$(((diff % 3600) / 60))
            if [ "$hours" -lt 1 ]; then
                gc_color="$RED"
            elif [ "$hours" -lt 2 ]; then
                gc_color="$YELLOW"
            else
                gc_color="$GREEN"
            fi
            if [ "$hours" -gt 0 ]; then
                gcloud_field=$(printf "%b%dh%dm%b" "$gc_color" "$hours" "$mins" "$RESET")
            else
                gcloud_field=$(printf "%b%dm%b" "$gc_color" "$mins" "$RESET")
            fi
        fi
    fi
fi

# --- Build output ---
sep=" | "
out="$session_field"
out+="${sep}${model}"
[ -n "$git_field" ] && out+="${sep}${git_field}"
out+="${sep}${LABEL}Context: ${RESET}${context_field}"
out+="${sep}${LABEL}Cost: ${RESET}${cost_field}"
out+="${sep}${LABEL}Time: ${RESET}${duration_field}"
out+="${sep}${LABEL}Clock: ${RESET}${clock_field}"
[ -n "$gcloud_field" ] && out+="${sep}${LABEL}GCloud: ${RESET}${gcloud_field}"

printf "%b" "$out"
