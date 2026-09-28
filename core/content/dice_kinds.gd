class_name DiceKinds
extends RefCounted
## Die kinds: the face set a die starts with. Values range 0..9 across all kinds.
## 0 is a blank face: it moves 0 tiles on the board, adds 0 pips and never forms a combo.
## Values above 6 are allowed (Giant) and are drawn as numerals by the presentation layer.
## `cap` is the highest value a Forge/Face Raise may raise a face to (9 for Giant, else 6).
## `price` is the shop price for a new die of that kind.

const DEFS := {
	"standard": {"name": "Standard", "faces": [1, 2, 3, 4, 5, 6], "rarity": "common", "price": 30, "cap": 6,
		"desc": "An honest die: 1 to 6."},
	"low": {"name": "Low", "faces": [1, 1, 2, 2, 3, 3], "rarity": "common", "price": 20, "cap": 6,
		"desc": "Faces 1,1,2,2,3,3. Short hops, easy pairs."},
	"odd": {"name": "Odd", "faces": [1, 1, 3, 3, 5, 5], "rarity": "common", "price": 25, "cap": 6,
		"desc": "Faces 1,1,3,3,5,5. Only odd numbers."},
	"even": {"name": "Even", "faces": [2, 2, 4, 4, 6, 6], "rarity": "common", "price": 35, "cap": 6,
		"desc": "Faces 2,2,4,4,6,6. Only even numbers."},
	"loaded": {"name": "Loaded", "faces": [1, 2, 3, 4, 6, 6], "rarity": "common", "price": 35, "cap": 6,
		"desc": "Faces 1,2,3,4,6,6. The five became a six."},
	"twin": {"name": "Twin", "faces": [3, 3, 3, 4, 4, 4], "rarity": "rare", "price": 40, "cap": 6,
		"desc": "Faces 3,3,3,4,4,4. Pairs up with anything."},
	"high": {"name": "High", "faces": [4, 4, 5, 5, 6, 6], "rarity": "rare", "price": 50, "cap": 6,
		"desc": "Faces 4,4,5,5,6,6. Never rolls low."},
	"gambler": {"name": "Gambler", "faces": [0, 0, 6, 6, 6, 6], "rarity": "rare", "price": 45, "cap": 6,
		"desc": "Faces 0,0,6,6,6,6. A blank moves nothing and scores nothing."},
	"giant": {"name": "Giant", "faces": [4, 5, 6, 7, 8, 9], "rarity": "epic", "price": 65, "cap": 9,
		"desc": "Faces 4 to 9. Forge can raise it up to 9."},
}

const IDS := ["standard", "low", "odd", "even", "loaded", "twin", "high", "gambler", "giant"]

## Rarity weights used when rolling a random kind (drafts, shop, events).
const RARITY_WEIGHTS := {"common": 60, "rare": 30, "epic": 10}

const MIN_VALUE := 0
const MAX_VALUE := 9

static func def(id: String) -> Dictionary:
	return DEFS.get(id, DEFS.standard)

static func faces(id: String) -> PackedInt32Array:
	return PackedInt32Array(def(id).faces)

static func raise_cap(id: String) -> int:
	return int(def(id).cap)

static func of_rarity(r: String) -> Array[String]:
	var out: Array[String] = []
	for id in IDS:
		if DEFS[id].rarity == r:
			out.append(id)
	return out

static func random_kind(rng: Rng, rarity_filter := "") -> String:
	var r := rarity_filter
	if r == "":
		r = rng.weighted(RARITY_WEIGHTS)
	return rng.pick(of_rarity(r))

## Label for a new die of this kind, e.g. "Giant Die".
static func label(id: String) -> String:
	return "%s Die" % def(id).name
