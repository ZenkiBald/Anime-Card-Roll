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

-- More than one request remains one bounded-memory receipt; copies never replay the same discovery.
do
 local B=MODULES.PackBatch
 local aggregate=B.New()
 for i=1,3 do
  local r={PackId="10",Opened=1000,Rolls=10000,TotalCards=10000,New=if i==1 then 1 else 0,Counts={Normal=10000},Groups={{CardId="rook",Border="Normal",Count=10000,Rarity=25,Outcome=if i==1 then "New" else "Copy",NewBorder=false}}}
  B.Accumulate(aggregate,r)
 end
 B.Finish(aggregate)
 check(aggregate.Opened==3000 and aggregate.Rolls==30000 and aggregate.Groups[1].Count==30000,"USE ALL receipts combine beyond 10000 rolls without losing packs / counts")
 check(#aggregate.Reveals==1 and aggregate.Reveals[1].Outcome=="New","a discovery survives later duplicate chunks and gets just one reveal candidate")
end

do
 local P=MODULES.RevealPolicy
 local fresh={CardId="rook",Border="Secret",Outcome="New"}
 local duplicate={CardId="rook",Border="Secret",Outcome="Copy"}
 local rainbow={CardId="noa",Border="Rainbow",Outcome="New"}
 check(P.Eligible(fresh,{RevealMinimum="Secret"}) and not P.Eligible(rainbow,{RevealMinimum="Secret"}),"Secret+ reveals filter every lower border")
 check(not P.Eligible(duplicate,{RevealMinimum="Secret"}) and P.Eligible(duplicate,{RevealMinimum="Secret",RevealDuplicates=true}),"duplicate reveals follow the saved new-only choice")
 check(not P.Eligible(fresh,{RevealMinimum="Off"}),"reveal OFF skips even a Secret cinematic")
 check(#P.Select({fresh,fresh,duplicate,rainbow},{RevealMinimum="Secret"})==1,"eligible pack cinematics are unique by card and border")
 local sum=MODULES.RewardBundle.Merge({TraitShards=2,Packs={["10"]=1}},{TraitShards=3,Packs={["10"]=2},TowerArtifacts={hundredcrown=true}})
 check(sum.TraitShards==5 and sum.Packs["10"]==3 and sum.TowerArtifacts.hundredcrown==true,"claim-all receipt combines paid quantities and permanent unlocks")
end
