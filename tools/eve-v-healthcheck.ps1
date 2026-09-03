<#
  eve-v-healthcheck.ps1
  Identifies an Eve V (2017) and checks every known software-fixable issue.
  Writes a Markdown report next to the script and prints it.

  Run:  powershell -NoProfile -ExecutionPolicy Bypass -File eve-v-healthcheck.ps1
  No admin required (a few checks say "needs admin" if not elevated).

  Part of: Eve V (2017) Community Knowledge Base
#>

$ErrorActionPreference = 'SilentlyContinue'
$out  = New-Object System.Text.StringBuilder
$dir  = Split-Path -Parent $MyInvocation.MyCommand.Path
$file = Join-Path $dir ("eve-v-report_{0:yyyyMMdd_HHmmss}.md" -f (Get-Date))

function H  ($t) { [void]$out.AppendLine("`n## $t`n") }
function L  ($t) { [void]$out.AppendLine($t) }
function KV ($k,$v) { [void]$out.AppendLine(("- **{0}:** {1}" -f $k,$v)) }
function OK ($t) { [void]$out.AppendLine("- [x] $t") }
function WARN ($t) { [void]$out.AppendLine("- [ ] :warning: $t") }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

L "# Eve V health check"
L ("_generated {0}  |  admin: {1}_" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $admin)

# ---------------------------------------------------------------- identity
H "Identity"
$cs  = Get-CimInstance Win32_ComputerSystem
$cpu = (Get-CimInstance Win32_Processor).Name
$bios= Get-CimInstance Win32_BIOS
$ram = Get-CimInstance Win32_PhysicalMemory
$ramGB = [math]::Round((($ram | Measure-Object Capacity -Sum).Sum)/1GB)
$disk = Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -match 'Fixed|SSD' -or $_.Model }
$mon = Get-CimInstance -Namespace root\wmi WmiMonitorID | Select-Object -First 1
$panel = if ($mon) { (-join ($mon.ManufacturerName | ? {$_} | % {[char]$_})) + ' ' + (-join ($mon.ProductCodeID | ? {$_} | % {[char]$_})) + "  (yr $($mon.YearOfManufacture) wk $($mon.WeekOfManufacture))" } else { 'n/a' }
$digi = Get-PnpDevice -Class HIDClass | Where-Object { $_.FriendlyName -match 'pen' -and $_.InstanceId -match 'HID' } | Select-Object -First 1

KV 'System'        ("{0} {1} (family {2}, SKU {3})" -f $cs.Manufacturer,$cs.Model,$cs.SystemFamily,$cs.SystemSKUNumber)
KV 'CPU'           $cpu
KV 'RAM'           ("{0} GB, {1} sticks @ {2} MT/s" -f $ramGB, $ram.Count, ($ram | Select-Object -First 1).Speed)
KV 'SSD'           (($disk | ForEach-Object { "{0} ({1} GB)" -f $_.Model, [math]::Round($_.Size/1GB) }) -join '; ')
KV 'Display panel' $panel
KV 'BIOS'          ("{0}  ({1:yyyy-MM-dd})" -f $bios.SMBIOSBIOSVersion, $bios.ConvertToDateTime($bios.ReleaseDate))

$config = switch -Regex ($cpu) { '7Y75' {'i7 (top): 16 GB / 512 GB'} '7Y54' {'i5: 8 GB / 256 GB'} '7Y30' {'m3: 8 GB / 128 GB'} default {'unknown'} }
KV 'Config'        $config

