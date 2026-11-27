param([string]$Serial = "7040016025040287")

adb -s $Serial logcat -c
adb -s $Serial shell am force-stop com.tacplan.game
adb -s $Serial shell am start -n com.tacplan.game/com.godot.game.GodotApp | Out-Null
Start-Sleep -Seconds 4
adb -s $Serial shell input tap 360 490
Start-Sleep -Seconds 5
adb -s $Serial exec-out screencap -p > "screenshots\verify_in_mission_3d.png"
Write-Output "captured screenshots/verify_in_mission_3d.png"
Write-Output "godot:E=$((adb -s $Serial logcat -d -s godot:E | Measure-Object -Line).Lines)"
