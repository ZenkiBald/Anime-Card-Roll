--!nonstrict
-- A read-only sky card: status, time, bonus and eligible portraits. Consumables stay in BAG.
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage.Shared
local Weather=require(Shared.Weather)
local Cards=require(Shared.Cards)
local Config=require(Shared.Config)
local Kit=require(script.Parent.Kit)
local Theme=require(script.Parent.Theme)
local Modal=require(script.Parent.Modal)
local State=require(script.Parent.Parent.State)
local Hud=require(script.Parent.Hud)
local Title=require(script.Parent.Title)
local PlayerList=require(script.Parent.PlayerList)
local Ui={}
local current=Weather.At(0)
local gui,pane,kicker,title,timer,timeLabel,subtitle,bonus,caption,strip,footer,fill,edge,fit
local shown=""
local function clock(seconds)
	seconds=math.max(0,math.ceil(seconds))
	return string.format("%d:%02d",seconds//60,seconds%60)
end
local function refresh()
	if not pane then return end
	local short=gui.AbsoluteSize.Y<540
	local expanded,listBottom=PlayerList.Bounds()
	pane.Visible=not Title.IsOpen() and not Modal.AnyOpen() and (not State.InBattle or State.BattleHidden) and not (short and expanded)
	local now=workspace:GetServerTimeNow()
	local active=current.Id~="clear" and current.Ends>now
	local forecast=not active and current.Forecast and current.Next
	local preview=if active then current.Id elseif forecast then current.Next.Id else "clear"
	local def=Weather.ById[preview]
	local hasCards=Config.CelestialCardsReady and preview~="clear"
	kicker.Text=if active then "ACTIVE SKY" elseif forecast then "ARRIVING SOON" else "SKY STATUS"
	title.Text=string.upper(def.Name)
	subtitle.Text=if active or forecast then def.Series else "Normal cards are always available"
	bonus.Text=if active then string.format("+%gx luck",def.Luck) elseif forecast then "FORECAST" else "CALM"
	bonus.TextColor3=Theme.Color.Luck
	timer.Text=if active then clock(current.Ends-now) elseif current.Next then clock(current.Next.Starts-now) else "--:--"
	timeLabel.Text=if active then "TIME LEFT" else "NEXT SKY"
	footer.Text=if hasCards then (if active then "Roll / AUTO / packs · 1 sky search / sec" else "Available when this sky arrives") else "Sky items and potions are in BAG"
	caption.Text=if active then "EXCLUSIVE ATTACK CARDS · ROLLABLE NOW" else "UPCOMING EXCLUSIVE CARDS"
	caption.Visible=hasCards;strip.Visible=hasCards
	edge.Color=def.Color
	pane.Size=UDim2.fromOffset(330,if hasCards then 238 else 104)
	footer.Position=UDim2.new(0,12,1,-26)
	local duration=if active then math.max(1,current.Ends-current.Starts) else 150
	local left=if active then current.Ends-now elseif forecast then current.Next.Starts-now else 0
	fill.Size=UDim2.fromScale(math.clamp(left/duration,0,1),1)
	fill.BackgroundColor3=def.Color
	fill.Parent.Visible=active or forecast
	local discoveries={}
	for _,card in Cards.WeatherPool(preview) do
		local own=State.Cards[card.Id]
		table.insert(discoveries,if own and (own.Copies or 0)>0 then "1" else "0")
	end
	local key=preview..tostring(hasCards)..table.concat(discoveries)
	if key~=shown then
		shown=key
		for _,child in strip:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
		if hasCards then
			for i,card in Cards.WeatherPool(preview) do
				local own=State.Cards[card.Id]
				local discovered=own and (own.Copies or 0)>0
				local cell=Kit.new("Frame",{Name=card.Id,LayoutOrder=i,Size=UDim2.fromOffset(71,104),BackgroundColor3=Color3.fromRGB(17,21,38),Parent=strip},{Kit.corner(),Kit.stroke(def.Color,1.5,.15)})
				Kit.surface(cell,Color3.fromRGB(18,26,40),Color3.fromRGB(5,9,17))
				cell:SetAttribute("Discovered",discovered==true)
				Kit.new("ImageLabel",{Name="Portrait",Image=if discovered then card.Image or "" else "",ScaleType=Enum.ScaleType.Crop,Size=UDim2.new(1,-4,1,-22),Position=UDim2.fromOffset(2,2),BackgroundTransparency=1,Parent=cell},{Kit.corner()})
				Kit.label({Name="Mystery",Text="?",Visible=not discovered,TextColor3=Theme.Color.Muted,Position=UDim2.fromScale(.2,.15),Size=UDim2.fromScale(.6,.52),Parent=cell},38)
				Kit.label({Name="Rarity",Text=Kit.commas(card.SkyOneIn),TextColor3=Theme.Color.Gold,Position=UDim2.fromScale(.05,.64),Size=UDim2.fromScale(.9,.16),ZIndex=4,Parent=cell},13)
				local name=string.match(card.Id,"_([^_]+)$") or card.Name
				name=string.upper(string.sub(name,1,1))..string.sub(name,2)
				if name=="Yuta" then name="Yuta & Rika" end
				Kit.label({Name="CharacterName",Text=if discovered then name else "???",Position=UDim2.new(0,2,1,-21),Size=UDim2.new(1,-4,0,19),Parent=cell},12)
			end
		end
	end
	fit.Scale=if short then 1 else math.min(1,gui.AbsoluteSize.X*.25/330)
	pane.Size=UDim2.fromOffset(if short then 236 else 330,if hasCards then (if short then 146 else 238) else (if short then 86 else 104))
	pane.Position=UDim2.new(1,-14,0,if expanded then math.max(52,listBottom+8) elseif short then 42 else 52)
	kicker.Position=UDim2.fromOffset(if short then 10 else 12,if short then 5 else 7)
	kicker.Size=UDim2.fromOffset(if short then 150 else 210,if short then 10 else 13)
	kicker.TextSize=if short then 8 else 11
	title.Position=UDim2.fromOffset(if short then 10 else 12,if short then 18 else 23)
	title.Size=UDim2.fromOffset(if short then 158 else 220,if short then 20 else 25)
	title.TextSize=if short then 16 else 23
	timer.Position=UDim2.fromOffset(if short then 178 else 242,if short then 18 else 23)
	timer.Size=UDim2.fromOffset(if short then 48 else 76,if short then 22 else 26)
	timer.TextSize=if short then 20 else 25
	timeLabel.Position=UDim2.fromOffset(if short then 176 else 245,if short then 5 else 7)
	timeLabel.Size=UDim2.fromOffset(if short then 52 else 73,if short then 10 else 13)
	timeLabel.TextSize=if short then 8 else 10
	subtitle.Position=UDim2.fromOffset(if short then 10 else 12,if short then 40 else 53)
	subtitle.Size=UDim2.fromOffset(if short then 150 else 214,if short then 14 else 17)
	subtitle.TextSize=if short then 11 else 14
	bonus.Position=UDim2.fromOffset(if short then 162 else 225,if short then 40 else 53)
	bonus.Size=UDim2.fromOffset(if short then 64 else 93,if short then 14 else 17)
	bonus.TextSize=if short then 10 else 14
	caption.Visible=hasCards and not short
	strip.Position=UDim2.fromOffset(if short then 10 else 12,if short then 60 else 96)
	strip.Size=UDim2.fromOffset(if short then 216 else 306,if short then 64 else 104)
	strip.UIListLayout.Padding=UDim.new(0,if short then 6 else 7)
	for _,cell in strip:GetChildren() do
		if cell:IsA("Frame") then
			cell.Size=UDim2.fromOffset(if short then 49.5 else 71,if short then 64 else 104)
			cell.Portrait.Size=UDim2.new(1,-4,1,if short then -18 else -22)
			cell.CharacterName.Position=UDim2.new(0,2,1,if short then -17 else -21)
			cell.CharacterName.Size=UDim2.new(1,-4,0,if short then 15 else 19)
			cell.CharacterName.TextSize=if short then 10 else 12
		end
	end
	footer.Position=UDim2.new(0,if short then 10 else 12,1,if short then -18 else -26)
	footer.Size=UDim2.fromOffset(if short then 216 else 306,if short then 12 else 17)
	footer.TextSize=if short then 10 else 12
	if short and hasCards then footer.Text=if active then "Rare sky finds · 1 search / sec" else "Available when this sky starts" end

end
function Ui.Init(playerGui)
	gui=Kit.screenGui("SkyHud",2,playerGui)
	gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets
	pane=Kit.new("Frame",{Name="WeatherStatus",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,52),Size=UDim2.fromOffset(330,104),BackgroundColor3=Color3.fromRGB(24,29,52),Parent=gui},{Kit.corner(UDim.new(0,12)),Kit.gradient(ColorSequence.new(Color3.fromRGB(38,44,76),Color3.fromRGB(14,18,34)),90)})
	edge=Kit.stroke(Theme.Color.Line,2,0);edge.Parent=pane
	fit=Kit.new("UIScale",{Parent=pane})
	kicker=Kit.label({Name="Status",Text="",TextColor3=Color3.fromRGB(180,193,217),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(12,7),Size=UDim2.fromOffset(210,13),Parent=pane},11)
	title=Kit.label({Name="SkyName",Text="",Font=Theme.Font.Display,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(12,23),Size=UDim2.fromOffset(220,25),Parent=pane},23)
	timeLabel=Kit.label({Text="TIME LEFT",TextColor3=Color3.fromRGB(180,193,217),Position=UDim2.fromOffset(245,7),Size=UDim2.fromOffset(73,13),Parent=pane},10)
	timer=Kit.label({Name="Countdown",Text="",Font=Theme.Font.Display,Position=UDim2.fromOffset(242,23),Size=UDim2.fromOffset(76,26),Parent=pane},25)
	subtitle=Kit.label({Name="Series",Text="",TextColor3=Color3.fromRGB(211,219,236),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(12,53),Size=UDim2.fromOffset(214,17),Parent=pane},14)
	bonus=Kit.label({Name="LuckBonus",Text="",TextXAlignment=Enum.TextXAlignment.Right,Position=UDim2.fromOffset(225,53),Size=UDim2.fromOffset(93,17),Parent=pane},14)
	caption=Kit.label({Text="",TextColor3=Color3.fromRGB(180,193,217),TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(12,77),Size=UDim2.fromOffset(306,15),Parent=pane},10)
	strip=Kit.new("Frame",{Name="AvailableCards",BackgroundTransparency=1,Position=UDim2.fromOffset(12,96),Size=UDim2.fromOffset(306,104),Parent=pane},{Kit.new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,7),SortOrder=Enum.SortOrder.LayoutOrder})})
	footer=Kit.label({Name="Hint",Text="",TextColor3=Color3.fromRGB(180,193,217),TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.fromOffset(306,17),Parent=pane},12)
	local track=Kit.new("Frame",{Name="TimeTrack",Position=UDim2.new(0,12,1,-5),Size=UDim2.new(1,-24,0,2),BackgroundColor3=Color3.fromRGB(12,15,28),BorderSizePixel=0,Parent=pane})
	fill=Kit.new("Frame",{Name="Fill",Size=UDim2.fromScale(1,1),BorderSizePixel=0,Parent=track})
	ReplicatedStorage.Remotes.WeatherState.OnClientEvent:Connect(function(state)
		local previous=current.Key
		current=state;State.Weather=state
		if state.Announcement then Hud.Hint(state.Announcement) end
		if previous~=state.Key then State.Notify("weather") end
		refresh()
	end)
	Modal.Changed:Connect(refresh)
	State.Changed:Connect(refresh)
	PlayerList.Changed:Connect(refresh)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refresh)
	task.spawn(function() while true do refresh();task.wait(1) end end)
end
return Ui
