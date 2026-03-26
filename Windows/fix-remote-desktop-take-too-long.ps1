Write-Host "Starting configuration..." -ForegroundColor Green

# 1. Disable Task Offload
Write-Host "Disabling Task Offload..." -ForegroundColor Yellow

Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" `
    -Name "DisableTaskOffload" -Value 1 -Type DWord

Write-Host "DisableTaskOffload configured." -ForegroundColor Green


# 2. fQueryUserConfigFromLocalMachine

$os = (Get-CimInstance Win32_OperatingSystem).Caption

if ($os -match "Windows Server 2016|Windows Server 2019") {
    Write-Host "Skipping fQueryUserConfigFromLocalMachine (not required for this OS)" -ForegroundColor Cyan
} else {
    Write-Host "Configuring fQueryUserConfigFromLocalMachine..." -ForegroundColor Yellow

    New-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Terminal Services" `
        -Name "fQueryUserConfigFromLocalMachine" -Value 1 -PropertyType DWord -Force

    Write-Host "fQueryUserConfigFromLocalMachine configured." -ForegroundColor Green
}

Write-Host "Configuration completed." -ForegroundColor Green