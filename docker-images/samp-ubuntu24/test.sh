#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-loxyhosting/samp-ubuntu24}"
TAG_REF="${TAG_REF:-latest}"
IMAGE_REF="${IMAGE_NAME}:${TAG_REF}"

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run these compatibility checks." >&2
  exit 1
fi

docker image inspect "${IMAGE_REF}" >/dev/null

for test_script in \
  tests/test-architecture.sh \
  tests/test-libraries.sh \
  tests/test-plugins.sh \
  tests/test-pterodactyl.sh; do
  echo "=== ${test_script} ==="
  IMAGE_REF="${IMAGE_REF}" bash "${test_script}"
done

printf '\nAll image checks passed for %s.\n' "${IMAGE_REF}"
