# Anime Card Roll Game — Concept

Oct 20, 2026 · @zenki

## Overview

A Roblox RNG card game: players roll anime-style cards, build a deck of 4 Attack + 4 Support cards, and fight each world's boss. Every boss win pays out instant bonus rolls, and harder bosses give more rolls with more luck.

**Design pillars**

- **Rarity is power.** A higher-rarity card always beats a lower one, even a fully upgraded lower one (rule in Rarity).
- **Every roll is a moment.** Quick for Commons, a bigger show for each tier above.
- **Two roles, real choices.** Attack cards win the fight; Support cards keep them alive and make them hit harder. The 4 + 4 split stops players from just stacking their top 8.
- **Smooth on a cheap phone.** Rolls, cards and battles are mostly 2D UI; 3D is a small hub plus one boss model per fight.
- **Content is data.** A new card = one table entry + its art, no new code, so adding cards after launch is fast.
- **Original characters only.** Real anime characters expose the game to copyright takedowns; original ones are yours to expand.

**First session, as intended:** roll about 20 times, auto-build a deck from Commons and Uncommons (about 15k Deck Power), beat World 1 Normal (12k recommended), and get 5 boss rolls with boosted luck.

&#91;embedded content: core loop · 4 steps, 1 decision, 2 loops\]

A loss sends the player back to rolling; a win pays reward rolls that make the deck stronger for the next, harder boss.

## Rarity and power

Seven tiers. Each tier's stats are at least 1.6× the tier below, which is more than a lower card can ever gain from variance and upgrades, so higher rarity always wins.

| Rarity | Base odds | About 1 in | Stat multiplier | Abilities | Colour | Reveal |
| --- | --- | --- | --- | --- | --- | --- |
| Common | 60% | 1.7 | 1.0× | Basic | Grey | Plain flip |
| Uncommon | 25% | 4 | 1.6× | Basic + Passive | Green | Flip + green glow |
| Rare | 10% | 10 | 2.6× | Basic + Skill | Blue | Glow burst + chime |
| Epic | 4% | 25 | 4.2× | Basic + Skill + Passive | Purple | Screen shake + particles |
| Legendary | 0.9% | 111 | 7.0× | + Ultimate | Gold | Gold flash, foil shimmer |
| Mythic | 0.09% | 1,111 | 12× | Ultimate with 2 effects + team aura | Crimson | Full-screen cut-in, server announcement |
| Secret | 0.01% | 10,000 | 20× | + a signature rule-breaking mechanic | Prismatic black | Blackout cinematic, server-wide announcement |

**Why rarity always wins**

- Within a tier, cards vary up to ±10% from the tier's base stats (glass cannon vs tank).
- Duplicates add stars: +5% stats per star, max 5★ (+25%).
- Best possible lower card = 1.1 × 1.25 = 1.375× its tier base. Weakest card of the next tier = 0.9 × 1.6 = 1.44×. Every gap in the table is 1.6× or more, so this holds at every step.
- Speed (SPD) stays between 85 and 120 at every rarity: it changes play style, not power.

**Luck** multiplies every Rare-and-above chance exactly; the extra comes out of Common. Uncommon stays at 25%. Launch cap is 5×, where Common reaches 0%.

```latex
P_t(L) = p_t \cdot L \quad (t \ge \text{Rare}), \qquad P_{\text{Common}}(L) = 1 - 0.25 - \sum_{t \ge \text{Rare}} p_t \, L
```

At 2× luck: Rare 20%, Epic 8%, Legendary 1.8%, Mythic 0.18%, Secret 0.02%, Uncommon 25%, Common 45%.

**Rarity floor** (boss reward rolls only): any result below the floor is upgraded to the floor tier, so luck still decides the rare pulls.

**Pity:** an Epic or better is guaranteed by the 50th roll without one, a Legendary or better by the 300th. Counters are saved per player.

