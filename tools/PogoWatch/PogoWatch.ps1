<#
  PogoWatch - USB connect/disconnect logger with pogo-pin debug tools
  Built for diagnosing the Eve V detachable keyboard (Novatek VID_0603 / PID_00F1)
  that attaches through the internal Genesys Logic hub (VID_05E3) on the pogo pins.

  No install. Run via Start-PogoWatch.bat  (needs Windows PowerShell 5.1 / WinForms).
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- config ------------------------------------------------------------------
$script:KbdVid   = 'VID_0603'     # Eve V keyboard controller (Novatek)
$script:KbdPid   = 'PID_00F1'
$script:HubVid   = 'VID_05E3'     # internal Genesys Logic hub (USB-A + pogo)
$script:ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:LogDir    = Join-Path $ScriptDir 'logs'
if (-not (Test-Path $script:LogDir)) { New-Item -ItemType Directory -Path $script:LogDir | Out-Null }
$script:LogFile   = Join-Path $script:LogDir ("pogowatch_{0:yyyyMMdd_HHmmss}.log" -f (Get-Date))

$script:Prev        = @{}
$script:EventCount  = 0
$script:MarkerN     = 0
$script:Running     = $false
$script:WmiOn       = $false
$script:LastChange  = Get-Date

# ---- helpers ---------------------------------------------------------------
function Write-Log {
    param([string]$Text, $Color)
    if (-not $Color) { $Color = [System.Drawing.Color]::Gainsboro }
    $stamp = Get-Date -Format 'HH:mm:ss.fff'
    $rtb = $script:Rtb
    if ($rtb) {
        $rtb.SelectionStart  = $rtb.TextLength
        $rtb.SelectionLength = 0
        $rtb.SelectionColor  = $Color
        $rtb.AppendText("[$stamp] $Text`r`n")
        $rtb.SelectionStart  = $rtb.TextLength
        $rtb.ScrollToCaret()
    }
    try { Add-Content -LiteralPath $script:LogFile -Value ("[{0:yyyy-MM-dd HH:mm:ss.fff}] {1}" -f (Get-Date), $Text) } catch {}
}

function Get-UsbSnapshot {
    $h = @{}
    try {
        Get-CimInstance Win32_PnPEntity -Filter "DeviceID LIKE 'USB%' OR DeviceID LIKE 'HID%'" -ErrorAction Stop |
            ForEach-Object { $h[$_.DeviceID] = "$($_.Name) [$($_.Status)]" }
    } catch { Write-Log "snapshot error: $_" ([System.Drawing.Color]::Salmon) }
    $h
}

function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Alert-Pogo {
    param([string]$Msg)
    Write-Log (">>> $Msg <<<") ([System.Drawing.Color]::Yellow)
    if ($script:ChkBeep.Checked) { try { [System.Media.SystemSounds]::Exclamation.Play() } catch {} }
    $script:Form.TopMost = $true
    $script:Form.Activate()
    if (-not $script:ChkTop.Checked) {
        $t = New-Object System.Windows.Forms.Timer
        $t.Interval = 1500
        $t.Add_Tick({ $script:Form.TopMost = $false; $this.Stop(); $this.Dispose() })
        $t.Start()
    }
}

function Update-PogoPanel {
    param($snap)
    $kbd  = @($snap.Keys | Where-Object { $_ -match $script:KbdVid })
    $xhci = @($snap.Keys | Where-Object { $_ -match 'ROOT_HUB' })
    $exth = @($snap.Keys | Where-Object { $_ -match $script:HubVid })   # external hub, informational only

    if ($kbd.Count) {
        $extra = ''
        try {
            $d = Get-PnpDevice -InstanceId $kbd[0] -ErrorAction SilentlyContinue
            if ($d) { $extra = "  [$($d.Status)/$($d.Problem)]" }
        } catch {}
        $script:LblKbd.Text      = "EVE KEYBOARD (VID_0603): PRESENT  x$($kbd.Count)$extra"
        $script:LblKbd.BackColor = [System.Drawing.Color]::FromArgb(20,120,20)
    } else {
        $script:LblKbd.Text      = "EVE KEYBOARD (VID_0603): ABSENT"
        $script:LblKbd.BackColor = [System.Drawing.Color]::FromArgb(150,30,30)
    }

    # the real path indicator: PCH xHCI root hub (USB-A ports + pogo keyboard hang directly off it)
    if ($xhci.Count) {
        $ext = if ($exth.Count) { "   (+ external hub attached)" } else { "" }
        $script:LblHub.Text      = "PCH xHCI root hub: PRESENT$ext"
        $script:LblHub.BackColor = [System.Drawing.Color]::FromArgb(20,90,20)
    } else {
        $script:LblHub.Text      = "PCH xHCI root hub: MISSING  - whole USB stack down"
        $script:LblHub.BackColor = [System.Drawing.Color]::FromArgb(150,30,30)
    }

    $script:LblCount.Text = "USB/HID nodes: $($snap.Count)    change events: $($script:EventCount)    markers: $($script:MarkerN)"
}

