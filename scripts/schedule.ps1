# scripts/schedule.ps1
$action = New-ScheduledTaskAction -Execute "python" -Argument "scripts/analyze.py"
$trigger = New-ScheduledTaskTrigger -Daily -At 3am
Register-ScheduledTask -TaskName "HistoireDataUpdate" -Action $action -Trigger $trigger