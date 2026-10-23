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
  Surge (`RollService` rollClick): Auto = Rare+ with 1.5x border / foil odds; a click inside the 1.5 s window after
  the cooldown (or the Auto Roll pass) = PERFECT: 3 cards, the first Epic+, 2x border / foil odds (`result.Extra`).
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
- HUD regroup: top bar = Shards, Trait Shards, Rolls (luck + ODDS under it). The menu is 4 categories, each a
  popover: BATTLE (Bosses, Tower, Raid, Cost = boss screen with Cost Challenge on), SQUAD (Deck, Index, Traits,
  Stats), HUB (Kenji, Quests = GIFTS, Fusion, Bag incl. alchemy, Wheel, Travel), STORE (Passes, Shards = Shard
  Shop, Totem, Codes), + DEV in TestMode. Item badges add up on their category. The left column (tracker + menu)
  scales with the screen (`layoutLeft`, ~0.6 on a phone); the Momentum line goes short on narrow docks.
Planned next: AI card illustrations (user). Ascension was left out (user's call). Keep it SMALL: rarity still wins.
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

- `src/shared` -> ReplicatedStorage.Shared: `Config` (tuning + `TestMode`, deck and battle rules), `Rarity` (7 tiers),
  `Cards` (card data; each ability lists its battle effects from the effect library documented at the top),
  `Odds` (luck, floor, pity math, shared by server and client so the odds panel matches the server),
  `Borders` (card border odds, colours and bonus), `Items` (artifacts, accessories, drop odds, gear bonuses),
  `Deck` (deck rules, validation, Deck Power, Auto-build), `Bosses` (boss stats, moves, difficulties, unlocks),
  `Rewards` (boss reward rolls / luck / floor per difficulty score D), `BossModels` (NPC figures from plain parts),
  `Tower` (Infinite Tower floors, enemies, affixes, curve, rewards, daily mutators),
  `Elements` (element wheel, synergies, bonds), `Raid` (server raid schedule, Colossus sizing, pool, rewards),
  `Foils` (foil editions), `Awaken` (Awakening nodes), `RollBoost` (Momentum + Overcharge Surge),
  `MonetizationConfig` (pass / product ids, perks, mock toggle),
  `Cards` also has the fusion helpers (`FusedRarity`, `MaxFusion`, `Stat`, `Power(card, stars, fusion)`),
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
  copies and max rarity, then fuses), `LeaderboardService` (leaderstats + the town boards; test scores go to
  `LB_*_Test_1` stores),
  `ProfileService` (Profile remote: public profiles of players in the server), `RaidService` (the server's raid
  pool, hitters, payouts, Raid Luck), `TraitService` (Trait Master rolls), `Momentum` (roll chains),
  `MonetizationService` (passes, policy gating, Luck Totem, receipts), `CodeService` + `Codes` (redeem codes, server-only list), `ProfileStore` (vendored, Apache-2.0). `RollService.RewardRolls` pays boss rewards (wired into BattleService in `Main.server`).
- `src/client` -> StarterPlayerScripts.Client: `Main.client`, `State`, `MetaClient` (progression calls, badge counts),
  `HubFx` (NPC idle animation, sage tips, portal lock labels), `ZoneFx` (zone music + lighting mood),
  `UI/*` (Kit helpers incl. `Kit.tile` / `Kit.dimTile`, Theme, Skin (UI kit image ids), BorderFx (card border frames), Title, Travel, Settings, Fusion, Modal (blurred-world
  panel with slanted banner), Controls (option pills, tabs, search, headers), CardView (full card), CardTile (square
  grid tile), ElementUi (element badges / rich text), ElementGuide (ELEMENTS panel), TraitMaster, Store, Reveal, Effects, Hud, Index, OddsPanel, Bag + BagGear, Stats, Shop, Gifts, DevPanel, DeckBuilder, BossScreen,
  Battle, RewardReveal, ModelView (3D figure in a ViewportFrame), Sfx).
- Remotes are declared in `default.project.json` under ReplicatedStorage.Remotes.
- Not in Rojo: the map lives only in the place file (published to Roblox): `workspace.Map` (Town, EmberVillage,
  FrostfangPeaks, NeonAbyss, StormspireIsle, Markers), Terrain, Lighting, `ServerStorage.MapKit` (store models,
  scripts stripped), `ReplicatedStorage.MountKit` (mount models), `ReplicatedStorage.BossKit` (boss / NPC models).
  `tools/studio/*.luau` rebuild or tweak it (see its README).

## Rules to keep

- The server owns every roll, stat and result; the client only requests and animates. Validate every remote argument on the server.
- Rarity always wins: each tier's stats are >= 1.6x the tier below; a card stays within +-10% of its tier base; stars add +5% each, max 5.
  Traits and borders stay small (traits never add ATK / HP). Rolls are pure luck: no pity.
  Fusion keeps this: a fused card counts as its new rarity (stats scaled by the tier multipliers), never more.
- Content is data: a new card is one entry in `src/shared/Cards.luau` (stats, abilities, `Image`), a new boss or
  difficulty one entry in `src/shared/Bosses.luau`, a new artifact one entry in `src/shared/Items.luau`, a new trait one entry in `src/shared/Traits.luau`,
  a new potion / gift / milestone / quest one entry in `src/shared/Meta.luau`
  (no other code changes). Only Secret signatures are coded in `BattleEngine`.
- Potions, upgrades and gifts are earned in game only. Robux sales live only in MonetizationConfig /
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
  few lights (the Abyss has 6), and give multi-part props ModelStreamingMode Atomic.
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
