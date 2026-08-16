#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/policy.sh
source "$SCRIPT_DIR/../lib/policy.sh"
require_local_ai || exit $?

# Get the list, skip the header, and extract the first column (model names)
model_names=$(ollama list | tail -n +2 | awk '{print $1}')

# Build a JSON array
json_array="["
for name in $model_names; do
    json_array+="\"$name\","
done

# Remove trailing comma and close the array
json_array="${json_array%,}]"

# Output the JSON array
echo "$json_array"