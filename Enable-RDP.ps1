# Enable-RDP.ps1
# PowerShell script to activate Remote Desktop Protocol with Premium Modern Light GUI
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

# Function to create custom premium flat buttons
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
    $button.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
    $button.Cursor = [System.Windows.Forms.Cursors]::Hand
    $button.FlatAppearance.BorderSize = 0
    $button.FlatAppearance.MouseOverBackColor = $HoverColor
    $button.FlatAppearance.MouseDownBackColor = $BackColor
    $button.Add_Click($Action)
    
    return $button
}

Write-Host "Initializing ElevoHost Premium RDP Light Suite..."

# Create Main Dashboard Form
$form = New-Object System.Windows.Forms.Form
$form.Text = "ElevoHost Suite"
$form.Size = New-Object System.Drawing.Size(820, 710)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "None" 
$form.BackColor = [System.Drawing.Color]::FromArgb(244, 246, 250) # Light Platinum Surface

# Top Header Bar
$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Size = New-Object System.Drawing.Size(820, 85)
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255) # Pure White
$form.Controls.Add($headerPanel)

# Branding Title
$headerLabel = New-Object System.Windows.Forms.Label
$headerLabel.Text = "ELEVO"
$headerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
$headerLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 145, 234) # Tech Cyan Blue
$headerLabel.Size = New-Object System.Drawing.Size(130, 45)
$headerLabel.Location = New-Object System.Drawing.Point(35, 20)
$headerPanel.Controls.Add($headerLabel)

$subHeaderLabel = New-Object System.Windows.Forms.Label
$subHeaderLabel.Text = "HOST"
$subHeaderLabel.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Regular)
$subHeaderLabel.ForeColor = [System.Drawing.Color]::FromArgb(55, 71, 79) # Slate Dark Grey
$subHeaderLabel.Size = New-Object System.Drawing.Size(120, 45)
$subHeaderLabel.Location = New-Object System.Drawing.Point(158, 20)
$headerPanel.Controls.Add($subHeaderLabel)

# Status telemetry panel
$statusPanel = New-Object System.Windows.Forms.Panel
$statusPanel.Size = New-Object System.Drawing.Size(750, 115)
$statusPanel.Location = New-Object System.Drawing.Point(35, 115)
$statusPanel.BackColor = [System.Drawing.Color]::White
$form.Controls.Add($statusPanel)

$currentStatus = Get-RDPStatus
$statusColor = if ($currentStatus -eq "Enabled") { [System.Drawing.Color]::FromArgb(0, 200, 83) } else { [System.Drawing.Color]::FromArgb(213, 0, 0) }

# Graphic Indicator Engine
$statusIconPanel = New-Object System.Windows.Forms.Panel
$statusIconPanel.Size = New-Object System.Drawing.Size(60, 60)
$statusIconPanel.Location = New-Object System.Drawing.Point(25, 28)
$statusPanel.Controls.Add($statusIconPanel)

$statusIconPanel.Add_Paint({
    $g = $_.Graphics
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush($statusColor)
    $g.FillEllipse($brush, 5, 5, 42, 42)
    $brush.Dispose()
})

# Meta Strings
$statusLabel = New-Object System.Windows.Forms.Label
$statusLabel.Text = "SYSTEM RDP NODE STATUS: " + $currentStatus.ToUpper()
$statusLabel.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$statusLabel.ForeColor = $statusColor
$statusLabel.Size = New-Object System.Drawing.Size(450, 28)
$statusLabel.Location = New-Object System.Drawing.Point(95, 23)
$statusPanel.Controls.Add($statusLabel)

$computerInfoLabel = New-Object System.Windows.Forms.Label
$computerInfoLabel.Text = "INSTANCE VIRTUAL NODE ID :  $env:COMPUTERNAME"
$computerInfoLabel.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Bold)
$computerInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 110, 130)
$computerInfoLabel.Size = New-Object System.Drawing.Size(500, 22)
$computerInfoLabel.Location = New-Object System.Drawing.Point(95, 53)
$statusPanel.Controls.Add($computerInfoLabel)

$ipInfoLabel = New-Object System.Windows.Forms.Label
$ipInfoLabel.Text = "NETWORK V4 IP ADDRESS  :  $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike '*Loopback*' -and $_.InterfaceAlias -notlike '*VM*'}).IPAddress -join ', ')"
$ipInfoLabel.Font = New-Object System.Drawing.Font("Consolas", 9.5, [System.Drawing.FontStyle]::Bold)
$ipInfoLabel.ForeColor = [System.Drawing.Color]::FromArgb(100, 110, 130)
$ipInfoLabel.Size = New-Object System.Drawing.Size(630, 22)
$ipInfoLabel.Location = New-Object System.Drawing.Point(95, 75)
$statusPanel.Controls.Add($ipInfoLabel)

