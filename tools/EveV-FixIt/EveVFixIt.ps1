<#
  Eve V Fix-It  -  portable software repair assistant for the original Eve V (2017)

  Detects, explains, applies (with confirmation) and verifies every SOFTWARE-fixable
  issue from the Eve V (2017) Community Knowledge Base, and lists the hardware /
  firmware / manual ones with links.

  Run directly:   powershell -NoProfile -ExecutionPolicy Bypass -STA -File EveVFixIt.ps1
  Or use:         Start-EveV-FixIt.bat   (self-elevating)
  Or the built:   EveV-FixIt.exe

  Part of: https://github.com/Ollleey/eve-v-2017-kb    (docs/00-read-first.md)

  This is a community tool built from ONE unit + public sources. Findings can be
  wrong or not apply to your batch. Nothing here is an official manual.
#>

$ErrorActionPreference = 'SilentlyContinue'
$ProgressPreference    = 'SilentlyContinue'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# ============================================================ globals / paths
$script:AppName  = 'Eve V Fix-It'
$script:Version  = '1.0.0'
$script:RepoBase = 'https://github.com/Ollleey/eve-v-2017-kb/blob/main/'
$script:DataDir  = Join-Path $env:LOCALAPPDATA 'EveV-FixIt'
$script:LogDir   = Join-Path $script:DataDir 'logs'
[void][System.IO.Directory]::CreateDirectory($script:LogDir)
$script:LogFile  = Join-Path $script:LogDir ("evev-fixit_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))
$script:RebootNeeded = $false

function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
$script:IsAdmin = Test-IsAdmin

# ============================================================ logging
function Write-Log {
    param([string]$Text, [ValidateSet('info','ok','warn','err','act')]$Level = 'info')
    try { Add-Content -LiteralPath $script:LogFile -Value ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Text) } catch {}
    if ($script:LogBox) {
        $line = "[{0:HH:mm:ss}] {1}" -f (Get-Date), $Text
        $col  = switch ($Level) { 'ok' {'#4ADE80'} 'warn' {'#FBBF24'} 'err' {'#F87171'} 'act' {'#60A5FA'} default {'#C8C8C8'} }
        $act  = {
            $run = New-Object System.Windows.Documents.Run($line)
            $run.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($col)
            $par = New-Object System.Windows.Documents.Paragraph($run)
            $par.Margin = '0'; $par.LineHeight = 15
            $script:LogBox.Document.Blocks.Add($par)
            $script:LogBox.ScrollToEnd()
        }
        $script:LogBox.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]$act)
    }
}

# ============================================================ small helpers
function Get-GhAnchor {
    param([string]$Heading)
    $s = $Heading.ToLower()
    $s = $s -replace '[^\p{L}\p{N} _-]', ''
    $s = $s -replace ' ', '-'
    $s
}
function Open-Url { param([string]$Url) try { Start-Process $Url } catch { Write-Log "could not open $Url" err } }

function Open-Kb {
    param([string]$DocFile, [string]$Heading)
    $u = $script:RepoBase + 'docs/' + $DocFile
    if ($Heading) { $u += '#' + (Get-GhAnchor $Heading) }
    Open-Url $u
}

# launch a long-running command in its own visible console, non-blocking
function Start-Console {
    param([string]$Title, [string]$CmdLine)
    $full = "title $Title & echo Running: $CmdLine & echo. & $CmdLine & echo. & echo ================================================================ & echo   Finished. Close this window, go back to Eve V Fix-It, click Re-check. & echo ================================================================ & pause"
    Start-Process -FilePath $env:ComSpec -ArgumentList '/k', $full -WindowStyle Normal | Out-Null
    Write-Log "launched console: $CmdLine" act
}

function Confirm-Box {
    param([string]$Text, [string]$Caption = $script:AppName)
    [System.Windows.MessageBox]::Show($Text, $Caption, 'YesNo', 'Warning') -eq 'Yes'
}
function Info-Box { param([string]$Text) [void][System.Windows.MessageBox]::Show($Text, $script:AppName, 'OK', 'Information') }

