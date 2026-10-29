do
	local D=MODULES.DevCommands
	check(D.Validate("GrantCard",{CardId="celestial_thunder_gojo",Border="Secret",Count=100}).Count==100,"DEV can target a weather card and exact border / copies")
	check(D.Validate("GrantCard",{CardId="madeup",Border="Secret",Count=1})==nil,"DEV rejects an unknown card")
	check(D.Validate("GrantCard",{CardId="rook",Border="madeup",Count=1})==nil,"DEV rejects an unknown border")
	check(D.Validate("GrantCard",{CardId="rook",Border="Normal",Count=0})==nil,"DEV cannot create an empty ownership entry")
	for _,value in {0,-10,1000001,math.huge,-math.huge,0/0,"not a number",{}} do
		check(D.Validate("GrantResource",{Kind="Fragments",Amount=value})==nil,"DEV rejects malformed / unbounded grant amounts")
	end
	check(D.Validate("GrantResource",{Kind="Shards",Amount=100})==nil,"DEV cannot revive retired diamond Shards")
	check(D.Validate("GrantPack",{Id="10",Count=100}).Count==100,"DEV can grant a full pack-opening test batch")
	check(D.Validate("GrantPack",{Id="1000:Flame",Count=1})==nil,"DEV excludes retired elemental packs")
	check(D.Validate("SetWeather",{Id="eclipse",Seconds=180}).Id=="eclipse" and D.Validate("SetWeather",{Id="fake",Seconds=180})==nil,"DEV sky preview uses known skies and bounded duration")
	check(D.Validate("SetLevel",100).Level==100 and D.Validate("SetLevel",101)==nil,"DEV level edits stay inside supported progression")
	check(D.Validate("SetLuck",0/0)==nil and D.Validate("SetLuck",10000).Luck==10000,"custom DEV luck accepts a large finite value, never NaN")
	local natural
	for slot=1900000,1900100 do local e=MODULES.Weather.Event(slot);if e.Id~="clear" then natural=e;break end end
	check(MODULES.Weather.At(natural.Starts+1,{Id="clear",Key="dev",Starts=natural.Starts,Ends=natural.Ends}).Id=="clear","DEV Quiet Skies overrides an active natural sky only for its preview duration")
end
