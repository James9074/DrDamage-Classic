if select(2, UnitClass("player")) ~= "ROGUE" then return end
	local GetSpellInfo = DrDamage.SafeGetSpellInfo
	local GetSpellCritChance = GetSpellCritChance
	local GetCritChance = GetCritChance
	local UnitDebuff = UnitDebuff
	local UnitCreatureType = UnitCreatureType
	local math_min = math.min
	local math_max = math.max
	local math_floor = math.floor
	local math_ceil = math.ceil
	local UnitHealth = UnitHealth
	local UnitHealthMax = UnitHealthMax
	local UnitDamage = UnitDamage
	local string_find = string.find
	local string_lower = string.lower
	local IsEquippedItemType = IsEquippedItemType
	local select = select
	local IsSpellKnown = IsSpellKnown

	function DrDamage:PlayerData()
		--Health Updates
		self.TargetHealth = { [1] = 0.35, [2] = "player" }
		--Special aura handling
		--[[
		local TargetIsPoisoned = false
		local Mutilate = GetSpellInfo(1329)
		local poison = GetSpellInfo(2818)		
		self.Calculation["TargetAura"] = function()
			local temp = TargetIsPoisoned
			TargetIsPoisoned = false
			for i=1,40 do
				local name, _, _, _, debuffType = UnitDebuff("target",i)
				if name then
				if debuffType == poison then
					TargetIsPoisoned = true
					break
				end
				else break end
			end
			if temp ~= TargetIsPoisoned then
				return true, Mutilate
			end
		end
		--]]