# ============================================================ context probe (once)
function Build-Context {
    $c = @{}
    $c.IsAdmin = $script:IsAdmin
    $cs   = Get-CimInstance Win32_ComputerSystem
    $cpu  = (Get-CimInstance Win32_Processor).Name
    $bios = Get-CimInstance Win32_BIOS
    $ram  = Get-CimInstance Win32_PhysicalMemory
    $disk = Get-CimInstance Win32_DiskDrive | Where-Object { $_.MediaType -match 'Fixed|SSD' -or $_.Model }
    $mon  = Get-CimInstance -Namespace root\wmi WmiMonitorID | Select-Object -First 1

    $c.Cpu     = $cpu
    $c.RamGB   = [math]::Round((($ram | Measure-Object Capacity -Sum).Sum) / 1GB)
    $c.Ssd     = (($disk | ForEach-Object { "{0} ({1} GB)" -f $_.Model.Trim(), [math]::Round($_.Size / 1GB) }) -join '; ')
    $c.Bios    = $bios.SMBIOSBIOSVersion
    $c.BiosOld = $false
    try { $c.BiosOld = ([double]($bios.SMBIOSBIOSVersion) -lt 5.12) } catch {}
    $c.Model   = "$($cs.Manufacturer) $($cs.Model)"
    $c.Config  = switch -Regex ($cpu) { '7Y75' {'i7 / 16 GB / 512 GB'} '7Y54' {'i5 / 8 GB / 256 GB'} '7Y30' {'m3 / 8 GB / 128 GB'} default {'unknown config'} }
    $c.Panel   = if ($mon) { (-join ($mon.ManufacturerName | Where-Object { $_ } | ForEach-Object { [char]$_ })) } else { '' }

    # digitizer vendor
    $c.Digitizer = 'unknown'
    $digi = Get-PnpDevice -Class HIDClass | Where-Object { $_.FriendlyName -match 'pen' -and $_.InstanceId -match 'HID' } | Select-Object -First 1
    if ($digi) {
        $hw = (Get-PnpDeviceProperty -InstanceId $digi.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds').Data -join ' '
        if     ($hw -match '04F3|200A')  { $c.Digitizer = 'ELAN (MPP pen)' }
        elseif ($hw -match 'WACF|WCOM')  { $c.Digitizer = 'Wacom AES' }
    }

    # cached device / driver inventories
    $c.Pnp     = Get-PnpDevice
    $c.Drivers = Get-CimInstance Win32_PnPSignedDriver | Where-Object { $_.DeviceName -match 'Wireless-AC 8265|Realtek High Definition Audio|HD Graphics 615|Goodix|SCC' }
    $c.Battery = Get-CimInstance Win32_Battery
    $c
}

# ============================================================ CHECK DEFINITIONS
# Kind : Fixable | Manual | Hardware | Info
# Risk : Safe | Behaviour | Corrective | Destructive | -
# Test : {param($ctx) -> @{ State='OK'|'Warn'|'Act'|'NA'|'Manual'; Detail='...' } }
# Fix  : {param($ctx) -> @{ Ok=$bool; Note='...'; RebootToFinish=$bool } }

$script:Checks = @(

  # -------------------------------------------------- Boot & power
  @{ Id='2.1'; Name='Fast Startup / cold boot'; Group='Boot & power'; Kind='Fixable'; Risk='Safe'
     Doc='02-known-issues-and-fixes.md'; Head='2.1 Fast Startup causes stale state [confirmed]'
     Summary='Hybrid shutdown never truly cold-boots the tablet, so some devices (USB hub, etc.) stop enumerating.'
     Undo='Set HiberbootEnabled back to 1, or tick "Turn on fast startup" in Power Options.'
     Test={ param($ctx)
        $hbe = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled).HiberbootEnabled
        $age = [int]((Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime).TotalDays
        if ($hbe -ne 0) {
           $d = "Fast Startup is ON (HiberbootEnabled=$hbe). Last real boot was $age days ago."
           @{ State='Warn'; Detail=$d }
        } else { @{ State='OK'; Detail="Disabled. Last boot $age days ago." } }
     }
     Fix={ param($ctx)
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled -Value 0 -Type DWord
        $ok = ((Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' -Name HiberbootEnabled).HiberbootEnabled -eq 0)
        @{ Ok=$ok; Note='HiberbootEnabled set to 0.'; RebootToFinish=$true }
     }
     PostFix='Do ONE full shutdown (Start > Shut down, wait 10 s, power on) to complete this.' }

  @{ Id='2.6w'; Name='Random wake from sleep'; Group='Boot & power'; Kind='Fixable'; Risk='Safe'
     Doc='02-known-issues-and-fixes.md'; Head='2.6 Modern Standby drain / random wake from sleep [confirmed + community]'
     Summary='The keyboard folded over the screen keeps sending keypresses and wakes the tablet.'
     Undo='powercfg /deviceenablewake "<device name>" for each device.'
     Test={ param($ctx)
        $armed = @(powercfg /devicequery wake_armed 2>$null | Where-Object { $_ -match 'keyboard|touch|HID|mouse' })
        if ($armed.Count) { @{ State='Warn'; Detail=("Wake-armed input devices: " + ($armed -join '; ')) } }
        else { @{ State='OK'; Detail='No input devices are armed to wake the tablet.' } }
     }
     Fix={ param($ctx)
        $armed = @(powercfg /devicequery wake_armed 2>$null | Where-Object { $_ -match 'keyboard|touch|HID|mouse' })
        $done = @()
        foreach ($d in $armed) { powercfg /devicedisablewake "$d" 2>$null; $done += $d }
        @{ Ok=$true; Note=("Disabled wake for: " + ($done -join '; ')); RebootToFinish=$false }
     }
     PostFix='' }

  @{ Id='2.6l'; Name='Sleep when the cover is closed'; Group='Boot & power'; Kind='Fixable'; Risk='Behaviour'
     Doc='02-known-issues-and-fixes.md'; Head='2.6 Modern Standby drain / random wake from sleep [confirmed + community]'
     Summary='Folding the keyboard cover triggers the lid sensor and puts the tablet to sleep.'
     Undo='Power Options > Choose what closing the lid does > set back to Sleep.'
     Test={ param($ctx)
        $g='5ca83367-6e45-459f-a27b-476b1d01c936'
        $q = powercfg /query SCHEME_CURRENT SUB_BUTTONS $g 2>$null
        $ac = ($q | Select-String 'Current AC Power Setting Index:\s*0x([0-9a-f]+)').Matches.Groups[1].Value
        if ($ac -and [Convert]::ToInt32($ac,16) -eq 0) { @{ State='OK'; Detail='Lid-close action is already "Do nothing".' } }
        else { @{ State='Warn'; Detail='Lid-close currently sleeps / hibernates / shuts down the tablet.' } }
     }
     Fix={ param($ctx)
        $g='5ca83367-6e45-459f-a27b-476b1d01c936'
        powercfg /setacvalueindex SCHEME_CURRENT SUB_BUTTONS $g 0
        powercfg /setdcvalueindex SCHEME_CURRENT SUB_BUTTONS $g 0
        powercfg /setactive SCHEME_CURRENT
        @{ Ok=$true; Note='Lid-close action set to "Do nothing" (AC + battery).'; RebootToFinish=$false }
     }
     PostFix='The screen may still turn off when covered - that is separate and fine.' }

  @{ Id='2.6h'; Name='Battery drains in "sleep"'; Group='Boot & power'; Kind='Fixable'; Risk='Behaviour'
     Doc='02-known-issues-and-fixes.md'; Head='2.6 Modern Standby drain / random wake from sleep [confirmed + community]'
     Summary='Modern Standby (S0ix) draws power. Hibernate does not. This enables Hibernate so you can use it instead.'
     Undo='powercfg /h off'
     Test={ param($ctx)
        $he = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name HibernateEnabled -ErrorAction SilentlyContinue).HibernateEnabled
        if ($he -eq 1) { @{ State='OK'; Detail='Hibernate is enabled - you can use it instead of sleep.' } }
        else { @{ State='Warn'; Detail='Hibernate is disabled. Enabling it gives you a zero-drain alternative to sleep.' } }
     }
     Fix={ param($ctx)
        & powercfg /h on | Out-Null
        $he = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' -Name HibernateEnabled -ErrorAction SilentlyContinue).HibernateEnabled
        @{ Ok=($he -eq 1); Note='Hibernate enabled. Set the power button / lid to Hibernate in Power Options to use it automatically.'; RebootToFinish=$false }
     }
     PostFix='' }

  @{ Id='pw'; Name='Power diagnostic reports'; Group='Boot & power'; Kind='Fixable'; Risk='Safe'
     Doc='02-known-issues-and-fixes.md'; Head='2.6 Modern Standby drain / random wake from sleep [confirmed + community]'
     Summary='Generate sleep-study, battery and energy reports so you can see what is waking / draining the tablet.'
     Undo='Just delete the generated files.'
     Test={ param($ctx) @{ State='Manual'; Detail='On demand - click Generate to build the reports.' } }
     Fix={ param($ctx)
        $d = $script:DataDir
        powercfg /sleepstudy /output (Join-Path $d 'sleepstudy.html')  2>$null
        powercfg /batteryreport /output (Join-Path $d 'batteryreport.html') 2>$null
        powercfg /energy /output (Join-Path $d 'energy.html') /duration 20 2>$null
        Start-Process $d
        @{ Ok=$true; Note="Reports written to $d"; RebootToFinish=$false }
     }
     ActionText='Generate'; PostFix='' }

  # -------------------------------------------------- Storage
  @{ Id='2.3s'; Name='Filesystem check (read-only)'; Group='Storage'; Kind='Fixable'; Risk='Safe'
     Doc='02-known-issues-and-fixes.md'; Head='2.3 NTFS corruption after an SSD I/O event [confirmed on one unit]'
     Summary='Runs "chkdsk C: /scan" - read-only. Tells you whether the filesystem needs an offline repair.'
     Undo='n/a (read-only).'
     Test={ param($ctx)
        $id7  = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='disk'; Id=7; StartTime=(Get-Date).AddDays(-60)}
        $ntfs = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Ntfs'; Id=98; StartTime=(Get-Date).AddDays(-30)} | Where-Object { $_.LevelDisplayName -in 'Error','Warning' }
        $dirty = if ($ctx.IsAdmin) { (& fsutil dirty query C: 2>&1) -join ' ' } else { 'unknown (needs admin)' }
        $parts = @()
        if ($id7)  { $parts += "$($id7.Count) disk bad-block events in 60 days" }
        if ($ntfs) { $parts += "NTFS flagged C: for repair on $($ntfs[0].TimeCreated)" }
        if ($dirty -match 'is Dirty') { $parts += 'C: dirty bit is SET' }
        if ($parts.Count) { @{ State='Warn'; Detail=($parts -join '. ') + '. Run the scan.' } }
        else { @{ State='OK'; Detail="No recent disk/NTFS errors. Dirty bit: $dirty" } }
     }
     Fix={ param($ctx) Start-Console 'chkdsk C: /scan' 'chkdsk C: /scan'; @{ Ok=$true; Note='chkdsk /scan running in a console window. Re-check when it finishes.'; RebootToFinish=$false } }
     ActionText='Run scan'; PostFix='If it says "run chkdsk /f", use the "Offline filesystem repair" card below.' }

  @{ Id='2.3f'; Name='Offline filesystem repair (chkdsk /f)'; Group='Storage'; Kind='Fixable'; Risk='Destructive'
     Doc='02-known-issues-and-fixes.md'; Head='2.3 NTFS corruption after an SSD I/O event [confirmed on one unit]'
     Summary='Schedules "chkdsk C: /f" for the next reboot. Repairs filesystem corruption. This CANNOT be undone - back up first.'
     Undo='None - this modifies the filesystem to repair it.'
     Test={ param($ctx)
        $ntfs = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-Ntfs'; Id=98; StartTime=(Get-Date).AddDays(-30)} | Where-Object { $_.LevelDisplayName -in 'Error','Warning' }
        $dirty = if ($ctx.IsAdmin) { (& fsutil dirty query C: 2>&1) -join ' ' } else { '' }
        if (($ntfs) -or ($dirty -match 'is Dirty')) { @{ State='Act'; Detail='Windows has flagged C: for offline repair. Back up, then schedule it.' } }
        else { @{ State='OK'; Detail='Windows has not flagged C: for offline repair.' } }
     }
     Fix={ param($ctx)
        if (-not (Confirm-Box "This schedules a filesystem repair (chkdsk /f) at the next reboot.`n`nIt can take 5-20 minutes at boot and CANNOT be undone.`n`nHave you backed up your important files? Continue?")) { return @{ Ok=$false; Note='Cancelled.'; RebootToFinish=$false } }
        'Y' | & chkdsk C: /f | Out-Null
        @{ Ok=$true; Note='chkdsk /f scheduled for the next reboot.'; RebootToFinish=$true }
     }
     ActionText='Schedule repair'; Gate=$true
     PostFix='Reboot when you are ready. Do not interrupt the boot-time check.' }

  @{ Id='2.3t'; Name='SSD TRIM & defragmentation'; Group='Storage'; Kind='Fixable'; Risk='Safe'
     Doc='02-known-issues-and-fixes.md'; Head='2.3 NTFS corruption after an SSD I/O event [confirmed on one unit]'
     Summary='The Intel 600p is slow and Windows lets its filesystem fragment. Runs a safe ReTrim (+ optional defrag) and re-enables the scheduled Optimize task.'
     Undo='n/a.'
     Test={ param($ctx)
        $task = Get-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag\' -ErrorAction SilentlyContinue
        $lr   = if ($task) { (Get-ScheduledTaskInfo $task).LastTaskResult } else { $null }
        if ($task -and $task.State -eq 'Disabled') { @{ State='Warn'; Detail='The scheduled "Optimize Drives" task is disabled.' } }
        elseif ($lr -ne $null -and $lr -ne 0)      { @{ State='Warn'; Detail="Optimize task last result: 0x{0:X}" -f $lr } }
        else { @{ State='OK'; Detail='Scheduled optimization is enabled. Run ReTrim any time.' } }
     }
     Fix={ param($ctx)
        try { Enable-ScheduledTask -TaskName 'ScheduledDefrag' -TaskPath '\Microsoft\Windows\Defrag\' -ErrorAction SilentlyContinue | Out-Null } catch {}
        Start-Console 'Optimize-Volume C: -ReTrim -Verbose' 'powershell -NoProfile -Command "Optimize-Volume -DriveLetter C -ReTrim -Verbose"'
        @{ Ok=$true; Note='Optimize task enabled; ReTrim running in a console window.'; RebootToFinish=$false }
     }
     ActionText='Run ReTrim'; PostFix='For heavy fragmentation you can also run "Optimize-Volume -DriveLetter C -Defrag" (safe, Wear was 0%).' }

  # -------------------------------------------------- Input
  @{ Id='2.2'; Name='Fingerprint driver crash loop'; Group='Input'; Kind='Fixable'; Risk='Behaviour'
     Doc='02-known-issues-and-fixes.md'; Head='2.2 Goodix fingerprint reader — driver crash loop [confirmed]'
     Summary='The Goodix driver crashes on every boot and resume. Disabling the device stops that. The sensor is usually dead hardware anyway.'
     Undo='Device Manager > Biometric devices > Goodix > Enable device.'
     Test={ param($ctx)
        $fp = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'Goodix|Fingerprint' } | Select-Object -First 1
        if (-not $fp) { return @{ State='NA'; Detail='No Goodix device present.' } }
        if ($fp.Problem -eq 'CM_PROB_DISABLED') { return @{ State='OK'; Detail='Already disabled - the crash loop is stopped.' } }
        if ($fp.Status -eq 'OK') { return @{ State='OK'; Detail='Working normally.' } }
        $cr = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-DriverFrameworks-UserMode'; Id=10110,10111; StartTime=(Get-Date).AddDays(-7)} | Where-Object { $_.Message -match 'Goodix|GXFP' }
        $d = "Not working ($($fp.Problem))."
        if ($cr) { $d += " Driver crashed $($cr.Count)x in the last 7 days." }
        @{ State='Warn'; Detail=$d }
     }
     Fix={ param($ctx)
        if (-not (Confirm-Box "Disable the fingerprint reader device?`n`nThis stops the driver crash loop. The sensor is almost certainly dead hardware. You can re-enable it in Device Manager.")) { return @{ Ok=$false; Note='Cancelled.'; RebootToFinish=$false } }
        $fp = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'Goodix|Fingerprint' } | Select-Object -First 1
        Disable-PnpDevice -InstanceId $fp.InstanceId -Confirm:$false
        $now = (Get-PnpDevice -InstanceId $fp.InstanceId).Problem
        @{ Ok=($now -eq 'CM_PROB_DISABLED'); Note="Fingerprint device now: $now"; RebootToFinish=$false }
     }
     Gate=$true; PostFix='' }

  @{ Id='2.11'; Name='Pen / touch dead after a Windows update'; Group='Input'; Kind='Fixable'; Risk='Behaviour'
     Doc='02-known-issues-and-fixes.md'; Head='2.11 Digitizer — less sensitive; dead pen/touch after a Windows upgrade [reported + community]'
     Summary='On Wacom-batch units a Windows upgrade can break the pen driver. Removing it lets Windows bind a working generic HID driver (Eve-staff-confirmed).'
     Undo='The rescan re-installs a driver automatically; nothing to undo.'
     Test={ param($ctx)
        $wac = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'Wacom' -and $_.Status -eq 'Error' }
        $pen = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'HID-compliant pen' -and $_.Status -eq 'OK' }
        if ($wac)      { @{ State='Act';  Detail="A Wacom device failed to start: $($wac[0].FriendlyName)" } }
        elseif ($pen)  { @{ State='OK';   Detail='HID pen device is present and OK.' } }
        else           { @{ State='NA';   Detail='No failed Wacom device and no HID pen - probably an ELAN unit (fine) or no pen hardware.' } }
     }
     Fix={ param($ctx)
        $wac = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'Wacom' }
        if (-not $wac) { return @{ Ok=$false; Note='No Wacom device to reset.'; RebootToFinish=$false } }
        if (-not (Confirm-Box "Remove the Wacom pen/touch device and let Windows re-detect it?`n`nInput may be missing for a few seconds.")) { return @{ Ok=$false; Note='Cancelled.'; RebootToFinish=$false } }
        foreach ($w in $wac) { & pnputil /remove-device $w.InstanceId 2>$null }
        & pnputil /scan-devices 2>$null
        Start-Sleep 2
        $ok = [bool]((Get-PnpDevice) | Where-Object { $_.FriendlyName -match 'HID-compliant pen|HID-compliant touch screen' -and $_.Status -eq 'OK' })
        @{ Ok=$ok; Note='Wacom device removed and re-scanned.'; RebootToFinish=$false }
     }
     Gate=$true; PostFix='If touch is still missing, reboot once.' }

  # -------------------------------------------------- Drivers
  @{ Id='2.4p'; Name='Wi-Fi adapter power saving'; Group='Drivers & radios'; Kind='Fixable'; Risk='Safe'
     Doc='02-known-issues-and-fixes.md'; Head='2.4 Intel Wireless-AC 8265 — old driver, drops, power-transition errors [confirmed]'
     Summary='Stops Windows powering down the Intel 8265 - a common cause of Wi-Fi drops on this tablet.'
     Undo='Device Manager > the 8265 > Power Management > re-tick the box.'
     Test={ param($ctx)
        $nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match '8265' } | Select-Object -First 1
        if (-not $nic) { return @{ State='NA'; Detail='No Intel 8265 adapter found.' } }
        $pm = Get-NetAdapterPowerManagement -Name $nic.Name
        if ($pm.AllowComputerToTurnOffDevice -eq 'Disabled') { @{ State='OK'; Detail='Power-down is already disabled.' } }
        else { @{ State='Warn'; Detail='Windows is allowed to power down the Wi-Fi adapter.' } }
     }
     Fix={ param($ctx)
        $nic = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match '8265' } | Select-Object -First 1
        Set-NetAdapterPowerManagement -Name $nic.Name -AllowComputerToTurnOffDevice Disabled
        $ok = (Get-NetAdapterPowerManagement -Name $nic.Name).AllowComputerToTurnOffDevice -eq 'Disabled'
        @{ Ok=$ok; Note='Wi-Fi adapter power-down disabled.'; RebootToFinish=$false }
     }
     PostFix='' }

  @{ Id='2.4v'; Name='Wi-Fi driver is old'; Group='Drivers & radios'; Kind='Manual'; Risk='-'
     Doc='06-drivers-and-bios.md'; Head='Driver versions worth updating (seen stale on a 2021-imaged unit)'
     Summary='The in-box 8265 driver is old (20.7x). Intel 22.x fixes drops. Cannot be auto-installed - get it from Intel.'
     Test={ param($ctx)
        $wl = $ctx.Drivers | Where-Object DeviceName -match '8265'
        if (-not $wl) { return @{ State='NA'; Detail='No 8265 driver info.' } }
        try { if ([version]$wl.DriverVersion -lt [version]'22.0.0.0') { return @{ State='Manual'; Detail="Installed: $($wl.DriverVersion) ($($wl.DriverDate)). Update to Intel 22.x." } } } catch {}
        @{ State='OK'; Detail="Installed: $($wl.DriverVersion) - current enough." }
     } }

  @{ Id='2.5'; Name='Speakers sound thin / quiet'; Group='Drivers & radios'; Kind='Manual'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.5 Speakers sound thin / quiet [reported + confirmed drivers old]'
     Summary='The Realtek driver is from 2018 and the TI smart-amp component is missing. Needs the Eve V audio package (community mirror).'
     Test={ param($ctx)
        $au = $ctx.Drivers | Where-Object DeviceName -match 'Realtek High Definition'
        $amp = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'Smart.*Amp|Texas Instruments' }
        if ($amp) { return @{ State='OK'; Detail='A smart-amp device is present.' } }
        $d = 'No TI smart-amp device present -> speakers likely thin.'
        if ($au) { $d = "Realtek driver from $($au.DriverDate.ToString('yyyy-MM')); no smart-amp device. " + $d }
        @{ State='Manual'; Detail=$d }
     } }

  # -------------------------------------------------- Windows health
  @{ Id='sdm'; Name='Windows component store'; Group='Windows health'; Kind='Fixable'; Risk='Corrective'
     Doc='02-known-issues-and-fixes.md'; Head='2.3 NTFS corruption after an SSD I/O event [confirmed on one unit]'
     Summary='Repairs a corrupted Windows component store (a common cause of failed updates). Non-destructive; needs internet; ~15-30 min.'
     Undo='None needed - this only repairs Windows to its intended state.'
     Test={ param($ctx)
        if (-not $ctx.IsAdmin) { return @{ State='Manual'; Detail='Run as administrator to check the component store.' } }
        $r = & dism.exe /online /cleanup-image /checkhealth 2>&1
        if ($r -match 'repairable') { @{ State='Warn'; Detail='DISM reports the component store is repairable (corruption present).' } }
        elseif ($r -match 'No component store corruption') { @{ State='OK'; Detail='No component store corruption.' } }
        else { @{ State='OK'; Detail=(($r | Select-Object -Last 2) -join ' ') } }
     }
     Fix={ param($ctx)
        Start-Console 'DISM /Online /Cleanup-Image /RestoreHealth  +  sfc /scannow' 'DISM /Online /Cleanup-Image /RestoreHealth & echo. & sfc /scannow'
        @{ Ok=$true; Note='DISM RestoreHealth + sfc /scannow running in a console window. This takes a while. Re-check when done.'; RebootToFinish=$false }
     }
     ActionText='Repair now'; PostFix='After it finishes, re-check for Windows updates.' }

  @{ Id='wu'; Name='Windows Update stuck / failing'; Group='Windows health'; Kind='Fixable'; Risk='Corrective'
     Doc='06-drivers-and-bios.md'; Head='Drivers - where to get them now'
     Summary='Clears the Windows Update cache and re-triggers a scan. Windows re-downloads what it needs.'
     Undo='Rename SoftwareDistribution.old back, or just let Windows rebuild it.'
     Test={ param($ctx)
        $f = Get-WinEvent -FilterHashtable @{LogName='System'; ProviderName='Microsoft-Windows-WindowsUpdateClient'; Level=2; StartTime=(Get-Date).AddDays(-30)}
        if ($f) { @{ State='Warn'; Detail="$($f.Count) update failures in the last 30 days (latest $($f[0].TimeCreated))." } }
        else { @{ State='OK'; Detail='No update failures logged in 30 days.' } }
     }
     Fix={ param($ctx)
        if (-not (Confirm-Box "Reset the Windows Update cache?`n`nStops the update services, renames the SoftwareDistribution folder, restarts them and starts a scan. Safe - Windows rebuilds it.")) { return @{ Ok=$false; Note='Cancelled.'; RebootToFinish=$false } }
        Stop-Service wuauserv,bits -Force
        $sd = Join-Path $env:WINDIR 'SoftwareDistribution'
        if (Test-Path $sd) { try { Rename-Item $sd "$sd.old_$(Get-Date -f yyyyMMddHHmmss)" -Force } catch {} }
        Start-Service bits,wuauserv
        Start-Process (Join-Path $env:WINDIR 'System32\UsoClient.exe') -ArgumentList 'StartScan' -WindowStyle Hidden
        @{ Ok=$true; Note='Update cache reset; a scan was started. Check Settings > Windows Update in a few minutes.'; RebootToFinish=$false }
     }
     ActionText='Reset & rescan'; Gate=$true; PostFix='' }

  # -------------------------------------------------- Performance
  @{ Id='8.8'; Name='Memory Integrity blocks undervolting'; Group='Performance'; Kind='Fixable'; Risk='Behaviour'
     Doc='08-community-findings.md'; Head='8.8 Undervolting'
     Summary='XTU / ThrottleStop undervolting (which reduces the fanless throttling) needs Core Isolation "Memory Integrity" turned OFF. That is a security downgrade - only do this if you will undervolt.'
     Undo='Turn Memory Integrity back on in Windows Security > Device security > Core isolation, then reboot.'
     Test={ param($ctx)
        $e = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -ErrorAction SilentlyContinue).Enabled
        if ($e -eq 1) { @{ State='Manual'; Detail='Memory Integrity is ON. Undervolting tools will refuse to apply offsets until it is off.' } }
        else { @{ State='OK'; Detail='Memory Integrity is off - undervolting tools can run.' } }
     }
     Fix={ param($ctx)
        if (-not (Confirm-Box "Turn OFF Core Isolation - Memory Integrity?`n`nThis is a real security feature. Only do this if you are going to undervolt the CPU with Intel XTU / ThrottleStop. Requires a reboot. You can turn it back on any time.")) { return @{ Ok=$false; Note='Cancelled.'; RebootToFinish=$false } }
        New-Item 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Force | Out-Null
        Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' -Name Enabled -Value 0 -Type DWord
        @{ Ok=$true; Note='Memory Integrity set to off. Reboot to apply, then use Intel XTU / ThrottleStop (start around -50 mV core + cache).'; RebootToFinish=$true }
     }
     Gate=$true; PostFix='Do NOT raise the power limits (PL1/PL2) - only lower the voltage.' }

  @{ Id='2.9'; Name='Thermal throttling under load'; Group='Performance'; Kind='Hardware'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.9 Thermal throttling under sustained load [confirmed]'
     Summary='Fanless 4.5 W chip. Under sustained load it drops to ~1.3 GHz. Mitigate with airflow / a cooling pad and an undervolt (see the card above).'
     Test={ param($ctx) @{ State='Manual'; Detail='Expected behaviour for this hardware. Keep it elevated for airflow; undervolt helps.' } } }

  @{ Id='2.10'; Name='Screen flicker at low brightness'; Group='Performance'; Kind='Hardware'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.10 PWM backlight flicker at low brightness [reported]'
     Summary='PWM flicker below ~25% brightness (985 Hz). Keep brightness above 25%, or disable "Display Power Saving Technology" in the Intel Graphics Command Center.'
     Test={ param($ctx) @{ State='Manual'; Detail='Hardware. Keep brightness > 25%; disable Intel DPST/CABC.' } } }

  @{ Id='2.7'; Name='Battery percentage is inaccurate'; Group='Performance'; Kind='Hardware'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.7 Battery percentage is inaccurate [confirmed]'
     Summary='The EC reports placeholder battery data. Recalibrate: charge to 100%, run to auto-off, repeat 2-3 times.'
     Test={ param($ctx)
        $b = $ctx.Battery
        if ($b) { @{ State='Manual'; Detail="Now: $($b.EstimatedChargeRemaining)%. If it jumps or shuts down early, recalibrate (charge full -> run to auto-off x2-3)." } }
        else { @{ State='NA'; Detail='No battery reported.' } }
     } }

  # -------------------------------------------------- Hardware & firmware
  @{ Id='8.1'; Name='Firmware (BIOS + 4 more components)'; Group='Hardware & firmware'; Kind='Info'; Risk='-'
     Doc='08-community-findings.md'; Head='8.1 The V has FIVE separately-updatable firmware components'
     Summary='The Eve V has five separate firmware blobs (BIOS, Battery EC, Thunderbolt NVM, Keyboard/Touchpad, Touch Panel). Flashing can permanently brick - "firmware 1.04" bricked displays. Never automated.'
     Test={ param($ctx)
        if ($ctx.BiosOld) { @{ State='Warn'; Detail="System BIOS is $($ctx.Bios). 5.12 (2017-10-31) is the final version - the only worthwhile firmware update. Read 8.1 first." } }
        else { @{ State='OK'; Detail="System BIOS $($ctx.Bios) is the final version. Do not flash the other components unless that specific part is faulty." } }
     } }

  @{ Id='2.12'; Name='Detachable keyboard dead'; Group='Hardware & firmware'; Kind='Hardware'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.12 Detachable keyboard — ribbon cable snaps at the hinge [confirmed as the common failure]'
     Summary='The ribbon cable at the hinge fold is the common failure. Not a software fix. Use the PogoWatch tool to confirm, then docs 03 / 07.'
     Test={ param($ctx)
        $kbd = $ctx.Pnp | Where-Object { $_.InstanceId -match 'VID_0603' }
        $xhci = $ctx.Pnp | Where-Object { $_.FriendlyName -match 'eXtensible Host Controller' -and $_.Status -eq 'OK' } | Select-Object -First 1
        if ($kbd -and ($kbd | Where-Object Status -eq 'OK')) { @{ State='OK'; Detail='Eve keyboard (VID_0603) is present and OK.' } }
        elseif (-not $xhci) { @{ State='Warn'; Detail='USB host controller not healthy - do one full shutdown first.' } }
        else { @{ State='Manual'; Detail='Eve keyboard not detected. If attached: hardware fault (flex cable). Use PogoWatch, then docs 03/07. Bluetooth pairing: Fn + the Bluetooth key.' } }
     } }

  @{ Id='2.17'; Name='USB-C / Thunderbolt "missing"'; Group='Hardware & firmware'; Kind='Info'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.17 The Thunderbolt / Alpine Ridge controller "disappears" [confirmed — not a fault]'
     Summary='With nothing plugged into USB-C, the Thunderbolt controller powers off the PCI bus (RTD3). That is NORMAL. Plug a USB-C device in and it comes back.'
     Test={ param($ctx)
        $ar = $ctx.Pnp | Where-Object { $_.InstanceId -match 'DEV_15DB' -or $_.FriendlyName -match 'USB 3.1 eXtensible' }
        if ($ar) { @{ State='OK'; Detail='Alpine Ridge / USB 3.1 controller is currently awake (a USB-C device is connected).' } }
        else { @{ State='OK'; Detail='Alpine Ridge is asleep (nothing in USB-C) - expected. Plug a USB-C device in to wake it. Not a fault.' } }
     } }

  @{ Id='2.8'; Name='USB-C ports feel loose'; Group='Hardware & firmware'; Kind='Hardware'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.8 USB-C ports sit slightly loose [reported]'
     Summary='Slanted chassis edges leave the Type-C ports a little loose. Blow out lint, use a cable with a longer/slimmer connector, avoid side load.'
     Test={ param($ctx) @{ State='Manual'; Detail='Hardware / mechanical. No software check.' } } }

  @{ Id='2.14'; Name='Clock / BIOS settings reset'; Group='Hardware & firmware'; Kind='Hardware'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.14 RTC / CMOS backup cell [theory, watch for it]'
     Summary='If the clock or BIOS settings reset after days unplugged and off, the RTC backup cell is flat. Replacement needs a teardown.'
     Test={ param($ctx) @{ State='Manual'; Detail='Test: fully power off + unplug for 2-3 days, then check the clock.' } } }

  @{ Id='2.16'; Name='Boots into EFI Shell'; Group='Hardware & firmware'; Kind='Info'; Risk='-'
     Doc='02-known-issues-and-fixes.md'; Head='2.16 EFI Shell on boot / SSD not seen at POST [community]'
     Summary='If you land in the EFI Shell instead of Windows: reboot -> Esc at the logo -> Fn+F3 (load defaults) + Fn+F4 (save & exit), or set Boot Option #1 = Windows Boot Manager.'
     Test={ param($ctx) @{ State='Manual'; Detail='Recovery steps only - see the KB. BIOS keys: Esc to enter, Fn+F3 defaults, Fn+F4 save & exit.' } } }
)

