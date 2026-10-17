# frappe-hrms-image

Builds a self-hosted Frappe image that includes:

- [frappe](https://github.com/frappe/frappe) (framework, `version-16`)
- [erpnext](https://github.com/frappe/erpnext) (`version-16`)
- [hrms](https://github.com/frappe/hrms) — Frappe HR, provides payroll (`version-16`)

The app list lives in [`apps.json`](apps.json). The build uses the stock
`images/layered/Containerfile` from [frappe/frappe_docker](https://github.com/frappe/frappe_docker),
so the image layout matches the official ones.

## Output

```
ghcr.io/shrekbytes/frappe-hrms:v16
ghcr.io/shrekbytes/frappe-hrms:latest
```

Rebuilds run automatically on push to `main`, or manually via *Actions → Build
HRMS Image → Run workflow*.

## Usage (Podman, rootless)

Point the compose file's Frappe services at the image:

```yaml
image: ghcr.io/shrekbytes/frappe-hrms:v16
```

Then, after the stack is up, install the app on the site:

```bash
podman exec -u frappe <backend-container> bench --site <site> install-app hrms
podman exec -u frappe <backend-container> bench --site <site> migrate
```

`ghcr.io` pulls need no login because the package inherits this public
repository's visibility.
