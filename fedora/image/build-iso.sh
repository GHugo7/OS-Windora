#!/usr/bin/env bash
# Construit l'image puis un ISO d'installation (à lancer depuis Fedora, avec podman).
#   ./image/build-iso.sh            -> output/bootiso/install.iso
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE="${IMAGE:-localhost/fxw-os:latest}"
FEDORA_VERSION="${FEDORA_VERSION:-44}"

command -v podman >/dev/null || { echo "podman est nécessaire : sudo dnf install podman" >&2; exit 1; }

echo "==> Construction de l'image $IMAGE (Fedora $FEDORA_VERSION)"
sudo podman build --build-arg FEDORA_VERSION="$FEDORA_VERSION" -f image/Containerfile -t "$IMAGE" .

echo "==> Fabrication de l'ISO (10 à 30 minutes)"
mkdir -p output
sudo podman run --rm -it --privileged --pull=newer \
    --security-opt label=type:unconfined_t \
    -v "$PWD/image/iso.toml:/config.toml:ro" \
    -v "$PWD/output:/output" \
    -v /var/lib/containers/storage:/var/lib/containers/storage \
    quay.io/centos-bootc/bootc-image-builder:latest \
    --type anaconda-iso --rootfs btrfs "$IMAGE"

echo "==> ISO prête : $PWD/output/bootiso/install.iso"
echo "    Copiez-la sur une clé USB avec Fedora Media Writer ou : sudo dd if=... of=/dev/sdX bs=4M status=progress"
