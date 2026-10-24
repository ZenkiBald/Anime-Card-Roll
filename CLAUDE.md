# Anime Card Roll (Roblox)

Roblox RNG card game: roll anime-style cards, build a 4 Attack + 4 Support deck, beat world bosses for bonus rolls.
Full design (rarities, cards, battle, bosses, rewards, production plan):
https://claude.ai/code/artifact/7c2c0257-e3da-4a93-adae-2ccb87e751bb

## Status

Milestones 1-4 of the design doc are built, plus a first polish pass: rolling (Roll / Quick Roll / Auto Roll),
the rarity reveal ladder, 18 starter cards, duplicates -> stars -> fusion copies, pity, saving, collection, odds panel,
test tools; the deck builder (4 + 4 slots, 3 presets, Auto-build); the server-run battle engine; all 3 worlds
(Kurogane, Rimeveil, Null Emperor Vex; World 4 Tenrai added later) on Normal / Hard / Nightmare with unlocks; boss reward rolls with luck,
floors and first-clear bonuses; 3D boss NPCs in the hub and in battle (built from parts in `BossModels`);
long-term progression (`Meta`):
potions, Shard Shop upgrades, the Index with completion rewards (replaces the old Collection / ODDS button;
the odds panel opens from the Index and the HUD stats), daily streak, playtime gifts, roll milestones;
SKIP on long reveals and the boss reward fan.
Design changes from the doc: Support cards have no HP (they can't be hit or KO'd and cast their Basic as the
fight opens; Support Deck Power is PWR x 24). Boss wins also pay 15 x D Shards and may drop a potion.
2026-10-22 pass (verified in Studio play mode with screenshots): UI kit skins load and fit (button art scales
to the button's height; top currency bar with big numbers; HUD hides during full reveals); a big world built
in Studio (terrain + Creator Store models + AI meshes, StreamingEnabled): spawn town in the middle, Ember
Village west, Frostfang Peaks north, Neon Abyss east, each with portal + boss; real sound (`UI/Sfx.luau`:
licensed Pro Sound Effects / APM stings, rarity stings, zone + battle music via `ZoneFx`).
Battle result panel and Gifts use the kit look (`Kit.tile` tiles, big numbers, kit icons); TRAVEL panel
(server-owned fast travel to Town / each boss zone); SETTINGS gear top right (Music / Effects volume saved in the
profile, effects quality HIGH/LOW; replaces the old FX menu button).
Fusion (user's design, 2026-10-22): duplicates past 5 stars no longer pay Shards; they pile up as copies.
`Config.FusionCopies` (100) copies of one card fuse it one rarity up at Hoshi the Fusion Master (town NPC at the
map's `Fusion` marker, panel `UI/Fusion`), again and again up to Secret; the copies become one card, stars stay.
A fused card gets its new rarity's power (`Cards.Stat`: stats x new tier multiplier / old), so "rarity always
wins" still holds. Saves keep it as `Cards[id].Fusion`. Frostfang Peaks' lighting mood has exposure -0.6 so snow
and Rimeveil don't blow out.
Daily quests (top of GIFTS): 3 a day from `Meta.Quests`, picked by `Meta.QuestsFor(day, userId)` (same on both
sides, not saved); the server counts progress with `MetaService.Track(player, stat)` from rolls, boss wins,
fusions, gifts and potions. Rebirth was removed (2026-10-23, user's call: a card game doesn't need it; long-term
luck comes from artifacts and accessories). Stat points: every level past 1 gives a point for Luck, Roll Speed,
Border Chance, Shard Gain or XP Gain (`Meta.Stats`, capped per stat; STATS menu button, `UI/Stats`; reset for
Shards). BAG menu button (`UI/Bag`) replaces POTIONS (now one item grid, see BAG below; the old tabs were
placeholders until they drop). The Lucky Wheel is an NPC, Madame Fortuna, at the map's `Wheel` marker (falls
back near the spawn) with a turning wheel booth; no HUD wheel button.
Card borders (`Borders.luau`, 2026-10-23): every pull also rolls a border on its own, Normal / Gold (1 in 25) /
Rainbow (1 in 250) / Secret (1 in 2,500), raised by the Border Chance stat; a card keeps every border it found
(`Cards[id].Borders`) and wears the best, for a tiny bonus (+1 / +2 / +4%, so a 5-star Secret-border card still
stays under the next rarity; odds_test checks). `UI/BorderFx` draws the frames; the reveal teases the border on the
card back, then slams a "NEW RAINBOW!" ribbon on and calls "RAINBOW LEGENDARY!"; Rainbow / Secret always get the
full reveal, stop Auto Roll when new, and are announced to the server. The odds panel lists border odds, the Index
detail shows found borders. Test tools: border reveal previews and GIVE BORDERS.
Artifacts (`Items.luau`, 2026-10-23): every boss win / tower floor rolls for an artifact (3% + 0.7% x D, max 15%,
x4 on Guardians), rarer ones on harder fights (Mythic only from D 7). 10 artifacts (Rare-Mythic): wear 3, each adds
Luck / RollSpeed / Border / ShardGain / XPGain (`Meta.Bonus` = stat points + worn artifacts); duplicates level
them to 5, then melt into Shards. Saved as `Gear` { Artifacts, Worn }; MetaService WearArtifact / RemoveArtifact.
Test tools: GIVE ARTIFACTS.
Infinite Tower (`Tower.luau`, 2026-10-23, built in a cloud session: headless tests only, not yet seen in Studio):
endless floors, progress saved as `Tower.Floor` (highest cleared; you always fight Floor + 1, each floor pays once).
Each floor's enemy is an "Echo" of a world boss (its moves, model tinted, backdrop) picked by a seeded hash of the
floor (same everywhere, previewable); Vex from floor 24, Tenrai from 30. Recommended power 9k x 1.068^(floor-1)
(floor 48 ~ Tenrai Nightmare, no top); HP / ATK from `Tower.Curve.Points` (simulator-fitted anchors, log-joined).
Boss move set by floor (Hard from 15, Nightmare from 30); affixes from floor 5 (Swift / Armored / Brutal /
Colossal, fair trades). Every 10th floor a Guardian (1.15x power): full boss reward rolls, bonus card, sure potion,
4x gear odds. Rewards use D = floor x 0.25 (`Rewards.For`, `Items.RollDrops(d, rng, boost)`). Server:
`BattleStart("tower")` (BattleService picks the floor; `Engine.new` takes `Stats` to override HP / ATK),
`RollService.TowerRewards`. Client: TOWER tab on the BATTLE screen (`BossScreen.OpenTower`), NEXT FLOOR / TRY AGAIN
on the result panel, a tower gate in town at the map's `Tower` marker (falls back to the spawn's right), a HIGHEST
FLOOR board beside it, Floor in the player list, a daily quest (TowerFloors), dev +10 FLOORS / TOWER TO FLOOR 1.
Opens after `Tower.UnlockAfter` (Kurogane Normal) when unlock rules are on. `tests/tower_test.luau` checks it.
Auto-climb: after a tower win the next floor starts after a 4 s countdown (AUTO CLIMB toggle on the result panel).
Roll Packs (2026-10-23, user's call; replaced the short-lived rarity-ticket roll bank, old tickets convert to
Roll Packs on load): `Packs.luau` (Roll Pack 10 / Big 100 / Mega 1000 rolls, no rarity of their own). Boss wins
drop `Packs.ForBoss(d, firstClear)` Roll Packs; tower floors drop on every 5th (Guardians 2, floor 25s a Big, 100s a
Mega, `Packs.ForFloor`); daily days 3 / 7 and roll milestones 500 / 2500 / 25000 grant packs too (`Bundle.Packs`).
Saved as `Packs[id] = count`; `OpenPack` remote opens one at the player's luck at that moment (batched rolls:
one AddXP, only the best pull announced; returns the rarest `Packs.ShowCards` for the flip reveal + counts per
rarity). BAG > PACKS (`UI/BagPacks`, `UI/PackOpen`), OPEN on the battle result panel. The BAG badge counts them. Fusion panel: `busy` now always clears (pcall + panel close), the
old lock-after-one-fusion bug.
4v4 squads (2026-10-23, user's pick; built in the cloud, headless tests only, not yet seen in Studio): every
fight is the leader (the boss, or the tower's echo; engine id "Boss") + 3 guards (G1-G3) from
`Bosses.GuardTypes` (12, three themed per boss in `boss.Guards`; HP / ATK are shares of the leader's).
Roles: Striker (hits hard), Hexer (burn / freeze / slow), Mender (heals 1.2% of the leader's HP every other
action, Rally +15% ATK every 5th; moves with Target "Ally"), Warder (Taunt + Protect: the leader takes 30% less
while it stands; listed last so it stands in front). Win = the leader falls. Cards hit the focus target
(BattleInput "Target", `Engine:SetFocus`; tap an enemy, tap again to clear), else a taunting guard, else the
enemy with the least HP. Card effects can target "Enemies" (Hayate's Cyclone, Amaya's Stormcall, Orin / Amane
debuffs) or "RandomEnemy" (Kaede, Noa's Comet Rain, Kaito's Ultimate). Tower floors draw 3 guards
(`Tower.GuardsAt`, seeded, at most one Warder / Mender). Boss HP / ATK and `Tower.Curve.Points` were retuned for
squads (about 75 s, about 1 card KO'd). Client: guard tiles left / right / in front of the leader, gold TARGET
marker, guard callouts and KO ("DOWN!"), GUARDS DOWN on the result panel, guard line on the BATTLE screen.
Favourite card + server list (2026-10-23): Index detail "SET AS FAVOURITE" (MetaService "SetFavorite",
`Settings.Favorite`); LeaderboardService sets player attributes Fav / FavFusion / FavBorder (favourite, else rarest),
Power (active Deck Power), Rolls, Level every 2 s; `UI/PlayerList` (top right, left of the gear, "›" folds it) lists
everyone strongest first with their favourite card as picture; Roblox's player list is off. Name tags show the
favourite. New card look (`CardView`, user's reference): full-art, chips (rarity, border, stars, fused), big name,
headline ability bar (Ultimate > Skill > Basic), tag chips (type + passives), DMG / HP (PWR / SPD) footer.
HUD: running potions are tiles bottom right (above the jump button on touch), legendary pity counter over ROLL,
Auto Roll feed lower right. Test tools: GIVE PACKS.
BAG (2026-10-23, user's reference): one grid of small square tiles (rarity badge, xN, coloured edge, timer / level /
WORN tag) with tabs ALL / PACKS / POTIONS / ARTIFACTS / ACCESSORIES, search, and a detail panel on the right
(OPEN / USE / BUY / WEAR / REMOVE, accessory card picker) in `UI/Bag` (BagGear / BagPacks are gone).
Profiles: tap anyone in the server list for PROFILE (`UI/Profile`, `ProfileService` + `Profile` remote, players in
this server only): favourite card big, level, Deck Power, rolls, tower floor, bosses, Index, playtime, strongest
cards and their deck; CHANGE FAVOURITE on your own.
2026-10-23 cleanup (user's calls): card accessories removed (saves refund 150 Shards each; `Gear` is just
Artifacts + Worn); pity removed (rolls are pure luck; `Config.Pity`, the HUD counter and odds bars are gone);
3D chibi card figures removed (`CardArt` and every card's `Look` deleted): a card shows `Image` (2D, filling the
card) or its glyph until the user's AI illustrations arrive; roll reveals no longer say FUSE / copies ("DUPE").
Traits (`Traits.luau`): since Phase 2 NOT rolled on pulls; bought at the Trait Master for Trait Shards (see Phase 2
below; Rare 75% / Epic 20% / Legendary 4.5% / Mythic 0.5%, shown in the ODDS panel; `Cards[id].Trait` / `Trait2`);
battle-only effects (SPD / Crit / CritDamage / Guard / StartEnergy, never ATK / HP)
applied in BattleEngine like the old accessories (UnitSpec.Trait). Trait chip on cards. Test tools: GIVE TRAITS.
CODES (menu button, `UI/Codes`): `src/server/Codes.luau` (server-only list; once per player, optional Expires),
`CodeService` + `Redeem` remote, saved in `Codes`. Add a code = one entry in Codes.luau.
Strategy layer (2026-10-23, from the user's design bible v2, mixed with Claude's ideas; the bible's DBZ / Naruto
roster, worlds and anime roadmap were NOT used: original characters only; its VIP luck pass was not built either,
see the paid random items rule): built in the cloud, headless tests only, not yet seen in Studio.
Elements (`Elements.luau`): every card / boss / guard has one (`Element` field): Flame > Frost > Storm > Flame,
Light <> Void, Cosmic (Secret cards only) beats all and is weak to none. Strong x1.3, weak x0.85, both ways (enemies
hit cards by the same rule); picked so rarity still wins (1.6 x 0.85 > 1.3, strategy_test checks). Menders are
Light (Void cards cut them down). Synergies: 2 / 4 cards of an element in the whole deck switch on a deck bonus
(Wildfire ATK, Permafrost Guard, Tempest SPD + energy, Radiance crit, Abyss Vuln), run as battle effects at the
start. Bonds: 8 named pairs (`Elements.Bonds`) fire a Dual Ultimate (300% of both cards' power at the leader) once,
when the leader hits 50% or at 45 s. Engine: `Element` on units and enemies, `El` flag (1 / -1) on Hit events,
"Bond" events, Info.Synergies / Info.Bonds. Boss HP and `Tower.Curve.Points` HP were retuned up (~1.05-1.3x, tower
1.2x) since fixture decks now use the layer; a deck that ignores elements is slower.
Scouting: the BATTLE screen's SCOUT box (leader + guard elements, what beats them, how your deck lines up, your
synergies / bonds), COUNTER-BUILD (`Deck.AutoBuild(owned, against)`, `Bosses.SquadElements`; DeckService
"AutoBuild" takes a boss id / Tower.Id / Raid.Id as its 3rd arg), HOW ELEMENTS WORK (`UI/ElementGuide`).
Element badges on CardView / CardTile / battle tiles (`UI/ElementUi`), element tag chip, Index detail lists the
element and bonds; deck screen has a synergy strip and an Element filter; battle numbers get ▲ / ▼.
Tower daily mutators (`Tower.Mutators`, `Tower.MutatorAt(day)`, same on every server): one element +25% damage, or
every card half Ultimate / +12% SPD; applied as extra trait effects in BattleService; only ever help (tests run
without). Dev: NEXT MUTATOR (ReplicatedStorage attribute DevMutator).
Server raids (`Raid.luau`, `RaidService`, remotes RaidState / RaidInfo): every hour at :30 for 10 min (clock, same
on every server). A Colossus (a world boss alone, Hard moves) sized to each player's Deck Power (tower curve HP x4,
can't fall solo; barriers sized off the base HP); 60 s runs (`BattleStart("raid")`, Engine `TimeLimit`, Guards {})
drain one shared pool live (each player's first run adds 3x their base HP; per-Colossus Pool factor). Cleared:
every hitter paid (`Raid.Reward`: Shards by damage, capped, + Roll Pack, top hitter + Big Roll Pack, 2x artifact
odds) and RAID LUCK x2 for the whole server for 10 min (attribute RaidLuckEnds, in MetaService.Luck and
State.Luck); failed: half Shards. Client: RAID tab on the BATTLE screen (live pool / timer / top hitters), raid pill
under the event pill (tap to join), raid result panel, payout toast. Daily quest "raid". Dev: START RAID.
Phase 2 (2026-10-23, user's spec; built in the cloud, headless tests only, not yet seen in Studio). The spec's
DBZ x Naruto roster / boss mapping (#6) was NOT done: original characters only (copyright, DMCA takedowns).
- Trait loop: pulls roll no trait. `TraitShards` currency (top bar, BAG): bosses 1-5 by D x2 first clear
  (`Rewards.TraitShards`), every tower floor (Guardians 10 + floor/5), raids (`Raid.Reward`), quests, playtime
  gifts, the wheel, codes, x2 on a Cost Challenge. Kenshin the Trait Master (NPC beside Hoshi, map marker
  `TraitMaster` else 12 studs right of `Fusion`; `BossModels.traitmaster`; panel `UI/TraitMaster`, Index shortcut):
  `TraitService` + `TraitMaster` remote: Roll (10) / LockRoll (25: keep one slot, roll the other twice, pick) /
  Choose (0 keep, 1-2 apply); the roll waits as `Cards[id].Pending` until chosen; slot 2 at Awakening node 4.
- Rolling: `RollBoost.luau` + server `Momentum.luau`: Momentum chain (+1% speed / +0.01x luck per 10 rolls, max
  500; breaks after 30 s idle, paused in fights; HUD meter over ROLL). Every 25th lifetime roll is an Overcharge
  Surge (`RollService` rollClick; cycle = `TotalRolls % 25`, no pity): standard = 10x border odds (Gold ~15%,
  Rainbow ~1%, Secret 1 in 10,000 at 1x luck), 1.5x foils; a click inside the 1.5 s window after the cooldown (or
  the Auto Roll pass) = PERFECT: 3 cards at 12x border / 2x foil odds (`result.Extra`). The summary sends
  `SurgeProgress` (0-24), `IsSurgeRoll` and `UntilSurge`; the ODDS panel has an OVERCHARGE SURGE table.
  Tiered luck (`Odds`: weight = base x luck ^ `Rarity.LuckExponent`, renormalised), cap 25x (Commons ~28% there).
  Foils (`Foils.luau`, every pull, kept like borders in `Cards[id].Foils`, best worn, battle-only): Aura 10% (+8%
  Skill DMG), Golden Ki 1.9% (+15 energy), Demon Seal 0.1% (+35% ATK, 5% HP per action, never below 1 HP).
  Awakening (`Awaken.luau`, `Cards[id].Awaken` = highest node): 20 / 40 / 60 / 80 copies = +10% stats
  (`Cards.Stat` 6th arg) / +15% Skill DMG / bond 400% / trait slot 2; fusing (100) = node 5: +25 Trait Shards and
  +0.05x base luck per fusion (MetaService.BaseLuck counts fusions). Rarity still wins on stats (odds_test).
- Pack Alchemy (`Packs.Condense`, `PackAlchemy` remote, BAG): 10 x 10 -> 1 x 100, 10 x 100 -> 1 x 1000; INFUSE a Mega
  Pack (2,500 Shards) into "1000:<Element>": that element x1.5 inside each rarity, 2x borders under LUCKY STORM /
  Raid Luck / a Totem.
- Combat: Stagger bar on leaders and raid Colossi (`Config.Battle.Stagger*`: 1.2% a hit, counter element x2.5,
  Cosmic x1.5, weak x0.5; full = 5 s Staggered: no actions, warned move cancelled, DEF 0, Ultimates +50%; staggered
  at half HP loses its first phase-2 move). Slot Links: each Support card's `Link` (Cards.luau) buffs Attack slot
  N from Support slot N. Deck Cost (`Cards.Cost` by base rarity 1/1/2/3/4/6/8, `Deck.Cost`): COST CHALLENGE toggle
  on boss fights (BattleStart 3rd arg `{ Cost = true }`, cap 30, x2 Trait Shards). Unit effects (both trait slots,
  foil, Awakening, mutator) go in `UnitSpec.Trait` (stats incl. SkillDMG, ATK, HPCost). Bosses / tower retuned.
- Monetization (`MonetizationConfig.luau`: ids 0 = placeholders, `MockPurchases`; `MonetizationService`, remotes
  Store / StoreState, `UI/Store`, STORE menu button): Fast Roll (-30% cooldown), Auto Roll+ (opens Auto Roll;
  perfect surges), Triple Roll (3 cards a click, packs open 3x faster), VIP (+25% Shards / XP, +2 presets
  `DeckService.PresetCount`, golden name tag via player attribute VIP, +25% Trait Shards, x2 luck), Server Luck
  Totem dev product (ProcessReceipt, once per PurchaseId in `Purchases`; x2 server luck 10 min via attribute
  TotemLuckEnds + a totem model by the spawn; buyer gets 2 Big Roll Packs + 50 Trait Shards). Random perks (luck,
  Trait Shard bonus, Triple Roll, perfect surges, the Totem) only where `ArePaidRandomItemsRestricted` is false
  (unknown = restricted); the STORE greys them out and links to ODDS. Mock buys (Studio / TestMode, id 0) save in
  `MockPasses`. Dev: +200 TRAIT SHARDS, +20 COPIES ALL, GIVE FOILS.
Playtest pass (2026-10-23, user's plan; built in the cloud, headless tests + luau-lsp only, not yet seen in Studio):
- Homage retheme, display strings only (ids unchanged): boss titles Nine-Tailed Calamity / Galactic Tyrant / Six
  Paths Sovereign / Multiverse Titan; Rook "Wolf Fist Brawler", Kaito "Ascended Golden Warrior" (not "Saiyan", a
  trademarked term), Akane "Lightning Copy Blade", Raijen "Autonomous God State", Aurelia "Nine-Tails Sovereign";
  bonds Martial Oath, Shadow and Mist, Thunder Rhythm, Rival Tempest, Pride & Lightning, Celestial Gambit, Sky
  Sovereigns, Cosmic Supremacy. Names stay original.
- Surge window: the client sends `Roll(mode, early)`; a tap made while the cooldown ran is Early and never PERFECT
  (`RollBoost.IsPerfect`), it gets the plain surge. Perfect = a clean tap after the gold ring lights.
- Raid dropout: a leaver's unearned share (`Raid.PoolAfterLeave`) leaves the pool (it can clear the raid);
  hitters keep their damage, and if the raid clears while they're gone their payout goes by ProfileStore message
  (`DataService.SendMessage` / `SetMessageHandler`, `RollService.RaidRewardsOffline`) into their save on next join,
  with a "While you were away" toast.
- Kenji's path (`Tutorial.luau`, `TutorialService`, remotes Tutorial / TutorialState, `UI/Tutorial`): 6 quests in
  order, each CLAIMed: roll 5 / fill 4+4 / beat Kurogane Normal / a Trait Master roll / condense 10 Roll Packs
  (Kenji tops the player up to 10 when it opens, `Supply`) / a Stagger finished by a counter element (Engine
  `CounterStaggers`) -> title "Apprentice". Saved as `Tutorial` { Step, Flags, Supplied }; flags count whenever they
  happen (`TutorialService.Note` from TraitService, RollService Condense, BattleService). Tracker banner above the
  menu (tap = claim when ready, else KENJI'S PATH); talking to Kenji opens the path until it's done, then tips.
  Titles: `Titles` set + `Settings.Title` (worn: name tags, profiles).
- HUD: top bar = Shards, Trait Shards, Rolls (luck + ODDS under it). The left column (tracker + menu) scales with
  the screen (`layoutLeft`, ~0.6 on a phone); the Momentum line goes short on narrow docks. (The 4-category
  popover menu from this pass was replaced the same day, see below.)
Shonen overhaul (2026-10-23, user's spec; cloud-built, headless tests + luau-lsp only, not yet seen in Studio):
- HUD menu = six direct buttons, no flyouts: BATTLE (boss screen: bosses, tower, raid, Cost Challenge), BAG,
  SQUAD, QUESTS, TRAVEL, STORE (+ DEV in TestMode). Badges: QUESTS (gifts + Kenji), SQUAD (Index + stat points), BAG.
- Tabbed panels (`Modal.Tabbed` + `host:Page(tab, region?, heading?)`: a page acts like a Modal for the screen
  module, so DeckBuilder / Index / Stats / Shop / Gifts / Tutorial / Fusion take an optional `host` in Init):
  SQUAD = DECK | INDEX | UPGRADES (Stats left half + Shard Shop right half); QUESTS = KENJI'S PATH (✓ once done) |
  DAILY & GIFTS; Hoshi's panel = FUSION | PACK ALCHEMY (`UI/Alchemy`, moved out of the BAG).
- STORE: one full-screen scroll: GAME PASSES, SHARDS & SERVER TOTEM (`MonetizationConfig.ShardBundles`, dev
  products, ProductId 0 = mock; Shards buy luck potions / upgrades, so bundles follow the paid random items rule
  like the totem: "BuyShards", ProcessReceipt once per PurchaseId), REDEEM CODES at the bottom (`Codes.Build`).
- Town NPC exclusivity: fusion + pack alchemy only at Hoshi, traits only at Kenshin, the wheel only at Madame
  Fortuna (no HUD buttons, no Index shortcut). Server-enforced: `NpcRange` (World registers every NPC's spot;
  FusionService, RollService PackAlchemy, TraitService Roll / LockRoll, MetaService SpinWheel answer "TooFar"
  beyond 24 studs; an NPC never placed doesn't block). Kenji's hints point at the NPCs.
- Look: dark obsidian glass (`Theme`: Panel 11,14,22 at 0.15 transparency, frames 18,22,34 at 0.1, Line 45,55,80,
  Neon cyan for active / selected), 5 px corners (`Kit.corner`; full-round stays only on square things), 1.2 px
  strokes (`Kit.stroke`: <= 2 -> 1.2, heavier -> 2), Gotham fonts (Display GothamBlack, Heavy GothamBold, Bold
  GothamMedium, Medium Gotham; billboards too); buttons are dark metal with a neon trim + glow line; the cartoon
  UI kit art is off (`Skin.KitArt = false`; icons still apply); old purples were mapped to slate.
- Lighting (`LightingSetup.luau`, run first in Main.client; reuses existing effects): 18:45 twilight, Brightness
  1.8, ambient 20,25,40 / outdoor 45,50,75, soft shadows, grade (contrast 0.18, sat -0.05), bloom (0.65 / 24 / 1.8),
  atmosphere (0.32 density, haze 1.5). ZoneFx moods are dusk / night variants on top. `Technology = Future` can
  only be set in Studio: run `tools/studio/lighting.luau` once and save the place.
- Town VFX (World `townLights`): a warm PointLight (2 / 14 / 255,150,60, no shadows) in the 24 town lanterns
  nearest the fountain, rising embers at the fountain and every portal (`embers`).
Polish + deck rebuild (2026-10-23, user's spec; cloud-built, headless tests + luau-lsp only, not yet seen in Studio):
- Portal / gate / tower signs: World `styleSign` (GothamBold title, GothamMedium sub, a 1 px drop "Shadow" child
  label instead of outlines, MaxDistance 45, tag "FadeSign"; the place's own map signs are restyled at start);
  HubFx `fadeSigns` fades them in from 45 to 28 studs and keeps each shadow's text in step. NPC name signs keep
  their range. (DistanceLower/UpperLimit are set in a pcall: they aren't in the API defs.)
- HUD: the SETTINGS gear is drawn in the server list's header (`PlayerList.Init(..., openSettings)`); PETS became a
  44 px MOUNT·G tile beside the roll console (G is the ride key; R is Roll). Modal close = 32 px dark square, 4 px
  corners, grey ✕ that glows white / red on hover. `UI/Controls` is obsidian: dropdown tiles (Option opens a list,
  upward near the screen bottom), underline tabs, banners with a neon bar, square icons, toggle `Chip`s.
- DECK tab rebuilt (`UI/DeckBuilder`): left FORMATION: 4v4 SQUAD, four paired rows (Attack slot N | 🔗 Slot Link /
  pulsing BOND ACTIVE | Support slot N; plates show slot no., mini card, name, archetype, element, power), footer with
  Deck Power, the cost pill (✓ COST n/30 VALID / ⚠️ EXCEEDS LIMIT), active synergies (roman tier) + bonds, AUTO-BUILD /
  CLEAR / PRESET ▾ and ▲ ▼ ✕ for the picked slot. Right CARD VAULT: chips ★5 / GOLD / RAINBOW / SECRET (borders),
  Type / Sort / Element dropdowns, the grid (tap = inspect, tap again = equip), inspector (traits, slot 2 lock at 80
  dupes, Awakening pips, EQUIP TO SLOT, VISIT TRAIT MASTER = closes and draws `UI/Waypoint` to Kenshin; NpcRange
  publishes NpcSpot_<id> attributes for it).
- Pets / mounts: follower pets float over the right shoulder (bob sin(t x 4) x 0.4, bank into turns, lean with
  speed; `Followers`). Mount parts weld to one MountRoot joined by Motor6D "MountJoint" (MountService); clients
  sway it with the stride (pitch / roll / heave + turn bank) in PreSimulation.
Combat & VFX pass (2026-10-23, not yet seen in Studio): Ultimate cut-in is an obsidian slash with an element
neon edge (`NEON` in `UI/Battle`), italic metallic GothamBlack, punch + sparks; battle cards stay dark (the border
in the edge), neon emerald / red HP, cyan action bar, energy glows when full, status badges top right (`BADGES`);
metal FIGHT! drop-in; a STAGGERED banner under the leader's HP while Staggered (shows the real effect, DEF 0 /
Ultimates +50%). NPC / booth name plates and the town boards showed within 25 studs only (undone 2026-10-24, see below); the
Momentum line sits in an Urushi header over the roll console with a 2 px bar to 500 (the Surge meter sits in
the row under it, beside AUTO STOP); Travel cards get a biome glow
and a boss badge (highest cleared difficulty).
Arena pass (2026-10-23, not yet seen in Studio): fights are staged in 3D at the boss's own spot in its world
(`UI/Arena`; World publishes each spot as `ReplicatedStorage.Arenas[bossId]` attribute Stand, BattleService moves
the player's ReplicationFocus to the `Boss_` marker for the fight): the leader where its NPC stands (the NPC is
hidden locally), the 3 guards as smaller copies of the boss figure tinted by role (Highlight) left / right / front,
two braziers in the world colour, ZoneFx mood of that zone, a low Scriptable camera looking up with depth of field.
The boss holder (taps, rings, damage numbers) and guard tiles ride on world-space BillboardGuis; the leader also has
a name + HP plate. No map: the old ViewportFrame + 2D backdrop. The squad dock is the lower 22% (attack badges, each
Support's chip under its column). Card portraits: `CardView.Portrait` (element glow + the Image, else a rim-lit bust
silhouette, never letters) and `CardView.Bevel(target, border)` (metal edge in the border colour) everywhere cards show.
Border tiers (2026-10-23, user's spec; cloud-built, headless tests + luau-lsp only, not yet seen in Studio). This
overrides the rarity / fusion / border notes above wherever they disagree:
- No card rarities: the BORDER is the tier. `Borders.luau`: Base ("Normal" save key) 1x / Gold 4x / Rainbow 16x /
  Secret 64x stats, base odds 98.4 / 1.5 / 0.099 / 0.001% (luck ^ LuckExponent 0.6 / 0.8 / 1, Border Chance and
  surges boost them, the special borders capped at 50% together), Deck Cost 2 / 4 / 6 / 8. Every card sits on one
  line (ATK ~500 +-10%, HP = 2 x ATK; Support PWR ~300), so `Cards.Stat(card, base, stars, border?, awaken?)`.
  Which card a pull gives is its `Weight` (`Cards.Pool`, `Cards.PullChances`). Rarity badges are gone; cards show
  clean art framed by the border + an element glow. `Rarity.luau` stays only for artifact / trait tiers.
- Saves: `Cards[id].BorderCopies` (copies per border), `Borders` (found), `Fusion` = fusions done (node 5 luck).
  Old saves migrate on load (DataService): old copies -> Base, each found border -> 1 copy, an old rarity fusion
  -> Gold copies; invalid AutoStop -> default. Index rewards are keyed by border (old rarity claims don't pay).
- Border fusion only (user's call): 100 copies at one border -> 1 copy at the next (Hoshi, `Fuse(cardId, border)`).
- Secret pulls: "[SERVER] {Player} rolled a SECRET BORDER {Card}!" banner. Auto Roll stop: Gold / Rainbow / Secret.
- Boss cards: `kurogane_card` / `rimeveil_card` / `vex_card` / `tenrai_card` (`Boss` field) join that player's pool
  after the boss's first Normal clear ("KUROGANE UNLOCKED IN THE CARD VAULT!" on the result panel,
  `summary.CardUnlocked`).
- Avatar: EQUIP AS AVATAR in the DECK inspector (MetaService "SetAvatar", `Settings.Avatar`). The client predicts it
  (`Avatars.Predict`, drawn the same frame; `Avatars.Revert` on a refusal); `AvatarService.Apply` sets AvatarCard /
  AvatarElement / AvatarBorder on the character (for later joiners) and fires `AuraReplication` (character, cardId,
  border) to every client, on equip, respawn, fusion and a new border on the worn card (10 s safety pass, change
  only). Client `Avatars.luau` draws the element aura, fire footsteps (Rainbow) or celestial motes (Secret).
- `UI/CardTooltip`: DECK plates + CARD VAULT tiles zoom to 1.15 on hover, a 0.25 s hover (touch: tap / long press)
  opens a 280 px flyout: name, title, element, role (each card's `Role` in Cards.luau: Striker / Hexer / Mender /
  Warder),
  "Gold Border · 4x", Basic (target, formula), Skill (CD, stagger), Ultimate (energy), bonds.
- Bosses / tower rescaled to the new power line (Kurogane Normal 45k ... Tenrai Nightmare 774k; fixtures use borders).
Occult UI pass (2026-10-23, user's spec; cloud-built, headless tests + luau-lsp only, not yet seen in Studio). Overrides
the obsidian / Gotham look above where they disagree:
- Tokens: `src/configs/UITheme.luau` (ReplicatedStorage.Configs): Urushi black panels, Tamahagane steel edges, Washi
  parchment text, Vermilion seal CTAs, Spirit Cyan -> Surge Gold, border glows, role glyphs (`UITheme.Roles`),
  FredokaOne headers. `UI/Theme` reads Panel / PanelLight / Line / Text / Muted / Tile* and Font.Display from it, so every
  screen follows. Element colours stay single-sourced in `Elements.luau` (retinted to the palette; UITheme reads them).
- `UI/Components/JuicyButton`: sheen rim (stroke UIGradient Offset -1 -> 1, one looping tween; still on LOW effects),
  spring scale (hover 1.05 Quad 0.15 s, press 0.95 Quad 0.08 s, release Back 0.25 s; `ScaleTarget` puts the UIScale on
  a parent so it stacks with existing scale animations), Sfx SpiritHover / BladeClick, `JuicyButton.Content` moves a
  button's contents into a CanvasGroup with its corner. Never pair it with Kit.pressable on the same button.
  Used on the roll console (ROLL = Vermilion seal, 3 px steel border) and the battle unit pods (contents in a
  CanvasGroup; the HP track is a CanvasGroup so drains clip, KO fades GroupTransparency).
- `UI/Components/IconBadge`: diamond Urushi plate, 2 px steel bezel + inner glow rim, four 1 px notches, round glow
  backlight (`IconBadge.GlowImage` = "" fakes the radial; set an uploaded radial id to use a texture), upright icon
  (asset id or glyph). All layers are siblings in an unrotated square root, so nothing clips. `ElementUi.Badge` /
  `ElementUi.RoleBadge` build on it (card tiles, card views, battle pods, tooltip, DECK plates + inspector); the top
  bar's currency chips use it too.
- HUD: Surge meter under the Momentum line (CanvasGroup track, fill Spirit Cyan -> Surge Gold by `SurgeProgress`,
  full + gold edge when the next roll is the surge); currency chips are Urushi with a steel edge and a thin colour
  line; flat white / black blocks in Hud / Battle went to Urushi / Washi. CardTooltip: Urushi, 2 px steel, an
  element line on top, Washi title, element + role IconBadges.
Merge note (2026-10-24): the combat / arena / portrait passes were built on a PC from the polish + deck commit and
merged after the border tiers and occult UI; where they said rarity, the merge uses the border.
Playtest fixes (2026-10-24, from the user's Studio screenshots; headless tests + luau-lsp only):
- NPC / booth name plates are full size again and seen from 160 studs, town boards from 120, Kenji's tip bubble
  from 60 (the 25-stud range was unreadable; user's call). Portal / gate signs still fade in close.
- `✕` and `▾` showed as empty boxes in game: `Kit.glyph("Cross" | "Chevron")` draws them (Modal close,
  Controls dropdowns, the deck's remove icon). Don't put those characters in labels.
- Card portraits: the stand-in bust is lit in the element colour with a pale rim (it read as a black blob).
- Arena: guards at ±13 / front 12 studs, the front guard's tile hangs under its feet, the leader plate sits
  higher, guard tiles 150 x 84, braziers softer, and the place's bloom is turned down for the fight (restored
  in Arena.Stop). Battle dock: cast tags sit inside their own card's top edge; KO! / SAVED floats are smaller.
- HUD: the Momentum line no longer repeats the surge count (the Surge meter shows it); MOUNT tile 58 px; Index
  Base shows no "1 in"; `Kit.tile` drops its gloss line when a layout is added; name tags sit above the
  avatar's bounding box (hats included).
Playtest round 2 (2026-10-24, user's asks; headless tests + luau-lsp only):
- Fusion: the "FUSED!" stage was wiped when another card was picked before "Tap to continue", leaving `busy` set
  (FUSE dead until the panel closed); drawDetail now ends a stage it clears. FUSE ALL (above the list;
  `Fuse("ALL")`): every card, lowest border first, cascading (200 Base -> 2 Gold; 100 Gold -> 1 Rainbow).
  Fusion still needs 100 copies AT ONE border; the tiles' xN is the total over all borders.
- DMG / HP: `Kit.statsText` (⚔ DMG / ❤ HP, Support ✨ PWR / SPD) on vault tiles (`CardTile` option Stats),
  the tooltip and the deck inspector; `Kit.short` for 2.2K / 1.25M.
- QUICK is a toggle (`Settings.QuickRoll`, MetaService "SetQuickRoll"; T key): on, ROLL plays the short reveal.
- Packs: `OpenPack(packId, count)` opens 1 / 5 / 10 / "all" (at most 10,000 rolls a call), and works while Auto
  Roll runs (a pack opens with no yield, so it can't interleave with an Auto Roll pull). BAG: OPEN 1 / 5 / 10 / ALL.
- Tower is repeatable: `BattleStart(Tower.Id, nil, { Floor = n })`, n from 1 to Floor + 1 (server-checked). A
  cleared floor is a replay: `Tower.Reward(floor, true)` = same Shards / Trait Shards / XP / artifact roll, no Roll
  Packs or sure potion. TOWER tab floor picker (‹‹ ‹ FLOOR n › ›› NEXT); NEXT FLOOR / TRY AGAIN / auto-climb
  go from the floor just fought.
Planned next: AI card illustrations (user). Ascension was left out (user's call). Keep it SMALL: the border still wins.
Leaderboards: Rolls / Level in the player list, and three boards at the map's `Leaderboards` marker
(most rolls, rarest card incl. fusions, fastest Nightmare clear of the last boss) from OrderedDataStores,
refreshed every 60 s.
World 4, Stormspire Isle (south of the lake, over a second bridge; town gate at the south-east): boss Tenrai,
the Storm Sovereign (Chain Lightning hits random cards, Thunderclap stuns the whole deck at 50%), D 10-12,
recommended 140k / 172k / 205k (Nightmare needs a few fusions), 4 new cards (Hayate, Amane, Tsubasa, Amaya),
rain battle backdrop, storm music + local lightning in `ZoneFx`. Terrain: `tools/studio/terrain.luau`
`{ Rows = {9, 11} }`; props + markers: `map.luau` `{ Part = "storm" }`.
Visual pass: a title screen (`UI/Title`: logo, 3D card fan, PLAY unlocks once loaded; the HUD waits behind
it); reveals stand on a tier-coloured backdrop (radial glow + motes), the card flips and sways, Legendary+ get
letterbox bars and Mythic/Secret a light burst; the battle has a glowing boss platform per world, a vignette,
themed hit sparks, crit flash + shake and bigger damage numbers; POTIONS, SHOP rows and the Index detail
use the kit tile look; panels rise and pop in.
Ride pets (`Mounts.luau`, `MountService`, `UI/Pets`): 5 AI-generated mounts (Sakura Pup free; Ember Fox,
Frost Wolf, Void Ray, Storm Kirin unlock on each boss's first Normal clear), speed 26-38, no battle power.
G or the PETS paw (top right, under the gear) rides / gets off; the server welds the model under the rider.
Models live in the place at `ReplicatedStorage.MountKit` (not Rojo); per mount `Seat` is the rider's hip height
and `Forward` slides the model so the saddle is under them. Dash on Q (touch: DASH button, gamepad: X), client
side; two charges (double dash), both back 1.2 s after the last; a mid-air double jump (ring of light, back on
landing), both in `Dash.luau`; Quick Roll moved from Q to T.
On foot, your last mount follows as a small pet (`Followers.luau`, client-drawn from the character's "Pet"
attribute). Name tags over every player (`NameTagService`: name, level, rarest card in its colour).
Sakura petals drift in town and leaves in Ember Village (`ZoneFx`). The 4 bosses, Kenji and Hoshi use AI
models from `ReplicatedStorage.BossKit` (place only; `BossModels.Build` scales them and falls back to the
block figures).
Retention pass (all in `Meta`, all earned, nothing sold): player levels 1-100 (XP from rolls, new cards,
boss wins x D, quests, fusions and every minute played; each level pays Shards, potions every 5th, +0.02x
base luck every 10th; `MetaService.AddXP` + Progress remote; level bar under the top bar, LEVEL UP burst);
server events on the clock (`Meta.EventAt`: the last 5 min of every 15 runs LUCKY STORM 2x luck / ROLL
RUSH 40% faster / DOUBLE XP in turn, same on every server; event pill under the level bar); Lucky Wheel
(`UI/Wheel`, a free spin per 20 min played, banked up to 5, every prize's chance shown); playtime gifts now
run to 3 hours. Test tools can start an event, give spins and add XP.
Readable abilities (`UI/Abilities`): coloured slot badge, when it fires, big name, numbers in gold; shown in the
Index detail, beside the card on full reveals, and in battle (tap a card for its abilities; SKILL casts pop a tag
over the card). Card art: the user is making 2D anime illustrations from `art/CARD_ART_PROMPTS.md`; PNGs go in
`art/cards/<cardId>.png`, Claude uploads them from Studio and sets `Image` in `Cards.luau` (an Image fills the
portrait in cards, tiles and battle; cards without one keep the 3D figure).

## Layout (Rojo project, `default.project.json`)

- `src/configs` -> ReplicatedStorage.Configs: `UITheme` (design tokens, client UI only).
- `src/shared` -> ReplicatedStorage.Shared: `Config` (tuning + `TestMode`, deck and battle rules), `Rarity` (7 tiers, artifacts / traits only),
  `Cards` (card data; each ability lists its battle effects from the effect library documented at the top),
  `Odds` (luck, floor, pity math, shared by server and client so the odds panel matches the server),
  `Borders` (the card tiers: odds, multipliers, cost, colours), `Items` (artifacts, accessories, drop odds, gear bonuses),
  `Deck` (deck rules, validation, Deck Power, Auto-build), `Bosses` (boss stats, moves, difficulties, unlocks),
  `Rewards` (boss reward rolls / luck / floor per difficulty score D), `BossModels` (NPC figures from plain parts),
  `Tower` (Infinite Tower floors, enemies, affixes, curve, rewards, daily mutators),
  `Elements` (element wheel, synergies, bonds), `Raid` (server raid schedule, Colossus sizing, pool, rewards),
  `Foils` (foil editions), `Awaken` (Awakening nodes), `RollBoost` (Momentum + Overcharge Surge),
  `MonetizationConfig` (pass / product ids, perks, mock toggle),
  `Cards` also has `Pool`, `PullChances`, `ForBoss`, `Stat`, `Power(card, stars, border, awaken)`, `Cost(border)`,
  `Traits` (card traits: odds, effects, reroll cost), `Meta` (potions, upgrades, Index rewards, daily, gifts,
  milestones, daily quests, levels and stat points, server events, the Lucky Wheel, and the luck / cooldown formulas
  both sides use), `Mounts` (ride pets).
- `src/server` -> ServerScriptService.Server: `Main.server`, `DataService` (ProfileStore saves),
  `RollService` (all rolls, cooldown, Auto Roll loop, dev tools), `DeckService` (presets), `BattleService`
  (runs fights in real time, streams events), `BattleEngine` (pure battle simulation, no Roblox services, so tests
  run it headless), `RateLimit`, `World` (at start: portal glow, signs, boss + sage NPCs and spawn at the saved
  map's markers, and zone circles in ReplicatedStorage.Zones; falls back to the old parts hub when there's no map),
  `MetaService` (potions + timers, shop, claims, SetMusic / SetEffects volume (must be in `Config.VolumeSteps`);
  owns the dev luck override and the player's total luck / cooldown),
  `TravelService` (Travel remote: validates "Town" or a boss id, rate-limited, refused in battle, streams the
  area in, then pivots beside the zone's Boss_ marker / Spawn), `FusionService` (Fuse remote: checks ownership,
  100 copies at that border, then fuses into the next border), `LeaderboardService` (leaderstats + the town boards; test scores go to
  `LB_*_Test_1` stores),
  `ProfileService` (Profile remote: public profiles of players in the server), `RaidService` (the server's raid
  pool, hitters, payouts, Raid Luck), `TraitService` (Trait Master rolls), `Momentum` (roll chains),
  `MonetizationService` (passes, policy gating, Luck Totem, Shard bundles, receipts), `AvatarService` (avatar auras:
  character attributes + the AuraReplication event), `NpcRange` (town NPC
  services only beside their NPC), `CodeService` + `Codes` (redeem codes, server-only list), `ProfileStore` (vendored, Apache-2.0). `RollService.RewardRolls` pays boss rewards (wired into BattleService in `Main.server`).
- `src/client` -> StarterPlayerScripts.Client: `Main.client`, `State`, `MetaClient` (progression calls, badge counts),
  `LightingSetup` (the twilight base light), `Followers` (shoulder pets, mount stride sway), `Avatars` (avatar auras / trails),
  `HubFx` (NPC idle animation, sage tips, portal lock labels), `ZoneFx` (zone music + lighting mood),
  `UI/*` (Kit helpers incl. `Kit.tile` / `Kit.dimTile`, Theme, Skin (UI kit image ids), BorderFx (card border frames), Title, Travel, Settings, Fusion, Modal (blurred-world
  obsidian panel with title tab; `Modal.Tabbed` pages), Alchemy (Hoshi's PACK ALCHEMY tab), Waypoint (guide line to a town NPC), Controls (dropdown tiles, tabs, chips, search, banners), Components/JuicyButton + Components/IconBadge (occult button feel, icon badges), CardView (full card), CardTooltip (hover zoom + ability flyout), CardTile (square
  grid tile), ElementUi (element badges / rich text), ElementGuide (ELEMENTS panel), TraitMaster, Store, Reveal, Effects, Hud, Index, OddsPanel, Bag + BagGear, Stats, Shop, Gifts, DevPanel, DeckBuilder, BossScreen,
  Battle, RewardReveal, ModelView (3D figure in a ViewportFrame), Sfx).
- Remotes are declared in `default.project.json` under ReplicatedStorage.Remotes.
- Not in Rojo: the map lives only in the place file (published to Roblox): `workspace.Map` (Town, EmberVillage,
  FrostfangPeaks, NeonAbyss, StormspireIsle, Markers), Terrain, Lighting, `ServerStorage.MapKit` (store models,
  scripts stripped), `ReplicatedStorage.MountKit` (mount models), `ReplicatedStorage.BossKit` (boss / NPC models).
  `tools/studio/*.luau` rebuild or tweak it (see its README).

## Rules to keep

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on the server.
- The border always wins: Base 1x / Gold 4x / Rainbow 16x / Secret 64x; every card's base stats stay within +-10% of
  one line (HP = 2 x ATK); stars add +5% each, max 5; a maxed card on one border never reaches a 0-star card on the
  next (odds_test checks). Traits stay small (never ATK / HP). Rolls are pure luck: no pity. Fusion is border
  fusion only: 100 copies at one border -> 1 copy at the next.
- Content is data: a new card is one entry in `src/shared/Cards.luau` (stats, abilities, `Role`, `Weight`, `Image`), a new boss or
  difficulty one entry in `src/shared/Bosses.luau`, a new artifact one entry in `src/shared/Items.luau`, a new trait one entry in `src/shared/Traits.luau`,
  a new potion / gift / milestone / quest one entry in `src/shared/Meta.luau`
  (no other code changes). Only Secret signatures are coded in `BattleEngine`.
- Potions, upgrades and gifts are earned in game only (Shards can also come from the STORE's Shard bundles,
  which are gated like random items because Shards buy luck). Robux sales live only in MonetizationConfig /
  MonetizationService; any perk that changes odds or gives random rewards is marked Random and gated by
  PolicyService (see the policy rule below).
- Boss HP / ATK per difficulty are tuned so the deck in `tests/fixtures.luau` for each fight (about its
  recommended power, fusions allowed via the fixture's `Fusion`) wins in 60-90 s; `tests/battle_test.luau` checks
  all 12 fights. Re-run it after changing
  cards, bosses or battle rules, and retune if it fails. `tests/tower_test.luau` does the same for the tower: each
  fixture deck must beat every enemy (and affix) at the floor matching its power, 90%+ with a median under 100 s
  (retune `Tower.Curve.Points` or the enemy HP multipliers if it fails).
- Original characters only, no real anime characters or names.
- Keep it cheap on phones: UI-first, plain Frames + tweens for effects, no textures or 3D particles in reveals;
  at most one 3D model per ViewportFrame. The world uses StreamingEnabled; keep the map under ~15k parts and
  few lights (the Abyss has 6, town lanterns are capped at 24 with no shadows), and give multi-part props
  ModelStreamingMode Atomic.
- Town services stay at their NPCs (Hoshi: fusion + alchemy, Kenshin: traits, Fortuna: wheel): no HUD
  shortcut, and the server checks `NpcRange.Near`.
- Creator Store models: strip every script before use (tools/studio/stage.luau does). Sounds: licensed
  libraries only (Pro Sound Effects, APM Music) or ones shipped with Roblox; all ids live in `UI/Sfx.luau`.
- Leave `Config.TestMode = true` during testing. Setting it false hides the dev panel, enables unlock rules
  (`Config.Unlocks`) and makes the server refuse dev tools.
- If anything is ever sold for Robux that changes odds (luck boosts, pity skips), Roblox's paid random items policy applies:
  show all outcomes and live odds summing to 100%, and check `PolicyService:GetPolicyInfoForPlayerAsync()` (`ArePaidRandomItemsRestricted`).

## Commands

- Workflow: open the published place in Studio, run `rojo serve`, press Connect in the Rojo plugin. Rojo only
  touches the folders in `default.project.json`, never the map. Save/publish the place from Studio.
- Never `rojo build` over the place you open in Studio: a built place has no map (it gets the fallback hub).
  `rojo build default.project.json -o AnimeCardRoll-Test.rbxlx` is only for a throwaway script test.
- Rojo and the `luau` CLI are installed via rokit (`~/.rokit/bin`, pinned in `rokit.toml`); luau-lsp isn't in rokit yet: in a cloud session download the release binary (1.70.1 worked) and rojo 7.7.1 into the scratchpad. The type check below ran clean (0 errors) on 2026-10-23; keep it clean.
- Type check (needs luau-lsp): `rojo sourcemap default.project.json --include-non-scripts -o sourcemap.json` then
  `luau-lsp analyze --platform roblox --sourcemap sourcemap.json --definitions @roblox=tests/defs/globalTypes.d.luau --ignore "**/ProfileStore.luau" src/`
- UI property names check (props set through `Kit.new` aren't type checked): `python tests/check_props.py tests/defs/globalTypes.d.luau src`
- Odds / card stat / progression / deck / battle / tower / pack / strategy (elements, raids) / phase 2 tests (needs the `luau` CLI): `python tests/bundle.py` then `luau tests/bundle_out.luau`

Tool versions are pinned in `rokit.toml` (`rokit install`).
