class_name LoadingScreen
extends Control

var percent := 0.0

func advance(p: float) -> void:
	percent = clamp(p, 0.0, 1.0)
