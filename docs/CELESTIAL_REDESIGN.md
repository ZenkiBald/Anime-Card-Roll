# Approved redesign — implementation tracker

User authorized all discussed changes on 2026-10-29. Preserve card/boss identities, ownership, art,
traits and mastery. All grants/rolls/eligibility/claims are server-owned, validated and rate-limited.
Implementation completed on 2026-10-29. Ordinary-play / live-server review remains in LAUNCH_CHECKLIST section 5.

## Required work

- [x] Collections: Card Packs NPC selects a saved active collection. ROLL/AUTO/consumable packs all use
  it; unlocked boss cards remain eligible. Default normal collection, world-unlocked themed collections,
  visible contents/odds/unlocks and ACTIVE PACK HUD. Existing cards stay owned and may mix in decks.
  Themes approved: Chakra Legends, Galactic Warriors, Cursed Spirits, Demon Hunters.
- [x] New-player starter pack + equip/fight guidance; earn consumable packs from existing progression.
- [x] Elements lose damage/counter/stagger/synergy bonuses; retain visual/ability themes and statuses.
  Convert infused packs without losing rolls; remove stale elemental advantage UI.
- [x] Battle rhythm: basics 2–3s, skills 8–12s, ultimate energy + 20–25s cadence at 1x; limit hit-energy
  farming, readable boss tells and meaningful bursts; retune all fixture fights and update target rules.
- [x] Familiar Attack/Support column bonds: Supports usable with everyone, authored familiar bonuses,
  visible BONDED + actual bonus/activation. No repeated revives, uncapped heals or energy loops.
- [x] Boss reward cooldown 5m per boss/difficulty after rewarded win, persisted across reconnects.
  Practice allowed without repeat farm grants; losses no cooldown, other challenges remain available.
- [x] Economy: retire general Shard upgrade shop; compensate existing purchases/balances safely.
  One normal trait reroll = 1 Trait Shard. No v1 paid economy for weather items.
- [x] Luck: earned permanent progression + additive potion/weather luck, diminishing returns instead
  of hard 25x cap. Exact displayed probabilities match server. Luck Potion I/II/III +0.5/1/2 for 5/10/15m.
- [x] Celestial Skies: Quiet Skies, Limitbreak Skies (Dragon Ball), Soulfall (Bleach), Cursed Night (Jujutsu Kaisen), Blood Moon (Demon Slayer).
  Seeded global 15m slots with varied start offset, forecast 2–3m before, active 5m/5m/5m/3m;
  additive luck +0.5/1/1/2. All servers agree on natural schedule.
- [x] Sixteen separate Celestial Cards, four Attacks per active weather (one anime per sky), new AI art, Codex,
  borders, 100:1 fusion. Never eligible outside weather. Individual 600-8000 sky rarities share one
  server-paced search / second across ROLL / AUTO / packs, without banking idle attempts or multiplying
  chances for a bulk opening. Every normal pull still arrives. Same rarity-to-stat curve across skies;
  stronger than normal / boss cards at matched rarity. Exact ranges / roster mapping are in CLAUDE.md.
  Weather +20% battle stats. No Celestial Supports or same-weather column sync.
  Read-only weather HUD with mystery slots until owned, base rarities / timer; all sky items/crafting in BAG. Bottom-right illustrated
  potion/worn-relic status icons have hover/tap details. Latest user authorized roster selection, no more approval questions.
- [x] Items: Celestial Orb random summon (45/25/25/5%), weather Sigils crafted from 10 fragments (25
  Eclipse), Celestial Fragments, Celestial Hourglass extends once +2m. Local summons 3m, override global
  then return; 5m cooldown after summon ends; no summons during Eclipse; named server banner.
  Sources quests/streak/wheel/bosses/tower/raids. Corrupted boss source needs visible eligibility.
- [x] Three presets + weather-aware Best Deck; 2–3 closest progress bars (mastery/fusion/collection/weather).
- [x] Single-anime collection / sky rosters; existing named bosses, faction guards and user-selected BossKit
  models retained. Collection unlock order does not replace the saved worlds. Studio Assistant tower-night
  mood preserved in source; its map / zone marker remain place-only.
- [x] Required checks, migration regressions, Studio verification, current CLAUDE/checklist/handoff, push.

## Decisions retained

No duplicate-stat Stars: mastery remains the card-training system. No roll pity. Existing saves must
not lose cards or purchased progression. A boss clear unlocks its card in the pool, not a guaranteed card.
First-session permanent rewards / milestone rewards should make the grind visible and reliable.