**Duplicates:** the first copy unlocks the card, copies 2–6 add stars, and anything past 5★ turns into Shards (Common 1, Uncommon 2, Rare 5, Epic 15, Legendary 60, Mythic 300, Secret 1,500). Shards buy permanent upgrades: faster rolls, +0.05× base luck per level, more inventory.

**Odds panel:** an "Odds" button beside the luck meter always shows the live percentages, with active luck and floors applied, summing to 100%. Free rolls don't legally need this, but the moment any luck boost or pity skip is sold for Robux, Roblox requires it, so build it from day one ([Roblox policy](https://create.roblox.com/docs/production/monetization/paid-random-items)).

## Card types: Attack and Support

Every card is Attack or Support. Attack cards deal the damage that wins the fight; Support cards heal, shield, buff the team and weaken the boss. Neither type can win alone.

|  | Attack | Support |
| --- | --- | --- |
| Job | Damage the boss | Keep Attack cards alive and make them hit harder |
| Main stat | ATK: damage per hit | PWR: strength of heals, shields, buffs |
| Main stat at 1.0× | 100 ATK | 60 PWR |
| HP at 1.0× | 400 | 500 |
| Row | Front: takes 70% of the boss's single-target hits | Back: takes 30% |
| Deck Power | ATK × 10 + HP | PWR × 15 + HP |

**Ability slots** (same for both types; how many a card has depends on rarity)

- **Basic:** used on every action.
- **Skill:** replaces the Basic every N actions (N is set per card, usually 3).
- **Passive:** always on.
- **Ultimate:** costs 100 energy; the player taps the card to fire it, or turns on Auto. Cards gain +20 energy per action and +10 per hit taken.
- **Aura** (Mythic): a passive that affects the whole deck.
- **Signature** (Secret): a mechanic that bends a battle rule, such as an extra turn or surviving a KO.

**Effect library.** Every Basic, Skill, Passive and Ultimate is built from 10 effects, so a new card is data, not code: Damage (single, multi-hit, all), Burn (damage over time), Heal, Shield, Buff (ATK, crit, SPD up), Debuff (boss DEF, ATK, SPD down), Energy, Cleanse, Taunt, Revive. Only Secret signatures are coded one by one.

## Starter card set (18 cards)

Launch with 9 Attack and 9 Support cards: two of each type at Common and Uncommon, so a full 4 + 4 deck is possible within the first few dozen rolls, and one of each type at every tier above. When a roll lands on a tier, each card in that tier is equally likely. All characters are original; stats follow the ±10% band rule.

**Attack cards**

| Card | Rarity | ATK | HP | SPD | Abilities |
| --- | --- | --- | --- | --- | --- |
| Rook, Village Brawler | Common | 110 | 360 | 95 | Basic: Heavy Jab, 100% ATK |
| Kaede, Kunai Thrower | Common | 95 | 420 | 115 | Basic: Twin Kunai, 2 hits × 50% |
| Tomo, Lantern Swordsman | Uncommon | 165 | 620 | 100 | Basic: Slash 100% · Passive: +15% damage while the boss is above 50% HP |
| Mirai, Spark Archer | Uncommon | 150 | 680 | 110 | Basic: Spark Arrow 100% · Passive: 15% chance to Burn (5% ATK per turn, 3 turns) |
| Sora Ikazuchi, Storm Blade | Rare | 270 | 1,000 | 120 | Basic: Slash 100% · Skill (every 3): Thunder Rush, 3 hits × 80% |
| Akane, Crimson Lancer | Epic | 430 | 1,700 | 105 | Basic: Thrust 100% · Skill (every 3): Piercing Spiral 250% + boss DEF −15% for 2 turns · Passive: crits deal 200% instead of 150% |
| Kaito Ryuzen, Dragon-Eye Ronin | Legendary | 720 | 2,700 | 110 | Basic: Cut 100% · Skill (every 3): Dragon Draw 300% · Passive: +20% ATK below 50% HP · Ultimate: Thousand Dragon Cut, 8 hits × 90% |
| Noa, Starfall Witch | Mythic | 1,250 | 4,600 | 100 | Basic: Star Bolt 120% · Skill (every 3): Comet Rain, 4 hits × 100% · Ultimate: Meteor Requiem 900% + boss takes +25% damage for 3 turns · Aura: all Attack cards +10% ATK |
| Raijen, Eclipse Sovereign | Secret | 2,050 | 8,100 | 115 | Basic: Shadow Edge 120% · Skill (every 3): Umbra Cross 400% · Ultimate: Black Sun 1,500%, ignores shields and DEF · Signature, Eclipse: every 5th action, he acts again at once |

