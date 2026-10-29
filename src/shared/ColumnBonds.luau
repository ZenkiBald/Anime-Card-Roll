--!strict
-- Familiar companions improve one authored part of a Support; no extra fatal-blow revives.
local Bonds={}
Bonds.List={
	{Attack="hana",Support="mitotic_seal",Name="Hundred-Petal Promise",Text="Bonded: healing +5 percentage points.",Stat="Amount",Amount=.05},
	{Attack="goro",Support="blood_vow",Name="Unbroken Vow",Text="Bonded: counter chance +10 percentage points.",Stat="Chance",Amount=.1},
	{Attack="suzu",Support="thunderclap_form",Name="First Thunder",Text="Bonded: opening attack speed +5 percentage points.",Stat="Amount",Amount=.05},
	{Attack="ibuki",Support="heavenly_pact",Name="Heaven Unbound",Text="Bonded: evade chance +5 percentage points.",Stat="Amount",Amount=.05},
	{Attack="yume",Support="ocular_seal",Name="Crows of the Black Moon",Text="Bonded: one additional cursed-flame activation.",Stat="Uses",Amount=1},
	{Attack="tetsu",Support="sand_gourd",Name="Living Sand",Text="Bonded: opening shield +5 percentage points.",Stat="Amount",Amount=.05},
	{Attack="luna",Support="wisteria_vial",Name="Wisteria Promise",Text="Bonded: on-defeat healing +5 percentage points.",Stat="Amount",Amount=.05},
	{Attack="orin",Support="blink_kunai",Name="Flying Thunder",Text="Bonded: opening Ultimate charge +10 percentage points.",Stat="Amount",Amount=.1},
	{Attack="aurelia",Support="beast_seal",Name="Crimson Covenant",Text="Bonded: +5% damage reduction. Fatal-blow return remains once per battle.",Stat="Guard",Amount=.05},
	{Attack="amane",Support="puppet_threads",Name="Threads of the Heart",Text="Bonded: one additional status reflection.",Stat="Uses",Amount=1},
	{Attack="amaya",Support="storm_mantle",Name="Lightning Armor",Text="Bonded: drain chance +10 percentage points; healing cap stays unchanged.",Stat="Chance",Amount=.1},
}
function Bonds.For(attack: any,support: any): any?
	if not attack or not support then return nil end
	for _,def in Bonds.List do if def.Attack==attack.Id and def.Support==support.Id then return def end end
	return nil
end
function Bonds.Active(deck: any): {any}
	local active={}
	for slot,attack in deck.Attack or {} do
		local support=(deck.Support or {})[slot] or ""
		local bond=Bonds.For({Id=attack},{Id=support})
		if bond then table.insert(active,bond) end
	end
	return active
end
return Bonds