# ============================================================ XAML
[xml]$xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Eve V Fix-It" Height="720" Width="880" MinHeight="500" MinWidth="680"
        WindowStartupLocation="Manual" Background="#FF16171A"
        FontFamily="Segoe UI Variable Text, Segoe UI" FontSize="13" TextOptions.TextFormattingMode="Ideal">
  <Window.Resources>
    <SolidColorBrush x:Key="Card"   Color="#FF212227"/>
    <SolidColorBrush x:Key="Card2"  Color="#FF2A2C33"/>
    <SolidColorBrush x:Key="Ink"    Color="#FFECECEC"/>
    <SolidColorBrush x:Key="Sub"    Color="#FF9A9AA5"/>
    <SolidColorBrush x:Key="Accent" Color="#FF3B82F6"/>
    <Style TargetType="Button">
      <Setter Property="Background" Value="{StaticResource Card2}"/>
      <Setter Property="Foreground" Value="{StaticResource Ink}"/>
      <Setter Property="BorderThickness" Value="0"/>
      <Setter Property="Padding" Value="14,7"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="FontWeight" Value="SemiBold"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="Button">
            <Border x:Name="b" Background="{TemplateBinding Background}" CornerRadius="7" Padding="{TemplateBinding Padding}">
              <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="Opacity" Value="0.85"/></Trigger>
              <Trigger Property="IsEnabled" Value="False"><Setter TargetName="b" Property="Opacity" Value="0.35"/></Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style x:Key="Primary" TargetType="Button" BasedOn="{StaticResource {x:Type Button}}">
      <Setter Property="Background" Value="{StaticResource Accent}"/>
      <Setter Property="Foreground" Value="White"/>
    </Style>
  </Window.Resources>

  <Grid Margin="0">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <!-- header -->
    <Border Grid.Row="0" Background="#FF1B1C20" Padding="22,16">
      <StackPanel>
        <StackPanel Orientation="Horizontal">
          <TextBlock Text="Eve V Fix-It" Foreground="{StaticResource Ink}" FontSize="20" FontWeight="Bold"/>
          <TextBlock x:Name="VerText" Foreground="{StaticResource Sub}" FontSize="12" Margin="8,6,0,0"/>
          <Border x:Name="AdminPill" Background="#33F87171" CornerRadius="9" Padding="8,2" Margin="12,3,0,0" Visibility="Collapsed">
            <TextBlock Text="not elevated - fixes disabled" Foreground="#FFF87171" FontSize="11"/>
          </Border>
        </StackPanel>
        <TextBlock x:Name="IdentText" Foreground="{StaticResource Sub}" Margin="0,4,0,0"/>
      </StackPanel>
    </Border>

    <!-- toolbar -->
    <Border Grid.Row="1" Background="#FF16171A" Padding="22,10">
      <StackPanel Orientation="Horizontal">
        <Button x:Name="BtnRescan"  Content="Re-check all"/>
        <Button x:Name="BtnFixAll"  Content="Fix all safe items" Style="{StaticResource Primary}" Margin="10,0,0,0"/>
        <Button x:Name="BtnReport"  Content="Export report" Margin="10,0,0,0"/>
        <Button x:Name="BtnLogs"    Content="Open logs" Margin="10,0,0,0"/>
        <Button x:Name="BtnReboot"  Content="Restart now" Margin="10,0,0,0" Visibility="Collapsed"/>
        <ProgressBar x:Name="Prog" Width="160" Height="8" Margin="14,0,0,0" Visibility="Collapsed"
                     Background="#FF2A2C33" Foreground="{StaticResource Accent}" BorderThickness="0"/>
      </StackPanel>
    </Border>

    <!-- cards -->
    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto" Padding="22,8,22,8">
      <StackPanel x:Name="CardHost"/>
    </ScrollViewer>

    <!-- log -->
    <Expander Grid.Row="3" Header="Activity log" Foreground="{StaticResource Sub}" Background="#FF16171A"
              Padding="22,4" IsExpanded="False" BorderThickness="0">
      <RichTextBox x:Name="LogBox" Height="150" Margin="22,4,22,10" IsReadOnly="True"
                   Background="#FF0F1012" Foreground="#FFC8C8C8" BorderThickness="0"
                   FontFamily="Consolas" FontSize="12" VerticalScrollBarVisibility="Auto">
        <RichTextBox.Resources><Style TargetType="Paragraph"><Setter Property="Margin" Value="0"/></Style></RichTextBox.Resources>
      </RichTextBox>
    </Expander>

    <!-- footer -->
    <Border Grid.Row="4" Background="#FF1B1C20" Padding="22,10">
      <TextBlock Foreground="{StaticResource Sub}" FontSize="11" TextWrapping="Wrap">
        Community tool, built from one unit + public sources. Findings can be wrong or not apply to your batch. Nothing here is an official manual.
        <Hyperlink x:Name="LinkReadFirst" Foreground="#FF60A5FA">Read first &#8594;</Hyperlink>
      </TextBlock>
    </Border>
  </Grid>
