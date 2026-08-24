# ==========================================
# WAP - QuickFix Windows
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

$LogFile = Join-Path $LogPath "WAP_ReparoRapido.log"

# Pegar informações do usuário logado e Active Directory
$LoggedUser = Get-WAP-LoggedUser
$Username = Get-WAP-ExtractedUser

Add-Content $LogFile "Usuario logado: $LoggedUser"
Add-Content $LogFile "Usuario extraido: $Username"

$Department = "Unknown"
if ($Username -and $Username -ne "Unknown" -and $Username -notlike "*$") {
    try {        # Verificar se módulo ActiveDirectory está disponível
        if (-not (Get-Module -Name ActiveDirectory -ErrorAction SilentlyContinue)) {
            Import-Module ActiveDirectory -ErrorAction Stop
        }
                $ADUser = Get-ADUser -Identity $Username -Properties Department -ErrorAction Stop
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
    Add-Content $LogFile "AVISO: Usuario invalido ou conta de sistema ($Username). Departamento nao disponivel."
}

$NetworkAccessible = $false

# Cabeçalho do LOG

Add-Content $LogFile "=========================================="
Add-Content $LogFile "WAP - QuickFix Windows"
Add-Content $LogFile "Inicio: $Inicio"
Add-Content $LogFile "Usuario: $env:USERNAME"
Add-Content $LogFile "Computador: $env:COMPUTERNAME"
Add-Content $LogFile "=========================================="

try {

    # Informações úteis para troubleshooting

    $IPv4 = (
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.IPAddress -notlike "169.*" -and
            $_.IPAddress -ne "127.0.0.1"
        } |
        Select-Object -First 1 -ExpandProperty IPAddress
    )

    $Disco = Get-CimInstance Win32_LogicalDisk |
        Where-Object DeviceID -eq "C:"

    $EspacoLivreGB = [Math]::Round(
        ($Disco.FreeSpace / 1GB),
        2
    )

    $BootTime = (
        Get-CimInstance Win32_OperatingSystem
    ).LastBootUpTime

    $UptimeHoras = [Math]::Round(
        ((Get-Date) - $BootTime).TotalHours,
        2
    )

    Add-Content $LogFile "IPv4: $IPv4"
    Add-Content $LogFile "Espaco livre (GB): $EspacoLivreGB"
    Add-Content $LogFile "Uptime (Horas): $UptimeHoras"

    # DNS

    Add-Content $LogFile "Executando FlushDNS..."
    ipconfig /flushdns | Out-Null

    # Winsock

    Add-Content $LogFile "Executando Winsock Reset..."
    netsh winsock reset | Out-Null

    # TCP/IP

    Add-Content $LogFile "Executando TCP/IP Reset..."
    netsh int ip reset | Out-Null

    # TEMP Usuário

    Add-Content $LogFile "Limpando TEMP do usuario..."

    if (Test-Path $env:TEMP) {
        Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    # TEMP Windows

    Add-Content $LogFile "Limpando TEMP do Windows..."

    if (Test-Path "C:\Windows\Temp") {
        Get-ChildItem "C:\Windows\Temp" -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
    }

    # Teams

    Add-Content $LogFile "Limpando cache Teams..."

    Stop-Process -Name "teams" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "ms-teams" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "msteams" -Force -ErrorAction SilentlyContinue

    $TeamsCache = Join-Path $env:LOCALAPPDATA "Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams"

    if (Test-Path $TeamsCache) {
        Remove-Item $TeamsCache -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Explorer

    Add-Content $LogFile "Reiniciando Explorer..."

    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Process explorer.exe

    Add-Content $LogFile "Windows Update Scan opcional removido por compatibilidade entre versoes do Windows."

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
    elseif ($Erro -match "timeout|time out") {
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

# JSON padrão WAP

$Resultado = [PSCustomObject]@{
    Data                 = $Inicio.ToString("yyyy-MM-dd HH:mm:ss")
    Ferramenta           = "WAP-ReparoRapido"
    Departamento         = $Department
    Status               = $Status
    DuracaoSegundos      = $Duracao
    Erro                 = $Erro
    TempoEconomizadoMins = 20
}

# Nome do CSV

$NomeArquivo = "ReparoRapido_{0}_{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format "yyyyMMdd_HHmmss")
$ArquivoJson = Join-Path -Path $JsonPath -ChildPath $NomeArquivo
$ArquivoJsonBackup = Join-Path -Path $JsonPathBackup -ChildPath $NomeArquivo

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
