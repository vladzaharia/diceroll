# Diceroll: the real-item Armory

Date: 2026-09-29 · Status: proposal. Numbers are starting values for the sim.
User request: "Our armory should use the actual weapon models we have from KayKit: different
weapons, different armors, etc."
Replaces: the 4 abstract gear pieces in `core/content/gear.gd` (helm/blade/boots/charm, L1–8,
L4/L8 trait pairs).
Reads with:
- docs/reviews/2026-09-28-meta-design-review.md §4.2 (vertical budget) and §5.1 (Armory)
- docs/plans/balance.md ("Meta numbers", "Tools and sweep notes")
- docs/design/2026-09-28-classes-enemies-skins.md (classes, skins, profile v2).

---

## 0. Summary

- **3 slots, all backed by real models:**
  - **WEAPON** (main hand; `handslot.r`, or `handslot.l` for bows)
  - **OFF-HAND** (`handslot.l`, belt or back)
  - **TRINKET** (a belt or hip prop, shown in the HUD).
- **Helm and Boots are dropped.** No helmet or armour meshes exist. Armour looks are class
  textures, which are skins (cosmetic only).
- **32 items:** 16 weapons, 8 off-hands and 8 trinkets.
  - Every item is a **sidegrade** with one dice-centric rule: Pairs, sets, High Roller, rerolls,
    kept dice, runes, 1s and 2s, overkill, first strike, Block, kills, Forge, board.
  - Every one of today's 16 gear traits lives on as an item effect, so nothing players liked is
    lost.
- **Progression:**
  - Power grows by **slot rank R0–8**, one rank per slot. It uses the same Crowns curve as today
    (15 … 190; 730 per slot).
  - Rank sets the equipped item's **tier (I: R1–3, II: R4–7, III: R8)** and a small base stat:
    Weapon R8 +1 ATK, Off-hand +0.5 HP per rank (max +4). The Trinket rank has no base stat.
  - Items themselves are **unlocked once** and never levelled individually. That keeps the choice
    horizontal and the grind flat.
- **Unlocks:**
  - Knight's kit (Sword, Round Shield, Tankard) at the start.
  - Each class brings its signature items when it unlocks.
  - Existing gear milestones grant pairs of items.
  - The rest cost Crowns (100–160) or Sigils (4).
- **Class affinity:** a class's signature weapon and off-hand work **one tier higher** (max III).
  This matters early and mid-game; at max ranks it disappears, so any class can use any item.
- **2H rule:** two-handed weapons block *hand* off-hands (shields, parrying dagger). Belt and
  back off-hands (Spellbook, Quiver, Smoke Bomb, Shuriken) stay allowed.
- **Visuals:**
  - Equipped items attach to the hero in runs, the Camp and class select.
  - The weapon type picks the attack animation set (1H, 2H, dual, bow, crossbow, magic,
    unarmed).
  - The Armory shows rotating 3D previews, and the Camp racks display owned items.
- **Budget:** full armory maxed vs empty ≤ **+15 pp** (realistic, max profile). Any single item
  at III vs an empty slot ≤ **+6 pp**. Within a slot, the best and worst items are ≤ **4 pp**
  apart.
- **Migration:** profile v2 → v3. Old levels map to slot ranks (blade → Weapon, helm → Off-hand,
  max(boots, charm) → Trinket, with a Crowns refund for the lower one). Old pieces grant the
  items that carry their traits, and chosen traits auto-equip.

---

## 1. Slots

