#!/usr/bin/env bash
set -euo pipefail

IMAGE_REF="${IMAGE_REF:-loxyhosting/samp-ubuntu24:latest}"

docker run --rm -i "${IMAGE_REF}" /bin/bash -s <<'CONTAINER'
set -euo pipefail
workdir="$(mktemp -d)"
trap 'rm -rf "$workdir"' EXIT

cat >"$workdir/exit32.s" <<'ASM'
.section .text
.globl _start
_start:
  mov $1, %eax
  xor %ebx, %ebx
  int $0x80
ASM

cat >"$workdir/exit64.s" <<'ASM'
.section .text
.globl _start
_start:
  mov $60, %rax
  xor %rdi, %rdi
  syscall
ASM

as --32 -o "$workdir/exit32.o" "$workdir/exit32.s"
ld -m elf_i386 -dynamic-linker /lib/ld-linux.so.2 \
  -e _start -o "$workdir/exit32" "$workdir/exit32.o" \
  /lib/i386-linux-gnu/libc.so.6

as --64 -o "$workdir/exit64.o" "$workdir/exit64.s"
ld -m elf_x86_64 -dynamic-linker /lib64/ld-linux-x86-64.so.2 \
  -e _start -o "$workdir/exit64" "$workdir/exit64.o" \
  /lib/x86_64-linux-gnu/libc.so.6

file "$workdir/exit32" "$workdir/exit64"
ldd "$workdir/exit32"
ldd "$workdir/exit64"
! ldd "$workdir/exit32" "$workdir/exit64" 2>&1 | grep -q 'not found'
"$workdir/exit32"
"$workdir/exit64"
echo "ELF32 and ELF64 execution and libc loading passed."
CONTAINER
