--!nonstrict
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Shared=ReplicatedStorage:WaitForChild("Shared")
local Catalog=require(Shared.Collections)
local Cards=require(Shared.Cards)
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
local function refresh()
	if not modal or not modal.IsOpen then return end
	local def=Catalog.ById[selected]
	heading.Text=def.Name
	for id,button in choiceButtons do
		Kit.surface(button,if id==selected then Theme.Color.Info else Theme.Color.PanelLight,if id==selected then Theme.Color.InfoDeep else Theme.Color.Panel)
	end
	local unlocked=Catalog.Unlocked(selected,State.Progress.Cleared)
	local active=State.Summary.SelectedCollection==selected
	info.Text=def.Text .. "\n" .. (if unlocked then "Unlocked boss cards stay eligible. Sky cards are separate rare finds while their sky is active." else "Unlock: " .. def.Unlock)
	choose.Label.Text=if active then "ACTIVE COLLECTION" elseif unlocked then "SELECT COLLECTION" else "LOCKED"
	Kit.dim(choose,not unlocked or active)
	for _,child in preview:GetChildren() do if child:IsA("GuiObject") then child:Destroy() end end
	local cleared=table.clone(State.Progress.Cleared)
	cleared[def.Unlock]=true -- browsing shows a locked collection's contents, never grants access
	local pool=Catalog.Pool(selected,cleared)
	local chances=Cards.PullChances(pool,nil,nil,Cards.FeaturedAt(os.time()))
	for i,card in pool do
		local cell=Kit.new("Frame",{LayoutOrder=i,BackgroundTransparency=1,Parent=preview})
		local tile=CardTile.new(card.Id,{Owned=true,Border="Normal"})
		tile.Size=UDim2.new(1,0,1,-24);tile.Parent=cell
		Kit.label({Text=string.format("%.2f%% card chance",chances[card.Id]*100),Position=UDim2.new(0,0,1,-22),Size=UDim2.new(1,0,0,20),Parent=cell},12)
	end
end
function Collections.Init(playerGui)
	modal=Modal.new(playerGui,"CollectionsGui","CARD PACKS",Vector2.new(.9,.88),Vector2.new(1120,760))
	choices=Kit.new("Frame",{BackgroundTransparency=1,Size=UDim2.new(.26,-10,1,0),Parent=modal.Body},{Kit.new("UIListLayout",{Padding=UDim.new(0,8)})})
	for i,def in Catalog.List do
		local button=Kit.button(def.Name,Theme.Color.PanelLight,Theme.Color.Panel,{LayoutOrder=i,Size=UDim2.new(1,0,0,58),Parent=choices})
		choiceButtons[def.Id]=button
		button.Activated:Connect(function() selected=def.Id;refresh() end)
	end
	local right=Kit.new("Frame",{BackgroundTransparency=1,Position=UDim2.fromScale(.27,0),Size=UDim2.fromScale(.73,1),Parent=modal.Body})
	heading=Kit.label({Text="",Font=Theme.Font.Display,TextXAlignment=Enum.TextXAlignment.Left,Size=UDim2.new(1,0,0,30),Parent=right},24)
	info=Kit.label({Text="",TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,Position=UDim2.fromOffset(0,36),Size=UDim2.new(1,0,0,54),Parent=right},15)
	choose=Kit.button("SELECT COLLECTION",Theme.Color.Gold,Color3.fromRGB(140,90,20),{Position=UDim2.fromOffset(0,96),Size=UDim2.new(1,0,0,40),Parent=right})
	choose.Activated:Connect(function()
		if busy or not Catalog.Unlocked(selected,State.Progress.Cleared) then return end
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
	State.Changed:Connect(function(kind) if kind~="roll" then refresh() end end)
end
function Collections.Open() modal:Open() end
return Collections
