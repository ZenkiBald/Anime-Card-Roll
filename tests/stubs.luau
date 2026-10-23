-- Minimal stand-ins for the Roblox types the shared modules touch at load time.
local Color3mt = {}
Color3mt.__index = Color3mt
Color3 = {}
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3mt) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3.fromHSV(h, s, v) return Color3.new(v, v, v) end
function Color3mt:ToHSV() return 0, 0.5, math.max(self.R, self.G, self.B) end
function Color3mt:Lerp(o, a) return Color3.new(self.R + (o.R - self.R) * a, self.G + (o.G - self.G) * a, self.B + (o.B - self.B) * a) end
function Color3mt:ToHex() return "FFFFFF" end
ColorSequence = { new = function(...) return { ... } end }
ColorSequenceKeypoint = { new = function(t, c) return { t, c } end }
Random = {}
Random.__index = Random
function Random.new(seed)
	math.randomseed(seed or 12345)
	return setmetatable({}, Random)
end
function Random:NextNumber() return math.random() end
function Random:NextInteger(a, b) return math.random(a, b) end
