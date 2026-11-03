# SA-MP Windows via Wine

Este diretório prepara uma imagem Docker para Pterodactyl com suporte a executáveis Windows do SA-MP em ambiente Wine.

## Componentes

- Debian 12 Bookworm slim
- Wine 32-bit/64-bit
- `curl`, `wget`, `unzip`, `file`, `cabextract`, `xvfb`
- diretório de trabalho em `/home/container`
- prefixo Wine persistente em `/home/container/.wine`

## Construir

```bash
cd docker-images/samp-wine
chmod +x build.sh
./build.sh
```

## Etapas de uso

```bash
docker run --rm -it \
  -v "$PWD:/home/container" \
  -w /home/container \
  --user 1000:1000 \
  loxyhosting/samp-wine:latest
```

## Observações

- O comando do servidor usa `samp-server.exe` via Wine.
- O diretório `plugins/` aceita DLLs nativas do Windows.
- O campo `SAMPVOICE_URL` deve apontar para um binario Windows compatível quando `SAMP_VOIP=1` e o plugin ainda nao existir.
