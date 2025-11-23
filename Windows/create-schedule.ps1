$taskName = "SQL AutoBlock Bruteforce"
$script   = "D:\mssql\AutoBlockSql.ps1"

$action = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument "-ExecutionPolicy Bypass -File `"$script`""

$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
  -RepetitionInterval (New-TimeSpan -Minutes 1) `
  -RepetitionDuration ([TimeSpan]::MaxValue)

Register-ScheduledTask `
  -TaskName $taskName `
  -Action $action `
  -Trigger $trigger `
  -RunLevel Highest `
  -User "SYSTEM" `
  -Force
# Create rule run 1 munutes
