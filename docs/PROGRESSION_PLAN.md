# Progression follow-up

The user's feedback on 2026-10-29: there is little reason to grind and the game feels boring.
This tracks implemented first-session / tower rewards and the remaining content work.

The current loop has twelve story challenges, mastery, border fusion, two towers and raids, but most
early visible rewards are consumables for more rolls. Boss cards are only added to the random pool after
a Normal clear. Random relics start at Infinite Tower floor 50 with a base 0.1% chance per win. Guaranteed
checkpoint relics now give a Four-Leaf Relic at floor 10 and Prism Shard at 50. The Pagoda crown needs
floor 100 and a very strong deck. Longer-session spacing still needs ordinary-play review.

The implemented GOALS page now connects existing progress to those rewards. It does not solve the
reward gap by itself. The next content pass should focus on this sequence:

1. **A useful first-session reward (implemented 2026-10-30).** Claiming Kenji's first-boss quest earns the
   permanent First Victory title, displayed in the quest rewards before the fight. Previous claimants
   receive it once through migration. Four Attack cards advance the guide; random Support discoveries
   no longer hold it at7/8. Desktop mock-profile review:10 starter pulls, one Gold, Normal clear22.3 s;
   no new card grants or combat tuning. Broader fresh-account sampling / first30-minute pacing remains.
2. **Milestones along the climb (implemented 2026-10-30).** Infinite Tower first clears pay at floors
   5 / 10 / 25 / 50 / 75 / 100, including guaranteed relics, potion tiers, packs, sky supplies and titles.
   Floor 100 adds a 10000-roll Colossal Pack to the existing Heart of the Endless Spire. The full table
   is Tower.Checkpoints; the tower preview and GOALS show the next exact reward. Claim flags survive
   lost runs, and existing best runs collect earned new rewards on their next win. Random borders
   remain pure luck. Review whether the gaps feel rewarding during longer ordinary play.
3. **A reason to change teammates.** Offer optional boss challenges with clear constraints, such as
   familiar bonds or the existing Cost Challenge. Reward successful different builds; avoid requiring
   hundreds of identical reruns. Mastery already provides part of this loop and needs clearer feedback.

Thirty unboosted headless starts forced every border to Base and disabled sky finds / traits. All won
the first boss; four attackers arrived in median / p95 10 pulls, median fight 26.1 seconds. This samples
normal-pool composition, not the real first 30 minutes or every possible unlucky outcome. No pity was added.
Familiar-pair bonus modifiers are checked for all 11 pairs, and each card's skill sheet names its partner.

Validate the first 30 minutes on a fresh profile: time until the first permanent reward, wins between
meaningful rewards, and whether a player can explain their next target without help. Then check a
mid-game profile so early improvements do not erase the longer chase. New saved claims require a
SaveMigration step and regression tests; all grants remain server-owned and rate-limited.