function Poll-Once {
    try {
        # 1) drain raw WMI device-change signals (fire even when enumeration fails)
        if ($script:WmiOn) {
            Get-Event -SourceIdentifier 'PogoDevChange' -ErrorAction SilentlyContinue | ForEach-Object {
                $et = $null
                try { $et = [int]$_.SourceEventArgs.NewEvent.EventType } catch {}
                $map = @{ 1='config changed'; 2='DEVICE ARRIVED (electrical)'; 3='DEVICE REMOVED (electrical)'; 4='docking' }
                $name = $map[$et]; if (-not $name) { $name = "EventType $et" }
                Write-Log ("WMI  ->  $name") ([System.Drawing.Color]::Khaki)
                $script:LastChange = Get-Date
                Remove-Event -EventIdentifier $_.EventIdentifier -ErrorAction SilentlyContinue
            }
        }

        # 2) diff the enumerated device set
        $now      = Get-UsbSnapshot
        $pogoOnly = $script:ChkPogo.Checked
        $added    = @($now.Keys  | Where-Object { -not $script:Prev.ContainsKey($_) })
        $removed  = @($script:Prev.Keys | Where-Object { -not $now.ContainsKey($_) })

        foreach ($id in $added) {
            $isKbd = $id -match $script:KbdVid
            $isHub = $id -match $script:HubVid
            if ($pogoOnly -and -not ($isKbd -or $isHub -or $id -match 'ROOT_HUB')) { continue }
            $script:EventCount++; $script:LastChange = Get-Date
            $c = if ($isKbd) {[System.Drawing.Color]::Lime} elseif ($isHub) {[System.Drawing.Color]::Cyan} else {[System.Drawing.Color]::LightGreen}
            Write-Log ("+ CONNECT  {0}" -f $now[$id]) $c
            Write-Log ("           {0}" -f $id) ([System.Drawing.Color]::Gray)
            if ($isKbd) { Alert-Pogo 'EVE KEYBOARD ENUMERATED' }
        }
        foreach ($id in $removed) {
            $isKbd = $id -match $script:KbdVid
            $isHub = $id -match $script:HubVid
            if ($pogoOnly -and -not ($isKbd -or $isHub -or $id -match 'ROOT_HUB')) { continue }
            $script:EventCount++; $script:LastChange = Get-Date
            $c = if ($isKbd) {[System.Drawing.Color]::Orange} elseif ($isHub) {[System.Drawing.Color]::Cyan} else {[System.Drawing.Color]::Salmon}
            Write-Log ("- REMOVE   {0}" -f $script:Prev[$id]) $c
            Write-Log ("           {0}" -f $id) ([System.Drawing.Color]::Gray)
            if ($isKbd) { Alert-Pogo 'EVE KEYBOARD DROPPED' }
        }

        $script:Prev = $now
        Update-PogoPanel $now

        $idle = [int]((Get-Date) - $script:LastChange).TotalSeconds
        $script:Status.Text = "  admin: $(if(Test-IsAdmin){'yes'}else{'no'})   |   idle since last change: ${idle}s   |   log: $script:LogFile"
    } catch {
        Write-Log "poll error: $_" ([System.Drawing.Color]::Salmon)
    }
}

