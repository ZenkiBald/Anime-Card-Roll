-- Export only the two sanitized anchored tower models to the local export bridge; no place / Lighting writes.
return function()
	local Http=game:GetService("HttpService")
	local serial=0
	local allowed={Model=true,Folder=true,Part=true,WedgePart=true,CornerWedgePart=true,PointLight=true,ParticleEmitter=true,ProximityPrompt=true}
	local fields={
		Part={Anchored="bool",CanCollide="bool",CanQuery="bool",CanTouch="bool",CastShadow="bool",CFrame="CoordinateFrame",Size="Vector3",Color="Color3",Material="token",Transparency="float",Reflectance="float",Shape="token",TopSurface="token",BottomSurface="token"},
		Model={ModelStreamingMode="token"},
		PointLight={Enabled="bool",Brightness="float",Range="float",Color="Color3",Shadows="bool"},
		ProximityPrompt={ActionText="string",ObjectText="string",KeyboardKeyCode="token",HoldDuration="float",MaxActivationDistance="float",RequiresLineOfSight="bool",Enabled="bool"},
		ParticleEmitter={Enabled="bool",Texture="Content",Color="ColorSequence",Size="NumberSequence",Transparency="NumberSequence",LightEmission="float",LightInfluence="float",Rate="float",Lifetime="NumberRange",Speed="NumberRange",SpreadAngle="Vector3",Acceleration="Vector3",EmissionDirection="token",Rotation="NumberRange",RotSpeed="NumberRange",Drag="float"},
	}
	local function convert(value,kind)
		if kind=="token" then return value.Value
		elseif kind=="Vector3" then return if typeof(value)=="Vector2" then {value.X,value.Y} else {value.X,value.Y,value.Z}
		elseif kind=="CoordinateFrame" then return {value:GetComponents()}
		elseif kind=="Color3" then return {value.R,value.G,value.B}
		elseif kind=="NumberRange" then return {value.Min,value.Max}
		elseif kind=="NumberSequence" then local a={} for _,k in value.Keypoints do table.insert(a,k.Time);table.insert(a,k.Value);table.insert(a,k.Envelope) end;return a
		elseif kind=="ColorSequence" then local a={} for _,k in value.Keypoints do table.insert(a,k.Time);table.insert(a,k.Value.R);table.insert(a,k.Value.G);table.insert(a,k.Value.B);table.insert(a,0) end;return a end
		return value
	end
	local function node(inst)
		assert(allowed[inst.ClassName],"Unexpected tower instance: "..inst.ClassName)
		serial+=1
		local result={Id=serial,Name=inst.Name,Class=inst.ClassName,Props={},Children={}}
		local props=fields[inst.ClassName] or (if inst:IsA("BasePart") then fields.Part else {})
		for key,kind in props do
			local ok,value=pcall(function() return inst[key] end)
			if ok then
				-- SpreadAngle is a Vector2 property; Roblox XML stores Vector2 separately.
				local actual=if key=="SpreadAngle" then "Vector2" else kind
				result.Props[key]={Type=actual,Value=convert(value,kind)}
			end
		end
		for _,child in inst:GetChildren() do table.insert(result.Children,node(child)) end
		return result
	end
	local final=node(workspace.InfiniteTower)
	local previous=node(game.ServerStorage.TowerReferenceBackup_20261029.InfiniteTower)
	local function send(path,data)
		local encoded=Http:JSONEncode(data)
		local result
		for i=1,#encoded,400000 do
			result=Http:PostAsync("http://127.0.0.1:34876/"..path,Http:JSONEncode({Chunk=encoded:sub(i,i+399999),Final=i+399999>=#encoded}),Enum.HttpContentType.ApplicationJson)
			task.wait()
		end
		return result
	end
	local a=send("tower",final)
	local b=send("original",previous)
	return {Current=a,Original=b,Instances=serial}
end