</Window>
'@

$win = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml))
foreach ($n in 'VerText','IdentText','AdminPill','BtnRescan','BtnFixAll','BtnReport','BtnLogs','BtnReboot','Prog','CardHost','LogBox','LinkReadFirst') {
    Set-Variable -Name $n -Value $win.FindName($n) -Scope Script
}

$script:VerText.Text  = "v$script:Version"
$script:IdentText.Text = "{0}  -  {1}  -  {2}  -  {3} digitizer  -  BIOS {4}" -f $script:Ctx.Model, $script:Ctx.Cpu.Trim(), $script:Ctx.Config, $script:Ctx.Digitizer, $script:Ctx.Bios
if (-not $script:IsAdmin) { $script:AdminPill.Visibility = 'Visible' }

# ============================================================ card rendering
$script:PillColors = @{
    Checking = @('#332A2C33','#FF9A9AA5','Checking...')
    OK       = @('#3334D399','#FF34D399','OK')
    Warn     = @('#33FBBF24','#FFFBBF24','Needs attention')
    Act      = @('#33F87171','#FFF87171','Action needed')
    NA       = @('#22FFFFFF','#FF7A7A85','Not applicable')
    Manual   = @('#333B82F6','#FF60A5FA','Manual')
    Fixed    = @('#3334D399','#FF34D399','Fixed')
    Reboot   = @('#333B82F6','#FF60A5FA','Applied - reboot to finish')
    Working  = @('#33FBBF24','#FFFBBF24','Working...')
}

