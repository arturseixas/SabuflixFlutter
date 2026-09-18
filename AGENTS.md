# Sabuflix

- Flutter/Dart; `lib/main.dart` inicializa MediaKit e registra os providers. UI em `lib/screens/` e `lib/widgets/`; estado em `lib/providers/`; integrações em `lib/services/` (casting em `lib/services/cast/`: SSDP/DLNA, mDNS/Cast v2, sessão e descoberta); tema em `lib/theme/`. Versão exibida em `lib/app_info.dart`.
- Comandos: `flutter pub get`; `flutter analyze`; `flutter test --reporter compact` (ou um arquivo de `test/`); `dart format <arquivos alterados>`. Build web: `flutter build web --release`. Builds nativos e empacotamento: `.github/workflows/build.yml`, `windows/installer.iss`.
- Preserve compatibilidade multiplataforma; downloads usam `dart:io` e PiP tem integração Android. Verifique o alvo afetado, sem presumir paridade com web.
- Persistência local usa SharedPreferences. Preserve chaves e isolamento por perfil; a seleção em `lib/screens/profile_selection_screen.dart` carrega os estados associados. `BackupService` exporta/importa essas chaves, então novas chaves por perfil devem entrar em `keysFor`. Testes de persistência usam `SharedPreferences.setMockInitialValues`.
- Casting: `CastProvider` é o único dono da sessão; telas usam `showCastPicker`/`CastRemoteScreen`. Reprodução em qualquer lugar deve passar pela lógica de `PlaybackResolver` (preferências de qualidade/áudio) e, quando houver TV conectada, enviar para ela em vez do player local.

## Eficiência de contexto

- Optimize context efficiency, not reasoning depth. Prioridade: correção, qualidade, compreensão suficiente, verificação/testes, eficiência de contexto, concisão.
- Comece pelos arquivos do pedido e use `rg` com caminhos/símbolos direcionados; expanda conforme necessário. Evite releituras, documentação preventiva e artefatos irrelevantes. Consulte arquivos ignorados/gerados quando relevantes.
- Estas são heurísticas, nunca limites: leia todo código, teste, documentação ou dependência que possa melhorar materialmente a solução; preserve análise de arquitetura, segurança e efeitos colaterais.
- Mantenha instruções compactas; regras locais em AGENTS.md locais e workflows especializados em `.agents/skills/` somente quando úteis, sem duplicação. Não altere comportamento do app para economizar contexto.
- Evite narrar ações triviais ou repetir pedidos, planos e resultados; limite saídas sem esconder falhas. Ao concluir, informe mudanças, verificações e decisões/problemas relevantes; explique mais quando útil.
