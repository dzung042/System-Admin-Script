Set-NetFirewallProfile -Profile Domain,Public,Private -Enabled False
Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Terminal*Server\WinStations\RDP-TCP\ -Name PortNumber 10000
shutdown -r -t 0
