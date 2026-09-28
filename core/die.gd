class_name Die
extends RefCounted
## A six-faced die. Faces hold values 0..9 (0 = blank face), a die may carry one rune.
## `kind` names its starting face set (DiceKinds); it also sets the raise cap.

var faces: PackedInt32Array = PackedInt32Array([1, 2, 3, 4, 5, 6])
var rune: String = ""
var edited: PackedByteArray = PackedByteArray([0, 0, 0, 0, 0, 0])
var kind: String = "standard"

static func make(rune_id: String = "", kind_id: String = "standard") -> Die:
	var d := Die.new()
	d.rune = rune_id
	d.kind = kind_id
	d.faces = DiceKinds.faces(kind_id)
	return d

## Highest value a face can be raised to (9 for Giant dice, 6 otherwise).
func raise_cap() -> int:
	return DiceKinds.raise_cap(kind)

func can_raise(face_idx: int) -> bool:
	return face_idx >= 0 and face_idx <= 5 and faces[face_idx] < raise_cap()

## Rolls the die and returns the face index (0..5).
func roll(rng: Rng) -> int:
	return rng.randi_range(0, 5)

func value(face_idx: int) -> int:
	return faces[face_idx]

func raise_face(face_idx: int) -> bool:
	if not can_raise(face_idx):
		return false
	faces[face_idx] += 1
	edited[face_idx] = 1
	return true

func mirror_face(face_idx: int, src_face: int) -> bool:
	if face_idx < 0 or face_idx > 5 or src_face < 0 or src_face > 5 or face_idx == src_face:
		return false
	if faces[face_idx] == faces[src_face]:
		return false
	faces[face_idx] = faces[src_face]
	edited[face_idx] = 1
	return true

## Index of the lowest face (first on ties).
func lowest_face() -> int:
	var best := 0
	for i in 6:
		if faces[i] < faces[best]:
			best = i
	return best

func face_sum() -> int:
	var s := 0
	for f in faces:
		s += f
	return s

func to_dict() -> Dictionary:
	var f: Array = []
	for v in faces:
		f.append(v)
	var e: Array = []
	for v in edited:
		e.append(v)
	return {"faces": f, "rune": rune, "edited": e, "kind": kind}

static func from_dict(d: Dictionary) -> Die:
	var die := Die.new()
	var f := PackedInt32Array()
	for v in d.get("faces", [1, 2, 3, 4, 5, 6]):
		f.append(int(v))
	die.faces = f
	die.rune = String(d.get("rune", ""))
	die.kind = String(d.get("kind", "standard"))
	var e := PackedByteArray()
	for v in d.get("edited", [0, 0, 0, 0, 0, 0]):
		e.append(int(v))
	die.edited = e
	return die
