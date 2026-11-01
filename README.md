# GitHub Actions metadata lab

Small fixture for observing native GitHub check selection and concurrency. Jobs run for seconds. The `route` job is a generic event router, not a model of any production classifier.

## Files

- `.github/workflows/fixture.yml`: job `Route fixture event`, then one `validate` job whose check name depends on the route: `Validate fixture` (dispatch or routed code event, steps `Hold` then `Validate`), `Metadata skip` (title/body edit, no validation), or `Fallback validation` (router failed, runs the real validator). `actions/checkout@v4` is a tag, not an immutable SHA pin.
- `fixture/validate.sh`: logs checkout commit and parents, fails if `fixture/mode` is not `pass` or if `fixture/require-base-marker` exists without `fixture/base-a-marker`.
- `fixture/mode`: `pass` or `fail`.
- `branch-protection.json`: required check `Validate fixture` bound to GitHub Actions (app_id 15368), strict, admins enforced, PR required with 0 approvals.

Control files you add on branches: `fixture/hold-seconds`, `fixture/route-hold-seconds` (step `Hold route` sleeps 0-30s before the router decides), `fixture/route-fault`, `fixture/require-base-marker`, `fixture/base-a-marker`.

## Setup

```sh
R=theredspoon/github-actions-metadata-lab
git push origin main
gh api -X PUT repos/$R/branches/main/protection --input branch-protection.json
gh api repos/$R/branches/main/protection/required_status_checks
```

## Cases

Observe each case with:

```sh
gh run list -R $R --workflow fixture.yml
gh api repos/$R/commits/<head-sha>/check-runs --jq '.check_runs[] | [.name,.status,.conclusion,.app.id] | @tsv'
gh pr view <n> -R $R --json mergeStateStatus,statusCheckRollup
```

1. Title/body edit isolation. Push a head with `fixture/hold-seconds` set to `25`. While it holds, run `gh pr edit <n> --title x`. The edit run uses the `meta` concurrency group and posts only `Metadata skip`. Expected: the code run is not cancelled, and only the code run posts `Validate fixture` on the head SHA.
2. Newer code supersession. Push twice within 25 seconds. Expected: the first run is cancelled by `cancel-in-progress` in the `code` group.
3. Router fault. Commit `fixture/route-fault`. The router exits 1. `Fallback validation` runs the real script under its own name. No `Validate fixture` check is posted for that run, so the required check stays missing and the PR stays blocked. Set `fixture/mode` to `fail` as well to see `Fallback validation` fail with no canonical replacement.
4. Older base success after newer base failure. Create `base-a` from `main` and commit `fixture/base-a-marker` there only. Open a PR from a head that adds `fixture/require-base-marker`, targeting `base-a`: passes. Retarget with `gh pr edit <n> --base main`: the merge checkout has no marker, so the shell check fails. Retarget back to `base-a` with the same head SHA: passes again. Compare the logged merge commit and parents for each run.
5. Manual cancel of the required check. `gh workflow run fixture.yml --ref <head-branch> -f hold_seconds=25`. Find the run with `gh run list -R $R --workflow fixture.yml --event workflow_dispatch --limit 1`. Wait until `gh run view <id> -R $R --json jobs` shows `Validate fixture` in_progress on step `Hold` (poll at most 20 seconds). Run `gh run cancel <id> -R $R`. Expected: `Validate fixture` ends cancelled before step `Validate` runs. Record the check run and rollup for the head SHA.

## Limits

These runs show how hosted GitHub Actions behaved in this repository at the time of the run. They do not validate any production classifier, required-check policy, or merge queue. No status or check is written through the API. Every outcome comes from an Actions job. A cancelled run that posts `Validate fixture` may still be selected by the rollup. Recording that behavior is part of the experiment.
