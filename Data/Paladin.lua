if select(2, UnitClass("player")) ~= "PALADIN" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local GetTrackingTexture = GetTrackingTexture
local GetSpellBonusDamage = GetSpellBonusDamage
local math_floor = math.floor
local math_min = math.min
local string_match = string.match
local string_find = string.find
local string_lower = string.lower
local tonumber = tonumber
local select = select
local pairs = pairs
local UnitBuff = UnitBuff
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitCreatureType = UnitCreatureType
local UnitIsUnit = UnitIsUnit
local IsSpellKnown = IsSpellKnown

function DrDamage:PlayerData()
	--Events
	local lastPower = UnitPower("player",9)
	self.Calculation["UNIT_POWER"] = function()
		local power = UnitPower("player",9)
		if power ~= lastPower then
			lastPower = power
			--TODO: Add which spells to update
			self:UpdateAB()
		end
	end
	--Lay on Hands (4.0)
	self.ClassSpecials[GetSpellInfo(633)] = function()
		return UnitHealthMax("player"), true
	end
	--Divine Plea (4.0)
	self.ClassSpecials[GetSpellInfo(54428)] = function()
		return 0.12 * UnitPowerMax("player",0), false, true
	end
	--Seal of Insight Heal (4.0)
	self.ClassSpecials[GetSpellInfo(20165)] = function()
		local AP = 0.15 * self:GetAP()
		local SP = 0.15 * GetSpellBonusDamage(2)
		return AP + SP, true
	end