**Support cards**

| Card | Rarity | PWR | HP | SPD | Abilities |
| --- | --- | --- | --- | --- | --- |
| Hana, Herb Healer | Common | 60 | 520 | 100 | Basic: heal the lowest-HP ally 100% PWR |
| Goro, Shield Monk | Common | 55 | 550 | 90 | Basic: shield one Attack card 150% PWR |
| Suzu, Shrine Drummer | Uncommon | 100 | 780 | 105 | Basic: all Attack cards +8% ATK for 1 turn · Passive: +5 energy to a random ally each time she acts |
| Ibuki, Fog Weaver | Uncommon | 92 | 820 | 100 | Basic: boss −10% ATK for 1 turn · Passive: the first boss hit aimed at her each battle misses |
| Yume Aoi, Moonlight Priestess | Rare | 160 | 1,300 | 110 | Basic: heal the lowest-HP ally 100% · Skill (every 3): Moon Bloom, heal all 120% + cleanse 1 debuff |
| Tetsu, Iron Wall Guardian | Epic | 245 | 2,200 | 85 | Basic: shield an ally 150% · Skill (every 3): Iron Bastion, taunt for 2 turns + team shield 100% · Passive: takes 20% less damage |
| Luna Mei, Celestial Strategist | Legendary | 430 | 3,400 | 115 | Basic: heal 100% · Skill (every 3): Battle Plan, all Attack cards +25% ATK for 2 turns · Passive: +5 energy to every ally each time she acts · Ultimate: Grand Formation, resets all Attack Skill cooldowns + 30 energy each |
| Orin, Time Weaver | Mythic | 740 | 5,900 | 100 | Basic: heal all 60% · Skill (every 3): Haste, all allies +20% SPD for 2 turns · Ultimate: Rewind, revive all KO'd allies at 40% HP + heal team 200% · Aura: boss −15% SPD |
| Aurelia, Dawn Empress | Secret | 1,230 | 10,200 | 110 | Basic: Radiant Heal, all 80% · Skill (every 3): Sunshield, team shield 200% · Ultimate: Radiant Crown, team +50% damage for 2 turns · Signature, Dawn Oath: once per battle, an ally who would be KO'd survives at 1 HP and is invulnerable for 1 turn |

Deck Power check: the first Common + Uncommon deck is about 14,600. The strongest launch deck (Secret, Mythic, Legendary, Epic of each type) is about 123,000 at 1★ and about 154,000 at 5★.

## Rolling: Roll, Quick Roll, Auto Roll

Rolling is free and unlimited, paced by a 1.2-second cooldown. Three buttons sit bottom-middle in this order: Auto Roll · ROLL · Quick Roll, with ROLL the largest. During the test phase all three buttons work from the start; the unlock rules below stay in the code behind an off switch, for launch.

| Button | What it does | Unlocks (launch only) |
| --- | --- | --- |
| Roll | One roll with the full reveal for its rarity | From the start |
| Quick Roll | One roll with a fast flip; Epic and up still flash, Mythic and up still get the full reveal | 20 rolls + 3 minutes played |
| Auto Roll | Rolls on every cooldown, hands-free, using the Quick Roll reveal; tap again to stop | 50 rolls + 10 minutes played |

