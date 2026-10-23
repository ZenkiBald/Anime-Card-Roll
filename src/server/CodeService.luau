--!nonstrict
-- CODES: the Redeem remote takes a code, checks it against Codes.luau (server-only), and pays its
-- reward once per player (saved in Codes[CODE] = true). Rate-limited so codes can't be guessed fast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes
local DataService = require(script.Parent.DataService)
local MetaService = require(script.Parent.MetaService)
local RateLimit = require(script.Parent.RateLimit)
local CODES = require(script.Parent.Codes)

local CodeService = {}

local limiter = RateLimit.new(0.5, 3) -- three tries at once, then one every 2 s

local byCode = {}
for _, entry in CODES do
	byCode[string.upper(entry.Code)] = entry
end

local function redeem(player: Player, text: unknown)
	if type(text) ~= "string" or #text > 40 then
		return { Ok = false, Reason = "Invalid" }
	end
	if not limiter:Allow(player) then
		return { Ok = false, Reason = "TooFast" }
	end
	local profile = DataService.Get(player)
	if profile == nil then
		return { Ok = false, Reason = "Loading" }
	end
	local code = string.upper((string.gsub(text, "%s", "")))
	local entry = byCode[code]
	if entry == nil then
		return { Ok = false, Reason = "Invalid" }
	end
	if entry.Expires and os.time() > entry.Expires then
		return { Ok = false, Reason = "Expired" }
	end
	local data = profile.Data
	if data.Codes[code] then
		return { Ok = false, Reason = "Used" }
	end
	data.Codes[code] = true
	local granted = MetaService.Grant(data, entry.Reward, player)
	return { Ok = true, Granted = granted, Meta = MetaService.State(player, data) }
end

function CodeService.Start()
	Remotes.Redeem.OnServerInvoke = redeem
end

return CodeService
