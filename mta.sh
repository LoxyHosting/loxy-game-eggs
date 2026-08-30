#!/bin/bash
set -Eeuo pipefail

cd /home/container

ACCELERATOR_URL="https://raw.githubusercontent.com/drysius/Eggs/main/Connect/MTA/Accelerator-Application/build/mta-accelerator"
CONFIG_FILE="./mods/deathmatch/mtaserver.conf"

echo "=================================================="
echo "             MTA - Loxy Systems v2"
echo " Runtime: ghcr.io/ptero-eggs/games:mta"
echo " Startup remoto: mta.sh"
echo "=================================================="

if [[ ! -f "./mta-server64" ]]; then
    echo "[ERRO] mta-server64 nao encontrado."
    echo "[ERRO] Execute Reinstall no Pterodactyl para restaurar os arquivos base."
    exit 127
fi

chmod 755 ./mta-server64

# Ajusta somente o arquivo oficial de configuracao do MTA.
if [[ -f "${CONFIG_FILE}" && -n "${SERVER_NAME:-}" ]]; then
    if grep -q '<servername>.*</servername>' "${CONFIG_FILE}"; then
        # Escapa caracteres que poderiam quebrar a substituicao.
        SAFE_NAME="$(printf '%s' "${SERVER_NAME}" | sed 's/[&|]/\\&/g')"
        sed -i -E "s|<servername>.*</servername>|<servername>${SAFE_NAME}</servername>|" "${CONFIG_FILE}"
        echo "[CONFIG] Nome do servidor atualizado."
    else
        echo "[AVISO] Tag <servername> nao encontrada em mtaserver.conf."
    fi
fi

# Acelerador opcional.
# So inicia quando EXPRESS_PORT for uma porta valida.
if [[ "${EXPRESS_PORT:-}" =~ ^[0-9]+$ ]] \
    && (( EXPRESS_PORT >= 1 && EXPRESS_PORT <= 65535 )); then

    echo "[ACCELERATOR] Porta configurada: ${EXPRESS_PORT}"

    if [[ -f "./mta-accelerator-update" ]]; then
        echo "[ACCELERATOR] Atualizacao encontrada. Aplicando..."
        rm -f ./mta-accelerator
        mv ./mta-accelerator-update ./mta-accelerator
    fi

    if [[ ! -s "./mta-accelerator" ]]; then
        echo "[ACCELERATOR] Binario ausente. Baixando..."
        if curl -fL --retry 3 --retry-delay 2 \
            -o "./mta-accelerator" "${ACCELERATOR_URL}"; then
            chmod 755 ./mta-accelerator
        else
            echo "[AVISO] Nao foi possivel baixar o acelerador."
            rm -f ./mta-accelerator
        fi
    fi

    if [[ -s "./mta-accelerator" ]]; then
        chmod 755 ./mta-accelerator
        echo "[ACCELERATOR] Iniciando..."
        ./mta-accelerator \
            --trace-warnings true \
            --express "${EXPRESS_PORT}" \
            > ./accelerator.log \
            2> ./accelerator_error.log &
        echo "[ACCELERATOR] Iniciado. Logs: accelerator.log / accelerator_error.log"
    fi
else
    echo "[ACCELERATOR] Desativado."
fi

echo "[MTA] Iniciando servidor sob supervisao direta do Pterodactyl..."

exec ./mta-server64 \
    --maxplayers "${MAX_PLAYERS:-10}" \
    --port "${SERVER_PORT}" \
    --httpport "${HTTP_PORT}" \
    -n
