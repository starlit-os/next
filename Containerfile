FROM quay.io/fedora/fedora-bootc:43

RUN --mount=type=bind,source=./build_files/,target=/ctx \
    . /ctx/01-repos.sh

RUN --mount=type=bind,source=./build_files/,target=/ctx \
    . /ctx/02-kernel.sh

RUN --mount=type=bind,source=./build_files/,target=/ctx \
    . /ctx/build.sh
