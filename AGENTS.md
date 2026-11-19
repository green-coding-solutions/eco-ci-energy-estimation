# Eco CI - Agent Guide

Eco CI estimates the energy (and CO2) of CI jobs. It is pure Bash: a background sampler records CPU utilization,
and each measurement maps it to power via a pre-computed power curve of the runner hardware.

It exposes three tasks: `start-measurement`, `get-measurement` (a "lap" with a label) and `display-results`.
Integrations:
- GitHub: composite action in `action.yml`
- GitLab: `eco-ci-gitlab.yml` (included by users, see `.gitlab-ci.yml.example`)
- Jenkins / local: `scripts/examples/`

`README.md` is the user documentation (all inputs/variables). Do not duplicate it here when updating this file.

## Map

- `scripts/setup.sh` - `start_measurement` / `lap_measurement` / `end_measurement`, starts and kills the CPU sampler, holds `ECO_CI_VERSION`
- `scripts/make_measurement.sh` - one lap: CPU util -> power lookup -> energy / CO2, sends data to the GMT API (if `send-data`)
- `scripts/display_results.sh` - totals, table, badge, PR comment text, energy unit (J / Wh / kWh)
- `scripts/vars.sh` - state persistence (`add_var` / `read_vars`) and `cpu_vars` (machine -> embodied carbon / SCI constants)
- `scripts/misc.sh` - geo IP lookup and grid intensity API (`location-based` CO2 method)
- `scripts/json.sh` - JSON output artifacts (`json-output`)
- `scripts/cpu-utilization-{linux,macos}.sh` - background CPU samplers
- `machine-power-data/*.sh` - power curves generated with [Cloud Energy](https://github.com/green-coding-solutions/cloud-energy) (`declare -A cloud_energy_hashmap`). Generated - do not hand-edit.

## Important Concepts

- Every task runs in a separate process / CI step. All state lives in `/tmp/eco-ci/`.
  `vars.sh` appends `KEY='value'` lines to `/tmp/eco-ci/vars.sh` and re-`source`s it, so values must not contain single quotes.
- `setup.sh start_measurement` takes **22 positional arguments**. Adding or reordering one requires updating all callers in lockstep:
  - `action.yml`
  - `eco-ci-gitlab.yml`
  - `scripts/examples/local_ci.example.sh`, `scripts/examples/jenkins_start.sh`
  - the forwarding `case` and the argument-count guard at the bottom of `setup.sh`
  - `README.md` (GitHub inputs, GitLab variables, Jenkins / local sections)

  Always append new arguments at the end.
- Flow of a new user-facing option: `action.yml` input -> positional arg -> `add_var` in `setup.sh` -> consuming script -> GitLab variable default in `eco-ci-gitlab.yml` -> README.
- New machine power data: generate the file with Cloud Energy, add it to `machine-power-data/`, and add a branch in `vars.sh::cpu_vars`
  setting `ECO_CI_MODEL_NAME`, `ECO_CI_SCI_M` and `ECO_CI_SCI_USAGE_DURATION` (with a source comment for each value).
- Portability: must run on Linux (x86 and arm), macOS and Alpine.
  - Bash >= 4 (associative arrays). macOS / Alpine need coreutils for `date "+%s%6N"` (microseconds).
  - Only `curl`, `jq`, `awk`, `date` and `git` (GitLab) are available. No Python / Node dependencies.
- Scripts use `set -euo pipefail`. Keep it.
- Labels and tags are user input interpolated into shell. Keep the existing sanitizing (quote rejection, `tr -d`).
- Users pin `@vX` tags that get moved on release. Do not make breaking changes to inputs or output formats without a major version.

## Testing

- There is no unit test suite.
- Local smoke test: `bash scripts/examples/local_ci.example.sh`
  - keep `ECO_CI_SEND_DATA='false'`
  - it defaults to `macos-14-mac-mini-m1.sh` power data. On Linux switch `ECO_CI_MACHINE_POWER_DATA` to `default.sh`
- The real tests are the GitHub workflows in `.github/workflows/` (Ubuntu 22.04 / 24.04 / 24.04-arm and macOS 14). They need repository secrets, so they only fully run on PRs from the main repository.

## Releases

Releases are done by humans - see `MAINTAINERS.md`. They include bumping `ECO_CI_VERSION` in `scripts/setup.sh`.
Agents must **never** run `update-tag.sh`. It deletes and force-rewrites tags on the remote.

## Updating this file

If you find general concepts that apply to most of the code in this repository, update this file.
