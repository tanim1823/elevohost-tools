# Enable-RDP.ps1
# PowerShell script to activate Remote Desktop Protocol with Premium Modern GUI
# Run with administrator privileges

# Make sure we have the required assemblies
Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
Add-Type -AssemblyName System.Drawing -ErrorAction Stop

# Check for Administrator privileges
function Test-Admin {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# If not running as admin, restart with admin rights
if (-not (Test-Admin)) {
    Write-Host "Restarting script with administrator privileges..."
    $scriptPath = $MyInvocation.MyCommand.Path
    Start-Process PowerShell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`"" -Verb RunAs
    exit
}

# Function to enable RDP
function Enable-RemoteDesktop {
    try {
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -Value 0 -ErrorAction Stop
        Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' -Name "UserAuthentication" -Value 1 -ErrorAction Stop
        Set-Service -Name "TermService" -StartupType Automatic -ErrorAction Stop
        
        $service = Get-Service -Name "TermService"
        if ($service.Status -ne "Running") {
            Start-Service -Name "TermService" -ErrorAction Stop
        }
        
        Enable-NetFirewallRule -DisplayGroup "Remote Desktop" -ErrorAction Stop
        
        return @{
            Success = $true
            Message = "RDP successfully enabled. System is ready for safe incoming connections."
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error enabling RDP: $_"
        }
    }
}

# Function to verify if RDP is already enabled
function Get-RDPStatus {
    $rdpValue = Get-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' -Name "fDenyTSConnections" -ErrorAction SilentlyContinue
    if ($null -ne $rdpValue -and $rdpValue.fDenyTSConnections -eq 0) {
        return "Enabled"
    } else {
        return "Disabled"
    }
}

# Function to optimize power settings
function Set-HighPerformancePower {
    try {
        $powerPlanGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "ElementName='High performance'").InstanceID.ToString()
        if (-not $powerPlanGuid) {
            $balancedGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "ElementName='Balanced'").InstanceID.ToString()
            if ($balancedGuid) {
                $balancedGuid = $balancedGuid.Replace("Microsoft:PowerPlan\{", "").Replace("}", "")
                $output = powercfg -duplicatescheme $balancedGuid
                $powerPlanGuid = (Get-WmiObject -Class Win32_PowerPlan -Namespace root\cimv2\power -Filter "ElementName='High performance'").InstanceID.ToString()
            }
        }
        
        if ($powerPlanGuid) {
            $powerPlanGuid = $powerPlanGuid.Replace("Microsoft:PowerPlan\{", "").Replace("}", "")
            powercfg -setactive $powerPlanGuid
        }
        
        powercfg -change -monitor-timeout-ac 0
        powercfg -change -monitor-timeout-dc 0
        powercfg -change -standby-timeout-ac 0
        powercfg -change -standby-timeout-dc 0
        powercfg -change -hibernate-timeout-ac 0
        powercfg -change -hibernate-timeout-dc 0
        
        return @{
            Success = $true
            Message = "Power infrastructure optimized: Performance initialized and sleep disabled."
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error setting power options: $_"
        }
    }
}

# Function to disable account lockout
function Disable-AccountLockout {
    try {
        $result = net accounts /lockoutthreshold:0
        return @{
            Success = $true
            Message = "Account lockout policies dismantled. Unrestricted remote admin retry enabled."
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error disabling account lockout policy: $_"
        }
    }
}

# Function to run the activation script
function Run-Activator {
    try {
        $tempFile = [System.IO.Path]::GetTempFileName()
        $scriptBlock = {
            param($tempFile)
            $output = irm https://get.activated.win | iex 2>&1 | Out-String
            $output | Out-File -FilePath $tempFile
        }
        
        $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList $tempFile
        $jobCompleted = Wait-Job -Job $job -Timeout 60
        
        if ($jobCompleted -eq $null) {
            Stop-Job -Job $job
            Remove-Job -Job $job -Force
            return @{
                Success = $false
                Message = "Deployment engine pipeline timed out after 60 seconds."
            }
        }
        
        $output = Get-Content -Path $tempFile -Raw
        Remove-Item -Path $tempFile -Force
        Remove-Job -Job $job -Force
        
        return @{
            Success = $true
            Message = "Global core system activator injected successfully."
            Output = $output
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error running activation cluster: $_"
        }
    }
}

# Function to disable Windows Firewall
function Disable-WindowsFirewall {
    try {
        $result = netsh advfirewall set allprofiles state off
        if ($result -match "Ok.") {
            return @{
                Success = $true
                Message = "Windows Native Firewall layer deactivated across all profile trees."
                Output = $result
            }
        } else {
            return @{
                Success = $false
                Message = "Security framework denied deactivation hook."
                Output = $result
            }
        }
    }
    catch {
        return @{
            Success = $false
            Message = "Error disabling Firewall: $_"
        }
    }
}

# Function to create premium styled button
function Create-PremiumButton {
    param (
        [string]$Text,
        [System.Drawing.Size]$Size,
        [System.Drawing.Point]$Location,
        [System.Drawing.Color]$BackColor,
        [System.Drawing.Color]$HoverColor,
        [scriptblock]$Action
    )
    
    $button = New-Object System.Windows.Forms.Button
    $button.Text = $Text
    $button.Size = $Size
    $button.Location = $Location
    $button.BackColor = $BackColor
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = $HoverColor
    $button.Add_Click($Action)
    
    return $button
}

Write-Host "Initializing ElevoHost Premium RDP Cluster..."

# Create Main Dashboard Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "ElevoHost Suite"
$form.Size = New-Object System.Drawing.Size(800, 680)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None" # Borderless Custom Acrylic Feel
$form.BackColor = [System.Drawing.Color]::FromArgb(15, 18, 36) # Dark Tech Palette

# Top Header Bar
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(800, 85)
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 56)
$form.Controls.Add($headerPanel)

# Branding Title
$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Text = "ELEVO"
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 198, 251) # Neon Cyan Accent
$headerLabel.Size = New-Object System.Drawing.Size(130, 45)
$headerLabel.Location = New-Object System.Drawing.Point(30, 20)
$headerPanel.Controls.Add($headerLabel)

$subHeaderLabel = New-Object System.Windows.Forms.Label
$subHeaderLabel.Text = "HOST"
$subHeaderLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Regular)
$subHeaderLabel.ForeColor = [System.Drawing.Color]::White
$subHeaderLabel.Size = New-Object System.Drawing.Size(120, 45)
$subHeaderLabel.Location = New-Object System.Drawing.Point(155, 20)
$headerPanel.Controls.Add($subHeaderLabel)

# Status telemetry panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(740, 110)
$statusPanel.Location = New-Object System.Drawing.Point(30, 110)
$statusPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 56)
$form.Controls.Add($statusPanel)

$currentStatus = Get-RDPStatus
$statusColor = if ($currentStatus -eq "Enabled") { [System.Drawing.Color]::FromArgb(0, 230, 118) } else { [System.Drawing.Color]::FromArgb(255, 23, 68) }

# Graphic Indicator Engine
$statusIconPanel = New-Object System.Windows.Forms.Panel
$statusIconPanel.Size = New-Object System.Drawing.Size(60, 60)
$statusIconPanel.Location = New-Object System.Drawing.Point(25, 25)
$statusPanel.Controls.Add($statusIconPanel)

$statusIconPanel.Add_Paint({
    $g = $_.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush($statusColor)
    $g.FillEllipse($brush, 5, 5, 45, 45)
    $brush.Dispose()
})

# Meta Strings
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "RDP STATE: " + $currentStatus.ToUpper()
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 13, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = $statusColor
$statusLabel.Size = New-Object System.Drawing.Size(400, 28)
$statusLabel.Location = New-Object System.Drawing.Point(100, 20)
$statusPanel.Controls.Add($statusLabel)

$computerInfoLabel = New-Object System.Windows.Forms.Label
$computerInfoLabel.Text = "NODE ID: $env:COMPUTERNAME"
$computerInfoLabel.Font = New-Object System.Drawing.Font("Consolas", 10)
$computerInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 175, 195)
$computerInfoLabel.Size = New-Object System.Drawing.Size(400, 22)
$computerInfoLabel.Location = New-Object System.Drawing.Point(100, 50)
$statusPanel.Controls.Add($computerInfoLabel)

$ipInfoLabel = New-Object System.Windows.Forms.Label
$ipInfoLabel.Text = "IPV4 ADDR: $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike '*Loopback*' -and $_.InterfaceAlias -notlike '*VM*'}).IPAddress -join ', ')"
$ipInfoLabel.Font = New-Object System.Drawing.Font("Consolas", 10)
$ipInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(170, 175, 195)
$ipInfoLabel.Size = New-Object System.Drawing.Size(600, 22)
$ipInfoLabel.Location = New-Object System.Drawing.Point(100, 72)
$statusPanel.Controls.Add($ipInfoLabel)

# Workspace Layout Config (Grid Control Block)
$gridPanel = New-Object System.Windows.Forms.Panel
$gridPanel.Size = New-Object System.Drawing.Size(740, 230)
$gridPanel.Location = New-Object System.Drawing.Point(30, 245)
$form.Controls.Add($gridPanel)

# Actions Configurations
$actionEnableRDP = {
    $logHeader.Text = "EXECUTING: EXPLOITING RDP CONFIGURATION TARGETS..."
    $logPanel.Update()
    $result = Enable-RemoteDesktop
    if ($result.Success) {
        $logHeader.Text = "TRANSACTION SUCCESSFUL"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 230, 118)
        $currentStatus = Get-RDPStatus
        $statusLabel.Text = "RDP STATE: " + $currentStatus.ToUpper()
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 230, 118)
        $statusColor = [System.Drawing.Color]::FromArgb(0, 230, 118)
        $statusIconPanel.Invalidate()
        $outputTextBox.AppendText("[$($result.Message)]`r`n")
    } else {
        $logHeader.Text = "PIPELINE FAULT OCCURRED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 23, 68)
        $outputTextBox.AppendText("[CRITICAL: $($result.Message)]`r`n")
    }
}

$actionActivator = {
    $logHeader.Text = "DOWNLOADING ARTIFACTS FROM MASSGRAVE INTERFACE..."
    $logPanel.Update()
    $result = Run-Activator
    if ($result.Success) {
        $logHeader.Text = "ACTIVATION REPOSITORIES APPLIED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 198, 251)
        $outputTextBox.AppendText("[SUCCESS: $($result.Message)]`r`n")
        if ($result.Output) { $outputTextBox.AppendText("$($result.Output)`r`n") }
    } else {
        $logHeader.Text = "ACTIVATION TARGET TERMINATED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 23, 68)
        $outputTextBox.AppendText("[ERROR: $($result.Message)]`r`n")
    }
}

$actionFirewall = {
    $logHeader.Text = "DEACTIVATING NETSH FIREWALL ROUTING PROFILES..."
    $logPanel.Update()
    $result = Disable-WindowsFirewall
    if ($result.Success) {
        $logHeader.Text = "FIREWALL SHIELD LOWERED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 171, 0)
        $outputTextBox.AppendText("[WARNING: $($result.Message)]`r`n")
    } else {
        $logHeader.Text = "SECURITY RULE MODIFICATION DENIED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 23, 68)
        $outputTextBox.AppendText("[ERROR: $($result.Message)]`r`n")
    }
}

$actionPower = {
    $logHeader.Text = "OVERRIDING CORE SYSTEM POWER MANAGEMENT POLICY..."
    $logPanel.Update()
    $result = Set-HighPerformancePower
    if ($result.Success) {
        $logHeader.Text = "POWER PROFILES OPTIMIZED SUCCESSFULLY"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 230, 118)
        $outputTextBox.AppendText("[METRICS: $($result.Message)]`r`n")
    } else {
        $logHeader.Text = "POWER PROFILES ENGINE EXCEPTION"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 23, 68)
        $outputTextBox.AppendText("[ERROR: $($result.Message)]`r`n")
    }
}

$actionLockout = {
    $logHeader.Text = "REMOVING MAXIMUM RETRIES ACCOUNT THRESHOLDS..."
    $logPanel.Update()
    $result = Disable-AccountLockout
    if ($result.Success) {
        $logHeader.Text = "LOCKOUT SAFEGUARDS BYPASSED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 230, 118)
        $outputTextBox.AppendText("[POLICY: $($result.Message)]`r`n")
    } else {
        $logHeader.Text = "ACCOUNT SECURITY SCHEME MODIFICATION FAILED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(255, 23, 68)
        $outputTextBox.AppendText("[ERROR: $($result.Message)]`r`n")
    }
}

# Drawing Premium Grid Controls (Column 1)
$btnRDP = Create-PremiumButton -Text "Enable Remote Desktop" -Size (New-Object System.Drawing.Size(350, 65)) -Location (New-Object System.Drawing.Point(0, 10)) -BackColor ([System.Drawing.Color]::FromArgb(0, 145, 234)) -HoverColor ([System.Drawing.Color]::FromArgb(0, 176, 255)) -Action $actionEnableRDP
$btnAct = Create-PremiumButton -Text "Run Windows Activator" -Size (New-Object System.Drawing.Size(350, 65)) -Location (New-Object System.Drawing.Point(0, 85)) -BackColor ([System.Drawing.Color]::FromArgb(101, 31, 255)) -HoverColor ([System.Drawing.Color]::FromArgb(124, 77, 255)) -Action $actionActivator
$btnFw  = Create-PremiumButton -Text "Disable Windows Firewall" -Size (New-Object System.Drawing.Size(350, 65)) -Location (New-Object System.Drawing.Point(0, 160)) -BackColor ([System.Drawing.Color]::FromArgb(221, 44, 0)) -HoverColor ([System.Drawing.Color]::FromArgb(255, 61, 0)) -Action $actionFirewall

# Drawing Premium Grid Controls (Column 2)
$btnPwr = Create-PremiumButton -Text "Optimize Power Infrastructure" -Size (New-Object System.Drawing.Size(360, 65)) -Location (New-Object System.Drawing.Point(380, 10)) -BackColor ([System.Drawing.Color]::FromArgb(0, 200, 83)) -HoverColor ([System.Drawing.Color]::FromArgb(0, 230, 118)) -Action $actionPower
$btnLck = Create-PremiumButton -Text "Disable Account Lockouts" -Size (New-Object System.Drawing.Size(360, 65)) -Location (New-Object System.Drawing.Point(380, 85)) -BackColor ([System.Drawing.Color]::FromArgb(255, 109, 0)) -HoverColor ([System.Drawing.Color]::FromArgb(255, 145, 0)) -Action $actionLockout

$gridPanel.Controls.AddRange(@($btnRDP, $btnAct, $btnFw, $btnPwr, $btnLck))

# Advanced Crypt Logging Stream Panel
$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Size = New-Object System.Drawing.Size(740, 130)
$logPanel.Location = New-Object System.Drawing.Point(30, 485)
$logPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 56)
$form.Controls.Add($logPanel)

$logHeader = New-Object System.Windows.Forms.Label
$logHeader.Text = "SYSTEM CONSOLE STREAMS"
$logHeader.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$logHeader.ForeColor = [System.Drawing.Color]::FromArgb(140, 148, 174)
$logHeader.Size = New-Object System.Drawing.Size(700, 25)
$logHeader.Location = New-Object System.Drawing.Point(15, 10)
$logPanel.Controls.Add($logHeader)

$outputTextBox = New-Object System.Windows.Forms.RichTextBox
$outputTextBox.Size = New-Object System.Drawing.Size(710, 80)
$outputTextBox.Location = New-Object System.Drawing.Point(15, 35)
$outputTextBox.ReadOnly = $true
$outputTextBox.BackColor = [System.Drawing.Color]::FromArgb(15, 18, 36)
$outputTextBox.ForeColor = [System.Drawing.Color]::FromArgb(0, 230, 118) # Console Terminal Green
$outputTextBox.Font = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$outputTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$logPanel.Controls.Add($outputTextBox)

# Footer Base branding
$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Size = New-Object System.Drawing.Size(800, 35)
$footerPanel.Location = New-Object System.Drawing.Point(0, 645)
$footerPanel.BackColor = [System.Drawing.Color]::FromArgb(24, 28, 56)
$form.Controls.Add($footerPanel)

$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.Text = "POWERED BY ELEVOHOST AUTOMATION SUITE"
$footerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$footerLabel.ForeColor = [System.Drawing.Color]::FromArgb(90, 100, 130)
$footerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$footerLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$footerPanel.Controls.Add($footerLabel)

# Custom Sleek Exit Window Trigger
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "×"
$exitButton.Size = New-Object System.Drawing.Size(40, 40)
$exitButton.Location = New-Object System.Drawing.Point(740, 20)
$exitButton.BackColor = [System.Drawing.Color]::Transparent
$exitButton.ForeColor = [System.Drawing.Color]::White
$exitButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$exitButton.Font = New-Object System.Drawing.Font("Arial", 20, [System.Drawing.FontStyle]::Regular)
$exitButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$exitButton.FlatAppearance.BorderSize = 0
$exitButton.TabStop = $false
$headerPanel.Controls.Add($exitButton)

$exitButton.Add_Click({
    $form.Close()
})

# Form dragging handlers for borderless setup
$lastLocation = New-Object System.Drawing.Point
$isDragging = $false

$headerPanel.Add_MouseDown({
    $script:isDragging = $true
    $script:lastLocation = [System.Windows.Forms.Cursor]::Position
})

$headerPanel.Add_MouseMove({
    if ($script:isDragging) {
        $currentPosition = [System.Windows.Forms.Cursor]::Position
        $offset = New-Object System.Drawing.Point(($currentPosition.X - $script:lastLocation.X), ($currentPosition.Y - $script:lastLocation.Y))
        $form.Location = New-Object System.Drawing.Point(($form.Location.X + $offset.X), ($form.Location.Y + $offset.Y))
        $script:lastLocation = $currentPosition
    }
})

$headerPanel.Add_MouseUp({ $script:isDragging = $false })

# Frame execution runtime logs
$timestamp = Get-Date -Format 'HH:mm:ss'
$outputTextBox.AppendText("[$timestamp] SYSTEM: ElevoHost Core Architecture Initialized Engine...`r`n")
$outputTextBox.AppendText("[$timestamp] STATUS: Telemetry node verified RDP as $currentStatus.`r`n")

[System.Windows.Forms.Application]::EnableVisualStyles()
$form.ShowDialog()
