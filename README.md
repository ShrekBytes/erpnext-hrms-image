# erpnext-hrms-image

Builds a self-hosted Frappe image that includes:

- [frappe](https://github.com/frappe/frappe) (framework, `version-16`)
- [erpnext](https://github.com/frappe/erpnext) (`version-16`)
- [hrms](https://github.com/frappe/hrms) — Frappe HR, provides payroll (`version-16`)

The app list lives in [`apps.json`](apps.json). The build uses the stock
`images/layered/Containerfile` from [frappe/frappe_docker](https://github.com/frappe/frappe_docker),
so the image layout matches the official ones.

## Tags

| Tag | Kind | Meaning |
|---|---|---|
| `:v16` | moving | Newest build of the `version-16` branches |
| `:latest` | moving | Same image as `:v16` |
| `:v<version>` | pin | ERPNext version in the image, e.g. `:v16.51.1` |
| `:sha-<commit>` | pin | Workflow commit the image was built from |

Pin a build in a compose file to freeze or roll back:

```yaml
image: ghcr.io/shrekbytes/erpnext-hrms:v16.51.1
```

## Rebuilds

- **Push to `main`** — when `apps.json` or the workflow changes.
- **Weekly** — Mondays 03:00 UTC. Each run re-fetches the current `version-16`
  branches of Frappe/ERPNext/HRMS, so upstream fixes land in the next build.
  (GitHub pauses schedules after 60 days without repo activity; re-enable from
  the Actions tab if that happens.)
- **Manually** — *Actions → Build HRMS Image → Run workflow*.

After pulling a newer image on a server, run the stack update and migrate:

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
