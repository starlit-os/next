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
variable "coprs"                {
    type = list(string)
    default = ["ublue-os/packages","ublue-os/staging","bieszczaders/kernel-cachyos"]
}
variable "extra_repos"          {
    type = list(string)
    default = ["https://negativo17.org/repos/fedora-multimedia.repo"]
}
variable "kernel_target"        {
    type = string
    default = "kernel-cachyos"
}
variable "extra_packages"       {
    type = list(string)
    default = [
        "plymouth",
	    "plymouth-system-theme",
	    "systemd-container",
	    "libcamera{,-{v4l2,gstreamer,tools}}",
        "ublue-os-luks",
        "ublue-os-udev-rules",
        "fish",
        "btrfs-progs",
	    "buildah",
	    "fzf",
    	"glow",
    	"gum",
	    "tuned-ppd",
	    "wireguard-tools",
	    "wl-clipboard",
    	"uupd"
    ]
}
variable "package_groups"       {
    type = list(string)
    default = [
        "cosmic-desktop"
    ]
}
variable "build_ref"            {
    type = string
    default = "dev"
}

locals {
  extra_packages_joined = join(" ", var.extra_packages)
  package_groups_joined = join(" ", var.package_groups)
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

  provisioner "shell" {
    inline = concat(
      [
        "set -xeuo pipefail",
        "echo '==> Starting customization (build_ref=${var.build_ref})'",
        "dnf5 -y install \"dnf5-command(copr)\"",
        "mkdir /var/roothome",
        "echo '==> Enabling Copr repos'"
      ],
      [for c in var.coprs : "dnf5 -y copr enable ${c}"],
      [
        "echo '==> Adding external repo files'"
      ],
      [for r in var.extra_repos : "dnf config-manager addrepo --from-repofile='${r}'"],
      [
        "echo '==> Swapping OpenCL ICD Loader -> ocl-icd'",
        "dnf -y swap --repo=fedora OpenCL-ICD-Loader ocl-icd",

        # Packages
        "echo '==> Installing packages: ${local.extra_packages_joined}'",
        "dnf -y install ${local.extra_packages_joined}",
        "dnf -y group install ${local.package_groups_joined}",

        "echo '==> Kernel swap to ${var.kernel_target}'",
        "dnf -y swap kernel\\* ${var.kernel_target}",

        "echo '==> Build complete.'"
      ]
    )
  }

  post-processor "docker-tag" {
    repository = "local/starlit-os-next"
    tags       = [var.image_tag, var.build_ref]
  }
}
