# Progression follow-up

The user's feedback on 2026-10-29: there is little reason to grind and the game feels boring.
This is a content proposal, not implemented reward behavior.

The current loop has twelve story challenges, mastery, border fusion, two towers and raids, but most
early visible rewards are consumables for more rolls. Boss cards are only added to the random pool after
a Normal clear. Relics start at Infinite Tower floor 50 with a base 0.1% chance per win (Guardians improve
it on new record floors). The Pagoda crown needs floor 100 and a very strong deck. These long gaps leave
few tangible goals for a new player.

The implemented GOALS page now connects existing progress to those rewards. It does not solve the
reward gap by itself. The next content pass should focus on this sequence:

1. **A useful first-session reward.** A short, visible series of boss objectives should earn something
   permanent that the player can see or use immediately. Prefer the existing title / cosmetic systems;
   avoid another currency. Show the exact reward and earned progress before the player starts.
2. **Milestones along the climb.** Give tower checkpoints worthwhile guaranteed first-clear rewards,
   alongside the existing random chase. Choose the rewards and balance them before changing the server;
   keep border rolls pure luck. The player should know the next few wins lead somewhere.
3. **A reason to change teammates.** Offer optional boss challenges with clear constraints, such as
   an element team or the existing Cost Challenge. Reward successful different builds; avoid requiring
   hundreds of identical reruns. Mastery already provides part of this loop and needs clearer feedback.

Validate the first 30 minutes on a fresh profile: time until the first permanent reward, wins between
meaningful rewards, and whether a player can explain their next target without help. Then check a
mid-game profile so early improvements do not erase the longer chase. New saved claims require a
SaveMigration step and regression tests; all grants remain server-owned and rate-limited.
