# Anime Card Roll: every card, stat and chance (2026-10-30)

Generated from the game data (`src/shared/Cards.luau`, `CelestialCards.luau`, `Weather.luau`, `Borders.luau`,
`Bosses.luau`) after the rarity / bulk-pack / boss-HP pass. Stats are at 0 stars with no mastery, traits or
buffs. How the whole game works is in `CLAUDE.md`.

## How a roll works
1. The game picks a **card** by its chance (Weight out of 10,000).
   - The pool is every normal card, plus each boss card after that boss's first Normal clear.
   - The Card Packs collection can narrow it.
2. It rolls a **border**: Gold, Rainbow and Secret multiply ATK / HP by 4x / 16x / 64x. Luck raises these.
3. The **rarity number** is how many pulls one of that card at that border takes on average at 1x luck. For
   example, Autonomous God State Secret is 1 in 1,000,000,000.
4. Pulls of 1 in 10,000,000 or rarer post a chat line. 1 in 1,000,000,000+ posts a BILLION PULL line.

## Roll Packs
- Opening any number of packs is one instant server pass, whether that's 100 x 1,000-roll packs (100,000 pulls)
  or a million.
- You get one combined summary: total cards, the five rarest first, then every card / border stack.

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
- Each card has its own chance per pull. Luck raises it by 15% of the luck bonus (25x luck = 4.6x).

| Sky | Any of its 4 cards, per pull (1x luck) | Rolling the whole sky by hand (~250 rolls) | 1,000 pulls | Expected from 100,000 pack pulls |
| --- | --- | --- | --- | --- |
| Limitbreak Skies | 0.19% | about 38% | about 85% | about 190 |
| Soulfall | 0.080% | about 18% | about 55% | about 80 |
| Cursed Night | 0.079% | about 18% | about 54% | about 79 |
| Blood Moon | 0.027% | about 6% | about 23% | about 27 |

## Border odds (1x luck)
| Border | Stat multiplier | Chance per pull |
| --- | --- | --- |
| Base | 1x | everything else |
| Gold | 4x | 0.5000% (1 in 200) |
| Rainbow | 16x | 0.0200% (1 in 5,000) |
| Secret | 64x | 0.0002% (1 in 500,000) |