function Set-Pill {
    param($check, [string]$key, [string]$overrideText)
    $c = $script:PillColors[$key]
    $check.UI.Pill.Background   = [System.Windows.Media.BrushConverter]::new().ConvertFromString($c[0])
    $check.UI.PillTx.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString($c[1])
    $check.UI.PillTx.Text       = if ($overrideText) { $overrideText } else { $c[2] }
}

function New-Card {
    param($check)
    $bc = [System.Windows.Media.BrushConverter]::new()

    $card = New-Object System.Windows.Controls.Border
    $card.Background = $win.FindResource('Card'); $card.CornerRadius = 10
    $card.Padding = '16'; $card.Margin = '0,0,0,10'

    $g = New-Object System.Windows.Controls.Grid
    [void]$g.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition))
    $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = 'Auto'; [void]$g.ColumnDefinitions.Add($c2)
    $card.Child = $g

    $left = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($left,0); [void]$g.Children.Add($left)

    # title row
    $tr = New-Object System.Windows.Controls.StackPanel; $tr.Orientation = 'Horizontal'
    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = $check.Name; $title.FontWeight = 'SemiBold'; $title.FontSize = 14
    $title.Foreground = $win.FindResource('Ink')
    [void]$tr.Children.Add($title)

    $pill = New-Object System.Windows.Controls.Border
    $pill.CornerRadius = 9; $pill.Padding = '9,2'; $pill.Margin = '10,0,0,0'; $pill.VerticalAlignment='Center'
    $pillTx = New-Object System.Windows.Controls.TextBlock; $pillTx.FontSize = 11
    $pill.Child = $pillTx
    [void]$tr.Children.Add($pill)
    [void]$left.Children.Add($tr)

    $sum = New-Object System.Windows.Controls.TextBlock
    $sum.Text = $check.Summary; $sum.Foreground = $win.FindResource('Sub'); $sum.TextWrapping = 'Wrap'
    $sum.Margin = '0,5,14,0'
    [void]$left.Children.Add($sum)

    $detail = New-Object System.Windows.Controls.TextBlock
    $detail.Foreground = $bc.ConvertFromString('#FFB9C0CC'); $detail.TextWrapping = 'Wrap'
    $detail.Margin = '0,6,14,0'; $detail.FontSize = 12
    [void]$left.Children.Add($detail)

    $post = New-Object System.Windows.Controls.TextBlock
    $post.Foreground = $bc.ConvertFromString('#FF60A5FA'); $post.TextWrapping = 'Wrap'
    $post.Margin = '0,6,14,0'; $post.FontSize = 12; $post.Visibility = 'Collapsed'
    [void]$left.Children.Add($post)

    # links row
    $lr = New-Object System.Windows.Controls.StackPanel; $lr.Orientation = 'Horizontal'; $lr.Margin = '0,8,0,0'
    $kb = New-Object System.Windows.Controls.TextBlock
    $kbl = New-Object System.Windows.Documents.Hyperlink((New-Object System.Windows.Documents.Run("Open knowledge base " + [char]0x2192)))
    $kbl.Foreground = $bc.ConvertFromString('#FF8AB4F8')
    $kbl.Add_Click({ Open-Kb $check.Doc $check.Head }.GetNewClosure())
    $kb.Inlines.Add($kbl)
    [void]$lr.Children.Add($kb)
    if ($check.Undo) {
        $u = New-Object System.Windows.Controls.TextBlock; $u.Margin='16,0,0,0'
        $ul = New-Object System.Windows.Documents.Hyperlink((New-Object System.Windows.Documents.Run("How to undo")))
        $ul.Foreground = $bc.ConvertFromString('#FF8AB4F8')
        $ul.Add_Click({ Info-Box ("Undo:`n`n" + $check.Undo) }.GetNewClosure())
        $u.Inlines.Add($ul); [void]$lr.Children.Add($u)
    }
    [void]$left.Children.Add($lr)

    # right column: action
    $right = New-Object System.Windows.Controls.StackPanel
    $right.VerticalAlignment = 'Center'; $right.Margin = '10,0,0,0'
    [System.Windows.Controls.Grid]::SetColumn($right,1); [void]$g.Children.Add($right)

    $btn = $null; $chk = $null
    if ($check.Kind -eq 'Fixable') {
        if ($check.Gate) {
            $chk = New-Object System.Windows.Controls.CheckBox
            $chk.Content = 'I have a backup'; $chk.Foreground = $win.FindResource('Sub')
            $chk.FontSize = 11; $chk.Margin = '0,0,0,6'; $chk.Visibility = 'Collapsed'
            [void]$right.Children.Add($chk)
        }
        $btn = New-Object System.Windows.Controls.Button
        $btn.Content = if ($check.ActionText) { $check.ActionText } else { 'Fix' }
        $btn.MinWidth = 110
        if ($check.Risk -eq 'Safe') { $btn.Style = $win.FindResource('Primary') }
        elseif ($check.Risk -eq 'Destructive') { $btn.Background = $bc.ConvertFromString('#FFB91C1C'); $btn.Foreground = 'White' }
        if ($check.Gate) { $btn.IsEnabled = $false; $chk.Add_Checked({ $btn.IsEnabled = $true }.GetNewClosure()); $chk.Add_Unchecked({ $btn.IsEnabled = $false }.GetNewClosure()) }
        $btn.Add_Click({ Invoke-CardFix $check }.GetNewClosure())
        if (-not $script:IsAdmin) { $btn.IsEnabled = $false }
        [void]$right.Children.Add($btn)
    }

    $check.UI = @{ Card=$card; Pill=$pill; PillTx=$pillTx; Detail=$detail; Post=$post; Btn=$btn; Chk=$chk }
    Set-Pill $check 'Checking'
    $card
}

