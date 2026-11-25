# Placeholder WAV generator for BP-08 (Ducking, Radio Squelch, Heartbeat)
param([string]$OutDir = "C:\TacPlan Shooter\assets\audio")

function WInt([System.IO.BinaryWriter]$bw, [int]$v) {
	$bw.Write([byte]($v -band 0xff)); $bw.Write([byte](($v -shr 8) -band 0xff))
	$bw.Write([byte](($v -shr 16) -band 0xff)); $bw.Write([byte](($v -shr 24) -band 0xff))
}
function WInt16([System.IO.BinaryWriter]$bw, [int]$v) {
	$bw.Write([byte]($v -band 0xff)); $bw.Write([byte](($v -shr 8) -band 0xff))
}
function MakeWav([string]$path, [int]$rate, [int]$ms, [scriptblock]$gen) {
	New-Item -ItemType Directory -Path (Split-Path $path) -Force -ErrorAction SilentlyContinue | Out-Null
	$n = [int]($rate * $ms / 1000)
	$bw = New-Object System.IO.BinaryWriter([System.IO.File]::Create($path))
	$bw.Write([byte[]]@(0x52,0x49,0x46,0x46)); WInt $bw (36 + $n * 2)
	$bw.Write([byte[]]@(0x57,0x41,0x56,0x45)); $bw.Write([byte[]]@(0x66,0x6d,0x74,0x20))
	WInt $bw 16; WInt16 $bw 1; WInt16 $bw 1
	WInt $bw $rate
	WInt $bw ($rate * 2)
	WInt $bw 0
	$bw.Write([byte[]]@(0x64,0x61,0x74,0x61)); WInt $bw ($n * 2)
	for ($i = 0; $i -lt $n; $i++) {
		$v = ([int]($gen.Invoke($i)[0])) -band 0xffff
		WInt16 $bw $v
	}
	$bw.Close()
}

New-Item -Path $OutDir -ItemType Directory -ErrorAction SilentlyContinue | Out-Null
for ($i = 1; $i -le 8; $i++) {
	MakeWav -path "$OutDir\sfx_ui_squelch_$([string]$i.ToString('00')).wav" -rate 22050 -ms 500 -gen { param($j) $s = $j / 12000.0; [int](900 * [math]::Sin($s * 2 * 3.14159 * 400) * (1 - $s / 1.2)) }
}
MakeWav -path "$OutDir\sfx_ui_squelch_strong.wav" -rate 22050 -ms 700 -gen { param($j) $s = $j / 9000.0; [int](1300 * [math]::Sin($s * 2 * 3.14159 * 380) * (1 - $s / 2.0)) }
MakeWav -path "$OutDir\sfx_ui_heartbeat.wav" -rate 22050 -ms 3000 -gen { param($j) $s = $j / 48000.0; $beat = if (($s % 0.8) -lt 0.08) {1.0} else {0.3}; [int](0.8 * $beat * [math]::Sin($s * 2 * 3.14159 * 95)) }
Write-Output "Placeholder WAVs written to $OutDir"
