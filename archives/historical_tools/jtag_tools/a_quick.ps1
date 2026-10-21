[Console]::OutputEncoding=[System.Text.UTF8Encoding]::new($false)
$ProgressPreference='SilentlyContinue'
Get-PnpDevice -PresentOnly | Where-Object { $_.InstanceId -match '^(USB|FTDIBUS)' -or $_.Class -eq 'Ports' -or $_.Status -eq 'Error' } | Select-Object Status,Class,FriendlyName,InstanceId,Problem | ConvertTo-Json -Depth 5
