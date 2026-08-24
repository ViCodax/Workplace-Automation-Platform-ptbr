# ==========================================
# WAP - Reparo Teams
# Autor: Vinicius Silva
# ==========================================

# Funções auxiliares (incorporadas para compatibilidade SCCM)
function Get-WAP-ExtractedUser {
    param()
    $LoggedUser = Get-WAP-LoggedUser

    if ([string]::IsNullOrWhiteSpace($LoggedUser) -or $LoggedUser -eq "Unknown") {
        return "Unknown"
    }

    if ($LoggedUser -like "*\*") {
        $User = $LoggedUser.Split('\')[-1]
    }
    elseif ($LoggedUser -like "*@*") {
        $User = $LoggedUser.Split('@')[0]
    }
    else {
        $User = $LoggedUser
    }

    if ($User -like "*$") {
        return "Unknown"
    }

    return $User
}

function Get-WAP-LoggedUser {
    param()
    try {
        $LoggedUser = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).UserName
        if (-not [string]::IsNullOrWhiteSpace($LoggedUser) -and $LoggedUser -like "*\*" -and $LoggedUser -notlike "*$") {
            return $LoggedUser
        }
    }
    catch {}

    try {
        $ExplorerProcess = Get-CimInstance Win32_Process -Filter "Name='explorer.exe'" -ErrorAction Stop |
            Sort-Object CreationDate -Descending |
            Select-Object -First 1

        if ($ExplorerProcess) {
            $Owner = Invoke-CimMethod -InputObject $ExplorerProcess -MethodName GetOwner -ErrorAction Stop
            if ($Owner -and $Owner.User -and $Owner.Domain) {
                return "$($Owner.Domain)\$($Owner.User)"
            }
        }
    }
    catch {}

    try {
        $LastLoggedOnUser = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication\LogonUI" -Name LastLoggedOnUser -ErrorAction Stop).LastLoggedOnUser
        if (-not [string]::IsNullOrWhiteSpace($LastLoggedOnUser)) {
            return $LastLoggedOnUser
        }
    }
    catch {}

    return "Unknown"
}

# Caminho dos JSONs (Power BI)

$JsonPath = "COLOQUE_SEU_PATH_AQUI"
$JsonPathBackup = "C:\Temp\WAP\JsonBackup"

# Criar backup local para fallback
if (!(Test-Path $JsonPathBackup)) {
    New-Item -Path $JsonPathBackup -ItemType Directory -Force | Out-Null
}

if (!(Test-Path $JsonPath)) {
    New-Item -Path $JsonPath -ItemType Directory -Force | Out-Null
}

# Variáveis de execução

$Inicio = Get-Date
$Status = "Sucesso"
$Erro = ""
$ErrorCategory = "Nenhum"
$Tentativa = 0

# Caminho dos LOGs

$LogPath = "C:\Temp\WAP\Logs"

if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogPath "WAP_ReparoTeams.log"

# Pegar informações do usuário logado e Active Directory

$LoggedUser = Get-WAP-LoggedUser
$User = Get-WAP-ExtractedUser

Add-Content $LogFile "Usuario logado: $LoggedUser"
Add-Content $LogFile "Usuario extraido: $User"

# Tentar obter departamento do Active Directory usando o usuário logado
$Department = "Unknown"
if ($User -and $User -ne "Unknown" -and $User -notlike "*$") {
    try {        # Verificar se módulo ActiveDirectory está disponível
        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
                $ADUser = Get-ADUser -Identity $User -Properties Department -ErrorAction Stop
        if ($ADUser.Department) {
            $Department = $ADUser.Department
            Add-Content $LogFile "Departamento obtido de AD: $Department"
        }
    }
    catch {
        Add-Content $LogFile "AVISO: Nao foi possivel obter departamento de AD: $($_.Exception.Message)"
    }
}
else {
    Add-Content $LogFile "AVISO: Usuario invalido ou conta de sistema ($User). Departamento nao disponivel."
}

$NetworkAccessible = $false

# Cabeçalho do LOG

Add-Content $LogFile "=========================================="
Add-Content $LogFile "WAP - Reparo Teams"
Add-Content $LogFile "Inicio: $Inicio"
Add-Content $LogFile "Usuario: $env:USERNAME"
Add-Content $LogFile "Computador: $env:COMPUTERNAME"
Add-Content $LogFile "=========================================="

