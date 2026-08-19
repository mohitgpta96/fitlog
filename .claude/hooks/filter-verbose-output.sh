#!/bin/bash
input=$(cat)
cmd=$(echo "$input" | jq -r '.tool_input.command')

if [[ "$cmd" =~ ^(npm test|npm run test|pytest|go test|yarn test|pnpm test) ]]; then
  filtered_cmd="$cmd 2>&1 | grep -A 5 -E '(FAIL|ERROR|error:|Error:)' | head -150"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":{\"command\":\"$filtered_cmd\"}}}"
  exit 0
fi

if [[ "$cmd" =~ ^(npm install|npm ci|pip install|yarn install|pnpm install) ]]; then
  filtered_cmd="$cmd 2>&1 | tail -40"
  echo "{\"hookSpecificOutput\":{\"hookEventName\":\"PreToolUse\",\"permissionDecision\":\"allow\",\"updatedInput\":{\"command\":\"$filtered_cmd\"}}}"
  exit 0
fi

echo "{}"
