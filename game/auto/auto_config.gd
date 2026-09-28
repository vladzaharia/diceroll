class_name AutoConfig
extends RefCounted
## Persists the player's AUTO policy (AutoRules) in user://settings.cfg, section [auto],
## one key per AutoRules.to_dict() entry. AUTO itself (on/off) is never persisted: a run
## always starts (or continues) with AUTO off.

const CFG := "user://settings.cfg"
const SECTION := "auto"


static func load_rules() -> AutoRules:
	var cfg := ConfigFile.new()
	if cfg.load(CFG) != OK or not cfg.has_section(SECTION):
		return AutoRules.new()
	var d := {}
	for k in cfg.get_section_keys(SECTION):
		d[k] = cfg.get_value(SECTION, k)
	return AutoRules.from_dict(d)


static func save_rules(r: AutoRules) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CFG)
	var d := r.to_dict()
	for k in d:
		cfg.set_value(SECTION, k, d[k])
	cfg.save(CFG)
