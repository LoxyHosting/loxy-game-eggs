#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-loxyhosting/samp-ubuntu24:latest}"
udp_container=""
signal_container=""

cleanup() {
  if [ -n "${udp_container}" ]; then
    docker stop "${udp_container}" >/dev/null 2>&1 || true
  fi
  if [ -n "${signal_container}" ]; then
    docker stop --time 5 "${signal_container}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

runtime_output="$(
  docker run --rm \
    --env STARTUP_TEST=from-pterodactyl \
    "${IMAGE_REF}" \
    /bin/bash -c '
      test "$PWD" = /home/container
      test "$PTERODACTYL_CONTAINER" = 1
      test "$(id -u)" -ne 0
      printf "%s\n" "$STARTUP_TEST"
      touch /home/container/.pterodactyl-write-test
      test -f /home/container/.pterodactyl-write-test
      rm /home/container/.pterodactyl-write-test
      echo "pterodactyl runtime checks passed"
    '
)"
printf '%s\n' "${runtime_output}"
grep -qx from-pterodactyl <<<"${runtime_output}"
grep -qx 'pterodactyl runtime checks passed' <<<"${runtime_output}"

udp_container="$(docker run -d \
  -p 127.0.0.1::7777/udp \
  "${IMAGE_REF}" \
  nc -ul 7777)"
host_port="$(docker port "${udp_container}" 7777/udp | awk -F: 'END {print $NF}')"
if [ -z "${host_port}" ]; then
  echo "Docker did not publish the UDP test port." >&2
  exit 1
fi

for _ in $(seq 1 30); do
  if docker exec "${udp_container}" pgrep -x nc >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done

for _ in $(seq 1 10); do
  printf 'loxy-samp-udp-test\n' >"/dev/udp/127.0.0.1/${host_port}"
  sleep 0.1
  if docker logs "${udp_container}" 2>&1 | grep -q 'loxy-samp-udp-test'; then
    break
  fi
done

if ! docker logs "${udp_container}" 2>&1 | grep -q 'loxy-samp-udp-test'; then
  echo "UDP packet did not reach the container." >&2
  exit 1
fi
echo "UDP port publishing and packet delivery passed."
docker stop "${udp_container}" >/dev/null
udp_container=""

signal_container="$(docker run -d --rm "${IMAGE_REF}" /bin/bash -c \
  'trap "exit 0" TERM; while :; do sleep 1 & wait $!; done')"
docker stop --time 5 "${signal_container}" >/dev/null
signal_container=""
echo "SIGTERM shutdown passed."
