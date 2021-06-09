if select(2, UnitClass("player")) ~= "DRUID" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local GetCombatRatingBonus = GetCombatRatingBonus
local GetCritChance = GetCritChance
local GetShapeshiftForm = GetShapeshiftForm
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitBuff = UnitBuff
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local math_floor = math.floor
local math_abs = math.abs
local math_min = math.min
local math_max = math.max
local select = select
local tonumber = tonumber
local IsSpellKnown = IsSpellKnown

function DrDamage:PlayerData()
	--Health updates
	self.TargetHealth = { [1] = 0.5, [0.5] = GetSpellInfo(774), [2] = 0.8, [0.8] = GetSpellInfo(6785) }
	--Events
	local lastEnergy = 0
	local ferocious_bite = GetSpellInfo(22568)
	self.Calculation["UNIT_POWER"] = function()
		local energy = UnitPower("player",3)
		if (energy < 65) and (lastEnergy > 65 or math_abs(energy - lastEnergy) >= 20) or (energy >= 65 and lastEnergy < 65) then
			lastEnergy = energy
			self:UpdateAB(ferocious_bite)
		end
	end
	--Innervate
	self.ClassSpecials[GetSpellInfo(29166)] = function()
		return (0.2 + select(self.talents[dreamstate_talent] or 3,0.15,0.3,0)) * UnitPowerMax("player",0), nil, true
	end
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			if mastery > 0 and mastery ~= masteryLast then
				if ActiveAuras["Eclipse"] then
					--NOTE: Eclipse added in aura module if no mastery present
					local eclipse = 1.15
					--Mastery: Total Eclipse
					local bonus = mastery * 0.01 
					calculation.dmgM = calculation.dmgM * (eclipse + bonus)
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		elseif spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
				if (ActiveAuras["Cat Form"] and (calculation.spellName == "Rake" or calculation.spellName == "Rip" or calculation.spellName == "Thrash (Cat)" or calculation.spellName == "Pounce" or calculation.spellName == "Thrash (Bear)")) then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.bleedBonus = calculation.bleedBonus / masteryBonus
					end
					local bonus = 1 + (mastery * 0.01)
					calculation.bleedBonus = calculation.bleedBonus * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		elseif spec == 4 then
			--Currently on 5.2 PTR
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.healingSpell then
					mastery, mycoefficient = GetMasteryEffect()
					local masteryBonus = mastery
					--Mastery: Harmony
					local bonus = 1 + (mastery * 0.01) 
					if calculation.spellName == "Healing Touch" or calculation.spellName == "Nourish" or calculation.spellName == "Swiftmend" then
						if masteryBonus then
							calculation.dmgM_dd = calculation.dmgM_dd / masteryBonus
						end
						calculation.dmgM_dd = calculation.dmgM_dd * bonus
						calculation.masteryBonus = bonus
						-- Harmony direct heal component
						if IsSpellKnown(77495) then
							calculation.dmgM_dd = calculation.dmgM_dd * 1.1
						end
					elseif calculation.spellName == "Regrowth" then
						if masteryBonus then
							calculation.dmgM_dd = calculation.dmgM_dd / masteryBonus
						end
						if calculation.masteryBonus2 then
							calculation.dmgM_dot = calculation.dmgM_dot / calculation.masteryBonus2
						end
						calculation.dmgM_dd = calculation.dmgM_dd * bonus
						calculation.masteryBonus = bonus
						if ActiveAuras["Harmony"] then
							calculation.dmgM_dot = calculation.dmgM_dot * bonus
							calculation.masteryBonus2 = bonus
						end
						-- Harmony direct heal component
						if IsSpellKnown(77495) then
							calculation.dmgM_dd = calculation.dmgM_dd * 1.1
						end
					--elseif ActiveAuras["Harmony"] then
					--	if masteryBonus then
					--		calculation.dmgM_dot = calculation.dmgM_dot / masteryBonus
					--	end
					--	calculation.dmgM_dot = calculation.dmgM_dot * bonus
					--	calculation.masteryBonus = bonus						
					end
					calculation.masteryLast = mastery
				end
			end
		end
		if calculation.spi ~= 0 then
			if IsSpellKnown(33596) then
				--Increases your spell hit rating by an additional amount equal to 50/100% of your Spirit.
				local rating = calculation.spi 
				calculation.hitPerc = calculation.hitPerc + self:GetRating("Hit", rating, true)
			end
		end
		if calculation.agi ~= 0 then
			--Nurturing Instinct
			if IsSpellKnown(33883) then	
				calculation.SP_mod = calculation.SP_mod + calculation.agi
			end
		end
	end
	local moonfury = { ["Wrath"] = true, ["Moonfire"] = true, ["Starfire"] = true, ["Starsurge"] = true, ["Insect Swarm"] = true, ["Starfall"] = true }
	self.Calculation["DRUID"] = function( calculation, ActiveAuras, spell, baseSpell )
		--Stat mods
		--[[if Talents["Heart of the Wild"] and ActiveAuras["Cat Form"] then
			--While in Cat Form your attack power is increased by 3/7/10%.
			calculation.APM = calculation.APM * (1 + Talents["Heart of the Wild"])
		end --]]
		--Specialization
		local spec = calculation.spec
		if spec == 1 then
			--TODO: Check specialization is active
			if IsSpellKnown(86530) then
				calculation.intM = calculation.intM * 1.05
			end
			if not calculation.healingSpell then
				if (calculation.school == "Nature" or calculation.school == "Arcane" or calculation.school == "Spellstorm") then
					--Passive: Moonfury
					calculation.dmgM = calculation.dmgM * 1.1
				end
				if moonfury[calculation.spellName] then
					calculation.critM = calculation.critM + 0.5
				end
			end
		elseif spec == 2 then
			--TODO: Check specialization is active
			if ActiveAuras["Cat Form"] and IsSpellKnown(86530) then
				calculation.agiM = calculation.agiM * 1.05
			end
			calculation.APM = calculation.APM * 1.25
		elseif spec == 4 then
			--TODO: Check specialization is active
			if IsSpellKnown(86530) then
				calculation.intM = calculation.intM * 1.05
			end
			--Naturalist on 5.2
			if IsSpellKnown(17073) and calculation.healingSpell then
				calculation.dmgM = calculation.dmgM * 1.1
			end
		end
		if calculation.healingSpell then
			--Glyph of Frenzied Regeneration 4.0 (multiplicative - 3.3.3)
			if ActiveAuras["Frenzied Regeneration"] and self:HasGlyph(54810) then
				calculation.dmgM = calculation.dmgM * 1.4
			end
			--if ActiveAuras["Tree of Life"] then
			--	calculation.dmgM = calculation.dmgM * 1.15
			--end
		else
			if ActiveAuras["Moonkin Form"] and (calculation.school == "Arcane" or calculation.school == "Nature" or calculation.school == "Spellstorm") then
				calculation.dmgM = calculation.dmgM * 1.1
			end
		end
	end
