#!/bin/bash
set -Eeuo pipefail

cd /home/container

REPO="openmultiplayer/open.mp"
VERSION="${VERSION:-latest}"

echo "=================================================="
echo "            Open-MP - Loxy Systems"
echo " Runtime: ghcr.io/ptero-eggs/games:samp"
echo " Startup remoto: openmp.sh"
echo "=================================================="

# Corrige apenas permissões seguras dos arquivos existentes.
if [[ -f "./omp-server" ]]; then
    chmod 755 ./omp-server
fi

find ./plugins -maxdepth 1 -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null || true
find ./components -maxdepth 1 -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null || true

# Se o binário principal foi apagado, tenta restaurá-lo automaticamente.
if [[ ! -f "./omp-server" ]]; then
    echo "[REPARO] omp-server nao encontrado. Tentando restaurar..."

    if ! command -v curl >/dev/null 2>&1 || ! command -v tar >/dev/null 2>&1; then
        echo "[ERRO] curl/tar nao estao disponiveis no container."
        echo "[ERRO] Execute Reinstall no Pterodactyl para restaurar o OpenMP."
        exit 127
    fi

    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR}"' EXIT

    if [[ -z "${VERSION}" || "${VERSION}" == "latest" ]]; then
        BASE_RELEASE_URL="https://github.com/${REPO}/releases/latest/download"
    else
        BASE_RELEASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
    fi

    DOWNLOAD_OK=0

    for ASSET in \
        "open.mp-linux-x86-dynssl.tar.gz" \
        "open.mp-linux-x86.tar.gz"
    do
        echo "[REPARO] Tentando ${ASSET}..."

        if curl -fL --retry 4 --retry-delay 2 \
            -o "${TMP_DIR}/openmp.tar.gz" \
            "${BASE_RELEASE_URL}/${ASSET}"; then
            DOWNLOAD_OK=1
            break
        fi
    done

    if [[ "${DOWNLOAD_OK}" != "1" ]]; then
        echo "[ERRO] Nao foi possivel baixar o binario OpenMP."
        echo "[ERRO] Execute Reinstall no Pterodactyl."
        exit 127
    fi

    mkdir -p "${TMP_DIR}/extract"
    tar -xzf "${TMP_DIR}/openmp.tar.gz" -C "${TMP_DIR}/extract"

    OMP_BINARY="$(find "${TMP_DIR}/extract" -type f -name omp-server -print -quit || true)"

    if [[ -z "${OMP_BINARY}" ]]; then
        echo "[ERRO] O pacote baixado nao contem omp-server."
        exit 127
    fi

    cp -f "${OMP_BINARY}" ./omp-server
    chmod 755 ./omp-server

    echo "[REPARO] omp-server restaurado com sucesso."
fi

if [[ ! -f "./server.cfg" ]]; then
    echo "[ERRO] server.cfg nao encontrado."
    echo "[ERRO] O arquivo de configuracao do servidor precisa ser restaurado."
    exit 1
fi

# Diagnóstico de bibliotecas antes de iniciar.
if command -v ldd >/dev/null 2>&1; then
    MISSING_LIBS="$(ldd ./omp-server 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"

    if [[ -n "${MISSING_LIBS}" ]]; then
        echo "[ERRO] Dependencias do omp-server ausentes:"
        echo "[ERRO] ${MISSING_LIBS}"
        echo "[ERRO] A Egg deve usar a imagem: ghcr.io/ptero-eggs/games:samp"
        echo "[ERRO] Nao copie bibliotecas .so manualmente para o servidor."
        exit 127
    fi

    echo "[CHECK] Bibliotecas do omp-server: OK"
fi

echo "[OpenMP] Executing Server Config..."
echo "[OpenMP] Iniciando omp-server sob supervisao direta do Pterodactyl..."

exec ./omp-server
