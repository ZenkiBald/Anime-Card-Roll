--!strict
-- Combine already-paid bundles for one receipt; never grants or reapplies reward multipliers.
local M={}
function M.Merge(target: any,source: any): any
	for key,value in source or {} do
		if type(value)=="number" then target[key]=(target[key] or 0)+value
		elseif type(value)=="table" then
			target[key]=target[key] or {}
			for id,n in value do
				if type(n)=="number" then target[key][id]=(target[key][id] or 0)+n else target[key][id]=n end
			end
		elseif key=="Title" then target.Title=value end
	end
	return target
end
return M
