# Anime Card Roll: every card, stat and chance (2026-10-30)

Generated from the game data (`src/shared/Cards.luau`, `CelestialCards.luau`, `Weather.luau`, `Borders.luau`,
`Bosses.luau`, `Items.luau`, `Meta.luau`, `Config.luau`) after the luck / odds / boss HP pass. Stats are at 0 stars
with no mastery, traits, duplicates or buffs. How the whole game works is in `CLAUDE.md`.

## How a roll works
1. The game picks a **card** by its chance (Weight out of 10,000).
   - The pool is every normal card, plus each boss card after that boss's first Normal clear.
   - The Card Packs collection can narrow it.
   - **Luck tilts the pool toward rare cards.** Cards of 1 in 100 or rarer are pulled more often as luck rises:
     at 35-40x luck high cards come about 2.5x as often, elite about 3.5x, apex about 4x and the World 4 boss card
     about 4.5x (5x at most). Starters give up a little of their share to make room.
2. It rolls a **border**: Gold, Rainbow and Secret multiply ATK / HP by 4x / 16x / 64x. Luck raises these.
   - Luck counts in full up to 35x. Above that it has diminishing returns (35 + 10 x ln(1 + over / 10)).
3. The **rarity number** is how many pulls one of that card at that border takes on average at 1x luck. For
   example, Autonomous God State Secret is 1 in 250,000,000.
4. Pulls of 1 in 10,000,000 or rarer post a chat line. 1 in 1,000,000,000+ posts a BILLION PULL line.

## Luck and gear
| Source | Luck | Border Chance | Other |
| --- | --- | --- | --- |
| Training: Luck (40 points) | +0.05x a point, +2x max | | |
| Training: Border Chance (30 points) | | +1% a point, +30% max | |
| Relic, Rare (Four-Leaf, Hourglass, Coin, Tome) | +0.75x | +15% | Hourglass / Coin / Tome keep a levelling specialty |
| Relic, Epic (Prism Shard, Moonstone) | +1x / +1.25x | +20% | |
| Relic, Legendary (Frost Sigil, Ember Heart) | +1.5x / +1.75x | +20% / +25% | Frost Sigil: faster rolls |
| Relic, Mythic (Storm Crown, Void Eye) | +2.25x / +2.5x | +30% / +35% | |
| The best three relics worn | +6.5x | +90% | |
| Crown of the Hundred Floors (Pagoda floor 100) | +3x | +50% | +15% squad ATK |
| Heart of the Endless Spire (Infinite Tower, first run to floor 100) | +2x | | 15% faster rolls |
| Luck Potion I / II / III (the best one counts) | +1.5x / +3x / +6x | | 5 / 10 / 15 min |
| Celestial sky | +0.5x to +2x | | |
| Raid Luck, Lucky Storm, Server Totem | multiply the total | | |

A maxed player (Training + three Mythic-tier relics + both artifacts + Potion III + Blood Moon, times Raid Luck and
Lucky Storm) reaches about 54x effective luck.

## Duplicates and fusion
- Every copy past the first at the border a card fights at adds **+0.5% ATK / HP**, up to **+25%** (51 copies).
- Hoshi fuses **100 copies** of one border into 1 copy at the next border, for every card and every step.

## Roll Packs
- Opening any number of packs is one instant server pass, whether that's 100 x 1,000-roll packs (100,000 pulls)
  or a million.
- You get one combined summary: total cards, the five rarest first, then every card / border stack.
- In the Cinematic reveal style, **SKIP ALL** ends the reveals and jumps to that summary.

## Celestial sky cards
- A sky can start in every 15-minute slot, 2.5 to 8.5 minutes in.

  | Sky | Chance per slot | Lasts | Luck bonus |
  | --- | --- | --- | --- |
  | Limitbreak Skies | 30% | 5 min | +0.5 |
  | Soulfall | 20% | 5 min | +1 |
  | Cursed Night | 20% | 5 min | +1 |
  | Blood Moon | 5% | 5 min | +2 |
  | none | 25% | | |
- **While a sky is active, every pull searches it once.** That includes each Triple Roll card and every pack
  pull, with no time limit, so packs opened during a sky give sky cards in proportion.
- Each card has its own chance per pull. Luck raises it by 35% of the luck bonus (30x luck = 11.15x, 50x = 18.15x).

| Sky | Any of its 4 cards, per pull (1x luck) | Rolling the whole sky by hand (~250 rolls) | 1,000 pulls | Expected from 100,000 pack pulls |
| --- | --- | --- | --- | --- |
| Limitbreak Skies (1 in 300 / 400 / 500 / 650) | 0.94% | about 90% | almost certain | about 940 |
| Soulfall (1 in 600 / 800 / 1,000 / 1,250) | 0.47% | about 69% | about 99% | about 470 |
| Cursed Night (1 in 600 / 800 / 1,000 / 1,250) | 0.47% | about 69% | about 99% | about 470 |
| Blood Moon (1 in 1,200 / 1,500 / 2,000 / 2,500) | 0.24% | about 45% | about 91% | about 240 |

## How a fight works (real-time battle pass)
- **Every Attack card acts on its own clock**, set by its archetype (from SPD). The four slots open their first
  Basics 0 / 0.35 / 0.7 / 1.05 s in. SPD buffs and slows speed up or slow down both timers.

  | Archetype | SPD | Basic every | Basic DMG | Skill cooldown | Skill DMG | Ultimate cost | Charge time | Ultimate DMG |
  | --- | --- | --- | --- | --- | --- | --- | --- | --- |
  | Fast | 120-135 | 1.0-1.2 s | 65-75% | 6.5-7.5 s | 240-270% | 80 | ~15 s | 480-540% |
  | Balanced | 105-119 | 1.5-1.8 s | 100-110% | 9-10.5 s | 280-320% | 100 | ~18.5 s | 580-650% |
  | Heavy | 85-104 | 2.3-2.8 s | 150-180% | 12-14 s | 340-400% | 135 | ~25 s | 750-900% |
  - DMG is the total of all hits per cast, an area hit counting once.
  - Within a band, the faster card gets the shorter timers and the rarer card the higher damage.
  - Energy charges at 5.4 a second, plus 3 for an enemy hit (at most every 2 s).
- **Ultimates:** tap a full card to fire it. **AUTO ULT** (on by default) fires them for you, also while you're AFK or
  the battle is hidden. **HOLD ULT FOR BREAK** (on by default) keeps full Ultimates while the boss Shield is over
  60%, then fires them one after another (0.5 s apart) the moment it breaks.
- **Boss Shield:** while the leader's Shield stands it takes **0.5x** damage (muted numbers with a shield mark).
  - Basics chip the bar, Skills chunk it (Heavy Skills twice as hard), Ultimates crack it a little.
  - A guard KO shatters 25% of the bar. A standing Warder absorbs 30% of the fill.
  - At 100% it **breaks**: the leader is stunned 6 s (its warned move cancelled) and takes **1.5x** damage (big gold
    numbers).