- **Locked look:** greyed with a lock icon and a progress ring ("12/20 rolls · 2:10 left"). On unlock the button pops with a glow and a one-line tip. Unlocks are permanent and saved.
- **Auto Roll stops itself** on Legendary or better by default; the player can set it to Mythic, Secret or never.
- **Auto Roll keeps running during boss fights.** Results go to a small feed in the corner, so fighting never costs rolls and boss rewards are pure bonus.
- **Only while in the game:** no offline rolling.
- **Roll speed:** Shard upgrades lower the cooldown from 1.2 s to 0.8 s. The server enforces the cooldown; the button only mirrors it.

## Deck building (4 Attack + 4 Support)

A deck is 8 slots: 4 Attack on the front row, 4 Support on the back row, and each slot accepts only its type.

1. No two copies of the same card in one deck, so collecting more cards always matters.
2. Empty slots are allowed; the deck simply has less power.
3. Deck Power (the sum of the 8 cards) shows at the top of the deck screen and beside each boss's recommended power.
4. 3 saved deck presets, switchable from the boss screen.
5. "Auto-build" fills each row with the highest-power cards owned.
6. Drag to reorder; when two cards have equal SPD, the left one acts first.

Synergy is where skill shows: Tetsu's taunt protects glass cannons like Rook, Akane's DEF cut raises every attacker's damage, and Luna Mei's cooldown reset is worth most with Skill-heavy attackers like Kaito and Sora.

## Battle system

Battles are 8 cards against one boss, played out automatically on action timers, with the player tapping Ultimates as they charge. A deck at the boss's recommended power should win in 60–90 seconds.

1. Every card and the boss has an action bar that fills at its SPD; a full bar means it acts.
2. A card's action is its Skill if the cooldown is ready, otherwise its Basic.
3. At 100 energy the card glows; tap it to fire its Ultimate, or switch on Auto.
4. Boss single-target hits land on the front row 70% of the time and the back row 30%, unless a taunt is up. Big boss moves show a 2-second warning marker first.
5. Boss phases: at 50% HP it adds a new move; at 20% it enrages (+30% ATK).
6. Win when the boss reaches 0 HP. Lose when all 4 Attack cards are KO'd or the 3-minute timer ends.
7. 1× / 2× speed toggle; 2× unlocks after clearing World 1 Normal.

**Damage**

```latex
\text{Damage} = \text{ATK} \times \text{Skill\%} \times (1 + \textstyle\sum \text{Buffs}) \times \text{Crit} \times (1 - \text{DEF}_{\text{boss}})
```

Crit: 10% base chance, 1.5× damage. Boss DEF runs 0–40%; debuffs lower it, never below 0. Heals and shields are PWR × the ability's %; a shield absorbs damage until it breaks or 2 turns pass.

## Worlds and bosses

Launch with 3 worlds, one boss each, and 3 difficulties per boss: 9 fights. Clearing Normal unlocks that boss's Hard and the next world's Normal; clearing Hard unlocks Nightmare.

| World | Boss | Mechanic | Recommended Deck Power (Normal / Hard / Nightmare) |
| --- | --- | --- | --- |
| 1 · Ember Village | Kurogane, the Ash Ronin | Hits Burn their target; at 50% HP, Ash Storm hits every card | 12k / 18k / 24k |
| 2 · Frostfang Peaks | Rimeveil, the Glacier Queen | Freeze makes a card skip its next action; at 50% HP she slows the whole deck | 28k / 42k / 56k |
| 3 · Neon Abyss | Null Emperor Vex | Raises shields that only burst damage breaks; steals one buff each phase | 50k / 75k / 100k |

- **Hard** = boss stats ×1.5 and one extra move. **Nightmare** = ×2, and warnings shrink from 2 s to 1 s.
- **Boss HP** is tuned in playtests so a deck at recommended power wins in 60–90 s.
- **World 3 Nightmare** effectively needs at least one Secret: it is the launch chase.
- Each world is a small themed area in the hub with a boss portal, so the world list grows without new menus.

## Boss reward rolls

