if select(2, UnitClass("player")) ~= "MAGE" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local GetSpellCritChance = GetSpellCritChance
local UnitBuff = UnitBuff
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local math_max = math.max
local math_floor = math.floor
local UnitDebuff = UnitDebuff
local Orc = (select(2,UnitRace("player")) == "Orc")
local select = select
local GetPetSpellBonusDamage = GetPetSpellBonusDamage
local IsSpellKnown = IsSpellKnown
--Waterbolt, Freeze
local spells = { [GetSpellInfo(31707)] = true, [GetSpellInfo(33395)] = true, }
function DrDamage:UpdatePetSpells()
	self:UpdateAB(spells)
end

function DrDamage:PlayerData()
	--Health Updates
	self.TargetHealth = { [1] = 0.35 }
	--Special AB info
	--Evocation
	self.ClassSpecials[GetSpellInfo(12051)] = function()
		return 0.6 * UnitPowerMax("player",0), false, true
	end
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			if mastery > 0 and mastery ~= masteryLast then
				local masteryBonus = calculation.masteryBonus
				if masteryBonus then
					calculation.dmgM = calculation.dmgM / masteryBonus
				end
				--Mana Adept: Damage bonus to all spells based on mana left
				local bonus = 1 + ((mastery * 0.01) * (UnitPower("player",0) / UnitPowerMax("player",0)))
				calculation.dmgM = calculation.dmgM * bonus
				calculation.masteryLast = mastery
				calculation.masteryBonus = bonus
			end
		elseif spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
			local masteryBonus = calculation.masteryBonus
				if baseSpell.Ignite then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.extraAvg = calculation.extraAvg - masteryBonus	
					end
					local bonus = mastery * 0.01 
					calculation.extraAvg = (calculation.extraAvg or 0) + bonus
					calculation.extraTicks = 2
					calculation.extraName = ignite
					calculation.extraCanCrit = false
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
					calculation.extraName = calculation.extraName and (calculation.extraName .. "+ Ignite") or "Ignite"
				end
			end
		elseif spec == 3 then
			if IsSpellKnown(76613) and mastery > 0 and mastery ~= masteryLast then
				if ActiveAuras["Brain Freeze"] and calculation.spellName == "Frostfire Bolt" then
					local masteryBonus = calculation.masteryBonus
					local bonus = 1 + (mastery * 0.01) 
                                        calculation.dmgM = calculation.dmgM * bonus
                                        calculation.masteryLast = mastery
                                        calculation.masteryBonus = bonus 
				elseif ActiveAuras["Frozen"] or calculation.spellName == "Waterbolt"  then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					--Frostburn: Damage Multiplier against Frozen Targets
					local bonus = 1 + (mastery * 0.01) 
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		end
	end
	local ignite = GetSpellInfo(12846)
	self.Calculation["MAGE"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		--General stats
		if IsSpellKnown(89744) then
			calculation.intM = calculation.intM * 1.05
		end
		--Set crits to 200%
		--calculation.critM = calculation.critM + 0.5
		--calculation.casterCrit = true
		--Specialization
		local spec = calculation.spec
		--General bonuses
		if IsSpellKnown(1463) then
			local iwstart, iwduration, iwenabled = GetSpellCooldown("1463")
			if iwstart == 0 and calculation.subType ~= "Absorb" then
				calculation.dmgM = calculation.dmgM * 1.06
			end
		end
		if calculation.group == "Pet" then
			if Orc then
				calculation.dmgM = calculation.dmgM * 1.05
			end
		end
		--if self.db.profile.ManaConsumables then
			--Mana Gem
		--	local managem = self:ScaleData(27.32, nil, nil, nil, true) / 120
		--	calculation.manaRegen = calculation.manaRegen + managem * ((self:GetSetAmount( "T7" ) >= 2) and 1.25 or 1)
		--end
		--Shatter
		if IsSpellKnown(12982) and ActiveAuras["Frozen"] then
			calculation.critPerc = (calculation.critPerc * 2) + 50
		end
		--Critical Mass
		if IsSpellKnown(117216) and baseSpell.CriticalMass then
			calculation.critPerc = calculation.critPerc * 1.5
		end
	end
--ABILITIES
	self.Calculation["Ice Lance"] = function( calculation, ActiveAuras )
		if ActiveAuras["Frozen"] then
			-- Ice Lance does quadruple damage against frozen targets - up from 200%.
			calculation.dmgM = calculation.dmgM * 4
		end
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.12
		end
	end
	self.Calculation["Frostfire Bolt"] = function( calculation, ActiveAuras, _, baseSpell )
		if self:GetSetAmount("PvP") >= 4 then
			 calculation.dmgM_Add = calculation.dmgM_Add + 0.05
		end
		if ActiveAuras["Brain Freeze"] then
			calculation.critPerc = (calculation.critPerc * 2) + 50
		end
	end
	self.Calculation["Arcane Missiles"] = function( calculation, ActiveAuras, _, spell, baseSpell )
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.07
		end
	end
	self.Calculation["Fireball"] = function( calculation, _, _, spell )
		if self:GetSetAmount("PvP") >= 4 then
			 calculation.dmgM_Add = calculation.dmgM_Add + 0.05
		end
	end
	self.Calculation["Frostbolt"] = function( calculation )
		if self:GetSetAmount("PvP") >= 4 then
			 calculation.dmgM_Add = calculation.dmgM_Add + 0.05
		end
	end
	self.Calculation["Arcane Blast"] = function( calculation )
		if self:GetSetAmount("PvP") >= 4 then
			 calculation.dmgM_Add = calculation.dmgM_Add + 0.05
		end
	end
	self.Calculation["Scorch"] = function( calculation )
		if self:GetSetAmount("PvP") >= 4 then
			 calculation.dmgM_Add = calculation.dmgM_Add + 0.05
		end
	end
	--self.Calculation["Arcane Barrage"] = function( calculation )
	--end
	self.Calculation["Pyroblast"] = function( calculation )
		if self:GetSetAmount("T14") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.08
		end
		if self:GetSetAmount("T15") >= 4 then
			calculation.critPerc = calculation.critPerc + 5
		end
	end
	self.Calculation["Pyroblast!"] = self.Calculation["Pyroblast"]
	self.Calculation["Freeze"] = function( calculation )
		calculation.SP = GetPetSpellBonusDamage()
	end
	--self.Calculation["Mirror Image"] = function( calculation )
	--	calculation.critPerc = calculation.critPerc - GetSpellCritChance(5) + 5
	--	calculation.critM = 0.5
	--end
	self.Calculation["Combustion"] = function (calculation)
		if self:HasGlyph ( 56368 ) then
			calculation.dmgM = calculation.dmgM * 2
			calculation.eDuration = calculation.eDuration * 2
			calculation.cooldown = calculation.cooldown * 2
		end
	end
	self.Calculation["Frost Bomb"] = function ( calculation )
		if calculation.haste > 0 then
			calculation.cooldown = calculation.cooldown * ( 1 - (calculation.haste - 1))
		end
		-- This does 60% damage on a player per Rygarius (down from 80%) vs another player.
		if UnitIsPlayer("target") and not UnitIsFriend("target","player") then
			calculation.dmgM = calculation.dmgM * 0.7
		end
		calculation.aoeM = 0.5
	end
	self.Calculation["Living Bomb"] = function (calculation)
		if UnitIsPlayer("target") and not UnitIsFriend("target","player") then
			calculation.dmgM = calculation.dmgM * 0.85
		end
	end
	self.Calculation["Nether Tempest"] = function (calculation)
		if UnitIsPlayer("target") and not UnitIsFriend("target","player") then
			calculation.dmgM = calculation.dmgM * 0.85
		end
		calculation.aoeM = 0.5
	end
	self.Calculation["Inferno Blast"] = function (calculation)
		-- Always crits.
		calculation.critPerc = 100
	end

--SETS
	self.SetBonuses["PvP"] = {
		--Gladiator's Regalia
		64928, 64929, 64930, 64931, 64932,
		--Relentless Gladiator's Regalia
		41947, 41954, 41960, 41966, 41972,		
		--Wrathful Gladiator's Regalia
		51463, 51464, 51465, 51466, 51467,
		--Bloodthirsty Gladiator's Regalia
		64853, 64854, 64855, 64856, 64857,
		--Vicious Gladiator's Regalia
		60463, 60464, 60465, 60466, 60467,
		--Ruthless Gladiator's Regalia
		70299, 70300, 70301, 70302, 70303,
		--Ruthless Gladiator's Regalia (Elite)
		70454, 70455, 70461, 70462, 70463,
		--Cataclysmic Gladiator's Regalia
		73572, 73573, 73574, 73575, 73576,
		--Cataclysmic Gladiator's Regalia (Elite)
		73709, 73710, 73711, 73712, 73713,	
	}
	self.SetBonuses["T14"] = { 86714, 86715, 86716, 86717, 86718, 85374, 85375, 85376, 85377, 85378, 87007, 87008, 87009, 87010, 87011 }
	self.SetBonuses["T15"] = { 95260, 95261, 95262, 95263, 95264, 95890, 95891, 95892, 95893, 95894, 96634, 96635, 96636, 96637, 96638 }
--AURA
--Player
	--Mage Armor - 4.0
	self.PlayerAura[GetSpellInfo(6117)] = { ActiveAura = "Mage Armor", ID = 6117 }
	--Frost Armor - 4.1
	self.PlayerAura[GetSpellInfo(7302)] = { ActiveAura = "Frost Armor", ID = 7302, NoManual = true }	
	--Presence of Mind - 4.0
	self.PlayerAura[GetSpellInfo(12043)] = { Update = true }
	--Icy Veins - 4.0
	self.PlayerAura[GetSpellInfo(12472)] = { Mods = { ["haste"] = function(v) return v*1.2 end }, ID = 12472 }
	--Arcane Power - 4.0
	self.PlayerAura[GetSpellInfo(12042)] = { Value = 0.2, ID = 12042, ModType = "dmgM_Add", Mods = { function(calculation) calculation.manaCost = calculation.manaCost + calculation.baseCost * 0.1 end }, Not = { "Summon Water Elemental", "Mirror Image" } }
	--Hot Streak - 4.0
	self.PlayerAura[GetSpellInfo(48108)] = { Update = true, Spells = { "Pyroblast" } }
	--Brain Freeze - 4.0
	self.PlayerAura[GetSpellInfo(57761)] = { ActiveAura = "Brain Freeze", ID=57761, }
	--Fingers of Frost - 4.1
	self.PlayerAura[GetSpellInfo(44544)] = { NoManual = true, ActiveAura = "Frozen", Spells = { "Ice Lance" }, Value = 0.25, ModType = "dmgM" }
	-- Level 90 talents do not affect Symbiosis from druids.
	--Invocation - 4.0
	self.PlayerAura[GetSpellInfo(116257)] = { School = "All", ID = 116257, ModType =
		function( calculation, _, ActiveAuras )
			if not (calculation.healingSpell or calculation.subType == "Absorb") then
				calculation.dmgM = calculation.dmgM * 1.15
			end
		end
	}
	--Rune of Power
	self.PlayerAura[GetSpellInfo(116011)] = { School = "All", ID = 116011, ModType =
		function( calculation, ActiveAuras )
			if not (calculation.healingSpell or calculation.subType == "Absorb") then
				calculation.dmgM = calculation.dmgM * 1.15
			end
		end
	}
	--Incanter's Ward
	self.PlayerAura[GetSpellInfo(116267)] = { School = "All", ID = 118859, ModType =
		function( calculation, _, ActiveAuras )
			if not (calculation.healingSpell or calculation.subType == "Absorb") then
				calculation.dmgM = calculation.dmgM * 1.30
			end
		end
	}

--Target
	--Frost Nova - 4.0
	self.TargetAura[GetSpellInfo(122)] = { ActiveAura = "Frozen", ID = 122, Manual = GetSpellInfo(50635) }
	--Improved Cone of Cold - 4.0
	self.TargetAura[GetSpellInfo(83301)] = self.TargetAura[GetSpellInfo(122)]
	--Shattered Barrier - 4.0
	self.TargetAura[GetSpellInfo(83073)] = self.TargetAura[GetSpellInfo(122)]
	--Deep Freeze - 4.0
	self.TargetAura[GetSpellInfo(44572)] = self.TargetAura[GetSpellInfo(122)]
	--Ring of Frost - 4.0
	self.TargetAura[GetSpellInfo(82691)] = self.TargetAura[GetSpellInfo(122)]
	--Freeze - 4.0
	self.TargetAura[GetSpellInfo(33395)] = self.TargetAura[GetSpellInfo(122)]
	--Pyromaniac
	self.TargetAura[GetSpellInfo(132210)] = { ID = 132210, Spells = { "Fireball", "Frostfire Bolt", "Inferno Blast", "Pyroblast" }, Value = 0.10, ModType = "dmgM" }
--Snares (shows up as Slow in the DrDamage buff menu)
	--Slow (Mage Arcane Talent) - 4.0
	self.TargetAura[GetSpellInfo(31589)] = { ActiveAura = "Snare", Manual = GetSpellInfo(31589), ID = 31589 }
	--Frostbolt (Mage Ability) - 4.0
	--self.TargetAura[GetSpellInfo(116)] = self.TargetAura[GetSpellInfo(6343)]
	--self.TargetAura[GetSpellInfo(116)] = { School = "Frost", Apps = 3, Value = 0.05, Spells = { "Frostbolt", "Ice Lance", "Waterbolt" }, ModType = "dmgM" }
	--Cone of Cold (Mage Ability) - 4.0
	self.TargetAura[GetSpellInfo(120)] = self.TargetAura[GetSpellInfo(31589)]
	--Blast Wave (Mage Fire Ability) - 4.0
	self.TargetAura[GetSpellInfo(11113)] = self.TargetAura[GetSpellInfo(31589)]
	--Chilled (Mage Frost Armor debuff, Improved Blizzard uses the same name but spellID of 12484) - 4.0
	self.TargetAura[GetSpellInfo(7321)] = self.TargetAura[GetSpellInfo(31589)]
	--Frostfire bolt - 4.0
	self.TargetAura[GetSpellInfo(44614)] = self.TargetAura[GetSpellInfo(31589)]
--Custom (Fix these for 4.0 Mirror Image/Water Elemental)
	--Moonkin Aura
	--self.PlayerAura[GetSpellInfo(24907)]["Not"] = "Mirror Image"
	--Elemental Oath
	--self.PlayerAura[GetSpellInfo(51470)]["Not"] = "Mirror Image"
	--Mind Quickening
	--self.PlayerAura[GetSpellInfo(49868)]["Not"] = "Mirror Image"	
	--Bloodlust
	--if self.PlayerAura[GetSpellInfo(2825)] then self.PlayerAura[GetSpellInfo(2825)]["ActiveAura"] = "Bloodlust"
	--Heroism
	--else self.PlayerAura[GetSpellInfo(32182)]["ActiveAura"] = "Bloodlust" end
	--Wrath of Air
	--self.PlayerAura[GetSpellInfo(3738)]["ActiveAura"] = "Wrath of Air"
--Custom
	--Arcane Charge 5.0
	self.PlayerAura[GetSpellInfo(36032)] = { Spells = { "Arcane Blast", "Arcane Missiles", "Arcane Barrage" }, Apps = 4, ID = 36032, ModType =
		function( calculation, _, _, index, apps )
			--Glyph of Arcane Blast - 4.0 (additive - 3.3.3)
			calculation.dmgM_Add = calculation.dmgM_Add + ((apps * 0.5) * ((self:GetSetAmount( "T15" ) >= 4) and 0.2 or 1))
			if not index and (calculation.spellName == "Arcane Blast") then
				calculation.manaCost = calculation.manaCost + calculation.baseCost * apps * 1.5
			end
		end
	}

	self.spellInfo = {
	--FIRE
		[GetSpellInfo(133)] = {
			["Name"] = "Fireball",
			["ID"] = 133,
			["Data"] = { 1.50, 0.24, 1.50, ["ct_min"] = 1500, ["ct_max"] = 2500, ["c_scale"] = 0.88, },
			[0] = { School = "Fire", Ignite = true, CriticalMass = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(2948)] = {
			["Name"] = "Scorch",
			["ID"] = 2948,
			["Data"] = { 0.976, 0.17, 0.837, },
			[0] = { School = "Fire", Ignite = true, CriticalMass = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(2136)] = {
			["Name"] = "Fire Blast",
			["ID"] = 2136,
			["Data"] = { 1.012, 0.17, 0.789 },
			[0] = { School = "Fire", Cooldown = 8, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(2120)] = {
			["Name"] = "Flamestrike",
			["ID"] = 2120,
			["Data"] = { 0.238, 0, 0.518, 0.476, 0, 0.135 },
			[0] = { School = "Fire", eDuration = 8, sTicks = 2, AoE = true, HybridAoE = true, },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		[GetSpellInfo(44614)] = {
			["Name"] = "Frostfire Bolt",
			["ID"] = 44614,
			["Data"] = { 1.50, 0.24, 1.50, ["ct_min"] = 1500, ["ct_max"] = 2750, ["c_scale"] = 0.8 },
			[0] = { School = "Frostfire", Double = { "Frost", "Fire" }, Ignite = true, CriticalMass = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(11366)] = {
			["Name"] = "Pyroblast",
			["ID"] = 11366,
			["Data"] = { 1.9802, 0.238, 1.98, 0.36, 0, 0.36, ["ct_min"] = 2100, ["ct_max"] = 3500, ["c_scale"] = 0.88, },
			[0] = { School = "Fire", Hits_dot = 4, eDuration = 12, sTicks = 3, Ignite = true, CriticalMass = true },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		--[[
		[GetSpellInfo(92315)] = {
			["Name"] = "Pyroblast!",
			["ID"] = 92315,
			["Data"] = { 1.75, 0.238, 1.75, 0.36, 0, 0.36, ["c_scale"] = 0.88, },
			[0] = { School = "Fire", Hits_dot = 4, eDuration = 12, sTicks = 3, Ignite = true, CriticalMass = true },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		--]]
		[GetSpellInfo(31661)] = {
			["Name"] = "Dragon's Breath",
			["ID"] = 31661,
			["Data"] = { 1.967, 0.15, 0.215 },
			[0] = { School = "Fire", Cooldown = 20, AoE = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(44457)] = {
			["Name"] = "Living Bomb",
			["ID"] = 44457,
			["Data"] = { 0.4121, 0, 0.08, 4.1199, 0, 0.8036, ["c_scale"] = 0.88 },
			[0] = { School = "Fire", Hits_dot = 4, eDuration = 12, sTicks = 3, AoE = 3 },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		--Combustion
		[GetSpellInfo(11129)] = {
			["Name"] = "Combustion",
			["ID"] = 11129,
			["Data"] = { 1.0, 0.17, 1.0 },
			[0] = { School = "Fire", Cooldown = 45, eDuration = 10, sTicks = 1, Hits_dot = 10 },
			[1] = { 0, 0 },
		},
		--FROST
		[GetSpellInfo(116)] = {
			["Name"] = "Frostbolt",
			["ID"] = 116,
			["Data"] = { 1.661, 0.24, 1.661, ["ct_min"] = 1500, ["ct_max"] = 2000, ["c_scale"] = 0.88 },
			[0] = { School = "Frost", },
			[1] = { 0, 0 },
			["Secondary"] = { 
				["Name"] = "Frostbolt",
				["ID"] = 126201,
				["Data"] = { 1.661, 0, 1.661 },
				[0] = { School = { "Frost" , "Healing" }, },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(10)] = {
			["Name"] = "Blizzard",
			["ID"] = 10,
			["Data"] = { 2.5826, 0, 2.936 },
			[0] = { School = "Frost", sTicks = 1, Hits = 8, Channeled = 8, AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(120)] = {
			["Name"] = "Cone of Cold",
			["ID"] = 120,
			["Data"] = { 0.381, 0, 0.318 },
			[0] = { School = "Frost", Cooldown = 10, AoE = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(122)] = {
			["Name"] = "Frost Nova",
			["ID"] = 122,
			["Data"] = { 0.53, 0.15, 0.188 },
			[0] = { School = "Frost", Cooldown = 25, AoE = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(30455)] = {
			["Name"] = "Ice Lance",
			["ID"] = 30455,
			["Data"] = { 0.25 * 1.43, 0.25, 0.25 * 1.43, ["c_scale"] = 0.8 },
			[0] = { School = "Frost", },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(11426)] = {
			["Name"] = "Ice Barrier",
			["ID"] = 11426,
			["Data"] = { 4.401 },
			[0] = { School = { "Frost", "Absorb" }, SPBonus = 3.3, Cooldown = 30, NoCrits = true, NoGlobalMod = true, NoTargetAura = true, NoSchoolTalents = true, NoNext = true, NoDPS = true, NoDoom = true, Unresistable = true, NoDPM = true, BaseIncrease = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(84721)] = {
			["Name"] = "Frostfire Orb",
			["ID"] = 84721,
			["Data"] = { 0.652, 0.25, 0.511 },
			[0] = { School = "Frost", Hits = 10, eDot = true, eDuration = 10, sTicks = 1 },
			[1] = { 0, 0 },
		},
	--ARCANE
		[GetSpellInfo(5143)] = {
			-- Checked in 4.1
			["Name"] = "Arcane Missiles",
			["ID"] = 5143,
			["Data"] = { 0.222, 0, 0.222},
			[0] = { School = "Arcane", Hits = 5, Channeled = 2, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(1449)] = {
			-- Checked in 4.1
			["Name"] = "Arcane Explosion",
			["ID"] = 1449,
			["Data"] = { 0.4833, 0.08, 0.55 },
			[0] = { School = "Arcane", AoE = true, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(30451)] = {
			["Name"] = "Arcane Blast",
			["ID"] = 30451,
			["Data"] = { 0.777, 0.15, 0.777, ["c_scale"] = 0.485 },
			[0] = { School = "Arcane", },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(44425)] = {
			-- Checked in 4.1
			["Name"] = "Arcane Barrage",
			["ID"] = 44425,
			["Data"] = { 1, 0.2, 1, ["c_scale"] = 0.83 },
			[0] = { School = "Arcane", Cooldown = 3, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(1463)] = {
			["Name"] = "Mana Shield",
			["ID"] = 1463,
			["Data"] = { 1 },
			[0] = { School = { "Arcane", "Absorb" }, SPBonus = 1, Cooldown = 25, NoCrits = true, NoGlobalMod = true, NoTargetAura = true, NoSchoolTalents = true, NoDPS = true, NoNext = true, NoDPM = true, NoDoom = true, Unresistable = true, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(1463)] = {
			["Name"] = "Incanter's Ward",
			["ID"] = 1463,
			["Data"] = { 1 },
			[0] = { School = { "Arcane", "Absorb" }, SPBonus = 1, Cooldown = 25, NoCrits = true, NoGlobalMod = true, NoTargetAura = true, NoSchoolTalents = true, NoDPS = true, NoNext = true, NoDPM = true, NoDoom = true, Unresistable = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(113092)] = {
			["Name"] = "Frost Bomb",
			["ID"] = 113092,
			["Data"] = { 4.4197, 0, 3.4468 },
			[0] = { School = { "Frost" }, CoolDown = 10, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(114923)] = {
			["Name"] = "Nether Tempest",
			["ID"] = 114923,
			["Data"] = { 3.7471, 0, 0.2436 },
			[0] = { School = { "Arcane" }, Hits = 12, eDot = true, eDuration = 12, sTicks = 1},
			[1] = { 0, 0, },
		}, 
		--TODO: Mirror Image
		[GetSpellInfo(55342)] = {
			["Name"] = "Mirror Image",
			["ID"] = 55342,
			["Data"] = { 0, 0, 4 }, 
			[0] = { School = "Arcane", eDot = true, eDuration = 30, Cooldown = 180, canCrit = true,  NoNext = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(108853)] = {
			-- Technically, this replaces Fire blast, but the description is generally the same
			["Name"] = "Inferno Blast",
			["ID"] = 108853,
			["Data"] = { 0.60, 0.17, 0.60 },
			[0] = { School = "Fire", Cooldown = 8, Ignite = true },
			[1] = { 0, 0 },
		},
		--Granted by Symbiosis
		[GetSpellInfo(113074)] = {
			["Name"] = "Healing Touch",
			["ID"] = 113074,
			["Data"] = { 19.341, 0, 1.86 },
			[0] = { School = { "Nature", "Healing" },  NoGlobalMod = true, NoDPS = true, SPBonus = 1.86, Cooldown = 10 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(31707)] = {
			["Name"] = "Waterbolt",
			["ID"] = 31707,
			["Data"] = { 0.40 * 1.25, 0.25, 0.40 * 1.25 },
			[0] = { School = { "Frost" } }, 
			[1] = { 0, 0 }, 
		},
		[GetSpellInfo(140468)] = {
			["Name"] = "Flameglow",
			["ID"] = 140468,
			["Data"] = { 0, 0, 0.2 },
			[0] = { School = { "Fire", "Absorb" }, NoCrits = true, NoGlobalMod = true, NoTargetAura = true, NoSchoolTalents = true, NoNext = true, NoDPS = true, NoDoom = true, Unresistable = true, NoDPM = true, BaseIncrease = true },
			[1] = { 0, 0 },
		},
	}
	self.talentInfo = {
						
	}
end
