--!strict
-- Per-player token bucket for remotes: `burst` requests at once, refilling at `perSecond`.

local Players = game:GetService("Players")

export type Limiter = { Allow: (self: Limiter, player: Player) -> boolean }

local RateLimit = {}

function RateLimit.new(perSecond: number, burst: number): Limiter
	local buckets: { [Player]: { Tokens: number, At: number } } = {}
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)

	local limiter = {}
	function limiter.Allow(_self, player: Player): boolean
		local now = os.clock()
		local bucket = buckets[player]
		if bucket == nil then
			bucket = { Tokens = burst, At = now }
			buckets[player] = bucket
		end
		bucket.Tokens = math.min(burst, bucket.Tokens + (now - bucket.At) * perSecond)
		bucket.At = now
		if bucket.Tokens < 1 then
			return false
		end
		bucket.Tokens -= 1
		return true
	end
	return limiter :: any
end

return RateLimit
