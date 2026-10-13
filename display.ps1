# ============================================================================
# MeuTweaker - display.ps1
# Leitura e ajuste da taxa de atualizacao (Hz) do monitor primario via P/Invoke
# do Win32 (EnumDisplaySettings/ChangeDisplaySettings). Nao exige admin.
# ============================================================================

$script:TipoDisplayAdicionado = $false

function Adicionar-TipoDisplay {
    if ($script:TipoDisplayAdicionado) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class MTDisp {
  [DllImport("user32.dll")] public static extern bool EnumDisplaySettings(string dev, int mode, ref DEVMODE dm);
  [DllImport("user32.dll")] public static extern int ChangeDisplaySettings(ref DEVMODE dm, int flags);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
  public struct DEVMODE {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmDeviceName;
    public short dmSpecVersion; public short dmDriverVersion; public short dmSize; public short dmDriverExtra;
    public int dmFields; public int dmPositionX; public int dmPositionY; public int dmDisplayOrientation; public int dmDisplayFixedOutput;
    public short dmColor; public short dmDuplex; public short dmYResolution; public short dmTTOption; public short dmCollate;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=32)] public string dmFormName;
    public short dmLogPixels; public int dmBitsPerPel; public int dmPelsWidth; public int dmPelsHeight;
    public int dmDisplayFlags; public int dmDisplayFrequency;
    public int dmICMMethod; public int dmICMIntent; public int dmMediaType; public int dmDitherType;
    public int dmReserved1; public int dmReserved2; public int dmPanningWidth; public int dmPanningHeight;
  }
}
'@
    $script:TipoDisplayAdicionado = $true
}

function Get-InfoMonitor {
    Adicionar-TipoDisplay
    $dm = New-Object MTDisp+DEVMODE
    $dm.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type]'MTDisp+DEVMODE')
    if (-not [MTDisp]::EnumDisplaySettings('\\.\DISPLAY1', -1, [ref]$dm)) { return $null }
    $largura = $dm.dmPelsWidth; $altura = $dm.dmPelsHeight; $atual = $dm.dmDisplayFrequency; $maximo = $atual
    $i = 0
    $sonda = New-Object MTDisp+DEVMODE
    $sonda.dmSize = $dm.dmSize
    while ([MTDisp]::EnumDisplaySettings('\\.\DISPLAY1', $i, [ref]$sonda)) {
        if ($sonda.dmPelsWidth -eq $largura -and $sonda.dmPelsHeight -eq $altura -and $sonda.dmDisplayFrequency -gt $maximo) {
            $maximo = $sonda.dmDisplayFrequency
        }
        $i++
    }
    return @{ largura = $largura; altura = $altura; atual = $atual; maximo = $maximo }
}

function Set-HzMonitor([int]$hz) {
    if ($hz -lt 24 -or $hz -gt 1000) { return @{ ok = $false; detail = 'Hz invalido.' } }
    Adicionar-TipoDisplay
    $dm = New-Object MTDisp+DEVMODE
    $dm.dmSize = [System.Runtime.InteropServices.Marshal]::SizeOf([type]'MTDisp+DEVMODE')
    if (-not [MTDisp]::EnumDisplaySettings('\\.\DISPLAY1', -1, [ref]$dm)) { return @{ ok = $false; detail = 'Nao foi possivel ler o monitor.' } }
    $dm.dmDisplayFrequency = $hz
    $dm.dmFields = $dm.dmFields -bor 0x400000  # DM_DISPLAYFREQUENCY
    $codigo = [MTDisp]::ChangeDisplaySettings([ref]$dm, 1)  # CDS_UPDATEREGISTRY
    return @{ ok = ($codigo -eq 0); detail = if ($codigo -eq 0) { 'OK' } else { "ChangeDisplaySettings retornou $codigo" } }
}
