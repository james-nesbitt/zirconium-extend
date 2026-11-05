# Zirconium Extension

A curated build of [Zirconium](https://github.com/zirconium-dev/zirconium).

This repo used to layer packages onto `ghcr.io/zirconium-dev/zirconium:latest`
with a `Containerfile`. It now runs the **full mkosi build itself**, against a
pinned checkout of upstream in `upstream/`, using upstream's own profiles plus
one of ours.

The reason for the change: a derived layer can only add. Removing a package in
a derived image writes a whiteout — the base layer still ships, so the pull
never shrinks and `brew`'s enabled units still run. Building from upstream's
profiles lets us pick the profile list and use `RemovePackages=`, which takes
roughly 1.3 GB and six enabled units out of the image.

**No upstream file is modified.** We are a consumer of their tree, not a fork.

## Layout

| Path | What it is |
|---|---|
| `upstream/` | submodule → `zirconium-dev/zirconium`, pinned to a SHA |
| `mkosi.profiles/jnesbitt/` | our profile: packages added, packages removed, Cato, branding |
| `Justfile` | thin wrapper; `just sync` copies the profile into `upstream/` |
| `.github/workflows/build-and-push.yaml` | weekly build + push to GHCR |

## What the profile changes

Added: `zsh` (login shell — upstream ships none and deletes `/usr/bin/chsh`),
`ghostty` (the default terminal), `mise` (previously only inside distrobox, so
host shells lost 33 tools), `@virtualization`, `dux-files` +
`ffmpegthumbnailer`, and the Cato Networks SDP client.

Dropped, all evidence-backed against this machine: `WithRecommends=false`
(which alone sheds an orphaned `qt6-qtwebengine`), `glibc-all-langpacks`,
`ibus`, `tailscale`, `orca`, the print-driver stack, the VM guest agents, the
fcitx5 CJK engines, and assorted never-launched desktop extras.

Deliberately **kept**: `fcitx5` itself — `~/.config/fcitx5/profile` drives
us/lv layout switching. Only its CJK engines go.

Deliberately **not carried over** from the old `Containerfile`: `containerd`
and `rootlesskit` (distrobox requires `podman`, never containerd),
`cliphist` (DMS 2.x has a native clipboard store at `~/.cache/dms/clipboard`),
`wezterm` and `alacritty` (one and two launches ever; ghostty is the terminal).

The `brew` profile is simply absent from the profile list in the `Justfile`.

## Building

```bash
just cat-config   # render merged config, no build — verifies the profile merged
just build        # full mkosi build (~40-60 min)
just load         # load the result into podman
just rechunk      # re-layer so bootc upgrades pull small deltas
just lint         # bootc container lint
just all          # all of the above
```

`just sync` runs automatically before `build`/`cat-config`; it copies
`mkosi.profiles/jnesbitt/` into `upstream/mkosi.profiles/` and adds a local
git exclude so the submodule stays clean.

## Bumping upstream

```bash
cd upstream && git fetch && git checkout <sha> && cd ..
git add upstream && git commit -m "chore: bump upstream to <sha>"
```

Builds are pinned on purpose: upstream's `terra`/`duxlabs` COPR churn now lands
in our CI rather than theirs, so the bump should be a deliberate act.

## Bootc system updates

**Switch your system to this image:**
```bash
sudo bootc switch --apply ghcr.io/james-nesbitt/zirconium-extend:latest
```

**Upgrade to the latest build:**
```bash
sudo bootc upgrade --apply
```

Builds run weekly (Mondays 03:00 UTC), not daily — a full mkosi build is
~40-60 minutes of runner time, and the only input that moves is a submodule we
bump by hand.

### Image signing

The image is **unsigned**. Upstream's `zirconium-bootc-ostree` profile bakes a
`policy.json` that pins `ghcr.io/zirconium-dev` to their cosign public key;
`ghcr.io/james-nesbitt` falls through to the `insecureAcceptAnything` default,
so `bootc switch` works but verifies nothing. Signing it properly needs our own
cosign keypair, a `SIGNING_SECRET` repo secret, and matching `policy.json` and
`registries.d` entries in the profile.

### Cato SDP client (VPN)

The payload is `/usr`-only, so it layers cleanly on an ostree root; the daemon
creates its mutable state in `/opt/cato` (i.e. `/var/opt/cato`) at first run.
The RPM enables `cato-client.service` and `cato-dem.service`, so the daemon is
running after a reboot and the client is used from your own desktop session,
where SSO can open a real browser:

```bash
cato-sdp start --account <subdomain>     # as your normal user, NOT root
cato-sdp status
cato-sdp stop
```

`cato-sdp update` cannot work — the client's self-update writes into
`/usr/lib/cato`. Version bumps come from rebuilding this image; the RPM URL is
a rolling "latest".

`/etc/systemd/resolved.conf` is materialised at boot by a tmpfiles rule in the
profile: the client aborts an established tunnel if it cannot read and rewrite
that file, and ostree ships only `/usr/lib/systemd/resolved.conf`.
