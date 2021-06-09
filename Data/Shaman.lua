if select(2, UnitClass("player")) ~= "SHAMAN" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local GetSpellCritChance = GetSpellCritChance
local GetSpellBonusDamage = GetSpellBonusDamage
local UnitPowerMax = UnitPowerMax
local UnitAttackSpeed = UnitAttackSpeed
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitDamage = UnitDamage
local UnitIsUnit = UnitIsUnit
local string_find = string.find
local string_match = string.match
local string_gsub = string.gsub
local math_min = math.min
local math_max = math.max
local math_floor = math.floor
local select = select
local tonumber = tonumber
local IsSpellKnown = IsSpellKnown

--TODO-MINOR: Glyph of Healing Wave (20% self-heal)
--Glyph of Flametongue Weapon is handled by API
--Dual Wield hit is handled by API

function DrDamage:PlayerData()
	--Health updates
	self.TargetHealth = { [1] = 0.351 }
	--Mana Spring Totem
	local MST = GetSpellInfo(5675)
	local TF = GetSpellInfo(16173)
	self.ClassSpecials[MST] = function()
		local cost = select(4, GetSpellInfo(MST))
		local duration = 0.2 * 5 * 60 * (1 + select(self.talents[TF] or 3,0.2,0.4,0))
		local value = duration * self:ScaleData(0.736, nil, nil, nil, true) - (tonumber(cost) or 0)
		return value, nil, true
	end
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			--Elemental Fury
			if IsSpellKnown(60188) and not (calculation.healingSpell or calculation.melee) then
				calculation.critM = calculation.critM * 1.5
			end

			if mastery > 0 and mastery ~= masteryLast then
				if calculation.spellName == "Lightning Bolt" or calculation.spellName == "Chain Lightning" or calculation.spellName == "Lava Burst" then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.finalMod_M = calculation.finalMod_M - masteryBonus
					end
					--TODO-MINOR: Improve this?
					local bonus = mastery * 0.01
					calculation.extraDamage = 0.75
					calculation.extraChance = bonus
					calculation.extraCanCrit = true
					calculation.extraName = "Elemental Overload"
					--calculation.finalMod_M = calculation.finalMod_M + bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus * 0.75
				end
			end
		elseif spec == 2 then
			calculation.SP_mod = 0 
			calculation.SP_bonus = nil
			if mastery > 0 and mastery ~= masteryLast then
				if not calculation.healingSpell then
					if (calculation.school == "Fire" or calculation.school == "Frost" or calculation.school == "Nature") then
						local masteryBonus = calculation.masteryBonus
						if masteryBonus then
							calculation.dmgM = calculation.dmgM / masteryBonus
						end
						local bonus = 1 + (mastery * 0.01)
						calculation.dmgM = calculation.dmgM * bonus
						calculation.masteryLast = mastery
						calculation.masteryBonus = bonus
					elseif calculation.spellName == "Attack" and calculation.E_dmgM then
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
			end
		elseif spec == 3 then
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.healingSpell then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					--TODO: Does this work with riptide?
					--1% of bonus at 100% health, 100% of bonus at 1% health
					--Mastery: Deep Healing
					local mult = 1 - UnitHealth(calculation.target) / UnitHealthMax(calculation.target)
					local bonus = 1 + (mult * (mastery * 0.01))
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		end
		if calculation.spi ~= 0 and spec == 1 then
			if calculation.caster and not calculation.healingSpell and IsSpellKnown(30674) then
				--Grants you spell hit rating equal to 33/66/100% of any Spirit gained from items or effects.
				local rating = calculation.spi 
				calculation.hitPerc = calculation.hitPerc + self:GetRating("Hit", rating, true)
			end
		end
		if spec == 3 and IsSpellKnown(112858) then
			if calculation.spellName == "Lightning Bolt" or calculation.spellName == "Flame Shock" or calculation.spellName == "Hex" or calculation.spellName == "Lava Burst" then
				calculation.hitPerc = calculation.hitPerc + 15
			end
		end
	end
	self.Calculation["Stats2"] = function( calculation, ActiveAuras, spell, baseSpell )
		if calculation.AP_mod ~= 0 then
			if calculation.spec == 2 then
				--Mental Quickness --Your spell power is now equal to 55% of your attack power
				calculation.SP_mod = calculation.SP_mod + 0.65 * calculation.AP_mod * calculation.SPM
			end
		end
	end

	--Rockbiter weapon
	local rb = GetSpellInfo(36494)
	--Lightning Shield
	local lightning_shield = GetSpellInfo(324)
	--Earthliving weapon
	local elw = GetSpellInfo(51730)
	local elwicon = "|T" .. select(3,GetSpellInfo(51730)) .. ":16:16:1:-1|t"
	--Windfury weapon
	local wf = GetSpellInfo(8232)
	local wficon = "|T" .. select(3,GetSpellInfo(8232)) .. ":16:16:1:-1|t"
	--Flametongue weapon
	local ft = GetSpellInfo(8024)
	local fticon = "|T" .. select(3,GetSpellInfo(8024)) .. ":16:16:1:-1|t"
	--Frostbrand weapon
	local fb = GetSpellInfo(8033)
	local fbicon = "|T" .. select(3,GetSpellInfo(8033)) .. ":16:16:1:-1|t"
	--Static Shock
	local ssicon = "|T" .. select(3,GetSpellInfo(51525)) .. ":16:16:1:-1|t"
	self.Calculation["SHAMAN"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		--Specialization
		local spec = calculation.spec
		local name = self:GetWeaponBuff()
		if name == "Flametongue" then
			if not calculation.healingSpell and not calculation.melee then
				calculation.dmgM = calculation.dmgM * 1.07
			end
		end
		if spec == 1 then
			--TODO: Check specialization is active
			if IsSpellKnown(86529) then
				calculation.intM = calculation.intM * 1.05
			end
			--Passive: Shamanism
			if IsSpellKnown(62099) then
				if calculation.spellName == "Lightning Bolt" or calculation.spellName == "Chain Lightning" then
					calculation.dmgM = calculation.dmgM * 1.7
					calculation.cooldown = calculation.cooldown - 0.5
					if calculation.spellName == "Chain Lightning" then
						calculation.cooldown = 0
					end
				end
			end
		elseif spec == 2 then
			calculation.APtoSP = true
			--TODO: Check specialization is active
			if IsSpellKnown(86529) then
				calculation.agiM = calculation.agiM * 1.05
			end
		elseif spec == 3 then
			--TODO: Check specialization is active
			if IsSpellKnown(86529) then
				calculation.intM = calculation.intM * 1.05
			end
			if (calculation.healingSpell and not baseSpell.Totem)  and IsSpellKnown(16213)  then
				--Passive: Purification
				if calculation.spellName == "Healing Rain" then
					--5.4 doubled the effectiveness of healing rain with Purification
					calculation.dmgM = calculation.dmgM * 2
				else
					calculation.dmgM = calculation.dmgM * 1.25
				end
			elseif baseSpell.Totem and IsSpellKnown(16213) then
				calculation.dmgM = calculation.dmgM * 1.5
			end
		end
		if calculation.healingSpell then
			if calculation.spellName ~= "Healing Stream Totem" or calculation.spellName ~= "Healing Tide Totem" then
				local name = self:GetWeaponBuff()
				local nameO = self:GetWeaponBuff(true)
				local mh = name and string_find(elw,name)
				local oh = nameO and string_find(elw,nameO)
				if (mh or oh) and UnitIsFriend("player","target") then
					local chance = 0.2 + (UnitHealth("target") ~= 0 and ((UnitHealth("target") / UnitHealthMax("target")) <= 0.35) or 0)
					--chance = math_min(1, chance * (calculation.spellName == "Chain Heal" and calculation.aoe or 1))
					calculation.extra = 4 * self:ScaleData(0.574)
					calculation.extraDamage = 4 * 0.057
					calculation.extraBonus = true
					--Glyph of Earthliving Weapon (4.0)
					calculation.extraDmgM = 0.2 * 1.2
					calculation.extraTicks = 4
					calculation.extraChance = math_min(1, (mh and chance or 0) + (oh and chance or 0))
					calculation.extraName = (mh and elwicon or "") .. (mh and oh and "+" or "") .. (oh and elwicon or "")
					calculation.extraCanCrit = true
				end
			end
			if self:GetSetAmount( "T13 Melee" ) >= 2 and ActiveAuras["Maelstrom Weapon"] then
				calculation.dmgM_Add = calculation.dmgM_Add + 0.20
			end
		else
			if spec == 2 then
				if ActiveAuras["Lightning Shield"] then
				--When you use your Primal Strike, Stormstrike, or Lava Lash abilities while having Lightning Shield active, you have a 45% chance to deal damage equal to a Lightning Shield orb without consuming a charge.
					calculation.extra = self.spellInfo[lightning_shield][1][1]
					calculation.extraDamage = 0
					calculation.extraDamageSP = self.spellInfo[lightning_shield][0].SPBonus
					calculation.extraChance = 0.45
					calculation.extraName = ssicon
					calculation.E_dmgM = select(7,UnitDamage("player")) * calculation.dmgM_Magic / calculation.dmgM_Physical
				end
				if calculation.school ~= "Physical" then
					local ftbuff
					local name = self:GetWeaponBuff()
					if name then
						if string_find(ft, name) then 
							calculation.dmgM = calculation.dmgM * 1.05
							ftbuff = true
						end
					end
					if not ftbuff and calculation.offHand then
						local name = self:GetWeaponBuff(true)
						if name then
							if string_find(ft, name) then 
								calculation.dmgM = calculation.dmgM * 1.05 
							end
						end
					end
				end
			end
		end
	end
--ABILITIES
	self.Calculation["Attack"] = function( calculation, _, spell, baseSpell )
		local spellHit = 0.01 * math_max(0,math_min(100,self:GetSpellHit(calculation.playerLevel, calculation.targetLevel) + calculation.spellHit))
		local dmgM = select(7,UnitDamage("player")) * calculation.dmgM_Magic / calculation.dmgM_Physical
		--local critM = (0.5 + (Talents["Elemental Fury"] or 0)) * (1 + 3 * self.Damage_critMBonus)
		local name, rank = self:GetWeaponBuff()
		local pcm, pco
		if name then
			if string_find(wf, name) then
				local spd = UnitAttackSpeed("player")
				--Glyph of Windfury Weapon (4.0)
				pcm = self:HasGlyph(55445) and (select(math_floor(spd/1.5) + 1, 0.132, 0.153, 0.18) or 0.22) or (select(math_floor(spd/1.5) + 1, 0.125, 0.143, 0.167) or 0.2)
				calculation.WindfuryBonus = self:ScaleData(10, nil, nil, nil, true)
				calculation.extraName = wficon
			elseif string_find(ft, name) then
				local spd = self:GetWeaponSpeed()
				local bonus = spd * 0.01 * self:ScaleData(7.61)
				local coeff = (spd <= 2.6) and (spd / 2.6) * 0.1 or (0.1 + (spd - 2.6)/ 1.4 * 0.05)
				--Modifiers to core:
				if calculation.spec == 2 then
					calculation.extraDamage = 0.8 * coeff
				else
					calculation.extraDamage = 0
					calculation.extraDamageSP = 0.8 * coeff
				end
				calculation.extraName = fticon
				calculation.extra = calculation.extra + bonus
				calculation.extraChance = spellHit
				calculation.E_canCrit = true
				calculation.E_critM = critM
				calculation.E_dmgM = dmgM
				calculation.E_critPerc = GetSpellCritChance(3) + calculation.spellCrit
			elseif string_find(fb, name) then
				local spd = self:GetWeaponSpeed()
				local bonus = self:ScaleData(0.609)
				local level = calculation.playerLevel
				--Modifiers to core:
				calculation.extraDamage = 0
				calculation.extraName = fbicon
				calculation.extra = calculation.extra + bonus
				calculation.extraDamageSP = 0.1
				calculation.extraChance = (spd * 9)/60 * spellHit
				calculation.E_canCrit = true
				calculation.E_critM = critM
				calculation.E_dmgM = dmgM
				--calculation.SP = calculation.SP - GetSpellBonusDamage(2) + GetSpellBonusDamage(5)
				calculation.E_critPerc = GetSpellCritChance(5) + calculation.spellCrit
			end
		end
		if calculation.offHand then
			local name, rank = self:GetWeaponBuff(true)
			if name then
				if string_find(wf, name) then
					local _, ospd = UnitAttackSpeed("player")
					if ospd then
						--Glyph of Windfury Weapon (4.0)
						pco = self:HasGlyph(55445) and (select(math_floor(ospd/1.5) + 1, 0.132, 0.153, 0.18) or 0.22) or (select(math_floor(ospd/1.5) + 1, 0.125, 0.143, 0.167) or 0.2)
						calculation.WindfuryBonus_O = self:ScaleData(10, nil, nil, nil, true)
						calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. wficon) or wficon
					end
				elseif string_find(ft, name) then
					local _, spd = self:GetWeaponSpeed()
					local bonus = spd * 0.01 * self:ScaleData(7.61)
					local coeff = (spd <= 2.6) and (spd / 2.6) * 0.1 or (0.1 + (spd - 2.6)/ 1.4 * 0.05)
					--Modifiers to core:
					calculation.extraDamage = 0
					if calculation.spec == 2 then
						calculation.extraDamage_O = 0.8 * coeff
					else
						calculation.extraDamageSP_O = 0.8 * coeff
					end
					calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. fticon) or fticon
					calculation.extra_O = (calculation.extra_O or 0) + bonus
					calculation.extraChance_O = spellHit
					calculation.E_canCrit = true
					calculation.E_critM = critM
					calculation.E_dmgM = dmgM
					--calculation.SP_O = GetSpellBonusDamage(3)
					calculation.E_critPerc_O = GetSpellCritChance(3) + calculation.spellCrit
				elseif string_find(fb, name) then
					local _, spd = self:GetWeaponSpeed()
					local bonus = self:ScaleData(0.609)
					--Modifiers to core:
					calculation.extraDamage = 0
					calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. fbicon) or fbicon
					calculation.extra_O = (calculation.extra_O or 0) + bonus
					calculation.extraDamageSP_O = 0.1
					calculation.extraChance_O = (spd * 9)/60 * spellHit
					calculation.E_canCrit = true
					calculation.E_critM = critM
					calculation.E_dmgM = dmgM
					--calculation.SP_O = GetSpellBonusDamage(5)
					calculation.E_critPerc_O = GetSpellCritChance(5) + calculation.spellCrit
				end
			end
		end
		--Model windfury cooldown effects
		if pcm and pco then
			local spd, ospd = UnitAttackSpeed("player")
			if spd <= 1.5 and ospd <= 1.5 then
				--From total 1.7s to 2.9s combined (simulation from 0.8 - 1.4, 0.9 - 1.5)
				if self:HasGlyph(55445) then
					--Max error deviation 1.39%, avg 0.346%
					pcm = 10.9 + math_min(1,math_max(0,(spd+ospd-1.7)/1.2)) * 4.1
				else
					--Max error deviation 0.8%, avg: 0.314%
					pcm = 10.7 + math_min(1,math_max(0,(spd+ospd-1.7)/1.2)) * 3.8
				end
			elseif spd <= 1.5 or ospd <= 1.5 then
				--From total 2.4s to 4.2s combined (simulation from 0.8 - 1.5, 1.6 - 2.7)
				if self:HasGlyph(55445) then
					--Max error deviation 1.73%, avg 0.725%
					pcm = 13.8 + math_min(1,math_max(0,(spd+ospd-2.4)/1.8)) * 4
				else
					--Max error deviation 1.7%, avg 0.678%
					pcm = 13.3 + math_min(1,math_max(0,(spd+ospd-2.4)/1.8)) * 3.9
				end
			elseif spd > 1.5 and ospd > 1.5 then
				--From total 3.3s to 5.3s combined (simulation from 1.6 - 2.6, 1.7 - 2.7)
				if self:HasGlyph(55445) then
					--Max error deviation 1.67%, avg 0.198%
					pcm = 18.5 + math_min(1,math_max(0,(spd+ospd-3.3)/2)) * 2.6
				else
					--Max error deviation 1.58%, avg 0.165%
					pcm = 17.8 + math_min(1,math_max(0,(spd+ospd-3.3)/2)) * 2.4
				end
			end
			calculation.WindfuryChance = pcm / 100
		else
			calculation.WindfuryChance = pcm or pco
		end
	end
	self.Calculation["Earth Shield"] = function( calculation, _ )
		if spec == 3 then
			calculation.dmgM = calculation.dmgM * 1.25
		end
	end
	self.Calculation["Lava Burst"] = function( calculation, ActiveAuras )
		--Always guaranteed to be a crit as of 5.2
		calculation.critPerc = 100
		--As of 5.2, this now increases damage of Lava Burst by 50% if the target has flameshock active.
		if ActiveAuras["Flame Shock"] then
			calculation.dmgM = calculation.dmgM * 1.5
		end
	end
	--self.Calculation["Chain Heal"] = function( calculation )
	--end
	self.Calculation["Chain Lightning"] = function( calculation, ActiveAuras )
		--Glyph of Chain Lightning (4.0)
		if self:HasGlyph(55449) then
			calculation.aoe = 5
			calculation.dmgM = calculation.dmgM * 0.9
		end
		-- Rolling Thunder and Lightning shield
		if IsSpellKnown(88764) and ActiveAuras["Lightning Shield"] then
			calculation.manaCost = calculation.manaCost - 0.02 * UnitPowerMax("player",0) 
		end
		if self:GetSetAmount( "T13 Melee" ) >= 2 and ActiveAuras["Maelstrom Weapon"] then
			calculation.dmgM_Add = calculation.dmgM_Add + 0.20
		end		
	end
	--self.Calculation["Flame Shock"] = function( calculation )
	--end
	--self.Calculation["Frost Shock"] = function( calculation )
	--end
	local fulmination_icon = "|T" .. select(3,GetSpellInfo(88766)) .. ":16:16:1:-1|t"
	self.Calculation["Earth Shock"] = function( calculation, ActiveAuras )
		-- Fulmination and Lightning shield
		if IsSpellKnown(88766) and ActiveAuras["Lightning Shield"] then
			local apps = ActiveAuras["Lightning Shield"] - 3
			if apps > 0 then
				--When you have more than 3 Lightning Shield charges active, your Earth Shock spell will consume any surplus charges, instantly dealing their total damage to the enemy target.
				local ls = self.spellInfo[lightning_shield]
				calculation.extra = apps * ls[1][1]
				calculation.extraDamage = apps * ls[0].SPBonus
				calculation.extraDmgM = select(7,UnitDamage("player")) * calculation.dmgM_Magic 
				calculation.extraName = fulmination_icon
				calculation.extraCanCrit = true
			end
		end
	end
	self.Calculation["Lightning Bolt"] = function( calculation, ActiveAuras )
		if self:GetSetAmount( "T14 Caster" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.05
		end
	end
	--self.Calculation["Lightning Shield"] = function( calculation )
	--end
	self.Calculation["Riptide"] = function( calculation )
		--Glyph of Riptide (4.0)
		if self:HasGlyph(63273) then
			calculation.cooldown = 0
			calculation.dmgM = calculation.dmgM * 0.1
			--calculation.eDuration = calculation.eDuration + 6
		end
	end
	local mana_restore = GetSpellInfo(33511)
	self.Calculation["Thunderstorm"] = function( calculation )
		--Glyph of Thunder (4.0)
		if self:HasGlyph(63270) then
			calculation.cooldown = calculation.cooldown - 10
		end
		calculation.customText = mana_restore or "Mana Restore"
		calculation.customTextValue = 0.15 * UnitPowerMax("player",0)
	end
	--self.Calculation["Healing Wave"] = function( calculation )
	--end
	--self.Calculation["Searing Totem"] = function( calculation, _, Talents )
	--end
	self.Calculation["Stormstrike"] = function( calculation )
		if self:GetSetAmount( "T14 Melee" ) >= 4 then
			calculation.critPerc = calculation.critPerc + 15
		end
	end
	self.Calculation["Lava Lash"] = function( calculation, ActiveAuras )
		if ActiveAuras["Searing Flames"] then
			--CHECK
			local bonus = 0
			calculation.dmgM_Add = calculation.dmgM_Add + ActiveAuras["Searing Flames"] * bonus
		end
		if calculation.offHand then
			local name = self:GetWeaponBuff(true)
			if name and string_find(ft, name) then
				calculation.dmgM = calculation.dmgM * 1.4
			end
		end
		if self:GetSetAmount( "T14 Melee" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.15
		end
	end
	self.Calculation["Healing Stream Totem"] = function (calculation)
		local spec = calculation.spec
		-- Resto has 10% greater heals on totems as part of the ability - builtin
		if spec == 3 then
			calculation.dmgM = calculation.dmgM * 1.8761
		end
	end
	self.Calculation["Healing Tide Totem"] = function (calculation)
		local spec = calculation.spec
		if spec == 3 then
			calculation.dmgM = calculation.dmgM * 1.25
		end
		calculation.aoe = 5
	end
	self.Calculation["Greater Healing Wave"] = function (calculation)
		if self:GetSetAmount( "T14 Healer" ) >= 2 then
			calculation.manaCost = calculation.manaCost * 0.9
		end
	end
	self.Calculation["Healing Surge"] = function (calculation)
		if self:GetSetAmount( "T14 Healer" ) >= 4 then
			calculation.critPerc = calculation.critPerc + 30
		end
	end
	self.Calculation["Fire Nova"] = function (calculation)
		local spec = calculation.spec
		if spec == 2 then
			calculation.dmgM = calculation.dmgM * 1.83
		end
	end
--SETS
	self.SetBonuses["T13 Melee"] = { 78724, 78667, 78686, 78704, 78733, 77040, 77041, 77042, 77043, 77044, 78819, 78762, 78781, 78799, 78828 }
	self.SetBonuses["T14 Caster"] = { 86630, 86629, 86631, 86632, 86633, 85293, 85292, 85291, 85290, 85289, 87140, 87139, 87141, 87142, 87143 }
	self.SetBonuses["T14 Melee"] = { 86624, 86625, 86626, 86627, 86628, 85284, 85285, 85286, 85287, 85288, 87134, 87135, 87136, 87137, 87138 }
	self.SetBonuses["T14 Healer"] = { 86689, 86690, 86691, 86692, 86693, 85349, 85350, 85351, 85352, 85353, 87129, 87130, 87131, 87132, 87133 }
--AURA
--Player
	--Maelstrom Weapon (4.0)
	self.PlayerAura[GetSpellInfo(53817)] = { ActiveAuras = "Maelstrom Weapon", ID = 53817 }
	--Lava Flows (4.0) Removed in Mists
	--self.PlayerAura[GetSpellInfo(65264)] = self.PlayerAura[GetSpellInfo(53817)]
	--Elemental Mastery (4.0 - Fire, Frost, Nature)
	self.PlayerAura[GetSpellInfo(16166)] = { School = "Damage Spells", ID = 16166, Mods = { ["haste"] = 1.3 } }
	--Clearcasting (4.0) - Elemental Focus
	self.PlayerAura[GetSpellInfo(16246)] = { ActiveAura = "Clearcasting", ID = 16246, ModType =
		function(calculation)
			if calculation.school ~= "Physical" then
				if calculation.manaCost then
					calculation.manaCost = calculation.manaCost * 0.6
				end
				if calculation.school ~= "Healing" then
					calculation.dmgM = calculation.dmgM * 1.15
				end
			end
		end
	}
	--Lightning Shield (4.0)
	self.PlayerAura[GetSpellInfo(324)] = { ActiveAura = "Lightning Shield", Apps = 3, Spells = { "Chain Lightning", "Lightning Bolt", "Stormstrike", "Lava Lash", "Primal Strike", "Earth Shock" }, ID = 324 }
	--Tidal Waves (4.0)
	self.PlayerAura[GetSpellInfo(51564)] = { ActiveAura = "Tidal Waves", Spells = { "Healing Wave", "Greater Healing Wave", "Healing Surge" }, NoManual = true, ModType =
		function( calculation )
			calculation.critPerc = calculation.critPerc + 30
		end
	}
	--Unleash Flame (4.0)
	self.PlayerAura[GetSpellInfo(73683)] = { Spells = { "Flame Shock", "Lava Burst", "Fire Nova" }, ID = 73683, ModType =
		function( calculation )
			calculation.dmgM = calculation.dmgM * 1.3
		end
	}
	--Unleash Life (4.0)
	--TODO: Does this work with chain heal or riptide dh-part?
	self.PlayerAura[GetSpellInfo(73685)] = { Spells = { "Healing Surge", "Healing Wave", "Greater Healing Wave", "Chain Heal", "Riptide" }, ID = 73685, ModType =
		function( calculation )
			calculation.dmgM = calculation.dmgM * 1.3
		end
	}
	-- Elemental Ascendance
	self.PlayerAura[GetSpellInfo(114050)] = { Spells = "Lava Burst", ModType = 
		function ( calculation )
			if calculation.spellName == "Lava Burst" then
				calculation.cooldown = 0
			end
		end
	}
	--Restoration Ascendance adds 100% healing for 15 seconds.
	self.PlayerAura[GetSpellInfo(114052)] = { School = "Healing", Value = 1, ModType = "dmgM" }
	--Stormblast
	self.PlayerAura[GetSpellInfo(115357)] = { Spells = { "Lightning Bolt", "Chain Lightning", "Lightning Shield", "Earth Shock" }, Value = 25, ModType = "critPerc", ID = 115357 }

--Target
	--Riptide (4.0)
	self.TargetAura[GetSpellInfo(61295)] = { Spells = "Chain Heal", Value = 0.25, ModType = "dmgM", ID = 61295 }
	--Flame Shock (4.0)
	self.TargetAura[GetSpellInfo(8050)] = { ActiveAura = "Flame Shock", Spells = "Lava Burst", ID = 8050 }
	--Frostbrand Attack (4.0)
	self.TargetAura[GetSpellInfo(8034)] = { ActiveAura = "Frostbrand Attack", ID = 8034 }
	--Earth Shield (4.0)
	self.TargetAura[GetSpellInfo(974)] = { School = "Healing", ActiveAura = "Earth Shield", Value = 0.20, SelfCastBuff = true, ID = 974, ModType=
		function (calculation)
			if calculation.spellName ~= "Healing Rain" and (calculation.spellName ~= "Healing Stream Totem" or calculation.spellName ~= "Healing Tide Totem") then
				calculation.dmgM = calculation.dmgM * 1.2
			end
		end
	}
	--Searing Flames (4.0)
	self.TargetAura[GetSpellInfo(77661)] = { ActiveAura = "Searing Flames", Apps = 5, ID = 7766 }
	--Stormstrike (4.0)
	self.TargetAura[GetSpellInfo(17364)] = { Spells = { "Lightning Bolt", "Chain Lightning", "Lightning Shield", "Earth Shock", "Elemental Blast" }, SelfCast = true, ID = 17364, ModType =
		function( calculation )
			calculation.critPerc = calculation.critPerc + 25
		end
	}
	--Unleashed Fury - elemental
	self.TargetAura[GetSpellInfo(118740)] = { ID = 118740, ModType = 
		function (calculation)
			if calculation.spellName == "Lightning Bolt" then
				calculation.dmgM = calculation.dmgM * 1.2
			end
			if calculation.spellName == "Lava Burst" then
				calculation.dmgM = calculation.dmgM * 1.1
			end
		end
	}
	--Unleashed Fury - restoration
	self.TargetAura[GetSpellInfo(118473)] = { ModType = 
		function (calculation) 
			if calculation.healingSpell and not calculation.aoe then
				calculation.dmgM  = calculation.dmgM * 1.5
			end
		end
	}
	--Stormfire (T12 4p bonus)
	--TODO: Add Flametongue weapon
	self.TargetAura[GetSpellInfo(99212)] = { Spells = { "Fire Nova", "Flame Shock", "Lava Burst", "Lava Lash", "Unleash Flame",  }, SelfCast = true, NoManual = true, ID = 99212, Value = 0.07 }
	

	self.spellInfo = {
		[GetSpellInfo(324)] = {
			["Name"] = "Lightning Shield",
			["ID"] = 324,
			["Data"] = { 0, 0, 0.267 },
			[0] = { School = "Nature", Hits = 3, NoDPS = true, NoDoom = true, NoPeriod = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(403)] = {
			["Name"] = "Lightning Bolt",
			["ID"] = 403,
			["Data"] = { 1.14, 0.133, 0.739, ["ct_min"] = 1500, ["ct_max"] = 2500 },
			[0] = { School = "Nature" },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(421)] = {
			["Name"] = "Chain Lightning",
			["ID"] = 421,
			["Data"] = { 0.989, 0.133, 0.518, },
			[0] = { School = "Nature", Cooldown = 3, chainFactor = 0.7, AoE = 3, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8042)] = {
			["Name"] = "Earth Shock",
			["ID"] = 8042,
			["Data"] = { 1.922, 0.10, 0.581, },
			[0] = { School = { "Nature", "Shock" }, Cooldown = 6, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8050)] = {
			["Name"] = "Flame Shock",
			["ID"] = 8050,
			["Data"] = { 0.9739, 0, 0.449, 0.261, 0, 0.2099 },
			[0] = { School = { "Fire", "Shock" }, Cooldown = 6, Hits_dot = 10, eDuration = 10, sTicks = 3, },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		[GetSpellInfo(8056)] = {
			["Name"] = "Frost Shock",
			["ID"] = 8056,
			["Data"] = { 1.121, 0.056, 0.51, },
			[0] = { School = { "Frost", "Shock" }, Cooldown = 6, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(3599)] = {
			["Name"] = "Searing Totem",
			["ID"] = 3599,
			["Data"] = { 0.063, 0, 0.11, },
			[0] = { School = "Fire", NoDotHaste = true, Hits = 24, eDot = true, eDuration = 60, sTicks = 2.5 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(1535)] = {
			["Name"] = "Fire Nova",
			["ID"] = 1535,
			["Data"] = { 0.785, 0.112, 0.164, },
			[0] = { School = "Fire", Cooldown = 4, AoE = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8190)] = {
			["Name"] = "Magma Totem",
			["ID"] = 8190,
			["Data"] = { 0.267, 0, 0.067, },
			[0] = { School = "Fire", NoDotHaste = true, Hits = 10, eDot = true, eDuration = 60, sTicks = 2, AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(51490)] = {
			["Name"] = "Thunderstorm",
			["ID"] = 51490,
			["Data"] = { 1.63, 0.133, 0.571, },
			[0] = { School = "Nature", Cooldown = 45, AoE = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(51505)] = {
			["Name"] = "Lava Burst",
			["ID"] = 51505,
			["Data"] = { 1.33, 0.25, 0.80, },
			[0] = { School = "Fire", Cooldown = 8, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8004)] = {
			["Name"] = "Healing Surge",
			["ID"] = 8004,
			["Data"] = { 11.233, 0.133, 1.135, },
			[0] = { School = { "Nature", "Healing", }, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(331)] = {
			["Name"] = "Healing Wave",
			["ID"] = 331,
			["Data"] = { 7.48699, 0.133, 0.755999, ["ct_min"] = 1500, ["ct_max"] = 3000 },
			[0] = { School = { "Nature", "Healing", }, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(77472)] = {
			["Name"] = "Greater Healing Wave",
			["ID"] = 77472,
			["Data"] = { 13.621, 0.133, 1.377, },
			[0] = { School = { "Nature", "Healing", }, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(1064)] = {
			["Name"] = "Chain Heal",
			["ID"] = 1064,
			["Data"] = { 6.81, 0.133, 0.6876, },
			[0] = { School = { "Nature", "Healing", }, DirectHeal = true, chainFactor = 1, AoE = 3 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(5394)] = {
			["Name"] = "Healing Stream Totem",
			["ID"] = 5394,
			["Data"] = { 0, 0, 0.444},
			[0] = { School = { "Nature", "Healing", }, Hits_dot = 7, eDuration = 15, sTicks = 2, Cooldown = 30, Totem = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(974)] = {
			["Name"] = "Earth Shield",
			["ID"] = 974,
			["Data"] = { 1.8329, 0, 0.13, },
			[0] = { School = { "Nature", "Healing", }, Hits = 9, NoDPS = true, NoDoom = true, NoPeriod = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(61295)] = {
			["Name"] = "Riptide",
			["ID"] = 61295,
			["Data"] = { 3.351, 0, 0.3389, 1.58299, 0, 0.1599 },
			[0] = { School = { "Nature", "Healing", }, DirectHeal = true, Hits_dot = 6, eDuration = 18, sTicks = 3, Cooldown = 6, },
			[1] = { 0, 0, hybridDotDmg = 0, },
		},
		[GetSpellInfo(73920)] = {
			["Name"] = "Healing Rain",
			["ID"] = 73920,
			["Data"] = { 2.3365 * 0.7, 0.173 * 0.7, 0.2364 * 0.7, },
			[0] = { School = { "Nature", "Healing", }, Hits = 5, eDot = true, eDuration = 10, sTicks = 2, Cooldown = 10, AoE = 6, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(17364)] = {
			["Name"] = "Stormstrike",
			["ID"] = 17364,
			--["Data"] = { },
			[0] = { Melee = true, WeaponDamage = 3.8, Cooldown = 8, DualAttack = true, NoNormalization = true, SP = 4 },
			[1] = { 0 },
		},
		[GetSpellInfo(73899)] = {
			--TODO: Is this normalized?
			["Name"] = "Primal Strike",
			["ID"] = 73899,
			["Data"] = { 0.66 },
			[0] = { Melee = true, WeaponDamage = 1, Cooldown = 8, SP = 4, --[[NoNormalization = true--]] },
			[1] = { 0 },
		},
		[GetSpellInfo(60103)] = {
			["Name"] = "Lava Lash",
			["ID"] = 60103,
			--["Data"] = { },
			[0] = { School = "Fire", Melee = true, WeaponDamage = 3, Cooldown = 10, OffhandAttack = true, --[[NoNormalization = true--]] SP = 4 },
			[1] = { 0 },
		},
		[GetSpellInfo(61882)] = {
			["Name"] = "Earthquake",
			["ID"] = 61882,
			["Data"] = { 0.324 },
			[0] = { Melee = true, SPBonus = 0.1099, Hits = 10, eDot = true, eDuration = 10, Ticks = 1, Unavoidable = true, NoArmor = true, AoE = true },
			[1] = { 0 },
		},
		[GetSpellInfo(51886)] = {
			["Name"] = "Cleanse Spirit",
			["ID"] = 51886,
			["Data"] = { 0.818, 0, 0.08299, },
			[0] = { School = { "Nature", "Healing", }, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(73680)] = {
			[0] = function()
				local name = self:GetWeaponBuff()
				if name then
					if string_find(wf,name) then
						return self.spellInfo[wf][0], self.spellInfo[wf]
					elseif string_find(ft,name) then
						return self.spellInfo[ft][0], self.spellInfo[ft]
					elseif string_find(fb,name) then
						return self.spellInfo[fb][0], self.spellInfo[fb]
					elseif string_find(elw,name) then
						return self.spellInfo[elw][0], self.spellInfo[elw]
					end
				end
			end,
			["Secondary"] = {
				[0] = function()
					local name = self:GetWeaponBuff(true)
					if name then
						if string_find(wf,name) then
							return self.spellInfo[wf][0], self.spellInfo[wf]
						elseif string_find(ft,name) then
							return self.spellInfo[ft][0], self.spellInfo[ft]
						elseif string_find(fb,name) then
							return self.spellInfo[fb][0], self.spellInfo[fb]
						elseif string_find(elw,name) then
							return self.spellInfo[elw][0], self.spellInfo[elw]
						end
					end
				end,
			},
		},
		[GetSpellInfo(8232)] = {
			["Name"] = "Unleash Wind",
			["Text1"] = GetSpellInfo(73680),
			["Text2"] = GetSpellInfo(73681),
			["ID"] = 8232,
			[0] = { Melee = true, WeaponDamage = 0.9, Cooldown = 15, SpellCost = 73680 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8024)] = {
			["Name"] = "Unleash Flame",
			["Text1"] = GetSpellInfo(73680),
			["Text2"] = GetSpellInfo(73683),
			["ID"] = 8024,
			["Data"] = { 1.113, 0.17, 0.429 },
			[0] = { School = "Fire", Cooldown = 15, SpellCost = 73680 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8033)] = {
			["Name"] = "Unleash Frost",
			["Text1"] = GetSpellInfo(73680),
			["Text2"] = GetSpellInfo(73682),
			["ID"] = 8033,
			["Data"] = { 0.869, 0.15, 0.386 },
			[0] = { School = "Frost", Cooldown = 15, SpellCost = 73680 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(51730)] = {
			["Name"] = "Unleash Life",
			["Text1"] = GetSpellInfo(73680),
			["Text2"] = GetSpellInfo(73685),
			["ID"] = 51730,
			["Data"] = { 2.899, 0.15, 0.386  },
			[0] = { School = { "Nature", "Healing" }, Cooldown = 15, SpellCost = 73680, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(114074)] = {
			["Name"] = "Lava Beam",
			["ID"] = 114074,
			["Data"] = { 1.088, 0.133, 0.571 },
			[0] = { School = Fire, Cooldown = 0 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(117014)] = {
			["Name"] = "Elemental Blast",
			["ID"] = 117014,
			["Data"] = { 4.2399, 0.15, 2.1119 },
			[0] = { School = Fire, Cooldown = 12 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(108280)] = {
			["Name"] = "Healing Tide Totem",
			["ID"] = 108280,
			["Data"] = { 4.4253, 0, 0.484 },
			[0] = { School = { "Nature", "Healing" }, Cooldown = 180, Totem = true, NoDotHaste = true, Hits = 5, eDot = true, eDuration = 10, sTicks = 2, AoE = 12 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(115356)] = {
			["Name"] = "Stormblast",
			["ID"] = 115356,
			["Data"] = { 0 },
			[0] = { School = { "Nature" }, Melee = true, WeaponDamage = 4.5 },
			[1] = { 0, 0 },
		}
	}
	self.talentInfo = {
	--ELEMENTAL:
		--Elemental Oath (multiplicative?)
		[GetSpellInfo(51466)] = { 	[1] = { Effect = 0.05, Caster = true, Spells = "All", ModType = "Elemental Oath" }, 
									[2] = { Effect = 0.05, Melee = true, Spells = "Earthquake", ModType = "Elemental Oath" }, },
		--Fulmination
		[GetSpellInfo(88766)] = { 	[1] = { Effect = 1, Caster = true, Spells = "Earth Shock", ModType = "Fulmination" }, },

	--ENHANCEMENT:
		--Searing Flames
		[GetSpellInfo(77657)] = { 	[1] = { Effect = { 0.08, 0.16, 0.24, 0.32, 0.40 }, Caster = true, Spells = "Searing Totem", ModType = "Searing Flames" }, },
	--RESTORATION:
		[GetSpellInfo(86959)] = { 	[1] = { Effect = 1, Caster = true, Spells = "Cleanse Spirit", ModType = "Cleansing Waters" }, },
		--Tidal Waves
		[GetSpellInfo(51564)] = {	[1] = { Effect = 10, Caster = true, Spells = "Healing Surge", ModType = "Tidal Waves" }, },
	}
end