--ABILITIES
	--local tol = GetSpellInfo(48371)
	self.Calculation["Lifebloom"] = function( calculation, ActiveAuras )
		--Glyph of Lifebloom - 4.0
		if self:HasGlyph(54826) then
			calculation.critPerc = calculation.critPerc + 10
		end
	end
	self.Calculation["Nourish"] = function( calculation, ActiveAuras )
		--Nourish bonus if Rejuvenation, Regrowth, Lifebloom, Wild Growth or Tranquility are active on the target
		local hotCount = 0
		if ActiveAuras["Rejuvenation"] then hotCount = hotCount + 1 end
		if ActiveAuras["Regrowth"] then hotCount = hotCount + 1 end
		if ActiveAuras["Lifebloom"] then hotCount = hotCount + 1 end
		if ActiveAuras["Wild Growth"] then hotCount = hotCount + 1 end
		if ActiveAuras["Tranquility"] then hotCount = hotCount + 1 end
		if hotCount > 0 then
			local bonus = 0
			--Multiplicative - 3.3.3
			calculation.dmgM = calculation.dmgM * (1.2 + bonus)
		end
	end
	self.Calculation["Swiftmend"] = function( calculation, ActiveAuras )
		if self:GetSetAmount("T14 Resto") >= 4 then
			calculation.cooldown = calculation.cooldown - 3
		end
	end 
	self.Calculation["Rejuvenation"] = function( calculation, ActiveAuras, spell )
		if self:GetSetAmount("T14 Resto") >= 2 then
			calculation.manaCost = calculation.manaCost * 0.9
		end
	end
	self.Calculation["Wild Growth"] = function( calculation, ActiveAuras )
		--Glyph of Wild Growth - 4.0
		if self:HasGlyph(62970) then
			calculation.aoe = calculation.aoe + 1
			calculation.cooldown = calculation.cooldown +2
		end
		if ActiveAuras["Tree of Life"] then
			calculation.aoe = calculation.aoe + 2
		end
	end
	self.Calculation["Moonfire"] = function( calculation, _ )
		--Glyph of Moonfire - 4.0 (additive - 3.3.3)
		if self:HasGlyph(54829) then
			calculation.dmgM_dot_Add = calculation.dmgM_dot_Add + 0.2
		end
		if self:GetSetAmount("T14 Balance") >= 4 then
			calculation.hits = calculation.hits + 1
		end
	end
	self.Calculation["Starfall"] = function( calculation )
		--Glyph of Starfall - 4.0
		if self:HasGlyph(54828) then
			calculation.cooldown = calculation.cooldown - 30
		end
		if calculation.targets > 1 then
			calculation.hits = 20
		end
		if self:GetSetAmount("T14 Balance") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.2
		end
	end
	self.Calculation["Wrath"] = function( calculation, ActiveAuras )
		--Glyph of Wrath - 4.0 -- Multiplicative??
		if self:HasGlyph(54756) then
			calculation.dmgM = calculation.dmgM * 1.1
		end
		if ActiveAuras["Tree of Life"] then
			calculation.dmgM = calculation.dmgM * 1.3
		end
	end
	--self.Calculation["Starfire"] = function( calculation, ActiveAuras, spell )
	--end
	self.Calculation["Starsurge"] = function( calculation, ActiveAuras )
		if self:GetSetAmount("T15 Balance") >= 2 then
			calculation.critPerc = calculation.critPerc + 10
		end
	end	
	--[[self.Calculation["Insect Swarm"] = function( calculation )
	end --]]
 	self.Calculation["Maul"] = function( calculation, ActiveAuras, spell )
		if ActiveAuras["Bleeding"] or ActiveAuras["Lacerate"] then
			--Multiplicative - 3.3.3
			calculation.dmgM = calculation.dmgM * 1.2
		end
		--Glyph of Maul - 4.0
		if self:HasGlyph(54811) then
			if calculation.targets >= 2 then
				calculation.aoe = 2
				calculation.aoeM = 0.5
			end
		end
	end
	self.Calculation["Ferocious Bite"] = function( calculation, ActiveAuras )
		if ActiveAuras["Bleeding"] or ActiveAuras["Lacerate"] then
			calculation.critPerc = calculation.critPerc + 25
		end
		local energy = math_min(25,UnitPower("player", 3) - calculation.actionCost)
		if energy > 0 then
			calculation.dmgM = calculation.dmgM * (1 + energy/25)
			calculation.actionCost = calculation.actionCost + energy
		end
	end
	self.Calculation["Rip"] = function( calculation )
		local spec = calculation.spec
		-- Feral has more damage in this spec for Rip than any other spec
		if spec == 2 then
			calculation.dmgM = calculation.dmgM * 1.255
		end
		if self:GetSetAmount("T14 Feral") >= 4 then
			calculation.hits = calculation.hits + 2
		end
	end 
	self.Calculation["Faerie Fire"] = function( calculation, ActiveAuras )
		if not ActiveAuras["Bear Form"] then
			calculation.zero = true
		end
	end
	self.Calculation["Mangle (Bear)"] = function( calculation, ActiveAuras )
		if ActiveAuras["Berserk"] then
			calculation.aoe = 3
			calculation.cooldown = 0
		end
	end
	self.Calculation["Mangle (Cat)"] = function( calculation )
		if self:GetSetAmount("T14 Feral") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.05
		end
	end
	--[[self.Calculation["Lacerate"] = function( calculation )
	end --]]
	--[[self.Calculation["Swipe (Bear)"] = function( calculation )
	end --]]
	--[[self.Calculation["Rake"] = function( calculation )
	end --]]
	self.Calculation["Shred"] = function( calculation, ActiveAuras, _, baseSpell )
		if ActiveAuras["Bleeding"] or ActiveAuras["Lacerate"] then
			--Multiplicative - 3.3.3
			calculation.dmgM = calculation.dmgM * 1.2
		end
		if self:GetSetAmount("T14 Feral") >= 2 then
			calculation.dmgM = calculation.dmgM * 1.05
		end
	end
	self.Calculation["Shred!"] = self.Calculation["Shred"]
	self.Calculation["Ravage"] = function( calculation, _ )
		if UnitHealth("target") ~=0 and (UnitHealth("target") / UnitHealthMax("target")) >= 0.80 then
			calculation.critPerc = calculation.critPerc + 50
		end
	end
	--self.Calculation["Frenzied Regeneration"] = function (calculation)
		--calculation.dmg = math_max(2.2 * (calculation.AP - (calculation.agi * 2)),calculation.stamina * 2.5)
		--Need to confirm variables with Gagorian
	--end
	self.Calculation["Sunfire"] = function (calculation)
		if self:GetSetAmount("T14 Balance") >= 4 then
			calculation.hits = calculation.hits + 1
		end
	end
	self.Calculation["Ravage!"] = self.Calculation["Ravage"]

	--Tier pieces
	self.SetBonuses["T14 Feral"] = { 86649, 86650, 86651, 86652, 86653, 85309, 85310, 85311, 85312, 85313, 86923, 86924, 86925, 86926, 86927 }
	self.SetBonuses["T14 Guardian"] = { 86719, 86720, 86721, 86722, 86723, 85383, 85382, 85381, 85380, 85379, 86938, 86939, 86940, 86941, 86942 }
	self.SetBonuses["T14 Resto"] = { 86928, 86929, 86930, 86931, 86932, 86694, 86695, 86696, 86697, 86698, 85354, 85355, 85356, 85357, 85358 }
	self.SetBonuses["T14 Balance"] = { 86644, 86645, 86646, 86647, 86648, 85304, 85305, 85306, 85307, 85308, 86933, 86934, 86935, 86936, 86938 }
	self.SetBonuses["T15 Feral"] = { 95235, 95236, 95237, 95238, 95239, 95835, 95836, 95837, 95838, 95839, 96579, 96580, 96581, 96582, 96583 }
	self.SetBonuses["T15 Guardian"] = { 95250, 95251, 95252, 95253, 95254  }
	self.SetBonuses["T15 Resto"] = { 95240, 95241, 95242, 95243, 95244  }
	self.SetBonuses["T15 Balance"] = { 95245, 95246, 95247, 95248, 95249, 96589, 96590, 96591, 96592, 96593, 95845, 95846, 95847, 95848, 95849 }
