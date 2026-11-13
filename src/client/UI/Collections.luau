--!nonstrict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Catalog=require(Shared.Collections)
local Cards=require(Shared.Cards)
local Bosses=require(Shared.Bosses)
local Kit=require(script.Parent.Kit)
local Theme=require(script.Parent.Theme)
local Modal=require(script.Parent.Modal)
local CardTile=require(script.Parent.CardTile)
local State=require(script.Parent.Parent.State)
local Collections={}
local modal, preview, heading, info, choose, choices
local selected="normal"
local choiceButtons={}
local busy=false
local lastSelection, lastPreview
local previewCells = {}
local function refresh()
	if not modal or not modal.IsOpen then return end
	local def=Catalog.ById[selected]
	heading.Text=def.Name
	if lastSelection ~= selected then
		lastSelection = selected
		for id,button in choiceButtons do
			Kit.surface(button,if id==selected then Theme.Color.Info else Theme.Color.PanelLight,if id==selected then Theme.Color.InfoDeep else Theme.Color.Panel)
		end
	end
	local unlocked=Catalog.Unlocked(selected,State.Progress.Cleared)
	local active=State.Summary.SelectedCollection==selected
	local cleared = State.Progress.Cleared
	local requirement = ""
	if not unlocked then
		local bossId, difficulty = def.Unlock:match("^([^:]+):(.+)$")
		local boss = Bosses.Get(bossId)
		if boss then requirement = `Unlock by defeating {boss.Name} on {difficulty}. ` end
	end
	local description = if selected == "normal" then "Roll from your full unlocked collection."
		else "Favor this family. Every unlocked card can still drop."
	info.Text = requirement .. description .. "\nROLL, AUTO and Bag packs use your selection."
	choose.Label.Text=if active then "ACTIVE" elseif unlocked then "USE THIS COLLECTION" else "LOCKED"
	Kit.dim(choose,not unlocked or active)
	local previewClears = table.clone(cleared)
	if not unlocked then previewClears[def.Unlock] = true end
	local pool, chances = Catalog.Distribution(selected,previewClears,nil,nil,Cards.FeaturedAt(workspace:GetServerTimeNow()),State.Luck())
	local signature = {selected}
	for _, card in pool do table.insert(signature, card.Id .. string.format("%.2f", chances[card.Id]*100)) end
	local key = table.concat(signature,"|")
	if lastPreview == key then return end
	lastPreview = key
	for id, entry in previewCells do
		if not chances[id] then
			entry.Cell:Destroy()
			previewCells[id] = nil
		end
	end
	table.sort(pool, function(a,b)
		local first = Catalog.CardFamily[a.Id] == selected
		local second = Catalog.CardFamily[b.Id] == selected
		if first ~= second then return first end
		return chances[a.Id] > chances[b.Id] or (chances[a.Id] == chances[b.Id] and a.Id < b.Id)
	end)
	for i,card in pool do
		local entry = previewCells[card.Id]
		if not entry then
			local cell=Kit.new("Frame",{BackgroundTransparency=1,Parent=preview})
			local tile=CardTile.new(card.Id,{Owned=true,Border="Normal"})
			tile.Size=UDim2.new(1,0,1,-24)
			tile.Parent=cell
			local label = Kit.label({Position=UDim2.new(0,0,1,-22),Size=UDim2.new(1,0,0,20),Parent=cell},12)
			entry = {Cell=cell, Label=label}
			previewCells[card.Id] = entry
		end
		entry.Cell.LayoutOrder=i
		entry.Label.Text=string.format("%.2f%% %s", chances[card.Id]*100, if Catalog.CardFamily[card.Id]==selected then "· FOCUSED" else "chance")
	end
end
function Collections.Init(playerGui)
	modal=Modal.new(playerGui,"CollectionsGui","CARD PACKS",Vector2.new(.9,.88),Vector2.new(1120,760))
	choices=Kit.new("Frame",{BackgroundTransparency=1,Size=UDim2.new(.26,-10,1,0),Parent=modal.Body},{Kit.new("UIListLayout",{Padding=UDim.new(0,8)})})
	for i,def in Catalog.List do
		local button=Kit.button(def.Name,Theme.Color.PanelLight,Theme.Color.Panel,{LayoutOrder=i,Size=UDim2.new(1,0,0,58),Parent=choices})
		local cover = Cards.Get(def.Cards[1] or "rook")
		Kit.new("ImageLabel",{Name="Cover",Image=cover.Image,ScaleType=Enum.ScaleType.Crop,BackgroundTransparency=1,
			Size=UDim2.fromOffset(42,48),Position=UDim2.fromOffset(6,5),Parent=button},{Kit.corner(UDim.new(0,6))})
		button.Label.AnchorPoint=Vector2.new(0,.5)
		button.Label.Position=UDim2.new(0,54,.5,0)
		button.Label.Size=UDim2.new(1,-60,.8,0)
		choiceButtons[def.Id]=button
		button.Activated:Connect(function() selected=def.Id;preview.CanvasPosition=Vector2.zero;refresh() end)
	end
	local right=Kit.new("Frame",{BackgroundTransparency=1,Position=UDim2.fromScale(.27,0),Size=UDim2.fromScale(.73,1),Parent=modal.Body})
	heading=Kit.label({Text="",Font=Theme.Font.Display,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,30),Parent=right},24)
	info=Kit.label({Text="",TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(0,36),Size=UDim2.new(1,0,0,54),Parent=right},15)
	choose=Kit.button("SELECT COLLECTION",Theme.Color.Gold,Color3.fromRGB(140,90,20),{Position=UDim2.fromOffset(0,96),Size=UDim2.new(1,0,0,40),Parent=right})
	choose.Activated:Connect(function()
		if busy or selected == State.Summary.SelectedCollection or not Catalog.Unlocked(selected,State.Progress.Cleared) then return end
		busy=true
		local ok,result=pcall(function() return ReplicatedStorage.Remotes.Collection:InvokeServer("Select",selected) end)
		busy=false
		if ok and result and result.Ok then
			State.Summary.SelectedCollection=result.Selected
			State.Progress=result.Progress
			State.Notify("collection")
		else info.Text=if type(result)=="table" and result.Reason=="TooFar" then "Stand beside the Card Packs keeper to change collections." else "Could not select that collection. Try again."; return end
		refresh()
	end)
	preview=Kit.new("ScrollingFrame",{BackgroundTransparency=1,BorderSizePixel=0,Position=UDim2.fromOffset(0,150),Size=UDim2.new(1,0,1,-150),AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ScrollBarThickness=6,Parent=right},{Kit.new("UIGridLayout",{CellSize=UDim2.fromOffset(124,150),CellPadding=UDim2.fromOffset(9,9)})})
	modal.OnOpen=function() selected=State.Summary.SelectedCollection or "normal";refresh() end
	State.Changed:Connect(refresh)
end
function Collections.Open() modal:Open() end
return Collections
