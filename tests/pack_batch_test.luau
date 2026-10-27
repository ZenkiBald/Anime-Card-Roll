local Batch = MODULES.PackBatch
local Packs = MODULES.Packs
local function equal(a,b) assert(a==b,`expected {b}, got {a}`) end
local function test(name,run)
	local ok,message=pcall(run)
	check(ok,name .. (if ok then "" else ": " .. tostring(message)))
end

test("100 ten-card packs select 100 packs and produce a 1,000-pull receipt", function()
	local n=Batch.OpenCount("10",100,100)
	equal(n,100)
	local receipt=Batch.New()
	for i=1,n*Packs.ById["10"].Rolls do
		Batch.Add(receipt,{CardId=if i%2==0 then "rook" else "tomo",Border=if i%100==0 then "Rainbow" else "Normal",Outcome="Copy"})
	end
	Batch.Finish(receipt)
	equal(receipt.Rolls,1000)
	equal(receipt.Counts.Normal,990)
	equal(receipt.Counts.Rainbow,10)
	local total=0
	for _,group in receipt.Groups do total+=group.Count end
	equal(total,1000)
	equal(#receipt.Results,5)
	for _,result in receipt.Results do equal(result.Border,"Rainbow") end
end)

test("bulk open validates requests, ownership and a bounded roll budget", function()
	equal(Batch.OpenCount("10","all",62),62)
	equal(Batch.OpenCount("1000","all",100),10)
	equal(Batch.OpenCount("10",100,7),7)
	equal(Batch.OpenCount("10",-1,100),nil)
	equal(Batch.OpenCount("10",0/0,100),nil)
	equal(Batch.OpenCount("10",math.huge,100),nil)
	equal(Batch.OpenCount("10","oops",100),nil)
	equal(Batch.OpenCount("unknown","all",100),nil)
end)

test("highlights and grouped stacks order by actual rarity, not input sequence", function()
	local batch=Batch.New()
	Batch.Add(batch,{CardId="rook",Border="Normal",Outcome="New",NewBorder=true})
	Batch.Add(batch,{CardId="tomo",Border="Secret",Outcome="Copy"})
	Batch.Add(batch,{CardId="rook",Border="Normal",Outcome="Copy"})
	Batch.Add(batch,{CardId="rook",Border="Gold",Outcome="Copy"})
	Batch.Finish(batch)
	equal(batch.Results[1].Border,"Secret")
	equal(batch.New,1)
	for i=2,#batch.Groups do
		assert(batch.Groups[i-1].Rarity>=batch.Groups[i].Rarity)
	end
	local common=batch.Groups[#batch.Groups]
	equal(common.Count,2)
	equal(common.Outcome,"New")
	-- The presentation receipt never carries old Copies / BorderCopies that could overwrite final state.
	equal(batch.Results[1].Copies,nil)
	equal(batch.Results[1].BorderCopies,nil)
end)