if ($digi) {
    $hw = (Get-PnpDeviceProperty -InstanceId $digi.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds').Data -join ' '
    if ($hw -match '04F3|200A') { KV 'Digitizer' 'ELAN (04F3:200A) -> buy an **MPP** pen (Surface Pen 1776 / Metapen M1). ~2048 pressure, no tilt.' }
    elseif ($hw -match 'WACF|WCOM') { KV 'Digitizer' 'Wacom AES -> Wacom Bamboo Ink (CS-323) etc.' }
    else { KV 'Digitizer' "unrecognised: $hw" }
}
KV 'BIOS note' '5.12 is the final BIOS. If yours is older, that is the only worthwhile BIOS update.'

# ---------------------------------------------------------------- fast startup
H "Fast Startup / cold boot (issue 2.1)"
$hbe = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled).HiberbootEnabled
$lastboot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
$bootAge = [int]((Get-Date) - $lastboot).TotalDays
KV 'HiberbootEnabled' $hbe
KV 'LastBootUpTime'   ("{0}  ({1} days ago)" -f $lastboot, $bootAge)
if ($hbe -ne 0) { WARN "Fast Startup is ON. Set HiberbootEnabled=0 (admin) and do one full shutdown. See issue 2.1." }
else { OK "Fast Startup disabled." }
if ($bootAge -gt 20 -and $hbe -ne 0) { WARN "No real cold boot in $bootAge days - very likely stale hybrid state." }

# ---------------------------------------------------------------- fingerprint
H "Fingerprint reader (issue 2.2)"
$fp = Get-PnpDevice | Where-Object { $_.FriendlyName -match 'Goodix|Fingerprint' } | Select-Object -First 1
if ($fp) {
    KV 'Device' ("{0}  [{1} / {2}]" -f $fp.FriendlyName, $fp.Status, $fp.Problem)
    $fpCrash = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-DriverFrameworks-UserMode'; Id=10110,10111; StartTime=(Get-Date).AddDays(-7)} | Where-Object { $_.Message -match 'Goodix|GXFP' }
    if ($fp.Problem -eq 'CM_PROB_DISABLED') { OK "Already disabled (stops the driver crash loop)." }
    elseif ($fp.Status -ne 'OK') {
        WARN "Not working ($($fp.Problem))."
        if ($fpCrash) { WARN "Driver crashed $($fpCrash.Count)x in the last 7 days. Disable-PnpDevice to stop it. See issue 2.2." }
    } else { OK "Working." }
} else { L "- no Goodix device found" }

# ---------------------------------------------------------------- filesystem / SSD
H "Filesystem / SSD (issue 2.3)"
$dirty = if ($admin) { (& fsutil dirty query C: 2>&1) } else { 'needs admin' }
KV 'C: dirty bit' $dirty
$id7 = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='disk'; Id=7; StartTime=(Get-Date).AddDays(-60)}
if ($id7) { WARN "$($id7.Count) 'bad block' (disk ID 7) events in 60 days, latest $($id7[0].TimeCreated). Run 'chkdsk C: /scan'. See issue 2.3." }
else { OK "No disk ID-7 events in 60 days." }
$ntfs = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Ntfs'; Id=98; StartTime=(Get-Date).AddDays(-30)} | Where-Object { $_.LevelDisplayName -in 'Error','Warning' }
if ($ntfs) { WARN "NTFS flagged C: for repair ($($ntfs[0].TimeCreated)). Back up, then 'chkdsk C: /f' + reboot." }
$rel = Get-PhysicalDisk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
if ($rel) { KV 'SSD wear / temp' ("wear {0}% / {1} C" -f $rel.Wear, $rel.Temperature) }

# ---------------------------------------------------------------- drivers
H "Driver versions (issues 2.4 / 2.5)"
$drv = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceName -match 'Wireless-AC 8265|Realtek High Definition Audio|HD Graphics 615|Goodix' }
foreach ($d in $drv) { KV $d.DeviceName ("{0}  ({1})" -f $d.DriverVersion, $d.DriverDate) }
$wl = $drv | Where-Object DeviceName -match '8265'
if ($wl -and [version]($wl.DriverVersion) -lt [version]'22.0.0.0') { WARN "Wi-Fi driver is old ($($wl.DriverVersion)). Update to Intel 22.x + disable adapter power saving. Issue 2.4." }
$au = $drv | Where-Object DeviceName -match 'Realtek High Definition'
if ($au -and $au.DriverDate -lt (Get-Date '2020-01-01')) { WARN "Realtek audio driver is from $($au.DriverDate.ToString('yyyy-MM')). Speakers likely thin (no smart-amp). Issue 2.5." }
$tiAmp = Get-PnpDevice | Where-Object { $_.FriendlyName -match 'Smart.*Amp|TI .*Amp|Texas Instruments' }
if (-not $tiAmp) { L "- no TI smart-amp device present -> install the Eve audio package for full speaker volume" }