--AURA
--Player
	--Moonkin form - 4.0
	self.PlayerAura[GetSpellInfo(24858)] = { ActiveAura = "Moonkin Form", ID = 25868, NoManual = true }
	--Tree of Life - 4.0
	self.PlayerAura[GetSpellInfo(33891)] = { ActiveAura = "Tree of Life", ID = 33891, NoManual = true }
	--Cat Form - 4.0
	self.PlayerAura[GetSpellInfo(768)] = { ActiveAura = "Cat Form", ID = 768, NoManual = true }
	--Bear Form - 4.0
	self.PlayerAura[GetSpellInfo(5487)] = { ActiveAura = "Bear Form", ID = 5487, NoManual = true }
	--Nature's Bounty
	self.PlayerAura[GetSpellInfo(96206)] = { Update = true, Spells = "Nourish" }
	--Rejuvenation - 4.0
	self.PlayerAura[GetSpellInfo(774)] = { Update = true, Spells = "Nourish", ID = 774 }
	--Regrowth - 4.0
	self.PlayerAura[GetSpellInfo(16561)] = { Update = true, Spells = "Nourish", ID = 16561 }
	--Lifebloom - 4.0
	self.PlayerAura[GetSpellInfo(33763)] = { Update = true, Spells = "Nourish", ID = 33763 }
	--Wild Growth - 4.0
	self.PlayerAura[GetSpellInfo(48438)] = { Update = true, Spells = "Nourish", ID = 48438 }
	--Tranquility - 4.0
	self.PlayerAura[GetSpellInfo(21791)] = { Update = true, Spells = "Nourish", ID = 21791 }
	--Frenzied Regeneration - 4.0
	self.PlayerAura[GetSpellInfo(22842)] = { School = "Healing", ActiveAura = "Frenzied Regeneration", ID = 22842 }
	--Tiger's Fury 4.0 - (needs to be divided out of spell modifiers)
	self.PlayerAura[GetSpellInfo(5217)] = { School = "Damage Spells", Multiply = true, ModType = "dmgM_Physical", Value = 0.15, NoManual = true, }
	--Eclipse (Solar) 4.0
	self.PlayerAura[GetSpellInfo(48517)] = { School = { "Nature", "Spellstorm" }, ActiveAura = "Eclipse", ID = 48517, ModType =
		function( calculation, _ )
			--TODO: Additive or multiplicative?
			calculation.dmgM = calculation.dmgM * 1.15
		end
	}
	--Eclipse (Lunar) 4.0
	self.PlayerAura[GetSpellInfo(48518)] = { School = { "Arcane", "Spellstorm" }, ActiveAura = "Eclipse", ID = 48518, ModType =
		function( calculation, _ )
			--TODO: Additive or multiplicative?
			calculation.dmgM = calculation.dmgM * 1.15
		end
	}
	--Berserk 4.0
	self.PlayerAura[GetSpellInfo(50334)] = { ActiveAura = "Berserk", ID = 50334, ModType =
		function( calculation, _, _, index )
			if not index and calculation.requiresForm == 3 then
				calculation.actionCost = calculation.actionCost * 0.5
			end
		end
	}
	--Nature's Swiftness 4.1
	self.PlayerAura[GetSpellInfo(132158)] = { Spells = { "Nourish", "Healing Touch", "Regrowth" }, Value = 0.5, ID = 132158, NoManual = true }
	--Harmony
	self.PlayerAura[GetSpellInfo(100977)] = { School = "Healing", ActiveAura = "Harmony", ID = 100977, NoManual = true, Value = 0.1, ModType = "dmgM_dot" }
	--Incarnation: Chosen of Elune (Need to check spell id in game to verify)
	self.PlayerAura[GetSpellInfo(102560)] = { School = { "Arcane", "Nature" }, ID = 102560, ModType = 
		function(calculation)
			if not calculation.healingSpell then
				calculation.dmgM = calculation.dmgM * 1.25
			end
		end
	}
	--Incarnation: Tree of Life
	self.PlayerAura[GetSpellInfo(33891)] = { School = "Healing", ID = 33891, Value = 0.15, ModType = "dmgM" }
