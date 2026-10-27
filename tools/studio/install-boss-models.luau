-- Edit mode only. Sanitize the user's inserted models and replace the four BossKit templates.
-- No inserted scripts, sounds, remotes, GUI, package updates or emitters survive installation.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before installing boss models")
local storage = game:GetService("ServerStorage")
local replicated = game:GetService("ReplicatedStorage")
assert(not storage:FindFirstChild("BossReplacementBackup_20261027"), "Already installed; use the saved BossKit asset")
local specs = {
	{ Id="kurogane", Source="Nine-Tails Fox (Kurama)", Label="Naruto Kurama Avatar", Forward="HumanoidRootPart" },
	{ Id="rimeveil", Source="Golden Frieza", Label="R6 Golden Frieza Rig", Forward="HumanoidRootPart" },
	{ Id="vex", Source="Susanoo (Madara)", Label="Madara Susanoo", Forward="HumanoidRootPart" },
	{ Id="tenrai", Source="Muzan Kibutsuji", Label="Muzan [R6]", Forward="HumanoidRootPart" },
}
local function clean(model)
	local removed=0
	for _,inst in model:GetDescendants() do
		if inst:IsA("LuaSourceContainer") or inst:IsA("LayerCollector") or inst:IsA("RemoteEvent")
			or inst:IsA("RemoteFunction") or inst:IsA("PackageLink") or inst:IsA("Sound")
			or inst:IsA("ParticleEmitter") or inst:IsA("Trail") or inst:IsA("Beam")
			or inst:IsA("Light") or inst:IsA("Fire") or inst:IsA("Smoke")
			or inst:IsA("ProximityPrompt") or inst:IsA("ClickDetector") then
			removed+=1
			inst:Destroy()
		elseif inst:IsA("BasePart") then
			inst.Anchored=true; inst.CanCollide=false; inst.CanTouch=false; inst.CanQuery=false
		elseif inst:IsA("Humanoid") then
			inst.EvaluateStateMachine=false
			inst.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
			inst.BreakJointsOnDeath=false; inst.AutoRotate=false
		end
	end
	return removed
end
local kit=Instance.new("Folder"); kit.Name="BossKit"
local report={}
for _,spec in specs do
	local source=assert(workspace:FindFirstChild(spec.Source), "Missing source " .. spec.Source)
	assert(source:IsA("Model"),spec.Source .. " must be a Model")
	local model=source:Clone()
	local removed=clean(model)
	local forward=model:FindFirstChild(spec.Forward,true)
	assert(forward and forward:IsA("BasePart"),"No facing reference for " .. spec.Source)
	local direction=forward.CFrame.LookVector*Vector3.new(1,0,1)
	assert(direction.Magnitude>.1,"Invalid facing reference")
	model.PrimaryPart=nil
	local box=model:GetBoundingBox()
	local basis=CFrame.lookAt(box.Position,box.Position+direction.Unit)
	-- Normalize the whole model, including its nested rigs / tails / wings, to face -Z.
	model:PivotTo(basis:Inverse()*model:GetPivot())
	model.WorldPivot=CFrame.identity
	model.Name=spec.Id
	model:SetAttribute("CanonicalFacing",true)
	model:SetAttribute("SourceLabel",spec.Label)
	if spec.Id=="vex" then
		-- Dark Neon suppresses all shape shading; keep the blue shell but let its armor read in battle.
		for _,p in model:GetDescendants() do
			if p:IsA("BasePart") and p.Transparency<.5 and p.Color.B>p.Color.R+.2 and p.Color.B>.3 then
				p.Material=Enum.Material.SmoothPlastic; p.Color=Color3.fromRGB(59,116,218)
			end
		end
	end
	local cf,size=model:GetBoundingBox()
	model:PivotTo(CFrame.new(0,size.Y/2,0)*cf:Inverse()*model:GetPivot())
	model.Parent=kit
	table.insert(report,{Id=spec.Id,Source=spec.Source,Label=spec.Label,Removed=removed,Size=tostring(size)})
end
local old=assert(replicated:FindFirstChild("BossKit"),"Existing BossKit missing")
for _,model in old:GetChildren() do
	if not kit:FindFirstChild(model.Name) then
		local copy=model:Clone(); clean(copy); copy.Parent=kit
	end
end
local backup=Instance.new("Folder"); backup.Name="BossReplacementBackup_20261027"
old.Parent=backup
-- Keep sanitized originals off the live map. They cannot run scripts when Play starts.
local sources=Instance.new("Folder"); sources.Name="UserSources"; sources.Parent=backup
for _,spec in specs do local source=workspace[spec.Source];clean(source);source.Parent=sources end
local previous=workspace:FindFirstChild("Itachi")
if previous then clean(previous);previous.Parent=backup end
backup.Parent=storage
kit.Parent=replicated
game:GetService("ChangeHistoryService"):SetWaypoint("Install sanitized user boss models")
return game:GetService("HttpService"):JSONEncode(report)