# Workspace Layout Config (Grid Control Block)
$gridPanel = New-Object System.Windows.Forms.Panel
$gridPanel.Size = New-Object System.Drawing.Size(750, 250)
$gridPanel.Location = New-Object System.Drawing.Point(35, 255)
$form.Controls.Add($gridPanel)

# Actions Configurations
$actionEnableRDP = {
    $logHeader.Text = "EXECUTING: ALLOCATING DATA ROUTING INTERFACES..."
    $logPanel.Update()
    $result = Enable-RemoteDesktop
    if ($result.Success) {
        $logHeader.Text = "TASK COMPLETED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 83)
        $currentStatus = Get-RDPStatus
        $statusLabel.Text = "SYSTEM RDP NODE STATUS: " + $currentStatus.ToUpper()
        $statusLabel.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 83)
        $statusColor = [System.Drawing.Color]::FromArgb(0, 200, 83)
        $statusIconPanel.Invalidate()
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: $($result.Message)`r`n")
    } else {
        $logHeader.Text = "EXECUTION EXCEPTION PIPELINE"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(213, 0, 0)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ERROR: $($result.Message)`r`n")
    }
}

$actionActivator = {
    $logHeader.Text = "DOWNLOADING FROM CORE SERVER ENDPOINT INTERFACE..."
    $logPanel.Update()
    $result = Run-Activator
    if ($result.Success) {
        $logHeader.Text = "ACTIVATION SUITE SYNCHRONIZED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 145, 234)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] SUCCESS: $($result.Message)`r`n")
        if ($result.Output) { $outputTextBox.AppendText("$($result.Output)`r`n") }
    } else {
        $logHeader.Text = "DEPLOYMENT TASK TERMINATED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(213, 0, 0)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] FAULT: $($result.Message)`r`n")
    }
}

$actionFirewall = {
    $logHeader.Text = "DISABLING SECURITY NETWORK DEPLOYMENT POLICIES..."
    $logPanel.Update()
    $result = Disable-WindowsFirewall
    if ($result.Success) {
        $logHeader.Text = "FIREWALL ACCESS CONTROL TERMINATED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(230, 81, 0)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] WARNING: $($result.Message)`r`n")
    } else {
        $logHeader.Text = "FIREWALL HOOK ACCESS DENIED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(213, 0, 0)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] EXCEPTION: $($result.Message)`r`n")
    }
}

$actionPower = {
    $logHeader.Text = "OVERRIDING LOCAL SCHEDULER SYSTEM POWER PROFILE..."
    $logPanel.Update()
    $result = Set-HighPerformancePower
    if ($result.Success) {
        $logHeader.Text = "POWER PROFILES ENGINE SYNCHRONIZED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 83)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] CORE: $($result.Message)`r`n")
    } else {
        $logHeader.Text = "SCHEDULER ENGINE EXCEPTION OVERRIDE"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(213, 0, 0)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ERROR: $($result.Message)`r`n")
    }
}

$actionLockout = {
    $logHeader.Text = "REMOVING SECURITY RETRIES RESTRICTION MAPS..."
    $logPanel.Update()
    $result = Disable-AccountLockout
    if ($result.Success) {
        $logHeader.Text = "LOCKOUT RETRIES MAP DISMANTLED"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 83)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] SECURITY: $($result.Message)`r`n")
    } else {
        $logHeader.Text = "LOCKOUT CRITICAL ERROR EXCEPTION"
        $logHeader.ForeColor = [System.Drawing.Color]::FromArgb(213, 0, 0)
        $outputTextBox.AppendText("[$(Get-Date -Format 'HH:mm:ss')] ERROR: $($result.Message)`r`n")
    }
}

# Advanced Light Balanced Slate Matrix Buttons
$btnRDP = Create-PremiumButton -Text "Enable Remote Desktop" -Size (New-Object System.Drawing.Size(360, 65)) -Location (New-Object System.Drawing.Point(0, 10)) -BackColor ([System.Drawing.Color]::FromArgb(41, 121, 255)) -HoverColor ([System.Drawing.Color]::FromArgb(0, 91, 234)) -Action $actionEnableRDP
$btnAct = Create-PremiumButton -Text "Run Windows Activator" -Size (New-Object System.Drawing.Size(360, 65)) -Location (New-Object System.Drawing.Point(0, 90)) -BackColor ([System.Drawing.Color]::FromArgb(101, 31, 255)) -HoverColor ([System.Drawing.Color]::FromArgb(74, 20, 140)) -Action $actionActivator
$btnFw  = Create-PremiumButton -Text "Disable Windows Firewall" -Size (New-Object System.Drawing.Size(360, 65)) -Location (New-Object System.Drawing.Point(0, 170)) -BackColor ([System.Drawing.Color]::FromArgb(255, 23, 68)) -HoverColor ([System.Drawing.Color]::FromArgb(183, 28, 28)) -Action $actionFirewall

