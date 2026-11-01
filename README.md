# loxy-game-eggs
Eggs, scripts de inicialização e runtimes personalizados para servidores SA-MP, OpenMP e outros serviços da Loxy Hosting no Pterodactyl.

## SA-MP startup

O launcher de SA-MP foi reestruturado para validar o runtime, detectar arquitetura do executável e plugins, fazer backup de server.cfg antes de ajustes de runtime e evitar download não validado de sampvoice.so.

Variáveis suportadas:
- `SAMP_VOIP=1` ou `0` para habilitar/desabilitar o SA-MP Voice.
- `VOIP_PORT` para a porta do voice em separado da principal.
- `SAMP_PLUGIN_SSCANF`, `SAMP_PLUGIN_STREAMER`, `SAMP_PLUGIN_PAWNRAKNET`, `SAMP_PLUGIN_SAMPVOICE` para controle individual dos plugins.
- `SAMP_DIAGNOSTIC=1` para iniciar em modo diagnóstico sem Pawn.RakNet e sem SampVoice.
- `SAMPVOICE_VERSION` para fixar a versão do plugin e `SAMPVOICE_SHA256` para validar o arquivo antes de substituir o plugin instalado.

A versão fixa do SampVoice usada pela egg é `1.0.0`, com hash SHA-256 validado antes de instalar o arquivo no diretório de plugins.

## Acelerador de downloads MTA

Quando `EXPRESS_PORT` estiver configurada, `mta.sh` baixa e inicia o acelerador HTTP binário-seguro, atualiza `httpdownloadurl` e aguarda uma resposta HTTP local antes de iniciar o MTA. A porta também deve estar atribuída ao servidor como allocation do Pterodactyl para que o Wings a publique. Se o listener não ficar pronto, a inicialização para e exibe `accelerator.log` e `accelerator_error.log`. Os arquivos são lidos como bytes e comprimidos sem corromper imagens ou outros recursos binários.
