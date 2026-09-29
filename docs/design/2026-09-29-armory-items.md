# Diceroll: the real-item Armory (weapons, armor, trinkets, variants)

Date: 2026-09-29 · Status: **decisions resolved (§11)**. Numbers are starting values for the
sim.
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

- **Stat slots:** **Weapon**, **Off-hand**, **Head**, **Body** (the torso + both arms as one
  set), **Trinket**, and a late **2nd Trinket**.
  - **Back** (capes, cloaks, backpacks, the pelt) is a **normal item slot whose items have no
    stats yet**. They carry `effect: {}` and `cosmetic: true`, and the UI shows a "Style" tag.
  - **Legs/Boots** is listed as a future option (§4.4).
- **Armor uses the real character parts.** The KayKit character GLBs are split into skinned
  parts on the shared Medium rig (`Knight_Helmet`, `Mage_Hat`, `Paladin_Helmet`, `Knight_Body` +
  arms, `Ninja_Chest`, capes, backpacks…).
  - An equipped piece hides the hero's own part and binds the donor's mesh to the hero's
    skeleton (§8.4).
  - Skins (alt textures) stay cosmetic and apply to the class's own parts.
- **Content:**
  - Weapons: 16 base items, 36 variants in total.
  - Off-hands: 8 base, 14 variants.
  - Head: 8 base, 12 variants.
  - Body: 10 pieces, plus the Monster Kid's Dino Suit.
  - Trinkets: 8.
  - Back: 12 items (no stats yet).
  - Every stat item has one dice-centric sidegrade. All 16 of today's gear traits live on as item
    effects.
- **Variants are not cosmetic.** Each concrete model variant (e.g. FantasyWeapons `sword_A`–`G`)
  keeps its base type's rule and tier scaling, and adds **one fixed secondary property** that
  fits its look.
  - The "Standard" variant has no secondary; instead its base numbers are ×1.2.
  - Variants are **earned deterministically**: a blueprint unlocks from **mastery** (fights won
    with that base item equipped: 15 / 45 / 90) or from a named **feat**. They are then **crafted
    for Crowns** (60 / 90 / 120) or 2 Sigils.
  - There are no drops and no randomness.
- **Progression:** there are **4 ranks** (R0–8, today's Crowns curve, 730 each, so 2,920 in
  total, exactly today's gear sink):
  - **Weapon**: R8 +1 ATK
  - **Off-hand**
  - **Armor** (shared by Head and Body): +0.5 max HP per rank, max +4
  - **Trinket**.
  - Rank sets the tier of the items in that group: **I at R1–3, II at R4–7, III at R8**.
  - Items are unlocked once and never levelled.
- **2nd Trinket slot:** the "Belt Pouch" costs **400 Crowns** and needs **Trinket rank ≥ 5**. Its
  item works **one tier lower** and never gets rank breakpoints (so no second Compass board
  reroll). The same item can't be equipped twice.
- **Class affinity:** every piece of a class's own kit (weapon, off-hand, head, body) works **+1
  tier** (max III).
- **Necromancer:** it keeps the **skull staff** look. That is the **Bone Staff variant of the
  Arcane Staff**, which is its signature weapon. The Scythe is a normal item with no affinity.
- **Budget:** the whole armory maxed (all slots incl. armor and the 2nd trinket) vs empty is
  ≤ **+15 pp** (realistic, max profile), with per-slot caps in §9. Variants within a base type
  are ≤ **3 pp** apart.
- **Migration** (profile v2 → v3): blade → Weapon rank, helm → Armor rank, boots → Off-hand
  rank, charm → Trinket rank. There are no refunds, since the four ranks replace four pieces
  one-for-one. Old pieces grant the items that carry their traits, and chosen traits auto-equip.

---

## 1. Slots

| slot | stat? | where it goes on the hero | rank / tier source | base stat | count |
|---|---|---|---|---|---|
| **Weapon** | yes | `handslot.r` (bows: `handslot.l`) | Weapon rank | +1 ATK at R8 (today's Blade cap) | 16 base items |
| **Off-hand** | yes | `handslot.l`, or a belt/back socket | Off-hand rank | – | 8 |
| **Head** | yes | replaces the hero's headwear part (hat, helmet, mask, crown) | **Armor rank** | +0.5 max HP per Armor rank, max +4 (today's Helm cap), counted once for Head + Body | 8 |
| **Body** | yes | replaces `<Class>_Body` + `_ArmLeft` + `_ArmRight` as one set | **Armor rank** | (shared with Head) | 10 (+ Dino Suit) |
| **Trinket** | yes | hip/belt socket (0.6×) + an icon in the run HUD | Trinket rank | – | 8 |
| **Trinket 2** (Belt Pouch) | yes | second hip socket | Trinket rank, **tier −1** (min I), **no rank breakpoints** | – | same 8 |
| **Back** | **no stats yet** (`effect: {}`, `cosmetic: true`; shown as "Style") | replaces the cape, cloak or backpack part | none (no rank) | – | 12 |

Rules:
- **Tier:**
  - A rank of R0 means the slot group isn't crafted, so its items have no effect (they are still
    shown).
  - R1–3 = tier I, R4–7 = II, R8 = III.
  - **Affinity** adds +1 tier (cap III).
  - Trinket 2 = tier −1 (min I).
- **Two-handed weapons** block *hand* off-hands (the 3 shields, Parrying Dagger). Belt and back
  off-hands (Spellbook, Quiver, Smoke Bomb, Shuriken) stay allowed.
- **Equipping** is free and saved **per class**. Every class starts with its own kit equipped
  (§6).
- **Appearance override (transmog):**
  - Head and Body can *display* any owned piece of that slot, their own class part, or (Head
    only) "hidden".
  - Stats always come from the equipped piece.
  - The default appearance is the class's own look, so a class looks unchanged until the player
    chooses otherwise. This also keeps skins that show a helmet valid (e.g. the Paladin helmet
    skins set the head appearance).
- **Monster Kid:** Head and Body are locked to the **Dino Suit** (a combined piece, §4.3). Back
  and hand items work as usual.

---

## 2. Weapons (16 base items; the variants are in §5)

"Style" is the attack animation set. Numbers are **I / II / III**. "After mult" means added
after the combo multiplier.