# group headers + cards
$groups = $script:Checks | Group-Object Group
foreach ($grp in $groups) {
    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = $grp.Name.ToUpper(); $h.FontSize = 11; $h.FontWeight = 'Bold'
    $h.Foreground = [System.Windows.Media.BrushConverter]::new().ConvertFromString('#FF6B6B78')
    $h.Margin = '2,10,0,8'
    [void]$script:CardHost.Children.Add($h)
    foreach ($chk in $grp.Group) { [void]$script:CardHost.Children.Add((New-Card $chk)) }
}

# ============================================================ scan / fix engine
function Apply-TestResult {
    param($check, $res)
    if (-not $res) { $res = @{ State='NA'; Detail='(no result)' } }
    $check.UI.Detail.Text = $res.Detail
    switch ($res.State) {
        'OK'     { Set-Pill $check 'OK' }
        'Warn'   { Set-Pill $check 'Warn' }
        'Act'    { Set-Pill $check 'Act' }
        'Manual' { Set-Pill $check 'Manual' }
        default  { Set-Pill $check 'NA' }
    }
    if ($check.UI.Chk) { $check.UI.Chk.Visibility = if ($res.State -eq 'Act' -or $res.State -eq 'Warn') { 'Visible' } else { 'Collapsed' } }
}

