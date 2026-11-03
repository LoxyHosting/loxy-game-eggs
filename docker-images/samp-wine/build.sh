#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${IMAGE_NAME:-loxyhosting/samp-wine}"
TAG_REF="${TAG_REF:-latest}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

docker build -t "${IMAGE_NAME}:${TAG_REF}" -f "${SCRIPT_DIR}/Dockerfile" "${SCRIPT_DIR}/../.."

echo "Imagem pronta: ${IMAGE_NAME}:${TAG_REF}"
