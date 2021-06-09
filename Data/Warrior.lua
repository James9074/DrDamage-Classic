if select(2, UnitClass("player")) ~= "WARRIOR" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local GetMastery = GetMastery
local GetSpecialization = GetSpecialization
local math_min = math.min
local math_abs = math.abs
local select = select
local UnitPower = UnitPower
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitDamage = UnitDamage
local GetCritChance = GetCritChance
local GetTalentInfo = GetTalentInfo
local IsDualWielding = IsDualWielding
local IsSpellKnown = IsSpellKnown

--NOTE; One-Handed Weapon Specialization is handled by API (7th return of UnitDamage("player"), Two-Handed Weapon Specialization is multiplied into weapon damage range

function DrDamage:PlayerData()
	--Events
	local lastRage = 0
	local execute = GetSpellInfo(5308)
	self.Calculation["UNIT_POWER"] = function()
		local rage = UnitPower("player",1)
		if (rage < 30) and (lastRage > 30 or math_abs(rage - lastRage) >= 5) or (rage >= 30 and lastRage < 30) then
			lastRage = rage
			self:UpdateAB(execute)
		end
	end
	--Specials
	--Enraged Regeneration
	self.ClassSpecials[GetSpellInfo(55694)] = function()
		--Field dressing
		local rank = select(5,GetTalentInfo(1,2)) or 0
		local spec = GetSpecialization()
		local bonus = 1 + ((spec == 2) and GetMastery() * 0.01 * 4.7 or 0)
		bonus = bonus * (1 + rank * 0.03) * (1 + rank * 0.1)
		return 0.3 * UnitHealthMax("player") * bonus, true
	end
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			if mastery > 0 and mastery ~= masteryLast then
				if baseSpell.AutoAttack then
					--Mastery: Strikes of Opportunity
					calculation.extraDamage = 0.55
					calculation.extraChance = mastery * 0.01
					calculation.extraName = "Mastery: "
					calculation.masteryLast = mastery
				end
			end
		elseif spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
				--Unshackled fury, increases the physical damage done as a function of the mastery.
				local masteryBonus = calculation.masteryBonus
				if masteryBonus then
					calculation.dmgM = calculation.dmgM / masteryBonus
				end
				--Mastery: Unshackled Fury
				local bonus = 1 + (mastery * 0.01)
				calculation.dmgM = calculation.dmgM * bonus
				calculation.masteryLast = mastery
				calculation.masteryBonus = bonus
			end
		end
		if ActiveAuras["Skull Banner"] and self:GetSetAmount( "T15 - DPS" ) >= 4 then
			calculation.critPerc = calculation.critPerc + 35
		end
	end
	local mastery_icon = "|T" .. select(3,GetSpellInfo(76838)) .. ":16:16:1:-1|t"
	self.Calculation["WARRIOR"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		--Specialization
		local spec = calculation.spec
		if spec == 1 then
			--TODO: Check specialization is active
			if IsSpellKnown(86526) then
				calculation.strM = calculation.strM * 1.05
			end
			if calculation.mastery > 0 and baseSpell.AutoAttack then
				calculation.extraDamage = 0
				calculation.extraTicks = nil
				calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. mastery_icon) or mastery_icon
				local min, max = self:WeaponDamage(calculation, true)
				local value = 0.5 * (min + max)
				calculation.extra = value
				calculation.extraM = true
				calculation.E_dmgM = calculation.dmgM_global
				calculation.E_canCrit = true
				calculation.E_critM = 1 + 2 * self.Damage_critMBonus
			end
		elseif spec == 2 then
			--TODO: Check specialization is active
			if IsSpellKnown(86526) then
				calculation.strM = calculation.strM * 1.05
			end
			--Crazed Berserker
			if IsSpellKnown(23588) and baseSpell.AutoAttack then
				calculation.dmgM = calculation.dmgM * 1.1
				calculation.offHdmgM = calculation.offHdmgM * 1.25
			end
			--Single Minded Fury, hopefully.
			--Requires both weapons to be one handed and for the spell to be known.
			--Increases damage for all abilities by 35%
			--Also increases offhand damage by and additional 35%.
			if IsSpellKnown(81099) and (Weapon == GetSpellInfo(196) or Weapon == GetSpellInfo(198) or Weapon == GetSpellInfo(201) and (Offhand == GetSpellInfo(196) or Offhand == GetSpellInfo(198) or Offhand == GetSpellInfo(201))) then
				calculation.dmgM = calculation.dmgM * 1.35
				calculation.offHdmgM = calculation.offHdmgM * 1.35
			end			
		end
		--Deep Wounds
		if (IsSpellKnown(115768) and (not calculation.NoCrits) and baseSpell.DeepWounds) or (IsSpellKnown(84615) and baseSpell.BloodAndThunder) then
			if not calculation.unarmed or calculation.offHand and baseSpell.AutoAttack then
				calculation.extraDamage = 0
				calculation.extraWeaponDamage = calculation.bleedBonus
				-- Increased by another 65% in 5.4 (was 1.5 weapon damage)
				calculation.extraWeaponDamage = calculation.extraWeaponDamage * 2.475
				calculation.extraWeaponDamage_dmgM = calculation.dmgM_global
				--calculation.extraWeaponDamageChanceCrit = true
				calculation.extraName = "Deep Wounds: "
				calculation.extraTicks = 5 
			end
			if calculation.offHand and baseSpell.AutoAttack then
				calculation.extraWeaponDamage_O = calculation.bleedBonus
				calculation.extraTicks = nil
			end
		end
		if IsSpellKnown(12712) and ( Weapon == GetSpellInfo(197) or Weapon == GetSpellInfo(199) or Weapon == GetSpellInfo(202)) then 
			--Seasoned Soldier (Arms at the moment, but leaving it here just in case that changes)
			calculation.dmgM = calculation.dmgM * 1.25
		end
		--Blood Bath
		if IsSpellKnown(113344) then
			calculation.extraAvg = 0.3
			calculation.extraTicks = 5
			calculation.extraName = "Bloodbath: "
		end

	end
--ABILITIES
	self.Calculation["Heroic Strike"] = function( calculation, ActiveAuras, _, spell )
		if Weapon == GetSpellInfo(196) or Weapon == GetSpellInfo(198) or Weapon == GetSpellInfo(201) then
			calculation.dmgM = calculation.dmgM * 1.4
		end
	end
	self.Calculation["Shield Slam"] = function( calculation, ActiveAuras, Talents )
		--Glyph of Heavy Repurcussions
		if self:HasGlyph(58388) and ActiveAuras["Shield Block"] then
			calculation.dmgM = calculation.dmgM * 1.5
		end
	end
	--self.Calculation["Devastate"] = function( calculation, ActiveAuras, _, spell )
	--end
	self.Calculation["Thunder Clap"] = function ( calculation, ActiveAuras )
		local spec = calculation.spec
		-- Does Greater damage for arms
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.2
		end
	end
	self.Calculation["Execute"] = function( calculation, ActiveAuras )
		local spec = calculation.spec
		local rage = math_min(20,UnitPower("player", 1) - 10)
		if rage > 0 then
			calculation.APBonus = calculation.APBonus + (rage/20) * 2 * calculation.APBonus
			calculation.minDam = calculation.minDam - 1
			calculation.maxDam = calculation.maxDam - 1
			calculation.actionCost = calculation.actionCost + rage
		end
		-- Arms does 20% greater damage on this ability
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.25
		end
	end
	self.Calculation["Cleave"] = function( calculation )
		if Weapon == GetSpellInfo(196) or Weapon == GetSpellInfo(198) or Weapon == GetSpellInfo(201) then
			calculation.dmgM = calculation.dmgM * 1.4
		end
	end
	self.Calculation["Mortal Strike"] = function( calculation )
		if self:GetSetAmount( "T14 - DPS" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.25
		end
	end
	self.Calculation["Overpower"] = function( calculation )
		--Glyph of Overpower (4.0)
		if self:HasGlyph(58386) then
			--CHECK
			calculation.dmgM_Add = calculation.dmgM_Add + 0.2
		end
		--Increased crit for prot and fury, but not arms.
		if spec ~= 1 then
			calculation.critPerc = calculation.critPerc + 60
		end
	end
	self.Calculation["Revenge"] = function( calculation, _, Talents )
		--Glyph of Revenge (4.0)
		if self:HasGlyph(58364) then
			--CHECK
			calculation.dmgM_Add = calculation.dmgM_Add + 0.5
		end
		calculation.aoe = 3
	end
	self.Calculation["Bloodthirst"] = function( calculation )
		--Glyph of Bloodthirst (4.0)
		if self:HasGlyph(58367) then
			--CHECK
			calculation.dmgM_Add = calculation.dmgM_Add + 1
		end
		--Double normal crit chance
		calculation.critPerc = calculation.critPerc * 2
		if self:GetSetAmount( "T14 - DPS" ) >= 2 then
			calculation.dmgM = calculation.dmgM * 1.25
		end
	end
	self.Calculation["Slam"] = function( calculation, _ , Talents, _, baseSpell )
		--NOTE: Slam base damage is multiplied by weapon damage multiplier
		calculation.minDam = calculation.minDam * baseSpell.WeaponDamage
		calculation.maxDam = calculation.maxDam * baseSpell.WeaponDamage
	end
	self.Calculation["Heroic Leap"] = function ( calculation )
		local spec = calculation.spec
		--Arms receives 20% more damage on this ability
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.2
		end
	end
	self.Calculation["Shockwave"] = function( calculation )
		local spec = calculation.spec
		--Arms receives 20% more damage on this ability
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.2
		end
	end
	self.Calculation["Victory Rush"] = function( calculation )
		local spec = calculation.spec
		--Arms receives 20% more damage on this ability
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.2
		end
	end
	self.Calculation["Bladestorm"] = function( calculation )
		local spec = calculation.spec
		if spec == 1 then
			calculation.WeaponDamage = 1.8
		elseif spec == 3 then
			calculation.WeaponDamage = 1.6
		end
	end
	--self.Calculation["Raging Blow"] = function( calculation )
	--end
	--self.Calculation["Rend"] = function( calculation )
		--BUG - the initial damage is applied to the dot and initially
	--end
	self.Calculation["Dragon Roar"] = function (calculation)
		local spec = calculation.spec
		--Arms receives 20% more damage on this ability
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.2
		end
		-- Always crits and ignores armor
		calculation.critPerc = 100
		calculation.armorM = 1
	end
	self.Calculation["Storm Bolt"] = function (calculation)
		local playerLevel, targetLevel, boss = self:GetLevels()
		-- Gets base + 300% (or 400%) if target is immune to stuns.  Bosses always are.
		if boss then 
			calculation.dmgM = calculation.dmgM * 4
		end
	end
	self.Calculation["Impending Victory"] = function (calculation)
		local spec = calculation.spec
		if calculation.spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.25
		end
	end
--SETS
	self.SetBonuses["T14 - DPS"] = { 86672, 86671, 86673, 86670, 86669, 85329, 85330, 85331, 85332, 85333, 87193, 87194, 87192, 87195, 87196 }
	self.SetBonuses["T15 - DPS"] = { 95530, 95531, 95532, 95533, 95534 } 
--AURA
--Player
	--Recklessness (Talent - 4.0)
	--TODO: Check which abilities gain crit chance
	self.PlayerAura[GetSpellInfo(1719)] = { Value = 30, ModType = "critPerc", ID = 1719, Not = { "Attack", "Shockwave", "Concussion Blow", "Heroic Throw", "Shattering Throw", "Thunder Clap" } }
	--Meat Cleaver (Talent - 4.0)
	self.PlayerAura[GetSpellInfo(85739)] = { Value = 1, Apps = 3, Spells = { "Raging Blow" }, ID = 85739 }
	--Shield Block (Ability - 4.0)
	self.PlayerAura[GetSpellInfo(2565)] = { ActiveAura = "Shield Block", ID = 2565 }
	--Glyph of Raging Wind
	self.PlayerAura[GetSpellInfo(115317)] = { Spells = "Whirlwind", ID = 115317, Value = 0.10, ModType = "dmgM" }
	--Enrage
	self.PlayerAura[GetSpellInfo(12880)] = { ActiveAura = "Enraged", School = "Physical", ID = 12880, Value = 0.10, ModType = "dmgM" }
	--Avatar - Need to check spellID
	self.PlayerAura[GetSpellInfo(107574)] = { ID = 107574, Value = 0.2, ModType = "dmgM" }
	
--Target
	--Sunder Armor (Ability - 4.0)
	self.TargetAura[GetSpellInfo(7386)] = { ActiveAura = "Sunder Armor", Apps = 3, Value = 0.04, ModType = "armorM", Category = "-12% Armor", Manual = GetSpellInfo(7386), ID = 7386 }
	--Colossus Smash (Ability - 4.0)
	self.TargetAura[GetSpellInfo(86346)] = { Value = 1, ModType = "armorM", ID = 86346, SelfCast = true }

	self.spellInfo = {
		[GetSpellInfo(78)] = {
			["Name"] = "Heroic Strike",
			["ID"] = 78,
			["Data"] = { 0.40 },
			[0] = { WeaponDamage = 1.1, Cooldown = 1.5 },
			[1] = { 0 },
		},
		[GetSpellInfo(7384)] = {
			["Name"] = "Overpower",
			["ID"] = 7384,
			[0] = { WeaponDamage = 1.05, Unavoidable = true },
			[1] = { 0 },
		},
		[GetSpellInfo(6572)] = {
			["Name"] = "Revenge",
			["ID"] = 6572,
			["Data"] = { 7.50, 0.2 },
			[0] = { APBonus = 0.64, Cooldown = 9, },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(6343)] = {
			["Name"] = "Thunder Clap",
			["ID"] = 6343,
			["Data"] = { 0.25 },
			[0] = { APBonus = 0.45, Cooldown = 6, NoWeapon = true, AoE = true, Unavoidable = true, BloodAndThunder = true },
			[1] = { 0 },
		},
		[GetSpellInfo(845)] = {
			["Name"] = "Cleave",
			["ID"] = 845,
			[0] = { WeaponDamage = 0.82, Cooldown = 1.5 }, 
			[1] = { 0 },
		},
		[GetSpellInfo(5308)] = {
			["Name"] = "Execute",
			["ID"] = 5308,
			["Data"] = { 5.525 },
			[0] = { APBonus = 2.55 },
			[1] = { 10 },
		},
		[GetSpellInfo(1464)] = {
			["Name"] = "Slam",
			["ID"] = 1464,
			["Data"] = { 1.7596 },
			[0] = { WeaponDamage = 2.2 * 1.25 },
			[1] = { 0 },
		},
		[GetSpellInfo(23881)] = {
			["Name"] = "Bloodthirst",
			["ID"] = 23881,
			["Data"] = { 1 }, 
			[0] = { WeaponDamage = 0.9, Cooldown = 4.5, DeepWounds = true },
			[1] = { 0 },
		},
		[GetSpellInfo(12294)] = {
			["Name"] = "Mortal Strike",
			["ID"] = 12294,
			["Data"] = { 2.16 }, 
			[0] = { WeaponDamage = 1.75, Cooldown = 6, DeepWounds = true },
			[1] = { 0 },
		},
		[GetSpellInfo(23922)] = {
			["Name"] = "Shield Slam",
			["ID"] = 23922,
			["Data"] = { 9*1.25, 0.05*1.25 },
			[0] = { APBonus = 1.2, NoWeapon = true, Cooldown = 6, --[[Offhand = select(7, GetItemInfo(40700)),--]] },
			[1] = { 0, 0, },
		},
		[GetSpellInfo(20243)] = {
			["Name"] = "Devastate",
			["ID"] = 20243,
			["Data"] = { 6.4398 },
			[0] = { WeaponDamage = 2.2, DeepWounds = true },
			[1] = { 0 },
		},
		[GetSpellInfo(34428)] = {
			["Name"] = "Victory Rush",
			["ID"] = 34428,
			["Data"] = { 1 },
			[0] = { APBonus = 0.56, NoWeapon = true },
			[1] = { 0 },
		},
		[GetSpellInfo(46968)] = {
			["Name"] = "Shockwave",
			["ID"] = 46968,
			[0] = { APBonus = 0.75, NoWeapon = true, AoE = true, Unavoidable = true, Cooldown = 20 },
			[1] = { 0 },
		},
		[GetSpellInfo(1680)] = {
			["Name"] = "Whirlwind",
			["ID"] = 1680,
			["Data"] = { 0 },
			[0] = { WeaponDamage = 0.85, DualAttack = true, Cooldown = 10, AoE = true },
			[1] = { 0 },
		},
		[GetSpellInfo(46924)] = {
			["Name"] = "Bladestorm",
			["ID"] = 46924,
			[0] = { WeaponDamage = 1.5, DualAttack = true, Cooldown = 90, Hits = 7, AoE = true },
			[1] = { 0 },
		},
		[GetSpellInfo(57755)] = {
			["Name"] = "Heroic Throw",
			["ID"] = 57755,
			[0] = { WeaponDamage = 0.5, Cooldown = 30 },
			[1] = { 0 },
		},
		[GetSpellInfo(64382)] = {
			["Name"] = "Shattering Throw",
			["ID"] = 64382,
			["Data"] = { 0.0096 },
			[0] = { APBonus = 0.5, Cooldown = 300 },
			[1] = { 12 },
		},
		[GetSpellInfo(86346)] = {
			["Name"] = "Colossus Smash",
			["ID"] = 86346,
			["Data"] = { 1.7799 },
			[0] = { WeaponDamage = 1.75, Cooldown = 20 },
			[1] = { 0 },
		},
		[GetSpellInfo(6544)] = {
			["Name"] = "Heroic Leap",
			["ID"] = 6544,
			[0] = { APBonus = 0.5, Cooldown = 45, NoWeapon = true },
			[1] = { 1 },
		},
		[GetSpellInfo(85288)] = {
			["Name"] = "Raging Blow",
			["ID"] = 85288,
			["Data"] = { 0 },
			[0] = { WeaponDamage = 1.9, DualAttack = true },
			[1] = { 0 },
		},
		[GetSpellInfo(100130)] = {
			["Name"] = "Wild Strike",
			["ID"] = 100130,
			["Data"] = { 0.3498 },
			[0] = { WeaponDamage = 2.3, OffhandAttack = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(118000)] = {
			["Name"] = "Dragon Roar",
			["ID"] = 118000,
			["Data"] = { 0.1653 }, 
			[0] = { APBonus = 1.4, AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(107570)] = {
			["Name"] = "Storm Bolt",
			["ID"] = 118000,
			[0] = { WeaponDamage = 1.25 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(103840)] = {
			["Name"] = "Impending Victory",
			["ID"] = 103840,
			["Data"] = { 1 },
			[0] = { APBonus = 0.56, Cooldown = 30 },
			[1] = { 0, 0 },
		},
	}
	self.talentInfo = {
	--FURY:
		--Single-Minded Fury
		[GetSpellInfo(81099)] = {	[1] = { Effect = 0.2, Spells = "Slam", ModType = "Single-Minded Fury" }, },
	}
end