$btnPwr = Create-PremiumButton -Text "Optimize Power Infrastructure" -Size (New-Object System.Drawing.Size(365, 65)) -Location (New-Object System.Drawing.Point(385, 10)) -BackColor ([System.Drawing.Color]::FromArgb(0, 230, 118)) -HoverColor ([System.Drawing.Color]::FromArgb(0, 145, 52)) -Action $actionPower
$btnLck = Create-PremiumButton -Text "Disable Account Lockouts" -Size (New-Object System.Drawing.Size(365, 65)) -Location (New-Object System.Drawing.Point(385, 90)) -BackColor ([System.Drawing.Color]::FromArgb(255, 145, 0)) -HoverColor ([System.Drawing.Color]::FromArgb(230, 81, 0)) -Action $actionLockout

$gridPanel.Controls.AddRange(@($btnRDP, $btnAct, $btnFw, $btnPwr, $btnLck))

# Advanced Modern Log Terminal Engine 
$logPanel = New-Object System.Windows.Forms.Panel
$logPanel.Size = New-Object System.Drawing.Size(750, 150)
$logPanel.Location = New-Object System.Drawing.Point(35, 510)
$logPanel.BackColor = [System.Drawing.Color]::White
$logPanel.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$form.Controls.Add($logPanel)

$logHeader = New-Object System.Windows.Forms.Label
$logHeader.Text = "SYSTEM CONSOLE FEED PROCESSOR"
$logHeader.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$logHeader.ForeColor = [System.Drawing.Color]::FromArgb(120, 130, 150)
$logHeader.Size = New-Object System.Drawing.Size(700, 25)
$logHeader.Location = New-Object System.Drawing.Point(18, 12)
$logPanel.Controls.Add($logHeader)

$outputTextBox = New-Object System.Windows.Forms.RichTextBox
$outputTextBox.Size = New-Object System.Drawing.Size(714, 95)
$outputTextBox.Location = New-Object System.Drawing.Point(18, 38)
$outputTextBox.ReadOnly = $true
$outputTextBox.BackColor = [System.Drawing.Color]::FromArgb(244, 246, 250)
$outputTextBox.ForeColor = [System.Drawing.Color]::FromArgb(38, 50, 56) # Deep Slate Text
$outputTextBox.Font = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
$outputTextBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$logPanel.Controls.Add($outputTextBox)

# Footer Layout Base
$footerPanel = New-Object System.Windows.Forms.Panel
$footerPanel.Size = New-Object System.Drawing.Size(820, 35)
$footerPanel.Location = New-Object System.Drawing.Point(0, 675)
$footerPanel.BackColor = [System.Drawing.Color]::FromArgb(255, 255, 255)
$form.Controls.Add($footerPanel)

$footerLabel = New-Object System.Windows.Forms.Label
$footerLabel.Text = "POWERED BY ELEVOHOST AUTOMATION SUITE"
$footerLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
$footerLabel.ForeColor = [System.Drawing.Color]::FromArgb(140, 150, 170)
$footerLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$footerLabel.Dock = [System.Windows.Forms.DockStyle]::Fill
$footerPanel.Controls.Add($footerLabel)

# Modern Form Dismiss Action Control
$exitButton = New-Object System.Windows.Forms.Button
$exitButton.Text = "×"
$exitButton.Size = New-Object System.Drawing.Size(40, 40)
$exitButton.Location = New-Object System.Drawing.Point(755, 20)
$exitButton.BackColor = [System.Drawing.Color]::Transparent
$exitButton.ForeColor = [System.Drawing.Color]::FromArgb(120, 130, 150)
$exitButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$exitButton.Font = New-Object System.Drawing.Font("Arial", 22, [System.Drawing.FontStyle]::Regular)
$exitButton.Cursor = [System.Windows.Forms.Cursors]::Hand
$exitButton.FlatAppearance.BorderSize = 0
$exitButton.TabStop = $false
$headerPanel.Controls.Add($exitButton)

$exitButton.Add_Click({
    $form.Close()
})

# Form Dynamic Motion Engine
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
$outputTextBox.AppendText("[$timestamp] SYSTEM: ElevoHost Core Suite Light Engine Initialized...`r`n")
$outputTextBox.AppendText("[$timestamp] STATUS: Telemetry verified RDP node state as $currentStatus.`r`n")

[System.Windows.Forms.Application]::EnableVisualStyles()
$form.ShowDialog()