function Invoke-CardTest {
    param($check)
    try { $r = & $check.Test $script:Ctx } catch { $r = @{ State='NA'; Detail=("check error: " + $_.Exception.Message) } }
    Apply-TestResult $check $r
    $r
}

function Invoke-CardFix {
    param($check)
    if (-not $script:IsAdmin) { Info-Box 'Run the tool as administrator to apply fixes.'; return }
    Write-Log ("FIX: {0} ({1})" -f $check.Name, $check.Id) act
    Set-Pill $check 'Working'
    if ($check.UI.Btn) { $check.UI.Btn.IsEnabled = $false }
    $win.Dispatcher.Invoke([System.Windows.Threading.DispatcherPriority]::Background, [action]{})
    try { $res = & $check.Fix $script:Ctx } catch { $res = @{ Ok=$false; Note=("fix error: " + $_.Exception.Message) } }
    if ($res.Note) { $lvl = if ($res.Ok) { 'ok' } else { 'warn' }; Write-Log ("  -> " + $res.Note) $lvl }
    if ($res.RebootToFinish) { $script:RebootNeeded = $true; $script:BtnReboot.Visibility = 'Visible' }

    # re-verify
    $t = Invoke-CardTest $check
    if ($res.Ok) {
        if ($res.RebootToFinish) { Set-Pill $check 'Reboot' } else { Set-Pill $check 'Fixed' }
        if ($check.PostFix) { $check.UI.Post.Text = $check.PostFix; $check.UI.Post.Visibility = 'Visible' }
    } elseif ($res.Note -notmatch 'Cancelled') {
        # keep whatever the re-test said
    }
    if ($check.UI.Btn) { $check.UI.Btn.IsEnabled = ($script:IsAdmin -and (-not $check.Gate -or $check.UI.Chk.IsChecked)) }
}