function Probe-Now {
    Write-Log "======== PROBE ========" ([System.Drawing.Color]::White)
    $snap = Get-UsbSnapshot
    Update-PogoPanel $snap
    Write-Log ("present USB/HID nodes: {0}" -f $snap.Count)

    $k = @($snap.Keys | Where-Object { $_ -match $script:KbdVid })
    if ($k.Count) {
        foreach ($id in $k) {
            $d = Get-PnpDevice -InstanceId $id -ErrorAction SilentlyContinue
            Write-Log ("  KBD present  {0}  [{1}/{2}]" -f $id, $d.Status, $d.Problem) ([System.Drawing.Color]::Lime)
        }
    } else {
        Write-Log "  Eve keyboard VID_0603 : NOT present" ([System.Drawing.Color]::Orange)
    }
    # last-known / phantom record (targeted lookup - fast)
    try {
        Get-PnpDevice -InstanceId 'USB\VID_0603&PID_00F1\*','HID\VID_0603*','USB\VID_0603*' -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log ("  last-known    {0}  [{1}/{2}]" -f $_.InstanceId, $_.Status, $_.Problem) ([System.Drawing.Color]::Gray)
        }
    } catch {}
    @($snap.Keys | Where-Object { $_ -match $script:HubVid }) | ForEach-Object { Write-Log ("  HUB  {0}  {1}" -f $_, $snap[$_]) ([System.Drawing.Color]::Cyan) }
    @($snap.Keys | Where-Object { $_ -match 'ROOT_HUB' })      | ForEach-Object { Write-Log ("  ROOT {0}" -f $_) ([System.Drawing.Color]::SkyBlue) }
    Write-Log "=======================" ([System.Drawing.Color]::White)
}

function Rescan-Hw {
    Write-Log "pnputil /scan-devices (elevated) ..." ([System.Drawing.Color]::White)
    try {
        Start-Process -FilePath 'pnputil.exe' -ArgumentList '/scan-devices' -Verb RunAs -WindowStyle Hidden -Wait -ErrorAction Stop
        Write-Log "  scan complete" ([System.Drawing.Color]::LightGreen)
    } catch {
        Write-Log "  scan cancelled / failed: $_" ([System.Drawing.Color]::Salmon)
    }
    Poll-Once
}

function Start-Mon {
    if ($script:Running) { return }
    $script:Prev = Get-UsbSnapshot
    Update-PogoPanel $script:Prev
    try {
        Register-CimIndicationEvent -Query "SELECT * FROM Win32_DeviceChangeEvent WITHIN 1" -SourceIdentifier 'PogoDevChange' -ErrorAction Stop | Out-Null
        $script:WmiOn = $true
        Write-Log "WMI DeviceChangeEvent watcher armed" ([System.Drawing.Color]::Gray)
    } catch {
        $script:WmiOn = $false
        Write-Log "WMI watcher unavailable (poll only): $_" ([System.Drawing.Color]::Salmon)
    }
    $script:Timer.Interval = [int]$script:NumInterval.Value
    $script:Timer.Start()
    $script:Running = $true
    $script:BtnStart.Text = 'STOP'
    $script:BtnStart.BackColor = [System.Drawing.Color]::FromArgb(150,30,30)
    Write-Log ("monitoring started - poll {0} ms - log {1}" -f $script:Timer.Interval, $script:LogFile) ([System.Drawing.Color]::White)
}

function Stop-Mon {
    if (-not $script:Running) { return }
    $script:Timer.Stop()
    if ($script:WmiOn) { Unregister-Event -SourceIdentifier 'PogoDevChange' -ErrorAction SilentlyContinue; $script:WmiOn = $false }
    $script:Running = $false
    $script:BtnStart.Text = 'START'
    $script:BtnStart.BackColor = [System.Drawing.Color]::FromArgb(20,110,20)
    Write-Log "monitoring stopped" ([System.Drawing.Color]::White)
}

# ---- UI --------------------------------------------------------------------
$dark  = [System.Drawing.Color]::FromArgb(30,30,30)
$panel = [System.Drawing.Color]::FromArgb(45,45,45)

