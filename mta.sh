#!/bin/bash
set -Eeuo pipefail

cd /home/container

ACCELERATOR_URL="https://raw.githubusercontent.com/LoxyHosting/loxy-game-eggs/main/mta-accelerator.py"
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

    if ! command -v python3 >/dev/null 2>&1; then
        echo "[ERRO] python3 nao esta disponivel no runtime MTA."
        exit 1
    fi

    echo "[ACCELERATOR] Baixando servidor HTTP binario-seguro..."
    if curl -fLsS --retry 3 --retry-delay 2 \
        -o "./mta-accelerator.py.update" "${ACCELERATOR_URL}"; then
        if python3 -c 'import ast, pathlib, sys; ast.parse(pathlib.Path(sys.argv[1]).read_text())' \
            "./mta-accelerator.py.update"; then
            mv -f ./mta-accelerator.py.update ./mta-accelerator.py
        else
            echo "[ERRO] O arquivo baixado do accelerator nao passou na validacao Python."
            rm -f ./mta-accelerator.py.update
            exit 1
        fi
    else
        echo "[ERRO] Nao foi possivel baixar o accelerator de ${ACCELERATOR_URL}."
        rm -f ./mta-accelerator.py.update
        exit 1
    fi

    echo "[ACCELERATOR] Iniciando..."
    python3 ./mta-accelerator.py \
        --express "${EXPRESS_PORT}" \
        > ./accelerator.log \
        2> ./accelerator_error.log &
    ACCELERATOR_PID=$!

    echo "[ACCELERATOR] Aguardando listener HTTP em 127.0.0.1:${EXPRESS_PORT}..."
    ACCELERATOR_READY=false
    for _ in {1..30}; do
        if ! kill -0 "${ACCELERATOR_PID}" 2>/dev/null; then
            break
        fi

        HTTP_STATUS="$(curl -sS --connect-timeout 1 --max-time 2 \
            -o /dev/null -w '%{http_code}' \
            "http://127.0.0.1:${EXPRESS_PORT}/" 2>/dev/null || true)"
        if [[ "${HTTP_STATUS}" =~ ^[1-4][0-9][0-9]$ ]]; then
            ACCELERATOR_READY=true
            break
        fi
        sleep 1
    done

    if [[ "${ACCELERATOR_READY}" != true ]]; then
        echo "[ERRO] O accelerator nao abriu um listener HTTP funcional na porta ${EXPRESS_PORT}."
        echo "[ERRO] Verifique a porta, a allocation do servidor e os logs abaixo."
        if [[ -s ./accelerator.log ]]; then
            echo "----- accelerator.log -----"
            cat ./accelerator.log
        fi
        if [[ -s ./accelerator_error.log ]]; then
            echo "----- accelerator_error.log -----"
            cat ./accelerator_error.log
        fi
        kill "${ACCELERATOR_PID}" 2>/dev/null || true
        wait "${ACCELERATOR_PID}" 2>/dev/null || true
        exit 1
    fi

    echo "[ACCELERATOR] Listener HTTP pronto na porta ${EXPRESS_PORT}. Logs: accelerator.log / accelerator_error.log"
else
    echo "[ACCELERATOR] Desativado."
fi

echo "[MTA] Iniciando servidor sob supervisao direta do Pterodactyl..."

exec ./mta-server64 \
    --maxplayers "${MAX_PLAYERS:-10}" \
    --port "${SERVER_PORT}" \
    --httpport "${HTTP_PORT}" \
    -n
