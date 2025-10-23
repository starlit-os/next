#!/usr/bin/env bash

set -xeuo pipefail

# Workaround to initramfs hooks during kernel installation from ublue-os/main
cd /usr/lib/kernel/install.d \
    && mv 05-rpmostree.install 05-rpmostree.install.bak \
    && mv 50-dracut.install 50-dracut.install.bak \
    && printf '%s\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install \
    && printf '%s\n' '#!/bin/sh' 'exit 0' > 50-dracut.install \
    && chmod +x  05-rpmostree.install 50-dracut.install

# Install CachyOS kernel
dnf5 -y swap kernel* kernel-cachyos

# Restore install hooks
cd /usr/lib/kernel/install.d && \
mv -f 05-rpmostree.install.bak 05-rpmostree.install \
&& mv -f 50-dracut.install.bak 50-dracut.install && \
cd -