$script:Form = New-Object System.Windows.Forms.Form
$script:Form.Text = 'PogoWatch - Eve V pogo-pin / USB monitor'
$script:Form.Size = New-Object System.Drawing.Size(960,640)
$script:Form.MinimumSize = New-Object System.Drawing.Size(720,460)
$script:Form.BackColor = $dark
$script:Form.ForeColor = [System.Drawing.Color]::Gainsboro

# top control bar
$bar = New-Object System.Windows.Forms.FlowLayoutPanel
$bar.Dock = 'Top'; $bar.Height = 84; $bar.BackColor = $panel; $bar.Padding = '6,6,6,6'; $bar.WrapContents = $true

$script:BtnStart = New-Object System.Windows.Forms.Button
$script:BtnStart.Text = 'START'; $script:BtnStart.Width = 80; $script:BtnStart.Height = 32
$script:BtnStart.BackColor = [System.Drawing.Color]::FromArgb(20,110,20); $script:BtnStart.ForeColor = 'White'; $script:BtnStart.FlatStyle = 'Flat'
$script:BtnStart.Add_Click({ if ($script:Running) { Stop-Mon } else { Start-Mon } })

$lblInt = New-Object System.Windows.Forms.Label
$lblInt.Text = 'poll ms'; $lblInt.AutoSize = $true; $lblInt.Margin = '10,10,2,0'

$script:NumInterval = New-Object System.Windows.Forms.NumericUpDown
$script:NumInterval.Minimum = 500; $script:NumInterval.Maximum = 10000; $script:NumInterval.Increment = 250
$script:NumInterval.Value = 1500; $script:NumInterval.Width = 70; $script:NumInterval.BackColor = $dark; $script:NumInterval.ForeColor = 'White'
$script:NumInterval.Add_ValueChanged({ if ($script:Running) { $script:Timer.Interval = [int]$script:NumInterval.Value } })

function New-Btn($text,$w,$cb){
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = $w; $b.Height = 32; $b.FlatStyle = 'Flat'
    $b.BackColor = [System.Drawing.Color]::FromArgb(60,60,60); $b.ForeColor = 'White'
    $b.Add_Click($cb); $b
}
$btnProbe  = New-Btn 'Probe now'      90  { Probe-Now }
$btnMarker = New-Btn 'MARKER'         80  { $script:MarkerN++; Write-Log ("========== MARKER #{0} - physical action here ==========" -f $script:MarkerN) ([System.Drawing.Color]::Magenta) }
$btnRescan = New-Btn 'Rescan HW'      90  { Rescan-Hw }
$btnClear  = New-Btn 'Clear'          60  { $script:Rtb.Clear() }
$btnLog    = New-Btn 'Open log'       75  { Start-Process explorer.exe $script:LogDir }

$script:ChkPogo = New-Object System.Windows.Forms.CheckBox
$script:ChkPogo.Text = 'pogo filter'; $script:ChkPogo.AutoSize = $true; $script:ChkPogo.Margin = '10,8,4,0'
$script:ChkBeep = New-Object System.Windows.Forms.CheckBox
$script:ChkBeep.Text = 'sound'; $script:ChkBeep.Checked = $true; $script:ChkBeep.AutoSize = $true; $script:ChkBeep.Margin = '6,8,4,0'
$script:ChkTop  = New-Object System.Windows.Forms.CheckBox
$script:ChkTop.Text = 'on top'; $script:ChkTop.AutoSize = $true; $script:ChkTop.Margin = '6,8,4,0'
$script:ChkTop.Add_CheckedChanged({ $script:Form.TopMost = $script:ChkTop.Checked })

$bar.Controls.AddRange(@($script:BtnStart,$lblInt,$script:NumInterval,$btnProbe,$btnMarker,$btnRescan,$btnClear,$btnLog,$script:ChkPogo,$script:ChkBeep,$script:ChkTop))

# right status panel
$side = New-Object System.Windows.Forms.Panel
$side.Dock = 'Right'; $side.Width = 330; $side.BackColor = $panel; $side.Padding = '8,8,8,8'

