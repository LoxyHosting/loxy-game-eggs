#!/bin/bash
set -Eeuo pipefail

cd /home/container

REPO="openmultiplayer/open.mp"
VERSION="${VERSION:-latest}"
REPAIR_DIR="/home/container/.loxy-openmp-repair"

cleanup() { rm -rf "${REPAIR_DIR}"; }
trap cleanup EXIT

echo "=================================================="
echo "            Open-MP - Loxy Systems v2.5"
echo " Runtime: ghcr.io/ptero-eggs/games:samp"
echo " Config: config.json"
echo "=================================================="

# Open-MP usa config.json como configuracao principal.
# server.cfg e legado e NAO e obrigatorio.

[[ -f ./omp-server ]] && chmod 755 ./omp-server
find ./plugins -maxdepth 1 -type f -name '*.so' -exec chmod 755 {} \; 2>/dev/null || true
find ./components -maxdepth 1 -type f -name '*.so' -exec chmod 755 {} \; 2>/dev/null || true

# Reparo automatico do binario sem usar /tmp.
if [[ ! -f ./omp-server ]]; then
    echo '[REPARO] omp-server nao encontrado. Tentando restaurar...'
    command -v curl >/dev/null 2>&1 || { echo '[ERRO] curl indisponivel.'; exit 127; }
    command -v tar >/dev/null 2>&1 || { echo '[ERRO] tar indisponivel.'; exit 127; }

    rm -rf "${REPAIR_DIR}"
    mkdir -p "${REPAIR_DIR}/extract"

    if [[ -z "${VERSION}" || "${VERSION}" == 'latest' ]]; then
        RELEASE_BASE="https://github.com/${REPO}/releases/latest/download"
    else
        RELEASE_BASE="https://github.com/${REPO}/releases/download/${VERSION}"
    fi

    DOWNLOAD_OK=0
    for ASSET in 'open.mp-linux-x86-dynssl.tar.gz' 'open.mp-linux-x86.tar.gz'; do
        echo "[REPARO] Tentando ${ASSET}..."
        if curl -fL --retry 4 --retry-delay 2 -o "${REPAIR_DIR}/openmp.tar.gz" "${RELEASE_BASE}/${ASSET}"; then
            DOWNLOAD_OK=1
            break
        fi
    done

    [[ "${DOWNLOAD_OK}" == '1' ]] || { echo '[ERRO] Nao foi possivel baixar o Open-MP.'; exit 127; }
    tar -xzf "${REPAIR_DIR}/openmp.tar.gz" -C "${REPAIR_DIR}/extract"
    OMP_BINARY="$(find "${REPAIR_DIR}/extract" -type f -name omp-server -print -quit || true)"
    [[ -n "${OMP_BINARY}" ]] || { echo '[ERRO] omp-server nao encontrado no pacote.'; exit 127; }
    cp -f "${OMP_BINARY}" ./omp-server
    chmod 755 ./omp-server
    echo '[REPARO] omp-server restaurado.'
fi

# Nunca verifica server.cfg.
# Se config.json estiver ausente, o Open-MP gera o padrao.
if [[ ! -f ./config.json ]]; then
    echo '[CONFIG] config.json ausente. Gerando configuracao padrao...'
    ./omp-server --default-config >/dev/null 2>&1 || true
fi

if command -v ldd >/dev/null 2>&1; then
    MISSING_LIBS="$(ldd ./omp-server 2>/dev/null | awk '/not found/ {print $1}' | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
    if [[ -n "${MISSING_LIBS}" ]]; then
        echo "[ERRO] Dependencias ausentes: ${MISSING_LIBS}"
        echo '[ERRO] Use a imagem: ghcr.io/ptero-eggs/games:samp'
        exit 127
    fi
    echo '[CHECK] Bibliotecas do omp-server: OK'
fi

echo '[CHECK] server.cfg e opcional.'
echo '[OpenMP] Iniciando omp-server...'
exec ./omp-server
