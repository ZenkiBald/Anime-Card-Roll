-- Pushes src/ (served by python http.server on 127.0.0.1:34875) into the open place, like rojo serve.
local H = game:GetService("HttpService")
local base = "http://127.0.0.1:34875/"
local roots = {
	shared = game.ReplicatedStorage.Shared,
	server = game.ServerScriptService.Server,
	client = game.StarterPlayer.StarterPlayerScripts.Client,
}
local was = H.HttpEnabled
H.HttpEnabled = true
local changed, created = {}, {}
local function list(path)
	local html = H:GetAsync(base .. path)
	local out = {}
	for href in html:gmatch('href="([^"]+)"') do
		table.insert(out, href)
	end
	return out
end
local function sync(path, parent)
	for _, href in list(path) do
		if href:sub(-1) == "/" then
			local name = href:sub(1, -2)
			local folder = parent:FindFirstChild(name)
			if not folder then
				folder = Instance.new("Folder")
				folder.Name = name
				folder.Parent = parent
				table.insert(created, path .. name)
			end
			sync(path .. href, folder)
		elseif href:match("%.luau$") then
			local name, class = href:match("^(.-)%.server%.luau$"), "Script"
			if not name then
				name, class = href:match("^(.-)%.client%.luau$"), "LocalScript"
			end
			if not name then
				name, class = href:match("^(.-)%.luau$"), "ModuleScript"
			end
			local source = H:GetAsync(base .. path .. href):gsub("\r\n", "\n")
			local inst = parent:FindFirstChild(name)
			if not inst then
				inst = Instance.new(class)
				inst.Name = name
				inst.Source = source
				inst.Parent = parent
				table.insert(created, path .. href)
			elseif inst.Source ~= source then
				inst.Source = source
				table.insert(changed, path .. href)
			end
		end
	end
end
local ok, err = pcall(function()
	for dir, root in roots do
		sync(dir .. "/", root)
	end
end)
H.HttpEnabled = was
return (ok and "" or ("ERROR " .. tostring(err) .. "\n")) .. "changed: " .. table.concat(changed, ", ") .. "\ncreated: " .. table.concat(created, ", ")
