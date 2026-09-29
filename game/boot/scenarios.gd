extends RefCounted
## Screenshot scenarios for the boot screens: asset_missing (the missing-assets screen).


static func build(name: String) -> Node:
	return AssetCheck.screen() if name == "asset_missing" else null


static func names() -> PackedStringArray:
	return PackedStringArray(["asset_missing"])
