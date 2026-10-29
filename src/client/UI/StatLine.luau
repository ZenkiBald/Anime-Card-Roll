--!nonstrict
-- Shared image-backed combat stats, used by full cards, inspectors and hover sheets.
local Kit=require(script.Parent.Kit)
local Theme=require(script.Parent.Theme)
local Cards=require(game:GetService("ReplicatedStorage").Shared.Cards)
local Stats={}
Stats.Images={DMG="rbxassetid://115433246877589",HP="rbxassetid://85300546215088"}
function Stats.Value(parent,kind,value,props)
	local p={Name=kind,BackgroundTransparency=1,Parent=parent}
	for k,v in props or {} do p[k]=v end
	local row=Kit.new("Frame",p)
	Kit.new("ImageLabel",{Name="StatIcon",Image=Stats.Images[kind],BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,
		AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromScale(0,.5),Size=UDim2.fromScale(.18,.94),ZIndex=row.ZIndex+1,Parent=row},{Kit.aspect(1)})
	Kit.label({Name="Value",Text=kind.." "..value,TextColor3=if kind=="HP" then Theme.Color.Health else Theme.Color.Attack,
		TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromScale(.2,0),Size=UDim2.fromScale(.8,1),ZIndex=row.ZIndex+1,Parent=row},30)
	return row
end
function Stats.new(card,stars,border,node,props,long)
	local p={Name="CombatStats",BackgroundTransparency=1}
	for k,v in props or {} do p[k]=v end
	local row=Kit.new("Frame",p)
	if card.Type~="Attack" then
		Kit.label({Text="PASSIVE SUPPORT",TextColor3=Theme.Color.Support,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.fromScale(1,1),Parent=row},16)
		return row
	end
	local fmt=if long then Kit.commas else Kit.short
	Stats.Value(row,"DMG",fmt(Cards.Stat(card,card.Main,stars,border,node)),{Size=UDim2.fromScale(.49,1),ZIndex=row.ZIndex})
	Stats.Value(row,"HP",fmt(Cards.Stat(card,card.HP or 0,stars,border,node)),{Position=UDim2.fromScale(.51,0),Size=UDim2.fromScale(.49,1),ZIndex=row.ZIndex})
	return row
end
return Stats
