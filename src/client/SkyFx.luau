--!nonstrict
-- Local, bounded sky ambience. Keep the tower/world lighting intact and pause behind menus/fights.
local Players=game:GetService("Players")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Weather=require(ReplicatedStorage.Shared.Weather)
local State=require(script.Parent.State)
local Theme=require(script.Parent.UI.Theme)
local Modal=require(script.Parent.UI.Modal)
local Title=require(script.Parent.UI.Title)
local SkyFx={}
local STYLES={
	rain={Tint=Color3.fromRGB(230,242,255),Accent=Color3.fromRGB(255,222,123),Speed=NumberRange.new(3,5),Direction=Enum.NormalId.Top},
	blizzard={Tint=Color3.fromRGB(220,241,255),Accent=Color3.fromRGB(255,255,255),Speed=NumberRange.new(1,2),Direction=Enum.NormalId.Bottom},
	thunder={Tint=Color3.fromRGB(238,218,255),Accent=Color3.fromRGB(121,91,255),Speed=NumberRange.new(2,4),Direction=Enum.NormalId.Top},
	eclipse={Tint=Color3.fromRGB(255,218,225),Accent=Color3.fromRGB(255,134,103),Speed=NumberRange.new(1,3),Direction=Enum.NormalId.Bottom},
}
function SkyFx.Start()
	local part=Instance.new("Part")
	part.Name="LocalSkyMotes"
	part.Size=Vector3.new(64,.1,64)
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
	part.Transparency=1;part.CastShadow=false
	part.Parent=workspace
	local motes=Instance.new("ParticleEmitter")
	motes.Name="SkyEnergy"
	motes.Texture="rbxasset://textures/particles/sparkles_main.dds"
	motes.LightEmission=.8
	motes.Lifetime=NumberRange.new(2,4)
	motes.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.2,.22),NumberSequenceKeypoint.new(1,0)})
	motes.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.35),NumberSequenceKeypoint.new(1,1)})
	motes.SpreadAngle=Vector2.new(12,12)
	motes.Rate=0; motes.Parent=part
	local grade=Instance.new("ColorCorrectionEffect")
	grade.Name="CelestialSkyGrade"
	-- Camera parenting keeps this separate from the map's ColorCorrectionEffect used by ZoneFx.
	grade.Parent=workspace.CurrentCamera
	local shown=""
	local lastLow=nil
	local function refresh()
		local id=ReplicatedStorage:GetAttribute("WeatherId") or "clear"
		local style=STYLES[id]
		local enabled=style~=nil and not Title.IsOpen() and not Modal.AnyOpen() and (not State.InBattle or State.BattleHidden)
		local key=if enabled then id else "clear"
		if key~=shown or lastLow~=Theme.FxLow then
			shown=key;lastLow=Theme.FxLow
			motes:Clear()
			motes.Rate=if enabled then (if Theme.FxLow then 3 else 12) else 0
			if enabled then
				motes.Color=ColorSequence.new(Weather.ById[id].Color,style.Accent)
				motes.Speed=style.Speed;motes.EmissionDirection=style.Direction
			end
			TweenService:Create(grade,TweenInfo.new(2),{TintColor=if enabled then style.Tint else Color3.new(1,1,1)}):Play()
		end
		if grade.Parent~=workspace.CurrentCamera then grade.Parent=workspace.CurrentCamera end
	end
	ReplicatedStorage:GetAttributeChangedSignal("WeatherId"):Connect(refresh)
	Modal.Changed:Connect(refresh)
	task.spawn(function() while true do refresh();task.wait(1) end end)
	RunService.RenderStepped:Connect(function()
		if motes.Rate==0 then return end
		local character=Players.LocalPlayer.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		if root then part.Position=root.Position+Vector3.new(0,if motes.EmissionDirection==Enum.NormalId.Top then 1 else 14,0) end
	end)
end
return SkyFx
