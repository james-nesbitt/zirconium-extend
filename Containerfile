# Extend the zirconium base image
FROM ghcr.io/zirconium-dev/zirconium:latest

RUN dnf -y --enablerepo copr:copr.fedorainfracloud.org:yalter:niri-git \
           --enablerepo copr:copr.fedorainfracloud.org:avengemedia:dms-git \
           --enablerepo copr:copr.fedorainfracloud.org:avengemedia:danklinux \
           upgrade -y

RUN dnf install --enablerepo=terra -y @virtualization

RUN dnf install --enablerepo=terra -y containerd ghostty nvim rootlesskit zsh

# Maintain labels
LABEL org.opencontainers.image.source="https://github.com/zirconium-dev/zirconium-extend"
LABEL org.opencontainers.image.description="Extended zirconium OCI image"


# OS Release File (changed in order with upstream)
# TODO: change ANSI_COLOR
RUN sed -i -f - /usr/lib/os-release <<EOF
s|^VERSION_CODENAME=.*|VERSION_CODENAME=\"jnesbitt\"|
EOF

RUN rm -rf /var/* && mkdir /var/tmp && bootc container lint