| slot | where the model goes | rank base stat (all items) | item count |
|---|---|---|---|
| **Weapon** | `handslot.r` (bows: `handslot.l`, like today's Ranger) | +1 ATK at R8 (today's Blade cap) | 16 |
| **Off-hand** | `handslot.l` (hand items), or a belt/back socket (belt and back items) | +0.5 max HP per rank, max +4 (today's Helm cap) | 8 |
| **Trinket** | a hip or belt socket (small prop, 0.6× scale); also an icon in the run HUD | none (today's gold cap moves to the Coin Purse) | 8 |

Rules:
- **Tier from rank:** R0 = the slot isn't crafted, so the equipped item has no effect (it is
  still shown). R1–3 = tier I, R4–7 = tier II, R8 = tier III.
- **Affinity:** +1 tier (I → II, II → III) for the class's signature weapon and off-hand (§5).
  III is the cap.
- **Two-handed weapons** (Greatsword, Great Axe, Spear, Scythe, Arcane Staff, Druid Staff, Hunting
  Bow) can't be combined with a *hand* off-hand (the 3 shields, Parrying Dagger). *Belt/back*
  off-hands (Spellbook, Quiver, Smoke Bomb, Shuriken) are always allowed.
- **Equipping** is free and saved **per class** (`armory.equipped[class]`), chosen in the Armory
  or on the Start Run panel. Every class starts with its signature kit equipped (§5).

---

## 2. Weapons (16)

"Style" is the attack animation set. Numbers are **I / II / III**. "After mult" means added
after the combo multiplier, like Straight Shooter.

| id | name | model (pack) | hands | style (clip) | effect I / II / III | affinity |
|---|---|---|---|---|---|---|
| `sword` | Arming Sword | `sword_1handed` (Adventurers; FWB `sword_A`–`C` as skins) | 1H | melee_1h (`Melee_1H_Attack_Slice_Diagonal`) | **Twin Edge:** Pair or Two Pair: **+2 / +4 / +6** damage after mult | Knight |
| `greatsword` | Greatsword | `sword_2handed_color` (Adventurers) / FWB `sword_E` | 2H | melee_2h (`Melee_2H_Attack_Slice`) | **Great Arc:** Three of a Kind or better: combo mult **+0.25 / +0.4 / +0.5** | – |
| `hand_axe` | Hand Axe | `axe_1handed` / FWB `axe_A` | 1H | melee_1h (`Melee_1H_Attack_Chop`) | **Cleave:** a kill carries **30 / 40 / 50%** of the excess damage to the next enemy (today's Cleave trait) | – |
| `great_axe` | Great Axe | `axe_2handed` (Adventurers; the Barbarian's axe today) | 2H | melee_2h (`Melee_2H_Attack_Chop`) | **Rampage:** each consecutive attack on the same target: **+3 / +5 / +7** flat, stacking to 3; resets on a target change or kill | Barbarian |
| `warhammer` | Warhammer | `paladin_hammer` (Mystery S4; FWB `hammer_A`–`D` as skins) | 1H | melee_1h (`Melee_1H_Attack_Chop`) | **Crush:** the highest die in the scoring group counts its pips **×1.5 / ×1.75 / ×2** (not on a die that already carries Heavy) | Paladin |
| `spear` | Spear | FWB `spear_A` | 2H | melee_2h (`Melee_2H_Attack_Stab`) | **First Strike:** your first attack each fight **×1.2 / ×1.3 / ×1.4**; +0.1 more against a final boss (absorbs today's Opener) | – |
| `scythe` | Scythe | FWB `scythe` | 2H | melee_2h (`Melee_2H_Attack_Spin`) | **Reap:** each enemy killed heals **2 / 3 / 4** | Necromancer |
| `dagger` | Dagger | `dagger` (Adventurers; FWB `dagger_A`–`C` as skins) | 1H | **dual** if the off-hand is the Parrying Dagger or Shuriken, else melee_1h (`Melee_1H_Attack_Stab`) | **Quick Hands:** +1 combat reroll on turn 1 / turns 1–2 / turns 1–3 of each fight | Rogue |
| `katana` | Katana | `Ninja_Katana` (Mystery S4) | 1H | melee_1h (`Melee_1H_Attack_Slice_Horizontal`) | **Flow:** each die rerolled this turn: +1 pip at attack, max **2 / 3 / 4** dice | Ninja |
| `arcane_staff` | Arcane Staff | `staff` (Adventurers; FWB `staff_A`–`D` as skins) | 2H | magic (`Ranged_Magic_Shoot`) | **Channel:** each runed die in the scoring group: **+1 pip (max 2 dice) / +1 (max 3) / +2 (max 3)** | Mage |
| `druid_staff` | Druid Staff | `druid_staff` (Adventurers) | 2H | magic (`Ranged_Magic_Spellcasting`) | **Grove:** at each biome change, raise the lowest face of **1 / 2 / 2** dice by +1; III also at run start | Druid |
| `wand` | Wand | `wand` (Adventurers) / FWB `wand_A` | 1H | magic (`Ranged_Magic_Shoot`) | **Spark:** the first attack each fight with a combo mult ≥ 2: **+0.5 / +0.75 / +1.0** mult | – |
| `hunting_bow` | Hunting Bow | `bow_withString` (Adventurers; FWB `bow_A`–`C_withString` as skins) | 2H | bow (`Ranged_Bow_Release`) | **Opening Volley:** at fight start, hit a random enemy for **4 / 6 / 8 × (1 + 0.15·(lap−1))** | Ranger |
| `crossbow` | Crossbow | `crossbow_1handed` (Adventurers) | 1H | **crossbow** (new alias → `Ranged_1H_Shoot`) | **Deadshot:** High Roller: **+4 / +7 / +10** damage after mult (absorbs Long Edge) | – |
| `claws` | Claws | FWB `fistweapon_C_right` (+ `_left` on the off hand when it's free) | 1H | unarmed (`Melee_Unarmed_Attack_Punch_A`) | **Scrap:** each die showing 1 or 2: **+2 / +3 / +4** damage after mult | Monster Kid |
| `wrench` | Wrench | `engineer_Wrench` (Adventurers) | 1H | melee_1h (`Melee_1H_Attack_Chop`) | **Tinker:** Forge tiles +1 edit / and shop Face Raises cost 18 (not 25) / Forge tiles +2 edits | Engineer |

Not used: FWB `halberd` (its splash overlaps Ember/Mage) and the Orc axe and club (enemy
identity). Either can come back as a skin variant.

---

## 3. Off-hands (8)

| id | name | model | mount | effect I / II / III | affinity |
|---|---|---|---|---|---|
| `round_shield` | Round Shield | `shield_round_color` (Adventurers; FWB `shield_A`–`B` as skins) | hand | **Bulwark:** Block **4 / 6 / 8** on turn 1 of every fight; III also **Last Stand** (once per run, a lethal hit leaves you at 1 HP if you were above 50%) | Knight |
| `spiked_shield` | Spiked Shield | `shield_spikes_color` | hand | **Thorns:** an enemy whose attack hits you or your Block takes **2 / 3 / 4** | – |
| `oath_shield` | Oath Shield | `paladin_shield` (Mystery S4) | hand | **Aegis:** a Pair or better grants Block = the set's value **×1 / ×1.5 / ×2** | Paladin |
| `parrying_dagger` | Parrying Dagger | `dagger` / FWB `dagger_B` | hand | **Steady:** each kept (not rerolled) die +1 pip, max **1 / 2 / 3** dice | Rogue |
| `spellbook` | Spellbook | `spellbook_open` (in hand for 1H; `spellbook_closed` on the belt with a 2H weapon) | belt | **Tome:** your 3rd attack each fight: combo mult **+0.5 / +0.75 / +1.0** | Mage |
| `quiver` | Quiver | `quiver` (Adventurers) | back | **Spare Arrows:** every 3rd attack in a fight also shoots a random enemy for **5 / 8 / 11 × (1 + 0.15·(lap−1))** | Ranger |
| `smoke_bomb` | Smoke Bomb | `smokebomb` (Adventurers) | belt | **Vanish:** the first enemy attack each fight deals **40 / 60 / 80%** less | – |
| `shuriken` | Shuriken | `Ninja_Shuriken` (Mystery S4) | belt | **Barrage:** each die you reroll deals **1 / 2 / 2** damage to a random enemy, max **3 / 3 / 4** per turn | Ninja |

---

## 4. Trinkets (8)

These carry today's economy and board traits, so no existing utility is lost.

| id | name | model | effect I / II / III | replaces |
|---|---|---|---|---|
| `tankard` | Tankard | `mug_full` (Adventurers) | Lap heal **+0.5 / +1 / +1.5%**; III also campfires +10% | Hearty, Camper |
| `compass` | Compass | `compass_base` (RPGTools) | Portal range **+2** / and value ties move the higher value / **at R6+: +1 board reroll per biome** (a rank breakpoint, not a tier) | Boots R6, Long Stride, Pathfinder's Eye |
| `lantern` | Lantern | `lantern` (RPGTools) | Traps, ice, lava and heat **−20 / −35 / −50%**; III also traps and ice dodge on 3+ | Boots hazard, Sure Foot |
| `coin_purse` | Coin Purse | `Gems_Sack` / `Money_Coins_Stack_Small` (ResourceBits) | Gold **+4 / +8 / +12%**; II also passing the Treasury banks +5; III also Treasury cash-outs ×1.25 | Charm %, Tithe, Interest |
| `traders_map` | Trader's Map | `map_rolled` (RPGTools) | Restock 7 gold / and 1 free restock per shop / and shops show +1 item | Haggle, Regular |
| `healers_flask` | Healer's Flask | `potion_medium_red` (Adventurers) | Every shop offers a potion / and potions heal +5% / +10% | Apothecary |
| `skeleton_key` | Skeleton Key | `key_gold` (Dungeon EXTRA) | Chest rune choices: 1 of **4** / and chest gold ×1.25 / and the first chest of each biome is always a rune chest | – |
| `loaded_die` | Loaded Die | `D6_A_red` (BoardGameBits) | At the first combat roll of each fight, **1 / 2 / all** dice showing a blank (0) or a 1 reroll for free | – |

---

## 5. Class signature kits (the default loadout, and affinity)

A class's kit is **owned when the class unlocks** and equipped by default. It reproduces today's
look.

| class | weapon | off-hand | look today (Character.MODELS) | note |
|---|---|---|---|---|
| Knight | Arming Sword | Round Shield | sword_1handed + shield_badge_color | the shield model changes to `shield_round_color`, or keep `shield_badge_color` as the Round Shield's default skin |
| Barbarian | Great Axe | – (2H) | axe_2handed | same |
| Mage | Arcane Staff | Spellbook (belt) | staff | the book is new, on the belt |
| Rogue | Dagger | Parrying Dagger | dagger ×2 (dual) | same (dual style) |
| Paladin | Warhammer | Oath Shield | (classes doc) paladin_hammer + paladin_shield | same |
| Ranger | Hunting Bow | Quiver | bow_withString | quiver on the back, as planned |
| Ninja | Katana | Shuriken | (classes doc) Ninja_Katana | same |
| Druid | Druid Staff | – | druid_staff | same |
| Engineer | Wrench | – | engineer_Wrench | same |
| Necromancer | Scythe | – | (classes doc: skull staff) | **change:** the Scythe (FWB) replaces the skull staff; see Q3 |
| Monster Kid | Claws | – | (classes doc: unarmed) | claws on both hands |

- Every class also starts with the **Tankard** trinket equipped, if owned.
- Affinity stacks with nothing else. A Knight with a Hunting Bow uses the bow at its normal
  tier.

---

## 6. Acquisition and progression (deterministic, non-monetized)

### 6.1 Slot ranks

- `Camp.rank_slot(slot)` costs Crowns via `GearDefs.COSTS` (15, 25, 40, 70, 100, 130, 160, 190;
  730 per slot).
- **The Armory unlocks** at `first_steps` (run 1), as the Helm did.
- The Weapon and Off-hand ranks start craftable at run 1. The Trinket rank opens with the first
  trinket unlock.
- There are **no trait pairs anymore**. The choice is *which item*, and the old traits live on
  as items.

### 6.2 Item unlocks

| source | items |
|---|---|
| Fresh profile | Arming Sword, Round Shield, Tankard (the Knight's kit) |
| Class unlock | that class's weapon and off-hand (§5) |
| `wanderer` (run ~2; was Blade) | Hand Axe, Coin Purse |
| `gate_crasher` (run ~4; was Boots) | Compass, Lantern |
| `boss_seen` (run ~6; was Charm) | Crossbow, Healer's Flask |
| Crowns (Armory shop), any time after the Armory opens | Greatsword 120 · Spear 120 · Wand 100 · Spiked Shield 100 · Smoke Bomb 100 · Trader's Map 100 · Skeleton Key 140 · Loaded Die 160 · **any class signature item before its class unlocks: 150** |
| Sigils (alternative) | any purchasable item: **4 Sigils** (the existing `gear` price) |

- **Crowns sink:** ranks 3 × 730 = 2,190 (was 4 × 730 = 2,920), plus purchasable items ≈ 1,100
  (+ up to about 1,650 for early signature buys), so ≈ **3,300–4,000**. That is slightly more
  than today, so the "maxed around run 45" pacing holds. Re-check with the campaign sim.
- `UnlockDefs`: kind `gear` becomes kind **`items`** (ids from `ItemDefs.IDS`). The Sigil price
  stays 4.

### 6.3 Profile schema (v2 → **v3**; v2 is the skins schema)

```text
armory: {
  ranks:    {weapon: 0..8, offhand: 0..8, trinket: 0..8},
  owned:    [item ids],                              # content order
  equipped: {class_id: {weapon: id|"", offhand: id|"", trinket: id|""}},
  seen_new: [item ids]                               # "new" dots
}
# removed: gear, gear_traits (kept read-only in from_dict for migration)
```

`MetaRun.build(profile, class)` emits:

```text
items: {weapon: {id, tier}, offhand: {id, tier}, trinket: {id, tier}}
hp:  offhand-rank HP
atk: weapon R8 ATK
lap_rerolls: compass rank ≥ 6
```

Tiers are resolved *at build time* (rank + affinity), so replays are exact.

### 6.4 Migration (v1/v2 gear → v3 armory), fair and one-time

| old | new |
|---|---|
| `blade` level L | Weapon rank = L |
| `helm` level L | Off-hand rank = L |
| `boots` L_b, `charm` L_c | Trinket rank = **max(L_b, L_c)**. **Refund** the Crowns spent on the lower piece: Σ COSTS[0 … min−1] (e.g. boots L6 + charm L4 → rank 6, refund 150). Toast: "Your gear was reforged: +150 Crowns". |
| owned `helm` | owns Round Shield + Tankard |
| owned `blade` | owns Arming Sword + Hand Axe + Crossbow |
| owned `boots` | owns Compass + Lantern |
| owned `charm` | owns Coin Purse + Trader's Map + Healer's Flask |
| chosen traits (L4/L8) | auto-equip the item that carries the chosen trait, preferring the Trinket choice by old level order. For example, Sure Foot → Lantern in the trinket slot; Bulwark → Round Shield; Cleave → Hand Axe; Opener → Spear (granted free if Opener was chosen). |
| classes owned | grant their signature kits |

Net effect:
- A migrated max profile keeps: the board reroll (with the Compass equipped), +4 HP, +1 ATK and
  the gold % (with the Coin Purse equipped).
- It loses stacking them all at once, because the trinket slot now forces a choice (board
  reroll *or* gold *or* hazard).
- That is intended, and it gives back about 3–6 pp of vertical power (see §8).
- Tests:
  - v1 and v2 fixtures → v3 round-trip.
  - A refund-sum test.
  - The idempotent migration (running `from_dict` twice changes nothing).

---

## 7. Visuals (presentation)

### 7.1 Attach rules

- **`game/actors/item_mounts.gd`** (new) holds a table `item_id → {scene, slot: "handslot.r" |
  "handslot.l" | "back" | "belt" | "hip", pos, rot, scale}`.
  - FantasyWeaponsBits items need a per-item transform: they are authored at a different scale
    and grip than the Adventurers weapons.
  - "back", "belt" and "hip" are new BoneAttachment offsets on `chest`/`hips`.
- **`Character.create(model, skin, loadout := {})`:** equipped items **replace**
  `MODELS[model][3]` (the default gear). An empty weapon slot falls back to the class default
  model, so a hero is never unarmed except the Monster Kid.
- **Attack style follows the weapon, not the class.**
  - `Character.ATTACKS` gains `"crossbow": "Ranged_1H_Shoot"`, `"spear": "Melee_2H_Attack_Stab"`
    and `"scythe": "Melee_2H_Attack_Spin"`.
  - `ItemDefs.style` picks the set: 1H / 2H / dual (Dagger + Parrying Dagger or Shuriken) / bow /
    crossbow / magic / unarmed.
  - `combat_stage.gd` chooses melee, ranged or magic *staging* (walk-in vs stand-off, projectile
    VFX) from the same field instead of `hero.model_id`.
- **Idle holds:** 2H items use `Melee_2H_Idle` in combat; bows use `Ranged_Bow_Idle`; magic uses
  the default idle.
- Shown in: runs (board and combat), the Camp hero, class select, the Start Run panel, the
  Wardrobe (skins shows the equipped kit) and the results screen.

### 7.2 Armory screen (`ui/camp/armory_modal.gd`)

- **Tabs:** Weapon / Off-hand / Trinket, with a class switcher at the top (loadouts are per
  class).
- **Left: 3D hero preview** (SubViewport turntable) wearing the selection. Tapping "Preview
  attack" plays the style's clip.
- **Right: item grid.** Each card is a **rotating 3D thumbnail** (a shared SubViewport renderer
  with a cached texture per item), showing name, rule text with the current tier's numbers, a
  tier pip (I/II/III), an affinity star for the selected class, and a "2H" tag.
- **Locked cards** show a silhouette plus their source: the milestone text, or "150 Crowns / 4
  Sigils".
- **Bottom:** the slot rank bar (R0–8), the next cost, and the base stat line ("Off-hand R5: +2
  max HP").
- Vector icons stay only as HUD glyphs for trinkets in the run.

### 7.3 Camp racks (`game/camp/camp_stations.gd`)

- The weapon rack along the back shows **owned weapons** (up to 12 pegs, in content order;
  locked slots empty).
- The shield wall shows owned hand off-hands.
- The table shows trinkets, the spellbook, quiver, smoke bomb and shuriken.
- The equipped kit for the selected class glows softly.
- This replaces "the rack fills by gear level" (tiers 1..3).

---

## 8. Balance

| check | target | command |
|---|---|---|
| Armory maxed (R8 ×3, best kit per class) vs an empty armory | **≤ +15 pp** realistic at max | `--strip=armory` |
| Any single item at III vs an empty slot | ≤ +6 pp | `--armory=weapon:<id>` (new flag, all else fixed) |
| Horizontal spread within a slot (the best vs worst item at III) | ≤ 4 pp | per-slot sweep |
| Affinity (the signature item at II on a mid profile vs the best non-signature item) | +1 to +3 pp, never more than 4 | mid profile |
| The Compass alone (board reroll per biome) | about 6 pp, as the Boots R6 today. It is the strongest trinket by design, since the trinket slot now forces it vs gold vs hazard. | `--armory=trinket:compass` |
| Profile bands | unchanged: realistic fresh 30–40% (the fresh profile has R0, so it's unaffected), mid 45–50%, max 55–65%, max A10 20–30% | standard sweep |
| Per class | the ±5 pp rule still holds with each class's *default* kit **and** with the sim's best-kit picker | `--class=<id>` |
| Degenerate stacks to watch | Katana + Shuriken + Ninja (a reroll engine); Warhammer + Heavy + Barbarian (the pip multiplier: a hard rule is no Crush on a Heavy die); Wand + Spellbook + Echo on Mage; Claws + Loaded Die (Loaded Die rerolls 1s, which anti-synergises with Claws; fine) | `--items` table |

The migration removes today's "all four at once" stacking, so a max profile may lose about 3–6 pp.
If the max band drops under 55%, adjust these first, in order:
1. Off-hand HP 0.5 → 0.75 per rank (cap +6).
2. Tier III numbers +10%.
Don't re-add a 4th slot.

The **sim bot** needs:
- a loadout picker (per class: the highest `--armory` value from a precomputed table, or the
  default kit on "realistic" to model real players)
- awareness in its combat EV of the Flow (Katana), Steady (Parrying Dagger), Rampage target
  stickiness and the Wand/Spellbook turn timing.

---

## 9. Implementation order

| step | work | layer | size |
|---|---|---|---|
| 1 | `core/content/items.gd` (`ItemDefs`: ids, slot, hands, style, tiers, numbers, affinity, model id), `ItemLogic` hook module (reusing the `ClassLogic` hook points: fight start, turn start, attack, reroll, kill, lap, biome, shop, board, hazard), and porting every trait effect from `GearDefs.TRAIT_BONUS` into items | core | M |
| 2 | Profile v3 (`armory`), migration + tests, `Camp.rank_slot` / `equip_item` / `buy_item`, `MetaRun.build` items + tiers, `UnlockDefs` kind `items` and the milestone remap | core/meta | M |
| 3 | Sim: `--strip=armory`, `--armory=`, the bot loadout picker, and the §8 sweep, then update balance.md "Meta numbers" | sim | M |
| 4 | `item_mounts.gd` + Character loadout attach + style-by-weapon + new ATTACKS aliases; FWB model import (copy the needed gltf into `assets/kaykit/weapons/`) | presentation | M |
| 5 | Armory modal rebuild (3D turntables, grid, rank bar) | presentation/UI | M |
| 6 | Camp racks show owned items; class select, Start Run and Wardrobe show the equipped kit | presentation | S |
| 7 | Device-matrix screenshots of every item attached per class (grip and scale check) | verification | S |

Steps 1–3 must land together with a migration test. Steps 4–7 can start once `ItemDefs` exists.

---

## 10. Open questions for the user

1. **Three slots** (Weapon, Off-hand, Trinket), with Helm and Boots dropped because there are no
   armour meshes. OK, or should an "Armour" slot exist anyway as an **icon-only** stat piece (it
   would reuse no model)?
2. **Trinket consolidation:** today's four pieces stack the board reroll, gold, hazard and heal
   all at once. With one trinket slot you pick one, which costs about 3–6 pp at max. Accept the
   nerf (it adds build variety), or add a **second trinket slot** at a late Crowns price (e.g.
   400)?
3. **Necromancer weapon:** switch to the FantasyWeapons **Scythe** (a strong silhouette; a real
   weapon item) instead of the skull staff from the classes doc?
4. **Class affinity:** +1 tier for the signature items. Is that the right strength, or do you
   prefer none (pure freedom) or a cosmetic-only "signature glow"?
5. **Weapon variants** (FWB `sword_A`–`G`, `axe_A`–`D`, `hammer_A`–`D`, `staff_A`–`D`,
   `bow_A`–`C`, `shield_A`–`D`): should they be **cosmetic weapon skins** (unlocked like hero
   skins), or stay unused for now?