try {

    Add-Content $LogFile "Encerrando processos Teams..."

    Get-Process -Name "ms-teams" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "teams" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "msteams" -ErrorAction SilentlyContinue | Stop-Process -Force
    Get-Process -Name "msedgewebview2" -ErrorAction SilentlyContinue | Stop-Process -Force

$TeamsCache = "C:\Users\$User\Appdata\Local\Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"

Add-Content $LogFile "Removendo cache Teams..."

Add-Content $LogFile "Caminho utilizado: $TeamsCache"

if (Test-Path $TeamsCache) {
    $CacheRemovido = $false
    $MaxTentativasCache = 3

    for ($TentativaCache = 1; $TentativaCache -le $MaxTentativasCache; $TentativaCache++) {
        Add-Content $LogFile "Tentativa $TentativaCache/$MaxTentativasCache para remover cache MSTeams..."

        try {
            # Limpa filhos primeiro para reduzir falhas de "pasta nao esta vazia".
            Get-ChildItem -Path $TeamsCache -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

            Remove-Item -Path $TeamsCache -Recurse -Force -ErrorAction Stop

            Start-Sleep -Milliseconds 500
            if (-not (Test-Path $TeamsCache)) {
                $CacheRemovido = $true
                Add-Content $LogFile "Pasta MSTeams removida com sucesso."
                break
            }
        }
        catch {
            Add-Content $LogFile "Falha na tentativa ${TentativaCache}: $($_.Exception.Message)"
        }

        if ($TentativaCache -lt $MaxTentativasCache) {
            Start-Sleep -Seconds 2
        }
    }

    if (-not $CacheRemovido) {
        throw "Nao foi possivel remover o cache MSTeams apos $MaxTentativasCache tentativas."
    }
}
else {

    Add-Content $LogFile "Pasta MSTeams nao localizada."
}

$Protocolos = @(
    "msteams:"
    "ms-teams:"
    "teams:"
)

foreach ($Protocolo in $Protocolos) {
    try {

        Add-Content $LogFile "Tentando abrir Teams usando $Protocolo"

        Start-Process $Protocolo -ErrorAction Stop

        Add-Content $LogFile "Comando enviado com sucesso utilizando $Protocolo"

        break
    }
    catch {

        Add-Content $LogFile "Falha ao iniciar Teams utilizando $Protocolo"
    }
}
}
catch {

    $Status = "Falha"
    $Erro = $_.Exception.Message
    
    # Categorizar erro
    if ($Erro -match "Access Denied|Permission") {
        $ErrorCategory = "PermissaoDenegada"
    }
    elseif ($Erro -match "not found|nao encontrado|caminho") {
        $ErrorCategory = "CaminhoNaoEncontrado"
    }
    elseif ($Erro -match "timeout|time out|timeout") {
        $ErrorCategory = "Timeout"
    }
    else {
        $ErrorCategory = "Outro"
    }

    Add-Content $LogFile "ERRO: $Erro"
    Add-Content $LogFile "Categoria do Erro: $ErrorCategory"
}

# Finalização

$Fim = Get-Date

$Duracao = [Math]::Round(
    ($Fim - $Inicio).TotalSeconds,
    2
)

# Informações finais do LOG

Add-Content $LogFile "Fim: $Fim"
Add-Content $LogFile "Duracao: $Duracao segundos"
Add-Content $LogFile "Status: $Status"
Add-Content $LogFile ""
Add-Content $LogFile "Duracao calculada: $Duracao"

# Objeto JSON (Padrão WAP)

$Resultado = [PSCustomObject]@{
    Data                 = $Inicio.ToString("yyyy-MM-dd HH:mm:ss")
    Ferramenta           = "WAP-ReparoTeams"
    Departamento         = $Department
    Status               = $Status
    DuracaoSegundos      = $Duracao
    Erro                 = $Erro
    TempoEconomizadoMins = 5
}

# Nome do CSV

$NomeArquivo = "ReparoTeams_{0}_{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format "yyyyMMdd_HHmmss")
$ArquivoJson = Join-Path -Path $JsonPath -ChildPath $NomeArquivo
$ArquivoJsonBackup = Join-Path -Path $JsonPathBackup -ChildPath $NomeArquivo

Add-Content $LogFile "Arquivo CSV:"
Add-Content $LogFile $ArquivoJson

# Exportação CSV com validação e retry

$JsonExportado = $false
$MaxTentativas = 3
$Tentativa = 0

while ($Tentativa -lt $MaxTentativas -and -not $JsonExportado) {
    $Tentativa++
    Add-Content $LogFile "Tentativa $Tentativa de $MaxTentativas para exportar CSV..."
    
    try {
        # Validar que o objeto pode ser serializado em CSV
        $CsvString = $Resultado | ConvertTo-Csv -NoTypeInformation -ErrorAction Stop
        Add-Content $LogFile "CSV serializacao: OK"
        
        # Tentar escrever no caminho de rede
        if (Test-Path $JsonPath) {
            $NetworkAccessible = $true
            Add-Content $LogFile "Caminho de rede acessivel. Escrevendo para: $ArquivoJson"
            $CsvString | Out-File -FilePath $ArquivoJson -Encoding UTF8 -Force -ErrorAction Stop
            
            # Validar que o arquivo foi criado
            Start-Sleep -Milliseconds 500
            if (Test-Path $ArquivoJson) {
                $FileSize = (Get-Item $ArquivoJson).Length
                Add-Content $LogFile "CSV gerado com sucesso em caminho de rede. Tamanho: $FileSize bytes"
                $JsonExportado = $true
            }
            else {
                Add-Content $LogFile "AVISO: Arquivo nao foi criado apos Out-File. Tentando backup..."
            }
        }
        else {
            Add-Content $LogFile "Caminho de rede nao acessivel. Usando backup local."
        }
        
        # Se nao foi exportado para rede, usar backup local
        if (-not $JsonExportado) {
            Add-Content $LogFile "Escrevendo CSV em backup local: $ArquivoJsonBackup"
            $CsvString | Out-File -FilePath $ArquivoJsonBackup -Encoding UTF8 -Force -ErrorAction Stop
            
            if (Test-Path $ArquivoJsonBackup) {
                Add-Content $LogFile "CSV exportado para backup local com sucesso."
                $JsonExportado = $true
            }
        }
    }
    catch {
        $ErroAtual = $_.Exception.Message
        Add-Content $LogFile "ERRO na tentativa $Tentativa - GERANDO CSV: $ErroAtual"
        
        if ($Tentativa -lt $MaxTentativas) {
            Add-Content $LogFile "Aguardando 2 segundos antes de retry..."
            Start-Sleep -Seconds 2
        }
    }
}

if (-not $JsonExportado) {
    Add-Content $LogFile "FALHA: CSV nao pode ser exportado apos $MaxTentativas tentativas."
    $Status = "Falha"
    $Erro = "Falha ao exportar CSV"
}

if ($Status -eq "Sucesso") {
    exit 0
}
else {
    exit 1
}