--GENERAL
	local hol_icon = "|T" .. select(3,GetSpellInfo(76672)) .. ":16:16:1:-1|t"
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local illuminated_healing_icon = "|T" .. select(3,GetSpellInfo(76669)) .. ":16:16:1:-1|t"
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			-- Updated for 4.1 -- Illuminated Healing bonus increased from 1.25% to 1.5% per mastery
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.healingSpell then
					--Mastery: Illuminated Healing
					calculation.extraAvg = mastery * 0.01 
					calculation.masteryLast = mastery
					calculation.extraName = calculation.extraName and (calculation.extraName .. "+ Holy Mastery" .. illuminated_healing_icon) or ("Holy Mastery" .. illuminated_healing_icon)
				end
			end
			--Holy Insight
			if IsSpellKnown(112859) then
				if calculation.spellName == "Holy Shock" or calculation.spellName == "Denounce" or calculation.spellName == "Judgment" then
					calculation.hitPerc = 100
				end
				if calculation.spellName == "Eternal Flame" or calculation.spellName == "Word of Glory" or calculation.spellName == "Light of Dawn" then
					calculation.dmgM = calculation.dmgM * 1.5
				else
					if calculation.baseSchool == "Healing" then 
						calculation.dmgM = calculation.dmgM * 1.25
					end
				end
			end
		elseif spec == 2 then
			if calculation.str ~= 0 then
				--Increases your spell power by an amount equal to 50% of your Strength.
				calculation.SP_mod = calculation.SP_mod + 0.5 * calculation.str
			end
		elseif spec == 3 then
			if calculation.str ~= 0 then
 				--Increases your spell power by an amount equal to 50% of your Strength.
				calculation.SP_mod = calculation.SP_mod + 0.5 * calculation.str
			end
			--Sword of Light
			if IsSpellKnown(53503) then
				if calculation.spellName == "Flash of Light" then
					calculation.dmgM = calculation.dmgM * 2
				elseif calculation.spellName == "Word of Glory" then
					calculation.dmgM = calculation.dmgM * 1.3
				end
			end
			if mastery > 0 and mastery ~= masteryLast then
				if baseSpell.HandOfLight then
					--local masteryBonus = calculation.masteryBonus
					--if masteryBonus then
					--	calculation.dmgM = calculation.dmgM / masteryBonus
					--end
					--Mastery: Hand of Light
					local bonus = 1 + (mastery * 0.01)
					calculation.extraAvg = bonus * calculation.dmgM_Magic 
					calculation.extraAvgM = true
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
					calculation.extraDamage = 0
					calculation.extraName = hol_icon			
				end
			end
			if baseSpell.SanctityOfBattle then
				calculation.cooldown = calculation.cooldown * ( 1 - (calculation.haste - 1))
			end
			if ActiveAuras["Inquisition"] then
				calculation.critPerc = calculation.critPerc + 10
			end
		end
	end
	self.Calculation["Stats2"] = function( calculation, ActiveAuras, spell, baseSpell )
		if calculation.spec == 3 and calculation.AP_mod ~= 0 then
			--Increases your spell power by an amount equal to 30% of your attack power
			calculation.SP_mod = calculation.SP_mod + 0.3 * calculation.AP_mod * calculation.SPM
		end
	end
	self.Calculation["PALADIN"] = function( calculation, ActiveAuras, spell, baseSpell )
		local illuminated_healing_icon = "|T" .. select(3,GetSpellInfo(76669)) .. ":16:16:1:-1|t"
		--Specialization
		local spec = calculation.spec
		local currentstance = GetShapeshiftForm()
		if currentstance == 1 then
			seal = "Seal of Truth"
		elseif currentstance == 2 then
			if IsSpellKnown(20154) then
				seal = "Seal of Righteousness"
			else
				seal = "Seal of Insight"
			end
		elseif currentstance == 3 then
			if spec == 3 then
				seal = "Seal of Justice"
			else
				seal = "Seal of Insight"
			end
		elseif currentstance == 4 then
			seal = "Seal of Insight"
		end
		if seal == "Seal of Insight" then
			if calculation.healingSpell and calculation.spellName ~= "Gift of the Naaru" and not baseSpell.L90Talent then
				calculation.dmgM = calculation.dmgM * 1.05
			end
		end
		if spec == 1 then
			--TODO: Check specialization is active
			if IsSpellKnown(86525) then
				calculation.intM = calculation.intM * 1.05
			end
			if calculation.healingSpell then
				--Passive: Walk in the Light
				calculation.dmgM = calculation.dmgM * 1.25
			end
			if calculation.mastery > 0 then
				if calculation.healingSpell then
					calculation.extraName = illuminated_healing_icon
				end
			end
		elseif spec == 2 then
			calculation.APtoSP = true
		elseif spec == 3 then
			calculation.APtoSP = true
			--TODO: Check specialization is active
			if IsSpellKnown(86525) then
				calculation.strM = calculation.strM * 1.05
			end
			--Two-Handed Weapon Specialization
			--"Attack", "Crusader Strike", "Divine Storm", "Hammer of the Righteous", "Templar's Verdict", "Judgement"
			--NOTE: Seal of Truth dot or Seal of Justice base part don't get any bonus
			if IsSpellKnown(53503) and self:GetNormM() == 3.3 then
				if (calculation.WeaponDamage or calculation.group == "Judgement") then
					calculation.wDmgM = calculation.wDmgM * 1.3
					calculation.dmgM = calculation.dmgM * 1.3
				elseif calculation.spellName == "Seal of Justice" then
					calculation.wDmgM = calculation.wDmgM * 1.3
					calculation.dmgM_Extra = calculation.dmgM_Extra * 1.3
				elseif calculation.spellName == "Seal of Righteousness" then
					calculation.wDmgM = calculation.wDmgM * 1.3
					calculation.dmgM_Extra = calculation.dmgM_Extra * 1.3
					--BUG?: Doesn't seem to apply full bonus
					calculation.dmgM_dd = calculation.dmgM_dd * 1.05
				elseif calculation.spellName == "Seal of Truth" then
					calculation.wDmgM = calculation.wDmgM * 1.3
					calculation.dmgM_dd = calculation.dmgM_dd * 1.3
				end
			end
		end
		if not baseSpell.Melee then
			--if calculation.healingSpell then
			--end
		else 
			if calculation.group == "Judgement" then
				if self:GetSetAmount( "PvP Retribution" ) >= 4 then
					calculation.cooldown = calculation.cooldown - 1
				end
			end
			--if calculation.group == "Seal" then
			--end
		end
	end
--TALENTS
	self.Calculation["Divinity"] = function( calculation, value )
		--Multiplicative - 3.3.3
		calculation.dmgM = calculation.dmgM * (1 + value)
		if UnitIsUnit(calculation.target,"player") then
			calculation.dmgM = calculation.dmgM * (1 + value)
		end
	end