$script:LblKbd = New-Object System.Windows.Forms.Label
$script:LblKbd.Dock = 'Top'; $script:LblKbd.Height = 54; $script:LblKbd.TextAlign = 'MiddleCenter'
$script:LblKbd.Font = New-Object System.Drawing.Font('Segoe UI',9,[System.Drawing.FontStyle]::Bold)
$script:LblKbd.ForeColor = 'White'; $script:LblKbd.Text = 'EVE KEYBOARD (VID_0603): ?'

$script:LblHub = New-Object System.Windows.Forms.Label
$script:LblHub.Dock = 'Top'; $script:LblHub.Height = 40; $script:LblHub.TextAlign = 'MiddleCenter'
$script:LblHub.ForeColor = 'White'; $script:LblHub.Text = 'PCH xHCI root hub: ?'

$script:LblCount = New-Object System.Windows.Forms.Label
$script:LblCount.Dock = 'Top'; $script:LblCount.Height = 30; $script:LblCount.TextAlign = 'MiddleCenter'
$script:LblCount.Text = 'USB/HID nodes: -'

$help = New-Object System.Windows.Forms.TextBox
$help.Multiline = $true; $help.ReadOnly = $true; $help.Dock = 'Fill'; $help.BackColor = $dark; $help.ForeColor = 'Silver'
$help.BorderStyle = 'None'; $help.Font = New-Object System.Drawing.Font('Consolas',8.5)
$help.Text = @"
READING THE LOG

WMI -> DEVICE ARRIVED  but no
"+ CONNECT" line:
  hub sees the pogo pins electrically,
  but the keyboard fails to enumerate
  -> flex cable / Novatek controller,
     not the port.

Attach keyboard and NOTHING logs
(no WMI, no +/-):
  dead connection - pins not making
  contact, or broken hinge ribbon.

NOTE: USB-A ports and the pogo
keyboard hang DIRECTLY off the PCH
xHCI root hub - there is no internal
hub. VID_05E3 = an external hub you
plugged in; its state does not
matter here.

If "PCH xHCI root hub: MISSING":
  whole USB stack is down -> do one
  full shutdown (fast-startup bug).

WORKFLOW
 1 Start
 2 press MARKER
 3 physically attach/detach keyboard
 4 watch 5-10 s
 5 press MARKER again
 6 Open log, read between markers

the WMI line catches the instant a
change happens; the next poll names
what changed. lower 'poll ms' for a
faster name, but enum costs ~1-2 s.
"@ -replace "`r?`n", "`r`n"
$side.Controls.AddRange(@($help,$script:LblCount,$script:LblHub,$script:LblKbd))

# center log
$script:Rtb = New-Object System.Windows.Forms.RichTextBox
$script:Rtb.Dock = 'Fill'; $script:Rtb.ReadOnly = $true; $script:Rtb.BackColor = [System.Drawing.Color]::Black
$script:Rtb.ForeColor = 'Gainsboro'; $script:Rtb.Font = New-Object System.Drawing.Font('Consolas',9)
$script:Rtb.DetectUrls = $false; $script:Rtb.WordWrap = $false; $script:Rtb.HideSelection = $false

# status strip
$strip = New-Object System.Windows.Forms.StatusStrip
$strip.BackColor = $panel
$script:Status = New-Object System.Windows.Forms.ToolStripStatusLabel
$script:Status.ForeColor = 'Silver'; $script:Status.Text = '  ready'
$strip.Items.Add($script:Status) | Out-Null

$script:Form.Controls.AddRange(@($script:Rtb,$side,$bar,$strip))

# timer
$script:Timer = New-Object System.Windows.Forms.Timer
$script:Timer.Interval = 1500
$script:Timer.Add_Tick({ Poll-Once })

$script:Form.Add_Shown({
    Write-Log ("PogoWatch started   admin={0}" -f (Test-IsAdmin)) ([System.Drawing.Color]::White)
    Write-Log ("watching: keyboard {0}/{1}   hub {2}" -f $script:KbdVid,$script:KbdPid,$script:HubVid) ([System.Drawing.Color]::Gray)
    Probe-Now
    Start-Mon
})
$script:Form.Add_FormClosing({ Stop-Mon; Get-Event -SourceIdentifier 'PogoDevChange' -ErrorAction SilentlyContinue | Remove-Event -ErrorAction SilentlyContinue })

[void]$script:Form.ShowDialog()
