class_name Rng
extends RefCounted
## Seeded xorshift64* generator. All game randomness goes through one of these.
## State is serialised as a decimal string so it survives JSON round trips.

const _MUL := 2685821657736338717 # 0x2545F4914F6CDD1D
const _GOLDEN := -7046029254386353131 # 0x9E3779B97F4A7C15
const _SM1 := -4658895280553007687 # 0xBF58476D1CE4E5B9
const _SM2 := -7723592293110705685 # 0x94D049BB133111EB

var state: int = 1

func _init(seed_value: int = 1) -> void:
	set_seed(seed_value)

func set_seed(seed_value: int) -> void:
	# splitmix64 scramble so small seeds give well-mixed states
	var z := seed_value + _GOLDEN
	z = (z ^ _lsr(z, 30)) * _SM1
	z = (z ^ _lsr(z, 27)) * _SM2
	z = z ^ _lsr(z, 31)
	if z == 0:
		z = _GOLDEN
	state = z

static func _lsr(x: int, n: int) -> int:
	return (x >> n) & ((1 << (64 - n)) - 1)

## Next raw 32-bit unsigned value (0 .. 2^32-1).
func next_u32() -> int:
	var x := state
	x ^= _lsr(x, 12)
	x ^= x << 25
	x ^= _lsr(x, 27)
	state = x
	return _lsr(x * _MUL, 32)

## Inclusive range.
func randi_range(from: int, to: int) -> int:
	if to <= from:
		return from
	return from + next_u32() % (to - from + 1)

## Uniform float in [0, 1).
func randf() -> float:
	return float(next_u32()) / 4294967296.0

func chance(p: float) -> bool:
	return self.randf() < p

func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[self.randi_range(0, arr.size() - 1)]

## In-place Fisher-Yates shuffle.
func shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := self.randi_range(0, i)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t

## Weighted pick: weights is {key: weight}. Iterates keys in insertion order.
func weighted(weights: Dictionary) -> Variant:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := self.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r < 0.0:
			return k
	return weights.keys().back()

func to_dict() -> Dictionary:
	return {"state": str(state)}

static func from_dict(d: Dictionary) -> Rng:
	var r := Rng.new(1)
	r.state = String(d.get("state", "1")).to_int()
	return r
