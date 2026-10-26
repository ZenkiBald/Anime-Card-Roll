# Card art drop folder

Keep each card's finished illustration here as a square PNG named after the card id (`aurelia.png`).
The game does not read this folder. To show a picture in game:

1. In Studio, open Asset Manager > Images > Bulk Import and pick the PNGs (the uploads must belong to the
   account or group that owns the game).
2. Right-click the uploaded image > Copy Asset ID.
3. Paste the number next to the card's id in the `ART` table in `src/shared/Cards.luau` (0 = no art yet).
4. Save the file, let Rojo sync, press Play. Cards with an id show the picture; the rest keep the bust.

Card ids: rook, kaede, tomo, mirai, sora, hayate, akane, kaito, tsubasa, noa, raijen, kurogane_card,
rimeveil_card, vex_card, tenrai_card (Attack); hana, goro, suzu, ibuki, yume, tetsu, amane, luna, orin,
amaya, aurelia (Support).
