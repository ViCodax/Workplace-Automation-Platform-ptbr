# ==========================================
# WAP - Advanced Repair
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

# Caminho JSON (Power BI)

$JsonPath = "COLOQUE_SEU_PATH_AQUI"
$JsonPathBackup = "C:\Temp\WAP\JsonBackup"

# Criar backup local para fallback
if (!(Test-Path $JsonPathBackup)) {
    New-Item -Path $JsonPathBackup -ItemType Directory -Force | Out-Null
}

if (!(Test-Path $JsonPath)) {
    New-Item -Path $JsonPath -ItemType Directory -Force | Out-Null
}

# Variáveis

$Inicio = Get-Date
$Status = "Sucesso"
$Erro = ""
$ErrorCategory = "Nenhum"
$Tentativa = 0

# Caminho Logs

$LogPath = "C:\Temp\WAP\Logs"

if (!(Test-Path $LogPath)) {
    New-Item -Path $LogPath -ItemType Directory -Force | Out-Null
}

$LogFile = Join-Path $LogPath "WAP_ReparoAvancado.log"

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

# Cabeçalho

Add-Content $LogFile "=========================================="
Add-Content $LogFile "WAP - Advanced Repair"
Add-Content $LogFile "Inicio: $Inicio"
Add-Content $LogFile "Usuario: $env:USERNAME"
Add-Content $LogFile "Computador: $env:COMPUTERNAME"
Add-Content $LogFile "=========================================="

try {

    # Informações para troubleshooting

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
    Add-Content $LogFile "Espaco Livre (GB): $EspacoLivreGB"
    Add-Content $LogFile "Uptime (Horas): $UptimeHoras"

# SFC

    Add-Content $LogFile "Iniciando SFC..."

    try {
        sfc /scannow | Out-Null
        Add-Content $LogFile "SFC concluido com sucesso."
    }
    catch {
        Add-Content $LogFile "Erro ao executar SFC: $($_.Exception.Message)"
    }

    # DISM

    Add-Content $LogFile "Iniciando DISM RestoreHealth..."

    try {
        DISM /Online /Cleanup-Image /RestoreHealth | Out-Null
        Add-Content $LogFile "DISM concluido com sucesso."
    }
    catch {
        Add-Content $LogFile "Erro ao executar DISM: $($_.Exception.Message)"
    }

    # CHKDSK

    Add-Content $LogFile "Iniciando CHKDSK..."

    try {
        & chkdsk C: /scan 2>&1 | Out-Null
        Add-Content $LogFile "CHKDSK concluido com sucesso."
    }
    catch {
        Add-Content $LogFile "Aviso: CHKDSK requer agendamento ou permissoes elevadas: $($_.Exception.Message)"
    }

    # Otimizacao de Disco (SSD/HDD)

    Add-Content $LogFile "Iniciando otimizacao de disco..."

    try {
        # Tentar otimizar C: (funciona em SSDs e HDDs)
        Optimize-Volume -DriveLetter C -Defrag -ErrorAction Stop | Out-Null
        Add-Content $LogFile "Otimizacao de disco concluida com sucesso."
    }
    catch {
        Add-Content $LogFile "Aviso: Nao foi possivel otimizar disco: $($_.Exception.Message)"
    }

    # Windows Update Reset

    Add-Content $LogFile "Reiniciando servicos Windows Update..."

    try {
        net stop wuauserv | Out-Null
        net stop bits | Out-Null
        Add-Content $LogFile "Servicos parados com sucesso."
    }
    catch {
        Add-Content $LogFile "Aviso ao parar servicos: $($_.Exception.Message)"
    }

    # Remove cache de atualização

    if (Test-Path "C:\Windows\SoftwareDistribution") {
        Add-Content $LogFile "Limpando SoftwareDistribution..."
        try {
            Remove-Item -Path "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction Stop
            Add-Content $LogFile "SoftwareDistribution removido com sucesso."
        }
        catch {
            Add-Content $LogFile "Aviso ao limpar SoftwareDistribution: $($_.Exception.Message)"
        }
    }

    try {
        net start wuauserv | Out-Null
        net start bits | Out-Null
        Add-Content $LogFile "Servicos Windows Update reiniciados com sucesso."
    }
    catch {
        Add-Content $LogFile "Aviso ao reiniciar servicos: $($_.Exception.Message)"
    }

    Add-Content $LogFile "Windows Update Reset concluido."

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

Add-Content $LogFile "Fim: $Fim"
Add-Content $LogFile "Duracao: $Duracao segundos"
Add-Content $LogFile "Status: $Status"
Add-Content $LogFile ""

# JSON padrão WAP

$Resultado = [PSCustomObject]@{
    Data                 = $Inicio.ToString("yyyy-MM-dd HH:mm:ss")
    Ferramenta           = "WAP-ReparoAvancado"
    Departamento         = $Department
    Status               = $Status
    DuracaoSegundos      = $Duracao
    Erro                 = $Erro
    TempoEconomizadoMins = 40
}

# Arquivo CSV

$NomeArquivo = "ReparoAvancado_{0}_{1}.csv" -f $env:COMPUTERNAME, (Get-Date -Format "yyyyMMdd_HHmmss")
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