- **Boss Clash:** when the leader's big warned move finishes winding up, a **CLICK / SPACE TO CLASH!** ring shows
  for 1.2 s. In time, your strongest card dashes in:
  - it reflects 200% of its ATK into the leader
  - the move deals 75% less damage
  - the Shield bar fills 30%

  Ignored (or AFK), the move lands as normal.
- **Guards** are linked to the leader by beams:
  - Warder: the leader takes 40% less damage, and it absorbs 30% of Shield fill.
  - Mender: heals the leader 3% of its max HP every 8 s and cleanses its debuffs.
  - Striker: stacks Expose (+5% DMG taken, up to 5) on your highest-ATK card.
  - Hexer: stacks Weaken (-5% DMG dealt, up to 5) on your highest-ATK card and Burns it.
  - Stacks fall off 8 s after the last one.
- **Vanguard:** Attack slot 1 draws 50% of single-target enemy attacks (80% if it's a Warder).
- **Passives have no self-penalties.** Every passive still has a trigger and a bound: a chance, a limit, or a
  condition. No elemental damage: elements are themes only.

## Border odds (1x luck)
| Border | Stat multiplier | Chance per pull |
| --- | --- | --- |
| Base | 1x | everything else |
| Gold | 4x | 0.5000% (1 in 200) |
| Rainbow | 16x | 0.0200% (1 in 5,000) |
| Secret | 64x | 0.0002% (1 in 500,000) |

## Normal pool: Attack cards (strongest base first)
### Autonomous God State · The Silver Instinct
Normal pool · Attack · Cosmic Striker · Weight 20 · SPD 115
**Balanced** · Basic every 1.6s · Skill cooldown 9.5s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.20% (about 1 in 500; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,600 | 5,200 | 500 |
| Gold | 10,400 | 20,800 | 100,000 |
| Rainbow | 41,600 | 83,200 | 2,500,000 |
| Secret | 166,400 | 332,800 | 250,000,000 |

- **Basic · Instinct Strike**: Strike an enemy for 105% DMG.
- **Skill · Afterimage Assault**: Disappear beyond sight, then strike for 305% DMG.
- **Ultimate · Limit-Breaking Fist**: Break through defense and protection with a 625% DMG strike.
- **Signature · Perfect Instinct**: After every 5 attacks, a 50% chance to land a 125% DMG afterimage strike and evade the next enemy hit.

### Nine-Tails Sovereign · Vessel of the Nine Tails
Normal pool · Attack · Cosmic Striker · Weight 20 · SPD 115
**Balanced** · Basic every 1.6s · Skill cooldown 9.5s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.20% (about 1 in 500; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,700 | 5,400 | 500 |
| Gold | 10,800 | 21,600 | 100,000 |
| Rainbow | 43,200 | 86,400 | 2,500,000 |
| Secret | 172,800 | 345,600 | 250,000,000 |

- **Basic · Chakra Palm**: Strike an enemy for 105% DMG.
- **Skill · Planetary Chakra Spiral**: Drive three orbiting Chakra spheres into an enemy for 100% DMG each.
- **Passive · Crimson Lifeline**: When below 50% HP, draw on the sealed beast: recover 35% HP and gain 20% DMG.
- **Ultimate · Sovereign Beast Cataclysm**: Detonate a Beast Bomb for 250% DMG on every enemy, then land a 375% DMG Chakra strike on the chosen target.

### Crimson Scourge · King of Malice
Normal pool · Attack · Flame Hexer · Weight 28.571428571428573 · SPD 105
**Balanced** · Basic every 1.8s · Skill cooldown 10.5s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.29% (about 1 in 350; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,400 | 4,800 | 325 |
| Gold | 9,600 | 19,200 | 75,000 |
| Rainbow | 38,400 | 76,800 | 1,750,000 |
| Secret | 153,600 | 307,200 | 175,000,000 |

- **Basic · Rending Cut**: Strike an enemy for 105% DMG.
- **Skill · Spatial Severance**: Cut through the enemy's defenses by 15% for 2 turns, then deal 305% DMG.
- **Passive · Cursed Incision**: Critical hits carve a Bleed into the enemy, dealing 15% DMG each turn for 3 turns.
- **Ultimate · Malevolent Barrage**: Rain down six cursed slashes on random enemies, each dealing 105% DMG.
- **Aura · Shrine of Malice**: On entry, every ally gains 10% DMG.

### Dream Reaper · Mirror of Hypnosis
Normal pool · Attack · Frost Hexer · Weight 28.571428571428573 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.29% (about 1 in 350; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,200 | 4,400 | 325 |
| Gold | 8,800 | 17,600 | 75,000 |
| Rainbow | 35,200 | 70,400 | 1,750,000 |
| Secret | 140,800 | 281,600 | 175,000,000 |

- **Basic · Crow Shuriken**: Send two crow-feather blades into an enemy for 55% DMG each.
- **Skill · Crimson Illusion**: Trap an enemy in an Illusion for 305% DMG and Weaken it by 15% for 2 turns.
- **Passive · Crow Clone Feint**: After attacking, a 25% chance to dissolve into Crows, evade the next hit and leave Black Flames that Burn for 10% DMG each turn for 3 turns.
- **Ultimate · Everlasting Black Flames**: Ignite every enemy for 625% DMG and Burn for 15% DMG each turn for 3 turns.

### Limitless Sage · The Untouchable
Normal pool · Attack · Storm Hexer · Weight 28.571428571428573 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.29% (about 1 in 350; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,300 | 4,600 | 325 |
| Gold | 9,200 | 18,400 | 75,000 |
| Rainbow | 36,800 | 73,600 | 1,750,000 |
| Secret | 147,200 | 294,400 | 175,000,000 |

- **Basic · Repulsion Palm**: Strike an enemy for 105% DMG.
- **Skill · Infinity Collapse**: Fold space around random enemies with four strikes, each dealing 75% DMG.
- **Ultimate · Void Convergence**: Collapse the void for 625% DMG. The enemy takes 25% more DMG for 3 turns.
- **Aura · Infinite Pressure**: On entry, grant every ally 10% DMG.

### Ascended Golden Warrior · Prince of Pride
Normal pool · Attack · Frost Striker · Weight 40 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.40% (about 1 in 250; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,050 | 4,100 | 250 |
| Gold | 8,200 | 16,400 | 50,000 |
| Rainbow | 32,800 | 65,600 | 1,250,000 |
| Secret | 131,200 | 262,400 | 125,000,000 |

- **Basic · Royal Strike**: Strike an enemy for 105% DMG.
- **Skill · Pride Breaker**: Unleash a royal Ki blast for 300% DMG.
- **Passive · Unbroken Pride**: When below 50% HP, awaken golden Ki for 25% DMG.
- **Ultimate · Golden Ki Barrage**: Fire eight Ki blasts at random enemies for 75% DMG each.

### Lunar Reaper · Crescent Soul Blade
Normal pool · Attack · Light Hexer · Weight 44.44444444444444 · SPD 112
**Balanced** · Basic every 1.6500000000000001s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.44% (about 1 in 225; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,950 | 3,900 | 225 |
| Gold | 7,800 | 15,600 | 50,000 |
| Rainbow | 31,200 | 62,400 | 1,200,000 |
| Secret | 124,800 | 249,600 | 120,000,000 |

- **Basic · Soul Slash**: Strike an enemy for 105% DMG.
- **Skill · Crescent Severance**: Mark an enemy to take 10% more DMG for 2 turns, then sever its soul for 300% DMG.
- **Passive · Reaper's Mark**: Critical hits scar the enemy's soul with Weaken, reducing its DMG by 15% for 2 turns.
- **Ultimate · Moonless Sky**: Send five crescent blades through defense and protection for 125% DMG each.

### Time Weaver · Keeper of Hours
Normal pool · Attack · Void Striker · Weight 50 · SPD 135
**Fast** · Basic every 1s · Skill cooldown 6.5s · Ultimate at 80 energy (about 15s)
Card chance per pull: 0.50% (about 1 in 200; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,850 | 3,700 | 200 |
| Gold | 7,400 | 14,800 | 40,000 |
| Rainbow | 29,600 | 59,200 | 1,000,000 |
| Secret | 118,400 | 236,800 | 100,000,000 |

- **Basic · Marked Kunai**: Strike an enemy with a marked blade for 70% DMG.
- **Skill · Space-Time Spiral**: Blink behind the enemy for 255% DMG and evade its next hit.
- **Passive · Yellow Flash**: On entry, blink into position with 25% Ultimate charge.
- **Ultimate · Flying Seal Barrage**: Warp between enemies for five strikes at 100% DMG each and gain 20% attack speed for 2 turns.

### Storm Oracle · Voice of the Storm
Normal pool · Attack · Storm Striker · Weight 71.42857142857143 · SPD 120
**Fast** · Basic every 1.2000000000000002s · Skill cooldown 7.5s · Ultimate at 80 energy (about 15s)
Card chance per pull: 0.71% (about 1 in 140; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,600 | 3,200 | 150 |
| Gold | 6,400 | 12,800 | 30,000 |
| Rainbow | 25,600 | 51,200 | 750,000 |
| Secret | 102,400 | 204,800 | 75,000,000 |

- **Basic · Lightning Elbow**: Crash into an enemy for 70% DMG.
- **Skill · Thunder Lariat**: Drive a lightning lariat through defense and protection for 255% DMG.
- **Passive · Lightning Chakra Armor**: On entry, charge the armor for 15% attack speed and 10% less incoming DMG.
- **Ultimate · Storm Guillotine**: Drop a lightning-charged heel for 510% DMG and Weaken every enemy by 15% for 2 turns.

### Cursed Prodigy · Shadow Familiar Tamer
Normal pool · Attack · Storm Striker · Weight 83.33333333333333 · SPD 120
**Fast** · Basic every 1.2000000000000002s · Skill cooldown 7.5s · Ultimate at 80 energy (about 15s)
Card chance per pull: 0.83% (about 1 in 120; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,525 | 3,050 | 120 |
| Gold | 6,100 | 12,200 | 25,000 |
| Rainbow | 24,400 | 48,800 | 600,000 |
| Secret | 97,600 | 195,200 | 60,000,000 |

- **Basic · Cursed Edge**: Strike an enemy for 70% DMG.
- **Skill · Shadow Familiar Rush**: A shadow familiar tears into the enemy three times for 85% DMG each.
- **Passive · Ravenous Pact**: When this card defeats an opponent, its familiar grants 25% DMG for 3 turns.
- **Ultimate · Chimera Procession**: Release three familiars at random enemies, each dealing 170% DMG.

### Fist of Severance · Blood-Pact Brawler
Normal pool · Attack · Light Striker · Weight 100 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 1.00% (about 1 in 100; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,450 | 2,900 | 100 |
| Gold | 5,800 | 11,600 | 20,000 |
| Rainbow | 23,200 | 46,400 | 500,000 |
| Secret | 92,800 | 185,600 | 50,000,000 |

- **Basic · Divergent Impact**: Land a fist and its delayed cursed echo for 50% DMG each.
- **Skill · Cursed Rush**: Deliver two crushing punches for 150% DMG each, then inflict Weaken for 10% less enemy DMG over 2 turns.
- **Passive · Zone Counter**: After attacking, a 25% chance to land a cursed follow-up for 50% DMG and gain 15% critical chance for 2 turns.
- **Ultimate · Crimson Flash Barrage**: Unleash four cursed impacts for 150% DMG each and gain 20% critical chance for 2 turns.

### Iron Bastion · Living Sand Fortress
Normal pool · Attack · Void Warder · Weight 142.85714285714286 · SPD 85
**Heavy** · Basic every 2.8000000000000003s · Skill cooldown 14s · Ultimate at 135 energy (about 25s)
Card chance per pull: 1.43% (about 1 in 70; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,200 | 2,400 | 75 |
| Gold | 4,800 | 9,600 | 15,000 |
| Rainbow | 19,200 | 38,400 | 325,000 |
| Secret | 76,800 | 153,600 | 32,500,000 |

- **Basic · Sand Spear**: Drive a sand spear into an enemy for 160% DMG.
- **Skill · Sand Coffin**: Crush an enemy for 360% DMG and draw attacks for 2 turns.
- **Passive · Automatic Sand Shield**: On entry, living sand shields this card for 80% DMG and reduces incoming DMG by 15%.
- **Ultimate · Imperial Sand Mausoleum**: Bury every enemy for 805% DMG and lower their defense by 15% for 3 turns.

### Infernal Warden · Purgatory Flamekeeper
Normal pool · Attack · Flame Striker · Weight 166.66666666666666 · SPD 128
**Fast** · Basic every 1.1s · Skill cooldown 7s · Ultimate at 80 energy (about 15s)
Card chance per pull: 1.67% (about 1 in 60; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,125 | 2,250 | 60 |
| Gold | 4,500 | 9,000 | 12,000 |
| Rainbow | 18,000 | 36,000 | 300,000 |
| Secret | 72,000 | 144,000 | 30,000,000 |

- **Basic · Flame Arc**: Strike an enemy for 70% DMG.
- **Skill · Blazing Resolve**: Slash every enemy twice for 125% DMG each. Gain 20% attack speed for 2 turns and shield every ally for 30% DMG.
- **Passive · Scorching Wake**: On a hit, a 20% chance to leave Burn behind, dealing 10% DMG each turn for 3 turns.
- **Ultimate · Purgatory Dance**: Sweep every enemy for 500% DMG and inflict Burn for 10% DMG each turn for 3 turns.

### Shadow Puppeteer · Mistress of Strings
Normal pool · Attack · Storm Hexer · Weight 200 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 2.00% (about 1 in 50; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,050 | 2,100 | 50 |
| Gold | 4,200 | 8,400 | 10,000 |
| Rainbow | 16,800 | 33,600 | 250,000 |
| Secret | 67,200 | 134,400 | 25,000,000 |

- **Basic · Puppet Needle**: Launch two puppet needles for 50% DMG each.
- **Skill · Scarlet Puppet Rush**: Slash an enemy for 290% DMG and leave a needle wound that Bleeds for 10% DMG each turn for 3 turns.
- **Passive · Hidden Puppet Core**: When below 50% HP, shed the damaged shell: cleanse Burn and Freeze and evade two hits.
- **Ultimate · Hundred-Puppet Cage**: Surround every enemy with puppet blades for three strikes at 200% DMG each.

### Phantom Blade · Cloud-Step Assassin
Normal pool · Attack · Frost Striker · Weight 333.3333333333333 · SPD 120
**Fast** · Basic every 1.2000000000000002s · Skill cooldown 7.5s · Ultimate at 80 energy (about 15s)
Card chance per pull: 3.33% (about 1 in 30; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 800 | 1,600 | 30 |
| Gold | 3,200 | 6,400 | 6,000 |
| Rainbow | 12,800 | 25,600 | 150,000 |
| Secret | 51,200 | 102,400 | 15,000,000 |

- **Basic · Assassin's Cut**: Cut an enemy for 65% DMG.
- **Skill · Inverted Spear**: Pierce protection and defense for 245% DMG, then expose the enemy to 10% more DMG for 2 turns.
- **Passive · Heavenly Physique**: On entry, trust physical instinct to evade the next two hits.
- **Ultimate · Soul-Splitting Ambush**: Three ruthless cuts ignore defense and protection for 165% DMG each.

### Starfall Witch · Mistress of Hounds
Normal pool · Attack · Void Hexer · Weight 400 · SPD 100
**Heavy** · Basic every 2.4000000000000004s · Skill cooldown 12.5s · Ultimate at 135 energy (about 25s)
Card chance per pull: 4.00% (about 1 in 25; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 750 | 1,500 | 25 |
| Gold | 3,000 | 6,000 | 5,000 |
| Rainbow | 12,000 | 24,000 | 125,000 |
| Secret | 48,000 | 96,000 | 12,500,000 |

- **Basic · Shadow Fang**: Strike an enemy for 155% DMG.
- **Skill · Hound Pursuit**: Three shadow hounds pursue random enemies, each dealing 115% DMG.
- **Passive · Shadow Bind**: On a hit, a 20% chance for the hounds to Weaken the enemy by 15% for 2 turns.
- **Ultimate · Chimera Garden**: Drown the enemy in shadows, lowering defense by 15% for 3 turns before dealing 780% DMG.

### Titan Warder · Armored Colossus
Normal pool · Attack · Flame Warder · Weight 454.54545454545456 · SPD 95
**Heavy** · Basic every 2.5500000000000003s · Skill cooldown 13s · Ultimate at 135 energy (about 25s)
Card chance per pull: 4.55% (about 1 in 22; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 725 | 1,450 | 23 |
| Gold | 2,900 | 5,800 | 4,000 |
| Rainbow | 11,600 | 23,200 | 120,000 |
| Secret | 46,400 | 92,800 | 12,000,000 |

- **Basic · Colossus Fist**: Strike an enemy for 155% DMG.
- **Skill · Wallbreaker Rush**: Draw enemy attacks for 2 turns, then charge for 350% DMG.
- **Passive · Armored Advance**: On entry, harden this card's armor to reduce incoming DMG by 15%.
- **Ultimate · Crushing Footfall**: Crush every enemy for 775% DMG.

### Solar Blade · Dawn Swordsman
Normal pool · Attack · Flame Striker · Weight 500 · SPD 100
**Heavy** · Basic every 2.4000000000000004s · Skill cooldown 12.5s · Ultimate at 135 energy (about 25s)
Card chance per pull: 5.00% (about 1 in 20; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 700 | 1,400 | 20 |
| Gold | 2,800 | 5,600 | 4,000 |
| Rainbow | 11,200 | 22,400 | 100,000 |
| Secret | 44,800 | 89,600 | 10,000,000 |

- **Basic · Sunlit Edge**: Strike an enemy for 155% DMG.
- **Skill · Flowing Sun**: Cut through an enemy twice, dealing 175% DMG with each slash.
- **Passive · Ember Breathing**: Critical hits ignite the enemy with Burn, dealing 10% DMG each turn for 3 turns.
- **Ultimate · Dance of Dawn**: Unleash a 775% DMG sun slash and inflict Burn for 5% DMG each turn for 3 turns.

### Celestial Strategist · Wisteria Tactician
Normal pool · Attack · Light Hexer · Weight 621.828 · SPD 125
**Fast** · Basic every 1.1500000000000001s · Skill cooldown 7s · Ultimate at 80 energy (about 15s)
Card chance per pull: 6.22% (about 1 in 16; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 500 | 1,000 | 15 |
| Gold | 2,000 | 4,000 | 3,250 |
| Rainbow | 8,000 | 16,000 | 80,000 |
| Secret | 32,000 | 64,000 | 8,000,000 |

- **Basic · Butterfly Thrust**: Pierce an enemy with two swift thrusts for 35% DMG each.
- **Skill · Wisteria Sting**: Strike for 245% DMG and open a toxin-laced wound that Bleeds for 10% DMG each turn for 3 turns.
- **Passive · Wisteria Dose**: Critical hits have a 50% chance to inject another dose: inflict Bleed for 10% DMG each turn for 2 turns and Weaken by 10% for 2 turns.
- **Ultimate · Centipede Dance**: Zigzag through an enemy's defense and protection with five thrusts for 100% DMG each.

### Thunder Flash · Sleeping Lightning
Normal pool · Attack · Storm Striker · Weight 932.742 · SPD 130
**Fast** · Basic every 1.05s · Skill cooldown 7s · Ultimate at 80 energy (about 15s)
Card chance per pull: 9.33% (about 1 in 11; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 470 | 940 | 10 |
| Gold | 1,880 | 3,760 | 2,250 |
| Rainbow | 7,520 | 15,040 | 50,000 |
| Secret | 30,080 | 60,160 | 5,000,000 |

- **Basic · Lightning Draw**: Draw and slash for 65% DMG.
- **Skill · Thunderclap Dash**: Flash through an enemy for 240% DMG and accelerate by 15% for 2 turns.
- **Passive · Trance Reflex**: When below 50% HP, enter a lightning trance: evade the next hit and gain 25% attack speed.
- **Ultimate · Sixfold Lightning**: Cross the battlefield with six lightning slashes for 80% DMG each.

### Spirit Weaver · Soul-Thread Medic
Normal pool · Attack · Void Mender · Weight 994.9248 · SPD 115
**Balanced** · Basic every 1.6s · Skill cooldown 9.5s · Ultimate at 100 energy (about 19s)
Card chance per pull: 9.95% (about 1 in 10; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 450 | 900 | 10 |
| Gold | 1,800 | 3,600 | 2,000 |
| Rainbow | 7,200 | 14,400 | 50,000 |
| Secret | 28,800 | 57,600 | 5,000,000 |

- **Basic · Spirit Thread**: Send out two soul threads, each dealing 50% DMG to a random enemy.
- **Skill · Soul Rejection**: Weave a shield worth 80% DMG around every ally.
- **Passive · Thread of Renewal**: After attacking, a 25% chance to mend this card for 15% of its DMG and remove a Burn or Freeze.

### Lotus Blossom · Hundred-Healing Medic
Normal pool · Attack · Light Mender · Weight 994.9248 · SPD 105
**Balanced** · Basic every 1.8s · Skill cooldown 10.5s · Ultimate at 100 energy (about 19s)
Card chance per pull: 9.95% (about 1 in 10; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 455 | 910 | 10 |
| Gold | 1,820 | 3,640 | 2,000 |
| Rainbow | 7,280 | 14,560 | 50,000 |
| Secret | 29,120 | 58,240 | 5,000,000 |

- **Basic · Chakra Fist**: Drive a Chakra-charged punch into an enemy for 100% DMG.
- **Skill · Cherry Blossom Clash**: Shatter the ground for 280% DMG and mend the lowest-HP ally for 40% DMG.
- **Passive · Mitotic Regeneration**: When below 50% HP, release stored Chakra to cleanse Burn and Freeze and recover 25% HP.
- **Ultimate · Hundred-Seal Release**: Strike for 585% DMG and restore 60% DMG as HP to every ally.

## Normal pool: Support cards
### Eight Trigrams Seal · Caged Beast Talisman
Normal pool · Support · Cosmic Mender · Weight 20 · SPD 0
Card chance per pull: 0.20% (about 1 in 500; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 55% | 500 |
| Gold | 70% | 100,000 |
| Rainbow | 85% | 2,500,000 |
| Secret | 100% | 250,000,000 |

- **Passive · Crimson Chakra Cloak**: Upon a fatal blow, the supported card releases its sealed Chakra and returns at 55% HP.

### Cursed Ocular Seal · Hypnotic Crow Crest
Normal pool · Support · Frost Mender · Weight 28.571428571428573 · SPD 0
Card chance per pull: 0.29% (about 1 in 350; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 15% | 325 |
| Gold | 20% | 75,000 |
| Rainbow | 25% | 1,750,000 |
| Secret | 30% | 175,000,000 |

- **Passive · Illusion of Crows**: The supported card's Skill or Ultimate has a 25% chance to summon Crows. They inflict Weaken for 15% less enemy DMG over 2 turns, and Black Flames Burn for 10% DMG each turn for 3 turns.

### Blink Kunai Seal · Marked Space-Time Blade
Normal pool · Support · Void Mender · Weight 44.44444444444444 · SPD 0
Card chance per pull: 0.44% (about 1 in 225; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 25% | 225 |
| Gold | 30% | 50,000 |
| Rainbow | 40% | 1,200,000 |
| Secret | 45% | 120,000,000 |

- **Passive · Blink Reserve**: On entry, the supported card gains 25% Ultimate charge.

### Binding Blood Vow · Cursed Counter-Pact
Normal pool · Support · Light Warder · Weight 76.92307692307692 · SPD 0
Card chance per pull: 0.77% (about 1 in 130; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 15% | 125 |
| Gold | 20% | 25,000 |
| Rainbow | 25% | 650,000 |
| Secret | 30% | 65,000,000 |

- **Passive · Severing Counter**: After an enemy attack, the supported card has a 25% chance to return 15% of the DMG taken as a counterstrike.

### Stormheart Mantle · Siphoning Lightning Armor
Normal pool · Support · Storm Warder · Weight 90.9090909090909 · SPD 0
Card chance per pull: 0.91% (about 1 in 110; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 10% | 120 |
| Gold | 15% | 22,500 |
| Rainbow | 20% | 600,000 |
| Secret | 25% | 60,000,000 |

- **Passive · Stormheart Siphon**: When the supported card deals direct DMG, a 25% chance to drain 10% of that DMG as HP.

### Gourd of Living Sand · Desert Seal Vessel
Normal pool · Support · Void Warder · Weight 153.84615384615384 · SPD 0
Card chance per pull: 1.54% (about 1 in 65; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 25% | 65 |
| Gold | 30% | 12,500 |
| Rainbow | 40% | 325,000 |
| Secret | 45% | 32,500,000 |

- **Passive · Living Sand Armor**: On entry, sand shields the supported card for 25% of its max HP.

### Chakra Puppet Threads · Reversal String Technique
Normal pool · Support · Storm Mender · Weight 181.8181818181818 · SPD 0
Card chance per pull: 1.82% (about 1 in 55; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 15% | 60 |
| Gold | 20% | 12,000 |
| Rainbow | 25% | 300,000 |
| Secret | 30% | 30,000,000 |

- **Passive · Puppet Reversal**: When the supported card receives Burn or Freeze, sever the strings: cleanse those effects and reflect them onto the attacker. Reflected Burn deals 15% DMG for 3 turns.

### Heavenly Restriction · Assassin's Physical Pact
Normal pool · Support · Frost Warder · Weight 400 · SPD 0
Card chance per pull: 4.00% (about 1 in 25; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 10% | 25 |
| Gold | 15% | 5,000 |
| Rainbow | 20% | 125,000 |
| Secret | 25% | 12,500,000 |

- **Passive · Cloud-Step Feint**: When attacked, the supported card has a 10% chance to evade. Each successful feint inflicts Weaken, reducing the attacker's DMG by 10% for 1 turn.

### First Form: Thunderclap · Lightning Draw Stance
Normal pool · Support · Storm Striker · Weight 746.1936 · SPD 0
Card chance per pull: 7.46% (about 1 in 13; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 20% | 13 |
| Gold | 25% | 2,500 |
| Rainbow | 30% | 65,000 |
| Secret | 35% | 6,500,000 |

- **Passive · Thunder Breathing**: On entry, the supported card gains 20% attack speed for 3 turns.

### Wisteria Antidote Vial · Butterfly Medical Extract
Normal pool · Support · Light Mender · Weight 932.742 · SPD 0
Card chance per pull: 9.33% (about 1 in 11; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 20% | 10 |
| Gold | 25% | 2,250 |
| Rainbow | 30% | 50,000 |
| Secret | 35% | 5,000,000 |

- **Passive · Wisteria Antidote**: When the supported card defeats an opponent, recover 20% of its max HP.

### Diamond Mitotic Seal · Forbidden Medical Crest
Normal pool · Support · Light Mender · Weight 994.9248 · SPD 0
Card chance per pull: 9.95% (about 1 in 10; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 20% | 10 |
| Gold | 25% | 2,000 |
| Rainbow | 30% | 50,000 |
| Secret | 35% | 5,000,000 |

- **Passive · Hundred-Petal Renewal**: When below 50% HP, the supported card cleanses Burn and Freeze and recovers 20% of its max HP.

## Boss cards
### Tailed Beast Calamity · The Ember Fox
Boss card · unlocks after beating kurogane on Normal · Attack · Flame Hexer · Weight 25 · SPD 102
**Heavy** · Basic every 2.35s · Skill cooldown 12s · Ultimate at 135 energy (about 25s)
Card chance per pull: 0.25% (about 1 in 400; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,650 | 5,300 | 400 |
| Gold | 10,600 | 21,200 | 80,000 |
| Rainbow | 42,400 | 84,800 | 2,000,000 |
| Secret | 169,600 | 339,200 | 200,000,000 |

- **Basic · Chakra Claw**: Strike an enemy for 170% DMG.
- **Skill · Chakra Eruption**: Burst through the enemy for 380% DMG. Searing Chakra inflicts Burn for 10% DMG each turn for 3 turns.
- **Passive · Crimson Cloak**: When below 50% HP, unleash the beast's Chakra for 25% DMG.
- **Ultimate · Beast Bomb Barrage**: Launch six Beast Bombs at random enemies for 140% DMG each.

### Galactic Emperor · The Frost Tyrant
Boss card · unlocks after beating rimeveil on Normal · Attack · Frost Hexer · Weight 20 · SPD 98
**Heavy** · Basic every 2.45s · Skill cooldown 12.5s · Ultimate at 135 energy (about 25s)
Card chance per pull: 0.20% (about 1 in 500; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,800 | 5,600 | 500 |
| Gold | 11,200 | 22,400 | 100,000 |
| Rainbow | 44,800 | 89,600 | 2,500,000 |
| Secret | 179,200 | 358,400 | 250,000,000 |

- **Basic · Death Ray**: Strike an enemy for 170% DMG.
- **Skill · Emperor's Command**: Deal 380% DMG and suppress every enemy's attack speed by 15% for 2 turns.
- **Passive · Golden Tyranny**: When this card defeats an opponent, recover 15% HP.
- **Ultimate · Planet Breaker**: Erase an enemy with a 850% DMG blast that ignores defense.

### Mirror Flower Overlord · The Hollow Betrayer
Boss card · unlocks after beating vex on Normal · Attack · Void Hexer · Weight 15.384615384615385 · SPD 104
**Heavy** · Basic every 2.3000000000000003s · Skill cooldown 12s · Ultimate at 135 energy (about 25s)
Card chance per pull: 0.15% (about 1 in 650; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,000 | 6,000 | 650 |
| Gold | 12,000 | 24,000 | 125,000 |
| Rainbow | 48,000 | 96,000 | 3,250,000 |
| Secret | 192,000 | 384,000 | 325,000,000 |

- **Basic · Illusion Cut**: Strike an enemy for 170% DMG.
- **Skill · Shattered Reflection**: Deal 385% DMG and expose a false opening, lowering defense by 15% for 3 turns.
- **Passive · Perfect Hypnosis**: On entry, create two Illusions to evade incoming hits.
- **Ultimate · False Heaven**: Strike through four false realities for 215% DMG each. Every enemy takes 15% more DMG for 3 turns.

### Demon Progenitor · The Thousand-Year Storm
Boss card · unlocks after beating tenrai on Normal · Attack · Storm Striker · Weight 12.5 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Card chance per pull: 0.12% (about 1 in 800; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,250 | 6,500 | 800 |
| Gold | 13,000 | 26,000 | 150,000 |
| Rainbow | 52,000 | 104,000 | 4,000,000 |
| Secret | 208,000 | 416,000 | 400,000,000 |

- **Basic · Blood Whip**: Strike an enemy for 105% DMG.
- **Skill · Thorned Blood**: Four blood thorns pierce random enemies for 75% DMG each.
- **Passive · Demon Rebirth**: When below 50% HP, cleanse Burn and Freeze and regenerate 25% of max HP.
- **Aura · Progenitor's Gift**: On entry, share cursed blood for 10% DMG on every ally.
- **Ultimate · Black Blood Tempest**: Engulf every enemy in a 630% DMG blood storm.

## Celestial sky cards (only while their sky is active)
### Ultra Instinct Goku · Dragon Ball
Sky card · Limitbreak Skies · Attack · Light Striker · Weight 1 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Chance: 1 in 650 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,250 | 6,500 | 650 |
| Gold | 13,000 | 26,000 | 125,000 |
| Rainbow | 52,000 | 104,000 | 3,250,000 |
| Secret | 208,000 | 416,000 | 325,000,000 |

- **Basic · Instinct Rush**: Strike for 105% DMG.
- **Skill · Autonomous Counter**: Strike for 310% DMG, then evade the next enemy hit.
- **Ultimate · Supreme Kamehameha**: Unleash 630% DMG on every enemy.
- **Passive · A Body Beyond Thought**: On entry, evade the next two hits.

### Ultra Ego Vegeta · Dragon Ball
Sky card · Limitbreak Skies · Attack · Void Striker · Weight 1 · SPD 95
**Heavy** · Basic every 2.5500000000000003s · Skill cooldown 13s · Ultimate at 135 energy (about 25s)
Chance: 1 in 500 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,050 | 6,100 | 500 |
| Gold | 12,200 | 24,400 | 100,000 |
| Rainbow | 48,800 | 97,600 | 2,500,000 |
| Secret | 195,200 | 390,400 | 250,000,000 |

- **Basic · Destroyer's Blow**: Strike for 170% DMG.
- **Skill · Destruction Sphere**: Strike for 380% DMG and reduce the target's defense by 25% for 2 turns.
- **Ultimate · Final Destruction**: Unleash 850% DMG on every enemy.
- **Passive · Pride in the Pain**: When below 50% HP, gain 35% DMG for the rest of the battle.

### Blue Gogeta · Dragon Ball
Sky card · Limitbreak Skies · Attack · Cosmic Striker · Weight 1 · SPD 105
**Balanced** · Basic every 1.8s · Skill cooldown 10.5s · Ultimate at 100 energy (about 19s)
Chance: 1 in 400 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,900 | 5,800 | 400 |
| Gold | 11,600 | 23,200 | 80,000 |
| Rainbow | 46,400 | 92,800 | 2,000,000 |
| Secret | 185,600 | 371,200 | 200,000,000 |

- **Basic · Meteor Combination**: Strike for 105% DMG.
- **Skill · Stardust Fall**: Strike four times for 75% DMG per hit.
- **Ultimate · Stardust Breaker**: Release the finishing blow for 625% DMG.
- **Passive · Perfect Fusion**: On entry, gain 25% critical chance for 3 turns.

### Full Power Broly · Dragon Ball
Sky card · Limitbreak Skies · Attack · Storm Striker · Weight 1 · SPD 90
**Heavy** · Basic every 2.6500000000000004s · Skill cooldown 13.5s · Ultimate at 135 energy (about 25s)
Chance: 1 in 300 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,750 | 5,500 | 300 |
| Gold | 11,000 | 22,000 | 60,000 |
| Rainbow | 44,000 | 88,000 | 1,500,000 |
| Secret | 176,000 | 352,000 | 150,000,000 |

- **Basic · Raging Impact**: Strike for 170% DMG.
- **Skill · Gigantic Roar**: Strike for 375% DMG and Weaken the target by 15% for 2 turns.
- **Ultimate · Gigantic Catastrophe**: Strike random enemies five times for 170% DMG each.
- **Passive · Uncontained Rage**: When below 50% HP, gain 35% DMG for the rest of the battle.

### Horn of Salvation Ichigo · Bleach
Sky card · Soulfall · Attack · Void Striker · Weight 1 · SPD 105
**Balanced** · Basic every 1.8s · Skill cooldown 10.5s · Ultimate at 100 energy (about 19s)
Chance: 1 in 600 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,500 | 7,000 | 600 |
| Gold | 14,000 | 28,000 | 120,000 |
| Rainbow | 56,000 | 112,000 | 3,000,000 |
| Secret | 224,000 | 448,000 | 300,000,000 |

- **Basic · Zangetsu**: Strike for 105% DMG.
- **Skill · Gran Rey Getsuga**: Strike for 310% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · True Bankai**: Release the finishing blow for 630% DMG.
- **Passive · Hollow Resolve**: When below 50% HP, gain 25% attack speed for 3 turns.

### Hogyoku Aizen · Bleach
Sky card · Soulfall · Attack · Void Striker · Weight 1 · SPD 100
**Heavy** · Basic every 2.4000000000000004s · Skill cooldown 12.5s · Ultimate at 135 energy (about 25s)
Chance: 1 in 800 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,750 | 7,500 | 800 |
| Gold | 15,000 | 30,000 | 150,000 |
| Rainbow | 60,000 | 120,000 | 4,000,000 |
| Secret | 240,000 | 480,000 | 400,000,000 |

- **Basic · Silent Cut**: Strike for 170% DMG.
- **Skill · Complete Hypnosis**: Strike for 385% DMG and Weaken the target by 15% for 2 turns.
- **Ultimate · Black Coffin**: Unleash 860% DMG on every enemy.
- **Passive · Beyond Perception**: After attacking, a 25% chance to evade the next hit and slow the target by 20% for 2 turns.

### Bankai Yamamoto · Bleach
Sky card · Soulfall · Attack · Flame Striker · Weight 1 · SPD 90
**Heavy** · Basic every 2.6500000000000004s · Skill cooldown 13.5s · Ultimate at 135 energy (about 25s)
Chance: 1 in 1,000 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,000 | 8,000 | 1,000 |
| Gold | 16,000 | 32,000 | 200,000 |
| Rainbow | 64,000 | 128,000 | 5,000,000 |
| Secret | 256,000 | 512,000 | 500,000,000 |

- **Basic · Ashen Edge**: Strike for 175% DMG.
- **Skill · Zanka no Tachi**: Strike for 385% DMG and Burn for 25% DMG each turn for 3 turns.
- **Ultimate · Heaven and Earth in Ash**: Unleash 865% DMG on every enemy.
- **Passive · Fifteen Million Degrees**: After attacking, a 25% chance to Burn the target for 15% DMG each turn for 2 turns.

### The Almighty Yhwach · Bleach
Sky card · Soulfall · Attack · Cosmic Striker · Weight 1 · SPD 95
**Heavy** · Basic every 2.5500000000000003s · Skill cooldown 13s · Ultimate at 135 energy (about 25s)
Chance: 1 in 1,250 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,300 | 8,600 | 1,250 |
| Gold | 17,200 | 34,400 | 250,000 |
| Rainbow | 68,800 | 137,600 | 6,250,000 |
| Secret | 275,200 | 550,400 | 625,000,000 |

- **Basic · Reishi Arrow**: Strike for 175% DMG.
- **Skill · Future Severance**: Deal 390% DMG and slow the target by 25% for 2 turns.
- **Ultimate · Auswahlen**: Unleash 870% DMG on every enemy.
- **Passive · The Future I Choose**: When below 50% HP, evade the next two hits.

### Awakened Gojo · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Cosmic Striker · Weight 1 · SPD 110
**Balanced** · Basic every 1.7000000000000002s · Skill cooldown 10s · Ultimate at 100 energy (about 19s)
Chance: 1 in 1,000 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,050 | 8,100 | 1,000 |
| Gold | 16,200 | 32,400 | 200,000 |
| Rainbow | 64,800 | 129,600 | 5,000,000 |
| Secret | 259,200 | 518,400 | 500,000,000 |

- **Basic · Limitless Impact**: Strike for 110% DMG.
- **Skill · Hollow Purple**: Strike for 310% DMG, then evade the next enemy hit.
- **Ultimate · Unlimited Void**: Unleash 635% DMG on every enemy.
- **Passive · Infinity**: On entry, evade the next two hits.

### True Form Sukuna · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Void Striker · Weight 1 · SPD 100
**Heavy** · Basic every 2.4000000000000004s · Skill cooldown 12.5s · Ultimate at 135 energy (about 25s)
Chance: 1 in 1,250 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,300 | 8,600 | 1,250 |
| Gold | 17,200 | 34,400 | 250,000 |
| Rainbow | 68,800 | 137,600 | 6,250,000 |
| Secret | 275,200 | 550,400 | 625,000,000 |

- **Basic · Dismantle**: Strike for 175% DMG.
- **Skill · Cleave**: Strike for 390% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · Malevolent Shrine**: Strike every enemy three times for 290% DMG per hit.
- **Passive · Binding Vow**: On entry, gain 25% DMG for the rest of the battle.

### Yuta & Rika · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Light Striker · Weight 1 · SPD 100
**Heavy** · Basic every 2.4000000000000004s · Skill cooldown 12.5s · Ultimate at 135 energy (about 25s)
Chance: 1 in 800 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,750 | 7,500 | 800 |
| Gold | 15,000 | 30,000 | 150,000 |
| Rainbow | 60,000 | 120,000 | 4,000,000 |
| Secret | 240,000 | 480,000 | 400,000,000 |

- **Basic · Cursed Blade**: Strike for 170% DMG.
- **Skill · Cursed Speech**: Strike for 385% DMG and Weaken the target by 15% for 2 turns.
- **Ultimate · Pure Love**: Release the finishing blow for 860% DMG.
- **Passive · Reverse Cursed Technique**: After a critical hit, heal for 20% of this card's DMG and cleanse one Burn or Freeze.

### Toji — Sorcerer Killer · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Void Striker · Weight 1 · SPD 115
**Balanced** · Basic every 1.6s · Skill cooldown 9.5s · Ultimate at 100 energy (about 19s)
Chance: 1 in 600 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,500 | 7,000 | 600 |
| Gold | 14,000 | 28,000 | 120,000 |
| Rainbow | 56,000 | 112,000 | 3,000,000 |
| Secret | 224,000 | 448,000 | 300,000,000 |

- **Basic · Split Soul Slash**: Strike for 105% DMG.
- **Skill · Inverted Spear**: Strike for 310% DMG and reduce the target's defense by 25% for 2 turns.
- **Ultimate · Chain of a Thousand Miles**: Strike random enemies five times for 125% DMG each.
- **Passive · Heavenly Restriction**: On entry, gain 25% attack speed for the rest of the battle.

### Moon Breathing Kokushibo · Demon Slayer
Sky card · Blood Moon · Attack · Void Striker · Weight 1 · SPD 105
**Balanced** · Basic every 1.8s · Skill cooldown 10.5s · Ultimate at 100 energy (about 19s)
Chance: 1 in 2,000 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 5,550 | 11,100 | 2,000 |
| Gold | 22,200 | 44,400 | 400,000 |
| Rainbow | 88,800 | 177,600 | 10,000,000 |
| Secret | 355,200 | 710,400 | 1,000,000,000 |

- **Basic · Crescent Slash**: Strike for 110% DMG.
- **Skill · Moonlit Calamity**: Strike for 315% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · Tenman Crescent**: Unleash 640% DMG on every enemy.
- **Passive · Transparent World**: On entry, gain 20% critical chance and reduce the target's defense by 20% for 3 turns.

### Compass Needle Akaza · Demon Slayer
Sky card · Blood Moon · Attack · Storm Striker · Weight 1 · SPD 115
**Balanced** · Basic every 1.6s · Skill cooldown 9.5s · Ultimate at 100 energy (about 19s)
Chance: 1 in 1,200 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,800 | 9,600 | 1,200 |
| Gold | 19,200 | 38,400 | 250,000 |
| Rainbow | 76,800 | 153,600 | 6,000,000 |
| Secret | 307,200 | 614,400 | 600,000,000 |

- **Basic · Destructive Fist**: Strike for 110% DMG.
- **Skill · Disorder**: Strike four times for 80% DMG per hit.
- **Ultimate · Blue Silver Chaotic Afterglow**: Strike every enemy three times for 210% DMG per hit.
- **Passive · Compass Needle**: After attacking, a 25% chance to evade the next hit and gain 15% critical chance for 2 turns.

### Frozen Lotus Doma · Demon Slayer
Sky card · Blood Moon · Attack · Frost Striker · Weight 1 · SPD 95
**Heavy** · Basic every 2.5500000000000003s · Skill cooldown 13s · Ultimate at 135 energy (about 25s)
Chance: 1 in 1,500 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 5,150 | 10,300 | 1,500 |
| Gold | 20,600 | 41,200 | 300,000 |
| Rainbow | 82,400 | 164,800 | 7,500,000 |
| Secret | 329,600 | 659,200 | 750,000,000 |

- **Basic · Lotus Fan**: Strike for 175% DMG.
- **Skill · Frozen Lotus**: Deal 390% DMG and slow the target by 25% for 2 turns.
- **Ultimate · Water Lily Bodhisattva**: Unleash 875% DMG on every enemy.
- **Passive · Frozen Blood**: After attacking, a 25% chance to Weaken the target by 20% for 2 turns and shield this card for 25% of its DMG.

### Demon King Muzan · Demon Slayer
Sky card · Blood Moon · Attack · Void Striker · Weight 1 · SPD 105
**Balanced** · Basic every 1.8s · Skill cooldown 10.5s · Ultimate at 100 energy (about 19s)
Chance: 1 in 2,500 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 6,000 | 12,000 | 2,500 |
| Gold | 24,000 | 48,000 | 500,000 |
| Rainbow | 96,000 | 192,000 | 12,500,000 |
| Secret | 384,000 | 768,000 | 1,250,000,000 |

- **Basic · Whip of Blood**: Strike for 110% DMG.
- **Skill · Black Blood Thorns**: Strike for 315% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · Calamity of Blood**: Unleash 645% DMG on every enemy.
- **Passive · Demon King's Regeneration**: When below 50% HP, heal for 50% of this card's DMG.

## Bosses
- **Tailed Beast Calamity** · The Ember Fox (World 1, Ember Village): Normal: HP 60,000, recommended Attack rating 22,500; Hard: HP 220,000, recommended Attack rating 69,540; Nightmare: HP 750,000, recommended Attack rating 142,800
- **Galactic Emperor** · The Frost Tyrant (World 2, Frostfang Peaks): Normal: HP 900,000, recommended Attack rating 200,400; Hard: HP 2,800,000, recommended Attack rating 736,800; Nightmare: HP 7,500,000, recommended Attack rating 1,545,600
- **Mirror Flower Overlord** · The Hollow Betrayer (World 3, Neon Abyss): Normal: HP 4,500,000, recommended Attack rating 1,216,800; Hard: HP 12,000,000, recommended Attack rating 2,438,400; Nightmare: HP 32,000,000, recommended Attack rating 7,584,000
- **Demon Progenitor** · The Thousand-Year Storm (World 4, Stormspire Isle): Normal: HP 14,000,000, recommended Attack rating 2,217,600; Hard: HP 45,000,000, recommended Attack rating 8,150,400; Nightmare: HP 125,000,000, recommended Attack rating 16,512,000

**Notes on the bosses (the user's 2026-10-30 HP table):** every fight is winnable. Each recommended rating is the
intended squad's Attack rating; medians from the battle simulator:
  - World 1: Normal four Base starters (~57 s), Hard 2 Gold + 2 Base (~69 s), Nightmare 4 Gold (~80 s)
  - World 2: Normal 4 Gold (~68 s), Hard 2 Rainbow + 2 Gold (~69 s), Nightmare 4 Rainbow (~75 s)
  - World 3: Normal 2 Rainbow + 2 Gold (~72 s), Hard 4 Rainbow (~78 s), Nightmare 1 Secret + 3 Rainbow (~98 s, the
    strongest such squad: Secret Muzan with Rainbow Kokushibo / Doma / Akaza)
  - World 4: Normal 4 Rainbow (~83 s), Hard 2 Secret + 2 Rainbow (~80 s), Nightmare 4 Secret Blood Moon cards
    (~119 s chase)