--GENERAL
		self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
			local mastery = calculation.mastery
			local masteryLast = calculation.masteryLast
			local spec = calculation.spec
			if spec == 1 then
				if mastery > 0 and mastery ~= masteryLast then
					if calculation.E_dmgM then
						local masteryBonus = calculation.masteryBonus
						if masteryBonus then
							calculation.E_dmgM = calculation.E_dmgM / masteryBonus
						end
						local bonus = 1 + (mastery * 0.01)
						calculation.E_dmgM = calculation.E_dmgM * bonus
						calculation.masteryLast = mastery
						calculation.masteryBonus = bonus
					end
				end
			elseif spec == 2 then
				if mastery > 0 and mastery ~= masteryLast then
					if baseSpell.AutoAttack or calculation.spellName == "Killing Spree" then
						--Mastery: Main Gauche
						--Each point of Mastery increases the chance by an additional 2.00%
						calculation.extraWeaponDamageChance = mastery * 0.01
						calculation.masteryLast = mastery
					end
				end
			elseif spec == 3 then
				if mastery > 0 and mastery ~= masteryLast then
					if baseSpell.Finisher then
						local masteryBonus = calculation.masteryBonus
						if masteryBonus then
							calculation.dmgM = calculation.dmgM / masteryBonus
						end
						--Mastery: Executioner
						local bonus = 1 + (mastery * 0.01)
						calculation.dmgM = calculation.dmgM * bonus
						calculation.masteryLast = mastery
						calculation.masteryBonus = bonus
					end
				end
			end
		end
		--TODO: Verify if poison AP coefficients scale or not
		local wpicon = "|T" .. select(3,GetSpellInfo(8679)) .. ":16:16:1:1|t"
		local dpicon = "|T" .. select(3,GetSpellInfo(2823)) .. ":16:16:1:-1|t"
		local mgicon = "|T" .. select(3,GetSpellInfo(76806)) .. ":16:16:1:1|t"
		local hmicon = "|T" .. select(3,GetSpellInfo(56807)) .. ":16:16:1:1|t"
		local vwicon = "|T" .. select(3,GetSpellInfo(79134)) .. ":16:16:1:1|t"		
		self.Calculation["ROGUE"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
			--TODO: Check specialization is active
			if IsSpellKnown(86531) then
				calculation.agiM = calculation.agiM * 1.05
			end
			--Specialization
			local spec = calculation.spec
			local mastery = calculation.mastery
			if spec == 1 then
				calculation.impPoison = true
			elseif spec == 2 then
				--Vitality: Increased attack power by 30%
				calculation.APM = calculation.APM * 1.4
				--Ambidexterity: Increased off-hand damage
				calculation.offHdmgM = calculation.offHdmgM * 1.75
				if mastery > 0 then
					local mgicon = "|T" .. select(3,GetSpellInfo(76806)) .. ":16:16:1:1|t"
					--Main gauche
					--Your main hand attacks have a chance to grant you an extra attack (1.2x mh weapon damage) based on mastery%
					if baseSpell.AutoAttack or calculation.spellName == "Killing Spree" then
						--Killing Spree apparently counts for main gauche
						if not calculation.extraDamage then calculation.extraDamage = 0 end
						calculation.extraWeaponDamage = 1.2
						calculation.extraWeaponDamageM = true
						calculation.extraWeaponDamageNorm = false
						calculation.extraWeaponDamage_dmgM = calculation.dmgM_global
						calculation.extra_canCrit = true
						--calculation.extra_critPerc = GetCritChance() + calculation.meleeCrit
						calculation.extraName = calculation.extraName and (calculation.extraName .. " MG " .. mgicon) or ( " MG " .. mgicon )
					end
				end
			elseif spec == 3 then
				--Sinister Calling: Increases agility by 30%
				calculation.agiM = calculation.agiM * 1.3
				if calculation.spellName == "Hemorrhage" then
					--Multiplicative according to tooltip
					calculation.WeaponDamage = calculation.WeaponDamage * 1.40
				end
				--Sanguinary Vein increases damage against bleeding targets
				if IsSpellKnown(79147) and ActiveAuras["Bleeding"] then
					calculation.dmgM = calculation.dmgM * 1.25
				end
				--TODO-MINOR: Slice and Dice bonus from Executioner?
			end
			if ActiveAuras["Blade Flurry"] then
				if calculation.aoe then
					--calculation.targets = calculation.targets * 2
					calculation.targets = 5
					calculation.aoeM = 0.4
				end
			end
			if not baseSpell.NoPoison and (ActiveAuras["Wound Poison"] or ActiveAuras["Deadly Poison"]) then
				calculation.E_dmgM = calculation.dmgM_Magic --* select(7,UnitDamage("player")) / calculation.dmgM_Physical
	            calculation.E_canCrit = true
				--Improved Poisons
				calculation.extraChance = (0.30 + (IsSpellKnown(14117) and 0.2 or 0)) * math_max(0,math_min(1, (calculation.hit + calculation.hitPerc)/100))
				if ActiveAuras["Wound Poison"] then
					calculation.extra = self:ScaleData(0.417, 0.28, calculation.playerLevel, 0)
					calculation.extraDamage = 0.12
					calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. wpicon) or wpicon
	            elseif ActiveAuras["Deadly Poison"] then
					if not ActiveAuras["Poisoned"] then
						--Include only DoT portion
						calculation.extra = 4 * self:ScaleData(0.6, 0, calculation.playerLevel,0)
						calculation.extraDamage = 4 * 0.213
						calculation.extraTicks = 4
						calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. dpicon .. " DoT") or (dpicon .. " DoT")
						calculation.E_eDuration = 12
					else
						--Instant portion
						calculation.extra = self:ScaleData(0.313,0.28,calculation.playerLevel,0)
						calculation.extraDamage = 0.109
						calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. dpicon) or dpicon				
						--DoT portion into DPS calculation
						calculation.extra_DPS = 4 * self:ScaleData(0.6, 0, calculation.playerLevel, 0)
						calculation.extra_DPS_canCrit = true
						calculation.extraDamage_DPS = 4 * 0.213
						calculation.extraDuration_DPS = 12
						calculation.extraName_DPS = dpicon .. " DoT"
					end
				end
			end
		end
		self.Calculation["Relentless Strikes"] = function( calculation, value )
			calculation.actionCost = calculation.actionCost - value * calculation.Melee_ComboPoints * 25
		end
		self.Calculation["Shiv"] = function( calculation, _ )
			local spec = calculation.spec
			calculation.extraChance_O = 0.01 * math_max(0,math_min(100, self:GetMeleeHit(calculation.playerLevel,calculation.targetLevel) + calculation.meleeHit))
			calculation.E_canCrit = false
			if spec == 2 and IsSpellKnown(35551) then
				calculation.actionCost = calculation.actionCost - 0.3 * 0.2 * (calculation.hitO / 100)
			end
		end
		self.Calculation["Envenom"] = function( calculation, ActiveAuras )
			local spec = calculation.spec
			if ActiveAuras["Deadly Poison"] then
				calculation.Melee_ComboPoints = math_min(ActiveAuras["Deadly Poison"], calculation.Melee_ComboPoints)
			else
				calculation.Melee_ComboPoints = 0
				calculation.zero = true
			end
                	--Assassin's Resolve
                	if spec == 1 and IsSpellKnown(84601) then
                   		calculation.dmgM = calculation.dmgM * 1.25
			end
		end
		self.Calculation["Mutilate"] = function( calculation, ActiveAuras )
			local spec = calculation.spec
			--Assassin's Resolve
			if spec == 1 and IsSpellKnown(84601) then
				calculation.dmgM = calculation.dmgM * 1.25
			end
		end
		self.Calculation["Killing Spree"] = function( calculation, ActiveAuras )
			if not ActiveAuras["Killing Spree"] then
				-- Killing Spree adds 50% damage (no glyph needed)
		  		calculation.dmgM = calculation.dmgM * 1.5 
			end
		end
		self.Calculation["Rupture"] = function( calculation, ActiveAuras )
			local spec = calculation.spec
			if self:GetSetAmount("T15") >= 2 and calculation.Melee_ComboPoints > 0 then
				calculation.Melee_ComboPoints = calculation.Melee_ComboPoints + 1
			end
			if spec == 1 then
				--Venomous Wounds
				if IsSpellKnown(79134) then
					if not calculation.extraDamage then
						calculation.extraDamage = 0
					end
					--TODO: Add hits and crits?
					calculation.extraTickDamage = self:ScaleData(0.6, nil, calculation.playerLevel)
					calculation.extraTickDamageBonus = 0.176
	                                if self:GetSetAmount("T14") >= 2 then
       		                              calculation.extraTickDamage = calculation.extraTickDamage * 1.2
					end
					--Chance to do extra damage is at 75%
					calculation.extraTickDamageChance = 0.75
					calculation.extraTickDamageCost = 10
					calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. vwicon) or vwicon
				end
				--Assassin's Resolve
				if IsSpellKnown(84601) then
					calculation.dmgM_Add = calculation.dmgM_Add * 1.25
				end
				if self:GetSetAmount("T14") >= 2 then
					calculation.dmgM_Add = calculation.dmgM_Add * 1.2
				end
			elseif spec == 3 then
				-- Sanguinary Vein adds 50% to rupture
				if IsSpellKnown(79147) then
					calculation.dmgM_Add = calculation.dmgM_Add * 1.5
				end
			end
		end
		self.Calculation["Garrote"] = function( calculation, ActiveAuras )
			--Venomous wounds, plus deadly poison or wound poison 
			if IsSpellKnown(79134) and (ActiveAuras["Deadly Poison"] or ActiveAuras["Wound Poison"]) then
				if not calculation.extraDamage then
					calculation.extraDamage = 0
				end
				--TODO: Add hits and crits?
				calculation.extraTickDamage = self:ScaleData(0.6, nil, calculation.playerLevel)
				calculation.extraTickDamageBonus = 0.176
                                if self:GetSetAmount("T14") >= 2 then
                                      calculation.extraTickDamage = calculation.extraTickDamage * 1.2
                                end
				calculation.extraTickDamageChance = 0.75
				calculation.extraTickDamageCost = 10
				calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. vwicon) or vwicon
			end
		end
		self.Calculation["Hemorrhage"] = function( calculation )
			if self:GetNormM() == 1.8 then
				calculation.WeaponDamage = calculation.WeaponDamage * 2.03
			elseif self:GetNormM() >= 2.0 then
				calculation.WeaponDamage = calculation.WeaponDamage * 1.4
			end
			calculation.extraAvg = 0.5 * calculation.bleedBonus
			calculation.extraAvgM = 1
			calculation.extraAvgChance = 1
			calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. hmicon) or hmicon
			--Duration 24, ticks every 3 seconds
			calculation.extraTicks = 8
		end
		self.Calculation["Crimson Tempest"] = function ( calculation )
			local spec = calculation.spec
			--Sub gets 24% more damage on this ability
			if spec == 3 then
				calculation.dmgM = calculation.dmgM * 1.24
			end
			calculation.extraAvg = 2.4 * calculation.bleedBonus
			calculation.extraTicks = 6
			calculation.extra_canCrit = true
			calculation.extraName = "CoT DoT"
		end
		self.Calculation["Sinister Strike"] = function( calculation )
			if self:GetSetAmount("Legendary Dagger") >= 1 then
				calculation.dmgM_Add = calculation.dmgM_Add + 0.45
			end
			if self:GetSetAmount("T14") >= 2 then
				--Multiplicative based on tooltip
				calculation.dmgM = calculation.dmgM * 1.15
			end
		end
		self.Calculation["Revealing Strike"] = function( calculation )
			if self:GetSetAmount("Legendary Dagger") >= 1 then
				calculation.dmgM_Add = calculation.dmgM_Add + 0.45
			end		
		end	
		self.Calculation["Backstab"] = function( calculation )
			if self:GetSetAmount("T14") >= 2 then
				calculation.dmgM = calculation.dmgM * 1.10
			--if UnitHealth("target") ~= 0 and (UnitHealth("target") / UnitHealthMax("target")) < 0.35 then
			--	calculation.actionCost = calculation.actionCost - Talents["Murderous Intent"]
			end
		end
		self.Calculation["Ambush"] = function( calculation )
			if Weapon == GetSpellInfo(1180) then
				--Daggers
				calculation.dmgM_add = calcuation.dmgM_Add * 1.447
			end
		end
		self.Calculation["Attack"] = function( calculation, ActiveAuras )
			if ActiveAuras["Shadow Blades"] then
				calculation.glancing = nil
				calculation.dmgM = calculation.dmgM * calculation.dmgM_Magic
				calculation.armorM = 1
			end
		end
		--SETS
		--	--T14
		self.SetBonuses["T14"] = { 87126, 87128, 87124, 87127, 87125, 85301, 85299, 85303, 85300, 85302, 86641, 86639, 86643, 86640, 86642 }
		self.SetBonuses["T15"] = { 95305, 95306, 95307, 95308, 95309, 95935, 95936, 95937, 95938, 95939, 96679, 96680, 96681, 96682, 96683 }
		--Legendary Daggers: Fear, The Sleeper, Golad, Twilight of Aspects
		self.SetBonuses["Legendary Dagger"] = { 77945, 77947, 77949 }
		--AURA
		--Player
		--Killing Spree (TODO: Verify API handles it properly)
		self.PlayerAura[GetSpellInfo(51690)] = { ActiveAura = "Killing Spree", ID = 51690 }
		--Envenom (4.0)
		self.PlayerAura[GetSpellInfo(32645)] = { ActiveAura = "Envenom", ID = 32645 }
		--Blade Flurry (4.0)
		self.PlayerAura[GetSpellInfo(13877)] = { ActiveAura = "Blade Flurry", Not = { "Fan of Knives", "Crimson Tempest", "Rupture", "Garrote" }, ID = 13877 }
		--Slice and Dice (4.0)
		self.PlayerAura[GetSpellInfo(5171)] = { Finisher = true, ID = 5171, Mods = { ["haste"] = function(v) return v * 1.4 end } }
		--Shallow Insight
		self.PlayerAura[GetSpellInfo(84745)] = { SelfCast = true, ID = 84745, Category = "Bandit's Guile", Value = 0.1 }
		--Moderate Insight
		self.PlayerAura[GetSpellInfo(84746)] = { SelfCast = true, ID = 84746, Category = "Bandit's Guile", Value = 0.2 }
		--Deep Insight
		self.PlayerAura[GetSpellInfo(84747)] = { SelfCast = true, ID = 84747, Category = "Bandit's Guile", Value = 0.3 }
		--Deadly Poison (4.0)
		self.PlayerAura[GetSpellInfo(2823)] = { ActiveAura = "Deadly Poison", ID = 2823, BuffID = 2823 }
		--Wound Poison (4.0)
		self.PlayerAura[GetSpellInfo(43461)] = { ActiveAura = "Wound Poison", ID = 8679, BuffID = 8679 }
		--Target
		self.TargetAura[GetSpellInfo(2818)] = { ActiveAura = "Poisoned", ID = 2818, DebuffID = 2818, SelfCast = true }
		--Vendetta (4.0)
		self.TargetAura[GetSpellInfo(79140)] = { SelfCast = true, ID = 79140, Value = 0.3 }
		--Revealing Strike (Only affects Eviscerate and Rupture - verified on WoWhead and WoWDB)
		self.TargetAura[GetSpellInfo(84617)] = { SelfCast = true, ID = 84617, Spells = { "Eviscerate", "Rupture" }, ModType =
			function( calculation )
				calculation.dmgM = calculation.dmgM * 1.35 
			end
		}
		--Find Weakness (4.0)
		self.TargetAura[GetSpellInfo(91023)] = { Ranks = 1, Value = 0.7, ModType = "armorM", ID = 91023 }
		--Bleed effects (TODO: Verify this contains all important ones)
		--Crimson Tempest
		self.TargetAura[GetSpellInfo(122233)] = { ActiveAura = "Bleeding", ID = 122233 }
		--Garrote - 4.0
		self.TargetAura[GetSpellInfo(703)] = 	self.TargetAura[GetSpellInfo(122233)]
		--Rupture - 4.0
		self.TargetAura[GetSpellInfo(1943)] = 	self.TargetAura[GetSpellInfo(122233)]
		--Shadow blades
		self.TargetAura[GetSpellInfo(121471)] = { ActiveAura = "Shadow Blades", ID = 121471 }

	self.spellInfo = {
		[GetSpellInfo(1752)] = {
			["Name"] = "Sinister Strike",
			["ID"] = 1752,
			["Data"] = { 0.178 },
			--AoE here is only relevant to Blade Flurry
			[0] = { WeaponDamage = 2.4, AoE = true, NoPoison = true },
			[1] = { 0 },
		},
		[GetSpellInfo(53)] = {
			["Name"] = "Backstab",
			["ID"] = 53,
			["Data"] = { 0.307 },
			[0] = { WeaponDamage = 3.8, NoPoison = true, Weapon = GetSpellInfo(1180) }, --Daggers
			[1] = { 0 },
		},
		[GetSpellInfo(2098)] = {
			["Name"] = "Eviscerate",
			["ID"] = 2098,
			["Data"] = { 0.593 * 0.9, 1, ["perCombo"] = 0.786 * 0.9 },
			[0] = { School = "Physical", ComboPoints = true, APBonus = 0.16 * 0.9, Finisher = true, AoE = true },
			[1] = { 0, 0, PerCombo = 0 },
		},
		[GetSpellInfo(8676)] = {
			["Name"] = "Ambush",
			["ID"] = 8676,
			["Data"] = { 0.5 },
			[0] = { WeaponDamage = 3.25, AoE = true, NoPoison = true },
			[1] = { 0 },
		},
		[GetSpellInfo(703)] = {
			-- This matches datamined info, but doesn't match in game values.  Need to figure out why.
			["Name"] = "Garrote",
			["ID"] = 703,
			["Data"] = { 0.70769 },
			[0] = { DotHits = 6, APBonus = 0.468, eDuration = 18, Ticks = 3, NoWeapon = true, NoPoison = true, Bleed = true },
			[1] = { 0 },
		},
		[GetSpellInfo(1943)] = {
			["Name"] = "Rupture",
			["ID"] = 1943,
			["Data"] = { 0.1853, ["perCombo"] = 0.0256 },
			[0] = { ComboPoints = true, APBonus = 0.186, DotHits = 4, eDuration = 8, Ticks = 2, TicksPerCombo = 1, Bleed = true, Finisher = true, NoPoison = true, AoE = false },
			[1] = { 0, PerCombo = 0, },
		},
		[GetSpellInfo(16511)] = {
			["Name"] = "Hemorrhage",
			["ID"] = 16511,
			["Data"] = { 0 },
			[0] = { WeaponDamage = 1.6, NoPoison = true },
			[1] = { 0 },
		},
		[GetSpellInfo(121411)] = {
			["Name"] = "Crimson Tempest",
			["ID"] = 121411,
			["Data"] = { 0.476, ["perCombo"] = 0.028 },
                        [0] = { APBonus = 0.028, ComboPoints = true, Finisher = true, AoE = false, Bleed = true },
			[1] = { 0 }, 
		},
		[GetSpellInfo(5938)] = {
			["Name"] = "Shiv",
			["ID"] = 5938,
			[0] = { WeaponDamage = 0.25, OffhandAttack = true, NoCrits = true, NoNormalization = true, NoPoison = true },
			[1] = { 0 },
		},
		[GetSpellInfo(32645)] = {
			["Name"] = "Envenom",
			["ID"] = 32645,
			["Data"] = { 0.3849, ["perCombo"] = 0.3851 },
			[0] = { School = "Nature", ComboPoints = true, APBonus = 0.112, Finisher = true },
			[1] = { 0, PerCombo = 0 },
		},
		[GetSpellInfo(26679)] = {
			["Name"] = "Deadly Throw",
			["ID"] = 26679,
			["Data"] = { 0.429, 1 },
			[0] = { School = { "Physical", "Ranged" }, ComboPoints = true, WeaponDamage = 1, NoPoison = true, NoNormalization = true, Finisher = true },
			[1] = { 0, 0, PerCombo = 0 },
		},
		[GetSpellInfo(1329)] = {
			["Name"] = "Mutilate",
			["ID"] = 1329,
			["Data"] = { 0.179 },
			[0] = { WeaponDamage = 2.8, School = "Physical", DualAttack = true, NoPoison = true, Weapon = GetSpellInfo(1180) }, --Daggers
			[1] = { 0 },
		},
		[GetSpellInfo(51723)] = {
			["Name"] = "Fan of Knives",
			["ID"] = 51723,
			["Data"] = { 1 }, 
			[0] = { AoE = false, APBonus = 0.14, NoNormalization = true },
			[1] = { 0 },
		},
		[GetSpellInfo(51690)] = {
			["Name"] = "Killing Spree",
			["ID"] = 51690,
			[0] = { WeaponDamage = 1, DualAttack = true, Hits = 7, NoNormalization = true, AoE = true },
			[1] = { 0 },
		},
		[GetSpellInfo(84617)] = {
			["Name"] = "Revealing Strike",
			["ID"] = 84617,
			["Data"] = { 0 },
			[0] = { AoE = true, WeaponDamage = 1.6, NoNormalization = true, NoPoison = true },
			[1] = { 0 },
		},
		[GetSpellInfo(111240)] = {
			["Name"] = "Dispatch",
			["ID"] = 111240,
			["Data"] = { 2.0669 },
			[0] = { WeaponDamage = 6.45, NoPoison = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(114014)] = {
			["Name"] = "Shuriken Toss",
			["ID"] = 114014, 
			["Data"] = { 2 },
			[0] = { APBonus = 0.6 },
			[1] = { 0, 0 },
		},
	}
	self.talentInfo = {
	--ALL:
		--Relentless Strikes
		--Now affects more abilities (verified on wowhead's "modified by").
		[GetSpellInfo(58423)] = {	[1] = { Effect = { 0.20 }, Spells = { "Eviscerate", "Rupture", "Slice and Dice", "Crimson Tempest", "Envenom" }, ModType = "Relentless Strikes", }, },
	--ASSASSINATION:
		--Venomous Wounds
		[GetSpellInfo(79134)] = {	[1] = { Effect = 0.3, Spells = { "Rupture", "Garrote" }, ModType = "Venomous Wounds" }, },
	--COMBAT:
	--SUBTLETY:
	}
end
