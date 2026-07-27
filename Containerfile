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

