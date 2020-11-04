# Copyright 1998-2018 Epic Games, Inc. All Rights Reserved.

$PublicIp = Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing

Write-Output "Public IP: $PublicIp"

$peerConnectionOptions = "{ \""iceServers\"": [{\""urls\"": [\""stun:stun.l.google.com:19302\"",\""turn:" + $PublicIp + ":19303\""], \""username\"": \""{{{TURN_LOGIN}}}\"", \""credential\"": \""{{{TURN_PASSWORD}}}\""}] }"

$ProcessExe = "node.exe"
$Arguments = @("cirrus", "--peerConnectionOptions=""$peerConnectionOptions""", "--publicIp=$PublicIp")
# Add arguments passed to script to Arguments for executable
$Arguments += $args

Write-Output "Running: $ProcessExe $Arguments"
Start-Process -FilePath $ProcessExe -ArgumentList $Arguments -Wait -NoNewWindow
