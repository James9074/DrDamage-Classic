if select(2, UnitClass("player")) ~= "DEATHKNIGHT" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetShapeshiftForm = GetShapeshiftForm
local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitIsUnit = UnitIsUnit
local UnitCreatureType = UnitCreatureType
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local string_lower = string.lower
local string_find = string.find
local string_split = string.split
local math_floor = math.floor
local tonumber = tonumber
local select = select
local math_max = math.max
local math_min = math.min
local IsSpellKnown = IsSpellKnown

--Spell hit abilities: Icy Touch, Blood Boil, Death Coil, Death and Decay, Howling Blast. (Unholy Blight, Corpse Explosion?)

function DrDamage:PlayerData()
	--Health updates
	self.TargetHealth = { [1] = 0.351 }
	--Class specials
	--Death Pact 4.0
	self.ClassSpecials[GetSpellInfo(48743)] = function()
		return 0.25 * UnitHealthMax("player"), true
	end
--TALENTS
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.school == "Frost" then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					local bonus = (1 + mastery * 0.01)
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		elseif spec == 3 then
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.school == "Shadow" and not calculation.healingSpell then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					--Mastery: Dreadblade
					local bonus = 1 + (mastery * 0.01) 
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				--Custom Dreadblade implementation for Scourge Strike
				elseif calculation.shadowBonus then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					else
						calculation.dmgM = calculation.dmgM / (1 + calculation.shadowBonus)
					end
					--Mastery: Dreadblade
					local bonus = calculation.shadowBonus * (1 + mastery * 0.01)
					calculation.dmgM = calculation.dmgM * (1 + bonus)
					calculation.masteryLast = mastery
					calculation.masteryBonus = (1 + bonus)
				end
			end
		end
	end
	local undead = string_lower(GetSpellInfo(5502))
	local ri = "|T" .. select(3,GetSpellInfo(53343)) .. ":16:16:1:-1|t"
	local lb = "|T" .. select(3,GetSpellInfo(53331)) .. ":16:16:1:-1|t"
	local diseaseCount = 0
	self.Calculation["DEATHKNIGHT"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		--Module variables
		local spec = calculation.spec
		if IsSpellKnown(86524) and spec ~= 1 then
			calculation.strM = calculation.strM * 1.05
		end
		
		diseaseCount = 0
		if ActiveAuras["Frost Fever"] then diseaseCount = 1 end
		if ActiveAuras["Blood Plague"] then diseaseCount = diseaseCount + 1 end
		if ActiveAuras["Ebon Plague"] then diseaseCount = diseaseCount + 1 end
		--Specialization
		--if spec == 2 then
			--TODO: Check specialization is active
			--if calculation.mastery > 0 then
			--	Talents["Frozen Heart"] = calculation.mastery * 0.01 * 2
			--end
		if spec == 3 then
			--TODO: Check specialization is active
			--Passive: Unholy Might
			calculation.strM = calculation.strM * 1.25
		end
		if baseSpell.Melee then
			if baseSpell.SpellCrit then
				calculation.critM = calculation.critM + 0.5
			end
		else
			calculation.SPBonus = 0
			calculation.SPBonus_dot = 0
			calculation.critM = calculation.critM + 0.5
			if calculation.instant and GetShapeshiftForm() == 3 then
				calculation.castTime = 1
			end
		end
		if not calculation.healingSpell then
			if calculation.WeaponDamage and calculation.group ~= "Disease" then
				local lichbane, lichbane_O, razorice, razorice_O
				local mh = GetInventoryItemLink("player",16)
				if mh then
					local _, _, rune = string_split(":",mh)
					lichbane = (rune == "3366")
					razorice = (rune == "3370")
				end
				if (baseSpell.AutoAttack or calculation.DualAttack) and calculation.offHand then
					local _, _, rune = string_split(":",GetInventoryItemLink("player",17))
					lichbane_O = (rune == "3366")
					razorice_O = (rune == "3370")
				end
				--Rune of Razorice (3370) 2% extra weapon damage as Frost damage
				if razorice or razorice_O then
					local min, max = self:GetMainhandBase()
					--Cinderglacier applies. Seems like Frost Vulnerability doesn't.
					local bonus = math_max(1, 0.02 * (1/2) * (min+max) * calculation.dmgM_Magic * (ActiveAuras["Cinderglacier"] or 1)) --* (ActiveAuras["Frost Vulnerability"] or 1)
					calculation.extraDamage = 0
					if razorice then
						calculation.extraDamBonus = bonus
						calculation.extraName = ri
					end
					if razorice_O then
						calculation.extraDamBonus_O = bonus
						calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. ri) or ri
					end
				end
				--Rune of Lichbane (3366) 2% extra weapon damage as Fire damage or 4% versus Undead targets.
				if lichbane or lichbane_O then
					local min, max = self:GetMainhandBase()
					local target = UnitCreatureType("target")
					local bonus = math_max(1, 0.02 * (1/2) * (min+max) * calculation.dmgM_Magic)
					if target and string_find(undead,string_lower(target)) then
						bonus = 2 * bonus
					end
					calculation.extraDamage = 0
					if lichbane then
						calculation.extraDamBonus = bonus
						calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. lb) or lb
					end
					if lichbane_O then
						calculation.extraDamBonus_O = bonus
						calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. lb) or lb
					end
				end
			end
		end
		--Might of the Frozen Wastes
		if IsSpellKnown(81333) and baseSpell.AutoAttack then
			calculation.dmgM = calculation.dmgM * 1.3
		end
		if IsSpellKnown(66192) and baseSpell.ThreatOfThassarian then
			if calculation.spellName == "Frost Strike" then
				calculation.DualAttack = 0.5
			else
				calculation.DualAttack = 0.4
			end
			calculation.OffhandChance = value
		end
	end
