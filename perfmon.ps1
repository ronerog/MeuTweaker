# ============================================================================
# MeuTweaker - perfmon.ps1
# Medidor de desempenho (estilo Gerenciador de Tarefas simplificado), via
# contadores de desempenho do Windows (CIM). Nao exige admin.
# ============================================================================

function Get-InfoEstaticaDesempenho {
    $ErrorActionPreference = 'SilentlyContinue'
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $mem = @(Get-CimInstance Win32_PhysicalMemory)
    $gpus = @(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -and ($_.AdapterRAM -gt 0 -or $_.CurrentRefreshRate -gt 0) })
    $mapaTipo = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 34 = 'DDR5' }
    $tipoRam = if ($mem.Count -gt 0) { $mapaTipo[[int]$mem[0].SMBIOSMemoryType] } else { '' }
    return @{
        cpuNome    = $(if ($cpu) { $cpu.Name.Trim() } else { 'Desconhecido' })
        nucleos    = $cpu.NumberOfCores
        logicos    = $cpu.NumberOfLogicalProcessors
        ramTotalGb = [math]::Round((($mem | Measure-Object Capacity -Sum).Sum) / 1GB, 0)
        tipoRam    = $tipoRam
        gpuNome    = $(if ($gpus.Count) { $gpus[0].Name.Trim() } else { $null })
    }
}

function Get-AmostraDesempenho {
    $ErrorActionPreference = 'SilentlyContinue'
    $cpu  = Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
    $mem  = Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory | Select-Object -First 1
    $disc = Get-CimInstance Win32_PerfFormattedData_PerfDisk_PhysicalDisk | Where-Object { $_.Name -eq '_Total' } | Select-Object -First 1
    $net  = @(Get-CimInstance Win32_PerfFormattedData_Tcpip_NetworkInterface)
    $ge   = @(Get-CimInstance Win32_PerfFormattedData_GPUPerformanceCounters_GPUEngine -ErrorAction SilentlyContinue | Where-Object { $_.Name -like '*engtype_3D*' })
    $netR = ($net | Measure-Object -Property BytesReceivedPersec -Sum).Sum
    $netS = ($net | Measure-Object -Property BytesSentPersec -Sum).Sum
    $gpu  = if ($ge.Count) { ($ge | Measure-Object -Property UtilizationPercentage -Sum).Sum } else { 0 }
    return @{
        cpuPct          = [math]::Round([double]$cpu.PercentProcessorTime, 0)
        ramDisponivelMb = [int]([double]$mem.AvailableMBytes)
        discoPct        = [math]::Min(100, [math]::Round([double]$disc.PercentDiskTime, 0))
        redeRecebidoKb  = [math]::Round([double]$netR / 1KB, 0)
        redeEnviadoKb   = [math]::Round([double]$netS / 1KB, 0)
        gpuPct          = [math]::Min(100, [math]::Round([double]$gpu, 0))
    }
}
