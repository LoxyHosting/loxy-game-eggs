#!/bin/bash
set -Eeuo pipefail

cd /home/container

VOICE_URL="https://github.com/drysius/Eggs/releases/latest/download/sampvoice.so"

echo "=================================================="
echo "          SA-MP Connect - Loxy v2.1"
echo " Runtime: ghcr.io/ptero-eggs/games:samp"
echo "=================================================="

if [[ ! -f "./samp03svr" ]]; then
    echo "[ERRO] samp03svr nao encontrado."
    echo "[ERRO] Execute Reinstall no Pterodactyl para restaurar os arquivos base."
    exit 127
fi

if [[ ! -f "./server.cfg" ]]; then
    echo "[ERRO] server.cfg nao encontrado."
    exit 1
fi

chmod 755 ./samp03svr
[[ -f "./samp-npc" ]] && chmod 755 ./samp-npc
[[ -f "./announce" ]] && chmod 755 ./announce

mkdir -p ./plugins
find ./plugins -maxdepth 1 -type f -name "*.so" -exec chmod 755 {} \; 2>/dev/null || true

if [[ "${SAMP_VOIP:-0}" == "1" ]]; then
    echo "[VOICE] SA-MP Voice habilitado."

    if [[ ! -s "./plugins/sampvoice.so" ]]; then
        echo "[VOICE] sampvoice.so ausente. Baixando..."
        if curl -fL --retry 3 --retry-delay 2 \
            -o "./plugins/sampvoice.so" "${VOICE_URL}"; then
            chmod 755 "./plugins/sampvoice.so"
        else
            echo "[AVISO] Nao foi possivel baixar sampvoice.so."
            rm -f "./plugins/sampvoice.so"
        fi
    fi

    if [[ -s "./plugins/sampvoice.so" ]]; then
        if grep -Eq '^[[:space:]]*plugins([[:space:]]|$)' ./server.cfg; then
            if ! awk '
                /^[[:space:]]*plugins([[:space:]]|$)/ {
                    for (i=2; i<=NF; i++) {
                        if ($i=="sampvoice" || $i=="sampvoice.so") found=1
                    }
                }
                END { exit(found ? 0 : 1) }
            ' ./server.cfg; then
                awk '
                    BEGIN { done=0 }
                    /^[[:space:]]*plugins([[:space:]]|$)/ && done==0 {
                        print $0 " sampvoice.so"
                        done=1
                        next
                    }
                    { print }
                ' ./server.cfg > ./server.cfg.loxy.tmp
                mv ./server.cfg.loxy.tmp ./server.cfg
                touch ./.loxy-sampvoice-managed
                echo "[VOICE] sampvoice.so adicionado a linha plugins."
            fi
        else
            echo "plugins sampvoice.so" >> ./server.cfg
            touch ./.loxy-sampvoice-managed
            echo "[VOICE] Linha plugins criada com sampvoice.so."
        fi
    fi

    if [[ "${VOIP_PORT:-0}" =~ ^[0-9]+$ ]] \
        && (( VOIP_PORT >= 1 && VOIP_PORT <= 65535 )); then
        if grep -Eq '^[[:space:]]*sv_port[[:space:]]+' ./server.cfg; then
            sed -i -E "s/^[[:space:]]*sv_port[[:space:]]+.*/sv_port ${VOIP_PORT}/" ./server.cfg
        else
            echo "sv_port ${VOIP_PORT}" >> ./server.cfg
            touch ./.loxy-svport-managed
        fi
        echo "[VOICE] Porta configurada: ${VOIP_PORT}"
    else
        echo "[AVISO] SAMP_VOIP=1, mas VOIP_PORT nao e uma porta valida."
    fi
else
    # Remove somente configuracoes adicionadas automaticamente por esta Egg.
    if [[ -f ./.loxy-sampvoice-managed ]]; then
        awk '
            BEGIN { OFS=" " }
            /^[[:space:]]*plugins([[:space:]]|$)/ {
                out=$1
                for (i=2; i<=NF; i++) {
                    if ($i!="sampvoice" && $i!="sampvoice.so") out=out OFS $i
                }
                print out
                next
            }
            { print }
        ' ./server.cfg > ./server.cfg.loxy.tmp
        mv ./server.cfg.loxy.tmp ./server.cfg
        rm -f ./.loxy-sampvoice-managed
        echo "[VOICE] Entrada gerenciada de sampvoice removida."
    fi

    if [[ -f ./.loxy-svport-managed ]]; then
        sed -i -E '/^[[:space:]]*sv_port[[:space:]]+/d' ./server.cfg
        rm -f ./.loxy-svport-managed
        echo "[VOICE] sv_port gerenciada removida."
    fi
fi

echo "[SA-MP] Iniciando samp03svr sob supervisao direta do Pterodactyl..."
exec ./samp03svr