--ABILITIES
	self.Calculation["Flash of Light"] = function( calculation, ActiveAuras )
		--PvP Healer Glove Flash of Light Bonus
		if self:GetSetAmount( "PvP Healing Gloves" ) >= 1 then
			calculation.critPerc = calculation.critPerc + 2
		end
	end
	self.Calculation["Holy Radiance"] = function( calculation )
		if self:GetSetAmount( "T13 Holy" ) >= 4 then
			calculation.dmgM_Add = calculation.dmgM_Add + 0.05
		end
		calculation.extraDamage = 0.5
		calculation.extraChance = 1
		calculation.extraName = "Holy Radiance"
		calculation.extraTargets = 5
		if self:GetSetAmount( "T14 Holy" ) >= 2 then
			calculation.manaCost = calculation.manaCost * 0.9
		end
	end	
	self.Calculation["Shield of the Righteous"] = function( calculation, ActiveAuras )
		local hp
		if IsSpellKnown(86172) then
			hp = ActiveAuras["Divine Purpose"] and 3 or math_min(3,UnitPower("player",9))
		else
			hp = math_min(3,UnitPower("player",9))
		end
		if hp > 0 then
			local bonus = select(hp,1,3,6)
			calculation.minDam = calculation.minDam * bonus - bonus
			calculation.maxDam = calculation.maxDam * bonus - bonus
			calculation.APBonus = calculation.APBonus * bonus
		else
			calculation.minDam = 0
			calculation.maxDam = 0
			calculation.APBonus = 0
		end
	end
	self.Calculation["Word of Glory"] = function( calculation, ActiveAuras )
		local hp
		if IsSpellKnown(86172) then
			hp = ActiveAuras["Divine Purpose"] and 3 or math_min(3,UnitPower("player",9))
		else
			hp = math_min(3,UnitPower("player",9))
		end
		if hp > 0 then
			calculation.minDam = calculation.minDam * hp
			calculation.maxDam = calculation.maxDam * hp
			calculation.SPBonus = calculation.SPBonus * hp
			calculation.APBonus = calculation.APBonus * hp
		else
			calculation.minDam = 0
			calculation.maxDam = 0
			calculation.SPBonus = 0
			calculation.APBonus = 0
		end
		if self:GetSetAmount( "T14 Prot" ) >= 4 then
			calculation.dmgM = calculation.dmgM * 1.1
		end
	end
	self.Calculation["Light of Dawn"] = function( calculation, ActiveAuras )
		local hp
		if IsSpellKnown(86172) then
			hp = ActiveAuras["Divine Purpose"] and 3 or math_min(3,UnitPower("player",9))
		else
			hp = math_min(3,UnitPower("player",9))
		end
		if hp > 0 then
			calculation.minDam = calculation.minDam * hp
			calculation.maxDam = calculation.maxDam * hp
			calculation.SPBonus = calculation.SPBonus * hp
		else
			calculation.minDam = 0
			calculation.maxDam = 0
			calculation.SPBonus = 0
		end
		--Glyph of Light of Dawn 4.3
		--Check to see if additive or multiplicative
		if self:HasGlyph(54940) then
			calculation.aoe = calculation.aoe - 2
			calculation.dmgM_Add = calculation.dmgM_Add * 0.25
		end
	end
	self.Calculation["Templar's Verdict"] = function( calculation, ActiveAuras )
		local hp
		if IsSpellKnown(86172) then
			hp = ActiveAuras["Divine Purpose"] and 3 or math_min(3,UnitPower("player",9))
		else
			hp = math_min(3,UnitPower("player",9))
		end
		if hp > 0 then
			local wp = select(hp,0.3,0.9,2.75)
			calculation.WeaponDamage = wp
		end
		if self:GetSetAmount( "T14 Ret" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.15
		end
	end
	self.Calculation["Avenger's Shield"] = function( calculation, _, _, baseSpell )
		--Glyph of Focused Shield 4.0
		if self:HasGlyph(54930) then
			calculation.dmgM = calculation.dmgM * 1.3
			calculation.aoe = nil
		end
	end
	--Detect Undead, Detect Demon
	local exorcism = string_lower(GetSpellInfo(11389) .. GetSpellInfo(11407))
	local glyph_icon = "|TInterface\\Icons\\INV_Glyph_PrimePaladin:16:16:1:-1|t"
	self.Calculation["Exorcism"] = function( calculation )
		local target = UnitCreatureType("target")
		if target and string_find(exorcism, string_lower(target)) then
			calculation.critPerc = 100
		end
		if (calculation.AP + calculation.AP_mod) > (calculation.SP + calculation.SP_mod) then
			calculation.SPBonus = 0
		else
			calculation.APBonus = 0
		end		
	end
	self.Calculation["Hammer of the Righteous"] = function( calculation, ActiveAuras )
		--TODO: Make sure all holy damage effects are multiplied into the extra portion
		if not calculation.extraDamage then
			calculation.extraDamage = 0
		end
		calculation.dmgM_Extra = calculation.dmgM_Extra * calculation.dmgM_Magic
		calculation.extraWeaponDamage = 0.35 * calculation.dmgM_Extra
		calculation.extraWeaponDamageChance = 1
		calculation.extra_canCrit = true
		calculation.extra_critM = 1 + 2 * self.Damage_critMBonus
		calculation.extra_critPerc = GetCritChance() + calculation.meleeCrit
		calculation.extraWeaponDamageM = true
		calculation.extraWeaponDamageNorm = false
		calculation.extraWeaponDamage_dmgM = calculation.dmgM_global
		calculation.extraName = calculation.extraName and (calculation.extraName .. "HotR AoE") or "HotR AoE" 
	end
	self.Calculation["Consecration"] = function( calculation )
		local spec = calculation.spec
		--Prot does a lot more damage on this than ret or holy - 8 times base.
		if spec == 2 then
			calculation.dmgM = calculation.dmgM * 8
		end
	end
	self.Calculation["Holy Shock"] = function( calculation )
		--Glyph of Holy Shock 5.1
		if self:HasGlyph(63224) then
			if calculation.healingSpell then
				calculation.dmgM = calculation.dmgM * 0.5
			else
				calculation.dmgM = calculation.dmgM * 1.5
			end
		end
		if calculation.healingSpell then
			if self:GetSetAmount( "PvP Healing" ) >= 4 then
				--Additive - 3.3.3
				calculation.dmgM_Add = calculation.dmgM_Add + 0.1
			end
		end
		if self:GetSetAmount ( "T14 Holy" ) >= 4 then
			calculation.cooldown = calculation.cooldown - 2
		end
		--Has native crit chance of 25% greater.  Check for spec is redundant.
		calculation.critPerc = calculation.critPerc + 25
	end
	--self.Calculation["Denounce"] = function( calculation )
	--end
	--self.Calculation["Holy Light"] = function( calculation )
	--end
	self.Calculation["Crusader Strike"] = function( calculation )
		--Sanctity of Battle
		if IsSpellKnown(25956) then
			calculation.cooldown = calculation.cooldown / calculation.haste
		end
	end
	self.Calculation["Divine Storm"] = function( calculation )
		--Sanctity of Battle
		if IsSpellKnown(25956) then
			calculation.cooldown = calculation.cooldown / calculation.haste
		end
	end
	--self.Calculation["Hammer of Wrath"] = function( calculation )
	--end
--SEALS AND JUDGEMENTS
	local soc_icon = "|T" .. select(3,GetSpellInfo(85126)) .. ":16:16:1:-1|t"
	self.Calculation["Seal of Righteousness"] = function( calculation )
		local spd = self:GetWeaponType() and self:GetWeaponSpeed() or 2
		calculation.APBonus = calculation.APBonus * spd
		calculation.SPBonus = calculation.SPBonus * spd
	end
	self.Calculation["Seal of Justice"] = function( calculation )
		local spd = self:GetWeaponType() and self:GetWeaponSpeed() or 2
		calculation.APBonus = calculation.APBonus * spd
		calculation.SPBonus = calculation.SPBonus * spd
	end
	local censure_icon = "|T" .. select(3,GetSpellInfo(31803)) .. ":16:16:1:-1|t"
	self.Calculation["Seal of Truth"] = function( calculation, ActiveAuras )
		local number = ActiveAuras["Censure"] or 1
		--calculation.extraDamage = calculation.extraDamage * number
		--calculation.extraDamageSP = calculation.extraDamageSP * number
		--calculation.extraName = number .. "x" .. censure_icon
		if ActiveAuras["Censure"] then
			calculation.WeaponDamage = (calculation.WeaponDamage or 0) + number * 0.03
			calculation.WeaponDPS = true
		end
	end
	self.Calculation["Judgement of Truth"] = function( calculation, ActiveAuras )
		if ActiveAuras["Censure"] then
			calculation.dmgM = calculation.dmgM * (1 + 0.2 * ActiveAuras["Censure"])
		end
	end
	self.Calculation["Censure"] = function ( calculation )
		local spec = calculation.spec
		if spec ~= 2 then
			--If not Prot, this does 5x damage more.
			calculation.dmgM = calculation.dmgM * 5
		end
	end
--SETS
	self.SetBonuses["PvP Healing Gloves"] = {
		--Savage, Hateful, Deadly, Furious, Relentless, Wrathful, Bloodthirsty, Vicious, Ruthless x 2, Cataclysmic x 2
		40918, 40925, 40926, 40927, 40928, 51459, 64803, 60602, 70354, 70418, 73559, 73700,
	}
	self.SetBonuses["PvP Retribution Gloves"] = {
		--Savage, Hateful, Deadly, Furious, Relentless, Wrathful, Bloodthirsty, Vicious, Ruthless x 2, Cataclysmic x 2
		40798, 40802, 40805, 40808, 40812, 51475, 64844, 60414, 70250, 70488, 73570, 73707,
	}	
	self.SetBonuses["PvP Healing"] = {
		--Cataclysmic Gladiator's
		73556, 73557, 73558, 73559, 73560,
		--Cataclysmic Gladiator's Elite,
		73697, 73698, 73699, 73700, 73701,
	}
	self.SetBonuses["PvP Retribution"] = {
		--Cataclysmic Gladiator's
		73567, 73568, 73569, 73570, 73571,
		--Cataclysmic Gladiator's Elite,
		73704, 73705, 73706, 73707, 73708,		
	}
	--T13
	self.SetBonuses["T13 Holy"] = { 78726, 78673, 78717, 78692, 78746, 76765, 76766, 76767, 76768, 76769, 78821, 78768, 78812, 78787, 78841 }
	self.SetBonuses["T14 Holy"] = { 86684, 86685, 86686, 86687, 86688, 85344, 85345, 85346, 85347, 85348, 87104, 87106, 87107, 87108, 87105 }
	self.SetBonuses["T14 Ret"] = { 86683, 86680, 86681, 86679, 86682, 85339, 85340, 85341, 85342, 85343, 87099, 87102, 87101, 87103, 87100 }
	self.SetBonuses["T14 Prot"] = { 86663, 86660, 86661, 86662, 86659, 85319, 85320, 85321, 85322, 85323, 87109, 87112, 87111, 87113, 87110 }
--AURA
--Player
	--Seal of Justice 4.0
	self.PlayerAura[GetSpellInfo(20154)] = { Update = true }
	self.PlayerAura[GetSpellInfo(31801)] = self.PlayerAura[GetSpellInfo(20154)]
	self.PlayerAura[GetSpellInfo(20165)] = self.PlayerAura[GetSpellInfo(20154)]
	self.PlayerAura[GetSpellInfo(20164)] = self.PlayerAura[GetSpellInfo(20154)]
	--Infusion of Light
	self.PlayerAura[GetSpellInfo(53576)] = { Update = true, Spells = { "Holy Light", "Divine Light", "Holy Radiance" }, Value = -1.5, ModType = cooldown }
	--Divine Favor 4.0
	self.PlayerAura[GetSpellInfo(31842)] = { ActiveAura = "Divine Favor", ID = 31842 }
	--Avenging Wrath 4.0
	self.PlayerAura[GetSpellInfo(31884)] = { School = "Healing", Value = 0.2, NoManual = true }
	--Divine Plea 4.0
	--self.PlayerAura[GetSpellInfo(54428)] = { School = "Healing", Value = -0.5, ID = 54428, NoManual = true }
	--Inquisition 4.0
	self.PlayerAura[GetSpellInfo(84963)] = { School = "Holy", ActiveAura = "Inquisition", Value = 0.3, ID = 84963 }
	--Divine Purpose 4.0.6
	self.PlayerAura[GetSpellInfo(90174)] = { School = "All", ActiveAura = "Divine Purpose", ID = 90174 }
	--Supplication
	self.PlayerAura[GetSpellInfo(94686)] = { Spells = "Flash of Light", ID = 94686, NoManual = true, Value=100, ModType = critPerc }
	--Glyph of Alabaster Shield proc
	self.PlayerAura[GetSpellInfo(121467)] = { Spells = "Shield of the Righteous", ID = 121467, Apps = 3, Value = 0.20, ModType = "dmgM" }
	--Glyph of Word of Glory - doesn't appear to have stacks or apps... so, maybe we need to assume full damage (9% instead of 3, but check)
	self.PlayerAura[GetSpellInfo(115522)] = { ID = 115522, ModType =
		function (calculation)
			if not calculation.healingSpell then
				calculation.dmgM = calculation.dmgM * 1.03
			end
		end
	}
--Target
	--Censure (4.0)
	self.TargetAura[GetSpellInfo(31803)] = { Spells = { "Seal of Truth", ["Judgement of Truth"] = true }, ActiveAura = "Censure", SelfCast = true, Apps = 5, ID = 31803 }

	self.spellInfo = {
		[GetSpellInfo(31935)] = {
			--200% crit, Melee hit
			["Name"] = "Avenger's Shield",
			["ID"] = 31935,
			["Data"] = { 5.8949, 0.2, ["c_scale"] = 0.33 },
			[0] = { School = { "Holy", "Melee" }, SPBonus = 0.3149, APBonus = 0.8175, MeleeHit = true, AoE = 3, Cooldown = 15 },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(24275)] = {
			--200% crit (verify), Melee Hit
			["Name"] = "Hammer of Wrath",
			["ID"] = 24275,
			["Data"] = { 1.61, 0.1, },
			[0] = { School = { "Holy", "Melee" }, SPBonus = 1.61, MeleeHit = true, MeleeCrit = true, Cooldown = 6, HandOfLight = true, SanctityOfBattle = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(879)] = {
			["Name"] = "Exorcism",
			["ID"] = 879,
			["Data"] = { 6.0949, 0.1099 },
			[0] = { School = { "Holy" }, APBonus = 0.677, Cooldown = 15, SanctityOfBattle = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(2812)] = {
			--Spell hit
			["Name"] = "Denounce",
			["ID"] = 2812,
			["Data"] = { 3.0499, 0.1700, 1.22 },
			[0] = { School = "Holy", SPBonus = 1.22 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(20473)] = {
			["Name"] = "Holy Shock",
			["Text1"] = GetSpellInfo(20473),
			["Text2"] = GetSpellInfo(37455),
			["ID"] = 20473,
			["Data"] = {  8.2211, 0.08, 0.833 },
			[0] = { School = { "Holy", "Healing", "Holy Shock Heal" }, Cooldown = 6, },
			[1] = { 0, 0 },
			["Secondary"] = {
					["Name"] = "Holy Shock",
					["Text1"] = GetSpellInfo(20473),
					["Text2"] = GetSpellInfo(48360),
					["ID"] = 20473,
					["Data"] = { 1.25, 0.08, 1.36 },
					[0] = { School = { "Holy", "Holy Shock Damage" }, Cooldown = 6 },
					[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(26573)] = {
			--Spell crit, Spell hit
			--This may also be spellid 82366 (32% ap + 32% sp).  Need to test in game to verify
			["Name"] = "Consecration",
			["ID"] = 26573,
			["Data"] = { 0.8, },
			[0] = { School = "Holy", Melee = true, MeleeCrit = true, APBonus = 0.9, Hits = 10, eDot = true, eDuration = 9, sTicks = 1, Cooldown = 9,  AoE = true, NoDotHaste = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(635)] = {
			["Name"] = "Holy Light",
			["ID"] = 635,
			["Data"] = {  7.7659, 0.108, 0.785, ["ct_min"] = 1500, ["ct_max"] = 3000 },
			[0] = { School = { "Holy", "Healing" }, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(19750)] = {
			["Name"] = "Flash of Light",
			["ID"] = 19750,
			["Data"] = { 11.03999, 0.115, 1.12, },
			[0] = { School = { "Holy", "Healing" }, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(85673)] = {
			["Name"] = "Word of Glory",
			["ID"] = 85673,
			["Data"] = { 4.8499, 0.108, 0.49, },
			[0] = { School = { "Holy", "Healing" }, Cooldown = 1.5 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(82326)] = {
			["Name"] = "Divine Light",
			["ID"] = 82326,
			["Data"] = { 14.727, 0.108, 1.49 },
			[0] = { School = { "Holy", "Healing" }, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(82327)] = {
			["Name"] = "Holy Radiance",
			["ID"] = 82327,
			["Data"] = { 4.96, 0.2, 0.675, },
			[0] = { School = { "Holy", "Healing" } },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(85222)] = {
			["Name"] = "Light of Dawn",
			["ID"] = 85222,
			["Data"] = { 1.506, 0.108, 0.15199 },
			[0] = { School = { "Holy", "Healing" }, AoE = 6 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(35395)] = {
			["Name"] = "Crusader Strike",
			["ID"] = 35395,
			["Data"] = { 0.554 },
			[0] = { Melee = true, WeaponDamage = 1.25, Cooldown = 4.5, HandOfLight = true, SanctityOfBattle = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(53385)] = {
			["Name"] = "Divine Storm",
			["ID"] = 53385,
			[0] = { Melee = true, WeaponDamage = 1, NoNormalization = true, AoE = true, HandOfLight = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(53595)] = {
			["Name"] = "Hammer of the Righteous",
			["ID"] = 53595,
			["Data"] = { 0, },
			[0] = { Melee = true, WeaponDamage = 0.2, Cooldown = 4.5, E_AoE = true, HandOfLight = true, SanctityOfBattle = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(53600)] = {
			["Name"] = "Shield of the Righteous",
			["ID"] = 53600,
			["Data"] = { 0.73199 },
			[0] = { School = "Holy", Melee = true, APBonus = 0.617 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(85256)] = {
			["Name"] = "Templar's Verdict",
			["ID"] = 85256,
			[0] = { Melee = true, WeaponDamage = 0, HandOfLight = true },
			[1] = { 0, 0 },
		},
		--Seals
		--Seal of Insight only heals
		[GetSpellInfo(20154)] = {
			["Name"] = "Seal of Righteousness",
			["ID"] = 20154,
			[0] = { School = { "Holy" , "Seal" }, Melee = true, MeleeCrit = true, WeaponDamage = 0.09, WeaponDPS = true, NoDPM = true, Unavoidable = true, AoE = true },
			[1] = { 0 },
		},
		[GetSpellInfo(20164)] = {
			["Name"] = "Seal of Justice",
			["ID"] = 20164,
			[0] = { School = { "Holy" , "Seal" }, Melee = true, MeleeCrit = true, WeaponDamage = 0.20, WeaponDPS = true, NoDPM = true, Unavoidable = true },
			[1] = { 0 },
		},
		[GetSpellInfo(31801)] = {
			["Name"] = "Seal of Truth",
			["ID"] = 31801,
			["Data"] = { 0.4685 },
			[0] = { School = { "Holy", "Seal" }, Melee = true, MeleeCrit = true, WeaponDamage = 0.12, WeaponDPS = true, SPBonus_extra = 0.094, Hits_extra = 5, E_eDuration = 15, E_Ticks = 3, E_canCrit = true, NoDPM = true, Unavoidable = true, NoNormalization = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(105361)] = {
			["Name"] = "Seal of Command",
			["ID"] = 105361,
			[0] = { School = { "Holy", "Seal" }, Melee = true, MeleeCrit = true, WeaponDamage = 0.10, WeaponDPS = true, NoNormalization = true, NoDPM = true, Unavoidable = true },
			[1] = { 0, 0 },
		},
		--Judgement
		[GetSpellInfo(20271)] = {
			["Name"] = "Judgment",
			["ID"] = 20271,
			["Data"] = { 0.5460, 0, 0.5460 }, 
			[0] = { School = { "Holy" }, APBonus = 0.328, Melee = true, MeleeCrit = true, SanctityOfBattle = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(114163)] = {
			--Replaces Eternal Flame
			--Need to test. Also need to verify that this hot scales with haste.
			["Name"] = "Eternal Flame",
			["ID"] = 114163,
			["Data"] = { 4.8499, 0.108, 0.49, 0.4448, 0, 0 },
			[0] = { School = { "Holy", "Healing" }, SPBonus = 0.0585, Hits = 10, eDot = true, eDuration = 30, sTicks = 3 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(31803)] = {
			["Name"] = "Censure",
			["ID"] = 31803,
			["Data"] = { 0.0939, 0, 0.0939 },
			[0] = { School = { "Holy" }, Hits = 5, eDot = true, eDuration = 5, sTicks = 3 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(114158)] = {
			["Name"] = "Light's Hammer",
			["ID"] = 114158,
			["Text1"] = 122773,
			["Text2"] = 114918,
			["Data"] = { 3.1789, 0.20, 0.321 },
			[0] = { School = { "Holy", "Healing" }, Hits = 7, eDot = true, eDuration = 14, sTicks = 2, L90Talent = true, NoDotHaste = true },
			[1] = { 0, 0 },
			["Secondary"] = {
				["Name"] = "Light's Hammer",
				["ID"] = 114158,
				["Text1"] = 122773,
				["Text2"] = 114918,
				["Data"] = { 3.1789 },
				[0] = { School = { "Holy" }, Hits = 7, eDot = true, eDuration = 14, sTicks = 2, L90Talent = true, NoDotHaste = true },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(114157)] = {
			["Name"] = "Execution Sentence",
			["ID"] = 114157,
			["Text1"] = 114157,
			["Text2"] = 114197,
			["Data"] = { 11.3746, 0, 5.936 },
			[0] = { School = { "Holy" }, Hits = 10, eDot = true, eDuration = 10, sTicks = 1, L90Talent = true, NoDotHaste = true },
			[1] = { 0, 0 },
			["Secondary"] = {
				["Name"] = "Stay of Execution",
				["ID"] = 114197,
				["Text1"] = 114157,
				["Text2"] = 114197,
				["Data"] = { 11.3746, 0, 5.936 },
				[0] = { School = { "Holy", "Healing" }, Hits = 10, eDot = true, eDuration = 10, sTicks = 1, L90Talent = true, NoDotHaste = true },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(114165)] = {
			-- Holy Prism
			-- Ability changes depending on whether enemy or target
			[0] = function ( calculation )
				if not UnitIsEnemy("player","target") then
					return self.spellInfo["Holy Prism (Healing)"][0], self.spellInfo["Holy Prism (Healing)"]
				else
					return self.spellInfo["Holy Prism (Damage)"][0], self.spellInfo["Holy Prism (Damage)"]
				end
			end
		},
		["Holy Prism (Healing)"] = {
			["Name"] = "Holy Prism (Healing)",
			["ID"] = 114871,
			["Text1"] = 114871,
			["Text2"] = 114852,
			["Data"] = { 14.1309, 0.20, 1.4279 },
			[0] = { School = { "Holy", "Healing" }, AoE = 5, L90Talent = true },
			[1] = { 0, 0 },
			["Secondary"] = {
				["ID"] = 114852,
				["Text1"] = 114871,
				["Text2"] = 114852,
				["Data"] = { 9.529, 0.20, 0.962 },
				[0] = { School = { "Holy" }, AoE = 5, L90Talent = true },
				[1] = { 0, 0 },
			},
		},
		["Holy Prism (Damage)"] = {
			["Name"] = "Holy Prism (Damage)",
			["ID"] = 114852,
			["Text1"] = 114852,
			["Text2"] = 114871,
			["Data"] = { 14.1309, 0.20, 1.4279 },
			[0] = { School = { "Holy" }, AoE = 5, L90Talent = true },
			[1] = { 0, 0 },
			["Secondary"] = { 
				["ID"] = 114871,
				["Text1"] = 114871,
				["Text2"] = 114852,
				["Data"] = { 9.529, 0.20, 0.962 },
				[0] = { School = { "Holy", "Healing" }, AoE = 5, L90Talent = true },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(20925)] = {
			--TODO: Check to see if pulses are affected by haste.
			["Name"] = "Sacred Shield",
			["ID"] = 20925,
			["Data"] = { 0.30, 0, 1.17 },
			[0] = { School = { "Holy", "Absorb" }, Cooldown = 6, eDot = true, Hits = 5, eDuration = 30, sTicks = 6 },
			[1] = { 0, 0 },
		},
	}
	self.talentInfo = {
	--HOLY:
	--PROTECTION:
		--Guarded by the Light
		[GetSpellInfo(53592)] = {	[1] = { Effect = 0.05, Spells = "Word of Glory", ModType = "Guarded by the Light" }, },

	--RETRIBUTION:
		--Crusade (additive?)
		[GetSpellInfo(31866)] = { 	[1] = { Effect = 0.1, Spells = { "Crusader Strike", "Hammer of the Righteous", "Templar's Verdict", "Holy Shock" }, },
									[2] = { Effect = 1, Spells = "Holy Light", ModType = "Crusade" }, },
		--Sanctity of Battle
		[GetSpellInfo(25956)] = {	[1] = { Effect = 1, Spells = { "Crusader Strike", "Divine Storm" }, ModType = "Sanctity of Battle" }, },
	}
end