## Normal pool: Attack cards (strongest base first)
### Autonomous God State · The Silver Instinct
Normal pool · Attack · Cosmic Striker · Weight 5 · SPD 115
Card chance per pull: 0.05% (about 1 in 1,990; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,600 | 5,200 | 2,000 |
| Gold | 10,400 | 20,800 | 400,000 |
| Rainbow | 41,600 | 83,200 | 10,000,000 |
| Secret | 166,400 | 332,800 | 1,000,000,000 |

- **Basic · Instinct Strike**: Strike an enemy for 120% DMG.
- **Skill · Afterimage Assault** (every 3 actions): Disappear beyond sight, then strike for 300% DMG.
- **Ultimate · Limit-Breaking Fist**: Break through defense and protection with a 550% DMG strike.
- **Signature · Perfect Instinct** (every 5 actions): After every 5 attacks, a 50% chance to land a 125% DMG afterimage strike and evade the next enemy hit.

### Nine-Tails Sovereign · Vessel of the Nine Tails
Normal pool · Attack · Cosmic Striker · Weight 5 · SPD 115
Card chance per pull: 0.05% (about 1 in 1,990; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,700 | 5,400 | 2,000 |
| Gold | 10,800 | 21,600 | 400,000 |
| Rainbow | 43,200 | 86,400 | 10,000,000 |
| Secret | 172,800 | 345,600 | 1,000,000,000 |

- **Basic · Chakra Palm**: Strike an enemy for 100% DMG.
- **Skill · Planetary Chakra Spiral** (every 3 actions): Drive three orbiting Chakra spheres into an enemy for 110% DMG each.
- **Passive · Crimson Lifeline**: When below 50% HP, draw on the sealed beast: recover 35% HP and gain 20% DMG, but the cloak prevents further healing.
- **Ultimate · Sovereign Beast Cataclysm**: Detonate a Beast Bomb for 200% DMG on every enemy, then land a 300% DMG Chakra strike on the chosen target.

### Crimson Scourge · King of Malice
Normal pool · Attack · Flame Hexer · Weight 6.6667 · SPD 105
Card chance per pull: 0.07% (about 1 in 1,493; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,400 | 4,800 | 1,500 |
| Gold | 9,600 | 19,200 | 300,000 |
| Rainbow | 38,400 | 76,800 | 7,500,000 |
| Secret | 153,600 | 307,200 | 750,000,000 |

- **Basic · Rending Cut**: Strike an enemy for 100% DMG.
- **Skill · Spatial Severance** (every 3 actions): Cut through the enemy's defenses by 15% for 2 turns, then deal 250% DMG.
- **Passive · Cursed Incision**: Critical hits carve a Bleed into the enemy, dealing 15% DMG each turn for 3 turns.
- **Ultimate · Malevolent Barrage**: Rain down six cursed slashes on random enemies, each dealing 130% DMG.
- **Aura · Shrine of Malice**: On entry, every ally gains 10% DMG, but the shrine makes them take 10% more DMG.

### Dream Reaper · Mirror of Hypnosis
Normal pool · Attack · Frost Hexer · Weight 6.6667 · SPD 110
Card chance per pull: 0.07% (about 1 in 1,493; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,200 | 4,400 | 1,500 |
| Gold | 8,800 | 17,600 | 300,000 |
| Rainbow | 35,200 | 70,400 | 7,500,000 |
| Secret | 140,800 | 281,600 | 750,000,000 |

- **Basic · Crow Shuriken**: Send two crow-feather blades into an enemy for 50% DMG each.
- **Skill · Crimson Illusion** (every 3 actions): Trap an enemy in an Illusion for 220% DMG and Weaken it by 15% for 2 turns.
- **Passive · Crow Clone Feint**: After attacking, a 25% chance to dissolve into Crows, evade the next hit and leave Black Flames that Burn for 10% DMG each turn for 3 turns.
- **Ultimate · Everlasting Black Flames**: Ignite every enemy for 170% DMG and Burn for 15% DMG each turn for 3 turns.

### Limitless Sage · The Untouchable
Normal pool · Attack · Storm Hexer · Weight 6.6667 · SPD 110
Card chance per pull: 0.07% (about 1 in 1,493; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,300 | 4,600 | 1,500 |
| Gold | 9,200 | 18,400 | 300,000 |
| Rainbow | 36,800 | 73,600 | 7,500,000 |
| Secret | 147,200 | 294,400 | 750,000,000 |

- **Basic · Repulsion Palm**: Strike an enemy for 120% DMG.
- **Skill · Infinity Collapse** (every 3 actions): Fold space around random enemies with four strikes, each dealing 100% DMG.
- **Ultimate · Void Convergence**: Collapse the void for 500% DMG. The enemy takes 25% more DMG for 3 turns.
- **Aura · Infinite Pressure**: On entry, grant every ally 10% DMG. Maintaining the field costs this card 10% attack speed.

### Ascended Golden Warrior · Prince of Pride
Normal pool · Attack · Frost Striker · Weight 10 · SPD 110
Card chance per pull: 0.10% (about 1 in 995; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,050 | 4,100 | 1,000 |
| Gold | 8,200 | 16,400 | 200,000 |
| Rainbow | 32,800 | 65,600 | 5,000,000 |
| Secret | 131,200 | 262,400 | 500,000,000 |

- **Basic · Royal Strike**: Strike an enemy for 100% DMG.
- **Skill · Pride Breaker** (every 3 actions): Unleash a royal Ki blast for 300% DMG.
- **Passive · Unbroken Pride**: When below 50% HP, awaken golden Ki for 25% DMG. Reckless pride makes this card take 10% more DMG.
- **Ultimate · Golden Ki Barrage**: Fire eight Ki blasts at random enemies for 90% DMG each.

### Lunar Reaper · Crescent Soul Blade
Normal pool · Attack · Light Hexer · Weight 11.7647 · SPD 112
Card chance per pull: 0.12% (about 1 in 846; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,950 | 3,900 | 800 |
| Gold | 7,800 | 15,600 | 150,000 |
| Rainbow | 31,200 | 62,400 | 4,000,000 |
| Secret | 124,800 | 249,600 | 400,000,000 |

- **Basic · Soul Slash**: Strike an enemy for 100% DMG.
- **Skill · Crescent Severance** (every 3 actions): Mark an enemy to take 10% more DMG for 2 turns, then sever its soul for 280% DMG.
- **Passive · Reaper's Mark**: Critical hits scar the enemy's soul with Weaken, reducing its DMG by 15% for 2 turns.
- **Ultimate · Moonless Sky**: Send five crescent blades through defense and protection for 140% DMG each.

### Time Weaver · Keeper of Hours
Normal pool · Attack · Void Striker · Weight 13.3333 · SPD 135
Card chance per pull: 0.13% (about 1 in 746; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,850 | 3,700 | 750 |
| Gold | 7,400 | 14,800 | 150,000 |
| Rainbow | 29,600 | 59,200 | 4,000,000 |
| Secret | 118,400 | 236,800 | 400,000,000 |

- **Basic · Marked Kunai**: Strike an enemy with a marked blade for 100% DMG.
- **Skill · Space-Time Spiral** (every 3 actions): Blink behind the enemy for 220% DMG and evade its next hit.
- **Passive · Yellow Flash**: On entry, blink into position with 25% Ultimate charge. Overextending makes this card take 10% more DMG for 2 turns.
- **Ultimate · Flying Seal Barrage**: Warp between enemies for five strikes at 90% DMG each and gain 20% attack speed for 2 turns.

### Storm Oracle · Voice of the Storm
Normal pool · Attack · Storm Striker · Weight 22.2222 · SPD 120
Card chance per pull: 0.22% (about 1 in 448; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,600 | 3,200 | 500 |
| Gold | 6,400 | 12,800 | 100,000 |
| Rainbow | 25,600 | 51,200 | 2,500,000 |
| Secret | 102,400 | 204,800 | 250,000,000 |

- **Basic · Lightning Elbow**: Crash into an enemy for 100% DMG.
- **Skill · Thunder Lariat** (every 3 actions): Drive a lightning lariat through defense and protection for 240% DMG.
- **Passive · Lightning Chakra Armor**: On entry, charge the armor for 15% attack speed and 10% less incoming DMG. Maintaining it reduces this card's DMG by 10% for 3 turns.
- **Ultimate · Storm Guillotine**: Drop a lightning-charged heel for 450% DMG and Weaken every enemy by 15% for 2 turns.

### Cursed Prodigy · Shadow Familiar Tamer
Normal pool · Attack · Storm Striker · Weight 26.3158 · SPD 120
Card chance per pull: 0.26% (about 1 in 378; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,525 | 3,050 | 400 |
| Gold | 6,100 | 12,200 | 75,000 |
| Rainbow | 24,400 | 48,800 | 2,000,000 |
| Secret | 97,600 | 195,200 | 200,000,000 |

- **Basic · Cursed Edge**: Strike an enemy for 100% DMG.
- **Skill · Shadow Familiar Rush** (every 3 actions): A shadow familiar tears into the enemy three times for 80% DMG each.
- **Passive · Ravenous Pact**: When this card defeats an opponent, its familiar grants 25% DMG for 3 turns, but this card takes 10% more DMG for 3 turns.
- **Ultimate · Chimera Procession**: Release three familiars at random enemies, each dealing 80% DMG.

### Fist of Severance · Blood-Pact Brawler
Normal pool · Attack · Light Striker · Weight 33.3333 · SPD 110
Card chance per pull: 0.33% (about 1 in 299; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,450 | 2,900 | 300 |
| Gold | 5,800 | 11,600 | 60,000 |
| Rainbow | 23,200 | 46,400 | 1,500,000 |
| Secret | 92,800 | 185,600 | 150,000,000 |

- **Basic · Divergent Impact**: Land a fist and its delayed cursed echo for 50% DMG each.
- **Skill · Cursed Rush** (every 3 actions): Deliver two crushing punches for 110% DMG each, then inflict Weaken for 10% less enemy DMG over 2 turns.
- **Passive · Zone Counter**: After attacking, a 25% chance to land a cursed follow-up for 50% DMG and gain 15% critical chance for 2 turns.
- **Ultimate · Crimson Flash Barrage**: Unleash four cursed impacts for 110% DMG each and gain 20% critical chance for 2 turns.

### Iron Bastion · Living Sand Fortress
Normal pool · Attack · Void Warder · Weight 62.5 · SPD 85
Card chance per pull: 0.63% (about 1 in 159; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,200 | 2,400 | 150 |
| Gold | 4,800 | 9,600 | 30,000 |
| Rainbow | 19,200 | 38,400 | 800,000 |
| Secret | 76,800 | 153,600 | 80,000,000 |

- **Basic · Sand Spear**: Drive a sand spear into an enemy for 100% DMG.
- **Skill · Sand Coffin** (every 3 actions): Crush an enemy for 210% DMG and draw attacks for 2 turns.
- **Passive · Automatic Sand Shield**: On entry, living sand shields this card for 80% DMG and reduces incoming DMG by 15%, but costs 10% attack speed.
- **Ultimate · Imperial Sand Mausoleum**: Bury every enemy for 180% DMG and lower their defense by 15% for 3 turns.

### Infernal Warden · Purgatory Flamekeeper
Normal pool · Attack · Flame Striker · Weight 71.4286 · SPD 128
Card chance per pull: 0.72% (about 1 in 139; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,125 | 2,250 | 150 |
| Gold | 4,500 | 9,000 | 30,000 |
| Rainbow | 18,000 | 36,000 | 750,000 |
| Secret | 72,000 | 144,000 | 75,000,000 |

- **Basic · Flame Arc**: Strike an enemy for 100% DMG.
- **Skill · Blazing Resolve** (every 3 actions): Slash every enemy twice for 70% DMG each. Gain 20% attack speed for 2 turns and shield every ally for 30% DMG.
- **Passive · Scorching Wake**: On a hit, a 20% chance to leave Burn behind, dealing 10% DMG each turn for 3 turns.
- **Ultimate · Purgatory Dance**: Sweep every enemy for 160% DMG and inflict Burn for 10% DMG each turn for 3 turns.

### Shadow Puppeteer · Mistress of Strings
Normal pool · Attack · Storm Hexer · Weight 83.3333 · SPD 110
Card chance per pull: 0.84% (about 1 in 119; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 1,050 | 2,100 | 120 |
| Gold | 4,200 | 8,400 | 25,000 |
| Rainbow | 16,800 | 33,600 | 600,000 |
| Secret | 67,200 | 134,400 | 60,000,000 |

- **Basic · Puppet Needle**: Launch two puppet needles for 50% DMG each.
- **Skill · Scarlet Puppet Rush** (every 3 actions): Slash an enemy for 180% DMG and leave a needle wound that Bleeds for 10% DMG each turn for 3 turns.
- **Passive · Hidden Puppet Core**: When below 50% HP, shed the damaged shell: cleanse Burn and Freeze and evade two hits. Exposing the core makes this card take 10% more DMG for 2 turns.
- **Ultimate · Hundred-Puppet Cage**: Surround every enemy with puppet blades for three strikes at 65% DMG each.

### Phantom Blade · Cloud-Step Assassin
Normal pool · Attack · Frost Striker · Weight 166.6667 · SPD 120
Card chance per pull: 1.67% (about 1 in 60; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 800 | 1,600 | 60 |
| Gold | 3,200 | 6,400 | 12,000 |
| Rainbow | 12,800 | 25,600 | 300,000 |
| Secret | 51,200 | 102,400 | 30,000,000 |

- **Basic · Assassin's Cut**: Cut an enemy for 100% DMG.
- **Skill · Inverted Spear** (every 3 actions): Pierce protection and defense for 200% DMG, then expose the enemy to 10% more DMG for 2 turns.
- **Passive · Heavenly Physique**: On entry, trust physical instinct to evade the next two hits. Reckless pursuit makes this card take 10% more DMG for 3 turns.
- **Ultimate · Soul-Splitting Ambush**: Three ruthless cuts ignore defense and protection for 135% DMG each.

### Starfall Witch · Mistress of Hounds
Normal pool · Attack · Void Hexer · Weight 200 · SPD 100
Card chance per pull: 2.01% (about 1 in 50; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 750 | 1,500 | 50 |
| Gold | 3,000 | 6,000 | 10,000 |
| Rainbow | 12,000 | 24,000 | 250,000 |
| Secret | 48,000 | 96,000 | 25,000,000 |

- **Basic · Shadow Fang**: Strike an enemy for 100% DMG.
- **Skill · Hound Pursuit** (every 3 actions): Three shadow hounds pursue random enemies, each dealing 70% DMG.
- **Passive · Shadow Bind**: On a hit, a 20% chance for the hounds to Weaken the enemy by 15% for 2 turns.
- **Ultimate · Chimera Garden**: Drown the enemy in shadows, lowering defense by 15% for 3 turns before dealing 350% DMG.

### Titan Warder · Armored Colossus
Normal pool · Attack · Flame Warder · Weight 222.2222 · SPD 95
Card chance per pull: 2.23% (about 1 in 45; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 725 | 1,450 | 50 |
| Gold | 2,900 | 5,800 | 10,000 |
| Rainbow | 11,600 | 23,200 | 250,000 |
| Secret | 46,400 | 92,800 | 25,000,000 |

- **Basic · Colossus Fist**: Strike an enemy for 100% DMG.
- **Skill · Wallbreaker Rush** (every 3 actions): Draw enemy attacks for 2 turns, then charge for 160% DMG.
- **Passive · Armored Advance**: On entry, harden this card's armor to reduce incoming DMG by 15%, but lose 10% attack speed.
- **Ultimate · Crushing Footfall**: Crush every enemy for 180% DMG.

### Solar Blade · Dawn Swordsman
Normal pool · Attack · Flame Striker · Weight 250 · SPD 100
Card chance per pull: 2.51% (about 1 in 40; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 700 | 1,400 | 40 |
| Gold | 2,800 | 5,600 | 8,000 |
| Rainbow | 11,200 | 22,400 | 200,000 |
| Secret | 44,800 | 89,600 | 20,000,000 |

- **Basic · Sunlit Edge**: Strike an enemy for 100% DMG.
- **Skill · Flowing Sun** (every 3 actions): Cut through an enemy twice, dealing 90% DMG with each slash.
- **Passive · Ember Breathing**: Critical hits ignite the enemy with Burn, dealing 10% DMG each turn for 3 turns.
- **Ultimate · Dance of Dawn**: Unleash a 400% DMG sun slash and inflict Burn for 5% DMG each turn for 3 turns.

### Celestial Strategist · Wisteria Tactician
Normal pool · Attack · Light Hexer · Weight 833.3333 · SPD 125
Card chance per pull: 8.37% (about 1 in 12; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 500 | 1,000 | 12 |
| Gold | 2,000 | 4,000 | 2,500 |
| Rainbow | 8,000 | 16,000 | 60,000 |
| Secret | 32,000 | 64,000 | 6,000,000 |

- **Basic · Butterfly Thrust**: Pierce an enemy with two swift thrusts for 50% DMG each.
- **Skill · Wisteria Sting** (every 3 actions): Strike for 170% DMG and open a toxin-laced wound that Bleeds for 10% DMG each turn for 3 turns.
- **Passive · Wisteria Dose**: Critical hits have a 50% chance to inject another dose: inflict Bleed for 10% DMG each turn for 2 turns and Weaken by 10% for 2 turns.
- **Ultimate · Centipede Dance**: Zigzag through an enemy's defense and protection with five thrusts for 75% DMG each.

### Thunder Flash · Sleeping Lightning
Normal pool · Attack · Storm Striker · Weight 1250 · SPD 130
Card chance per pull: 12.56% (about 1 in 8; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 470 | 940 | 8 |
| Gold | 1,880 | 3,760 | 1,500 |
| Rainbow | 7,520 | 15,040 | 40,000 |
| Secret | 30,080 | 60,160 | 4,000,000 |

- **Basic · Lightning Draw**: Draw and slash for 100% DMG.
- **Skill · Thunderclap Dash** (every 3 actions): Flash through an enemy for 210% DMG and accelerate by 15% for 2 turns.
- **Passive · Trance Reflex**: When below 50% HP, enter a lightning trance: evade the next hit and gain 25% attack speed, but take 10% more DMG for 3 turns.
- **Ultimate · Sixfold Lightning**: Cross the battlefield with six lightning slashes for 65% DMG each.

### Spirit Weaver · Soul-Thread Medic
Normal pool · Attack · Void Mender · Weight 1333.3333 · SPD 115
Card chance per pull: 13.40% (about 1 in 7; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 450 | 900 | 8 |
| Gold | 1,800 | 3,600 | 1,500 |
| Rainbow | 7,200 | 14,400 | 40,000 |
| Secret | 28,800 | 57,600 | 4,000,000 |

- **Basic · Spirit Thread**: Send out two soul threads, each dealing 50% DMG to a random enemy.
- **Skill · Soul Rejection** (every 3 actions): Weave a shield worth 80% DMG around every ally.
- **Passive · Thread of Renewal**: After attacking, a 25% chance to mend this card for 15% of its DMG and remove a Burn or Freeze.

### Lotus Blossom · Hundred-Healing Medic
Normal pool · Attack · Light Mender · Weight 1333.3333 · SPD 105
Card chance per pull: 13.40% (about 1 in 7; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 455 | 910 | 8 |
| Gold | 1,820 | 3,640 | 1,500 |
| Rainbow | 7,280 | 14,560 | 40,000 |
| Secret | 29,120 | 58,240 | 4,000,000 |

- **Basic · Chakra Fist**: Drive a Chakra-charged punch into an enemy for 100% DMG.
- **Skill · Cherry Blossom Clash** (every 3 actions): Shatter the ground for 180% DMG and mend the lowest-HP ally for 40% DMG.
- **Passive · Mitotic Regeneration**: When below 50% HP, release stored Chakra to cleanse Burn and Freeze and recover 25% HP. Exhaustion costs 10% attack speed for 2 turns.
- **Ultimate · Hundred-Seal Release**: Strike for 250% DMG and restore 60% DMG as HP to every ally.

## Normal pool: Support cards
### Eight Trigrams Seal · Caged Beast Talisman
Normal pool · Support · Cosmic Mender · Weight 5 · SPD 0
Card chance per pull: 0.05% (about 1 in 1,990; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 55% | 2,000 |
| Gold | 70% | 400,000 |
| Rainbow | 85% | 10,000,000 |
| Secret | 100% | 1,000,000,000 |

- **Passive · Crimson Chakra Cloak**: Upon a fatal blow, the supported card releases its sealed Chakra and returns at 55% HP. The Crimson Cloak costs 25% DMG and prevents further healing.

### Cursed Ocular Seal · Hypnotic Crow Crest
Normal pool · Support · Frost Mender · Weight 6.6667 · SPD 0
Card chance per pull: 0.07% (about 1 in 1,493; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 15% | 1,500 |
| Gold | 20% | 300,000 |
| Rainbow | 25% | 7,500,000 |
| Secret | 30% | 750,000,000 |

- **Passive · Illusion of Crows**: The supported card's Skill or Ultimate has a 25% chance to summon Crows. They inflict Weaken for 15% less enemy DMG over 2 turns, and Black Flames Burn for 10% DMG each turn for 3 turns.

### Blink Kunai Seal · Marked Space-Time Blade
Normal pool · Support · Void Mender · Weight 10.5263 · SPD 0
Card chance per pull: 0.11% (about 1 in 945; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 25% | 1,000 |
| Gold | 30% | 200,000 |
| Rainbow | 40% | 5,000,000 |
| Secret | 45% | 500,000,000 |

- **Passive · Blink Reserve**: On entry, the supported card gains 25% Ultimate charge, but stabilizing the seal reduces its attack speed by 10% for 2 turns.

### Binding Blood Vow · Cursed Counter-Pact
Normal pool · Support · Light Warder · Weight 23.8095 · SPD 0
Card chance per pull: 0.24% (about 1 in 418; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 15% | 400 |
| Gold | 20% | 80,000 |
| Rainbow | 25% | 2,000,000 |
| Secret | 30% | 200,000,000 |

- **Passive · Severing Counter**: After an enemy attack, the supported card has a 25% chance to return 15% of the DMG taken as a counterstrike.

### Stormheart Mantle · Siphoning Lightning Armor
Normal pool · Support · Storm Warder · Weight 29.4118 · SPD 0
Card chance per pull: 0.30% (about 1 in 338; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 10% | 300 |
| Gold | 15% | 75,000 |
| Rainbow | 20% | 1,500,000 |
| Secret | 25% | 150,000,000 |

- **Passive · Stormheart Siphon**: When the supported card deals direct DMG, a 25% chance to drain 10% of that DMG as HP.

### Gourd of Living Sand · Desert Seal Vessel
Normal pool · Support · Void Warder · Weight 66.6667 · SPD 0
Card chance per pull: 0.67% (about 1 in 149; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 25% | 150 |
| Gold | 30% | 30,000 |
| Rainbow | 40% | 750,000 |
| Secret | 45% | 75,000,000 |

- **Passive · Living Sand Armor**: On entry, sand shields the supported card for 25% of its max HP. The heavy armor reduces attack speed by 10% for 2 turns.

### Chakra Puppet Threads · Reversal String Technique
Normal pool · Support · Storm Mender · Weight 76.9231 · SPD 0
Card chance per pull: 0.77% (about 1 in 129; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 15% | 125 |
| Gold | 20% | 25,000 |
| Rainbow | 25% | 600,000 |
| Secret | 30% | 60,000,000 |

- **Passive · Puppet Reversal**: When the supported card receives Burn or Freeze, sever the strings: cleanse those effects and reflect them onto the attacker. Reflected Burn deals 15% DMG for 3 turns.

### Heavenly Restriction · Assassin's Physical Pact
Normal pool · Support · Frost Warder · Weight 181.8182 · SPD 0
Card chance per pull: 1.83% (about 1 in 55; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 10% | 60 |
| Gold | 15% | 10,000 |
| Rainbow | 20% | 250,000 |
| Secret | 25% | 25,000,000 |

- **Passive · Cloud-Step Feint**: When attacked, the supported card has a 10% chance to evade. Each successful feint inflicts Weaken, reducing the attacker's DMG by 10% for 1 turn.

### First Form: Thunderclap · Lightning Draw Stance
Normal pool · Support · Storm Striker · Weight 1000 · SPD 0
Card chance per pull: 10.05% (about 1 in 10; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 20% | 10 |
| Gold | 25% | 2,000 |
| Rainbow | 30% | 50,000 |
| Secret | 35% | 5,000,000 |

- **Passive · Thunder Breathing**: On entry, the supported card gains 20% attack speed for 3 turns. Lightning-fast cuts deal 10% less DMG during that time.

### Wisteria Antidote Vial · Butterfly Medical Extract
Normal pool · Support · Light Mender · Weight 1250 · SPD 0
Card chance per pull: 12.56% (about 1 in 8; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 20% | 8 |
| Gold | 25% | 1,500 |
| Rainbow | 30% | 40,000 |
| Secret | 35% | 4,000,000 |

- **Passive · Wisteria Antidote**: When the supported card defeats an opponent, recover 20% of its max HP. The antidote dulls its next attacks, reducing DMG by 10% for 2 turns.

### Diamond Mitotic Seal · Forbidden Medical Crest
Normal pool · Support · Light Mender · Weight 1333.3333 · SPD 0
Card chance per pull: 13.40% (about 1 in 7; full pool, boss cards included)
| Border | Passive strength | Rarity (1 in) |
| --- | --- | --- |
| Base | 20% | 8 |
| Gold | 25% | 1,500 |
| Rainbow | 30% | 40,000 |
| Secret | 35% | 4,000,000 |

- **Passive · Hundred-Petal Renewal**: When below 50% HP, the supported card cleanses Burn and Freeze and recovers 20% of its max HP. It cannot be healed for 2 turns.

## Boss cards
### Tailed Beast Calamity · The Ember Fox
Boss card · unlocks after beating kurogane on Normal · Attack · Flame Hexer · Weight 5 · SPD 102
Card chance per pull: 0.05% (about 1 in 1,990; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,650 | 5,300 | 2,000 |
| Gold | 10,600 | 21,200 | 400,000 |
| Rainbow | 42,400 | 84,800 | 10,000,000 |
| Secret | 169,600 | 339,200 | 1,000,000,000 |

- **Basic · Chakra Claw**: Strike an enemy for 110% DMG.
- **Skill · Chakra Eruption** (every 3 actions): Burst through the enemy for 220% DMG. Searing Chakra inflicts Burn for 10% DMG each turn for 3 turns.
- **Passive · Crimson Cloak**: When below 50% HP, unleash the beast's Chakra for 25% DMG, but the unstable cloak makes this card take 10% more DMG.
- **Ultimate · Beast Bomb Barrage**: Launch six Beast Bombs at random enemies for 80% DMG each.

### Galactic Emperor · The Frost Tyrant
Boss card · unlocks after beating rimeveil on Normal · Attack · Frost Hexer · Weight 4 · SPD 98
Card chance per pull: 0.04% (about 1 in 2,488; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,800 | 5,600 | 2,500 |
| Gold | 11,200 | 22,400 | 500,000 |
| Rainbow | 44,800 | 89,600 | 12,500,000 |
| Secret | 179,200 | 358,400 | 1,250,000,000 |

- **Basic · Death Ray**: Strike an enemy for 100% DMG.
- **Skill · Emperor's Command** (every 4 actions): Deal 250% DMG and suppress every enemy's attack speed by 15% for 2 turns.
- **Passive · Golden Tyranny**: When this card defeats an opponent, recover 15% HP. Its arrogance makes it take 10% more DMG for 2 turns.
- **Ultimate · Planet Breaker**: Erase an enemy with a 350% DMG blast that ignores defense.

### Mirror Flower Overlord · The Hollow Betrayer
Boss card · unlocks after beating vex on Normal · Attack · Void Hexer · Weight 3.125 · SPD 104
Card chance per pull: 0.03% (about 1 in 3,185; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,000 | 6,000 | 3,000 |
| Gold | 12,000 | 24,000 | 600,000 |
| Rainbow | 48,000 | 96,000 | 15,000,000 |
| Secret | 192,000 | 384,000 | 1,500,000,000 |

- **Basic · Illusion Cut**: Strike an enemy for 100% DMG.
- **Skill · Shattered Reflection** (every 3 actions): Deal 180% DMG and expose a false opening, lowering defense by 15% for 3 turns.
- **Passive · Perfect Hypnosis**: On entry, create two Illusions to evade incoming hits. Maintaining them makes this card take 10% more DMG for 2 turns.
- **Ultimate · False Heaven**: Strike through four false realities for 120% DMG each. Every enemy takes 15% more DMG for 3 turns.

### Demon Progenitor · The Thousand-Year Storm
Boss card · unlocks after beating tenrai on Normal · Attack · Storm Striker · Weight 2.5 · SPD 110
Card chance per pull: 0.03% (about 1 in 3,981; full pool, boss cards included)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,250 | 6,500 | 4,000 |
| Gold | 13,000 | 26,000 | 800,000 |
| Rainbow | 52,000 | 104,000 | 20,000,000 |
| Secret | 208,000 | 416,000 | 2,000,000,000 |

- **Basic · Blood Whip**: Strike an enemy for 100% DMG.
- **Skill · Thorned Blood** (every 3 actions): Four blood thorns pierce random enemies for 60% DMG each.
- **Passive · Demon Rebirth**: When below 50% HP, cleanse Burn and Freeze and regenerate 25% of max HP. This card can no longer be healed.
- **Aura · Progenitor's Gift**: On entry, share cursed blood for 10% DMG on every ally. The pact makes them take 10% more DMG.
- **Ultimate · Black Blood Tempest**: Engulf every enemy in a 300% DMG blood storm.

## Celestial sky cards (only while their sky is active)
### Ultra Instinct Goku · Dragon Ball
Sky card · Limitbreak Skies · Attack · Light Striker · Weight 1 · SPD 110
Chance: 1 in 3,000 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,250 | 6,500 | 3,000 |
| Gold | 13,000 | 26,000 | 600,000 |
| Rainbow | 52,000 | 104,000 | 15,000,000 |
| Secret | 208,000 | 416,000 | 1,500,000,000 |

- **Basic · Instinct Rush**: Strike for 110% DMG.
- **Skill · Autonomous Counter** (every 3 actions): Strike for 280% DMG, then evade the next enemy hit.
- **Ultimate · Supreme Kamehameha**: Unleash 350% DMG on every enemy.
- **Passive · A Body Beyond Thought**: On entry, evade the next two hits, but lose 10% attack speed for 2 turns.

### Ultra Ego Vegeta · Dragon Ball
Sky card · Limitbreak Skies · Attack · Void Striker · Weight 1 · SPD 95
Chance: 1 in 2,500 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,050 | 6,100 | 2,500 |
| Gold | 12,200 | 24,400 | 500,000 |
| Rainbow | 48,800 | 97,600 | 12,500,000 |
| Secret | 195,200 | 390,400 | 1,250,000,000 |

- **Basic · Destroyer's Blow**: Strike for 110% DMG.
- **Skill · Destruction Sphere** (every 3 actions): Strike for 300% DMG and reduce the target's defense by 25% for 2 turns.
- **Ultimate · Final Destruction**: Unleash 350% DMG on every enemy.
- **Passive · Pride in the Pain**: When below 50% HP, gain 35% DMG, but take 15% more DMG for the rest of the battle.

### Blue Gogeta · Dragon Ball
Sky card · Limitbreak Skies · Attack · Cosmic Striker · Weight 1 · SPD 105
Chance: 1 in 2,000 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,900 | 5,800 | 2,000 |
| Gold | 11,600 | 23,200 | 400,000 |
| Rainbow | 46,400 | 92,800 | 10,000,000 |
| Secret | 185,600 | 371,200 | 1,000,000,000 |

- **Basic · Meteor Combination**: Strike for 110% DMG.
- **Skill · Stardust Fall** (every 3 actions): Strike four times for 80% DMG per hit.
- **Ultimate · Stardust Breaker**: Release the finishing blow for 450% DMG.
- **Passive · Perfect Fusion**: On entry, gain 25% critical chance, but lose 10% attack speed for 3 turns.

### Full Power Broly · Dragon Ball
Sky card · Limitbreak Skies · Attack · Storm Striker · Weight 1 · SPD 90
Chance: 1 in 1,500 per pull while Limitbreak Skies is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 2,750 | 5,500 | 1,500 |
| Gold | 11,000 | 22,000 | 300,000 |
| Rainbow | 44,000 | 88,000 | 7,500,000 |
| Secret | 176,000 | 352,000 | 750,000,000 |

- **Basic · Raging Impact**: Strike for 110% DMG.
- **Skill · Gigantic Roar** (every 3 actions): Strike for 300% DMG and Weaken the target by 15% for 2 turns.
- **Ultimate · Gigantic Catastrophe**: Strike random enemies five times for 90% DMG each.
- **Passive · Uncontained Rage**: When below 50% HP, gain 35% DMG, but take 15% more DMG for the rest of the battle.

### Horn of Salvation Ichigo · Bleach
Sky card · Soulfall · Attack · Void Striker · Weight 1 · SPD 105
Chance: 1 in 3,500 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,500 | 7,000 | 4,000 |
| Gold | 14,000 | 28,000 | 750,000 |
| Rainbow | 56,000 | 112,000 | 20,000,000 |
| Secret | 224,000 | 448,000 | 2,000,000,000 |

- **Basic · Zangetsu**: Strike for 110% DMG.
- **Skill · Gran Rey Getsuga** (every 3 actions): Strike for 300% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · True Bankai**: Release the finishing blow for 550% DMG.
- **Passive · Hollow Resolve**: When below 50% HP, gain 25% attack speed for 3 turns, but cannot be healed for 3 turns.

### Hogyoku Aizen · Bleach
Sky card · Soulfall · Attack · Void Striker · Weight 1 · SPD 100
Chance: 1 in 4,500 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,750 | 7,500 | 5,000 |
| Gold | 15,000 | 30,000 | 1,000,000 |
| Rainbow | 60,000 | 120,000 | 25,000,000 |
| Secret | 240,000 | 480,000 | 2,500,000,000 |

- **Basic · Silent Cut**: Strike for 110% DMG.
- **Skill · Complete Hypnosis** (every 3 actions): Strike for 300% DMG and Weaken the target by 15% for 2 turns.
- **Ultimate · Black Coffin**: Unleash 500% DMG on every enemy.
- **Passive · Beyond Perception**: After attacking, a 25% chance to evade the next hit and slow the target by 20% for 2 turns.

### Bankai Yamamoto · Bleach
Sky card · Soulfall · Attack · Flame Striker · Weight 1 · SPD 90
Chance: 1 in 6,000 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,000 | 8,000 | 6,000 |
| Gold | 16,000 | 32,000 | 1,200,000 |
| Rainbow | 64,000 | 128,000 | 30,000,000 |
| Secret | 256,000 | 512,000 | 3,000,000,000 |

- **Basic · Ashen Edge**: Strike for 110% DMG.
- **Skill · Zanka no Tachi** (every 3 actions): Strike for 280% DMG and Burn for 25% DMG each turn for 3 turns.
- **Ultimate · Heaven and Earth in Ash**: Unleash 500% DMG on every enemy.
- **Passive · Fifteen Million Degrees**: After attacking, a 25% chance to Burn the target for 15% DMG each turn for 2 turns, but take 10% more DMG for 2 turns.

### The Almighty Yhwach · Bleach
Sky card · Soulfall · Attack · Cosmic Striker · Weight 1 · SPD 95
Chance: 1 in 8,000 per pull while Soulfall is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,300 | 8,600 | 8,000 |
| Gold | 17,200 | 34,400 | 1,500,000 |
| Rainbow | 68,800 | 137,600 | 40,000,000 |
| Secret | 275,200 | 550,400 | 4,000,000,000 |

- **Basic · Reishi Arrow**: Strike for 110% DMG.
- **Skill · Future Severance** (every 3 actions): Deal 280% DMG and slow the target by 25% for 2 turns.
- **Ultimate · Auswahlen**: Unleash 500% DMG on every enemy.
- **Passive · The Future I Choose**: When below 50% HP, evade the next two hits, but deal 15% less DMG for 2 turns.

### Awakened Gojo · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Cosmic Striker · Weight 1 · SPD 110
Chance: 1 in 6,500 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,050 | 8,100 | 6,000 |
| Gold | 16,200 | 32,400 | 1,250,000 |
| Rainbow | 64,800 | 129,600 | 30,000,000 |
| Secret | 259,200 | 518,400 | 3,000,000,000 |

- **Basic · Limitless Impact**: Strike for 110% DMG.
- **Skill · Hollow Purple** (every 3 actions): Strike for 280% DMG, then evade the next enemy hit.
- **Ultimate · Unlimited Void**: Unleash 550% DMG on every enemy.
- **Passive · Infinity**: On entry, evade the next two hits, but lose 10% attack speed for 2 turns.

### True Form Sukuna · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Void Striker · Weight 1 · SPD 100
Chance: 1 in 8,000 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,300 | 8,600 | 8,000 |
| Gold | 17,200 | 34,400 | 1,500,000 |
| Rainbow | 68,800 | 137,600 | 40,000,000 |
| Secret | 275,200 | 550,400 | 4,000,000,000 |

- **Basic · Dismantle**: Strike for 110% DMG.
- **Skill · Cleave** (every 3 actions): Strike for 300% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · Malevolent Shrine**: Strike every enemy three times for 190% DMG per hit.
- **Passive · Binding Vow**: On entry, gain 25% DMG, but cannot be healed for 3 turns.

### Yuta & Rika · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Light Striker · Weight 1 · SPD 100
Chance: 1 in 4,500 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,750 | 7,500 | 5,000 |
| Gold | 15,000 | 30,000 | 1,000,000 |
| Rainbow | 60,000 | 120,000 | 25,000,000 |
| Secret | 240,000 | 480,000 | 2,500,000,000 |

- **Basic · Cursed Blade**: Strike for 110% DMG.
- **Skill · Cursed Speech** (every 3 actions): Strike for 300% DMG and Weaken the target by 15% for 2 turns.
- **Ultimate · Pure Love**: Release the finishing blow for 600% DMG.
- **Passive · Reverse Cursed Technique**: After a critical hit, heal for 20% of this card's DMG and cleanse one Burn or Freeze.

### Toji — Sorcerer Killer · Jujutsu Kaisen
Sky card · Cursed Night · Attack · Void Striker · Weight 1 · SPD 115
Chance: 1 in 3,500 per pull while Cursed Night is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 3,500 | 7,000 | 4,000 |
| Gold | 14,000 | 28,000 | 750,000 |
| Rainbow | 56,000 | 112,000 | 20,000,000 |
| Secret | 224,000 | 448,000 | 2,000,000,000 |

- **Basic · Split Soul Slash**: Strike for 110% DMG.
- **Skill · Inverted Spear** (every 3 actions): Strike for 300% DMG and reduce the target's defense by 25% for 2 turns.
- **Ultimate · Chain of a Thousand Miles**: Strike random enemies five times for 120% DMG each.
- **Passive · Heavenly Restriction**: On entry, gain 25% attack speed, but take 15% more DMG for the rest of the battle.

### Moon Breathing Kokushibo · Demon Slayer
Sky card · Blood Moon · Attack · Void Striker · Weight 1 · SPD 105
Chance: 1 in 18,000 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 5,550 | 11,100 | 20,000 |
| Gold | 22,200 | 44,400 | 4,000,000 |
| Rainbow | 88,800 | 177,600 | 100,000,000 |
| Secret | 355,200 | 710,400 | 10,000,000,000 |

- **Basic · Crescent Slash**: Strike for 110% DMG.
- **Skill · Moonlit Calamity** (every 3 actions): Strike for 300% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · Tenman Crescent**: Unleash 600% DMG on every enemy.
- **Passive · Transparent World**: On entry, gain 20% critical chance and reduce the target's defense by 20% for 3 turns.

### Compass Needle Akaza · Demon Slayer
Sky card · Blood Moon · Attack · Storm Striker · Weight 1 · SPD 115
Chance: 1 in 10,000 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 4,800 | 9,600 | 10,000 |
| Gold | 19,200 | 38,400 | 2,000,000 |
| Rainbow | 76,800 | 153,600 | 50,000,000 |
| Secret | 307,200 | 614,400 | 5,000,000,000 |

- **Basic · Destructive Fist**: Strike for 110% DMG.
- **Skill · Disorder** (every 3 actions): Strike four times for 80% DMG per hit.
- **Ultimate · Blue Silver Chaotic Afterglow**: Strike every enemy three times for 210% DMG per hit.
- **Passive · Compass Needle**: After attacking, a 25% chance to evade the next hit and gain 15% critical chance for 2 turns.

### Frozen Lotus Doma · Demon Slayer
Sky card · Blood Moon · Attack · Frost Striker · Weight 1 · SPD 95
Chance: 1 in 14,000 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 5,150 | 10,300 | 15,000 |
| Gold | 20,600 | 41,200 | 3,000,000 |
| Rainbow | 82,400 | 164,800 | 75,000,000 |
| Secret | 329,600 | 659,200 | 7,500,000,000 |

- **Basic · Lotus Fan**: Strike for 110% DMG.
- **Skill · Frozen Lotus** (every 3 actions): Deal 280% DMG and slow the target by 25% for 2 turns.
- **Ultimate · Water Lily Bodhisattva**: Unleash 600% DMG on every enemy.
- **Passive · Frozen Blood**: After attacking, a 25% chance to Weaken the target by 20% for 2 turns and shield this card for 25% of its DMG.

### Demon King Muzan · Demon Slayer
Sky card · Blood Moon · Attack · Void Striker · Weight 1 · SPD 105
Chance: 1 in 25,000 per pull while Blood Moon is active (at 1x luck)
| Border | ATK | HP | Rarity (1 in) |
| --- | --- | --- | --- |
| Base | 6,000 | 12,000 | 25,000 |
| Gold | 24,000 | 48,000 | 5,000,000 |
| Rainbow | 96,000 | 192,000 | 125,000,000 |
| Secret | 384,000 | 768,000 | 12,500,000,000 |

- **Basic · Whip of Blood**: Strike for 110% DMG.
- **Skill · Black Blood Thorns** (every 3 actions): Strike for 300% DMG and inflict Bleed for 20% DMG each turn for 2 turns.
- **Ultimate · Calamity of Blood**: Unleash 650% DMG on every enemy.
- **Passive · Demon King's Regeneration**: When below 50% HP, heal for 50% of this card's DMG, but deal 15% less DMG for 3 turns.

## Bosses
- **Tailed Beast Calamity** · The Ember Fox (World 1, Ember Village): Normal: HP 250,000, recommended Attack rating 115,700; Hard: HP 800,000, recommended Attack rating 295,900; Nightmare: HP 2,500,000, recommended Attack rating 801,600
- **Galactic Emperor** · The Frost Tyrant (World 2, Frostfang Peaks): Normal: HP 1,200,000, recommended Attack rating 504,000; Hard: HP 4,000,000, recommended Attack rating 1,108,800; Nightmare: HP 12,000,000, recommended Attack rating 1,920,000
- **Mirror Flower Overlord** · The Hollow Betrayer (World 3, Neon Abyss): Normal: HP 5,500,000, recommended Attack rating 2,284,800; Hard: HP 18,000,000, recommended Attack rating 5,721,600; Nightmare: HP 55,000,000, recommended Attack rating 13,401,600
- **Demon Progenitor** · The Thousand-Year Storm (World 4, Stormspire Isle): Normal: HP 25,000,000, recommended Attack rating 5,318,400; Hard: HP 85,000,000, recommended Attack rating 16,512,000; Nightmare: HP 250,000,000, recommended Attack rating 25,000,000

**Notes on the bosses:**
- **Squads:** each recommended rating is a squad that wins in about 60-90 s:
  - World 1: Gold / Rainbow commons
  - World 2: Rainbow
  - World 3: Secret (its Nightmare needs Secret Soulfall / Cursed Night sky cards)
  - World 4 Normal: Secret high cards
  - World 4 Hard: four Secret Blood Moon cards
- **Starter deck:** the all-Base starter deck (31.5k) can't clear World 1 Normal yet.
- **World 4 Nightmare (250M HP)** is currently out of reach of every deck: the best one deals about 169M before
  the 3-minute limit.
