# ./Auto-block-MSSQL-brute-force-attack.ps1 -DryRun to test
# ================== CONFIG ==================
param(
    [switch]$DryRun
)

# ================== CONFIG ==================
$ErrorLogPath  = "C:\Program Files\Microsoft SQL Server\MSSQL15.MSSQLSERVER\MSSQL\Log\ERRORLOG"
$MinutesBack   = 5
$Threshold     = 10
$SqlPort       = 1433
$RulePrefix    = "AutoBlock-SQLBruteforce"
$BlockLogFile  = "D:\blocked_ips.log"

$ipPattern = [Regex]::new("\b\d{1,3}(\.\d{1,3}){3}\b")
$own_IPs   = [Regex]::new("(127\.0\.0\.1|10\.\d{1,3}\.\d{1,3}\.\d{1,3}|192\.168\.\d{1,3}\.\d{1,3}|203\.0\.113\.\d{1,3})")

# Timestamp đầu dòng: 2025-05-23 08:27:17.95
$tsPattern = [Regex]::new("^(?<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{2,3})")

$lines = Get-Content $ErrorLogPath -Tail 50000
$since = (Get-Date).AddMinutes(-$MinutesBack)

# ================== PARSE LOGIN FAILED LINES ==================
$recentFailIPs = foreach ($line in $lines) {

    # chỉ bắt đúng dòng fail có CLIENT
    if ($line -notmatch "Login failed for user" -or $line -notmatch "\[CLIENT:") { continue }

    # lọc theo time window
    $tsMatch = $tsPattern.Match($line)
    if ($tsMatch.Success) {
        try {
            $ts = [datetime]::ParseExact($tsMatch.Groups["ts"].Value, "yyyy-MM-dd HH:mm:ss.ff", $null)
            if ($ts -lt $since) { continue }
        } catch {}
    }

    # lấy IP trong line
    $ipMatch = $ipPattern.Match($line)
    if ($ipMatch.Success) {
        $ip = $ipMatch.Value
        if ($own_IPs.IsMatch($ip)) { continue }
        $ip
    }
}

if (-not $recentFailIPs) {
    Write-Host "No brute-force activity found in last $MinutesBack minutes."
    return
}

# ================== COUNT & BLOCK ==================
$recentFailIPs |
    Group-Object |
    Where-Object { $_.Count -ge $Threshold } |
    ForEach-Object {

        $ip = $_.Name
        $count = $_.Count
        $ruleName = "$RulePrefix-$ip"

        if ($DryRun) {
            Write-Host "[DRY-RUN] Would block IP: $ip (fails=$count)"
            return
        }

        if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {

            New-NetFirewallRule `
                -DisplayName $ruleName `
                -Direction Inbound `
                -Action Block `
                -RemoteAddress $ip `
                -Protocol TCP `
                -LocalPort $SqlPort | Out-Null

            $msg = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') BLOCKED $ip fails=$count"
            Add-Content -Path $BlockLogFile -Value $msg
            Write-Host $msg
        }
        else {
            Write-Host "Already blocked: $ip (fails=$count)"
        }
    }
