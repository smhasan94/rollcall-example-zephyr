# rollcall-example-zephyr

[![rollcall](https://github.com/smhasan94/rollcall-example-zephyr/actions/workflows/rollcall.yml/badge.svg?branch=main)](https://github.com/smhasan94/rollcall-example-zephyr/actions/workflows/rollcall.yml)
[![CRA readiness](https://img.shields.io/endpoint?url=https%3A%2F%2Fraw.githubusercontent.com%2Fsmhasan94%2Frollcall-example-zephyr%2Fbadges%2Frollcall.json)](https://github.com/smhasan94/rollcall-example-zephyr/actions/workflows/rollcall.yml?query=branch%3Amain)

A minimal Zephyr firmware repository with [rollcall](https://github.com/smhasan94/rollcall)
wired into CI. Every push and pull request builds the firmware and runs the rollcall Action on
the build:

- a CycloneDX 1.6 SBOM of the product (MCUboot and the application as one product, the
  Zephyr kernel split into the subsystems the build links, every west module with its upstream
  purl and CPE), validated against the CycloneDX schema and checked against the CISA 2026 and
  CRA profiles;
- a grype scan, triaged with rollcall's starter VEX rules;
- a readiness report, in the job summary and the workflow artifact;
- on a pull request, one comment comparing the build with `main`, and a failing check if the
  pull request adds a high or critical vulnerability.

The second badge above is the readiness score of `main`'s latest build.

## What is here

| Path | What it is |
|------|------------|
| `app/` | The application: a sysbuild build with MCUboot (overwrite-only), after Zephyr's `samples/sysbuild/with_mcuboot` |
| `west.yml` | The west workspace: Zephyr v4.4.2 (pinned to its commit) with only the modules this build needs |
| `requirements.txt` | The pinned Python tools (west, reuse, imgtool) |
| `scripts/setup-sdk.sh` | Sets up the workspace and Zephyr SDK 1.0.1, each download checked against its SHA-256 |
| `scripts/build.sh` | Builds for `nrf52840dk/nrf52840` and prepares the build directory for rollcall (`west spdx`, `west list`) |
| `scripts/badge.sh` | Writes the readiness badge's JSON from the Action's `score` output |
| `.github/workflows/rollcall.yml` | CI: build, the rollcall Action, and the badge |

The pins are the ones rollcall's own Zephyr test fixtures are built with.

## Build it yourself

Needs Linux (x86-64 or arm64) or an Apple-silicon Mac, with `git`, `curl`, `tar`, `xz`,
Python 3.10+ (with venv), CMake 3.20+ and Ninja; about 2 GB of disk.

```sh
mkdir example-ws && cd example-ws
git clone https://github.com/smhasan94/rollcall-example-zephyr
rollcall-example-zephyr/scripts/setup-sdk.sh
rollcall-example-zephyr/scripts/build.sh
```

Then, with [rollcall installed](https://smhasan94.github.io/rollcall/quickstart.html):

```sh
cd rollcall-example-zephyr
rollcall generate build --identify -o product.cdx.json
rollcall validate --schema product.cdx.json
rollcall report --format md -o report.md product.cdx.json
```

## The badge

The `badge` job runs on pushes to `main` only. It turns the Action's `score` output into a
[shields.io endpoint](https://shields.io/badges/endpoint-badge) JSON file with
`scripts/badge.sh` and force-pushes it, as the only file, to the orphan branch `badges`. The
README's badge reads it from
`https://raw.githubusercontent.com/smhasan94/rollcall-example-zephyr/badges/rollcall.json`.
No external service or token is involved; the job's `contents: write` permission is the only
write access in the workflow.

## The pull-request comment

The branch `demo/mbedtls` adds Mbed TLS to the application (`CONFIG_MBEDTLS=y`). A pull
request from it shows the comment: the components the change adds, any new vulnerabilities,
and the gate's verdict.

## Licence

Apache-2.0; see [LICENSE](LICENSE). `app/` is derived from Zephyr's
`samples/sysbuild/with_mcuboot` (Apache-2.0, Copyright (c) 2022 Nordic Semiconductor).
