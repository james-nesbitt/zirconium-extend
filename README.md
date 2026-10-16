# Zirconium Extension

This project extends the [Zirconium](https://github.com/zirconium-dev/zirconium) OCI image with additional tools or configurations.

## Features

- Custom Containerfile extending zirconium base image.
- Automate OCI image builds and pushes to container registry.
- GitHub Actions workflow for daily builds.

## Usage

### Automation

A GitHub workflow is configured to automatically build and push the image daily or on push to the `master` branch.

### Bootc System Updates

This project builds a bootable OCI image (bootc) that is published daily. You can switch your currently running system to use this image, or upgrade it if you are already using it.

**Switch your system to this image:**
```bash
sudo bootc switch --apply ghcr.io/james-nesbitt/zirconium-extend:latest
```

**Upgrade to the latest daily build:**
```bash
sudo bootc upgrade --apply
```

### Local Development

Use `just` to build and test the container locally:

```bash
# Build the container
just build

# Run the container
just run
```

### Cato SDP client (VPN)

The image layers the Cato Networks Linux SDP client from its public RPM. The payload is
`/usr`-only, so it layers cleanly on an ostree root; the daemon creates its mutable state in
`/opt/cato` (i.e. `/var/opt/cato`) at first run. The RPM enables `cato-client.service` and
`cato-dem.service`, so the daemon is running after a reboot and the client is used from your
own desktop session, where SSO can open a real browser:

```bash
cato-sdp start --account <subdomain>     # as your normal user, NOT root
cato-sdp status
cato-sdp stop
```

Two consequences of an immutable `/usr`:

- **`cato-sdp update` cannot work** — the client's self-update writes into `/usr/lib/cato`.
  Version bumps come from rebuilding this image (the RPM URL is a rolling "latest").
- Builds are unpinned by default. For a reproducible build, pass the checksum:
  `podman build --build-arg CATO_RPM_SHA256=<sha256> …`

