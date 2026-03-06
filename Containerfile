# Extend the zirconium base image
FROM ghcr.io/zirconium-dev/zirconium:latest

RUN dnf -y --enablerepo copr:copr.fedorainfracloud.org:yalter:niri-git \
           --enablerepo copr:copr.fedorainfracloud.org:avengemedia:dms-git \
           --enablerepo copr:copr.fedorainfracloud.org:avengemedia:danklinux \
           upgrade -y \
 && dnf -y --enablerepo copr:copr.fedorainfracloud.org:yalter:niri-git \
           --enablerepo copr:copr.fedorainfracloud.org:avengemedia:dms-git \
           --enablerepo copr:copr.fedorainfracloud.org:avengemedia:danklinux \
           clean -y all

RUN dnf --enablerepo=terra install -y @virtualization \
 && dnf --enablerepo=terra clean -y all

RUN dnf --enablerepo=terra install -y containerd cliphist ghostty nvim rootlesskit zsh alacritty \
 && dnf --enablerepo=terra clean -y all

# Maintain labels
LABEL org.opencontainers.image.source="https://github.com/zirconium-dev/zirconium-extend"
LABEL org.opencontainers.image.description="Extended zirconium OCI image"

# OS Release File (changed in order with upstream)
# TODO: change ANSI_COLOR
RUN sed -i -f - /usr/lib/os-release <<EOF
s|^VERSION_CODENAME=.*|VERSION_CODENAME=\"jnesbitt\"|
EOF

# rebuild of initramfs might be needed if we upgraded the kernel
RUN KERNEL_VERSION="$(find "/usr/lib/modules" -maxdepth 1 -type d ! -path "/usr/lib/modules" -exec basename '{}' ';' | sort | tail -n 1)"; \
    export DRACUT_NO_XATTR=1; \
    dracut --no-hostonly --kver "$KERNEL_VERSION" --reproducible --zstd -v --add ostree -f "/usr/lib/modules/$KERNEL_VERSION/initramfs.img"; \
    chmod 0600 "/usr/lib/modules/${KERNEL_VERSION}/initramfs.img"

RUN rm -rf /var/* && mkdir /var/tmp && bootc container lint
