#!/bin/bash

set -e

EXTRA_LINKS_FILE=.ci-temp/checkstyle/target/site/extra-site-links.txt

# The generator PR modifies the XDocs in the Checkstyle checkout during site generation.
# We ignore templates and deleted files.
CHANGED_XDOCS_PATHS=$(git -C .ci-temp/checkstyle diff --name-only --diff-filter=d -- \
  src/site/xdoc/ \
  | grep src/site/xdoc/ \
  | grep -v '.*xml.template$' \
  || true)
echo "CHANGED_XDOCS_PATHS=$CHANGED_XDOCS_PATHS"

if [[ -z "$CHANGED_XDOCS_PATHS" ]]; then
  echo "[WARN] The generator did not change any XDocs."
  exit 0
fi

: > "$EXTRA_LINKS_FILE"

# Use the diff produced by the locally installed generator.
PR_DIFF=$(git -C .ci-temp/checkstyle diff -- src/site/xdoc/)

# Iterate through all changed xdocs files.
while IFS= read -r CURRENT_XDOC_PATH; do
  echo "Processing file: $CURRENT_XDOC_PATH"

  EARLIEST_CHANGE_LINE_NUMBER=$(
    echo "$PR_DIFF" | grep -A 5 "diff.*$CURRENT_XDOC_PATH" | grep @@ | \
    head -1 | grep -oEi "[0-9]+" | head -1
  )
  if [[ -n "$EARLIEST_CHANGE_LINE_NUMBER" ]]; then
    EARLIEST_CHANGE_LINE_NUMBER=$((EARLIEST_CHANGE_LINE_NUMBER + 3))
    echo "EARLIEST_CHANGE_LINE_NUMBER=$EARLIEST_CHANGE_LINE_NUMBER"
  else
    echo "No diff change for $CURRENT_XDOC_PATH; using diff context only."
  fi

  SUBSECTION_ID=""

  DIFF_CONTEXT=$(
    head -n "$EARLIEST_CHANGE_LINE_NUMBER" \
      ".ci-temp/checkstyle/$CURRENT_XDOC_PATH" | tac
  )
  echo "DIFF_CONTEXT:"
  echo "$DIFF_CONTEXT"

  # Extract name attribute only from section or subsection tags.
  SECTION_NAME=$(echo "$DIFF_CONTEXT" | \
    grep -oP '<(?:section|subsection)[^>]*name="\K[^"]+' | head -1)
  SECTION_NAME=$(echo "$SECTION_NAME" | tr -d '\n\r' | \
    sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

  # Decode all HTML entities using Perl.
  SECTION_NAME=$(echo "$SECTION_NAME" | \
    perl -MHTML::Entities -pe '$_ = decode_entities($_)')

  echo "SECTION_NAME found: '$SECTION_NAME'"

  if [[ -n "$SECTION_NAME" ]]; then
    if echo "$SECTION_NAME" | grep -q '[^A-Za-z0-9 _-]'; then
      echo "Section name has special characters; encoding..."
      SUBSECTION_ID=$(echo "$SECTION_NAME" | tr -d '\n\r' | jq -sRr @uri | \
        sed 's/%/./g' | sed 's/\.20/_/g')
    else
      echo "Section name contains only allowed characters; replacing spaces..."
      SUBSECTION_ID=${SECTION_NAME// /_}
    fi

    # If the anchor starts with a digit, prefix it with an "a".
    if [[ "$SUBSECTION_ID" =~ ^[0-9] ]]; then
      SUBSECTION_ID="a$SUBSECTION_ID"
    fi
    echo "Derived SUBSECTION_ID: $SUBSECTION_ID"
  else
    echo "Warning: No section or subsection name found in $CURRENT_XDOC_PATH"
  fi

  CURRENT_XDOC_NAME=$(
    echo "$CURRENT_XDOC_PATH" | sed 's/src\/site\/xdoc\/\(.*\)\.xml/\1/' | \
    sed 's/.vm//'
  )
  echo "CURRENT_XDOC_NAME=$CURRENT_XDOC_NAME"

  echo "$CURRENT_XDOC_NAME.html#$SUBSECTION_ID" >> "$EXTRA_LINKS_FILE"
  echo "Added link suffix: $CURRENT_XDOC_NAME.html#$SUBSECTION_ID"

  SUBSECTION_ID=""
done <<< "$CHANGED_XDOCS_PATHS"
