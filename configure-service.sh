#!/bin/bash

# Usage: ./replace_key_value.sh <file> <key> <new_value>

FILE=$1
KEY=$2
NEW_VALUE=$3

if [[ -z "$FILE" || -z "$KEY" || -z "$NEW_VALUE" ]]; then
  echo "Usage: $0 <file> <key> <new_value>"
  exit 1
fi

# Escape special characters in the key and new value
ESCAPED_KEY=$(printf '%s\n' "$KEY" | sed -e 's/[]\/$*.^[]/\\&/g')
ESCAPED_NEW_VALUE=$(printf '%s\n' "$NEW_VALUE" | sed -e 's/[\/&]/\\&/g')

# Replace the value for the given key
sed -i "s/^\($ESCAPED_KEY *= *\).*/\1$ESCAPED_NEW_VALUE/" "$FILE"

echo "Replaced value for key '$KEY' with '$NEW_VALUE' in file '$FILE'."