-- Backdoor scanner: paste into Studio's command bar (View > Command Bar) and press Enter. Read-only unless
-- DELETE is true. It lists every script in the place that Rojo doesn't manage (our code lives only in
-- ServerScriptService.Server, StarterPlayer.StarterPlayerScripts.Client, ReplicatedStorage.Shared and
-- ReplicatedStorage.Configs) and flags the ones whose source looks like a free-model backdoor: loading
-- assets by id (GetObjects / InsertService / require(number)), running strings (loadstring / getfenv),
-- or the fake "Error 501 ... paste this into the command bar" screen.
-- 1. Run it as is and read the Output. 2. Set DELETE = true and run again to delete what it flagged.
-- 3. Save / publish. Never paste code a game screen asks you to paste.
local DELETE = false

local OURS = {
	game:GetService("ServerScriptService"):FindFirstChild("Server"),
	game:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client"),
	game:GetService("ReplicatedStorage"):FindFirstChild("Shared"),
	game:GetService("ReplicatedStorage"):FindFirstChild("Configs"),
}
local PATTERNS = {
	"GetObjects", "InsertService", "LoadAsset", "loadstring", "getfenv", "setfenv",
	"require%s*%(%s*%d", "Error 501", "command bar", "Ctrl %+ C", "rbxassetid://%d+'%)%[1%]",
	"HttpService", "PostAsync", "string%.reverse", "\\%d%d%d\\%d%d%d",
}

local function ours(inst: Instance): boolean
	for _, root in OURS do
		if root and (inst == root or inst:IsDescendantOf(root)) then
			return true
		end
	end
	return false
end

local found, flagged = 0, {}
for _, d in game:GetDescendants() do
	local ok, isScript = pcall(function()
		return d:IsA("LuaSourceContainer")
	end)
	if ok and isScript and not ours(d) then
		found += 1
		local source = ""
		pcall(function()
			source = (d :: any).Source
		end)
		local hits = {}
		for _, p in PATTERNS do
			if string.find(source, p) then
				table.insert(hits, p)
			end
		end
		if #hits > 0 then
			table.insert(flagged, d)
			warn(`[scan] SUSPICIOUS {d.ClassName} {d:GetFullName()}  ({table.concat(hits, ", ")})`)
		else
			print(`[scan] other script (check it): {d.ClassName} {d:GetFullName()}`)
		end
	end
end
-- The fake error screen itself may sit in StarterGui as a ScreenGui.
for _, gui in game:GetService("StarterGui"):GetDescendants() do
	if gui:IsA("TextLabel") or gui:IsA("TextBox") then
		local text = gui.Text
		if string.find(text, "Error 501") or string.find(text, "GetObjects") or string.find(text, "command bar") then
			local screen = gui:FindFirstAncestorWhichIsA("ScreenGui") or gui
			table.insert(flagged, screen)
			warn(`[scan] FAKE ERROR SCREEN {screen:GetFullName()}`)
		end
	end
end
print(`[scan] {found} script(s) outside our code, {#flagged} flagged`)
if DELETE then
	for _, inst in flagged do
		if inst.Parent then
			print(`[scan] deleting {inst:GetFullName()}`)
			inst:Destroy()
		end
	end
	print("[scan] done: save / publish the place now")
end
