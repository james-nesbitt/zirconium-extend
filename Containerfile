# Extend the zirconium base image
FROM ghcr.io/zirconium-dev/zirconium:latest

# Write terra.repo explicitly so the build is independent of base image state.
# gpgcheck=0: the terra GPG key file is absent in the CI base image and no
# reliable HTTP URL exists to fetch it; packages are pulled over HTTPS from
# the signed metalink. repo_gpgcheck=0: suppresses the interactive key-import
# prompt that dnf5 would otherwise show in a non-TTY buildah context.
RUN printf '[terra]\nname=Terra %s\nmetalink=https://tetsudou.fyralabs.com/metalink?repo=terra%s&arch=$basearch\nenabled=1\ngpgcheck=0\nrepo_gpgcheck=0\ncountme=1\n' \
    "$(rpm -E %fedora)" "$(rpm -E %fedora)" > /etc/yum.repos.d/terra.repo \
 && dnf install -y containerd cliphist ghostty nvim rootlesskit zsh alacritty \
 && dnf clean all

RUN dnf install -y @virtualization \
 && dnf clean all

# Install wezterm from upstream COPR (not available in terra)
RUN curl -fsSL https://copr.fedorainfracloud.org/coprs/wezfurlong/wezterm-nightly/repo/fedora-$(rpm -E %fedora)/wezfurlong-wezterm-nightly-fedora-$(rpm -E %fedora).repo \
    -o /etc/yum.repos.d/wezterm-nightly.repo \
 && dnf install -y wezterm \
 && dnf clean all

# Dux Files (dfiles) — the standalone file manager released alongside DMS 2.0.
# Not in the zirconium base nor terra; it is built in the duxlabs/dux-repo COPR
# (dux-files-2.0.0-1, chroot fedora-45-x86_64). Only dux-files is named: that COPR
# also carries quickshell, and the base image's quickshell already satisfies the
# dependency, so nothing is swapped out from under DMS.
# ffmpegthumbnailer is the one optional helper the dfiles daemon probes on PATH that
# the base lacks (video thumbnails); poppler-utils, gvfs, udisks2 and bubblewrap are
# already in the base image, so PDF thumbnails, devices, network shares and sandboxed
# thumbnailers work without further packages.
RUN curl -fsSL https://copr.fedorainfracloud.org/coprs/duxlabs/dux-repo/repo/fedora-$(rpm -E %fedora)/duxlabs-dux-repo-fedora-$(rpm -E %fedora).repo \
    -o /etc/yum.repos.d/duxlabs-dux-repo.repo \
 && dnf install -y dux-files ffmpegthumbnailer \
 && dnf clean all \
 && test -x /usr/bin/dfiles

# Cato Networks SDP client (VPN). Verified /usr-only payload (rpm -ql cato_client-5.8.1-7658):
# /usr/lib/cato, /usr/bin/cato-sdp, /usr/sbin/{cato-clientd,cato-demd}, /etc/ld.so.conf.d and a
# CA anchor — nothing in /opt, so no relocation is needed on an ostree root where /opt is a
# symlink into the (image-discarded) /var. The daemon creates /opt/cato -> /var/opt/cato itself
# at first run, which is where mutable client state belongs on bootc.
# The RPM's %post enables cato-client.service and cato-dem.service via multi-user.target.wants.
# CATO_RPM_SHA256 pins the rolling "latest" artifact for reproducible builds; empty = unpinned.
ARG CATO_RPM_URL=https://clientdownload.catonetworks.com/public/clients/cato-client-install.rpm
ARG CATO_RPM_SHA256=
RUN curl -fsSL --proto '=https' --tlsv1.2 -o /tmp/cato-client-install.rpm "$CATO_RPM_URL" \
 && { [ -z "$CATO_RPM_SHA256" ] || echo "${CATO_RPM_SHA256}  /tmp/cato-client-install.rpm" | sha256sum -c -; } \
 && dnf install -y /tmp/cato-client-install.rpm \
 && rm -f /tmp/cato-client-install.rpm \
 && dnf clean all \
 && test -x /usr/sbin/cato-clientd \
 && test -x /usr/bin/cato-sdp

# cato-clientd with --use-systemd-resolv 1 reads, backs up and rewrites /etc/systemd/resolved.conf.
# Fedora ships only /usr/lib/systemd/resolved.conf and ostree materialises no /etc copy, so the
# client aborts an already-established tunnel:
#   [E] backup_dns_config:303   Failed to read /etc/systemd/resolved.conf
#   [E] cato_setup_dns_config:811  error backing up dns servers
#   [E] utAuthenticatedUpdateNetworkParamet:636  Failed to DNS  -> STOP, ERR_USER_INTERRUPTED
# The shipped file is entirely commented defaults, so materialising it in /etc changes no
# resolver behaviour; it only gives the client a file to edit.
RUN [ -e /etc/systemd/resolved.conf ] \
 || cp -a /usr/lib/systemd/resolved.conf /etc/systemd/resolved.conf

# Maintain labels
LABEL org.opencontainers.image.source="https://github.com/zirconium-dev/zirconium-extend"
LABEL org.opencontainers.image.description="Extended zirconium OCI image"

# OS Release File (changed in order with upstream)
RUN sed -i 's|^VERSION_CODENAME=.*|VERSION_CODENAME="jnesbitt"|' /usr/lib/os-release

# rebuild of initramfs might be needed if we upgraded the kernel
RUN KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"; \
    export DRACUT_NO_XATTR=1; \
    dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"; \
    chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

RUN rm -rf /var/* && mkdir /var/tmp && bootc container lint

