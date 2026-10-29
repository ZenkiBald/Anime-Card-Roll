--!strict
-- Presentation preferences never change the server's roll or rewards.
local Borders=require(script.Parent.Borders)
local Policy={}
Policy.Minimums={"All","Gold","Rainbow","Secret","Off"}
Policy.Styles={"Pack","Cinematic"}
function Policy.Read(settings: any): any
	local s=if type(settings)=="table" then settings else {}
	return {RevealMinimum=if table.find(Policy.Minimums,s.RevealMinimum) then s.RevealMinimum else "Rainbow",
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
return Policy
