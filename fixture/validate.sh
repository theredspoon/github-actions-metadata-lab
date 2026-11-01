#!/bin/sh
# Usage: validate.sh
set -eu
echo "checkout: $(git log -1 --format='%H parents=%P')"
mode=$(cat fixture/mode 2>/dev/null || echo pass)
if [ -f fixture/require-base-marker ] && [ ! -f fixture/base-a-marker ]; then
  echo "fixture/require-base-marker present but fixture/base-a-marker absent in merge checkout"
  exit 1
fi
[ "$mode" = "pass" ] || { echo "fixture/mode=$mode"; exit 1; }
echo "validation passed"
