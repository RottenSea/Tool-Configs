#!/usr/bin/env bash
# Claude Code status line - Windows/Git Bash compatible
# Displays: [Model] | 📁 dir | 📋 session | ⛁ percentage%

input=$(cat)

# Extract fields using grep/cut (no jq dependency)
MODEL=$(echo "$input" | grep -o '"display_name":"[^"]*"' | cut -d'"' -f4)
CWD=$(echo "$input" | grep -o '"cwd":"[^"]*"' | cut -d'"' -f4)
SESSION=$(echo "$input" | grep -o '"session_name":"[^"]*"' | cut -d'"' -f4)
PCT=$(echo "$input" | grep -o '"used_percentage":[0-9.]*' | cut -d: -f2 | cut -d. -f1)

# Fallbacks
[ -z "$PCT" ] && PCT=0
DIRNAME="${CWD##*[/\\]}"

# ANSI colors
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
OFFWHITE='\033[38;5;255m'
RESET='\033[0m'

# Color-code percentage: green < 70%, yellow >= 70%
if [ "$PCT" -ge 70 ]; then PCT_COLOR="$YELLOW"
else PCT_COLOR="$GREEN"; fi

# Assemble: [Model] | 📁 dir | 📋 session | ⛁ 56%
OUTPUT="[${CYAN}${MODEL}${RESET}] | 📁 ${DIRNAME}"

# Session name is optional - only show when set via --name or /rename
[ -n "$SESSION" ] && OUTPUT="${OUTPUT} | 📋 ${SESSION}"

OUTPUT="${OUTPUT} | ${OFFWHITE}󰦨${RESET} ${PCT_COLOR}${PCT}%${RESET}"

echo -e "$OUTPUT"
