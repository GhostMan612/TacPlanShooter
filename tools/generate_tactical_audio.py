#!/usr/bin/env python3
# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
import math
import struct
import wave
from pathlib import Path

OUT = Path(r"C:\TacPlan Shooter\assets\audio")
RATE = 22050


def write(name: str, seconds: float, gen) -> None:
    out = OUT / name
    frames = int(RATE * seconds)
    with wave.open(str(out), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        buff = bytearray()
        for i in range(frames):
            v = max(-1.0, min(1.0, gen(i / RATE, i)))
            buff.extend(struct.pack("<h", int(v * 26000)))
        w.writeframes(bytes(buff))
    print(f"{name}: {frames} frames")


def stealth(t: float, i: int) -> float:
    bass = math.sin(2 * math.pi * 55 * t) * 0.22 + math.sin(2 * math.pi * 82.5 * t) * 0.10
    pad = math.sin(2 * math.pi * 220 * t + math.sin(t * 0.7)) * 0.07
    return bass + pad


def caution(t: float, i: int) -> float:
    step = int(t * 8) % 8
    freq = [220, 261, 329, 392, 329, 261, 220, 196][step]
    env = 1.0 - (t * 8 % 1.0)
    return math.sin(2 * math.pi * freq * t) * 0.16 * env + math.sin(2 * math.pi * 55 * t) * 0.12


def combat(t: float, i: int) -> float:
    kick = math.sin(2 * math.pi * 70 * t) * 0.24 * (1.0 - (t * 4 % 1.0))
    arp = math.sin(2 * math.pi * (440 if int(t * 8) % 2 else 330) * t) * 0.10
    return kick + arp


def sting(t: float, i: int) -> float:
    return math.sin(2 * math.pi * (900 - t * 500) * t) * 0.5 * math.exp(-t * 8)


def gun(t: float, i: int) -> float:
    n = math.sin(i * 12.9898) * 43758.5453
    noise = n - math.floor(n) - 0.5
    return noise * 0.7 * math.exp(-t * 24)


def breach(t: float, i: int) -> float:
    n = math.sin(i * 78.233) * 12345.678
    noise = n - math.floor(n) - 0.5
    return (math.sin(2 * math.pi * 48 * t) * 0.5 + noise * 0.5) * math.exp(-t * 5)


def flash(t: float, i: int) -> float:
    return math.sin(2 * math.pi * 1400 * t) * 0.4 * math.exp(-t * 12)


def squelch(t: float, i: int) -> float:
    n = math.sin(i * 3.17) * 9123.45
    return (n - math.floor(n) - 0.5) * 0.4 * (1.0 - t / 0.4)


def blip(t: float, i: int) -> float:
    return math.sin(2 * math.pi * 880 * t) * 0.3 * math.exp(-t * 18)


def chime(t: float, i: int) -> float:
    return (math.sin(2 * math.pi * 660 * t) + math.sin(2 * math.pi * 990 * t) * 0.5) * 0.22 * math.exp(-t * 5)


def heartbeat(t: float, i: int) -> float:
    beat = 1.0 if (t % 0.85) < 0.07 else 0.15
    return math.sin(2 * math.pi * 90 * t) * 0.32 * beat


if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    write("bgm_stealth_pad.wav", 8.0, stealth)
    write("bgm_caution_pulse.wav", 8.0, caution)
    write("bgm_combat_alert.wav", 8.0, combat)
    write("sfx_alert_sting.wav", 0.6, sting)
    write("sfx_gun_suppressed.wav", 0.25, gun)
    write("sfx_gun_loud.wav", 0.35, gun)
    write("sfx_breach_c4.wav", 1.2, breach)
    write("sfx_flashbang.wav", 0.8, flash)
    write("sfx_radio_squelch.wav", 0.4, squelch)
    write("sfx_ui_blip.wav", 0.2, blip)
    write("sfx_gocode_chime.wav", 0.7, chime)
    write("sfx_heartbeat.wav", 3.0, heartbeat)
