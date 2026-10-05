# Gera o instalador do Windows localmente. No CI quem faz isso é o job "windows" do release.yml.
# Precisa do Inno Setup 6 e de env/prod.json (copie de env/prod.json.example) para o endereço da API.
$ErrorActionPreference = 'Stop'

$projectRoot = Resolve-Path "$PSScriptRoot\.."
$issFile = Join-Path $projectRoot 'installer\orama_fabrica.iss'

Push-Location $projectRoot
try {
  $versionLine = Get-Content 'pubspec.yaml' | Where-Object { $_ -match '^version:\s*(.+)$' } | Select-Object -First 1
  if (-not $versionLine) {
    throw 'Versão não encontrada no pubspec.yaml.'
  }

  $appVersion = ($versionLine -replace '^version:\s*', '') -replace '\+.*$', ''

  if (-not (Test-Path 'env\prod.json')) {
    throw 'env\prod.json não encontrado. Copie env\prod.json.example e preencha a API_URL.'
  }
  flutter build windows --release --dart-define-from-file=env/prod.json

  $iscc = Get-Command iscc -ErrorAction SilentlyContinue
  $isccPath = if ($iscc) { $iscc.Source } else { Join-Path ${env:ProgramFiles(x86)} 'Inno Setup 6\ISCC.exe' }

  if (-not (Test-Path $isccPath)) {
    throw 'Inno Setup Compiler (iscc) não encontrado no PATH. Instale o Inno Setup e tente novamente.'
  }

  & $isccPath "/DAppVersion=$appVersion" $issFile
}
finally {
  Pop-Location
}
