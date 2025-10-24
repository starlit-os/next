# Packer template: single provisioner, unconditional kernel & OpenCL swaps.
packer {
  required_plugins {
    docker = {
      source  = "github.com/hashicorp/docker"
      version = ">= 1.0.0"
    }
  }
}


variable "image_tag"            {
    type = string
    default = "latest"
}
variable "base_image"           {
    type = string
    default = "quay.io/fedora/fedora-bootc:43"
}
variable "list_files" {
  type = list(string)
  default = [
    "coprs",
    "packages",
    "package_groups",
    "repos"
  ]
}
variable "build_ref"            {
    type = string
    default = "dev"
}
variable "kernel_target"            {
    type = string
    default = ""
}
locals {
  parsed_lists = {
    for name in var.list_files :
    name => [
      for line in split("\n", trimspace(file("build_files/${name}.txt"))) :
      trimspace(line)
      if trimspace(line) != "" && !startswith(trimspace(line), "#")
    ]
  }

  coprs = local.parsed_lists["coprs"]
  packages = join(" ", local.parsed_lists["packages"])
  package_groups = join(" ", local.parsed_lists["package_groups"])
  repos = local.parsed_lists["repos"]
}

source "docker" "fedora-bootc" {
  image       = var.base_image
  commit      = true
  pull        = true
  run_command = ["-d","-i","-t","{{.Image}}","/bin/bash"]
}

build {
  name    = "starlit-os-next"
  sources = ["source.docker.fedora-bootc"]

  provisioner "file" {
    source      = "system_files/"
    destination = "/"
  }

  provisioner "shell" {
    inline = concat(
      [
        "set -xeuo pipefail",
        "echo '==> Starting customization (build_ref=${var.build_ref})'",
        "dnf5 -y install \"dnf5-command(copr)\"",
        "mkdir /var/roothome",
        "echo '==> Enabling Copr repos'"
      ],
      [for c in local.coprs : "dnf5 -y copr enable ${c}"],
      ["echo '==> Adding external repo files'"],
      [for r in local.repos : "dnf config-manager addrepo --from-repofile='${r}'"],
      [
        # Packages
        "echo '==> Installing packages'",
        "dnf -y swap --repo=fedora OpenCL-ICD-Loader ocl-icd",
        "dnf -y install ${local.packages}",
        "dnf -y group install ${local.package_groups}"
      ],
      # Optional kernel swap
      var.kernel_target != "" ? [
        # Kernel swap
        "echo '==> Kernel swap to ${var.kernel_target}'",
        "pushd /usr/lib/kernel/install.d >/dev/null",
        "mv 05-rpmostree.install 05-rpmostree.install.bak",
        "mv 50-dracut.install 50-dracut.install.bak",
        "printf '%s\\n' '#!/bin/sh' 'exit 0' > 05-rpmostree.install",
        "printf '%s\\n' '#!/bin/sh' 'exit 0' > 50-dracut.install",
        "chmod +x 05-rpmostree.install 50-dracut.install",
        "trap 'echo Restoring kernel hooks; mv -f 05-rpmostree.install.bak 05-rpmostree.install; mv -f 50-dracut.install.bak 50-dracut.install; popd >/dev/null' EXIT",
        "dnf -y swap kernel\\* ${var.kernel_target}",
        "KERNEL_SUFFIX=\"\"",
        "QUALIFIED_KERNEL=\"$(rpm -qa | grep -P 'kernel-(|'\"$KERNEL_SUFFIX\"'-)(\\d+\\.\\d+\\.\\d+)' | sed -E 's/kernel-(|'\"$KERNEL_SUFFIX\"'-)//' | tail -n 1)\"",
        "/usr/bin/dracut --no-hostonly --kver \"$QUALIFIED_KERNEL\" --reproducible --zstd -v --add ostree -f \"/lib/modules/$QUALIFIED_KERNEL/initramfs.img\"",
      ] : [],
      ["bootc container lint"]
    )
  }

  post-processor "docker-tag" {
    repository = "local/starlit-os-next"
    tags       = [var.image_tag, var.build_ref]
  }
}
