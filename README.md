# erpnext-hrms-image

Builds a self-hosted Frappe image with:

- [erpnext](https://github.com/frappe/erpnext) — the ERPNext business modules
- [hrms](https://github.com/frappe/hrms) — Frappe HR, payroll and attendance
- [frappe](https://github.com/frappe/frappe) — the framework, taken from the official `frappe/base` and `frappe/build` images

The build uses the stock `images/layered/Containerfile` from
[frappe/frappe_docker](https://github.com/frappe/frappe_docker), so the image
layout matches the official ones.

## Stable release policy

ERPNext and HRMS are pinned to **release tags** in [`apps.json`](apps.json) —
branch heads are never built:

```json
[
  { "url": "https://github.com/frappe/erpnext", "branch": "v16.54.0" },
  { "url": "https://github.com/frappe/hrms", "branch": "v16.53.2" }
]
```

The *Watch for Stable Releases* workflow checks the upstream tags daily
(04:00 UTC), considering only stable `vMAJOR.MINOR.PATCH` v16 tags (no beta/rc).
When a newer release exists it bumps these pins, commits, and **dispatches the
build explicitly** (a push made with the default `GITHUB_TOKEN` does not trigger
other workflows, so the dispatch is required).

Before anything is published, the build runs
[`ci/integration-test.sh`](ci/integration-test.sh): it starts MariaDB + Redis,
creates a throwaway site with `erpnext` and `hrms` installed, runs
`bench migrate` and `bench doctor`. If that fails, nothing is pushed and the
existing tags keep pointing at the last good image.

### What is and isn't pinned

| Component | Pinned? |
|---|---|
| `erpnext`, `hrms` | yes — release tags in `apps.json` |
| `frappe_docker` build files | yes — commit SHA in `build.yml` |
| GitHub Actions | yes — full commit SHAs (Dependabot keeps them current) |
| `frappe` framework + `frappe/base` / `frappe/build` images | **no** — they follow `version-16`. The upstream Containerfile uses one ref for both images and they don't share every patch tag, so a patch pin would hold the framework back. The resulting framework version is recorded in every run summary. |

So rebuilding the same `apps.json` can pick up newer framework/base-image
changes. The only truly immutable reference to a build is its **digest**.

## Tags

| Tag | Kind | Meaning |
|---|---|---|
| `:v16` | moving | Newest verified build |
| `:latest` | moving | Same image as `:v16` |
| `:erpnext-vX-hrms-vY` | pin | Both app versions, e.g. `:erpnext-v16.54.0-hrms-v16.53.2` |
| `:build-<run id>-<attempt>` | pin | Unique per workflow run, never reused |

**Production should deploy by digest.** Every run summary prints a ready-to-paste
line (`ERPNEXT_IMAGE=ghcr.io/shrekbytes/erpnext-hrms@sha256:...`). Moving tags
(`:v16`, `:latest`) are for experiments only.

## Rebuilds

- **Automatic** — *Watch for Stable Releases* finds a newer ERPNext or HRMS release.
- **Manual** — *Actions → Build HRMS Image → Run workflow*, or edit `apps.json`.

Deploying an update to a server is deliberately manual. The deployment folder
(compose file, `office-up.sh`, `office-upgrade.sh`) lives outside this repo; the
upgrade procedure is: **backup → pin new digest → stop app services → `bench
migrate` with the new image → start**.

## Running with Podman (rootless)

This repo only builds the image. Point your compose file at the digest:

```yaml
image: ghcr.io/shrekbytes/erpnext-hrms@sha256:<digest from the run summary>
```

Tested with Podman 6.1 using Docker Compose 5.x as the `podman compose`
provider (`systemctl --user enable --now podman.socket` required). Note
`podman compose` delegates to whichever provider is installed.

`ghcr.io` pulls need no login because the package inherits this public
repository's visibility.
