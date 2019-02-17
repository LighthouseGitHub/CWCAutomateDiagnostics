(new-object Net.WebClient).DownloadString('http://bit.ly/LTPoSh') | iex

# WMI Service check and start/auto
function serviceCheck($service){
	$svc_info = Get-WmiObject win32_service | where-object {$_.name -eq $service}
	if ($svc_info.State -eq 'Stopped') { Start-Service $service; $state_check = 'Previously Stopped, starting service now' -f $service }
	elseif ($svc_info.state -eq 'Running') { $state_check = 'Running' -f $service }
	
	if ($svc_info.StartMode -eq 'Auto') { $start_check = 'Automatic' }
	else { $svc_info.ChangeStartMode('Auto'); $start_check = 'Previously set to {0} changed to Auto' -f $svc_info.StartMode }
	@{'Status' = $state_check; 'Start Mode' = $start_check }
}

# Check services
$ltservice_check = serviceCheck('LTService')
$ltsvcmon_check = serviceCheck('LTSVCMon')

# Get ltservice info
$info = Get-LTServiceInfo
$lastsuccess = Get-Date $info.LastSuccessStatus
$lasthbsent = Get-Date $info.HeartbeatLastSent
$lasthbrcv = Get-Date $info.HeartbeatLastReceived

# Check online and heartbeat statuses
$online_threshold = (Get-Date).AddMinutes(-5)
$heartbeat_threshold = (Get-Date).AddMinutes(-5)
$servers = ($info.'Server Address').Split('|')
$online = $lastsuccess -ge $online_threshold
$heartbeat_rcv = $lasthbrcv -ge $heartbeat_threshold 
$heartbeat_snd = $lasthbsent -ge $heartbeat_threshold
$heartbeat = $heartbeat_rcv -or $heartbeat_snd

# Get server list
$Server = $servers|Select-Object -Expand 'Server' -EA 0

# Check updates
$update = Try { $results = Update-LTService -WarningVariable updatetest 3>&1 -WarningAction Stop; $update_text = 'Updated from {1} to {0}' -f (Get-LTServiceInfo).Version,$info.Version } catch { $update_text = 'No update needed, on {0}' -f (Get-LTServiceInfo).Version }

# Output diagnostic data in JSON format
$diag = @{
    'id' = $info.id
	'version' = $info.Version
	'server_addr' = $servers -join ", "
	'online' = $online
	'heartbeat' = $heartbeat
	'update' = $update_text
	'updatedebug' = $updatetest[0].message
	'lastcontact'  = $info.LastSuccessStatus
	'heartbeat_sent' = $info.HeartbeatLastSent
	'heartbeat_rcv' = $info.HeartbeatLastReceived
	'svc_ltservice' = $ltservice_check
	'svc_ltsvcmon' = $ltsvcmon_check
}
$diag | ConvertTo-Json -depth 2