--ABILITIES
	local bcb = "|T" .. select(3,GetSpellInfo(49219)) .. ":16:16:1:-1|t"
	--self.Calculation["Attack"] = function( calculation, ActiveAuras, Talents )
		--[[if Talents["Blood-Caked Blade"] then
			local mh = not calculation.unarmed
			local oh = calculation.offHand
			if mh or oh then
				calculation.extraDamage = 0
				calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. bcb) or bcb
				calculation.extraWeaponDamageChance = Talents["Blood-Caked Blade"]
				calculation.extraWeaponDamageM = true
			end
			if mh then
				calculation.extraWeaponDamage = 0.25 + diseaseCount * 0.125
			end
			if oh then
				calculation.extraWeaponDamage_O = 0.25 + diseaseCount * 0.125
			end
		end--]]
	--end
	--self.Calculation["Blood Strike"] = function( calculation, ActiveAuras )
	--end
	self.Calculation["Heart Strike"] = function( calculation )
		--Multiplicative - 3.3.3
		calculation.dmgM = calculation.dmgM * (1 + diseaseCount * 0.15 )
	end
	self.Calculation["Obliterate"] = function( calculation )
		--Might of the Frozen Wastes
		if IsSpellKnown(81333) then
			calculation.dmgM = calculation.dmgM * 1.5
		end
		if diseaseCount > 0 then
			--Additive - 3.3.3
			calculation.dmgM_Add = calculation.dmgM_Add + diseaseCount * 0.125 
		end
		--Glyph of Enduring Infection
		if self:HasGlyph(58671) then
			calculation.dmgM = calculation.dmgM * 0.7
		end
		if self:GetSetAmount( "T14 - Damage" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.04
		end
	end
	local ff = GetSpellInfo(59921)
	self.Calculation["Icy Touch"] = function( calculation, _, Talents )
		calculation.extra = 0.32 * calculation.playerLevel * 1.15
		calculation.extraName = ff
	end
	self.Calculation["Chains of Ice"] = function( calculation, _, Talents )
		calculation.extra = 0.32 * calculation.playerLevel * 1.15
		calculation.extraName = ff
		--Glyph of Chains of Ice 4.0
		if self:HasGlyph(58620) then
			calculation.minDam = 144
			calculation.maxDam = 156
			calculation.APBonus = 0.08
		end
	end
	self.Calculation["Howling Blast"] = function( calculation, _, Talents, spell )
		calculation.aoeM = 0.5
	end
	local bp = GetSpellInfo(59879)
	self.Calculation["Plague Strike"] = function( calculation, ActiveAuras, Talents )
		calculation.extra = 0.394 * calculation.playerLevel * 1.15
		calculation.extraName = bp
		calculation.dmgM_Extra = calculation.dmgM_Extra * calculation.dmgM_Magic
	end
	self.Calculation["Scourge Strike"] = function( calculation, ActiveAuras, Talents )
		if diseaseCount > 0 then
			--Multiplicative - 3.3.3
			local shadow = calculation.dmgM_Magic * (ActiveAuras["Cinderglacier"] or 1)
			calculation.shadowBonus = diseaseCount * 0.18 * shadow 
			--Glyph of Scourge Strike 4.0
			calculation.dmgM = calculation.dmgM * (1 + calculation.shadowBonus)
			--Is this a better way of displaying it?
			--calculation.extraDamage = 0
			--calculation.extraAvg = diseaseCount * 0.12 * ((self:GetSetAmount( "T8 - Damage" ) >= 4) and 1.2 or 1)
			--calculation.dmgM_Extra = calculation.dmgM_Extra * shadow
		end
		if self:GetSetAmount( "T14 - Damage" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.04
		end		
	end
	self.Calculation["Blood Boil"] = function( calculation, ActiveAuras )
		if ActiveAuras["Blood Plague"] or ActiveAuras["Frost Fever"] then
			local bonus = self:ScaleData(0.159) --TODO: Verify
			calculation.minDam = calculation.minDam + bonus
			calculation.maxDam = calculation.maxDam + bonus
			calculation.APBonus = calculation.APBonus + 0.0476 --TODO: Verify
		end
		--Crimson Scourge
		if IsSpellKnown(81136) then
			calculation.dmgM = calculation.dmgM * 1.1
		end 
	end
	self.Calculation["Frost Strike"] = function( calculation, _, Talents )
		if self:GetSetAmount( "T14 - Damage" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.04
		end
	end
	local ub = "|T" .. select(3,GetSpellInfo(49194)) .. ":16:16:1:-1|t"
	--self.Calculation["Death Coil"] = function( calculation, _, Talents )
	--end
	--self.Calculation["Death and Decay"] = function( calculation )
	--end
	self.Calculation["Death Strike"] = function( calculation )
		--Blood Rites
		if IsSpellKnown(50034) then
			calculation.dmgM = calculation.dmgM * 1.4
		end
	end
	--self.Calculation["Rune Strike"] = function( calculation )
	--end
	self.Calculation["Rune Tap"] = function( calculation, _, Talents )
		calculation.minDam = UnitHealthMax("player")
		calculation.maxDam = calculation.minDam
		calculation.dmgM = 0.1 
	end
	self.Calculation["Soul Reaper"] = function ( calculation )
		if self:GetSetAmount( "T15 - Damage" ) >= 4 then
			local soulreaper_activation = 0.45
		else	
			local soulreaper_activation = 0.35
		end
		if UnitHealth("target") ~= 0 and (UnitHealth("target") / UnitHealthMax("target")) < soulreaper_activation then
			calculation.extra = self:ScaleData(40)
			calculation.extraSchool = Shadow
			calculation.extraDamage = 1
			calculation.E_eDuration = 5
			calculation.extraTicks = 1
			calculation.extraName = calculation.extraName and (calculation.extraName .. "+ Soul Reaper") or "Soul Reaper"
		end
	end
--[[
	self.Calculation["Summon Gargoyle"] = function( calculation )
		--Assume one second is wasted
		calculation.hits = math_floor((30 - 1) / (2 / calculation.haste))
		calculation.APBonus = calculation.APBonus * calculation.hits
		calculation.haste = 1
		calculation.canCrit = true
		calculation.critM = 0.5
		calculation.critPerc = 5
		calculation.critM_custom = true
	end
--]]
	self.Calculation["Death Siphon"] = function ( calculation )
		--5.4 increased this by 10%
		calculation.dmgM = calculation.dmgM * 1.1
	end
--SETS
	self.SetBonuses["T14 - Damage"] = { 86654, 86655, 86656, 86657, 86658, 85314, 85315, 85316, 85317, 85318, 86918, 86919, 86920, 86921, 86922 }
	self.SetBonuses["T15 - Damage"] = { 95825, 95826, 95827, 95828, 95829, 96569, 96570, 96571, 96572, 96573, 95225, 95226, 95227, 95228, 95229 }
--AURA
--Player
	--Killing Machine 
	self.PlayerAura[GetSpellInfo(51124)] = { Spells = { "Obliterate", "Frost Strike" }, Value = 100, ModType = "critPerc", ID = 51124 }
	--Cinderglacier 
	self.PlayerAura[GetSpellInfo(53386)] = { ID = 53386, ModType =
		function( calculation, ActiveAuras )
			if calculation.school == "Frost" or calculation.school == "Shadow" then
				calculation.dmgM = calculation.dmgM * 1.2
			end
		end
	}
	--Vampiric Blood 
	self.PlayerAura[GetSpellInfo(55233)] = { School = "Healing", NoManual = true, ModType = "dmgM" }
	--Pillar of Frost 
	self.PlayerAura[GetSpellInfo(51271)] = { ID = 51271, NoManual = true, ModType =
		function ( calculation )
			if self:GetSetAmount( "T14 - Damage" ) >= 4 then
				calculation.strM = calculation.strM * 1.07
			else
				calculation.strM = calculation.strM * 1.02
			end
		end
	 }
	--Unholy Strength 
	self.PlayerAura[GetSpellInfo(53365)] = { ID = 53365, ModType = "strM", Multiply = true, Value = 0.15, NoManual = true }
--Target
	--Frost Fever 
	self.TargetAura[GetSpellInfo(55095)] = { ActiveAura = "Frost Fever", SelfCast = true, ID = 55095 }
	--Blood Plague 
	self.TargetAura[GetSpellInfo(55078)] = { ActiveAura = "Blood Plague", SelfCast = true, ID = 55078 }
	--Frost Vulnerability (Rune of Razorice)
	self.TargetAura[GetSpellInfo(51714)] = { Apps = 5, SelfCast = true, ID = 51714, ModType =
		function( calculation, ActiveAuras, _, _, apps )
			if calculation.school == "Frost" then
				calculation.dmgM = calculation.dmgM * (1 + 0.03 * apps)
			elseif calculation.spellName == "Attack" then
				ActiveAuras["Frost Vulnerability"] = 1 + 0.03 * apps
			end
		end
	}
	--Ebon Plaguebringer
	self.TargetAura[GetSpellInfo(51160)] = { ID = 51160, ModType =
		function( calculation )
			if calculation.group == "Disease" then
				calculation.dmgM = calculation.dmgM * 1.6
			end
		end
	}
	self.spellInfo = {
		--BLOOD
		[GetSpellInfo(45902)] = {
				["Name"] = "Blood Strike",
				["ID"] = 45902,
				["Data"] = { 0.7559 },
				[0] = { Melee = true, WeaponDamage = 0.4 },
				[1] = { 0 },
		},
		[GetSpellInfo(55050)] = {
				["Name"] = "Heart Strike",
				["ID"] = 55050,
				["Data"] = { 0.437 },
				[0] = { Melee = true, WeaponDamage = 1.05, ChainFactor = 0.75, AoE = 3 },
				[1] = { 0 },
		},
		[GetSpellInfo(48721)] = {
				["Name"] = "Blood Boil",
				["ID"] = 48721,
				["Data"] = { 3.0959, 0.20 },
				[0] = { School = "Shadow", APBonus = 0.11, AoE = true },
				[1] = { 0, 0 },
		},
		[GetSpellInfo(48982)] = {
				["Name"] = "Rune Tap",
				["ID"] = 48982,
				[0] = { School = { "Shadow", "Healing" }, Cooldown = 30 },
				[1] = { 0, 0 }
		},
		--TODO: Figure out how tooltip works in conjunction with Imp. Death Strike
		[GetSpellInfo(49998)] = {
				["Name"] = "Death Strike",
				["ID"] = 49998,
				["Data"] = { 0.4 },
				[0] = { Melee = true, WeaponDamage = 1.85, ThreatOfThassarian = true },
				[1] = { 0 },
		},
		--FROST
		[GetSpellInfo(49020)] = {
				["Name"] = "Obliterate",
				["ID"] = 49020,
				[0] = { Melee = true, WeaponDamage = 2.5, ThreatOfThassarian = true },
				[1] = { 0 },
		},
		[GetSpellInfo(49143)] = {
				["Name"] = "Frost Strike",
				["ID"] = 49143,
				[0] = { School = "Frost", Melee = true, WeaponDamage = 1.15, ThreatOfThassarian = true },
				[1] = { 0 },
		},
		[GetSpellInfo(56815)] = {
				["Name"] = "Rune Strike",
				["ID"] = 56815,
				[0] = { Melee = true, WeaponDamage = 2, Unavoidable = true },
				[1] = { 0 },
		},
		[GetSpellInfo(45477)] = {
				["Name"] = "Icy Touch",
				["ID"] = 45477,
				["Data"] = { 0.4679, 0.083 },
				[0] = { School = { "Frost", "Disease", "Spell" }, Melee = true, APBonus_extra = 0.319, Hits_extra = 10, E_eDuration = 30, E_canCrit = true, E_Ticks = 3, },
				[1] = { 0, 0, },
		},
		[GetSpellInfo(45524)] = {
				["Name"] = "Chains of Ice",
				["ID"] = 45524,
				--["Data"] = { 0, 0 },
				[0] = { School = { "Frost", "Disease", "Spell" }, Melee = true, Hits_extra = 4, E_eDuration = 8, E_Ticks = 2, E_canCrit = true, },
				[1] = { 0, 0 },
		},
		[GetSpellInfo(49184)] = {
				["Name"] = "Howling Blast",
				["ID"] = 49184,
				["Data"] = { 0.4646 * 1.15 },
				--NOTE: Marked as Disease and E_eDuration for Glyph
				[0] = { School = { "Frost", "Disease", "Spell" }, Melee = true, APBonus = 0.856 * 1.15, AoE = true, },
				[1] = { 0, 0 },
		},
		[GetSpellInfo(85948)] = {
				["Name"] = "Festering Strike",
				["ID"] = 85948,
				["Data"] = { 0.4329 --[[* 1.5--]] },
				[0] = { Melee = true, WeaponDamage = 2 },
				[1] = { 0 },
		},
		--UNHOLY
		[GetSpellInfo(45462)] = {
				["Name"] = "Plague Strike",
				["ID"] = 45462,
				["Data"] = { 0.374 },
				[0] = { School = { "Physical", "Disease" }, Melee = true, WeaponDamage = 1, APBonus_extra = 0.158, Hits_extra = 10, E_eDuration = 30, E_Ticks = 3, E_canCrit = true, ThreatOfThassarian = true },
				[1] = { 0 },
		},
		[GetSpellInfo(55090)] = {
				["Name"] = "Scourge Strike",
				["ID"] = 55090,
				["Data"] = { 0.479 },
				[0] = { Melee = true, WeaponDamage = 1.35 },
				[1] = { 0 },
		},
		[GetSpellInfo(47541)] = {
				["Name"] = "Death Coil",
				["Text"] = GetSpellInfo(47541),
				["ID"] = 47541,
				["Data"] = { 0.9089 },
				[0] = { School = "Shadow", APBonus = 0.514 },
				[1] = { 0, 0 },
			["Secondary"] = {
				["Name"] = "Death Coil",
				["Text"] = GetSpellInfo(47541),
				["ID"] = 47541,
				["Data"] = { 3.182 },
				[0] = { School = { "Shadow", "Healing" }, APBonus = 1.799 },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(43265)] = {
				["Name"] = "Death and Decay",
				["ID"] = 43265,
				["Data"] = { 0.041 },
				[0] = { School = "Shadow", APBonus = 0.064, eDot = true, eDuration = 10, Hits = 11, Cooldown = 30, AoE = true, NoPeriod = true },
				[1] = { 0, 0, },
		},
		[GetSpellInfo(73975)] = {
				["Name"] = "Necrotic Strike",
				["ID"] = 73975,
				[0] = { Melee = true, WeaponDamage = 1 },
				[1] = { 0 },
		},
		[GetSpellInfo(108196)] = {
				["Name"] = "Death Siphon",
				["ID"] = 108196,
				["Data"] = { 6, 0.15 },
				[0] = { Melee = true, School= "Shadowfrost", APBonus = 0.34 },
				[1] = { 0, 0 },
		},
		[GetSpellInfo(130736)] = {
				["Name"] = "Soul Reaper",
				["ID"] = 130736,
				["Data"] = { 0 },
				[0] = { Melee = true, WeaponDamage = 1 },
				[1] = { 0, 0 },
		},
		--2 other versions of Soul Reaper do the same thing.
		[GetSpellInfo(130735)] = GetSpellInfo(130736),
		[GetSpellInfo(114866)] = GetSpellInfo(130736),		

		--[GetSpellInfo(49206)] = {
		--		["Name"] = "Summon Gargoyle",
		--		[0] = { School = "Nature", eDot = true, eDuration = 30, SPBonus = 0, APBonus = 0.35, BaseIncrease = true, MeleeHit = true, MeleeHaste = true, CustomHaste = true, NoNext = true, NoPeriod = true },
		--		[1] = { 51, 69, 57, 77, spellLevel = 60 }
		--},
	}
	self.talentInfo = {
	--BLOOD
	--FROST
	--UNHOLY
	}
end
