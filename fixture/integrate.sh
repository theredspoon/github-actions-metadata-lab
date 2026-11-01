#!/bin/sh
# Usage: HEAD_SHA=<40hex> BASE_SHA=<40hex or empty> sh fixture/integrate.sh
# Checks that HEAD is HEAD_SHA, then merges BASE_SHA into the working tree
# with --no-commit --no-ff. Empty BASE_SHA (dispatch) skips the merge.
# Never commits or pushes. Any conflict or error exits non-zero.
set -eu
is_sha() { printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$'; }
is_sha "${HEAD_SHA:-}" || { echo "HEAD_SHA is not 40 hex: '${HEAD_SHA:-}'"; exit 1; }
actual=$(git rev-parse HEAD)
echo "declared head=$HEAD_SHA base=${BASE_SHA:-<none>} actual HEAD=$actual"
[ "$actual" = "$HEAD_SHA" ] || { echo "HEAD mismatch"; exit 1; }
if [ -z "${BASE_SHA:-}" ]; then
  echo "no base: merge skipped, tree=$(git rev-parse HEAD^{tree})"
  exit 0
fi
is_sha "$BASE_SHA" || { echo "BASE_SHA is not 40 hex: '$BASE_SHA'"; exit 1; }
git cat-file -e "$BASE_SHA^{commit}" || { echo "BASE_SHA not present locally"; exit 1; }
if ! git -c user.name=fixture -c user.email=fixture@invalid \
    merge --no-commit --no-ff "$BASE_SHA"; then
  echo "merge of base into head failed"
  exit 1
fi
[ -z "$(git diff --name-only --diff-filter=U)" ] || { echo "unmerged paths"; exit 1; }
echo "integrated head=$actual base=$BASE_SHA tree=$(git write-tree)"
