# SA-MP Ubuntu 24.04 image

Local Docker image for SA-MP servers and 32-bit/64-bit Linux plugins on Ubuntu
24.04 LTS. The build targets `linux/amd64`, enables the `i386` package
architecture, and runs as the unprivileged `container` user.

The image is built and stored in the local Docker Engine. The build and test
scripts do not log in to or push to Docker Hub or any other registry.

## Files

```text
docker-images/samp-ubuntu24/
├── Dockerfile
├── README.md
├── .dockerignore
├── build.sh
├── test.sh
├── scripts/
│   ├── install-dependencies.sh
│   ├── compatibility-check.sh
│   └── entrypoint.sh
└── tests/
    ├── test-architecture.sh
    ├── test-libraries.sh
    ├── test-plugins.sh
    └── test-pterodactyl.sh
```

## Runtime libraries

The image installs the available Ubuntu 24.04 runtime packages for both
`amd64` and `i386`, including:

- `libc6`, `libstdc++6`, `libgcc-s1`, `zlib1g`, and `libatomic1`
- `libcurl4t64`, `libssl3t64`, `libnghttp2-14`, `libidn2-0`, `libpsl5`,
  `libssh2-1t64`, and `librtmp1`
- `libmariadb3` (amd64), `libmysqlclient21` (amd64 and i386), and
  `libsqlite3-0`
- `libgomp1`, `libexpat1`, `libtinfo6`, `libncurses6`, and `libuuid1`
- `libaio1t64`, `libdb5.3t64`, `libbz2-1.0`, `libfreetype6`, and `libudev1`
- `lib32gcc-s1`, `lib32stdc++6`, and `lib32z1`

Diagnostic tools include `file`, `binutils`, `patchelf`, `procps`, `curl`,
`wget`, `unzip`, `tar`, `xz-utils`, `iproute2`, `net-tools`, `dnsutils`,
`lsof`, `psmisc`, and `netcat-openbsd`.

### Legacy package limitations

Ubuntu 24.04 Noble does not provide these packages in its standard
repositories:

- `libssl1.1` (replaced by `libssl3`)
- `libgcc1` (replaced by `libgcc-s1`)
- `libmysqlclient18` (the image provides `libmysqlclient21`)
- `libtinfo5` and `libncurses5` (the image provides `libtinfo6` and
  `libncurses6`)

The image does not mix repositories from other Ubuntu releases, replace
essential libraries, or create compatibility symlinks. A plugin that requires
one of these exact legacy ABIs must supply a compatible private library in
`/opt/loxy-compat/lib` or `/opt/loxy-compat/lib32`; this directory is included in
the dynamic loader search path. Do not copy untrusted libraries into a running
server.

The Noble repository does not publish `libmariadb3:i386`; its i386 MySQL
client runtime is provided by `libmysqlclient21:i386` instead.

The image does not bundle SA-MP plugins. Its plugin check creates a synthetic
32-bit shared object to exercise dependency resolution for common C/C++,
MySQL, curl, OpenSSL, and SQLite ABIs. It is not a substitute for testing the
specific plugin binaries used by a server. No third-party plugin binary is
downloaded or redistributed by these scripts.

## Build locally

```bash
cd /opt/loxy-docker/samp-ubuntu24
./build.sh
```

The script builds for `linux/amd64` and tags the same local image as:

- `loxyhosting/samp-ubuntu24:latest`
- `loxyhosting/samp-ubuntu24:ubuntu24`
- `loxyhosting/samp-ubuntu24:stable`

To select another build tag:

```bash
TAG_REF=latest ./build.sh
```

There is deliberately no `docker push` command.

## Test

Run after building:

```bash
./test.sh
```

The suite executes real ELF32 and ELF64 binaries, resolves installed
dependencies, checks a synthetic 32-bit plugin ABI, and tests non-root startup,
environment variables, writable container storage, UDP packet delivery, and
SIGTERM shutdown. To check a real plugin's architecture and dynamic
dependencies without running plugin code, set
`PLUGIN_TEST_BINARY=/path/to/plugin.so ./test.sh`. This checks dependencies
with `ldd`; it does not load the plugin into a SA-MP server.

## Pterodactyl/Wings

- Working directory: `/home/container`
- Default image user: `container` (non-root); root execution is rejected
- The entrypoint uses `exec` to forward the Wings startup command and signals
- Environment variables are inherited, including the `STARTUP` variable
- UDP ports 7777, 7778, and 30120 are declared; publish/configure the actual
  server port in the egg/allocation as usual
- No systemd or extra daemon is started

Use `loxyhosting/samp-ubuntu24:latest` (or either of the other local tags) in
the egg's Docker image field. The egg and Wings configuration are not modified
by this project.

## Save or load a local backup

```bash
mkdir -p /opt/loxy-docker/backups
docker save -o /opt/loxy-docker/backups/samp-ubuntu24.tar \
  loxyhosting/samp-ubuntu24:latest
docker load -i /opt/loxy-docker/backups/samp-ubuntu24.tar
```

Keep the backup outside this source tree; image archives must not be committed
to Git.
