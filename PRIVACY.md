# Compromisso de Privacidade e Segurança do MonoTab

O **MonoTab** foi desenvolvido com um princípio inegociável: **Privacidade Absoluta e Zero Telemetria**.

Este documento detalha a arquitetura de segurança e privacidade implementada no aplicativo, permitindo que usuários e auditores verifiquem como seus dados e janelas são protegidos.

---

## 1. Zero Coleta de Dados e Zero Telemetria

- **Sem Rede**: O MonoTab não contém nenhuma chamada de rede (`URLSession`, `Network.framework`, WebSockets, sockets ou requisições HTTP/HTTPS).
- **Sem Telemetria ou Analytics**: Não há bibliotecas de terceiros, SDKs de rastreamento, Google Analytics, Firebase, Sentry ou rastreadores de qualquer natureza.
- **Operação 100% Offline e Local**: O processamento de lista de janelas e atalhos de teclado acontece estritamente na CPU e GPU locais da sua máquina.
- **Entitlements Restritivos**: O aplicativo é assinado com `Resources/Entitlements.plist` sem a permissão `com.apple.security.network.client`, tornando-o incapaz de abrir conexões de rede de saída.

---

## 2. Eliminação Total de Logs em Disco

- **Sem Arquivos de Log em `/tmp`**: O MonoTab não grava logs em arquivos temporários ou no disco (`/tmp/MonoTab.log` foi permanentemente removido).
- **Apple Unified Logging (`os.Logger`)**: Toda a instrumentação do aplicativo utiliza o subsistema oficial de logging da Apple:
  - Registros residem em anéis de memória volátil gerenciados pelo macOS.
  - Dados potencialmente sensíveis (como títulos de janelas e nomes de processos) são mascarados com redação de privacidade (`<private>`).
  - Nenhum título de janela, nome de aplicativo, busca ou tecla é enviado ao log do sistema.

---

## 3. Miniaturas e Screenshots em Memória RAM

- **Retenção Efêmera na RAM**: As miniaturas geradas pela API nativa `ScreenCaptureKit` são mantidas estritamente na memória volátil (`ThumbnailStore`).
- **Sem Gravação em Cache de Disco**: Nenhuma imagem de janela é salva no disco, em pastas de cache (`~/Library/Caches`) ou em arquivos temporários.
- **Descarte Imediato**: Quando uma janela é fechada ou quando o MonoTab é encerrado, todos os buffers de imagem são imediatamente liberados da memória.
- **Isolamento de Janelas**: A captura é restrita à janela individual (`SCContentFilter(desktopIndependentWindow:)`), sem capturar áreas adjacentes da tela ou dados de outros monitores.

---

## 4. Proteção contra Keylogger (Event Tap Seguro)

- **Captura Restrita de Teclas**: O interceptor de eventos de baixo nível (`CGEventTap`) é utilizado exclusivamente para detectar a combinação de ativação configurada (por exemplo, `⌥ Option + Tab` ou `⌘ Command + Tab`) e as teclas de controle enquanto o alternador está visível (setas, `Esc`, `Enter`).
- **Repasse Imediato**: Todas as outras teclas do teclado são ignoradas e repassadas instantaneamente para o sistema operacional sem nenhuma interceptação, gravação ou inspeção.
- **Sem Bufferização de Digitação**: O MonoTab nunca grava, armazena ou transmite o que o usuário digita.

---

## 5. Auditoria e Verificação

Qualquer usuário pode verificar essas garantias executando no terminal:

1. **Inspecionar símbolos do binário por chamadas de rede**:
   ```bash
   nm -u /Applications/MonoTab.app/Contents/MacOS/MonoTab | grep -iE "urlsession|socket|curl|analytics"
   # Resultado: 0 correspondências
   ```

2. **Verificar entitlements do binário assinado**:
   ```bash
   codesign -d --entitlements :- /Applications/MonoTab.app
   # Confirma ausência de com.apple.security.network.client
   ```

3. **Verificar ausência de arquivos residuais no disco**:
   ```bash
   ls /tmp/MonoTab.log
   # Arquivo inexistente
   ```
