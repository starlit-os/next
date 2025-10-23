#!/usr/bin/env bash

set -xeuo pipefail

coprs=(
    ublue-os/packages
    ublue-os/staging
    bieszczaders/kernel-cachyos
)

repos=(
    "https://negativo17.org/repos/fedora-multimedia.repo"
)

dnf5 -y install "dnf5-command(copr)"
for copr in "${coprs[@]}"; do
    dnf5 -y copr enable "${copr}"
done

for repo in "${repos[@]}"; do
    dnf config-manager addrepo --from-repofile="${repo}"
done
