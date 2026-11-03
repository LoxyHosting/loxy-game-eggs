# SA-MP Windows via Wine

Esta egg adiciona uma rotina de inicializacao para executar `samp-server.exe` em ambiente Wine dentro do Pterodactyl, mantendo a compatibilidade com os padrões de seguranca e preservacao de arquivos da Loxy Hosting.

## Objetivo

- Execucao do servidor Windows via Wine e prefixo persistente em `/home/container/.wine`
- Carregamento seguro de plugins com extensao `.dll` na pasta `plugins/`
- Gerenciamento do `server.cfg` sem sobrescrever configuracoes existentes desnecessariamente
- Suporte opcional ao SA-MP Voice com `SAMP_VOIP` e `VOIP_PORT`
- Entrada do processo pela camada de inicializacao do Pterodactyl sem quebrar o startup do servidor Linux atual

## Arquivos adicionados

- `egg-samp-windows-wine.json` — Egg importavel para Pterodactyl
- `samp-wine.sh` — startup customizado com validacao do runtime Wine
- `docker-images/samp-wine/Dockerfile` — imagem de runtime com Wine e dependencias minimas
- `docker-images/samp-wine/build.sh` — script para construir a imagem localmente

## Variaveis principais

- `SERVER_PORT` — porta principal do servidor
- `MAX_PLAYERS` — limite de jogadores
- `SERVER_HOSTNAME` — nome visivel no servidor
- `RCON_PASSWORD` — senha do RCON
- `SERVER_PASSWORD` — senha de entrada opcional
- `ANNOUNCE` — anuncio na lista de servidores
- `QUERY` — consulta do servidor
- `LAN` — modo LAN
- `RCON` — habilita RCON
- `SAMP_VOIP` — habilita ou desabilita verificacao do plugin de voz
- `VOIP_PORT` — porta UDP do plugin SampVoice
- `SAMPVOICE_URL` — URL opcional para download seguro do `sampvoice.dll`

## Consideracoes de seguranca

- A URL do plugin de voz nao e inventada; a egg exige `SAMPVOICE_URL` quando o plugin estiver ausente.
- Arquivos `.so` no `plugins/` sao ignorados e nao sao carregados como DLLs.
- O prefixo Wine permanece em `/home/container/.wine`, preservando estado e evitando perda de dados em reinicializacoes.
- Enquanto `SAMP_VOIP=0`, a egg nao remove plugins ou alteracoes de cliente.

## Limites conhecidos

- A compatibilidade real do plugin de voz depende do binario Windows correto e da URL informada pelo administrador.
- A execucao de um servidor Windows em Wine exige uma imagem Docker com o runtime Wine corretamente instalado.
- Nao e possivel validar o funcionamento completo do `samp-server.exe` neste ambiente sem um host Pterodactyl ou um container Wine real.

## Publicacao

Os arquivos estao prontos no repositorio local. Para publicar no GitHub, e necessario permissao de escrita na branch principal do repositório e um push final com os arquivos novos.
