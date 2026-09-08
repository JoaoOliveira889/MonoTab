# MonoTab Rules

Regras obrigatórias para desenvolvimento, manutenção e versionamento do MonoTab.

## Versionamento Semântico (SemVer) e Incremento Contínuo

O projeto segue rigorosamente o Versionamento Semântico (`MAJOR.MINOR.PATCH`):
- **Versão Inicial Base**: `0.0.1` (Tag: `v0.0.1`).
- **PATCH (`0.0.x`)**: Correções de bugs, ajustes de usabilidade, refinamentos de UI/UX, refatorações internas e melhorias de performance que não alterem a interface ou comportamento fundamental.
- **MINOR (`0.x.0`)**: Novos recursos (ex.: novos modos de navegação, novos filtros, suporte a novos atalhos/gestos), opções configuráveis ou adições substanciais sem quebrar compatibilidade.
- **MAJOR (`x.0.0`)**: Reescritas arquiteturais profundas, redesign completo ou alterações com quebra de compatibilidade.

### Procedimento Obrigatório de Incremento a Cada Nova Versão
Sempre que uma nova tarefa, correção ou funcionalidade for concluída e pronta para entrega:
1. **Incrementar a versão no código**:
   - Atualizar `AppInfo.version` (e `AppInfo.build` se aplicável) em `Sources/MonoTab/Models/AppVersion.swift`.
2. **Atualizar metadados do pacote**:
   - Atualizar `CFBundleShortVersionString` e incrementar `CFBundleVersion` em `Resources/Info.plist`.
3. **Atualizar documentação**:
   - Atualizar o badge de versão no topo do `README.md` (`https://img.shields.io/badge/version-vX.Y.Z-brightgreen`).
4. **Verificar interface do usuário**:
   - A tela de Configurações (`SettingsView.swift`) consome `AppInfo.version` e `AppInfo.build` automaticamente através do bundle infoDictionary.
5. **Garantir integridade dos testes e build**:
   - Executar `make test` (com `DEVELOPER_DIR` configurado para Xcode) garantindo 0 falhas.
   - Executar `make build` e `make install` para validar o empacotamento do app e reiniciar a versão local atualizada.
6. **Publicar no Git e GitHub**:
   - Criar commit com Conventional Commits (`fix:`, `feat:`, `chore:`).
   - Criar tag semver anotada correspondente (`git tag -a vX.Y.Z -m "vX.Y.Z"`).
   - Fazer push dos commits e da nova tag (`git push origin main && git push origin vX.Y.Z`).
   - Gerar o bundle de release (`make app` e zip `MonoTab-vX.Y.Z-macOS-arm64.zip`).
   - Publicar a release no GitHub via `gh release create vX.Y.Z MonoTab-vX.Y.Z-macOS-arm64.zip --title "vX.Y.Z"`.

---

## Arquitetura & Invariantes de Performance

- **Zero Telemetria / Zero Rede**: MonoTab é estritamente local. Não coletar ou transmitir dados, logs ou telemetria.
- **Latência Perceptual 0ms**: O event tap global está na run loop principal; execuções acionadas pelo tap devem permanecer bem abaixo de 1s de timeout.
- **ScreenCaptureKit Hardware-Accelerated**: As capturas são vinculadas aos bounds das janelas e processadas de forma assíncrona, sem sobrecarregar a GPU com texturas 4K/5K desnecessárias.
- **ProMotion 120 FPS**: Evitar re-rasterização custosa de camadas de vidro CoreAnimation ou transformações de escala que causem perda de fluidez.
- **Permissões**: Gerenciar graciosamente permissões de Acessibilidade e Gravação de Tela através do `PermissionsManager` e exibir `PermissionsBannerView` em caso de falta de permissão.
