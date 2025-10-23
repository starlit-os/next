#!/usr/bin/env bash

set -xeuo pipefail

dnf5 -y swap --repo='fedora' \
    OpenCL-ICD-Loader ocl-icd

dnf5 -y install \
    ublue-os-luks \
    ublue-os-udev-rules \
    zstd
