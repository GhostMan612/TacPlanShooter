# ============================================================
# As Above, So Below. As Within, So Without.
# The Future Dictates the Past and the Past is Always Present.
# ============================================================
class_name CommitReveal
extends Object


func commit(plan_json: String, salt: String) -> String:
	return (plan_json + salt).sha256_text()


func verify(plan_json: String, salt: String, commitment: String) -> bool:
	return (plan_json + salt).sha256_text() == commitment