Every win instantly fires a burst of reward rolls. Each fight has a difficulty score D, from 1 (World 1 Normal) to 9 (World 3 Nightmare), and rolls, luck and the rarity floor all grow with it.

- **Reward rolls** = 3 + 2D
- **Boss luck** = 1 + 0.35D, capped at 4×; the player's own luck multiplies on top, total cap 5×
- **Floor:** Uncommon for D 1–2, Rare for D 3–6, Epic for D 7 and up
- **First clear** of each difficulty adds one guaranteed card one tier above its floor

| Fight | D | Reward rolls | Boss luck | Floor | First-clear bonus |
| --- | --- | --- | --- | --- | --- |
| World 1 Normal | 1 | 5 | 1.35× | Uncommon | Rare |
| World 1 Hard | 2 | 7 | 1.70× | Uncommon | Rare |
| World 1 Nightmare | 3 | 9 | 2.05× | Rare | Epic |
| World 2 Normal | 4 | 11 | 2.40× | Rare | Epic |
| World 2 Hard | 5 | 13 | 2.75× | Rare | Epic |
| World 2 Nightmare | 6 | 15 | 3.10× | Rare | Epic |
| World 3 Normal | 7 | 17 | 3.45× | Epic | Legendary |
| World 3 Hard | 8 | 19 | 3.80× | Epic | Legendary |
| World 3 Nightmare | 9 | 21 | 4.00× (cap) | Epic | Legendary |

&#91;embedded content: computed from the reward table above · 9 fights, player luck 1×\]

The floor upgrades only the low results, so the Legendary+ chance per roll is simply 1% × luck; more rolls and more luck together give the 12× jump.

**Reveal:** the reward cards fan out on screen and flip one by one, sorted so the rarest flips last. New worlds just continue D (World 4 = D 10–12) with no new rules.

## UI and performance on every device

The game is UI-first: rolling, decks and battles are 2D layers over a small 3D hub, which keeps it smooth on cheap phones while the effects stay flashy. Target: a steady 60 FPS, Roblox's default ([performance docs](https://create.roblox.com/docs/performance-optimization)), on one chosen low-end baseline phone.

**Main screen layout**

- **Bottom middle:** Auto Roll · ROLL · Quick Roll. The bottom corners stay clear for Roblox's mobile thumbstick and jump button.
- **Just above the buttons:** luck meter, the "Odds" button and Shards. Nothing important at the very top, where Roblox's own top bar sits on mobile ([DevForum](https://devforum.roblox.com/t/best-practices-for-mobile-users/264069)).
- **Left edge:** icon buttons for Cards, Deck, Worlds, Upgrades, Settings.
- **Right side, mid-height:** the Auto Roll feed.

**Fancy, but cheap**

