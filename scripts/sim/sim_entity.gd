# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name SimEntity
extends RefCounted

var id := -1
var kind := 0                                # int(AgentCommand.ActionKind) — FLASHBANG / FRAG / TEAR_GAS / BREACH_CHARGE
var op_id := -1                              # owning operative
var pos := Vector2.ZERO                      # cell-unit center (D-017)
var spawned_tick := 0
var due_tick := 0                            # effect tick; entity removed after expiry
var done := false


func to_dict() -> Dictionary:
	return {
		"id": id,
		"kind": kind,
		"op_id": op_id,
		"px": pos.x,
		"py": pos.y,
		"spawned_tick": spawned_tick,
		"due_tick": due_tick,
		"done": done,
	}


static func from_dict(d: Dictionary) -> SimEntity:
	var e := SimEntity.new()
	e.id = int(d.get("id", -1))
	e.kind = int(d.get("kind", 0))
	e.op_id = int(d.get("op_id", -1))
	e.pos = Vector2(float(d.get("px", 0.0)), float(d.get("py", 0.0)))
	e.spawned_tick = int(d.get("spawned_tick", 0))
	e.due_tick = int(d.get("due_tick", 0))
	e.done = bool(d.get("done", false))
	return e
