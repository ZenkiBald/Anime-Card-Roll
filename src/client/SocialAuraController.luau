--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Cards = require(ReplicatedStorage.Shared.Cards)
local Borders = require(ReplicatedStorage.Shared.Borders)
local Showcase = require(script.Parent.Showcase)
local Kit = require(script.Parent.UI.Kit)
local Social = {}

function Social.Start()
	local anchor, slab, animation
	local function clear()
		if animation then animation:Disconnect(); animation = nil end
		if slab then slab:Destroy(); slab = nil end
	end
	local function refresh()
		clear()
		local map = workspace:FindFirstChild("Map")
		local town = map and map:FindFirstChild("Town")
		local pedestal = workspace:FindFirstChild("LegendPedestal") or (town and town:FindFirstChild("LegendPedestal"))
		anchor = pedestal and pedestal:FindFirstChild("DisplayAnchor")
		local record = ReplicatedStorage:GetAttribute("ServerLegend")
		if not anchor or not anchor:IsA("BasePart") or type(record) ~= "string" then return end
		local info = HttpService:JSONDecode(record)
		local card = Cards.Get(info.CardId)
		if not card then return end
		local border = Borders.Get(info.Border)
		slab = Instance.new("Part")
		slab.Name = "ServerLegendCard"
		slab.Size = Vector3.new(4.6, 6.5, 0.14)
		slab.Color = border.Color
		slab.Anchored = true
		slab.CanCollide, slab.CanQuery, slab.CanTouch, slab.CastShadow = false, false, false, false
		slab.CFrame = anchor.CFrame
		Showcase.Faces(slab, card.Id, info.Border)
		local label = Instance.new("BillboardGui")
		label.Name = "LegendCaption"
		label.Size = UDim2.fromOffset(240, 72)
		label.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
		label.MaxDistance = 90
		label.LightInfluence = 0
		label.Parent = slab
		local function line(name, caption, y, color)
			Kit.label({ Name = name, Text = caption, TextColor3 = color,
				Position = UDim2.fromScale(0, y), Size = UDim2.fromScale(1, 1/3), Parent = label }, 19)
		end
		line("CardName", card.Name, 0, Color3.new(1, 1, 1))
		line("BorderRarity", border.Name .. " · 1 in " .. Kit.commas(info.Rarity), 1/3, border.Color)
		line("Owner", "@" .. info.Owner, 2/3, Color3.fromRGB(200, 226, 255))
		slab.Parent = anchor
		animation = RunService.RenderStepped:Connect(function()
			slab.CFrame = anchor.CFrame * CFrame.new(0, 0.28 * math.sin(workspace:GetServerTimeNow() * 1.6), 0)
		end)
	end
	ReplicatedStorage:GetAttributeChangedSignal("ServerLegend"):Connect(refresh)
	workspace.DescendantAdded:Connect(function(instance)
		if instance.Name == "DisplayAnchor" and instance.Parent and instance.Parent.Name == "LegendPedestal" then
			task.defer(refresh)
		end
	end)
	workspace.DescendantRemoving:Connect(function(instance)
		if instance == anchor then anchor = nil; clear() end
	end)
	refresh()
end
return Social
