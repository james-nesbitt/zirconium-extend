# Zirconium Extension

This project extends the [Zirconium](https://github.com/zirconium-dev/zirconium) OCI image with additional tools or configurations.

## Features

- Custom Containerfile extending zirconium base image.
- Automate OCI image builds and pushes to container registry.
- GitHub Actions workflow for daily builds.

## Usage

### Local Development

Use `just` to build and test the container locally:

```bash
# Build the container
just build

# Run the container
just run
```

### Automation

A GitHub workflow is configured to automatically build and push the image daily or on push to the `master` branch.

### Bootc System Updates

This project builds a bootable OCI image (bootc) that is published daily. You can switch your currently running system to use this image, or upgrade it if you are already using it.

**Switch your system to this image:**
```bash
sudo bootc switch ghcr.io/james-nesbitt/zirconium-extend:latest
```

**Upgrade to the latest daily build:**
```bash
sudo bootc upgrade
```