--Target
	--Insect Swarm (For t13 bonus)
	self.TargetAura[GetSpellInfo(5570)] = { Spells = { "Starfire", "Starsurge", "Wrath" }, ActiveAura = "Insect Swarm", ID = 5570 }
	--Rejuvenation - 4.0
	self.TargetAura[GetSpellInfo(774)] = { School = "Healing", ActiveAura = "Rejuvenation", Index = true, SelfCastBuff = true, ID = 774 }
	--Regrowth - 4.0
	self.TargetAura[GetSpellInfo(16561)] = { School = "Healing", ActiveAura = "Regrowth", Index = true, SelfCastBuff = true, ID = 16561 }
	--Lifebloom - 4.0
	self.TargetAura[GetSpellInfo(33763)] = { School = "Healing", ActiveAura = "Lifebloom", SelfCastBuff = true, ID = 33763 }
	--Wild Growth - 4.0
	self.TargetAura[GetSpellInfo(48438)] = { School = "Healing", ActiveAura = "Wild Growth", SelfCastBuff = true, ID = 48438 }
	--Tranquility - 4.0
	self.TargetAura[GetSpellInfo(21791)] = { School = "Healing", ActiveAura = "Tranquility", SelfCastBuff = true, ID = 21791 }
	--Lacerate 4.0
	self.TargetAura[GetSpellInfo(33745)] = { Spells = { "Shred", "Maul", "Ferocious Bite" }, ActiveAura = "Lacerate", Apps = 3, SelfCast = true, ID = 33745 }

