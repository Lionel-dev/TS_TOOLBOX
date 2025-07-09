$ScriptDir = Split-Path -Parent $PSCommandPath
$configPath = Join-Path $ScriptDir '..' 'Config' 'config_menu.yaml'
$optionsDir = Join-Path $ScriptDir '..' 'Options'

# Ensure ConvertFrom-Yaml is available
if (-not (Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue)) {
    try {
        Install-Module -Name powershell-yaml -Force -Scope CurrentUser -SkipPublisherCheck
        Import-Module powershell-yaml
    } catch {
        Write-Host "Failed to import powershell-yaml: $_" -ForegroundColor Red
    }
}

$config = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Yaml
$functions = $config.MenuOptions | ForEach-Object { $_.function }

Get-ChildItem $optionsDir -Filter '*.ps1' | ForEach-Object { . $_.FullName }

Describe 'Menu configuration functions' {
    foreach ($func in $functions) {
        It "Function $func should be defined" {
            Get-Command $func -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }
}