| id | name | Standard model | hands | style (clip) | base rule I / II / III | affinity |
|---|---|---|---|---|---|---|
| `sword` | Arming Sword | `sword_1handed` (Adventurers) | 1H | melee_1h (`Melee_1H_Attack_Slice_Diagonal`) | **Twin Edge:** Pair or Two Pair: **+2 / +3 / +5** after mult | Knight |
| `greatsword` | Greatsword | `sword_2handed_color` (Adventurers) | 2H | melee_2h (`Melee_2H_Attack_Slice`) | **Great Arc:** Three of a Kind or better: combo mult **+0.2 / +0.3 / +0.4** | – |
| `hand_axe` | Hand Axe | `axe_1handed` (Adventurers) | 1H | melee_1h (`Melee_1H_Attack_Chop`) | **Cleave:** a kill carries **25 / 35 / 45%** of the excess damage to the next enemy | – |
| `great_axe` | Great Axe | `axe_2handed` (Adventurers) | 2H | melee_2h (`Melee_2H_Attack_Chop`) | **Rampage:** each consecutive attack on the same target **+2 / +4 / +6** flat, stacking to 3; resets on a target change or kill | Barbarian |
| `warhammer` | Warhammer | `paladin_hammer` (Mystery S4) | 1H | melee_1h (`Melee_1H_Attack_Chop`) | **Crush:** the highest die in the scoring group counts its pips **×1.4 / ×1.6 / ×1.8** (never on a Heavy die) | Paladin |
| `spear` | Spear | FWB `spear_A` | 2H | melee_2h (`Melee_2H_Attack_Stab`) | **First Strike:** first attack each fight **×1.15 / ×1.25 / ×1.35**; +0.1 more against a final boss | – |
| `scythe` | Scythe | FWB `scythe` | 2H | melee_2h (`Melee_2H_Attack_Spin`) | **Reap:** each enemy killed heals **1 / 2 / 3** | – (the user kept the Necromancer's staff look) |
| `dagger` | Dagger | `dagger` (Adventurers) | 1H | **dual** with the Parrying Dagger or Shuriken, else melee_1h (`Melee_1H_Attack_Stab`) | **Quick Hands:** +1 combat reroll on turn 1 / turns 1–2 / turns 1–3 | Rogue |
| `katana` | Katana | `Ninja_Katana` (Mystery S4) | 1H | melee_1h (`Melee_1H_Attack_Slice_Horizontal`) | **Flow:** each die rerolled this turn: +1 pip at attack, max **2 / 3 / 3** dice | Ninja |
| `arcane_staff` | Arcane Staff | `staff` (Adventurers) | 2H | magic (`Ranged_Magic_Shoot`) | **Channel:** each runed die in the scoring group **+1 pip (max 2) / +1 (max 3) / +2 (max 2)** | **Mage, Necromancer** |
| `druid_staff` | Druid Staff | `druid_staff` (Adventurers) | 2H | magic (`Ranged_Magic_Spellcasting`) | **Grove:** at each biome change, raise the lowest face of **1 / 1 / 2** dice by +1 | Druid |
| `wand` | Wand | `wand` (Adventurers) | 1H | magic (`Ranged_Magic_Shoot`) | **Spark:** the first attack each fight with mult ≥ 2: **+0.4 / +0.6 / +0.8** mult | – |
| `hunting_bow` | Hunting Bow | `bow_withString` (Adventurers) | 2H | bow (`Ranged_Bow_Release`) | **Opening Volley:** at fight start, hit a random enemy for **3 / 5 / 7 × (1 + 0.15·(lap−1))** | Ranger |
| `crossbow` | Crossbow | `crossbow_1handed` (Adventurers) | 1H | **crossbow** (new alias → `Ranged_1H_Shoot`) | **Deadshot:** High Roller **+3 / +6 / +9** after mult | – |
| `claws` | Claws | FWB `fistweapon_C_right` (+`_left` when the off hand is free) | 1H | unarmed (`Melee_Unarmed_Attack_Punch_A`) | **Scrap:** each die showing 1 or 2: **+2 / +2 / +3** after mult | Monster Kid |
| `wrench` | Wrench | `engineer_Wrench` (Adventurers) | 1H | melee_1h (`Melee_1H_Attack_Chop`) | **Tinker:** Forge tiles +1 edit / and shop Face Raises cost 18 / Forge tiles +2 edits | Engineer |

Not used: FWB `halberd` is a Spear variant (§5); the Orc axe and club keep enemy identity.

---

## 3. Off-hands (8)

| id | name | Standard model | mount | base rule I / II / III | affinity |
|---|---|---|---|---|---|
| `round_shield` | Round Shield | `shield_round_color` (Knight default look: `shield_badge_color` as its appearance) | hand | **Bulwark:** Block **3 / 5 / 7** on turn 1; III also **Last Stand** (once per run, survive a lethal hit at 1 HP if above 50%) | Knight |
| `spiked_shield` | Spiked Shield | `shield_spikes_color` | hand | **Thorns:** an enemy whose attack hits you or your Block takes **2 / 2 / 3** | – |
| `oath_shield` | Oath Shield | `paladin_shield` | hand | **Aegis:** a Pair or better grants Block = the set's value **×1 / ×1.25 / ×1.5** | Paladin |
| `parrying_dagger` | Parrying Dagger | `dagger` (Adventurers, left hand) | hand | **Steady:** each kept (not rerolled) die +1 pip, max **1 / 2 / 2** dice | Rogue |
| `spellbook` | Spellbook | `spellbook_open` (1H) / `spellbook_closed` on the belt (2H) | belt | **Tome:** 3rd attack each fight: combo mult **+0.4 / +0.6 / +0.8** | Mage |
| `quiver` | Quiver (stays an off-hand) | `quiver` (Adventurers); on the Ranger it uses its own `Ranger_Quiver` mesh | back socket (no conflict with the cosmetic Back slot: the quiver sits on the hip or back strap) | **Spare Arrows:** every 3rd attack also shoots a random enemy for **4 / 6 / 9 × (1 + 0.15·(lap−1))** | Ranger |
| `smoke_bomb` | Smoke Bomb | `smokebomb` | belt | **Vanish:** the first enemy attack each fight deals **30 / 50 / 70%** less | – |
| `shuriken` | Shuriken | `Ninja_Shuriken` | belt | **Barrage:** each rerolled die deals **1 / 1 / 2** to a random enemy, max **3 / 3 / 4** per turn | Ninja |

---

## 4. Armor

Head and Body tiers come from the **Armor rank**. The numbers are deliberately small: there are
two armor slots now, and the Armor rank also carries the HP base stat.

### 4.1 Head (8 base items)

| id | name | part (donor GLB) | rule I / II / III | affinity |
|---|---|---|---|---|
| `knight_helm` | Knight Helm | `Knight_Helmet` + `Knight_HelmetVisor` (Knight.glb) | **Steadfast:** when you gain Block from a rune or item, +1 / +1 / +2 more (once per turn) | Knight |
| `paladin_helm` | Paladin Helm | `Paladin_Helmet` (Paladin_with_Helmet.glb) | **Vow:** Three of a Kind or better heals **2 / 3 / 4** | Paladin |
| `wizard_hat` | Wizard Hat | `Mage_Hat` (Mage.glb) | **Arcana:** the first rune trigger of turn 1 fires twice / turns 1–2 / turns 1–3. It never stacks with Resonance or Rune Echo: an already-doubled trigger isn't doubled again. | Mage |
| `bear_hat` | Bear Hat | `Barbarian_BearHat` (Barbarian.glb) | **Ferocity:** below 50% HP: **+2 / +3 / +4** flat damage | Barbarian |
| `goggles` | Engineer Goggles | `Engineer_Goggles` (Engineer.glb) | **Appraise:** shop dice and Face Raises **−10 / −15 / −20%** | Engineer |
| `ninja_headband` | Ninja Headband | `Ninja_Headband` (Ninja.glb) | **Focus:** a reroll of exactly one die is free: 1 / 2 per fight / 1 per turn | Ninja |
| `bandit_mask` | Bandit Mask | `RogueHooded_Mask` (Rogue_Hooded.glb) | **Ambush:** after a board move on doubles, the next fight's first attack **×1.15 / ×1.2 / ×1.25** | Rogue |
| `bone_crown` | Bone Crown | `Necromancer_Crown` (Skeletons Necromancer.glb) | **Dominion:** each kill: +1 pip on your next attack's lowest die, stacking to **2 / 3 / 4** | Necromancer |

Classes with no native headwear (Ranger, Druid, and the Paladin's default no-helmet look) start
with the head slot **empty**. Their affinity budget sits in their weapon and body instead.
Checked by the ±5 pp per-class rule.

### 4.2 Body: torso + both arms (10 pieces)

| id | name | parts | rule I / II / III | affinity |
|---|---|---|---|---|
| `knight_plate` | Knight Plate | `Knight_Body` + `Knight_ArmLeft/Right` | **Plated:** Block **1 / 2 / 3** at the start of every combat turn | Knight |
| `paladin_cuirass` | Paladin Cuirass | `Paladin_Body` + arms | **Blessed:** a Pair or better heals **1 / 1 / 2** (once per turn) | Paladin |
| `barbarian_harness` | Barbarian Harness | `Barbarian_Body` + arms | **Brawn:** Heavy dice **+1 / +1 / +2** pips, added after doubling, max 2 dice | Barbarian |
| `mage_robe` | Mage Robe | `Mage_Body` + arms | **Rune-woven:** Ember and Thunder deal **+1 / +2 / +3**; Venom poison **+1 / +1 / +2** | Mage |
| `rogue_leathers` | Rogue Leathers | `Rogue_Body` + arms | **Nimble:** keep ≥ 2 dice all turn → bank +1 reroll (max banked **1 / 1 / 2**) | Rogue |
| `ranger_tunic` | Ranger Tunic | `Ranger_Body` + arms | **Hunter:** **+2 / +3 / +4** damage against enemies at full HP | Ranger |
| `ninja_gi` | Ninja Gi | `Ninja_Chest` + arms | **Poise:** a reroll that creates a match heals 1, max **1 / 2 / 3** per turn | Ninja |
| `druid_robe` | Druid Robe | `Druid_Body` + arms | **Bark:** lap completion heals **+1 / +2 / +3** HP | Druid |
| `engineer_overalls` | Engineer Overalls | `Engineer_Body` + arms | **Patchwork:** after each fight won, heal **1 / 2 / 3** | Engineer |
| `hooded_robe` | Hooded Robe | `RogueHooded_Body` + arms | **Shroud:** Poison you apply **+1 / +1 / +2** | Necromancer |

Excluded as bodies:
- Skeleton torsos: bones read as undead enemies on a hero.
- `OrcRaider_Body`: enemy identity.
- Off-tone packs.

### 4.3 Monster Kid: Dino Suit

`MonsterCostume_Body` + arms + the costume head, locked in both Head and Body. It uses the Armor
rank.

**Thick Hide:** Block **1 / 2 / 2** each turn, and BOO!'s boss weaken is **−35 / −40 / −40%**
instead of −30%. That is equivalent to about one head + one body piece. Checked by the ±5 pp
per-class rule.

### 4.4 Legs / Boots (future option, not in this pass)

`<Class>_LegLeft/Right` could be a **Boots** slot, e.g. Knight greaves or Ninja tabi with board
and hazard rules. It stays out for now:
- the legs are small at board-tile scale, so the swap doesn't read
- a 6th stat slot would crowd the Armory and the budget.

Revisit it if the hero camera gets closer (the Camp, class select).

### 4.5 Back (a real item slot, no stats yet)

Back pieces are **obtainable items** like every other slot:
- owned in `armory.owned`
- shown in the Armory with 3D previews
- equipped per class.

They grant **no stats for now**. Each `ItemDefs` entry has `slot: "back"`, `effect: {}` and
`cosmetic: true`. The UI shows **"Style"** where other items show their rule and tier. There is
no Back rank. When stats are added later, it only takes filling `effect` (and optionally a rank
group). No schema change is needed.

| id | name | part | how to get it |
|---|---|---|---|
| `knight_cape` | Knight Cape | `Knight_Cape` | Knight kit (fresh profile) |
| `mage_cape`, `ranger_cape`, `rogue_cape`, `hooded_cape`, `paladin_cape` | class capes | `<Class>_Cape` | the class kit (on class unlock), or **60 Crowns / 2 Sigils** before owning the class |
| `druid_backpack`, `engineer_backpack` | backpacks | `<Class>_Backpack` | the class kit, or 60 Crowns / 2 Sigils |
| `bone_cloak`, `tattered_cloak`, `grave_cape` | skeleton cloaks | `Skeleton_Warrior_Cloak`, `Skeleton_Minion_Cloak`, `Skeleton_Rogue_Cape` | milestone **"Bone Collector"**: defeat 300 skeletons (new counter `skeleton_kills`) grants all three |
| `orc_warpack` | Orc Warpack | `Orc_Warpack` | feat: defeat the Orc Warchief once |
| `bear_pelt` | Bear Pelt | `Barbarian_Large_BearPelt` (Large rig; **fit test** on Medium, otherwise it is offered only on the Barbarian's Chieftain skin) | feat: win with the Barbarian at A6+ |
| (empty) | No back | – | always available |

Back pieces have no variants for now. The `variants` map works for them if models are added
later.

---

## 5. Variants: real properties, not cosmetics

### 5.1 Rules

1. Every base item has a **Standard** variant, its default model: `Standard` = **no secondary
   property**, but its base rule's numbers are **×1.2** (rounded).
   - For count-based rules (Dagger rerolls, Katana dice, Druid Staff dice, Focus counts) the
     Standard variant instead gives **Block 2 on turn 1**.
2. Every other variant keeps the base rule **at its normal numbers and tier scaling** and **adds
   one secondary property** with **fixed numbers**. The secondary doesn't scale with tier, so
   rank investment isn't multiplied by variants and they stay horizontal.
3. Some secondaries are **trade-offs** (a minus plus a plus), marked ⚖.
4. **Budget:** within a base type, best vs worst variant ≤ **3 pp** (`--variant=` sweep). A
   variant beyond that gets its secondary cut, never its base.
5. A variant changes the **model**, and the model defines the attack style only through the
   base type (all sword variants use the sword's style, except where noted).

### 5.2 Weapon variants (36 including the Standards)

| base | variant id | model | secondary property | unlock |
|---|---|---|---|---|
| **Arming Sword** | `sword` (Standard) | `sword_1handed` | ×1.2 base | with the item |
| | `sword_training` | FWB `sword_A` (wooden) | **Lesson:** while you have ≤ 3 dice, +1 combat reroll on turn 1 | mastery 15 |
| | `sword_knight` | FWB `sword_B` (plain steel) | **Guarded:** scoring a Pair also grants 2 Block | mastery 45 |
| | `sword_saber` | FWB `sword_C` (curved) | **Slash:** Pairs also hit a second enemy for 25% of the attack | mastery 90 |
| | `sword_rapier` | FWB `sword_D` (basket hilt) | **Precision:** High Roller also counts for Twin Edge at half value | feat: score 200 High Rollers |
| | `sword_flame` | FWB `sword_F` (flame blade) | **Burning:** each 6 in a scoring Pair deals 3 to all enemies | feat: defeat the Cinder King with a Sword equipped |
| | `sword_frost` | FWB `sword_G` (ice cleaver) | **Chill:** a Pair of 1s or 2s Freezes the target (skips its next action), once per fight | feat: defeat the Frost Warden with a Sword |
| **Greatsword** | `greatsword` (Standard) | `sword_2handed_color` | ×1.2 base | with the item |
| | `greatsword_plain` | `sword_2handed` | **Steel:** +3 max HP ⚖ −0.05 of Great Arc | mastery 15 |
| | `greatsword_zwei` | FWB `sword_E` (long blade) | **Reach:** Three of a Kind+ also splashes 25% to the other enemies | mastery 45 |
| **Hand Axe** | `hand_axe` (Standard) | `axe_1handed` | ×1.2 base | with the item |
| | `axe_twinbit` | FWB `axe_A` (small double-bit) | **Double Chop:** Two Pair +3 after mult | mastery 15 |
| | `axe_cleaver` | FWB `axe_C` (cleaver) | ⚖ **Butcher:** −1 combat reroll each turn, **+4** flat damage | mastery 45 |
| | `axe_bone` | Skeletons `Skeleton_Axe` | **Grisly:** Cleave's carried damage also applies 2 Poison | feat: defeat 300 skeletons |
| **Great Axe** | `great_axe` (Standard) | `axe_2handed` | ×1.2 base | with the item |
| | `axe_war` | FWB `axe_B` (large double-bit) | **Frenzy:** Rampage stacks to 4 | mastery 15 |
| | `axe_jagged` | FWB `axe_D` (jagged) | **Bleed:** each Rampage stack also applies 1 Poison | mastery 45 |
| | `axe_golem` | Skeletons `Skeleton_Golem_Axe` | ⚖ **Crushing:** Rampage resets only on a kill (not on a target change); −3 max HP | feat: defeat the Bone Golem 10 times |
| **Warhammer** | `warhammer` (Standard) | `paladin_hammer` | ×1.2 base | with the item |
| | `hammer_smith` | FWB `hammer_A` | **Tempered:** a Crush die showing 6 counts +1 pip more | mastery 15 |
| | `hammer_morningstar` | FWB `hammer_B` (spiked ball) | **Spikes:** Crush also deals 3 to a random other enemy | mastery 45 |
| | `hammer_club` | FWB `hammer_C` (spiked club) | **Rend:** Crush applies 2 Poison | mastery 90 |
| | `hammer_mallet` | FWB `hammer_D` (great mallet; 2H style) | ⚖ **Heavy Swing:** 2H; Crush **+0.3** more | feat: win a run with a Warhammer at A3+ |
| | `hammer_bone` | Skeletons `Skeleton_Mace` | **Bonebreak:** Crush vs an armored enemy ignores 50% of its Block | feat: defeat the Bone Champion 3 times |
| **Spear** | `spear` (Standard) | FWB `spear_A` | ×1.2 base | with the item |
| | `spear_halberd` | FWB `halberd` | **Sweep:** the First Strike attack splashes 25% to all enemies | mastery 15 |
| | `spear_trident` | FWB `spear_B` (golden trident) | **Gilded:** +3 gold per kill | feat: win a run with a Spear |
| **Scythe** | `scythe` (Standard) | FWB `scythe` | ×1.2 base | with the item |
| | `scythe_bone` | Skeletons `Skeleton_Scythe` | **Harvest:** kills also +1 pet charge | mastery 15 |
| **Dagger** | `dagger` (Standard) | `dagger` (Adventurers) | Block 2 on turn 1 | with the item |
| | `dagger_leaf` | FWB `dagger_A` | **Light:** kept dice +1 pip on turn 1 (max 2) | mastery 15 |
| | `dagger_venom` | FWB `dagger_C` (green blade) | **Venom:** attacks with a Pair apply 2 Poison | mastery 45 |
| | `dagger_bone` | Skeletons `Skeleton_Dagger` | **Shiv:** +2 damage against poisoned enemies | feat: kill 100 enemies with Poison |
| **Katana** | `katana` (Standard only) | `Ninja_Katana` | Block 2 on turn 1 | – |
| **Arcane Staff** | `arcane_staff` (Standard) | `staff` (Adventurers) | ×1.2 base | with the item |
| | `staff_quarter` | FWB `staff_A` (plain) | **Unbound:** Channel also gives +1 pip to one *un-runed* die in the group | mastery 15 |
| | `staff_frost` | FWB `staff_B` (blue crystal) | **Rime:** a runed die showing 1 Freezes the target, once per fight | mastery 45 |
| | `staff_sun` | FWB `staff_D` (golden sun) | **Radiant:** each runed die in the group heals 1 (max 2 per turn) | feat: defeat the Lich with an Arcane Staff |
| | `staff_bone` | Skeletons `Skeleton_Staff` (**the Necromancer's default: the skull staff**) | **Soul:** each kill adds +2 to your next attack (max +6) | owned with the Necromancer class; otherwise mastery 90 |
| **Druid Staff** | `druid_staff` (Standard) | `druid_staff` | Block 2 on turn 1 | with the item |
| | `staff_living` | FWB `staff_C` (twisted, green gem) | **Bloom:** each Grove raise also heals 3 | mastery 15 |
| **Wand** | `wand` (Standard) | `wand` (Adventurers) | ×1.2 base | with the item |
| | `wand_sapphire` | FWB `wand_A` | **Focus:** the Spark turn also gives +1 reroll | mastery 15 |
| | `wand_orb` | FWB `wand_B` (magenta orb) | **Hex:** the Spark attack also applies 3 Poison | mastery 45 |
| **Hunting Bow** | `hunting_bow` (Standard) | `bow_withString` | ×1.2 base | with the item |
| | `bow_short` | FWB `bow_A_withString` | **Quick Draw:** the Volley also fires on turn 2 at half damage | mastery 15 |
| | `bow_composite` | FWB `bow_B_withString` | **Piercing:** Volley and Spare Arrows ignore Block | mastery 45 |
| | `bow_long` | FWB `bow_C_withString` (great longbow) | **Marksman:** the Volley targets the highest-HP enemy and deals +25% | feat: win at A3+ with a Hunting Bow |
| **Crossbow** | `crossbow` (Standard) | `crossbow_1handed` | ×1.2 base | with the item |
| | `crossbow_arbalest` | `crossbow_2handed` | ⚖ 2H; Deadshot **+50%** | mastery 15 |
| | `crossbow_bone` | Skeletons `Skeleton_Crossbow` | **Reload:** a Deadshot kill gives +1 reroll next turn | mastery 45 |
| **Claws** | `claws` (Standard) | FWB `fistweapon_C` | ×1.2 base | with the item |
| | `claws_knuckles` | FWB `fistweapon_A` | **Brawl:** 1s count as 2 for damage | mastery 15 |
| | `claws_gauntlet` | FWB `fistweapon_B` | **Guard:** each die showing 1 or 2 also gives 1 Block | mastery 45 |
| **Wrench** | `wrench` (Standard only) | `engineer_Wrench` | Block 2 on turn 1 | – |

### 5.3 Off-hand and head variants (the body pieces have no variants: one mesh each)

| base | variant id | model | secondary | unlock |
|---|---|---|---|---|
| Round Shield | `round_shield` (Standard) | `shield_round_color` / `shield_badge_color` (appearance) | ×1.2 base | with the item |
| | `shield_plank` | FWB `shield_A` (wooden) | ⚖ **Light:** +1 combat reroll on turn 1, Bulwark −2 | mastery 15 |
| | `shield_heraldic` | FWB `shield_B` (blue/white heater) | **Rally:** Bulwark Block left after turn 1 carries into turn 2 | mastery 45 |
| | `shield_tower` | FWB `shield_C` (iron-banded) | ⚖ **Wall:** Bulwark also on turn 2 at half; −1 reroll on turn 1 | mastery 90 |
| | `shield_bone` | Skeletons `Skeleton_Shield_Small_A` | **Rattle:** Bulwark Block that is broken by an attack deals 2 back | feat: defeat 300 skeletons |
| Spiked Shield | `spiked_shield` (Standard) | `shield_spikes_color` | ×1.2 base | with the item |
| | `shield_dragon` | FWB `shield_D` (red, curved) | **Scorch:** Thorns also apply 1 Poison | feat: defeat the Magma Golem with a Spiked Shield |
| | `shield_bone_large` | Skeletons `Skeleton_Shield_Large_A` | ⚖ **Bulk:** +4 max HP; Thorns −1 | mastery 15 |
| Parrying Dagger | `parrying_dagger` (Standard) | `dagger` | Block 2 on turn 1 | with the item |
| | `parry_sai` | FWB `dagger_B` (sai) | **Catch:** a fully blocked enemy attack gives +1 reroll next turn | mastery 15 |
| Quiver | `quiver` (Standard) | `quiver` / `Ranger_Quiver` | ×1.2 base | with the item |
| | `quiver_bone` | Skeletons `Skeleton_Quiver` | **Barbed:** Spare Arrows apply 2 Poison | mastery 15 |
| Spellbook, Smoke Bomb, Shuriken, Oath Shield | Standard only | – | – | – |
| Knight Helm | `knight_helm` (Standard) | `Knight_Helmet` + visor | ×1.2 base | with the item |
| | `helm_bone` | `Skeleton_Warrior_Helmet` | **Horned:** Thorns 1 while you have Block | feat: defeat 300 skeletons |
| Wizard Hat | `wizard_hat` (Standard) | `Mage_Hat` | ×1.2 base | with the item |
| | `hat_grave` | `Skeleton_Mage_Hat` | **Grave Magic:** the doubled Arcana trigger also heals 1 | mastery 15 |
| Bandit Mask | `bandit_mask` (Standard) | `RogueHooded_Mask` | ×1.2 base | with the item |
| | `hood_grave` | `Skeleton_Rogue_Hood` | **Ambush Poison:** the Ambush attack applies 2 Poison | mastery 15 |
| Ninja Headband | `ninja_headband` (Standard) | `Ninja_Headband` | Block 2 on turn 1 | with the item |
| | `ninja_mask` | `Ninja_Mask` (+ headband) | **Silent:** a Focus reroll also gives that die +1 pip | mastery 15 |

Other heads (Paladin Helm, Bear Hat, Goggles, Bone Crown) are Standard only.

### 5.4 Acquisition: why mastery and feats, crafted for Crowns

- **Mastery** (fights won with the base item equipped, any variant; tracked per base item like
  pet XP) makes the item you *use* grow sideways. It is deterministic and visible ("12/15 fights
  to the Training Sword blueprint"), and it never needs randomness.
- **Feats** give the flashy models (Flame Sword, Sun Staff, Golden Trident, Longbow, Dragon
  Shield, the bone set) a named, memorable condition, like skins.
- **Crafting** (60 / 90 / 120 Crowns by blueprint order, or 2 Sigils; feat variants 120) is a
  Crowns sink after the ranks cap. Blueprints never expire.
- **Rejected: in-run drops (chests, bosses) that persist to the profile.** Random permanent
  power is lootbox-like. Chest and boss drops stay in-run only (runes, passives).
- **New profile counters:** `high_rollers`, `skeleton_kills`, `boss_kills` (per id, from the
  classes doc), `poison_kills` (existing), and per-item `mastery`. A feat condition "with item X
  equipped" reads the run stats' `loadout` + `bosses_killed`.

---

## 6. Class signature kits (the default loadout; +1 tier affinity)

| class | weapon (variant) | off-hand | head | body | back (Style item) |
|---|---|---|---|---|---|
| Knight | Arming Sword | Round Shield (badge look) | Knight Helm | Knight Plate | Knight Cape |
| Barbarian | Great Axe | – (2H) | Bear Hat | Barbarian Harness | – |
| Mage | Arcane Staff | Spellbook (belt) | Wizard Hat | Mage Robe | Mage Cape |
| Rogue | Dagger | Parrying Dagger | Bandit Mask (appearance: own head) | Rogue Leathers | Rogue Cape |
| Paladin | Warhammer | Oath Shield | Paladin Helm (appearance: hidden, so the default look stays helmet-less) | Paladin Cuirass | Paladin Cape |
| Ranger | Hunting Bow | Quiver (`Ranger_Quiver`) | – | Ranger Tunic | Ranger Cape |
| Ninja | Katana | Shuriken | Ninja Headband | Ninja Gi | – |
| Druid | Druid Staff | – | – | Druid Robe | Druid Backpack |
| Engineer | Wrench | – | Engineer Goggles | Engineer Overalls | Engineer Backpack |
| Necromancer | **Arcane Staff: Bone Staff variant (skull staff)** | – | Bone Crown | Hooded Robe | Hooded Cape |
| Monster Kid | Claws | – | Dino Suit (locked) | Dino Suit (locked) | – |

- The kit is **owned when the class unlocks**, including the signature variant (Bone Staff for
  the Necromancer).
- Affinity applies to these pieces for that class only. The Arcane Staff counts for both the
  Mage and the Necromancer.
- Every class also starts with the Tankard trinket if owned.

---

## 7. Acquisition and progression

### 7.1 Ranks and costs

| rank | covers | cost | base stat |
|---|---|---|---|
| Weapon R0–8 | weapon | 15, 25, 40, 70, 100, 130, 160, 190 (730) | +1 ATK at R8 |
| Off-hand R0–8 | off-hand | 730 | – |
| Armor R0–8 | head + body | 730 | +0.5 max HP per rank (max +4) |
| Trinket R0–8 | trinket (+ Trinket 2 at −1 tier) | 730 | – |
| Belt Pouch | the 2nd trinket slot | **400**, requires Trinket R5 | – |

The ranks total **2,920**, today's gear sink. Items, variants, the Belt Pouch and back pieces
add roughly **+2,500–3,500**, which keeps the "maxed around run 45" pacing. Re-check it with the
campaign sim.

### 7.2 Item unlocks

| source | items |
|---|---|
| Fresh profile | the Knight kit (Arming Sword, Round Shield, Knight Helm, Knight Plate, Knight Cape) + Tankard |
| Class unlock | that class's kit (§6) |
| `wanderer` (run ~2; was Blade) | Hand Axe, Coin Purse |
| `gate_crasher` (run ~4; was Boots) | Compass, Lantern |
| `boss_seen` (run ~6; was Charm) | Crossbow, Healer's Flask |
| Crowns (Armory shop) | Greatsword 120 · Spear 120 · Scythe 120 · Wand 100 · Spiked Shield 100 · Smoke Bomb 100 · Trader's Map 100 · Skeleton Key 140 · Loaded Die 160 · **another class's kit piece before owning that class: 150 each** |
| Sigils | any purchasable item: 4 |

### 7.3 Trinkets (8; unchanged rules, tier from Trinket rank)

| id | name | model | rule I / II / III |
|---|---|---|---|
| `tankard` | Tankard | `mug_full` | Lap heal +0.5 / +1 / +1.5%; III also campfires +10% |
| `compass` | Compass | `compass_base` (RPGTools) | Portal +2 / and value ties move the higher value / **R6+ in slot 1 only: +1 board reroll per biome** |
| `lantern` | Lantern | `lantern` (RPGTools) | Traps, ice, lava and heat −20 / −35 / −50%; III also dodge on 3+ |
| `coin_purse` | Coin Purse | `Gems_Sack` (ResourceBits) | Gold +4 / +8 / +12%; II also Treasury passes bank +5; III also cash-outs ×1.25 |
| `traders_map` | Trader's Map | `map_rolled` (RPGTools) | Restock 7 / and 1 free restock per shop / and shops +1 item |
| `healers_flask` | Healer's Flask | `potion_medium_red` | Every shop offers a potion / and potions heal +5% / +10% |
| `skeleton_key` | Skeleton Key | `key_gold` (Dungeon EXTRA) | Chest runes: 1 of 4 / and chest gold ×1.25 / and the first chest per biome is a rune chest |
| `loaded_die` | Loaded Die | `D6_A_red` (BoardGameBits) | At the first combat roll of each fight, 1 / 2 / all dice showing 0 or 1 reroll free |

**2nd trinket (Belt Pouch):**
- Tier = the Trinket-rank tier −1 (min I).
- The Compass's R6 board reroll only counts in **slot 1**.
- A max profile can therefore have, for example, a Compass at III (board reroll) plus a Coin
  Purse at II (+8% gold, Treasury +5). That is **two of today's four stacked benefits, one of
  them weakened**, which is the intended middle ground between today's "all four" and "only one".

### 7.4 Profile schema (v2 → **v3**; v2 is the skins schema)

```text
armory: {
  ranks:    {weapon: 0..8, offhand: 0..8, armor: 0..8, trinket: 0..8},
  pouch:    0|1,                                   # 2nd trinket slot
  owned:    [item ids],                            # weapons, off-hands, heads, bodies, trinkets, back
  variants: {item_id: [variant ids]},              # "standard" is implicit for owned items
  blueprints: {item_id: [variant ids]},            # unlocked, not yet crafted
  mastery:  {item_id: fights_won},
  equipped: {class_id: {weapon: {id, variant}, offhand: {id, variant}, head: {id, variant},
                        body: id, trinket: id, trinket2: id, back: id | ""}},   # back = a normal owned item
  appearance: {class_id: {head: id | "own" | "hidden", body: id | "own"}},
  seen_new: [ids]
}
records.counters += high_rollers, skeleton_kills
# removed: gear, gear_traits (read-only in from_dict for migration)
```

`MetaRun.build(profile, class)` resolves everything to `items: {slot: {id, variant, tier}}` +
`hp`, `atk`, `lap_rerolls`, so replays are exact without the profile. The run's end stats gain
`loadout` (for feats) and `item_fights` (for mastery).

### 7.5 Migration (v1/v2 gear → v3), one-time and fair

| old | new |
|---|---|
| `blade` level L | Weapon rank L |
| `helm` level L | **Armor rank** L (the HP base stat moved with it) |
| `boots` level L | Off-hand rank L |
| `charm` level L | Trinket rank L |
| owned `helm` | Round Shield + Tankard |
| owned `blade` | Arming Sword + Hand Axe + Crossbow |
| owned `boots` | Compass + Lantern |
| owned `charm` | Coin Purse + Trader's Map + Healer's Flask |
| chosen traits (L4/L8) | auto-equip the carrying item. Trinket traits go in slot 1 by the old level order, and the Belt Pouch is granted **free** if the old boots and charm were both ≥ L5 (so no player loses an existing double benefit on migration day). Opener → Spear, granted free. |
| owned classes | their kits (§6), with Standard variants |
| mastery | 0 (it starts accumulating) |

Notes:
- There are no Crowns refunds: 4 old pieces map one-for-one to 4 ranks.
- Tests: v1 and v2 fixtures → v3, an idempotent `from_dict`, and the pouch grant rule.

---

## 8. Visuals (presentation)

### 8.1 Weapons and off-hands

- **`game/actors/item_mounts.gd`:** `model_id → {scene, socket: "handslot.r" | "handslot.l" |
  "back" | "belt" | "hip", pos, rot, scale}`.
  - FWB models need per-item transforms (a different scale and grip from the Adventurers
    weapons).
  - Every variant has its own row.
- **`Character.create(model, skin, loadout := {})`:** equipped items replace `MODELS[model][3]`,
  the class default gear.
- **Attack style follows the weapon.**
  - `Character.ATTACKS` gains `crossbow` → `Ranged_1H_Shoot`, `spear` → `Melee_2H_Attack_Stab`
    and `scythe` → `Melee_2H_Attack_Spin`. These clip names are checked in the Rig_Medium
    CombatMelee file.
  - `combat_stage.gd` stages melee, ranged or magic from `ItemDefs.style`, not `hero.model_id`.
  - 2H weapons idle with `Melee_2H_Idle` in combat and bows with `Ranged_Bow_Idle`.

### 8.2 Armor

- **Default look:** the class's own parts.
- **An equipped Head/Body piece with its appearance set to that piece:**
  - hides the class's matching part(s): the headwear part, or for Body the `<Class>_Body` +
    `_ArmLeft` + `_ArmRight`
  - adds the donor's skinned meshes bound to the hero skeleton.
- **Heads with built-in hair or hoods:** a head fit table `(hero head mesh, head item) → ok |
  scale 1.03–1.06 | swap_head` handles clipping:
  - `swap_head` replaces the hero's `<Class>_Head` with the donor's head as a group. Example: the
    Knight Helm on the Druid, whose head has an antler hood, swaps to the Knight head under the
    helm.
  - Combinations marked `bad` fall back to **appearance hidden** automatically (the stat still
    applies), with an "i" note in the Armory.
  - The table is filled from a device-matrix screenshot pass over 11 heroes × 12 head
    appearances.
- **Skins (alt textures) apply to the class's own parts only.**
  - Donor pieces keep their own atlas, because the UV layouts differ per character, so a
    palette can't be shared in general.
  - Exception: donors from the same texture family share the skin (Rogue ↔ Rogue_Hooded use the
    rogue atlases; Paladin ↔ Paladin_with_Helmet).
  - An optional later feature: "tint donor pieces to the skin's accent", a hue-shift uniform on
    donor materials.
- **Silhouette readability:**
  - The weapon + body carry the class read at tile scale.
  - Big hats (Wizard Hat, Bear Hat) change the silhouette but stay heroic.
  - Heroes keep their rim/outline and HP bar, and enemies keep their glowing eyes + tint (≥ 0.6),
    so a hero in a Bone Helm never reads as a skeleton.
  - The Armory preview shows the tile-scale silhouette thumbnail next to the big turntable.
- **Back items:** the same hide + bind method for `<Class>_Cape`/`_Backpack`. The Bear Pelt
  needs a Large-on-Medium fit test.

### 8.3 Armory and Camp UI

- **Armory tabs:**
  - Weapon · Off-hand · Head · Body · **Back** (Style items) · Trinkets (2 slots) · Appearance
    (head/body overrides).
  - A class switcher sits at the top.
  - The left side holds the **3D hero turntable** wearing the selection, with a "Preview attack"
    button.
- **Item cards:**
  - Each card shows a rotating 3D thumbnail (a shared SubViewport renderer, cached per model),
    the rule with the current tier numbers, a tier pip, an affinity star and a 2H tag.
  - Under each card is a **variant picker**: chips with mini 3D thumbnails.
  - Locked chips show the blueprint condition and mastery progress ("31/45 fights"), or the
    craft cost when unlocked.
- **Rank bars:** Weapon / Off-hand / Armor / Trinket ranks with the next cost and base stat, plus
  the Belt Pouch purchase row.
- **Camp racks:**
  - The weapon rack shows owned weapons and variants (12 pegs; a scrolling "armory wall" if more
    are owned).
  - The shield wall shows shields.
  - A mannequin row shows owned bodies + heads (the `Mannequin_Medium` wearing the parts via the
    same binder).
  - A table holds trinkets, books and quivers.
  - The selected class's equipped kit glows.

### 8.4 Technical note: extracting a part in Godot

- All Medium-rig character GLBs share the same 23 bone names and order (the `Rig_Medium`
  skeleton).
- **Donor instance:** `var donor := (load(glb) as PackedScene).instantiate()`. Find
  `MeshInstance3D` nodes by name (e.g. `Knight_Helmet`, `Knight_HelmetVisor`, or `Paladin_Body`
  + `Paladin_ArmLeft/Right`).
- **Re-bind:**
  - `donor_mi.get_parent().remove_child(donor_mi)`, then `hero_skeleton.add_child(donor_mi)`, and
    set `donor_mi.skeleton = NodePath("..")`.
  - Keep `donor_mi.skin` (the donor's `Skin` resource). Its bind poses reference bones **by
    name**, which are identical, so it binds correctly to the hero skeleton.
  - If a Skin binds by index, rebuild it: `skin.set_bind_name(i, name)` for each bind (a
    one-time, cached conversion).
  - Free the rest of the donor.
- **Hide the hero parts:** `hero.get_node("…/Knight_Head").visible = false`, etc. Keep a
  per-model part map (head / headwear / body / arms / back) in `Character.PART_MAP`.
- **Materials:** the donor keeps its own atlas material. Skins swap textures only on the
  class-owned parts.
- **Cache:** one bound hero per (class, skin, loadout, appearance) in the Camp. In runs the
  loadout is fixed, so build it once.
- **Large rig** (the Bear Pelt, Barbarian_Large parts): different proportions. It goes behind a
  fit test and isn't offered on Medium heroes if it fails.

---

## 9. Balance

**Per-slot caps** (realistic, max profile; item at III vs an empty slot, with the other slots at
their defaults):

| slot | cap | note |
|---|---|---|
| Weapon | ≤ 4 pp | the numbers were cut about 20% from the first draft |
| Off-hand | ≤ 3 pp | |
| Head | ≤ 2 pp | |
| Body | ≤ 2 pp | |
| Trinket 1 | ≤ 3 pp, **Compass ≤ 6 pp** | the board reroll, as today's Boots R6 |
| Trinket 2 | ≤ 2 pp | tier −1, no breakpoint |
| Base stats (+1 ATK, +4 HP) | ≈ 2–3 pp | unchanged from today |
| **Whole armory maxed vs empty** | **≤ +15 pp** (`--strip=armory`) | slots don't add linearly; measure it |

| check | target | command |
|---|---|---|
| Horizontal spread within a slot (items at III) | ≤ 4 pp | `--armory=<slot>:<id>` sweep |
| Variants within a base type | ≤ 3 pp | `--variant=<item>:<variant>` sweep |
| Affinity (a signature piece at II vs the best non-signature piece, mid profile) | +1 to +3 pp, never more than 4 | mid profile |
| Profile bands | unchanged: realistic fresh 30–40%, mid 45–50%, max 55–65%, max A10 20–30% | standard sweep |
| Per class (the default kit, and the best kit picked by the sim) | ±5 pp of the class average (watch Ranger/Druid/Paladin with an empty default head; the Monster Kid with the Dino Suit) | `--class=<id>` |
| Degenerate stacks | the Katana + Shuriken + Ninja Headband/Gi reroll engine; Warhammer + Barbarian Harness + Heavy (Crush never on Heavy; Brawn adds after doubling); Wizard Hat + Resonance (no re-doubling); Wand + Spellbook + Mage Robe | the `--items` table |

- If the max band drops under 55%, adjust in this order:
  1. Armor HP 0.5 → 0.75 per rank (cap +6).
  2. Tier III numbers +10%.
- If it exceeds 65%, cut the Trinket 2 slot to tier −2 first.
- The bot needs:
  - a loadout picker (the default kit on "realistic"; the best by table on "expert")
  - awareness of Flow, Steady, Focus, Rampage stickiness and the Spark/Tome turn timing.

---

## 10. Implementation order

| step | work | layer | size |
|---|---|---|---|
| 1 | `core/content/items.gd` (`ItemDefs`: slots, hands, style, tiers, numbers, affinity, variants with secondaries, blueprint conditions); an `ItemLogic` hook module reusing the `ClassLogic` hook points; port every `GearDefs.TRAIT_BONUS` effect | core | L |
| 2 | Profile v3 (`armory`), migration + tests; `Camp.rank(group)`, `equip`, `buy_item`, `craft_variant`, `set_appearance`, `buy_pouch`; mastery and feat evaluation in `apply_run_result`; `MetaRun.build` items + tiers; `UnlockDefs` kind `items`; the milestone remap | core/meta | M |
| 3 | Sim: `--strip=armory`, `--armory=`, `--variant=`, the bot loadout picker; the §9 sweep; update balance.md "Meta numbers" | sim | M |
| 4 | `item_mounts.gd` (weapons, off-hands, trinkets, all variants) + style-by-weapon + ATTACKS aliases; import the FWB/Skeletons/Mystery weapon models | presentation | M |
| 5 | **Armor binder**: `Character.PART_MAP`, donor-mesh re-binding (§8.4), appearance override, head fit table + the screenshot pass (11 heroes × 12 heads), back pieces, the Bear Pelt fit test | presentation | L |
| 6 | Armory modal (tabs, turntables, variant picker, rank bars, Appearance tab) | presentation/UI | L |
| 7 | Camp racks, shield wall, mannequin row; class select, Start Run and Wardrobe show the kit | presentation | M |
| 8 | Device-matrix screenshots of grip, scale and clipping for every item/variant per class | verification | M |

Steps 1–3 must land together with the migration tests. Steps 4–8 can start once `ItemDefs`
exists, and step 5 is independent of step 4.

---

## 11. Decisions (resolved, user via the tech lead, 2026-09-29)

1. **Slots:**
   - **Weapon, Off-hand, Trinket** as designed.
   - Plus **Head** and **Body** armor, from the real skinned character parts.
   - **Body = torso + both arms** as one set.
   - **Back = a normal item slot with obtainable items** (capes, cloaks, backpacks, the pelt),
     earned like other items. It has **no stats for now** (`effect: {}`, `cosmetic: true`, shown
     as "Style"), so stats can be added later with no schema change.
   - **Boots/Legs** is a future option only (§4.4).
   - The **Quiver stays the Ranger's off-hand**.
2. **Second trinket slot:** the Belt Pouch (400 Crowns, requires Trinket rank ≥ 5). It works one
   tier lower, gets no rank breakpoints (so no second Compass reroll), and can't hold a duplicate
   item. Migrated profiles with both old boots and charm ≥ L5 get it free.
3. **Class affinity:** +1 tier on the class's own kit (weapon, off-hand, head, body), max III.
4. **Necromancer:** it keeps the **skull staff** look (the Skeletons `Skeleton_Staff`, the Bone
   Staff variant of the Arcane Staff, with Mage/Necromancer affinity). The **Scythe is a normal
   item with no affinity**. The class isn't re-themed.
5. **Weapon variants have real properties:** each variant model adds one fixed secondary
   property on top of its base type's rule and tier scaling (the Standard variant gets ×1.2 base
   numbers instead).
   - They are earned by **mastery or feats** and **crafted for Crowns or Sigils**. There are no
     random drops.
   - They stay horizontal (≤ 3 pp within a type).
6. **Budget:** the whole armory (all stat slots, both trinkets, base stats) maxed ≤ **+15 pp**,
   with the per-slot caps in §9. The profile bands are unchanged.
