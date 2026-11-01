#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-loxyhosting/samp-ubuntu24:latest}"

docker run --rm -i "${IMAGE_REF}" /bin/bash -s <<'CONTAINER'
set -euo pipefail
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cat >"$workdir/plugin.s" <<'ASM'
.section .text
.globl samp_plugin_fixture
samp_plugin_fixture:
  ret
ASM

as --32 -o "$workdir/plugin.o" "$workdir/plugin.s"
ld -m elf_i386 -shared --soname samp_plugin_fixture.so \
  -o "$workdir/samp_plugin_fixture.so" "$workdir/plugin.o"

for library in \
  libstdc++.so.6 \
  libmysqlclient.so.21 \
  libcurl.so.4 \
  libssl.so.3 \
  libsqlite3.so.0; do
  patchelf --add-needed "$library" "$workdir/samp_plugin_fixture.so"
done

file "$workdir/samp_plugin_fixture.so"
ldd "$workdir/samp_plugin_fixture.so"
ldd "$workdir/samp_plugin_fixture.so" | tee "$workdir/dependencies.txt"
if grep -q 'not found' "$workdir/dependencies.txt"; then
  echo "A plugin runtime dependency is missing." >&2
  exit 1
fi

echo "Synthetic 32-bit plugin ABI dependency resolution passed."
echo "No third-party SA-MP plugin binaries were included in this test."
CONTAINER

if [ -n "${PLUGIN_TEST_BINARY:-}" ]; then
  if [ ! -f "${PLUGIN_TEST_BINARY}" ]; then
    echo "Plugin test file does not exist: ${PLUGIN_TEST_BINARY}" >&2
    exit 1
  fi

  actual_plugin_output="$(
    docker run --rm \
      --volume "${PLUGIN_TEST_BINARY}:/tmp/plugin-test.so:ro" \
      "${IMAGE_REF}" \
      /bin/bash -lc '
        set -euo pipefail
        file /tmp/plugin-test.so
        dependencies="$(ldd /tmp/plugin-test.so)"
        printf "%s\n" "$dependencies"
        if grep -q "not found" <<<"$dependencies"; then
          exit 1
        fi
      '
  )"
  printf '%s\n' "${actual_plugin_output}"
  echo "Actual plugin dependency loading passed; plugin code was not executed."
fi
