if select(2, UnitClass("player")) ~= "HUNTER" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitCreatureType = UnitCreatureType
local UnitRangedDamage = UnitRangedDamage
local GetTrackingTexture = GetTrackingTexture
local GetInventoryItemLink = GetInventoryItemLink
local IsEquippedItem = IsEquippedItem
local tonumber = tonumber
local string_match = string.match
local string_find = string.find
local string_lower = string.lower
local select = select
local math_min = math.min
local math_max = math.max
local IsSpellKnown = IsSpellKnown

function DrDamage:PlayerData()
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			if mastery > 0 and mastery ~= masteryLast then
				if baseSpell.PetAttack then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					local bonus = 1 + mastery * 0.01
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		elseif spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.group == "Ranged" and (calculation.subType ~= "Trap" or calculation.spellName ~= "Serpent Sting") then
					--Mastery: Wild Quiver
					calculation.extraWeaponDamage = 0.8
					calculation.extraWeaponDamageChance = mastery * 0.01 
					calculation.masteryLast = mastery
				end
			end
		elseif spec == 3 then
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.school ~= "Physical" then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					--Mastery: Essence of the Viper - Increases all magic damage you deal
					local bonus = 1 + mastery * 0.01
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		end
	end
	local piercingshots = "|T" .. select(3,GetSpellInfo(53234)) .. ":16:16:1:-1|t"
	local wildquiver = "|T" .. select(3,GetSpellInfo(76659)) .. ":16:16:1:-1|t"
	self.Calculation["HUNTER"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		--TODO: Check specialization is active
		if IsSpellKnown(86528) then
			calculation.agiM = calculation.agiM * 1.05
		end
		--Specialization
		local spec = calculation.spec
		--if spec == 1 then
		if spec == 2 then
			if calculation.mastery > 0 then
				if calculation.group == "Ranged" and calculation.subType ~= "Trap" then
					calculation.extraDamage = 0
					calculation.extraWeaponDamage = 1
					calculation.extra_canCrit = true
					calculation.extraName = wildquiver
				end
			end
		--elseif spec == 3 then
		end
		--Careful Aim
		if IsSpellKnown(34483) and UnitHealth("target") ~= 0 and ((UnitHealth("target") / UnitHealthMax("target")) > 0.8) and baseSpell.CarefulAim then
			calculation.critPerc = calculation.critPerc + 75
		end
		--Piercing Shots
		if IsSpellKnown(53238) and baseSpell.PiercingShot then
			--TODO: Fix crits in conjunction with wild quiver
			calculation.extraDamage = 0
			calculation.extraCrit = 0.3
			calculation.extraChanceCrit = true
			if calculation.extraName then
				calculation.extraName = calculation.extraName .. "+" .. piercingshots
			else
				calculation.extraTicks = 8
				calculation.extraName = piercingshots
			end
		end
	end
--ABILITIES
	--self.Calculation["Steady Shot"] = function( calculation, ActiveAuras )
	--end
	local serpent_sting = GetSpellInfo(1978)
	--local serpent_sting_icon = "|T" .. select(3,GetSpellInfo(1978)) .. ":16:16:1:-1|t"
	--local improved_serpent_sting = GetSpellInfo(82834)
	local improved_serpent_sting_icon = "|T" .. select(3,GetSpellInfo(82834)) .. ":16:16:1:-1|t"
	--self.Calculation["Multi-Shot"] = function( calculation, _, Talents )
		--Gladiator's Chain Gauntlets
		--if IsEquippedItem( 28335 ) or IsEquippedItem( 31961 ) or IsEquippedItem( 33665 ) then
		--	calculation.cooldown = calculation.cooldown - 1
		--end
		--[[if Talents["Serpent Spread"] then
			local hits = Talents["Serpent Spread"] / 3
			local iss = (Talents["Improved Serpent Sting"] or 0) * self.spellInfo[serpent_sting][0].Hits
			local bonus = 1 + (self:GetSetAmount("T8") >= 2 and 0.1 or 0) + (self:GetSetAmount("T9") >= 2 and 0.1 or 0)
			calculation.extra = bonus * (hits + iss) * self.spellInfo[serpent_sting][1][2]
			calculation.extraDamage = bonus * (hits + iss) * self.spellInfo[serpent_sting][0].APBonus
			calculation.extraName = serpent_sting
		end--]]
	--end
	self.Calculation["Serpent Sting"] = function ( calculation, _, Talents )
		if self:GetSetAmount("T11") >= 2 then
			calculation.critPerc = calculation.critPerc + 5
		end
		--Improved Serpent Sting
		if IsSpellKnown(82834) then
			--Increases damage by 50% and then adds a 15% instant hit.
			calculation.dmgM = calculation.dmgM * 1.5
			calculation.extra = 0.15 * calculation.hits * calculation.maxDam
			calculation.extraDamage = 0.15 * calculation.hits * calculation.APBonus
			calculation.extra_canCrit = true
			if calculation.extraName then
				calculation.extraName = calculation.extraName .. "+" .. improved_serpent_sting_icon
			else
				calculation.extraName = improved_serpent_sting_icon
			end
		end
	end
	--self.Calculation["Arcane Shot"] = function ( calculation )
	--end
	--self.Calculation["Chimera Shot"] = function ( calculation, ActiveAuras, Talents )
	--end
	self.Calculation["Explosive Shot"] = function ( calculation )
		--5.4 buff
		calculation.dmgM = calculation.dmgM * 1.27
	end
	self.Calculation["Explosive Trap"] = function ( calculation )
		--5.4 nerf
		calculation.dmgM = calculation.dmgM * 0.7

		local mastery = calculation.mastery
		--Mastery: Essence of the Viper - Increases all magic damage you deal
		local bonus = 1 + mastery * 0.01
		calculation.dmgM = calculation.dmgM * bonus
		-- For some reason mastery doesn't affect the trap like it should.  This works, however.
	end
	--self.Calculation["Immolation Trap"] = function ( calculation, ActiveAuras, Talents )
	--end
	--self.Calculation["Wyvern Sting"] = function ( calculation )
	--end
	--self.Calculation["Aimed Shot"] = function( calculation, ActiveAuras, Talents )
	--end
	--self.Calculation["Black Arrow"] = function ( calculation )
	--end
	--self.Calculation["Kill Shot"] = function ( calculation )
	--end
	self.Calculation["Kill Command"] = function (calculation)
		calculation.dmgM = calculation.dmgM * 1.34
	end
--SETS
	self.SetBonuses["T11"] = { 60303, 60304, 60305, 60306, 60307, 65204, 65205, 65206, 65207, 65208 }
--AURA
--Player
	--Sniper Training - 4.0
	self.PlayerAura[GetSpellInfo(53302)] = { Spells = { "Steady Shot", "Cobra Shot" }, ModType = "dmgM_Add", Value = 0.02, Ranks = 3, ID = 53302 }
--Target
	--Freezing Trap - 4.0
	self.TargetAura[GetSpellInfo(3355)] = { ActiveAura = "Frozen", ID = 3355, Manual = GetSpellInfo(3355) }
	--Ice Trap - 4.0
	self.TargetAura[GetSpellInfo(13810)] = self.TargetAura[GetSpellInfo(3355)]
	--Serpent Sting - 4.0
	self.TargetAura[GetSpellInfo(1978)] = { ActiveAura = "Serpent Sting", ID = 1978 }
--Custom
	--Hunter's Mark - 4.0
	self.TargetAura[GetSpellInfo(1130)] = { School = "Ranged", ID = 1130, Value = 0.05, ModType = "dmgM" } 
	
	self.spellInfo = {
		[GetSpellInfo(75)] = {
			["Name"] = "Auto Shot",
			["ID"] = 75,
			[0] = { School = { "Physical", "Ranged", "Shot" }, WeaponDamage = 1, NoNormalization = true, AutoShot = true, DPSrg = true },
			[1] = { 0 },
		},
		[GetSpellInfo(3044)] = {
			["Name"] = "Arcane Shot",
			["ID"] = 3044,
			["Data"] = { 1.85 },
			[0] = { School = { "Arcane", "Ranged", "Shot" }, WeaponDamage = 1.25 },
			[1] = { 0 },
		},
		[GetSpellInfo(19434)] = {
			["Name"] = "Aimed Shot",
			["ID"] = 19434,
			["Data"] = { 2.2, 0.10 },
			[0] = { School = { "Physical", "Ranged", "Shot" }, WeaponDamage = 4.5, BleedExtra = true, PiercingShot = true, CarefulAim = true },
			[1] = { 0 },
		},
		[GetSpellInfo(2643)] = {
			-- Checked in 4.1
			["Name"] = "Multi-Shot",
			["ID"] = 2643,
			["Data"] = { 0 },
			[0] = { School = { "Physical", "Ranged", "Shot" }, WeaponDamage = 0.60, AoE = true },
			[1] = { 0 },
		},
		[GetSpellInfo(19503)] = {
			["Name"] = "Scatter Shot",
			["ID"] = 19503,
			[0] = { School = { "Physical", "Ranged", "Shot" }, WeaponDamage = 0.5, Cooldown = 30, NoNormalization = true },
			[1] = { 0 },
		},
		[GetSpellInfo(56641)] = {
			["Name"] = "Steady Shot",
			["ID"] = 56641,
			["Data"] = { 1.1522 }, 
			[0] = { School = { "Physical", "Ranged", "Shot" }, WeaponDamage = 0.6, BleedExtra = true, PiercingShot = true, CarefulAim = true },
			[1] = { 0 },
		},
		[GetSpellInfo(53351)] = {
			["Name"] = "Kill Shot",
			["ID"] = 53351,
			["Data"] = { 0 }, 
			[0] = { School = { "Physical", "Ranged", "Shot" }, WeaponDamage = 4.2, Cooldown = 6 },
			[1] = { 0 },
		},
		--TODO-MINOR: 5% self heal
		[GetSpellInfo(53209)] = {
			["Name"] = "Chimera Shot",
			["ID"] = 53209,
			["Data"] = { 1.25 },
			[0] = { School = { "Nature", "Ranged", "Shot" }, WeaponDamage = 2.65, Cooldown = 9, BleedExtra = true, PiercingShot = true },
			[1] = { 0 },
		},
		[GetSpellInfo(13813)] = {
			["Name"] = "Explosive Trap",
			["ID"] = 13813,
			["Data"] = { 0.1981, 0.25, ["extra"] = 0.02567 },
			[0] = { School = { "Fire", "Ranged", "Trap" }, APBonus = 0.0546, Hits_extra = 10, APBonus_extra = 0.546, E_eDuration = 20, E_Ticks = 2, E_canCrit = true, Cooldown = 30, AoE = true, E_AoE = true, Unresistable = true, },
			[1] = { 0, 0, Extra = 0, },
		},
		[GetSpellInfo(1978)] = {
			["Name"] = "Serpent Sting",
			["ID"] = 1978,
			["Data"] = { 2.5999 },
			[0] = { School = { "Nature", "Ranged" }, APBonus = 0.16, eDot = true, Hits = 5, eDuration = 15, Ticks = 3, },
			[1] = { 0 },
		},
		[GetSpellInfo(3674)] = {
			["Name"] = "Black Arrow",
			["ID"] = 3674,
			["Data"] = { 1.2597 },
			[0] = { School = { "Shadow", "Ranged" }, APBonus = 0.126, eDot = true, Hits = 10, eDuration = 20, Ticks = 2, Cooldown = 30 },
			[1] = { 0 },
		},
		[GetSpellInfo(53301)] = {
			["Name"] = "Explosive Shot",
			["ID"] = 53301,
			["Data"] = { 0.3081, 1 },
			[0] = { School = { "Fire", "Ranged", "Shot" }, APBonus = 0.3079, Cooldown = 6, Hits = 2, sTicks = 1, NoHits = true },
			[1] = { 0 },
		},
		[GetSpellInfo(77767)] = {
			["Name"] = "Cobra Shot",
			["ID"] = 77767,
			["Data"] = { 0 },
			[0] = { School = { "Nature", "Ranged", "Shot" }, WeaponDamage = 0.7 },
			[1] = { 0 },
		},
		[GetSpellInfo(34026)] = {
			["Name"] = "Kill Command",
			["ID"] = 34026,
			["Data"] = { 0.84 },
			[0] = { School = { "Physical", "Ranged" }, APBonus = 1.05, Cooldown = 6, PetAttack = true },
			[1] = { 0 },
		},
		--Pets
		[GetSpellInfo(17253)] = {
			["Name"] = "Bite",
			["ID"] = 17253,
			["Data"] = { 0.1709 },
			[0] = { School = { "Physical", "Ranged" }, APBonus = 0.252, Cooldown = 3, PetAttack = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(16827)] = {
			["Name"] = "Claw",
			["ID"] = 16827,
			["Data"] = { 0.1709 },
			[0] = { School = { "Physical", "Ranged" }, APBonus = 0.252, Cooldown = 3, PetAttack = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(92380)] = {
			["Name"] = "Froststorm Breath",
			["ID"] = 92380,
			["Data"] = { 0.2206 },
			[0] = { School = { "Froststorm", "Ranged" }, APBonus = 0.144, eDuration = 8, Hits = 4, sTicks = 2, AoE = true, PetAttack = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(49966)] = {
			["Name"] = "Smack",
			["ID"] = 49966,
			["Data"] = { 0.1709 },
			[0] = { School = { "Physical", "Ranged" }, APBonus = 0.252, Cooldown = 3, PetAttack = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(93433)] = {
			["Name"] = "Burrow Attack",
			["ID"] = 93433,
			[0] = { School = { "Nature", "Ranged" }, eDuration = 8, APBonus = 0.922, Cooldown = 14, PetAttack = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(90361)] = {
			["Name"] = "Spirit Mend",
			["ID"] = 90361,
			["Data"] = { 1.1, 0, 0.175, 0.423, 0 },
			[0] = { School = { "Nature", "Ranged", "Healing" }, eDuration = 10, Hits = 5, sTicks = 2, APBonus = 0.117, Cooldown = 30, PetAttack = true },
			[1] = { 0, 0 },
		}, 
	}
	self.talentInfo = {
	--BEAST MASTERY:

	--MARKMANSHIP:
		--Careful Aim
		--TODO: Rewrite this one
	--SURVIVAL:
		--Improved Serpent Sting
		[GetSpellInfo(82834)] = {	[1] = { Effect = 0.15, Spells = { "Serpent Sting", }, ModType = "Improved Serpent Sting" } } ,
		--Trap Mastery (additive - 3.3.3)
		[GetSpellInfo(63458)] = {	[1] = { Effect = 0.3, Spells = { "Explosive Trap", "Black Arrow" }, ModType = "dmgM_Extra_Add" }, },
	}
end