# staged scan via DispatcherTimer so the UI stays responsive
$script:ScanQueue = $null
$script:ScanTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(40)
$script:ScanTimer.Add_Tick({
    if (-not $script:ScanQueue -or $script:ScanQueue.Count -eq 0) {
        $script:ScanTimer.Stop(); $script:Prog.Visibility = 'Collapsed'
        $script:BtnRescan.IsEnabled = $true; $script:BtnFixAll.IsEnabled = $script:IsAdmin
        Write-Log 'scan complete' ok
        return
    }
    $check = $script:ScanQueue.Dequeue()
    Invoke-CardTest $check | Out-Null
    $script:Prog.Value = $script:Prog.Maximum - $script:ScanQueue.Count
})

function Start-Scan {
    $script:BtnRescan.IsEnabled = $false; $script:BtnFixAll.IsEnabled = $false
    foreach ($c in $script:Checks) { Set-Pill $c 'Checking' }
    $script:ScanQueue = New-Object System.Collections.Queue
    foreach ($c in $script:Checks) { $script:ScanQueue.Enqueue($c) }
    $script:Prog.Maximum = $script:ScanQueue.Count; $script:Prog.Value = 0; $script:Prog.Visibility = 'Visible'
    Write-Log 'scanning...' info
    $script:ScanTimer.Start()
}

function Fix-AllSafe {
    $safe = $script:Checks | Where-Object { $_.Kind -eq 'Fixable' -and $_.Risk -eq 'Safe' -and -not $_.Gate }
    $todo = @()
    foreach ($c in $safe) { $r = Invoke-CardTest $c; if ($r.State -in 'Warn','Act') { $todo += $c } }
    if (-not $todo) { Info-Box 'Nothing to do - all safe items are already OK.'; return }
    if (-not (Confirm-Box ("Apply these safe fixes now?`n`n - " + (($todo | ForEach-Object { $_.Name }) -join "`n - ")))) { return }
    foreach ($c in $todo) { Invoke-CardFix $c }
    Write-Log 'fix all safe: done' ok
}

function Export-Report {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine("# Eve V Fix-It report")
    [void]$sb.AppendLine("_{0}_`n" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    [void]$sb.AppendLine("- **System:** $($script:Ctx.Model) / $($script:Ctx.Cpu.Trim()) / $($script:Ctx.Config)")
    [void]$sb.AppendLine("- **Digitizer:** $($script:Ctx.Digitizer)   **BIOS:** $($script:Ctx.Bios)`n")
    foreach ($grp in ($script:Checks | Group-Object Group)) {
        [void]$sb.AppendLine("`n## $($grp.Name)`n")
        foreach ($c in $grp.Group) {
            $state = $c.UI.PillTx.Text
            $mark = if ($state -match 'OK|Fixed|Not applicable') { '- [x]' } else { '- [ ] :warning:' }
            [void]$sb.AppendLine("$mark **$($c.Name)** - $state")
            if ($c.UI.Detail.Text) { [void]$sb.AppendLine("  - $($c.UI.Detail.Text)") }
        }
    }
    [void]$sb.AppendLine("`n---`n_Eve V (2017) Community Knowledge Base - github.com/Ollleey/eve-v-2017-kb_")
    $f = Join-Path $script:DataDir ("evev-fixit-report_{0:yyyyMMdd_HHmmss}.md" -f (Get-Date))
    $sb.ToString() | Set-Content -LiteralPath $f -Encoding UTF8
    Write-Log "report saved: $f" ok
    Start-Process $f
}

# ============================================================ wire up
$script:BtnRescan.Add_Click({ Start-Scan })
$script:BtnFixAll.Add_Click({ Fix-AllSafe })
$script:BtnReport.Add_Click({ Export-Report })
$script:BtnLogs.Add_Click({ Start-Process $script:LogDir })
$script:BtnReboot.Add_Click({ if (Confirm-Box 'Restart Windows now?') { Restart-Computer -Force } })
$script:LinkReadFirst.Add_Click({ Open-Url ($script:RepoBase + 'docs/00-read-first.md') })
if (-not $script:IsAdmin) { $script:BtnFixAll.IsEnabled = $false }

$win.Add_SourceInitialized({
    try {
        $sw = [System.Windows.SystemParameters]::PrimaryScreenWidth
        $sh = [System.Windows.SystemParameters]::PrimaryScreenHeight
        $win.Left = [Math]::Max(0, ($sw - $win.Width)  / 2)
        $win.Top  = [Math]::Max(0, ($sh - $win.Height) / 2)
    } catch {}
})
$win.Add_ContentRendered({
    Write-Log ("Eve V Fix-It v{0} started (admin: {1})" -f $script:Version, $script:IsAdmin) info
    Start-Scan
})

[void]$win.ShowDialog()
