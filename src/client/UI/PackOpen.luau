--!nonstrict
-- Opening Roll Packs (Packs.luau) on the client: asks the server to open one, keeps the client's copy of
-- the player's cards and packs in step, and plays it: the rarest pulls flip one by one (RewardReveal)
-- under a line that sums up everything the pack gave.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Packs = require(Shared.Packs)
local Borders = require(Shared.Borders)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local Kit = require(script.Parent.Kit)
local Theme = require(script.Parent.Theme)
local RewardReveal = require(script.Parent.RewardReveal)
local State = require(script.Parent.Parent.State)

local PackOpen = {}

local REASONS = {
	TooFast = "One moment...",
	InBattle = "Finish the fight first",
	AutoActive = "Turn off Auto Roll first",
	NoPacks = "You don't have that pack",
	Loading = "Still loading",
}

-- Opens one pack of `packId`. Returns the server's result, or nil and a message.
function PackOpen.Open(packId: string): (any, string?)
	local ok, result = pcall(function()
		return Remotes.OpenPack:InvokeServer(packId)
	end)
	if not ok or result == nil or not result.Ok then
		return nil, if ok and result then REASONS[result.Reason] or "Couldn't open it" else "Couldn't open it, try again"
	end
	for id, entry in result.Cards or {} do
		State.Cards[id] = entry
	end
	if result.Quests then
		State.Meta.Quests = result.Quests
	end
	State.ApplyPacks(result.Packs)
	if result.Meta then
		State.ApplyMeta(result.Meta)
	end
	return result, nil
end

-- "100 rolls at 2.40x luck · 3 NEW · Legendary 2 · Epic 9 · Rare 30 ..." (rarest first).
function PackOpen.SummaryText(result): string
	local parts = { `{result.Rolls} rolls at {string.format("%.2f", result.Luck or 1)}x luck` }
	if (result.New or 0) > 0 then
		table.insert(parts, `<font color="#FFC42E"><b>{result.New} NEW</b></font>`)
	end
	for i = #Borders.Order, 1, -1 do
		local id = Borders.Order[i]
		local count = result.Counts and result.Counts[id]
		if count and count > 0 then
			table.insert(parts, `<font color="#{Borders.Get(id).Color:ToHex()}">{Borders.Get(id).Name} {Kit.commas(count)}</font>`)
		end
	end
	return table.concat(parts, "  ·  ")
end

-- Plays an opened pack inside `area`: the summary line on top and the rarest pulls flipping below.
function PackOpen.Play(area: Frame, result, onDone: (() -> ())?)
	local pack = Packs.ById[result.PackId]
	Kit.label({
		Name = "PackSummary",
		Text = `{if pack then pack.Icon .. " " .. string.upper(pack.Name) .. "  ·  " else ""}{PackOpen.SummaryText(result)}`,
		RichText = true,
		Font = Theme.Font.Heavy,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = area,
	}, 18)
	local fan = Kit.new("Frame", {
		Name = "Fan",
		Position = UDim2.new(0, 0, 0, 46),
		Size = UDim2.new(1, 0, 1, -46),
		BackgroundTransparency = 1,
		Parent = area,
	})
	RewardReveal.Play(fan, { Results = result.Results, Summary = result.Summary }, onDone)
end

return PackOpen