--Bleed effects
	--Deep Wound - 4.0 (TODO: Verify this contains all important ones)
	self.TargetAura[GetSpellInfo(43104)] = 	{ ActiveAura = "Bleeding", Manual = "Bleeding", Spells = { "Shred", "Maul", "Ferocious Bite" }, ID = 59881 }
	--Pounce - 4.0
	self.TargetAura[GetSpellInfo(9005)] = 	self.TargetAura[GetSpellInfo(43104)]
	--Rip - 4.0
	self.TargetAura[GetSpellInfo(1079)] = 	self.TargetAura[GetSpellInfo(43104)]
	--Rake - 4.0
	self.TargetAura[GetSpellInfo(59881)] = 	self.TargetAura[GetSpellInfo(43104)]
	--Garrote - 4.0
	self.TargetAura[GetSpellInfo(703)] = 	self.TargetAura[GetSpellInfo(43104)]
	--Rupture - 4.0
	self.TargetAura[GetSpellInfo(1943)] = 	self.TargetAura[GetSpellInfo(43104)]
	--Piercing Shots - 4.0
	self.TargetAura[GetSpellInfo(53234)] = 	self.TargetAura[GetSpellInfo(43104)]

        --Dream of Cenarius Healing version (Excludes Tranquility)
        --self.PlayerAura[GetSpellInfo(108382)] = { ID=108382, BuffID=108382, School = "Healing", Not = "Tranquility", Value = 0.3, ModType = "dmgM" }
        self.PlayerAura[GetSpellInfo(108382)] = {  ModType = 
		function( calculation, _, _, _, index )
			local id = select(11,UnitAura("player","Dream of Cenarius",nil,"PLAYER"))
			if id == 108382 then
      				if calculation.School == "Healing" and calculation.spellName ~= "Tranquility" then
					calculation.dmgM = calculation.dmgM * 1.3
				end
			elseif id == 108381 then
     				if calculation.melee then
					calculation.dmgM = calculation.dmgM * 1.30
				elseif calculation.spellName == "Moonfire" or calculation.spellName == "Sunfire" then
					calculation.dmgM = calculation.dmgM * 1.25
				end
			end
		end
	}
	--Nature's Vigil
	--TODO: Verify spellid for aura.
	self.PlayerAura[GetSpellInfo(124974)] = { ID=124974, Value = 0.12, ModType = "dmgM" }

	local bear = GetSpellInfo(5487)
	local bear_rank = select(2,GetSpellInfo(33878))
	local cat = GetSpellInfo(768)
	local cat_rank = select(2,GetSpellInfo(33876))
	self.spellInfo = {
		[GetSpellInfo(5176)] = {
			["Name"] = "Wrath",
			["ID"] = 5176,
			["Data"] = { 2.433 * 1.1, 0.25, 1.2159 * 1.1, ["ct_min"] = 1500, ["ct_max"] = 2500 },
			[0] = { School = "Nature", },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(16914)] = {
			["Name"] = "Hurricane",
			["ID"] = 16914,
			["Data"] = { 0.31, 0, 0.31 },
			[0] = { School = "Nature", Hits = 10, Channeled = 10, AoE = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(5570)] = {
			["Name"] = "Insect Swarm",
			["ID"] = 5570,
			["Data"] = { 0.416, 0, 0.397 },
			[0] = { School = "Nature", Hits = 6, eDot = true, eDuration = 12, sTicks = 2, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8921)] = {
			["Name"] = "Moonfire",
			["ID"] = 8921,
			["Data"] = { 0.5709, 0.20, 0.2399, 0.2399, 0, 0.2399 },
			[0] = { School = "Arcane", Hits_dot = 7, eDuration = 14, sTicks = 2, },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		[GetSpellInfo(93402)] = {
			--Sunfire
			["Name"] = "Moonfire",
			["ID"] = 93402,
			["Data"] = { 0.5701, 0.20, 0.2399, 0.2399, 0, 0.2399 },
			[0] = { School = "Nature", Hits_dot = 7, eDuration = 14, sTicks = 2, },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		[GetSpellInfo(2912)] = {
			["Name"] = "Starfire",
			["ID"] = 2912,
			["Data"] = { 4.051 * 1.1, 0.25, 1.9689 * 1.1, ["ct_min"] = 3500, ["ct_max"] = 3200 },
			[0] = { School = "Arcane", },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(48505)] = {
			["Name"] = "Starfall",
			["ID"] = 48505,
			["Data"] = { 0.527 * 1.1, 0, 0.1169 * 1.1 },
			[0] = { School = "Arcane", Hits = 10, eDot = true, eDuration = 10, AoE = 2, NoPeriod = true, NoDotHaste = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(88747)] = {
			["Name"] = "Wild Mushroom",
			["ID"] = 88747,
			["Data"] = { 0.295, 0.19, 0.349 },
			[0] = { School = "Nature", AoE = true },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(78674)] = {
			["Name"] = "Starsurge",
			["ID"] = 78674,
			["Data"] = { 4.5399, 0.319, 2.388 },
			[0] = { School = "Spellstorm", Double = { "Nature", "Arcane" }, Cooldown = 15 },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(5185)] = {
			["Name"] = "Healing Touch",
			["ID"] = 5185,
			["Data"] = { 18.388, 0.166, 1.86, ["ct_min"] = 1500, ["ct_max"] = 3000  },
			[0] = { School = { "Nature", "Healing", }, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(774)] = {
			["Name"] = "Rejuvenation",
			["ID"] = 774,
			["Data"] = { 3.868, 0, 0.3919 },
			[0] = { School = { "Nature", "Healing", }, Hits = 4, Hits_dot = 4, eDot = true, eDuration = 12, sTicks = 3, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8936)] = {
			["Name"] = "Regrowth",
			["ID"] = 8936,
			["Data"] = { 9.4849, 0.1099, 0.958, 0.7189, 0, 0.0729 },
			[0] = { School = { "Nature", "Healing", }, Hits_dot = 3, eDuration = 6, sTicks = 2, },
			[1] = { 0, 0, hybridDotDmg = 0, },
		},
		[GetSpellInfo(740)] = {
			["Name"] = "Tranquility",
			["ID"] = 740,
			["Data"] = { 8.255, 0, 0.8349, 1.409, 0, 0.142  },
			[0] = { School = { "Nature", "Healing", }, Channeled = 8, Hits = 4, Hits_dot = 4, eDuration = 8, sTicks = 2, Cooldown = 480, AoE = 5, HybridAoE = true },
			[1] = { 0, 0, hybridDotDmg = 0 },
		},
		[GetSpellInfo(33763)] = {
			["Name"] = "Lifebloom",
			["ID"] = 33763,
			["Data"] = { 7.455, 0, 0.7519, 0.5669, 0, 0.057 },
			[0] = { School = { "Nature", "Healing" }, Hits_dot = 10, eDuration = 10, sTicks = 1, DotStacks = 3, },
			[1] = { 0, 0, hybridDotDmg = 0, },
		},
		[GetSpellInfo(48438)] = {
			["Name"] = "Wild Growth",
			["ID"] = 48438,
			["Data"] = { 0.9039, 0, 0.092 },
			[0] = { School = { "Nature", "Healing" }, Hits = 7, eDot = true, eDuration = 7, sTicks = 1, Cooldown = 8, AoE = 5 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(50464)] = {
			["Name"] = "Nourish",
			["ID"] = 50464,
			["Data"] = { 6.0739, 0.15, 0.614 },
			[0] = { School = { "Nature", "Healing" }, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(18562)] = {
			["Name"] = "Swiftmend",
			["ID"] = 18562,
			["Data"] = { 12.7569, 0, 1.2899 },
			[0] = { School = { "Nature", "Healing" }, Cooldown = 15, HybridAoE = true, HybridAoE_Only = true },
			[1] = { 0, 0, },
		},
		--Feral
		[GetSpellInfo(770)] = {
			["Name"] = "Faerie Fire",
			["ID"] = 770,
			["Data"] = { 0.009 },
			[0] = { Melee = true, School = "Nature", APBonus = 0.302, requiresForm = 1 },
			[1] = { 0 },
		},
		[GetSpellInfo(1079)] = {
			["Name"] = "Rip",
			["ID"] = 1079,
			["Data"] = { 0.103, ["perCombo"] = 0.387 },
			[0] = { Melee = true, Hits = 8, APBonus = 0.0484, ComboPoints = true, requiresForm = 3, eDot = true, eDuration = 16, Ticks = 2, Bleed = true },
			[1] = { 0, PerCombo = 0 },
		},
		[GetSpellInfo(5221)] = {
			["Name"] = "Shred",
			["ID"] = 5221,
			["Data"] = { 0.071 },
			[0] = { WeaponDamage = 5.0, Melee = true, requiresForm = 3, Bleed = true, Armor = true, },
			[1] = { 0 },
		},
		[GetSpellInfo(114236)] = {
                        ["Name"] = "Shred!",
                        ["ID"] = 114236,
                        ["Data"] = { 0.071 },
                        [0] = { WeaponDamage = 5.0, Melee = true, requiresForm = 3, Bleed = true, Armor = true, },
                        [1] = { 0 },
		},

		[GetSpellInfo(1822)] = {
			["Name"] = "Rake",
			["ID"] = 1822,
			["Data"] = { 0.09, ["extra"] = 0.09 },
			[0] = { Melee = true, APBonus = 0.3, Hits_extra = 5, APBonus_extra = 0.3, E_eDuration = 15, E_Ticks = 3, E_canCrit = true, requiresForm = 3, Bleed = true, BleedExtra = true },
			[1] = { 0, Extra = 0 },
		},
		[GetSpellInfo(22568)] = {
			["Name"] = "Ferocious Bite",
			["ID"] = 22568,
			["Data"] = { 0.456, 0.74, ["perCombo"] = 0.695},
			[0] = { Melee = true, APBonus = 0.196, ComboPoints = true, requiresForm = 3 },
			[1] = { 0, 0, PerCombo = 0 },
		},
		[GetSpellInfo(6785)] = {
			["Name"] = "Ravage",
			["ID"] = 6785,
			["Data"] = { 0.071 },
			[0] = { Melee = true, WeaponDamage = 9.5, requiresForm = 3, },
			[1] = { 0 },
		},
		[GetSpellInfo(102545)] = {
			["Name"] = "Ravage!",
			["ID"] = 102545,
			["Data"] = { 0.071 },
			[0] = { Melee = true, WeaponDamage = 9.5, requiresForm = 3, },
			[1] = { 0 },
		},		
		[GetSpellInfo(9005)] = {
			["Name"] = "Pounce",
			["ID"] = 9005,
			["Data"] = { 0.697 },
			[0] = { Melee = true, APBonus = 0.053, Hits = 6, eDot = true, eDuration = 18, Ticks = 3, Bleed = true, requiresForm = 3, },
			[1] = { 0 },
		},
                [GetSpellInfo(106785)] = {
                        [0] = function(ActiveAuras)
                                if UnitBuff("player", bear) then
                                        return self.spellInfo["Swipe (Bear)"][0], self.spellInfo["Swipe (Bear)"]
                                elseif UnitBuff("player", cat) then
                                        return self.spellInfo["Swipe (Cat)"][0], self.spellInfo["Swipe (Cat)"]
                                end
                        end,
                },
		["Swipe (Bear)"] = {
			["Name"] = "Swipe (Bear)",
			["ID"] = 779,
				["Data"] = { 0.225 },
			[0] = { APBonus = 0.225, Melee = true, requiresForm = 1, AoE = true, Cooldown = 3 },
			[1] = { 0, 0, },
		},
		["Swipe (Cat)"] = {
			["Name"] = "Swipe (Cat)",
			["ID"] = 62078,
			["Data"] = { 0 },
			[0] = { WeaponDamage = 4.0, Melee = true, requiresForm = 3, AoE = true },
			[1] = { 0 },
		},
		--Mangle
		[GetSpellInfo(33878)] = {
			[0] = function(ActiveAuras)
				if UnitBuff("player", bear) then
					return self.spellInfo["Mangle (Bear)"][0], self.spellInfo["Mangle (Bear)"]
				elseif UnitBuff("player", cat) then
					return self.spellInfo["Mangle (Cat)"][0], self.spellInfo["Mangle (Cat)"]
				end
			end,
		},
		["Mangle (Bear)"] = {
			["Name"] = "Mangle (Bear)",
			["ID"] = 33878,
			["Data"] = { 0 },
			[0] = { WeaponDamage = 2.8, Melee = true, requiresForm = 1, Cooldown = 6, },
			[1] = { 0 },
		},
		["Mangle (Cat)"] = {
			["Name"] = "Mangle (Cat)",
			["ID"] = 33876,
			["Data"] = { 0.071 },
			[0] = { WeaponDamage = 5.0, Melee = true, requiresForm = 3, },
			[1] = { 0 },
		},
		[GetSpellInfo(6807)] = {
			["Name"] = "Maul",
			["ID"] = 6807,
			[0] = { WeaponDamage = 1.1, Melee = true, Bleed = true, Armor = true, Cooldown = 3 },
		},		
		--BUG: Blizzard tooltip values for base and combo are too low. Real values seem to be increased by about 155%. Check when Blizzard upates tooltip
		[GetSpellInfo(22570)] = {
			["Name"] = "Maim",
			["ID"] = 22570,
			["Data"] = { 0.075, ["perCombo"] = 0.179, },
			[0] = { Melee = true, WeaponDamage = 2, ComboPoints = true, requiresForm = 3, Cooldown = 10 },
			[1] = { 0, 0, PerCombo = 0 },
		},
		[GetSpellInfo(33745)] = {
			["Name"] = "Lacerate",
			["ID"] = 33745,
			["Data"] = { 0 },
			[0] = { Melee = true, APBonus = 0.616, Hits_extra = 5, APBonus_extra = 0.0512, E_eDuration = 15, E_Ticks = 3, E_canCrit = true, BleedExtra = true, requiresForm = 1 },
			[1] = { 0, Extra = 0 },
		},
		[GetSpellInfo(77758)] = {
			["Name"] = "Thrash (Bear)",
			["ID"] = 77758,
			["Data"] = {  1.125, ["extra"] = 0.627 },
			[0] = { Melee = true, APBonus = 0.191, Hits_extra = 3, APBonus_extra = 1.128, E_eDuration = 16, E_Ticks = 2, E_canCrit = true, requiresForm = 1, Cooldown = 6, E_AoE = true },
			[1] = { 0, 0, Extra = 0 },
		},
		[GetSpellInfo(106830)] = {
			["Name"] = "Thrash (Cat)",
			["ID"] = 106830,
			["Data"] = { 1.125, ["extra"] = "0.627" },
			[0] = { Melee = true, APBonus = 0.191, Hits_extra = 5, APBonus_extra = 0.141, E_eDuration = 15, E_Ticks = 3, E_canCrit = true, requiresForm = 3, Bleed = true, BleedExtra = true },
			[1] = { 0, Extra = 0 },
                },
		--Symbiosis
		[GetSpellInfo(122282)] = {
			["Name"] = "Death Coil",
			["ID"] = 122282,
			["Data"] = { 0.997 },
			[0] = { School = Shadow, APBonus = 0.495 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(110701)] = {
			["Name"] = "Consecrate",
			["ID"] = 110701,
			["Data"] = { 0, 0, 0.04 },
			[0] = { School = Nature, Cooldown = 30, AoE = true, APBonus = 0.04, Hits_extra = 2, E_eDuration = 10, E_Ticks = 5, E_canCrit = true },
			[1] = { 0, 0 }, 
		},
		-- Data supported by simulationcraft (Spirit Bite = Bonus of 1 from the scaler data, plus 1 AP = 1 dmg) 120 second CD.
		[GetSpellInfo(110807)] = {
			["Name"] = "Feral Spirit",
			["ID"] = 110807,
			["Data"] = { 1 },
			[0] = { APBonus = 1, Cooldown = 120 },
			[1] = { 0 , 0 },
		},
		[GetSpellInfo(102351)] = {
			["Name"] = "Cenarion Ward",
			["ID"] = 102351,
			["Data"] = { 11.2799 },
			[0] = { School = { "Nature", "Healing" }, Hit_extra = 3, E_eDuration = 6, E_Ticks = 2, E_canCrit = true, SPBonus = 1.0399 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(22842)] = {
			["Name"] = "Frenzied Regeneration",
			["ID"] = 22842,
			[0] = { School = { "Healing" }, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(106737)] = {
			--The ability varies by spec and is a talent at the level 60 tier.
			[0] = { function (calculation)
					local spec = calculation.spec
					if spec == 1 then
						return self.spellInfo["Force of Nature (Balance)"][0], self.spellInfo["Force of Nature (Balance)"]
					elseif spec == 2 then
						return self.spellInfo["Force of Nature (Feral)"][0], self.spellInfo["Force of Nature (Feral)"]
					elseif spec == 3 then
						return self.spellInfo["Force of Nature (Guardian)"][0], self.spellInfo["Force of Nature (Guardian)"]
					elseif spec == 4 then
						return self.spellInfo["Force of Nature (Resto)"][0], self.spellInfo["Force of Nature (Resto)"]
					end
				end
			},
		},
		-- 3 treants summoned for a total of 15 seconds - attacking (except for Resto) every 2 seconds for 15 seconds.
		["Force of Nature (Balance)"] = {
			["Name"] = "Force of Nature (Balance)",
			["ID"] = 33831,
			["Data"] = { 1.4998 },
			[0] = { School = "Nature", SPBonus = 0.3, Hit_extra = 7, E_eDuration = 15, E_Ticks = 2, E_canCrit = true, Cooldown = 60 },
			[1] = { 0, 0 },
		},
		["Force of Nature (Feral)"] = {
			--TODO: Verify whether or not treants are affected by Savage Roar/Tiger's Fury
			["Name"] = "Force of Nature (Feral)",
			["ID"] = 102703,
			["Data"] = { 3.2007 },
			[0] = { School = "Physical", APBonus = 0.107, Hit_extra = 7, E_eDuration = 15, E_Ticks = 2, E_canCrit = true, Cooldown = 60 },
			[1] = { 0, 0 },
		},
		["Force of Nature (Guardian)"] = {
			["Name"] = "Force of Nature (Guardian)",
			["ID"] = 102706,
			["Data"] = { 0.6412 },
			[0] = { School = "Physical", APBonus = 0.021, Hit_extra = 7, E_eDuration = 15, E_Ticks = 2, E_canCrit = true, Cooldown = 60 },
			[1] = { 0, 0 },
		},
		["Force of Nature (Resto)"] = { 
			["Name"] = "Force of Nature (Resto)",
			["ID"] = 102693,
			["Data"] = { 3.1879 },
			[0] = { School = { "Nature", "Healing" }, SPBonus = 0.323, Hits_extra = 6, E_eDuration = 15, E_Ticks = 2.5, E_canCrit = true, Cooldown = 60 },
			[1] = { 0, 0 },
		}, 
	}
	self.talentInfo = {
	--FERAL:
		--Nurturing Instinct
		[GetSpellInfo(33873)] = { [1] = { Effect = 0.5, Caster = true, Spells = "Healing", ModType = "Nurturing Instinct" }, },
	--RESTORATION:
		--Blessing of the Grove (additive - 4.0)
		--Swift Rejuvenation
		[GetSpellInfo(33886)] = { [1] = { Effect = -0.5, Caster = true, Spells = "Rejuvenation", ModType = "castTime" }, },
		--Heart of the Wild talent
		[GetSpellInfo(108288)] = { [1] = { Effect = 0.06, Spells = "All", Multiply = true, NoManual = true, ModType =  { "agiM", "intM" }, }, },
	}
end
