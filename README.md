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
  { "url": "https://github.com/frappe/erpnext", "branch": "v16.51.1" },
  { "url": "https://github.com/frappe/hrms", "branch": "v16.51.0" }
]
```

The *Watch for Stable Releases* workflow checks the upstream release tags daily
(04:00 UTC). Only when a newer v16 release exists does it bump these pins and
commit — and that commit is what triggers a build. Every published image
therefore contains released, tagged code, never an unreleased or hotfix commit.

If a build fails its verification step, nothing is published and the existing
tags keep pointing at the last good image.

The framework is deliberately **not** pinned to a patch tag: the Containerfile
uses one ref for both `frappe/build:<ref>` and `frappe/base:<ref>`, and those
images do not share every patch tag (`base` publishes `v16.52.0` while `build`
has `v16.51.1`), so a pin would hold the framework backwards.
`frappe/base:version-16` / `frappe/build:version-16` are Frappe's own released
images from the stable `version-16` branch.

## Tags

| Tag | Kind | Meaning |
|---|---|---|
| `:v16` | moving | Newest verified build |
| `:latest` | moving | Same image as `:v16` |
| `:v<version>` | pin | ERPNext version in the image, e.g. `:v16.51.1` |
| `:sha-<commit>` | pin | Workflow commit the image was built from |

Pin a build in a compose file to freeze or roll back:

```yaml
image: ghcr.io/shrekbytes/erpnext-hrms:v16.51.1
```

## Rebuilds

- **Automatic** — only when *Watch for Stable Releases* finds a newer ERPNext or
  HRMS release.
- **Manual** — *Actions → Build HRMS Image → Run workflow* rebuilds the pinned
  versions; editing `apps.json` yourself also triggers a build.
- Every build verifies that `frappe`, `erpnext` and `hrms` are present before it
  pushes anything.

Deploying an update to a server is deliberately a manual step:

```bash
podman compose -f <compose file> pull
podman compose -f <compose file> up -d --no-build
podman exec -u frappe <backend-container> bench --site <site> migrate
```

## Usage (Podman, rootless)

Point the compose file's Frappe services at the image:

```yaml
image: ghcr.io/shrekbytes/erpnext-hrms:v16
```

Then, after the stack is up, install the app on the site:

```bash
podman exec -u frappe <backend-container> bench --site <site> install-app hrms
podman exec -u frappe <backend-container> bench --site <site> migrate
```

`ghcr.io` pulls need no login because the package inherits this public
repository's visibility.