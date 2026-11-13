--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ids: { [string]: string } = {
	SunburstRays = "rbxassetid://5626201485", MagicCircle = "rbxassetid://13086801741",
	CrackOverlay = "rbxassetid://131184670003058", SpeedLines = "rbxassetid://18553799686",
	StarGlint = "rbxassetid://13761580371", SlashVFX = "rbxassetid://81985560792849",
	HitImpactVFX = "rbxassetid://124966368363599",
}
-- A Marketplace Decal ID identifies its container. ImageLabel needs that decal's Texture ID.
-- These texture IDs were read directly from the seven Marketplace decals in Studio.
local textures: { [string]: string } = {
	SpeedLines = "rbxassetid://18553799646",
	SunburstRays = "rbxassetid://5626201475",
	SlashVFX = "rbxassetid://99074144587419",
	CrackOverlay = "rbxassetid://95712963976055",
	StarGlint = "rbxassetid://13761580325",
	MagicCircle = "rbxassetid://13086801689",
	HitImpactVFX = "rbxassetid://99566027026247",
}
local Assets = {}
function Assets.image(parent: Instance, name: string, size: number, layer: number): ImageLabel
	local folder = ReplicatedStorage:FindFirstChild("VFXAssets")
	local decal = folder and folder:FindFirstChild(name)
	local image = Instance.new("ImageLabel")
	image.Name = name
	local source = if decal and decal:IsA("Decal") then decal.Texture else ids[name]
	image.Image = if source and source ~= ids[name] and source ~= "" and source ~= "rbxassetid://0" then source else assert(textures[name])
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.Size = UDim2.fromScale(size, size)
	image.ZIndex = layer
	image.Parent = parent
	return image
end
-- Slashes can last less than one network fetch on the first visit.
function Assets.Preload()
	local preload = Instance.new("Folder")
	for name in textures do Assets.image(preload, name, 1, 1) end
	pcall(function() game:GetService("ContentProvider"):PreloadAsync(preload:GetChildren()) end)
	preload:Destroy()
end
return Assets
