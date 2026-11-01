#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-loxyhosting/samp-ubuntu24}"
TAG_REF="${TAG_REF:-latest}"

cd "$(dirname "$0")"

docker build --pull --no-cache -t "${IMAGE_NAME}:${TAG_REF}" .

echo "Built ${IMAGE_NAME}:${TAG_REF}"