# ---------------------------------------------------------------- modern standby
H "Modern Standby drain (issue 2.6)"
$ms = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Kernel-Power'; Id=506,507; StartTime=(Get-Date).AddDays(-3)}
if ($ms) {
    $enter = ($ms | Where-Object Id -eq 506).Count
    KV 'Standby enter/exit (72h)' "$enter cycles"
    if ($enter -gt 20) { WARN "Frequent standby cycling ($enter in 72h). Prefer Hibernate; check 'powercfg /requests' and wake-armed devices. Issue 2.6." }
} else { L "- no S0ix enter/exit events (S0ix may be off, or nothing logged)" }

# ---------------------------------------------------------------- battery gauge
H "Battery gauge (issue 2.7)"
$bat = Get-CimInstance Win32_Battery
if ($bat) {
    KV 'Battery' ("{0}  -  {1}% ({2})" -f $bat.Name, $bat.EstimatedChargeRemaining, @('','discharging','AC','fully charged','low','critical')[$bat.BatteryStatus])
    L "- if % jumps or shuts down early: charge to 100%, run to auto-off, repeat 2-3x to recalibrate the gauge"
}

# ---------------------------------------------------------------- USB / pogo keyboard
H "USB topology / detachable keyboard (issue 2.12, doc 03)"
$xhci = Get-PnpDevice -PresentOnly | Where-Object { $_.FriendlyName -match 'eXtensible Host Controller|xHCI' } | Select-Object -First 1
if ($xhci) {
    KV 'PCH xHCI controller' ("{0} / {1}" -f $xhci.Status, $xhci.Problem)
    if ($xhci.Status -ne 'OK') { WARN "USB host controller not healthy - whole USB stack affected. Do one full shutdown." }
} else { WARN "PCH xHCI controller not found." }
$kbd = Get-PnpDevice | Where-Object { $_.InstanceId -match 'VID_0603' }
if ($kbd) {
    foreach ($k in $kbd) { KV 'Eve keyboard (VID_0603)' ("{0}  [{1}/{2}]" -f $k.InstanceId, $k.Status, $k.Problem) }
} else {
    WARN "Eve keyboard (VID_0603) not present. If attached and still absent: use tools/PogoWatch to check for any electrical signal on connect, then see doc 03."
}
$oc = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-USB-USBHUB3'} | Where-Object { $_.Id -in 34,35 -or $_.Message -match 'over.?current|power limit|exceeded' }
if ($oc) { WARN "USB over-current / power-limit events found ($($oc.Count)) - possible past short on a port. See doc 03 step 3." }
else { OK "No USB over-current events on record." }

# ---------------------------------------------------------------- other problem devices
H "Other problem devices"
$bad = Get-PnpDevice -PresentOnly | Where-Object { $_.Status -eq 'Error' -and $_.Problem -ne 'CM_PROB_DISABLED' } | Select-Object Class,FriendlyName,Problem
if ($bad) { $bad | ForEach-Object { WARN ("{0}  ({1})  - {2}" -f $_.FriendlyName, $_.Class, $_.Problem) } }
else { OK "No devices in an error state (disabled devices ignored)." }

# ---------------------------------------------------------------- write + show
L "`n---`n_Eve V (2017) Community Knowledge Base - issue numbers refer to docs/02-known-issues-and-fixes.md_"
$out.ToString() | Set-Content -LiteralPath $file -Encoding UTF8
Write-Host $out.ToString()
Write-Host "`nReport saved: $file" -ForegroundColor Green
