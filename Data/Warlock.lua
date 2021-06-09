if select(2, UnitClass("player")) ~= "WARLOCK" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitIsUnit = UnitIsUnit
local math_min = math.min
local math_max = math.max
local math_ceil = math.ceil
local select = select
local GetPetSpellBonusDamage = GetPetSpellBonusDamage
local GetSpellCritChanceFromIntellect = GetSpellCritChanceFromIntellect
local Orc = (select(2,UnitRace("player")) == "Orc")
local IsSpellKnown = IsSpellKnown

local spells = { [GetSpellInfo(7814) or "Lash of Pain"] = true, [GetSpellInfo(54049) or "Shadow Bite"] = true, [GetSpellInfo(3110) or "Firebolt"] = true, }
function DrDamage:UpdatePetSpells()
	self:UpdateAB(spells)
end

function DrDamage:PlayerData()
	--Health updates
	self.PlayerHealth = { [1] = 0.251, [0.251] = GetSpellInfo(689) }
	self.TargetHealth = { [1] = 0.251, }
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			if mastery > 0 and mastery ~= masteryLast then
				local masteryBonus = calculation.masteryBonus
				if baseSpell.Affliction then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					local bonus = 1 + (mastery * 0.01)
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		elseif spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
				if ActiveAuras["Metamorphosis"] then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					if not baseSpell.PetAttack then
						local bonus = 1 + (mastery * 0.01 * 3)
						calculation.masteryBonus = bonus
					else
						local bonus = 1 + (mastery * 0.01)
						calculation.masteryBonus = bonus
					end
					calculation.masteryLast = mastery
				elseif not ActiveAuras["Metamorphosis"] then
					local masteryBonus = calculation.masteryBonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = 1 + (mastery * 0.01)
				end
			end
		elseif spec == 3 then
			--if mastery > 0 and mastery ~= masteryLast then
			--end
		end
	end
	self.Calculation["WARLOCK"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		--General stats
		if IsSpellKnown(86091) then
			calculation.intM = calculation.intM * 1.05
		end
		--General bonuses
		if baseSpell.PetAttack then
			if Orc then
				calculation.dmgM = calculation.dmgM * 1.05
			end
		end
	end
--ABILITIES
	local damage_text = GetSpellInfo(48360)
	self.Calculation["Life Tap"] = function( calculation, _, Talents )
		if not self:HasGlyph(63320) then
			local amount = UnitHealthMax("player") * 0.15  
			calculation.minDam = amount
			calculation.maxDam = amount
			calculation.customText = damage_text
			calculation.customTextValue = 0.15 * UnitHealthMax("player")
		end
	end
	local heal = GetSpellInfo(2050)
	self.Calculation["Drain Life"] = function( calculation, ActiveAuras, Talents )
		--calculation.customTextValue = 0.06 * UnitHealthMax("player") * (ActiveAuras["Demon Armor"] or 1)
		calculation.customTextValue = 0.02 * UnitHealthMax("player")
		if ActiveAuras["Soulburn"] then
			calculation.customTextValue = calculation.customTextValue * 1.5
		end
		if ActiveAuras["Demon Armor"] then
			calculation.customTextValue = calculation.customTextValue * 1.1
		end
		if self:HasGlyph(63302) then
			calculation.customTextValue = calculation.customTextValue * 1.3
		end
		calculation.customText = heal
	end
	self.Calculation["Drain Soul"] = function ( calculation, ActiveAuras, Talents, spell )
		if UnitHealth("target") ~= 0 and (UnitHealth("target") / UnitHealthMax("target")) <= 0.2 then
			calculation.minDam = calculation.minDam * 2
			calculation.maxDam = calculation.maxDam * 2
		end
		if self:GetSetAmount("T15") >= 4 then
			calculation.minDam = calculation.minDam * 1.05
		end
	end
	self.Calculation["Incinerate"] = function( calculation, ActiveAuras, Talents, spell )
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.05
		end
	end
	--self.Calculation["Soul Fire"] = function( calculation, ActiveAuras, Talents, spell )
	--end
	--self.Calculation["Chaos Bolt"] = function( calculation, ActiveAuras, Talents )
	--end
	--self.Calculation["Immolate"] = function( calculation )
	--end
	self.Calculation["Corruption"] = function( calculation )
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.1
		end
	end
	--self.Calculation["Conflagrate"] = function( calculation, ActiveAuras, Talents )
	--end
	--self.Calculation["Unstable Affliction"] = function( calculation )
	--end
	self.Calculation["Shadow Bolt"] = function( calculation )
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.02
		end
	end
	--self.Calculation["Immolation Aura"] = function( calculation, ActiveAuras )
	--end
	--self.Calculation["Demon Leap"] = function( calculation, ActiveAuras )
	--end
	--self.Calculation["Firebolt"] = function( calculation, ActiveAuras, Talents, spell )
	--end
	--self.Calculation["Shadow Bite"] = function( calculation, ActiveAuras, Talents, spell )
	--end
	--self.Calculation["Lash of Pain"] = function( calculation, ActiveAuras, Talents, spell )
	--end
	self.Calculation["Rain of Fire"] = function ( calculation, ActiveAuras )
		local spec = calculation.spec
		if ActiveAuras["Immolate"] and spec == 3 then
			calculation.dmgM = calculation.dmgM * 1.5
		end
	end
	self.Calculation["Touch of Chaos"] = function (calculation)
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.02
		end
	end
	self.Calculation["Demonic Slash"] = function (calculation)
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.02
		end
	end
	self.Calculation["Malefic Grasp"] = function (calculation)
		if self:GetSetAmount("T15") >= 4 then
			calculation.dmgM = calculation.dmgM * 1.05
		end
	end
--SETS
	self.SetBonuses["T14"] = { 86709, 86710, 86711, 86712, 86713, 87187, 87188, 87189, 87190, 87191, 85369, 85370, 85371, 85372, 85373, }
	self.SetBonuses["T15"] = { 95981, 95982, 95983, 95984, 95985, 95325, 95326, 95327, 95328, 95329, 96725, 96726, 96727, 96728, 96729, }
--AURA
--Player
	--Metamorphosis - TODO: Verify aura ID.
	self.PlayerAura[GetSpellInfo(103958)] = { ActiveAura = "Metamorphosis", Update = true, Index = true, ID = 103958 }
	--Soulburn
	self.PlayerAura[GetSpellInfo(74434)] = { ActiveAura = "Soulburn", Spells = { "Soul Fire", "Drain Life" }, ID = 74434 }
	--TODO: Demon Soul: Felguard. Does API handle it?
	--Dark Soul: Instability
	self.PlayerAura[GetSpellInfo(113858)] = { ActiveAura = "Dark Soul: Instability", Value = 30, ModType = "critPerc" }
	--Grimoire of Sacrifice: Affliction
	self.PlayerAura[GetSpellInfo(132612)] = { Spells = { "Malefic Grasp", "Haunt", "Fel Flame" }, Value = 0.2, ModType = "dmgM" }
	--Grimoire of Sacrifice: Demonology
	self.PlayerAura[GetSpellInfo(132613)] = { Spells = { "Shadow Bolt", "Touch of Chaos", "Demonic Slash", "Soul Fire", "Fel Flame" }, Value = 0.2, ModType = "dmgM" }
	--Grimoire of Sacrifice: Destruction
	self.PlayerAura[GetSpellInfo(132614)] = { Spells = { "Incinerate", "Conflagrate", "Chaos Bolt", "Shadowburn", "Fel Flame" }, Value = 0.15, ModType = "dmgM" }
--Target
	--Immolate
	self.TargetAura[GetSpellInfo(348)] = { ActiveAura = "Immolate", Spells = { "Incinerate", "Conflagrate", "Chaos Bolt" }, SelfCast = true, ID = 348 }
	--Soul Siphon
		--Agony
		self.TargetAura[GetSpellInfo(980)] = 	self.TargetAura[GetSpellInfo(172)]
		--Doom
		self.TargetAura[GetSpellInfo(603)] = 	self.TargetAura[GetSpellInfo(172)]
		--Curse of Exhaustion
		self.TargetAura[GetSpellInfo(18223)] = 	self.TargetAura[GetSpellInfo(172)]
		--Unstable Affliction
		self.TargetAura[GetSpellInfo(30108)] = 	self.TargetAura[GetSpellInfo(172)]
		--Seed of Corruption
		self.TargetAura[GetSpellInfo(27243)] = 	self.TargetAura[GetSpellInfo(172)]
		--Fear
		self.TargetAura[GetSpellInfo(5782)] = 	self.TargetAura[GetSpellInfo(172)]
		--Howl of Terror
		self.TargetAura[GetSpellInfo(5484)] = 	self.TargetAura[GetSpellInfo(172)]
--Custom
	--Demon Armor
	self.PlayerAura[GetSpellInfo(79934)] = { Spells = { "Drain Life" }, ID = 687, ModType =
		function( calculation, ActiveAuras, Talents )
			calculation.leechBonus = (calculation.leechBonus or 0) * 1.2 
			ActiveAuras["Demon Armor"] = 1.2 
		end
	}
	--Backdraft
	self.PlayerAura[GetSpellInfo(117828)] = { NoManual = true, ModType =
		function( calculation, _, Talents )
			calculation.haste = calculation.haste * 1.3
		end
	}
	--Haunt
	self.TargetAura[GetSpellInfo(48181)] = { School = "Shadow", SelfCast = true, ID = 48181, Not = { "Pet" }, Value = 0.45, ModType = "dmgM" }

	self.spellInfo = {
		[GetSpellInfo(172)] = {
			["Name"] = "Corruption",
			["ID"] = 172,
			["Data"] = { (1.3481/5.5) * 1.1 },
			[0] = { School = { "Shadow" }, SPBonus = (0.15/5.5) * 1.1, Hits = 9, eDot = true, eDuration = 18, sTicks = 2, Affliction = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(686)] = {
			["Name"] = "Shadow Bolt",
			["ID"] = 686,
			["Data"] = { 0.62, 0.11, 0.754, ["ct_min"] = 1700, ["ct_max"] = 2500 },
			[0] = { School = { "Shadow" } },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(1454)] = {
			["Name"] = "Life Tap",
			["ID"] = 1454,
			[0] = { School = { "Shadow", "Utility", }, NoCrits = true, NoGlobalMod = true, NoTargetAura = true, NoSchoolTalents = true, NoDPS = true, NoNext = true, NoDPM = true, NoDoom = true, Unresistable = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(6229)] = {
			["Name"] = "Shadow Ward",
			["ID"] = 6229,
			["Data"] = { 3, 0 },
			[0] = { School = { "Shadow", "Absorb" }, SPBonus = 3, NoCrits = true, NoGlobalMod = true, NoTargetAura = true, NoSchoolTalents = true, NoDPS = true, NoNext = true, NoDPM = true, NoDoom = true, Unresistable = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(980)] = {
			["Name"] = "Agony",
			["ID"] = 980,
			["Data"] = { 0.0539, 0, 0.026 },
			[0] = { School = { "Shadow" }, Hits = 12, eDot = true, eDuration = 24, sTicks = 2, Affliction = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(603)] = {
			["Name"] = "Doom",
			["ID"] = 603,
			["Data"] = { 3.7483, 0, 0.9375  },
			[0] = { School = { "Shadow" }, Hits = 4, eDot = true, eDuration = 60, sTicks = 15 },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(689)] = {
			["Name"] = "Drain Life",
			["ID"] = 689,
			["Data"] = { 0.334, 0, 0.334 },
			[0] = { School = { "Shadow" }, Hits = 6, sTicks = 1, Channeled = 6, Drain = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(1120)] = {
			["Name"] = "Drain Soul",
			["ID"] = 1120,
			["Data"] = { 0.3903 * 0.66, 0, 0.375 * 0.66 },
			[0] = { School = { "Shadow" }, Hits = 5, sTicks = 3, Channeled = 15, Drain = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(6353)] = {
			["Name"] = "Soul Fire",
			["ID"] = 6353,
			["Data"] = { 0.8539, 0.2, 0.8539 },
			[0] = { School = { "Fire" } },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(17877)] = {
			["Name"] = "Shadowburn",
			["ID"] = 17877,
			["Data"] = { 3.5, 0.2, 3.5 },
			[0] = { School = { "Shadow" }, Cooldown = 15, Emberstorm = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(348)] = {
			["Name"] = "Immolate",
			["ID"] = 348,
			["Data"] = { 0.4269 * 1.1, 0, 0.4269 * 1.1, 2.1344 * 1.1, 0, 0.4269 * 1.1 },
			[0] = { School = { "Fire" }, Hits_dot = 5, eDuration = 15, sTicks = 3, BurningEmbers = true },
			[1] = { 0, 0, hybridDotDmg = 0, },
		},
		[GetSpellInfo(1949)] = {
			["Name"] = "Hellfire",
			["ID"] = 1949,
			["Data"] = { 0.2099, 0, 0.2099, },
			[0] = { School = { "Fire" }, Hits = 14, Channeled = 14, sTicks = 1, AoE = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(5740)] = {
			["Name"] = "Rain of Fire",
			["ID"] = 5740,
			["Data"] = { 0.2499, 0, 0.2499, },
			[0] = { School = { "Fire" }, Hits = 6, Channeled = 6, sTicks = 1, AoE = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(30108)] = {
			["Name"] = "Unstable Affliction",
			["ID"] = 30108,
			["Data"] = { 1.6775 * 1.21, 0, 0.2499 * 1.21 },
			[0] = { School = { "Shadow" }, Hits = 7, eDot = true, eDuration = 14, sTicks = 2, Affliction = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(17962)] = {
			["Name"] = "Conflagrate",
			["ID"] = 17962,
			["Data"] = { 1.725, 0.1, 1.725 }, 
			[0] = { School = { "Fire" }, BurningEmbers = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(27243)] = {
			["Name"] = "Seed of Corruption",
			["ID"] = 27243,
			["Data"] = { 0.91, 0.15, 0.91, 1.2581, 0, 0.21  },
			["Data2"] = function(baseSpell, spell, playerLevel)
				baseSpell.Cap = 2.113 * self.Scaling[playerLevel]
				baseSpell.Cap_SPBonus = 0.1716
				end,
			[0] = { School = { "Shadow" }, Hits_dot = 6, eDuration = 18, sTicks = 3, NoDotAverage = true, AoE = true },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		[GetSpellInfo(29722)] = {
			["Name"] = "Incinerate",
			["ID"] = 29722,
			["Data"] = { 1.5399, 0.1, 1.5399 },
			[0] = { School = { "Fire" }, BurningEmbers = true },
			[1] = { 0, 0, 0, 0 },
		},
		[GetSpellInfo(48181)] = {
			["Name"] = "Haunt",
			["ID"] = 48181,
			["Data"] = { 1.75 * 1.5, 0, 1.75 * 1.5 },
			[0] = { School = { "Shadow" }, Cooldown = 8 },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(116858)] = {
			["Name"] = "Chaos Bolt",
			["ID"] = 116858,
			["Data"] = { 2.0249, 0.2, 2.25, },
			[0] = { School = { "Fire" }, Emberstorm = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(50589)] = GetSpellInfo(1949),
		[GetSpellInfo(3110)] = {
			["Name"] = "Firebolt",
			["ID"] = 3110,
			["Data"] = { 0.907, 0, 0.907, ["ct_min"] = 1250, ["ct_max"] = 1750 },
			[0] = { School = { "Fire" }, PetAttack = true, SPBonus = 0.907, NoGlobalMod = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, NoDPSC = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(54049)] = {
			["Name"] = "Shadow Bite",
			["ID"] = 54049,
			["Data"] = { 0.3799, 0, 0.3799 },
			[0] = { School = { "Shadow" }, PetAttack = true, SPBonus = 0.3799, NoGlobalMod = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(7814)] = {
			["Name"] = "Lash of Pain",
			["ID"] = 7814,
			["Data"] = { 0.907, 0, 0.907},
			[0] = { School = { "Shadow" }, PetAttack = true, SPBonus = 0.907, NoGlobalMod = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(86121)] = {
			["Name"] = "Soul Swap",
			["ID"] = 86121,
			["Data"] = { 0.5, 0, 0.5 },
			[0] = { School = { "Shadow", "Affliction" }, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(105174)] = {
			["Name"] = "Hand of Gul'Dan",
			["ID"] = 105174,
			["Data"] = { 0.5747, 0, 0.5747, 0.82, 0, 0.137 },
			[0] = { School = "Shadowflame", Double = { "Shadow", "Fire" }, SPBonus = 0.137, eDot = true, Hits = 6, eDuration = 6, sTicks = 1, AoE = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(77799)] = {
			["Name"] = "Fel Flame",
			["ID"] = 77799,
			["Data"] = { 0.75 * 1.13, 0.1 * 1.13, 0.75 * 1.13 },
			[0] = { School = "Shadowflame", Double = { "Shadow", "Fire" }, BurningEmbers = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(103103)] = {
			["Name"] = "Malefic Grasp",
			["ID"] = 103103,
			["Data"] = { 0.2 * 0.66, 0, 0.2 * 0.66 },
			[0] = { School = "Shadow", Hits = 4, Channeled = 4, sTicks = 1 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(103964)] = {
			["Name"] = "Touch of Chaos",
			["ID"] = 103964,
			["Data"] = { 0.7671, 0, 0.7671 }, 
			[0] = { School = "Chaos" },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(103967)] = {
			["Name"] = "Carrion Swarm",
			["ID"] = 103967,
			["Data"] = { 0.5, 0.1, 0.5 },
			[0] = { School = "Shadow", Cooldown = 12, AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(124916)] = {
			["Name"] = "Chaos Wave",
			["ID"] = 124916,
			["Data"] = { 1, 0, 1.167 }, 
			[0] = { School = "Shadow", AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(129343)] = {
			["Name"] = "Void Ray",
			["ID"] = 129343,
			["Data"] = { 0.2, 0.1, 0.2 },
			[0] = { School = "Shadowflame", Double = { "Fire", "Shadow" }, AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(114175)] = {
			["Name"] = "Demonic Slash",
			["ID"] = 114175,
			["Data"] = { 0.6665, 0, 0.6665 },
			[0] = { School = "Shadow" },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(104025)] = GetSpellInfo(1949),
		--Pets
		--Fel Imp
		[GetSpellInfo(115746)] = {
			["Name"] = "Felbolt",
			["ID"] = 115746,
			["Data"] = { 0.907, 0.1, 0.907, ["ct_min"] = 1250, ["ct_max"] = 1750 },
			[0] = { School = { "Fire" }, PetAttack = true, SPBonus = 0.907, NoGlobalMod = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, NoDPSC = true },
			[1] = { 0, 0 },
		},
		--Observer
		[GetSpellInfo(115778)] = {
			["Name"] = "Tongue Lash",
			["ID"] = 115778,
			["Data"] = { 0.3799, 0, 0.3799 },
			[0] = { School = { "Shadow" }, PetAttack = true, SPBonus = 0.3799, NoGlobalMod = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0 },
		},
		--Observer
		[GetSpellInfo(115781)] = { 
			["Name"] = "Optic Blast",
			["ID"] = 115781,
			["Data"] = { 0.14, 0, 0.14 },
			[0] = { School = { "Shadow" }, PetAttack = true, SPBonus = 0.14, NoGlobalMod = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0 },
		},
		--Infernal
		[GetSpellInfo(1122)] = {
			["Name"] = "Summon Infernal",
			["ID"] = 1122,
			["Data"] = { 1, 0.1199, 1 },
			[0] = { School = { "Fire" }, eDot = true, PetAttack = true, Cooldown = 600, Hits = 30, sTicks = 2, eDuration = 60, SPBonus = 1, AoE = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0 },
		},
		--Abyssal
		[GetSpellInfo(112921)] = {
		--Data found in Spell ID: 22703 (the missile summoned by the infernal)
			["Name"] = "Summon Abyssal",
			["ID"] = 112921,
			["Data"] = { 1, 0.1199, 1 },
			[0] = { School = { "Fire" }, eDot = true, PetAttack = true, Cooldown = 600, Hits = 30, sTicks = 2, eDuration = 60, SPBonus = 1, AoE = true, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0 },
		},
		--Doomguard
		[GetSpellInfo(18540)] = {
			["Name"] = "Summon Doomguard",
			["ID"] = 18540,
			["Data"] = { 0.90, 0.1199, 0.90 },
			[0] = { School = { "Shadow" }, eDot = true, PetAttack = true, Cooldown = 600, Hits = 20, sTicks = 3, eDuration = 60, SPBonus = 0.9, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0 },
		},
		--Terrorguard
		[GetSpellInfo(112927)] = {
			["Name"] = "Summon Terrorguard",
			["ID"] = 112927,
			["Data"] = { 0.90, 0.1199, 0.90 },
			[0] = { School = { "Shadow" }, eDot = true, PetAttack = true, Cooldown = 600, Hits = 20, sTicks = 3, eDuration = 60, SPBonus = 0.9, NoManaCalc = true, NoNext = true, NoMPS = true, NoDPM = true, },
			[1] = { 0, 0 },
		},
	}
	self.talentInfo = {
	--AFFLICTION
	--DEMONOLOGY
	--DESTRUCTION:
	}
end
