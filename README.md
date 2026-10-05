# Orama Fábrica

App Flutter da fábrica: registra as entradas de estoque (sorvetes, polpas, insumos, descartáveis),
mostra saldo e histórico e permite estornar com senha de administrador. Conversa com a `orama_api`
(Spring Boot + PostgreSQL). O desenho completo está em
`../orama_admin/lib/docs/Plano - novo banco de estoque.md`.

## O que o app faz

- **Entrada**: escolhe o local (câmara frigorífica, geladeira, oficina), os itens e as quantidades.
  Itens com recipiente (baldes, cubas, potes) pedem o peso real de cada um, lote e validade.
- **Funciona sem internet**: a entrada é salva no aparelho com um identificador único e enviada em
  lotes quando a conexão volta. Reenviar nunca duplica. Linhas recusadas pela API não são reenviadas
  sozinhas: aparecem para correção.
- **Estoque**: saldo por item e local, e lista de recipientes em estoque (primeiro a vencer primeiro).
- **Histórico**: filtros por período, local e item; estorno com motivo e senha de administrador.

## Rodar

```bash
flutter pub get
flutter run --dart-define-from-file=env/dev.json   # emulador Android falando com a API local
```

- `API_URL` é obrigatória e não tem valor padrão. Em build de release ela precisa ser `https://`.

## Windows

O app também roda no Windows (as telas ficam numa coluna central de até 840 px, em vez de esticar na janela).
O build precisa ser feito em uma máquina Windows com o Visual Studio (carga "Desenvolvimento para desktop com C++"):

```bash
flutter run -d windows --dart-define-from-file=env/dev.json
flutter build windows --release --dart-define-from-file=env/prod.json   # saída em build/windows/x64/runner/Release
```

O instalador é gerado a cada release (Inno Setup, como no `orama_admin`): `orama_fabrica_setup_X.Y.Z.exe`. Para gerar
um na própria máquina: `installer\build_installer.ps1` (precisa do Inno Setup 6 e de `env\prod.json`). Na atualização
pelo próprio app, ele baixa o instalador do release e o executa; o instalador fecha o app, troca os arquivos e o reabre.

## Release (GitHub Actions)

A cada push na `main`, `.github/workflows/release.yml` cria a tag `vX.Y.Z` (versão do `pubspec.yaml`, se ainda
não existir), roda análise e testes, compila APK e AAB assinados (Android) e o instalador do Windows (num runner Windows) e publica tudo no Release. Suba a versão no
`pubspec.yaml` para gerar um novo. Nada sensível fica no repositório; configure em *Settings > Secrets and variables > Actions*:

| Secret | Conteúdo |
|--------|----------|
| `PROD_ENV_JSON` | JSON como `env/prod.json.example` (`{"API_URL": "https://..."}`) |
| `KEYSTORE_BASE64` | `base64 -w0 keystore.jks` do keystore do app |
| `STORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS` | dados do keystore |

Guarde o keystore com backup fora do repositório: sem ele não há como publicar atualizações do mesmo app.
- Em debug no Android, HTTP simples é permitido (manifesto de debug). Em release, não.
- Para a versão web: `flutter build web --release --dart-define=API_URL=https://api.seudominio.com.br`
  e coloque o endereço do site em `ORAMA_CORS_ORIGINS` na API.

## Testes

```bash
flutter analyze
flutter test --coverage                  # 108 testes, cobertura de linhas ~94%
```

Teste de contrato contra uma API de verdade (suba a `orama_api` antes, com um administrador):

```bash
flutter test test/integracao/api_real_test.dart \
  --dart-define=API_REAL_URL=http://127.0.0.1:8080 \
  --dart-define=API_REAL_ADMIN_LOGIN=admin \
  --dart-define=API_REAL_ADMIN_SENHA=...
```

Sem `API_REAL_URL`, esse teste é pulado.

## Estrutura (`lib/`)

| Pasta | Conteúdo |
|---|---|
| `config/` | endereço da API e validações de configuração |
| `api/` | cliente HTTP, modelos e chamadas da API |
| `auth/` | login e sessão (token em armazenamento seguro) |
| `data/` | catálogo, fila offline de entradas, rascunho |
| `pages/` | telas |
| `storage/`, `util/`, `widgets/` | apoio |

## Limites conhecidos

- Na versão web o token fica no `localStorage` do navegador (exposto a XSS). No celular usa o
  armazenamento seguro do sistema.
- O build Android não foi verificado neste ambiente (SDK do Flutter somente leitura).
- Impressão de etiquetas ainda não existe (melhoria futura).
