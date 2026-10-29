--!nonstrict
-- Named targets and explicit amounts; the server validates every test action independently.
local Shared=game:GetService("ReplicatedStorage").Shared
local Cards=require(Shared.Cards)
local Weather=require(Shared.Weather)
local Kit=require(script.Parent.Kit)
local Theme=require(script.Parent.Theme)
local Controls=require(script.Parent.Controls)
local Pane={}
function Pane.Build(parent,call)
	local pane=Kit.new("Frame",{Name="CustomTools",LayoutOrder=-10,Size=UDim2.new(1,-8,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Parent=parent},
		{Kit.new("UIListLayout",{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})})
	Kit.label({Text="YOUR SANDBOX",Size=UDim2.new(1,0,0,28),LayoutOrder=1,Parent=pane},24)
	Kit.label({Text="Grants change your saved test profile. Sky previews affect this server. No rewards from level / cooldown edits.",TextWrapped=true,Size=UDim2.new(1,0,0,36),LayoutOrder=2,Parent=pane},14)
	local function row(name,order)
		return Kit.new("Frame",{Name=name,LayoutOrder=order,BackgroundTransparency=1,Size=UDim2.new(1,0,0,42),Parent=pane},
			{Kit.new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder})})
	end
	local function field(host,name,value,order,width)
		return Kit.new("TextBox",{Name=name,Text=value,PlaceholderText=name,ClearTextOnFocus=false,Font=Theme.Font.Heavy,TextSize=17,TextColor3=Theme.Color.Text,BackgroundColor3=Theme.Color.Backdrop,
			Size=UDim2.fromOffset(width or 110,40),LayoutOrder=order,Parent=host},{Kit.corner(),Kit.stroke(Theme.Color.Line,1)})
	end
	local function button(host,name,order,callback)
		local b=Kit.button(name,Theme.Color.Quick,Theme.Color.QuickDeep,{Name=name,LayoutOrder=order,Size=UDim2.fromOffset(160,40),Parent=host})
		b.Activated:Connect(callback);return b
	end
	local selected=Cards.List[1].Id
	local selectedName=Kit.label({Name="SelectedCard",Text="Card: "..Cards.List[1].Name,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,24),LayoutOrder=3,Parent=pane},18)
	local searchRow=row("FindCard",4)
	local search=field(searchRow,"Search cards","",1,400)
	local list=Kit.new("ScrollingFrame",{Name="CardPicker",BackgroundColor3=Theme.Color.Backdrop,BorderSizePixel=0,Size=UDim2.new(1,0,0,135),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=6,LayoutOrder=5,Parent=pane},
		{Kit.new("UIListLayout",{Padding=UDim.new(0,4)})})
	local function filter()
		for _,v in list:GetChildren() do if v:IsA("GuiObject") then v:Destroy() end end
		for i,card in Cards.List do
			if search.Text=="" or string.find(string.lower(card.Name),string.lower(search.Text),1,true) then
				local b=Kit.button(card.Name.." · "..card.Type,Theme.Color.PanelLight,Theme.Color.Panel,{Name=card.Id,Size=UDim2.new(1,-8,0,32),LayoutOrder=i,Parent=list})
				b.Activated:Connect(function() selected=card.Id;selectedName.Text="Card: "..card.Name end)
			end
		end
	end
	search:GetPropertyChangedSignal("Text"):Connect(filter);filter()
	local cardRow=row("GrantCard",6)
	local border="Normal"
	Controls.Option(cardRow,"Border",{"Normal","Gold","Rainbow","Secret"},1,function(v) border=v end)
	local copies=field(cardRow,"Copies","1",2)
	button(cardRow,"GIVE CARD",3,function() call("GrantCard",{CardId=selected,Border=border,Count=tonumber(copies.Text)}) end)
	local luckRow=row("CustomLuck",7)
	local luck=field(luckRow,"Luck","100",1)
	button(luckRow,"SET LUCK",2,function() call("SetLuck",tonumber(luck.Text)) end)
	button(luckRow,"USE EARNED LUCK",3,function() call("ClearDevLuck") end)
	local resourceRow=row("Resources",8)
	local kind="TraitShards"
	Controls.Option(resourceRow,"Resource",{"TraitShards","Fragments"},1,function(v) kind=v end)
	local amount=field(resourceRow,"Amount","1000",2)
	button(resourceRow,"GIVE RESOURCE",3,function() call("GrantResource",{Kind=kind,Amount=tonumber(amount.Text)}) end)
	local packRow=row("Packs",9)
	local pack="10"
	Controls.Option(packRow,"Pack size",{"10","100","1000"},1,function(v) pack=v end)
	local packCount=field(packRow,"Pack count","100",2)
	button(packRow,"GIVE PACKS",3,function() call("GrantPack",{Id=pack,Count=tonumber(packCount.Text)}) end)
	local skyRow=row("SkyPreview",10)
	local sky,names="clear",{}
	for _,v in Weather.List do table.insert(names,v.Name) end
	Controls.Option(skyRow,"Sky",names,1,function(v) for _,def in Weather.List do if def.Name==v then sky=def.Id end end end)
	local duration=field(skyRow,"Seconds","180",2)
	button(skyRow,"SET SKY",3,function() call("SetWeather",{Id=sky,Seconds=tonumber(duration.Text)}) end)
	local profileRow=row("ProfileTools",11)
	local level=field(profileRow,"Level","100",1)
	button(profileRow,"SET LEVEL",2,function() call("SetLevel",tonumber(level.Text)) end)
	button(profileRow,"SKY ITEM KIT",3,function() call("GiveSkyItems") end)
	local cooldownRow=row("CooldownTools",12)
	button(cooldownRow,"RESET BOSS TIMERS",1,function() call("ClearBossCooldowns") end)
end
return Pane
