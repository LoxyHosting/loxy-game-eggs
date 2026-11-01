#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-loxyhosting/samp-ubuntu24}"
TAG_REF="${TAG_REF:-latest}"

cd "$(dirname "$0")"

docker build --pull --platform linux/amd64 -t "${IMAGE_NAME}:${TAG_REF}" .

image_id="$(docker image inspect --format '{{.Id}}' "${IMAGE_NAME}:${TAG_REF}")"
for tag in latest ubuntu24 stable; do
  docker image tag "${IMAGE_NAME}:${TAG_REF}" "${IMAGE_NAME}:${tag}"
  tag_id="$(docker image inspect --format '{{.Id}}' "${IMAGE_NAME}:${tag}")"
  if [ "${tag_id}" != "${image_id}" ]; then
    echo "Tag ${IMAGE_NAME}:${tag} does not point to the built image." >&2
    exit 1
  fi
done

printf 'Built local image %s (%s) with tags: %s:latest, %s:ubuntu24, %s:stable\n' \
  "${IMAGE_NAME}:${TAG_REF}" "${image_id}" "${IMAGE_NAME}" "${IMAGE_NAME}" "${IMAGE_NAME}"
