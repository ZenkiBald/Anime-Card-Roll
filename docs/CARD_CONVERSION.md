# Character Attack / relic Support conversion

The user's request (2026-10-27): convert the current 11 character Supports into Attack cards, add new
non-character Supports, and show 2–3 art examples before uploading / pushing Support artwork.
Gemini's pasted suggestions were references, not a replacement for the approved character art.

All original character names, ids, list positions and portraits are kept. Every converted character has
ATK / HP / attack speed and its own Basic, Skill, triggered Passive and Ultimate. Supports remain passive
equipment for the same-numbered attacker, with no personal damage / HP / turns. New relics are appended
to the roll pool, with the former Support's element, weight and passive math. Pull probabilities recalculate
over the expanded pool (37 total cards, 33 before boss unlocks); border odds are unchanged.

| Converted character | Approved inspiration | New Support |
| --- | --- | --- |
| Lotus Blossom (`hana`) | Sakura Haruno (Naruto) | Diamond Mitotic Seal (`mitotic_seal`) |
| Fist of Severance (`goro`) | Yuji Itadori (Jujutsu Kaisen) | Binding Blood Vow (`blood_vow`) |
| Thunder Flash (`suzu`) | Zenitsu Agatsuma (Demon Slayer) | First Form: Thunderclap (`thunderclap_form`) |
| Phantom Blade (`ibuki`) | Toji Fushiguro (Jujutsu Kaisen) | Heavenly Restriction (`heavenly_pact`) |
| Dream Reaper (`yume`) | Itachi Uchiha (Naruto) | Cursed Ocular Seal (`ocular_seal`) |
| Iron Bastion (`tetsu`) | Gaara (Naruto) | Gourd of Living Sand (`sand_gourd`) |
| Celestial Strategist (`luna`) | Shinobu Kocho (Demon Slayer) | Wisteria Antidote Vial (`wisteria_vial`) |
| Time Weaver (`orin`) | Minato Namikaze (Naruto) | Blink Kunai Seal (`blink_kunai`) |
| Nine-Tails Sovereign (`aurelia`) | Naruto Uzumaki, golden Kurama Chakra cloak (Naruto) | Eight Trigrams Seal (`beast_seal`) |
| Shadow Puppeteer (`amane`) | Sasori (Naruto) | Chakra Puppet Threads (`puppet_threads`) |
| Storm Oracle (`amaya`) | A, Fourth Raikage (Naruto) | Stormheart Mantle (`storm_mantle`) |

Phantom Blade remains inspired by Toji, Time Weaver by Minato, Shadow Puppeteer by Sasori and Storm Oracle
by the Fourth Raikage. Their kits use those existing identities; no HxH / One Piece / Date A Live additions.
Wisteria uses the existing Bleed scheduler for a needle wound, rather than claiming an unimplemented poison status.
Black Flames remain cleanseable Burn; there is no false claim of unremovable flames.

## Existing saves

After normalizing old borders, `SaveMigration` runs `SupportRelicsVersion` once. Each owned former Support
stays owned as its character Attack card. Its replacement relic receives an independent copy of the old
entry, including per-border piles, traits, foil, Mastery and selected border. An already-owned replacement
is never overwritten. Support positions in every preset (and older `Deck.Support`) switch to the relic;
Attack lineups and active preset do not move. Normal future rolls grant only the pulled entry. Deep-copy
and repeat-load regression tests prevent shared progress tables or repeated compensation.

Character bonds still require the actual characters. A corresponding relic does not stand in for a partner.
Chase fixtures now correctly apply their requested earned Mastery; the old helper silently ignored it for
non-story cases. Story fixtures continue using preceding distinct boss clears. No boss tuning was changed.

## Completed Support artwork

The user approved all three examples and the style on 2026-10-27. All 11 Supports are now illustrated,
uploaded and connected in Cards.ART. Sources, asset ids, hashes and prompts are in
`art/cards/support-20261027/`. The three approved previews are unchanged. Eight new relic / technique
illustrations complete the set, with two small cleanup edits; no character portraits were replaced.
All sources are 1254 x 1254 with a central subject for the existing portrait crops. Actual CardTile,
full CardView and normal SQUAD Support screens were visually checked in Studio. Nothing was published.