- Each rarity has its own frame and outline; Legendary and up get a moving gradient sweep for a foil shimmer, one tween per card.
- The reveal ladder is chained tweens of size, rotation, transparency and colour, each starting when the last completes ([UI animation docs](https://create.roblox.com/docs/ui/animation)). Tweens are created once and reused.
- Screen shake moves the UI, not the camera. Sparks and bursts are sprite-sheet images in the UI, not 3D particle emitters.
- Sound does a lot of the work: a rising sting per rarity, a deep hit for Mythic and Secret.

**Runs everywhere**

- **Effects setting** High / Low, defaulting to Low on phones: Low drops blur, halves sprite bursts and shortens cinematics.
- **UI sizing:** Scale plus aspect-ratio and size constraints, checked in Studio's device emulator at phone, tablet, PC and console sizes.
- **Hub:** instance streaming on, which Roblox says improves join time, memory and frame rate ([design for performance](https://create.roblox.com/docs/performance-optimization/design)).
- **Art:** preload only the current card pool's images; one image size for all card art.
- **Profiling** on a real phone with the MicroProfiler: Roblox notes most players are on phones and tablets, which are the most constrained devices ([MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler)).

## Production plan

The server owns every roll, stat and battle result; the client only shows them. Card, rarity and boss data live in shared modules, so content grows without code changes.

&#91;embedded content: architecture · client, 5 server services, saved data, shared config\]

Requests go up, results and battle events come down; only the server touches saved data, and both sides read the same card and boss tables.

**Saved player data** uses ProfileStore, which session-locks a save to one server at a time to stop item duplication and rollbacks ([ProfileStore](https://devforum.roblox.com/t/profilestore/3190543)).

- Inventory: card ID → copies and stars
- Decks: 3 presets of 4 Attack + 4 Support card IDs
- Progress: cleared fights and first-clear flags
- Counters: total rolls, playtime, Epic and Legendary pity
- Shards and upgrade levels (roll speed, base luck)
- Settings: Auto Roll stop rarity, effects quality, battle speed
- A data version number, for safe migrations after updates

**Security**

- The client only sends requests: roll, start or stop Auto Roll, save deck, start fight, use Ultimate on card X.
- The server checks the cooldown, unlocks, deck rules (4 + 4, no copies, cards owned) and energy before an Ultimate, and rate-limits every remote.
- Random numbers come from a server-side `Random` object only; nothing random runs on the client.

**If Robux items are added later**

- Luck boosts, pity skips and rate-ups sold for Robux count as paid random items. Their odds must show as percentages summing to 100% before purchase, and update live while a boost is active ([Roblox policy](https://create.roblox.com/docs/production/monetization/paid-random-items)).
- Check `PolicyService:GetPolicyInfoForPlayerAsync()`: when `ArePaidRandomItemsRestricted` is true, that player must not be able to buy them (hide them, block the purchase, or offer a non-random version). If trading is ever added, allow it only when `IsPaidItemTradingAllowed` is true.
- Cosmetics (card frames, reveal styles) and convenience (extra deck presets) avoid these rules entirely.

**Milestones**

1. Rolling prototype: Roll button, reveal ladder, the 18 cards, inventory, saving. Done when a scripted million-roll test matches the Odds panel.
2. Quick Roll and Auto Roll (unlocks switched off for testing); duplicates, stars and Shards.
3. Deck builder, battle engine and the World 1 boss. Done when the first 14.6k deck beats World 1 Normal in 60–90 s.
4. Boss rewards, Worlds 2–3, difficulty unlocks, first-clear bonuses.
5. Polish: effects and sound, mobile layout, effects setting. Done at a steady 60 FPS on the baseline phone.
6. Closed test with friends; tune odds, unlock times and boss HP from play data.
7. Public launch. Next content: new cards (data only) and World 4.

## Open questions before production

- [ ] Game name.
- [ ] Unlock thresholds for launch (off during testing): keep 20 rolls + 3 min and 50 rolls + 10 min, or change them?
- [ ] Should Auto Roll keep running during boss fights? Currently yes.
- [ ] Ultimates: tap to fire with an Auto toggle (current), or fully automatic?
- [ ] Allow two copies of the same card in one deck? Currently no.
- [ ] Trading at launch? Currently no; adding it brings the policy checks above.
- [ ] Who makes the art for 18 cards and 3 bosses, and in what style?
- [ ] Robux plan: cosmetics only, or luck boosts under the odds rules?

## Sources

- [Paid random items policy guidelines](https://create.roblox.com/docs/production/monetization/paid-random-items), Roblox Creator Hub
- [Performance optimization](https://create.roblox.com/docs/performance-optimization), Roblox Creator Hub
- [Design for performance](https://create.roblox.com/docs/performance-optimization/design), Roblox Creator Hub
- [MicroProfiler](https://create.roblox.com/docs/performance-optimization/microprofiler), Roblox Creator Hub
- [UI animation and tweens](https://create.roblox.com/docs/ui/animation), Roblox Creator Hub
- [Best practices for mobile users](https://devforum.roblox.com/t/best-practices-for-mobile-users/264069), Roblox DevForum
- [ProfileStore](https://devforum.roblox.com/t/profilestore/3190543), Roblox DevForum
