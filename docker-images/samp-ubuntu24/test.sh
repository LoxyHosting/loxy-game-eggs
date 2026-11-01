#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME="${IMAGE_NAME:-loxyhosting/samp-ubuntu24}"
TAG_REF="${TAG_REF:-latest}"

cd "$(dirname "$0")"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to run these compatibility checks." >&2
  exit 1
fi

docker build -t "${IMAGE_NAME}:${TAG_REF}" .

docker run --rm --entrypoint /bin/bash "${IMAGE_NAME}:${TAG_REF}" -lc "ldconfig -p | grep -E 'libstdc\+\+|libcurl|libssl|libmysql|libsqlite|zlib|libmariadb' && echo 'ldconfig checks passed'"

echo "Image build and basic runtime checks completed for ${IMAGE_NAME}:${TAG_REF}."
