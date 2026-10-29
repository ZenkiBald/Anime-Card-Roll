--!strict
-- Event-only Attack cards. Each sky is one series; existing normal cards keep their identities.
local Weather = require(script.Parent.Weather)
local Art = require(script.Parent.CelestialArt)
local M = {}
local function damage(pct: number, target: string?, hits: number?): any
	return {Kind="Damage",Pct=pct,Target=target,Hits=hits}
end
local function buff(stat: string, amount: number, turns: number?): any
	return {Kind="Buff",Stat=stat,Amount=amount,Turns=turns,Target="Self"}
end
local function weaken(stat: string, amount: number, turns: number): any
	return {Kind="Debuff",Stat=stat,Amount=amount,Turns=turns}
end
local passives: {[string]: any} = {
	dodge={Trigger="OnEntry",Limit=1,Text="On entry, evade the next two hits.",Effects={{Kind="Evade",Hits=2,Target="Self"}}},
	rage={Trigger="BelowHalf",Limit=1,Text="When below 50% HP, gain {a1} DMG for the rest of the battle.",Effects={buff("ATK",.35)}},
	crit={Trigger="OnEntry",Limit=1,Text="On entry, gain {a1} critical chance for {t1} turns.",Effects={buff("Crit",.25,3)}},
	resolve={Trigger="BelowHalf",Limit=1,Text="When below 50% HP, gain {a1} attack speed for {t1} turns.",Effects={buff("SPD",.25,3)}},
	hypnosis={Trigger="OnAct",Chance=.25,Limit=3,Text="After attacking, a {chance} chance to evade the next hit and slow the target by {a2} for {t2} turns.",Effects={{Kind="Evade",Hits=1,Target="Self"},weaken("SPD",.2,2)}},
	flames={Trigger="OnAct",Chance=.25,Limit=4,Text="After attacking, a {chance} chance to Burn the target for {p1} DMG each turn for {t1} turns.",Effects={{Kind="Burn",Pct=.15,Turns=2}}},
	future={Trigger="BelowHalf",Limit=1,Text="When below 50% HP, evade the next two hits.",Effects={{Kind="Evade",Hits=2,Target="Self"}}},
	vow={Trigger="OnEntry",Limit=1,Text="On entry, gain {a1} DMG for the rest of the battle.",Effects={buff("ATK",.25)}},
	renewal={Trigger="OnCrit",Limit=3,Text="After a critical hit, heal for {p1} of this card's DMG and cleanse one Burn or Freeze.",Effects={{Kind="Heal",Pct=.2,Target="Self"},({Kind="Cleanse",Amount=1,Target="Self"} :: any)}},
	restriction={Trigger="OnEntry",Limit=1,Text="On entry, gain {a1} attack speed for the rest of the battle.",Effects={buff("SPD",.25)}},
	moon={Trigger="OnEntry",Limit=1,Text="On entry, gain {a1} critical chance and reduce the target's defense by {a2} for {t2} turns.",Effects={buff("Crit",.2,3),weaken("DEF",.2,3)}},
	compass={Trigger="OnAct",Chance=.25,Limit=4,Text="After attacking, a {chance} chance to evade the next hit and gain {a2} critical chance for {t2} turns.",Effects={{Kind="Evade",Hits=1,Target="Self"},buff("Crit",.15,2)}},
	ice={Trigger="OnAct",Chance=.25,Limit=3,Text="After attacking, a {chance} chance to Weaken the target by {a1} for {t1} turns and shield this card for {p2} of its DMG.",Effects={weaken("ATK",.2,2),{Kind="Shield",Pct=.25,Target="Self"}}},
	regeneration={Trigger="BelowHalf",Limit=1,Text="When below 50% HP, heal for {p1} of this card's DMG.",Effects={{Kind="Heal",Pct=.5,Target="Self"}}},
}
local specs: {any} = {
	{Id="celestial_rain_goku",Weather="rain",SkyOneIn=3000,ATK=3250,Name="Ultra Instinct Goku",Title="Dragon Ball",Element="Light",SPD=110,Basic="Instinct Rush",Skill="Autonomous Counter",Ultimate="Supreme Kamehameha",Passive="A Body Beyond Thought",Kind="dodge"},
	{Id="celestial_rain_vegeta",Weather="rain",SkyOneIn=2500,ATK=3050,Name="Ultra Ego Vegeta",Title="Dragon Ball",Element="Void",SPD=95,Basic="Destroyer's Blow",Skill="Destruction Sphere",Ultimate="Final Destruction",Passive="Pride in the Pain",Kind="rage"},
	{Id="celestial_rain_gogeta",Weather="rain",SkyOneIn=2000,ATK=2900,Name="Blue Gogeta",Title="Dragon Ball",Element="Cosmic",SPD=105,Basic="Meteor Combination",Skill="Stardust Fall",Ultimate="Stardust Breaker",Passive="Perfect Fusion",Kind="crit"},
	{Id="celestial_rain_broly",Weather="rain",SkyOneIn=1500,ATK=2750,Name="Full Power Broly",Title="Dragon Ball",Element="Storm",SPD=90,Basic="Raging Impact",Skill="Gigantic Roar",Ultimate="Gigantic Catastrophe",Passive="Uncontained Rage",Kind="rage"},
	{Id="celestial_blizzard_ichigo",Weather="blizzard",SkyOneIn=3500,ATK=3500,Name="Horn of Salvation Ichigo",Title="Bleach",Element="Void",SPD=105,Basic="Zangetsu",Skill="Gran Rey Getsuga",Ultimate="True Bankai",Passive="Hollow Resolve",Kind="resolve"},
	{Id="celestial_blizzard_aizen",Weather="blizzard",SkyOneIn=4500,ATK=3750,Name="Hogyoku Aizen",Title="Bleach",Element="Void",SPD=100,Basic="Silent Cut",Skill="Complete Hypnosis",Ultimate="Black Coffin",Passive="Beyond Perception",Kind="hypnosis"},
	{Id="celestial_blizzard_yamamoto",Weather="blizzard",SkyOneIn=6000,ATK=4000,Name="Bankai Yamamoto",Title="Bleach",Element="Flame",SPD=90,Basic="Ashen Edge",Skill="Zanka no Tachi",Ultimate="Heaven and Earth in Ash",Passive="Fifteen Million Degrees",Kind="flames"},
	{Id="celestial_blizzard_yhwach",Weather="blizzard",SkyOneIn=8000,ATK=4300,Name="The Almighty Yhwach",Title="Bleach",Element="Cosmic",SPD=95,Basic="Reishi Arrow",Skill="Future Severance",Ultimate="Auswahlen",Passive="The Future I Choose",Kind="future"},
	{Id="celestial_thunder_gojo",Weather="thunder",SkyOneIn=6500,ATK=4050,Name="Awakened Gojo",Title="Jujutsu Kaisen",Element="Cosmic",SPD=110,Basic="Limitless Impact",Skill="Hollow Purple",Ultimate="Unlimited Void",Passive="Infinity",Kind="dodge"},
	{Id="celestial_thunder_sukuna",Weather="thunder",SkyOneIn=8000,ATK=4300,Name="True Form Sukuna",Title="Jujutsu Kaisen",Element="Void",SPD=100,Basic="Dismantle",Skill="Cleave",Ultimate="Malevolent Shrine",Passive="Binding Vow",Kind="vow"},
	{Id="celestial_thunder_yuta",Weather="thunder",SkyOneIn=4500,ATK=3750,Name="Yuta & Rika",Title="Jujutsu Kaisen",Element="Light",SPD=100,Basic="Cursed Blade",Skill="Cursed Speech",Ultimate="Pure Love",Passive="Reverse Cursed Technique",Kind="renewal"},
	{Id="celestial_thunder_toji",Weather="thunder",SkyOneIn=3500,ATK=3500,Name="Toji — Sorcerer Killer",Title="Jujutsu Kaisen",Element="Void",SPD=115,Basic="Split Soul Slash",Skill="Inverted Spear",Ultimate="Chain of a Thousand Miles",Passive="Heavenly Restriction",Kind="restriction"},
	{Id="celestial_eclipse_kokushibo",Weather="eclipse",SkyOneIn=18000,ATK=5550,Name="Moon Breathing Kokushibo",Title="Demon Slayer",Element="Void",SPD=105,Basic="Crescent Slash",Skill="Moonlit Calamity",Ultimate="Tenman Crescent",Passive="Transparent World",Kind="moon"},
	{Id="celestial_eclipse_akaza",Weather="eclipse",SkyOneIn=10000,ATK=4800,Name="Compass Needle Akaza",Title="Demon Slayer",Element="Storm",SPD=115,Basic="Destructive Fist",Skill="Disorder",Ultimate="Blue Silver Chaotic Afterglow",Passive="Compass Needle",Kind="compass"},
	{Id="celestial_eclipse_doma",Weather="eclipse",SkyOneIn=14000,ATK=5150,Name="Frozen Lotus Doma",Title="Demon Slayer",Element="Frost",SPD=95,Basic="Lotus Fan",Skill="Frozen Lotus",Ultimate="Water Lily Bodhisattva",Passive="Frozen Blood",Kind="ice"},
	{Id="celestial_eclipse_muzan",Weather="eclipse",SkyOneIn=25000,ATK=6000,Name="Demon King Muzan",Title="Demon Slayer",Element="Void",SPD=105,Basic="Whip of Blood",Skill="Black Blood Thorns",Ultimate="Calamity of Blood",Passive="Demon King's Regeneration",Kind="regeneration"},
}
-- Skills fire every 3 actions like the normal cards' (280-320% DMG). Ultimates: Limitbreak keeps its
-- 350-450% kits; Soulfall 500-550%, Cursed Night 550-600%, Blood Moon 600-650% (the hardest hitters).
local ULTIMATE = { rain = 3.5, blizzard = 5, thunder = 5.5, eclipse = 6 }
local function moves(spec: any): {any}
	local sky=spec.Weather
	local ult=ULTIMATE[sky]
	local basic={Slot="Basic",Name=spec.Basic,Text="Strike for {p1} DMG.",Effects={damage(1.1)}} :: any
	local skill={Slot="Skill",Name=spec.Skill,Every=3,Text="Strike for {p1} DMG and Weaken the target by {a2} for {t2} turns.",Effects={damage(3),weaken("ATK",.15,2)}} :: any
	local ultimate={Slot="Ultimate",Name=spec.Ultimate,Text="Unleash {p1} DMG on every enemy.",Effects={damage(ult,"Enemies")}} :: any
	local id=spec.Id
	if string.find(id,"goku") or string.find(id,"gojo") then
		skill.Text="Strike for {p1} DMG, then evade the next enemy hit."
		skill.Effects={damage(2.8),{Kind="Evade",Hits=1,Target="Self"}}
	elseif string.find(id,"yamamoto") then
		skill.Text="Strike for {p1} DMG and Burn for {p2} DMG each turn for {t2} turns."
		skill.Effects={damage(2.8),{Kind="Burn",Pct=.25,Turns=3}}
	elseif string.find(id,"ichigo") or string.find(id,"sukuna") or string.find(id,"kokushibo") or string.find(id,"muzan") then
		skill.Text="Strike for {p1} DMG and inflict Bleed for {p2} DMG each turn for {t2} turns."
		skill.Effects={damage(3),{Kind="Bleed",Pct=.2,Turns=2}}
	elseif string.find(id,"toji") or string.find(id,"vegeta") then
		skill.Text="Strike for {p1} DMG and reduce the target's defense by {a2} for {t2} turns."
		skill.Effects={damage(3),weaken("DEF",.25,2)}
	elseif string.find(id,"doma") or string.find(id,"yhwach") then
		skill.Text="Deal {p1} DMG and slow the target by {a2} for {t2} turns."
		skill.Effects={damage(2.8),weaken("SPD",.25,2)}
	elseif string.find(id,"akaza") or string.find(id,"gogeta") then
		skill.Text="Strike four times for {p1} DMG per hit."
		skill.Effects={damage(.8,nil,4)}
	end
	if string.find(id,"gogeta") or string.find(id,"yuta") or string.find(id,"ichigo") then
		ultimate.Text="Release the finishing blow for {p1} DMG."
		ultimate.Effects={damage(if sky=="rain" then 4.5 else ult+.5)}
	elseif string.find(id,"broly") or string.find(id,"toji") then
		ultimate.Text="Strike random enemies five times for {p1} DMG each."
		ultimate.Effects={damage(if sky=="rain" then .9 else (ult+.5)/5,"RandomEnemy",5)}
	elseif string.find(id,"sukuna") or string.find(id,"akaza") then
		ultimate.Text="Strike every enemy three times for {p1} DMG per hit."
		ultimate.Effects={damage(if sky=="eclipse" then 2.1 else 1.9,"Enemies",3)}
	elseif string.find(id,"muzan") then
		ultimate.Effects={damage(6.5,"Enemies")}
	end
	local passive=table.clone(passives[spec.Kind])
	passive.Slot="Passive";passive.Name=spec.Passive
	return {basic,skill,ultimate,passive}
end
function M.Build(): {any}
	local cards={}
	for _,spec in specs do
		table.insert(cards,{Id=spec.Id,Weather=spec.Weather,Name=spec.Name,Title=spec.Title,Type="Attack",Role="Striker",
			Weight=1,SkyOneIn=spec.SkyOneIn,Element=spec.Element,Main=spec.ATK,HP=2*spec.ATK,SPD=spec.SPD,Glyph="CS",
			Accent=Weather.ById[spec.Weather].Color,Image=Art[spec.Id],Abilities=moves(spec)})
	end
	return cards
end
return M
