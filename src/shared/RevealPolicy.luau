--!strict
-- Presentation preferences never change the server's roll or rewards.
local Borders=require(script.Parent.Borders)
local Policy={}
Policy.Minimums={"All","Gold","Rainbow","Secret","Off"}
Policy.Styles={"Pack","Cinematic"}
-- Gold and above stops for the full reveal by default (2026-11-13; it was Rainbow, which hid every Gold).
Policy.DefaultMinimum="Gold"
function Policy.Read(settings: any): any
	local s=if type(settings)=="table" then settings else {}
	return {RevealMinimum=if table.find(Policy.Minimums,s.RevealMinimum) then s.RevealMinimum else Policy.DefaultMinimum,
		RevealStyle=if table.find(Policy.Styles,s.RevealStyle) then s.RevealStyle else "Pack",
		RevealDuplicates=s.RevealDuplicates==true}
end
function Policy.Eligible(result: any,settings: any): boolean
	local s=Policy.Read(settings)
	if s.RevealMinimum=="Off" then return false end
	if not s.RevealDuplicates and result.Outcome~="New" and result.NewBorder~=true then return false end
	return s.RevealMinimum=="All" or Borders.Index(result.Border)>=Borders.Index(s.RevealMinimum)
end
function Policy.Select(results: {any},settings: any): {any}
	local list,seen={},{}
	for _,r in results do
		local key=r.CardId..":"..(r.Border or "Normal")
		if not seen[key] and Policy.Eligible(r,settings) then seen[key]=true;table.insert(list,r) end
	end
	return list
end
-- How big a pull's centre-stage moment is (UI/Reveal), from its rarity number (Cards.Rarity: card odds x
-- border odds). 0 routine, 1 uncommon, 2 rare (elite / apex / boss cards and every Gold), 3 jackpot.
Policy.HeatFrom={50,300,20000}
-- Seconds a card of each heat stays on stage before it leaves by itself (a newer roll replaces it sooner).
Policy.HeatHold={[0]=0.85,1.05,1.4,2}
function Policy.Heat(rarity: number): number
	local heat=0
	for i,from in Policy.HeatFrom do
		if rarity>=from then heat=i end
	end
	return heat
end
return Policy
