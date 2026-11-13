--!nonstrict
local Shared = game:GetService("ReplicatedStorage").Shared
local Bosses = require(Shared.Bosses)
local Hunts = require(Shared.CardHunts)
local State = require(script.Parent.Parent.State)
local Kit = require(script.Parent.Kit)
local Modal = require(script.Parent.Modal)
local Theme = require(script.Parent.Theme)
local CardTile = require(script.Parent.CardTile)

local Board = {}
local modal, cards, note, startFight
local busy = false

function Board.Init(playerGui, start)
	startFight = start
	modal = Modal.new(playerGui, "HuntGui", "CARD HUNTS", Vector2.new(.76,.84), Vector2.new(800,550))
	note = Kit.label({Name="Brief", Font=Theme.Font.Bold, TextColor3=Theme.Color.Text,
		TextWrapped=true, Size=UDim2.fromScale(1,.15), Parent=modal.Body}, 19)
	cards = Kit.new("Frame", {BackgroundTransparency=1, Position=UDim2.fromScale(0,.17),
		Size=UDim2.fromScale(1,.81), Parent=modal.Body})
end

function Board.Open(world)
	if busy then return end
	local boss = Bosses.Get(world)
	if not boss then return end
	cards:ClearAllChildren()
	local open = Bosses.IsUnlocked(State.Progress.Cleared,world,"Normal")
	note.Text = if open then boss.WorldName .. " · Choose a Gold card to earn."
		else "Clear the previous world's Normal boss to unlock these hunts."
	for i, hunt in Hunts.ByWorld[world] do
		local guard = Bosses.GuardTypes[boss.Guards[tonumber(hunt.Guard:sub(2))]]
		local complete = (State.Progress.Hunts or {})[hunt.Card] == true
		local plate = Kit.tile({Position=UDim2.fromScale((i-1)*.51,0),Size=UDim2.fromScale(.49,1),Parent=cards}, Theme.Color.Gold)
		local art = CardTile.new(hunt.Card,{Owned=true,Border="Gold"})
		art.AnchorPoint=Vector2.new(.5,0)
		art.Position=UDim2.fromScale(.5,.03)
		art.Size=UDim2.fromScale(.8,.57)
		art.Parent=plate
		Kit.new("UIAspectRatioConstraint",{AspectRatio=1,Parent=art})
		Kit.label({Text="Tap " .. guard.Name .. " to mark them. Defeat them, then the boss.",
			Font=Theme.Font.Medium,TextWrapped=true,Position=UDim2.fromScale(.04,.60),Size=UDim2.fromScale(.92,.19),Parent=plate},16)
		local button=Kit.button(if complete then "GOLD CLAIMED" elseif open then "HUNT THIS CARD" else "LOCKED",
			Theme.Color.Gold,Color3.fromRGB(110,70,23),{Position=UDim2.fromScale(.05,.82),Size=UDim2.fromScale(.90,.15),Parent=plate})
		Kit.dim(button,complete or not open)
		local function choose()
			if busy or complete or not open or not modal.IsOpen then return end
			busy=true
			local ok, reason=startFight(world,"Normal",{Hunt=hunt.Card})
			busy=false
			if ok then modal:Close() else note.Text=reason or "Unable to start the hunt." end
		end
		button.Activated:Connect(choose)
		art.Activated:Connect(choose)
	end
	modal:Open()
end
return Board
