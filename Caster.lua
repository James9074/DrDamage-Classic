local _, playerClass = UnitClass("player")
if playerClass ~= "DRUID" and playerClass ~="MAGE" and playerClass ~="PALADIN" and playerClass ~="PRIEST" and playerClass ~="SHAMAN" and playerClass ~="WARLOCK" and playerClass ~= "DEATHKNIGHT" then return end
local playerHealer = (playerClass == "PRIEST") or (playerClass == "SHAMAN") or (playerClass == "PALADIN") or (playerClass == "DRUID")
local playerHybrid = (playerClass == "DRUID") or (playerClass == "PALADIN") or (playerClass == "SHAMAN") or (playerClass == "DEATHKNIGHT")

--Libraries
DrDamage = LibStub("AceAddon-3.0"):NewAddon("DrDamage","AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceBucket-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("DrDamage", true)
local GT = LibStub:GetLibrary("LibGratuity-3.0")
local DrDamage = DrDamage

--General
local settings
local type = type
local pairs = pairs
local tonumber = tonumber
local next = next
local math_abs = math.abs
local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local string_match = string.match
local string_sub = string.sub
local string_gsub = string.gsub
local string_find = string.find
local select = select

--Module
local UnitDamage = UnitDamage
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitLevel = UnitLevel
local UnitPower = UnitPower
local UnitIsPlayer = UnitIsPlayer
local UnitIsFriend = UnitIsFriend
local UnitExists = UnitExists
local UnitStat = UnitStat
local UnitRangedDamage = UnitRangedDamage
local UnitCreatureType = UnitCreatureType
local GetSpellInfo = GetSpellInfo
local GetSpellBonusDamage = GetSpellBonusDamage
local GetSpellBonusHealing = GetSpellBonusHealing
local GetSpellCritChance = GetSpellCritChance
local GetCritChance = GetCritChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local GetRangedCritChance = GetRangedCritChance
local GetManaRegen = GetManaRegen
local GetUnitManaRegenRateFromSpirit = GetUnitManaRegenRateFromSpirit
local GetSpellHitModifier = GetSpellHitModifier
local GetAttackPowerForStat = GetAttackPowerForStat
local HasWandEquipped = HasWandEquipped
local IsShiftKeyDown = IsShiftKeyDown

--Module variables
local DrD_ClearTable, DrD_Round, DrD_DmgCalc, DrD_BuffCalc
local spellInfo, PlayerAura, TargetAura, Consumables, Calculation

function DrDamage:Caster_OnEnable()
	local ABOptions = self.options.args.General.args.Actionbar.args
	if settings.DisplayType then
		if not ABOptions.DisplayType.values[settings.DisplayType] then
			settings.DisplayType = "AvgTotal"
		end
	end
	if settings.DisplayType2 then
		if not ABOptions.DisplayType2.values[settings.DisplayType2] then
			settings.DisplayType2 = false
		end
	end
	if not playerHybrid then
		local displayTypeTable = { ["Avg"] = 1, ["AvgTotal"] = 1, ["AvgHit"] = 2, ["AvgHitTotal"] = 2, ["AvgCrit"] = 3, ["MinHit"] = 4, ["MaxHit"] = 5, ["MinCrit"] = 6, ["MaxCrit"] = 7, ["MaxTotal"] = 7, ["DPS"] = 8, ["DPSC"] = 8, ["DPSCD"] = 8, ["CastTime"] = 9, ["PerHit"] = 2, }
		self.ClassSpecials[GetSpellInfo(5019) or "Shoot"] = function()
			if not HasWandEquipped() then return "" end
			local speed, min, max = UnitRangedDamage("player")
			local avg = (min + max) / 2
			local avgTotal = avg * (1 + 0.005 * GetRangedCritChance())
			local DPS = avgTotal / speed
			local display = settings.DisplayType and displayTypeTable[settings.DisplayType]
			if display then
				local text = select(display, avgTotal, avg, 1.5 * avg, min, max, 1.5 * min, 1.5 * max, DPS, DrD_Round(speed, 2))
				return text, nil, nil, (display == 9)
			end
		end
	end
	self:Caster_CheckBaseStats()
	DrD_ClearTable = self.ClearTable
	DrD_BuffCalc = self.BuffCalc
	DrD_Round = self.Round
	spellInfo = self.spellInfo
	PlayerAura = self.PlayerAura
	TargetAura = self.TargetAura
	Consumables = self.Consumables
	Calculation = self.Calculation
end

function DrDamage:Caster_RefreshConfig()
	settings = self.db.profile
end

local oldValues = 0
function DrDamage:Caster_CheckBaseStats()
	local newValues = 0

	--for i = 2, 7 do
		--newValues = newValues + GetSpellBonusDamage(i)
		--newValues = newValues + GetSpellCritChance(i)
	--end
	newValues = newValues
	+ GetSpellBonusDamage(3)
	+ GetSpellCritChance(3)
	+ GetSpellBonusHealing()
	+ GetSpellHitModifier()
	--Spell hit rating
	+ GetCombatRating(8)
	+ GetManaRegen("player")
	--Cast time
	+ select(7,GetSpellInfo(18960))
	--Spell haste rating
	--+ GetCombatRating(20)
	--Intellect
	--+ select(2,UnitStat("player",4))
	--Spirit
	--+ select(2,UnitStat("player",5))

	if newValues ~= oldValues then
		oldValues = newValues
		return true
	end

	return false
end

--Static values
local baseSpiM = (select(2,UnitRace("player")) == "Human") and 1.03 or 1
local troll = (select(2,UnitRace("player")) == "Troll")
local mage = (playerClass == "MAGE")
local mastery = GetSpellInfo(86471)

--Static tables
local schoolTable = { ["Holy"] = 2, ["Fire"] = 3, ["Nature"] = 4, ["Frost"] = 5, ["Shadow"] = 6, ["Arcane"] = 7 }
local potion_sickness = GetSpellInfo(53787) or ""
local ABRound = { ["DPS"] = true, ["DPSC"] = true, ["DPSCD"] = true, ["MPS"] = true }

--Temporary tables
local calculation = {}
local ActiveAuras = {}
local AuraTable = {}
local Talents = {}
local CalculationResults = {}

--[[
local function ModifyTable( table )
	if table then
		for k, v in pairs( table ) do
			if calculation[k] then
				local sign, value = string_sub(v,1,1), tonumber(string_sub(v,2))
				if sign == "=" then
					calculation[k] = value
				elseif sign == "+" then
					calculation[k] = calculation[k] + value
				elseif sign == "-" then
					calculation[k] = calculation[k] - value
				elseif sign == "*" then
					calculation[k] = calculation[k] * value
				elseif sign == "/" then
					calculation[k] = calculation[k] / value
				end
			end
		end
	end
end
--]]

function DrDamage:CasterCalc( name, rank, tooltip, modify, debug )
	if not spellInfo or not name then return end

	local spellTable
	if spellInfo[name]["Secondary"] and (settings.SwapCalc and (not tooltip or not IsShiftKeyDown()) or not settings.SwapCalc and tooltip and IsShiftKeyDown()) then
		spellTable = spellInfo[name]["Secondary"]
	else
		spellTable = spellInfo[name]
	end

	if not spellTable then return end
	local baseSpell = spellTable[0]

	if type(baseSpell) == "function" then
		baseSpell, spellTable = baseSpell(rank)
		if not (baseSpell and spellTable) then return end
	end

	if not rank then rank = 1
	else rank = tonumber(string_match(rank,"%d+")) or 1 end

	local spell = spellTable[rank]
	if not spell then return end
	local spellName = spellTable["Name"]
	local spellID = spellTable["ID"]
	local spellTalents = spellTable["Talents"]
	local spellPlayerAura = spellTable["PlayerAura"]
	local spellTargetAura = spellTable["TargetAura"]
	local spellConsumables = spellTable["Consumables"]
	local textLeft = spellTable["Text1"]
	local textRight = spellTable["Text2"]

	DrD_ClearTable( calculation )

	if type(baseSpell.School) == "table" then
		calculation.school = baseSpell.School[1]
		calculation.group = baseSpell.School[2]
		calculation.subType = baseSpell.School[3]
	else
		calculation.school = baseSpell.School
	end

	local healingSpell = (calculation.group == "Healing")					--Healing spell (boolean)
	calculation.healingSpell = healingSpell									--Healing spell, boolean
	calculation.caster = true
	calculation.name = name													--Ability name, localized
	calculation.spellName = spellName										--Ability name, enUS
	calculation.tooltipName = textLeft										--Text to display on left side of first line
	calculation.tooltipName2 = textRight									--Text to display on right side of first line
	calculation.minDam = math_floor(spell[1] + 0.5)							--Spell initial base min damage
	calculation.maxDam = math_floor(spell[2] + 0.5)							--Spell initial base max damage
	calculation.eDuration = baseSpell.eDuration or baseSpell.Channeled or 1	--Effect duration
	calculation.cooldown = baseSpell.Cooldown or 0							--Spell's cooldown
	calculation.hits = baseSpell.Hits										--Amount of hits of spell
	calculation.hits_dot = baseSpell.Hits_dot
	calculation.sTicks = baseSpell.sTicks									--Time between ticks of the spell
	calculation.canCrit = not baseSpell.NoCrits 							--Crits true/false
	calculation.hybridDotDmg = spell.hybridDotDmg							--DoT portion of hybrid spells
	calculation.eDot = baseSpell.eDot										--Is the spell a dot?
	calculation.manaCost = select(4,GetSpellInfo(baseSpell.SpellCost or spellID or name)) or 0	--Mana cost
	calculation.baseCost = calculation.manaCost
	calculation.powerType = select(6,GetSpellInfo(spellID or name))			--Power cost type
	calculation.playerMana = UnitPower("player",0)							--Player mana
	calculation.oocRegen, calculation.combatRegen = GetManaRegen("player")	--Mana regen
	calculation.baseRegen = 0.004 * calculation.playerMana
	calculation.spiritRegen = GetUnitManaRegenRateFromSpirit("player")
	calculation.regenRatio = (calculation.combatRegen - calculation.baseRegen) / (calculation.oocRegen - calculation.baseRegen)
	calculation.str = 0
	calculation.strM = 1
	--calculation.strM_Add = 0
	calculation.agi = 0
	calculation.agiM = 1
	--calculation.agiM_Add = 0
	calculation.int = 0
	calculation.intM = 1
	--calculation.intM_Add = 0
	calculation.spi = 0
	calculation.spiM = baseSpiM
	--calculation.spiM_Add = 0
	calculation.aoe = baseSpell.AoE											--Spell aoe amount
	calculation.targets = settings.TargetAmount								--Target amount for aoe spells
	calculation.chainFactor = baseSpell.chainFactor							--Chain effect spells
	calculation.leechBonus = baseSpell.Leech or 0							--Leech amount
	calculation.hybridCanCrit = true
	--calculation.noDotHaste = baseSpell.NoDotHaste
	--Calculation variables
	calculation.bDmgM = 1													--Base multiplier
	calculation.dmgM = 1													--Final multiplier
	calculation.dmgM_dot = 1												--Final multiplier to DoT portion
	calculation.dmgM_dd = 1													--Final coefficient multiplier for hybrid spells
	calculation.dmgM_dd_Add = 0												--Final coefficient additive modifier for hybrid spells
	calculation.dmgM_dot_Add = 0											--Talents: DoT Damage multiplier additive
	calculation.dmgM_Add = 0												--Talents: Damage multiplier additive
	calculation.dmgM_Magic = 1												--Magic damage modifier (CoE, Ebon Plague, Earth and Moon)
	calculation.dmgM_Physical = 1											--Physical damage modifier
	calculation.finalMod = 0 												--Modifier to final damage +/-
	calculation.finalMod_M = 1												--Modifier to calculated total damage
	--calculation.finalMod_fM = 0											--Modifier to final damage with dmgM coefficient
	--calculation.finalMod_sM = 0											--Modifier to final damage with SPBonus coefficient
	--calculation.finalMod_dot = 0											--Modifier to final dot damage +/-
	calculation.spellCrit = 0
	calculation.spellHit = 0
	calculation.meleeCrit = 0
	calculation.meleeHit = 0
	calculation.freeCrit = 0												--Mana crit modifier

	--CORE: Spell damage and coefficients
	calculation.SP = healingSpell and GetSpellBonusHealing() or baseSpell.Double and math_max(GetSpellBonusDamage(schoolTable[baseSpell.Double[1]]),GetSpellBonusDamage(schoolTable[baseSpell.Double[2]])) or GetSpellBonusDamage(schoolTable[calculation.school] or 1)
	calculation.SP_dd = 0
	calculation.SP_dot = 0
	calculation.SPBonus = baseSpell.SPBonus or 0
	calculation.SPBonus_Add = 0
	calculation.SPBonus_dot = baseSpell.SPBonus_dot or 0
	calculation.SPBonus_dot_Add = 0
	calculation.APBonus = baseSpell.APBonus or 0
	calculation.AP = baseSpell.APBonus and self:GetAP() or 0
	calculation.APM = 1
	calculation.SPM = 1
	calculation.AP_mod = 0
	calculation.SP_mod = 0	

	--Determine levels used to calculate
	local playerLevel, targetLevel, boss = self:GetLevels()
	if settings.TargetLevel > 0 then
		targetLevel = playerLevel + settings.TargetLevel
	end
	calculation.playerLevel = playerLevel
	calculation.targetLevel = targetLevel
	local target = not healingSpell and "target" or (not UnitExists("target") or baseSpell.SelfHeal) and "player" or UnitIsFriend("target","player") and "target" or UnitIsFriend("targettarget","player") and "targettarget" or "player"
	calculation.target = target

	--CORE: Calculate hit
	if baseSpell.MeleeHit then
		calculation.hitPerc = self:GetMeleeHit(playerLevel, targetLevel)
	else
		calculation.hitPerc = self:GetSpellHit(playerLevel, targetLevel)
	end

	--CORE: Calculate crit
	if baseSpell.MeleeCrit then
		calculation.critM = 1
		calculation.critPerc = GetCritChance()
	else
		calculation.critM = 1 --healingSpell and 1 or 0.5
		calculation.critPerc = baseSpell.Double and math_max(GetSpellCritChance(schoolTable[baseSpell.Double[1]]), GetSpellCritChance(schoolTable[baseSpell.Double[2]])) or GetSpellCritChance(schoolTable[calculation.school] or 1)
	end

	--CORE: Calculate modified cast time
	local ct = select(7, GetSpellInfo(spellID or name))
	if baseSpell.MeleeHaste then
		calculation.haste = 1 + 0.01 * GetCombatRatingBonus(19)
		calculation.hasteRating = GetCombatRating(19)
	else
		calculation.haste = 1.5 / (0.00015 * (select(7,GetSpellInfo(18960))))
		calculation.hasteRating = GetCombatRating(20)
	end
	if not ct or ct == 0 then
		if baseSpell.Channeled then
			calculation.castTime = baseSpell.Channeled
		else
			calculation.instant = true
			calculation.castTime = 1.5
		end
	else
		calculation.castTime = ct/1000 * calculation.haste
	end

	--CORE: Process modification tables
	--[[
	if self.CasterGlobalModify and not base then
		local modify = self.CasterGlobalModify
		ModifyTable( modify["All"] )
		ModifyTable( modify[calculation.school] )
		ModifyTable( modify[calculation.group] )
		ModifyTable( modify[spellName] )
	end
	if modify and type(modify) == "table" then
		ModifyTable( modify )
	end
	--]]

	--CORE: Manual variables from profile:
	if settings.Custom then
		if settings.CustomAdd then
			calculation.str = settings.Str
			calculation.agi = settings.Agi
			calculation.int = settings.Int
			calculation.spi = settings.Spi
			calculation.SP_mod = settings.SP
			calculation.AP_mod = settings.AP
			--Nether Attunement
			if IsSpellKnown(117957) and settings.HasteRating ~= 0 then
				calculation.combatRegen = (calculation.combatRegen / (1 + 0.01 * GetCombatRatingBonus(20))) * (1 + 0.01 * math_max(0, GetCombatRatingBonus(20) + self:GetRating("Haste", settings.HasteRating, true)))
			end			
		else
			--Do not allow stats below 0
			calculation.str = math_max(0, settings.Str)
			calculation.agi = math_max(0, settings.Agi)
			calculation.int = math_max(0, settings.Int)
			calculation.spi = math_max(0, settings.Spi)
			calculation.customStats = true
			--Attack Power (Agility/Strength)
			--[[
			local strToAP = GetAttackPowerForStat(1,UnitStat("player",1))
			local agiToAP = GetAttackPowerForStat(2,UnitStat("player",2))
			calculation.AP = calculation.AP - strToAP - agiToAP
			calculation.AP = select(2,UnitAttackPower("player"))
			end
			--]]
			calculation.AP = 0
			calculation.AP_mod = math_max(0, settings.AP)
			--Crit chance (Agility/Intellect)
			if baseSpell.MeleeCrit then
				calculation.critPerc = calculation.critPerc - self:GetCritChanceFromAgility()
			else
				calculation.critPerc = calculation.critPerc - self:GetCritChanceFromIntellect()
			end
			--Spell Power (Intellect)
			calculation.SP = 0 --calculation.SP - math_max(0,UnitStat("player",4)-10)
			calculation.SP_mod = math_max(0, settings.SP)
			--Ratings
			calculation.haste = calculation.haste - GetCombatRatingBonus(20)/100
			calculation.hasteRating = calculation.hasteRating - GetCombatRating(20)
			calculation.critPerc = calculation.critPerc - GetCombatRatingBonus((baseSpell.MeleeCrit and 9 or 11))
			calculation.hitPerc = calculation.hitPerc - GetCombatRatingBonus((baseSpell.MeleeHit and 6 or 8))
			--Nether attunement
			if IsSpellKnown(117957) then
				calculation.combatRegen = calculation.combatRegen / (1 + 0.01 * GetCombatRatingBonus(20)) * (1 + 0.01 * math_max(0,self:GetRating("Haste", settings.HasteRating, true)))
			else
			--Mana Regen (Spirit)
				calculation.combatRegen = calculation.combatRegen - calculation.spiritRegen * calculation.regenRatio
			end
		end
		--Ratings
		calculation.haste = math_max(1,(calculation.haste + 0.01 * self:GetRating("Haste", settings.HasteRating, true)))
		calculation.hasteRating = math_max(0, calculation.hasteRating + settings.HasteRating)
		calculation.spellHit = self:GetRating("Hit", settings.HitRating, true)
		calculation.meleeHit = calculation.spellHit
		calculation.spellCrit = self:GetRating("Crit", settings.CritRating, true)
		calculation.meleeCrit = calculation.meleeCrit
	end

	--CORE: Add mana potions if not potion sickness
	if settings.ManaConsumables and not UnitDebuff("player", potion_sickness) then
		calculation.playerMana = calculation.playerMana + (28501+31500)/2
	end

	--CORE: Apply talents
	for i=1,#spellTalents do
		local talentValue = spellTalents[i]
		local modType = spellTalents[("ModType" .. i)]

		if calculation[modType] then
			if spellTalents[("Multiply" .. i)] then
				calculation[modType] = calculation[modType] * (1 + talentValue)
			else
				calculation[modType] = calculation[modType] + talentValue
			end
		elseif self.Calculation[modType] then
			self.Calculation[modType](calculation, talentValue, Talents, baseSpell, spell)
		else
			Talents[modType] = talentValue
		end
	end

	--CORE: Buffs/Debuffs
	local mod
	if baseSpell.NoGlobalMod then 
		mod = 1
	elseif healingSpell then 
		mod = self.healingMod
	else
		mod = (select(7, UnitDamage("player")) or 1) * (self.casterMod or 1)
		if troll and not UnitIsFriend("player","target") then
			local creature = UnitCreatureType("target")
			if creature and creature == L["Beast"] then
				mod = mod * 1.05
			end
		end
	end
	if mod and mod > 0 then calculation.dmgM = calculation.dmgM * mod end
	--BUFF/DEBUFF -- DAMAGE/HEALING -- PLAYER
	for index=1,40 do
		local buffName, rank, texture, apps = UnitBuff("player",index)
		if buffName then
			if spellPlayerAura[buffName] then
				DrD_BuffCalc( PlayerAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, "player" )
				AuraTable[buffName] = true
			end
		else break end
	end
	--DEBUFF -- DAMAGE/HEALING -- PLAYER
	for index=1,40 do
		local buffName, rank, texture, apps = UnitDebuff("player",index)
		if buffName then
			if spellPlayerAura[buffName] then
				DrD_BuffCalc( PlayerAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, "player" )
				AuraTable[buffName] = true
			end
		else break end
	end
	if next(settings["PlayerAura"]) or debug then
		for buffName in pairs(debug and spellPlayerAura or settings["PlayerAura"]) do
			if spellPlayerAura[buffName] and not AuraTable[buffName] then
				DrD_BuffCalc( PlayerAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName )
			end
		end
	end
	if next(settings["Consumables"]) or debug then
		for buffName in pairs(debug and spellConsumables or settings["Consumables"]) do
			if spellConsumables[buffName] then
				local aura = Consumables[buffName]
				if not UnitBuff("player", (aura.Alt or buffName)) then
					DrD_BuffCalc( aura, calculation, ActiveAuras, Talents, baseSpell, buffName )
				end
			end
		end
	end
	if not baseSpell.NoTargetAura then
		--DEBUFF -- DAMAGE/HEALING -- TARGET
		for index=1,40 do
			local buffName, rank, texture, apps = UnitDebuff(target,index)
			if buffName then
				if spellTargetAura[buffName] then
					DrD_BuffCalc( TargetAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, target )
					AuraTable[buffName] = true
				end
			else break end
		end
		--BUFF - HEALING -- TARGET
		if healingSpell then
			for index=1,40 do
				local buffName, rank, texture, apps = UnitBuff(target,index)
				if buffName then
					if spellTargetAura[buffName] then
						DrD_BuffCalc( TargetAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, target )
						AuraTable[buffName] = true
					end
				else break end
			end
		end
		if next(settings["TargetAura"]) or debug then
			for buffName in pairs(debug and spellTargetAura or settings["TargetAura"]) do
				if spellTargetAura[buffName] and not AuraTable[buffName] then
					DrD_BuffCalc( TargetAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName )
				end
			end
		end
	end

	--CORE: Sum up buffs, hit and crit
	if baseSpell.MeleeCrit then
		calculation.critPerc = calculation.critPerc + calculation.meleeCrit
	else
		calculation.critPerc = calculation.critPerc + calculation.spellCrit
	end
	if baseSpell.MeleeHit then
		calculation.hitPerc = calculation.hitPerc + calculation.meleeHit
	else
		calculation.hitPerc = calculation.hitPerc + calculation.spellHit
	end
	if not healingSpell then
		calculation.dmgM = calculation.dmgM * calculation.dmgM_Magic
		if not baseSpell.NoGlobalMod then
			calculation.dmgM = calculation.dmgM / calculation.dmgM_Physical
		end
	end

	--CORE: Calculate crit depression
	if settings.TargetLevel > 0 or not UnitIsPlayer("target") then
		if settings.CritDepression then -- and baseSpell.MeleeCrit then
			if boss then
				calculation.critPerc = calculation.critPerc - 3
			else
				local deltaLevel = math_max(0,targetLevel - playerLevel)
				calculation.critPerc = calculation.critPerc - deltaLevel
			end
		end
	end	

	if Calculation[playerClass] then
		Calculation[playerClass]( calculation, ActiveAuras, Talents, spell, baseSpell )
	end
	if Calculation[spellName] then
		Calculation[spellName]( calculation, ActiveAuras, Talents, spell, baseSpell )
	end

	--CORE: Add Haste
	calculation.castTime = calculation.castTime / calculation.haste

	--CORE: Crit modifier
	if not calculation.critM_custom then
		local baseCrit = baseSpell.MeleeCrit and 1 or calculation.casterCrit and 0.995 or 1
		local bonus = (1 + baseCrit) * (healingSpell and self.Healing_critMBonus or self.Damage_critMBonus) * (1 + (calculation.critM - baseCrit) / baseCrit)
		calculation.critM = calculation.critM + bonus
	end

	--CORE: Resilience
	if settings.Resilience > 0 and not healingSpell then
		calculation.dmgM = calculation.dmgM * math_min(1, 0.99 ^ (settings.Resilience / self:GetRating("PVPResilience")) - 0.4)
	end

	--CORE: Sum spell power coefficient
	calculation.SPBonus = (calculation.SPBonus + calculation.SPBonus_Add) * (baseSpell.sFactor or 1)
	calculation.SPBonus_dot = (calculation.SPBonus_dot + calculation.SPBonus_dot_Add) * (baseSpell.sFactor or 1)

	--CORE: Reset cooldown if <= 0
	if calculation.cooldown and calculation.cooldown <= 0 then
		calculation.cooldown = nil
	end

	--CORE: Duration mods
	local baseDuration = spell.eDuration or baseSpell.eDuration
	calculation.modDuration = baseDuration and (calculation.eDuration > baseDuration) and (1 + (calculation.eDuration - baseDuration) / baseDuration) or 1

	local avgTotal = DrD_DmgCalc( baseSpell, spell, false, false, tooltip )

	if tooltip and not baseSpell.NoNext then
		if settings.Next or settings.CompareStats or settings.CompareStr or settings.CompareAgi or settings.CompareInt or settings.CompareAP or settings.CompareCrit or settings.CompareHit or settings.CompareHaste then
			local avgTotal = DrD_DmgCalc( baseSpell, spell, true )
			CalculationResults.Stats = avgTotal
			if calculation.canCrit then
				calculation.critPerc = calculation.critPerc + 1
				CalculationResults.NextCrit = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.critPerc = calculation.critPerc - 1
			end
			if (calculation.SPBonus > 0) or (calculation.SPBonus_dot > 0) then
				calculation.int = calculation.int + 10
				CalculationResults.NextInt = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.int = calculation.int - 10
			end
			if calculation.APBonus > 0 or calculation.APtoSP then
				calculation.AP_mod = calculation.AP_mod + 10
				CalculationResults.NextAP = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.AP_mod = calculation.AP_mod - 10
				if GetAttackPowerForStat(1,100) > 0 then
					calculation.str = calculation.str + 10
					CalculationResults.NextStr = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
					calculation.str = calculation.str - 10
				end
			end
			if baseSpell.MeleeCrit or calculation.APBonus > 0 and GetAttackPowerForStat(2,100) > 0 or calculation.APtoSP then
				calculation.agi = calculation.agi + 10
				CalculationResults.NextAgi = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.agi = calculation.agi - 10
			end
			if not healingSpell and not baseSpell.Unresistable then
				local temp = settings.HitCalc and avgTotal or DrD_DmgCalc( baseSpell, spell, true, true )
				calculation.hitPerc = calculation.hitPerc + 1
				CalculationResults.NextHit = DrD_DmgCalc( baseSpell, spell, true, true ) - temp
			end
		end
	end

	DrD_ClearTable( Talents )
	DrD_ClearTable( ActiveAuras )
	DrD_ClearTable( AuraTable )
	--temp = nil

	local text1 = settings.DisplayType and (ABRound[settings.DisplayType] and math_floor(CalculationResults[settings.DisplayType] + 0.5) or CalculationResults[settings.DisplayType])
	local text2 = settings.DisplayType2 and (ABRound[settings.DisplayType2] and math_floor(CalculationResults[settings.DisplayType2] + 0.5) or CalculationResults[settings.DisplayType2])
	return text1, text2, CalculationResults, calculation, debug and ActiveAuras
end

local function DrD_FreeCrits( casts, calculation )
	local total = casts
	local mod = calculation.freeCrit * calculation.critPerc / 100
	for i = 1, 5 do
		casts = math_floor(mod * casts)
		if casts == 0 then break end
		total = total + casts
	end
	return total
end

DrD_DmgCalc = function( baseSpell, spell, nextCalc, hitCalc, tooltip )
	--CORE: Adjust stats
	local statCalc
	if calculation.str ~= 0 or calculation.str_mod then
		calculation.str = (calculation.str_mod or 0) + calculation.str * calculation.strM --* (1 + calculation.strM_Add)
		calculation.str_mod = nil
		statCalc = true
	end
	if calculation.agi ~= 0 or calculation.agi_mod then
		calculation.agi = (calculation.agi_mod or 0) + calculation.agi * calculation.agiM --* (1 + calculation.agiM_Add)
		calculation.agi_mod = nil
		statCalc = true
	end
	if calculation.int ~= 0 or calculation.int_mod  then
		calculation.int = (calculation.int_mod or 0) + calculation.int * calculation.intM --* (1 + calculation.intM_Add)
		calculation.int_mod = nil
		statCalc = true
	end
	if calculation.spi ~= 0 or calculation.spi_mod  then
		calculation.spi = (calculation.spi_mod or 0) + calculation.spi * calculation.spiM --* (1 + calculation.spiM_Add)
		calculation.spi_mod = nil
		statCalc = true
	end
	--CORE: Module stat modifiers
	DrDamage.Calculation["Stats"]( calculation, ActiveAuras, Talents, spell, baseSpell )
	--CORE: Stat delta calculation
	if statCalc then
		DrDamage:StatCalc(calculation, baseSpell)
	end
	--CORE: Apply bonuses
	if calculation.AP_mod ~= 0 or calculation.AP_bonus then
		calculation.AP_mod = calculation.AP_mod * calculation.APM + (calculation.AP_bonus or 0)
		calculation.AP_bonus = nil
	end
	if calculation.SP_mod ~= 0 or calculation.SP_bonus then
		calculation.SP_mod = calculation.SP_mod * calculation.SPM + (calculation.SP_bonus or 0)
		calculation.SP_bonus = nil
	end
	--CORE: Module secondary stat modifiers
	if DrDamage.Calculation["Stats2"] then
		DrDamage.Calculation["Stats2"]( calculation, ActiveAuras, Talents, spell, baseSpell )
	end
	calculation.customStats = false

	--CORE: Initialize variables
	local eDuration = calculation.eDuration
	local dispSPBonus = calculation.SPBonus * (calculation.hits or 1)
	local sTicks = calculation.sTicks

	--CORE: Damage modifier
	local dmgM_dot = calculation.dmgM_dot_global or calculation.dmgM_dot * calculation.dmgM * (1 + calculation.dmgM_Add + calculation.dmgM_dot_Add)
	local dmgM = calculation.dmgM_global or calculation.eDot and dmgM_dot or calculation.dmgM * (1 + calculation.dmgM_Add + calculation.dmgM_dd_Add)
	calculation.AP = calculation.AP + calculation.AP_mod
	calculation.SP = calculation.SP + calculation.SP_mod
	calculation.AP_mod = 0
	calculation.SP_mod = 0
	local AP = math_max(0, calculation.AP)
	local SP = math_max(0, calculation.SP)

	--CORE: Cap crit chance
	local critPerc = calculation.critPerc
	if critPerc > 100 then
		critPerc = 100
	elseif critPerc < 0 then
		critPerc = 0
	end
	--[[
	if not temp then
		temp = {}
		for k,v in pairs( calculation ) do
			temp[k] = v
		end
	else
		for k, v in pairs( calculation ) do
			if v ~= temp[k] then
				DrDamage:Print(k, v)
			end
		end
	end
	--]]
	--CORE: Basic min/max calculation
	local calcMinDmg = calculation.dmgM_dd * dmgM * (calculation.bDmgM * calculation.minDam + (SP + calculation.SP_dd) * calculation.SPBonus + AP * calculation.APBonus) + calculation.finalMod --+ calculation.finalMod_fM * dmgM --+ calculation.finalMod_sM * calculation.SPBonus
	local calcMaxDmg = calculation.dmgM_dd * dmgM * (calculation.bDmgM * calculation.maxDam + (SP + calculation.SP_dd) * calculation.SPBonus + AP * calculation.APBonus) + calculation.finalMod --+ calculation.finalMod_fM * dmgM --+ calculation.finalMod_sM * calculation.SPBonus
	local calcDotDmg = 0
	if nextCalc then
		calcMinDmg = (calculation.hits or 1) * calcMinDmg
		calcMaxDmg = (calculation.hits or 1) * calcMaxDmg
	else
		calcMinDmg = (calculation.hits or 1) * math_floor(calcMinDmg)
		calcMaxDmg = (calculation.hits or 1) * math_ceil(calcMaxDmg)
	end

	--CORE: Effects extended by talents. (Imp. SW:P etc.)
	if calculation.eDot and (calculation.modDuration > 1) then
		calcMinDmg = calcMinDmg * calculation.modDuration
		calcMaxDmg = calcMaxDmg * calculation.modDuration
		dispSPBonus = dispSPBonus * calculation.modDuration
	end

	--CORE: Calculate average
	local calcAvgDmg = (calcMinDmg + calcMaxDmg) / 2

	--CORE: Critical hits
	local calcAvgCrit, calcAvgDmgCrit, calcMinCrit, calcMaxCrit
	local critBonus, critBonus_dot = 0, 0
	if calculation.canCrit then
		calcMinCrit = calcMinDmg + calcMinDmg * calculation.critM
		calcMaxCrit = calcMaxDmg + calcMaxDmg * calculation.critM
		critBonus = (critPerc / 100) * calcAvgDmg * calculation.critM
		calcAvgCrit = (calcMinCrit + calcMaxCrit) / 2
		calcAvgDmgCrit = calcAvgDmg + critBonus
	else
		calcAvgCrit = calcAvgDmg
		calcAvgDmgCrit = calcAvgDmg
	end

	--DOT: Hybrid
	if calculation.hybridDotDmg then
		calcDotDmg = dmgM_dot * (calculation.hits_dot or 1) * (calculation.SPBonus_dot * (SP + calculation.SP_dot) + calculation.hybridDotDmg) * calculation.modDuration
		dispSPBonus = dispSPBonus + calculation.SPBonus_dot * calculation.modDuration * (calculation.hits_dot or 1)
		if calculation.hybridCanCrit then
			critBonus_dot = calcDotDmg * ((critPerc + (calculation.critPerc_dot or 0)) / 100) * (calculation.critM_dot or calculation.critM)
			calcDotDmg = calcDotDmg + critBonus_dot
		end
	end

	--DOT: Final modifier
	--calcDotDmg = calcDotDmg + calculation.finalMod_dot

	--SPECIAL: Extra effects
	local extra = calculation.extra or 0
	local extraMin, extraMax = calculation.extraMin or extra, calculation.extraMax or extra
	local extraAvg
	if calculation.extraCrit then
		extra = extra + calcAvgCrit * calculation.extraCrit
		extraMin = extraMin + (calcMinCrit or calcMinDmg) * calculation.extraCrit
		extraMax = extraMax + (calcMaxCrit or calcMaxDmg) * calculation.extraCrit
	elseif calculation.extraAvg then
		extra = extra + calcAvgDmgCrit * calculation.extraAvg
		extraMin = extraMin + calcMinDmg * calculation.extraAvg
		extraMax = extraMax + (calcMaxCrit or calcMaxDmg) * calculation.extraAvg
	end
	if calculation.extraChanceCrit then
		calculation.extraChance = critPerc / 100
	end
	if calculation.extraDamage then
		local bonus = calculation.extraDamage * SP + (calculation.extraDamageAP or 0) * AP
		extra = extra + bonus
		extraMin = extraMin + bonus
		extraMax = extraMax + bonus
	end
	if calculation.extraBonus then
		local bonus = calculation.extraDmgM or dmgM
		extra = extra * bonus
		extraMin = extraMin * bonus
		extraMax = extraMax * bonus
	end
	if calculation.extraCanCrit then
		extraAvg = extra * (1 + calculation.critM * critPerc / 100) * (calculation.extraChance or 1)
		extraMax = extraMax * (1 + calculation.critM)
	else
		extraAvg = extra * (calculation.extraChance or 1)
	end
	if calculation.extraCritEffect then
		extraAvg = extraAvg + calculation.extraCritEffect * extraMax * (critPerc / 100)
		extraMax = extraMax + calculation.extraCritEffect * extraMax
	end

	--SPECIAL: Final average modifiers (lightning overload) and effects from modules
	calcAvgDmgCrit = calcAvgDmgCrit * calculation.finalMod_M + extraAvg

	--CORE: Hit calculation:
	local hitPenalty, hitPenaltyAvg = 0, 0
	local hitPerc = calculation.hitPerc
	if hitPerc > 100 then
		hitPerc = 100
	elseif hitPerc < 0 then
		hitPerc = 0
	end
	if not calculation.healingSpell and not baseSpell.Unresistable then
		if settings.HitCalc or hitCalc then
			if (settings.TwoRoll and not baseSpell.MeleeHit) or (settings.TwoRoll_M and baseSpell.MeleeHit) then
				hitPenalty = calcAvgDmgCrit * ((hitPerc / 100) - 1)
				hitPenaltyAvg = (calcAvgDmg + critBonus) * ((hitPerc / 100) - 1)
			else
				hitPenalty = (calcAvgDmgCrit - critBonus) * ((hitPerc / 100) - 1)
				hitPenaltyAvg = calcAvgDmg * ((hitPerc / 100) - 1)
			end
			calcAvgDmgCrit = calcAvgDmgCrit + hitPenalty
		end
	end

	local perHit, ticks, nexttick
	--CORE: Per hit calculation
	if sTicks then
		if baseSpell.Channeled then
			ticks = math_floor(baseSpell.Channeled / sTicks + 0.5)
			perHit = calcAvgDmg / ticks
			sTicks = sTicks / calculation.haste
		elseif calculation.eDot or calculation.hybridDotDmg then
			local oticks = eDuration / sTicks
			local osticks, oduration
			if not baseSpell.NoDotHaste then
				osticks = sTicks
				oduration = eDuration
				if calculation.haste > 1 then
					sTicks = DrD_Round( sTicks / calculation.haste, 3)
				end
			end
			--if baseSpell.RoundTicks then
				ticks = math_floor(eDuration / sTicks + 0.5)
				eDuration = ticks * sTicks
			--else
			--	ticks = math_floor(eDuration / sTicks)
			--end
			perHit = (calculation.hybridDotDmg and (calcDotDmg - critBonus_dot) or calcAvgDmg) / oticks
			if osticks then
				--math_floor( eDuration / DrD_Round(osticks / x, 3)  + 0.5) = ticks + 1
				local nsticks = oduration / (ticks + 0.5)
				nsticks = math_floor(nsticks * 1000) / 1000 + 0.4999/1000
				nexttick = (osticks / nsticks - calculation.haste) * 100
			end
			if ticks > oticks then
				local nticks = ticks - oticks
				if calculation.eDot then
					calcMinDmg = calcMinDmg + nticks * (calcMinDmg / oticks)
					calcMaxDmg = calcMaxDmg + nticks * (calcMaxDmg / oticks)
					calcAvgDmg = calcAvgDmg + nticks * perHit
					calcAvgDmgCrit = calcAvgDmgCrit + nticks * (calcAvgDmgCrit / oticks)
				elseif calculation.hybridDotDmg then
					calcDotDmg = calcDotDmg + nticks * (calcDotDmg / oticks)
					if calculation.dotToDD then
						--local bonus = calculation.dotToDD * (nticks / oticks)
						local bonus = (1 + nticks/oticks)
						calcMinDmg = bonus * calcMinDmg
						calcMaxDmg = bonus * calcMaxDmg 
						calcAvgDmg = bonus * calcAvgDmg
						calcMinCrit = bonus * calcMinCrit
						calcMaxCrit = bonus * calcMaxCrit
						calcAvgCrit = bonus * calcAvgCrit
						calcAvgDmgCrit = bonus * calcAvgDmgCrit
						critBonus = bonus * critBonus
						hitPenalty = bonus * hitPenalty
						hitPenatlyAvg = bonus * hitPenaltyAvg
					end
				end
			end
			if baseSpell.Cap then
				local cap = (baseSpell.Cap --[[+ baseSpell.Cap_SPBonus * SP--]]) * dmgM_dot
				ticks = math_ceil(cap / perHit)
				calcDotDmg = ticks * perHit
				dispSPBonus = dispSPBonus - calculation.SPBonus_dot + (calculation.SPBonus_dot / 6) * ticks
				eDuration = ticks * sTicks
			end
		end
	elseif calculation.hits then
		ticks = calculation.hits
		perHit = calcAvgDmg / ticks
		if not baseSpell.NoPeriod then
			sTicks = (calculation.instant and eDuration or calculation.castTime) / calculation.hits
		end
	elseif calculation.extraTicks then
		ticks = calculation.extraTicks
		perHit = extra / ticks
	end

	--CORE: AoE and Chain effects (chain lightning, chain heal)
	local aoe, targets, perTarget
	if calculation.targets > 1 then
		if calculation.aoe then
			targets = (type(calculation.aoe) == "number") and math_min(calculation.targets, calculation.aoe) or calculation.targets
			if calculation.chainFactor then
				aoe = calcAvgDmgCrit * (calculation.chainBonus or 1) * (calculation.chainFactor + (targets >= 3 and calculation.chainFactor^2 or 0) + (targets >= 4 and calculation.chainFactor^3 or 0) + (targets >= 5 and calculation.chainFactor^4 or 0))
				targets = targets - 1
			elseif not baseSpell.HybridAoE_Only then
				aoe = calcAvgDmgCrit * (targets - 1)
				perTarget = calcAvgDmgCrit
			end
			if baseSpell.HybridAoE then
				aoe = (aoe or 0) + calcDotDmg * (targets - 1)
				perTarget = (perTarget or 0) + calcDotDmg
				--TODO: Do we want this to display?
				--if ticks then
				--	ticks = ticks * (targets - 1)
				--end
			end
		--elseif baseSpell.ExtraAoE then
		--	targets = (calculation.targets - 1) * (calculation.hits or 1)
		--	calcAvgDmgCrit = calcAvgDmgCrit - extraAvg
		--	aoe = extraAvg * targets
		--	perTarget = extraAvg
		end
		calcAvgDmgCrit = calcAvgDmgCrit + (aoe or 0)
	end

	--CORE: Remove average penalty for dot not hitting (when the main spell doesn't hit)
	if hitPenalty > 0 then
		calcAvgDmgCrit = calcAvgDmgCrit - calcDotDmg * (1 - ( hitPerc / 100))
	end

	--SPECIAL: Stacking spells, not used by anything at the moment
	--[[if baseSpell.Stacks then
		if calculation.extraDotDmg then
			perHit = calcAvgDmgCrit
			ticks = "~" .. baseSpell.Stacks
			calcAvgDmgCrit = calcAvgDmgCrit + calculation.extraDotDmg * (baseSpell.Stacks - 1) * dmgM_dot
		end
	end
	--]]

	local calcDPS, spamDmg, spamDPS
	if not nextCalc then
		--CORE: Minimum GCD 1s
		if calculation.castTime < 1 then
			calculation.castTime = 1
		else
			calculation.castTime = DrD_Round(calculation.castTime,3)
		end
		--CORE: Maximum GCD 1.5s
		if calculation.instant and calculation.castTime > 1.5 then
			calculation.castTime = 1.5
		end
		--CORE: DPS calculation
		if (calculation.eDot or calculation.hybridDotDmg) and not calculation.dotStacks then
			calcDPS = ( calcAvgDmgCrit + calcDotDmg ) / eDuration
			if baseSpell.DotStacks then
				spamDmg = (calcDotDmg - perHit) * (baseSpell.DotStacks)
				spamDPS = (calcDotDmg / eDuration) * (baseSpell.DotStacks)
			elseif calculation.hybridDotDmg then
				if calculation.constantDPS then
					calcDPS = calcAvgDmgCrit / calculation.castTime + calcDotDmg / eDuration
				elseif calculation.hybridDotRoll then
					spamDmg = calcAvgDmgCrit + calcDotDmg
					spamDPS = calcAvgDmgCrit / calculation.castTime + calcDotDmg / eDuration
				else
					spamDmg = calcAvgDmgCrit + (sTicks and (math_floor((calculation.cooldown or calculation.castTime)/sTicks) * perHit) or 0)
					spamDPS = spamDmg / (calculation.cooldown or calculation.castTime)
				end
			end
		else
			calcDPS = calcAvgDmgCrit / calculation.castTime
		end
	end

	--CORE: Add dot portion to total average value
	if not baseSpell.NoDotAverage then
		calcAvgDmgCrit = calcAvgDmgCrit + calcDotDmg
	end

	if nextCalc then
		return calcAvgDmgCrit
	else
		DrD_ClearTable( CalculationResults )

		CalculationResults.Avg =			math_floor(calcAvgDmg + hitPenaltyAvg + critBonus + 0.5)
		CalculationResults.AvgHit = 		math_floor(calcAvgDmg + 0.5)
		CalculationResults.PerHit = 		perHit and DrD_Round(perHit, 1 ) or CalculationResults.AvgHit
		CalculationResults.AvgHitTotal = 	math_floor((calcAvgDmg + calcDotDmg)/(calculation.hits or 1) + 0.5)
		CalculationResults.AvgTotal = 		math_floor(calcAvgDmgCrit + 0.5)
		CalculationResults.MinHit = 		math_floor(calcMinDmg)
		CalculationResults.MaxHit = 		math_ceil(calcMaxDmg)
		CalculationResults.MaxTotal = 		math_ceil(calcDotDmg + (calcMaxCrit or calcMaxDmg) + (aoe or 0) + extra)
		CalculationResults.CastTime = 		DrD_Round(calculation.castTime, 2)

		if calculation.canCrit and not calculation.hits then
			CalculationResults.MinCrit =	math_floor( calcMinCrit )
			CalculationResults.MaxCrit = 	math_ceil( calcMaxCrit )
			CalculationResults.AvgCrit = 	math_floor( calcAvgCrit + 0.5 )
		else
			CalculationResults.MinCrit =	CalculationResults.MinHit
			CalculationResults.MaxCrit = 	CalculationResults.MaxHit
			CalculationResults.AvgCrit = 	CalculationResults.AvgHit
		end
		if baseSpell.NoDPS then
			CalculationResults.DPS = 		CalculationResults.AvgTotal
			CalculationResults.DPSC = 		CalculationResults.AvgTotal
		else
			CalculationResults.DPS = 		DrD_Round(calcDPS, 1)
			CalculationResults.DPSC = 		not baseSpell.NoDPSC and DrD_Round(calcAvgDmgCrit / calculation.castTime, 1) or CalculationResults.DPS
		end

		CalculationResults.DPSCD = 			calculation.cooldown and DrD_Round(calcAvgDmgCrit / calculation.cooldown, 1) or CalculationResults.DPS

		if calculation.manaCost > 0 then
			local manaCost = 				calculation.manaCost * (1 - ((calculation.canCrit and critPerc or 0)/100) * calculation.freeCrit)
			CalculationResults.DPM = 		DrD_Round(calcAvgDmgCrit / manaCost, 1)
			CalculationResults.MPS = 		DrD_Round(manaCost / calculation.castTime, 1)
		else
			CalculationResults.DPM = 		"\226\136\158"
			CalculationResults.MPS = 		0
			CalculationResults.NoCost = 	true
		end
		--CORE: Write tooltip data
		if tooltip then
			CalculationResults.Healing = 			calculation.healingSpell
			CalculationResults.HitRate = 			DrD_Round( hitPerc, 2 )
			CalculationResults.DotDmg = 			math_floor( calcDotDmg + 0.5 )
			CalculationResults.DmgM = 				DrD_Round( dmgM, 3 )
			CalculationResults.Cooldown = 			calculation.cooldown

			if calculation.canCrit then
				CalculationResults.CritRate = 		DrD_Round( critPerc, 2 )
				CalculationResults.CritM =			DrD_Round( 100 + calculation.critM * 100, 2)
			end
			if calculation.APBonus > 0 then
				CalculationResults.AP = 			math_floor( AP + 0.5 )
				CalculationResults.APBonus = 		DrD_Round( calculation.APBonus, 3 )
			end
			if dispSPBonus > 0 then
				CalculationResults.SP = 			math_floor( SP + 0.5 )
				CalculationResults.SPBonus = 		DrD_Round( dispSPBonus, 3 )
			end
			if (calculation.castTime > 1) and not baseSpell.NoHaste then
				CalculationResults.Haste = 			math_max(0,calculation.hasteRating)
			end
			if calculation.instant then
				CalculationResults.GCD = 			calculation.castTime
			end
			if calculation.tooltipName then
				CalculationResults.Name = 			calculation.tooltipName
			end
			if calculation.tooltipName2 then
				CalculationResults.Name2 = 			calculation.tooltipName2
			end
			if calculation.customText then
				CalculationResults.CustomText	=	calculation.customText
				CalculationResults.CustomTextValue = math_floor( calculation.customTextValue + 0.5 )
			end
			if calculation.customText2 then
				CalculationResults.CustomText2	=	calculation.customText2
				CalculationResults.CustomTextValue2 = math_floor( calculation.customTextValue2 + 0.5 )
			end
			if spamDPS then
				CalculationResults.SpamDPS =		DrD_Round( spamDPS, 1 )
			end
			if aoe then
				CalculationResults.AoE = 			math_floor( aoe + 0.5 )
				CalculationResults.Targets = 		targets
				if perTarget then
					CalculationResults.PerTarget =	math_floor( perTarget + 0.5 )
				end
			end
			if extra > 0 then
				CalculationResults.Extra =			math_floor( extraAvg + 0.5 )
				CalculationResults.ExtraMin =		math_floor( extraMin )
				CalculationResults.ExtraMax = 		math_ceil( extraMax )
				CalculationResults.ExtraName =		calculation.extraName
				--CalculationResults.ExtraDPS = 	DrD_Round( extraDPS, 1 )
			end
			if perHit and ticks then
				if calculation.canCrit and not calculation.hybridDotDmg and not calculation.extraTicks 
				or calculation.hybridCanCrit and calculation.hybridDotDmg 
				or calculation.extraCanCrit and calculation.extraTicks then
					CalculationResults.PerCrit = 	DrD_Round( perHit + (calculation.critM_dot or calculation.critM) * perHit, 1 )
					CalculationResults.Crits = 		math_floor( ticks * (critPerc / 100) + 0.5 )
					ticks = 						ticks - CalculationResults.Crits
				end
				CalculationResults.Hits = 			ticks
				if sTicks then
					CalculationResults.Ticks = 		DrD_Round( sTicks, 3 )
					if nexttick then
						CalculationResults.NextTick = nexttick
					end
				end
			end
			if baseSpell.Leech and calculation.leechBonus ~= 1 or not baseSpell.Leech and calculation.leechBonus > 0 then
				if not baseSpell.DotLeech then
					CalculationResults.AvgLeech = 	DrD_Round( calcAvgDmg * calculation.leechBonus, 1 )
				end
				if perHit then
					CalculationResults.PerHitHeal = DrD_Round( perHit * calculation.leechBonus, 1 )
				end
			end
			if calculation.powerType == 0 and not baseSpell.NoManaCalc then
				local manaCost = calculation.manaCost
				if manaCost > 0 then
					local costMod = (1 - ((calculation.canCrit and critPerc or 0)/100) * calculation.freeCrit)
					if costMod < 1 then
						CalculationResults.TrueManaCost = DrD_Round(manaCost * costMod, 1)
					end
					local castTime = math_max((calculation.cooldown or 0), calculation.castTime)
					local PlayerMana = calculation.playerMana
					local base_casts = (calculation.freeCrit > 0) and calculation.canCrit and DrD_FreeCrits(math_floor(PlayerMana / manaCost), calculation) or math_floor(PlayerMana / manaCost)
					local casts = base_casts
					local regen_speed = calculation.combatRegen
					local regen_casts = 0 --math_floor(calculation.manaMod / manaCost)
					local regen_total = 0 --regen_casts * castTime * regen_speed

					if castTime <= 10 then
						for i = 1, 5 do
							local regen_new = casts * castTime * regen_speed
							casts = (calculation.freeCrit > 0) and calculation.canCrit and DrD_FreeCrits(math_floor(regen_new / manaCost), calculation) or math_floor(regen_new / manaCost)
							regen_total = regen_total + regen_new
							regen_casts = regen_casts + casts
							if casts == 0 then break end
						end
						CalculationResults.SOOM = DrD_Round((base_casts + regen_casts) * castTime, 1)
					end

					if spamDmg then
						CalculationResults.SpamDPM = DrD_Round(spamDmg / (CalculationResults.TrueManaCost or manaCost), 1)
					end
					if (base_casts + regen_casts) > 1000 then
						CalculationResults.castsBase = "\226\136\158"
						CalculationResults.castsRegen = 0
						CalculationResults.DOOM = "\226\136\158"
						CalculationResults.SOOM = nil
					else
						CalculationResults.castsBase = base_casts
						CalculationResults.castsRegen = regen_casts
						CalculationResults.DOOM = math_floor(CalculationResults.DPM * (PlayerMana + regen_total) + 0.5)
					end
				else
					CalculationResults.castsBase = "\226\136\158"
					CalculationResults.castsRegen = 0
				end
			elseif calculation.powerType == 6 then
				CalculationResults.RunicPower = L["PRP"] .. ":"
			end
		end
		return calcAvgDmgCrit
	end
end

function DrDamage:CasterTooltip( frame, name, rank )
	local value = select(3,self:CasterCalc(name, rank, true))
	if not value then return end

	local baseSpell
	if spellInfo[name]["Secondary"] and ((settings.SwapCalc and not IsShiftKeyDown()) or (IsShiftKeyDown() and not settings.SwapCalc)) then
		baseSpell = spellInfo[name]["Secondary"][0]
	else
		baseSpell = spellInfo[name][0]
		if type(baseSpell) == "function" then baseSpell = baseSpell(rank) end
	end

	frame:AddLine(" ")

	local r, g, b = 1, 0.82745098, 0
	local rt, gt, bt = 1, 1, 1

	if CalculationResults.Name2 then
		frame:AddDoubleLine( CalculationResults.Name .. ":", CalculationResults.Name2, rt, gt, bt, r, g, b )
	elseif CalculationResults.Name then
		frame:AddLine( CalculationResults.Name, r, g, b )
		frame:AddLine(" ")
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor1
		rt, gt, bt = c.r, c.g, c.b
		c = settings.TooltipTextColor2
		r, g, b = c.r, c.g, c.b
	end

	local healingSpell = CalculationResults.Healing
	local spellType, spellAbbr

	if healingSpell then
		spellType = L["Heal"]
		spellAbbr = L["H"]
	else
		spellType = L["Dmg"]
		spellAbbr = L["D"]
	end

	if settings.PlusDmg then
		local sp = CalculationResults.SPBonus and DrD_Round( CalculationResults.SP * CalculationResults.SPBonus * CalculationResults.DmgM, 1 )
		local ap = CalculationResults.APBonus and DrD_Round( CalculationResults.AP * CalculationResults.APBonus * CalculationResults.DmgM, 1 )
		if ap or sp then
			frame:AddDoubleLine(L["Effective"] .. " " .. (sp and L["SP"] or "") .. (sp and ap and "/" or "") .. (ap and L["AP"] or "") .. ":", (sp or "") .. (sp and ap and "/" or "") .. (ap or ""), rt, gt, bt, r, g, b )
		end
	end

	if settings.Coeffs then
		local sp = CalculationResults.SPBonus
		local ap = CalculationResults.APBonus
		if ap or sp then
			frame:AddDoubleLine(L["Coeffs"] --[[.. (sp and ap and (" " .. L["SP"] .. "/" .. L["AP"]) or "")--]] .. ":", (sp and (sp .."*" .. CalculationResults.SP) or "") .. (sp and ap and "/" or "") .. (ap and (ap .. "*" .. CalculationResults.AP) or ""), rt, gt, bt, r, g, b )
		end
		frame:AddDoubleLine(L["Multiplier:"], (CalculationResults.DmgM * 100) .. "%", rt, gt, bt, r, g, b )
		if CalculationResults.CritM then
			frame:AddDoubleLine(L["Crit Multiplier:"], CalculationResults.CritM .. "%", rt, gt, bt, r, g, b )
		end
	end

	if settings.DispCrit and CalculationResults.CritRate then
		frame:AddDoubleLine(L["Crit:"], CalculationResults.CritRate .. "%", rt, gt, bt, r, g, b )
	end

	if settings.DispHit and not baseSpell.Unresistable and not healingSpell then
		frame:AddDoubleLine(L["Hit:"], CalculationResults.HitRate .. "%", rt, gt, bt, r, g, b )
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor3
		r, g, b = c.r, c.g, c.b
	end

	if settings.AvgHit then
		frame:AddDoubleLine(L["Avg"] .. ":", CalculationResults.AvgHit .. " (".. CalculationResults.MinHit .."-".. CalculationResults.MaxHit ..")", rt, gt, bt, r, g, b )

		if CalculationResults.AvgLeech then
			frame:AddDoubleLine(L["Avg Heal:"], CalculationResults.AvgLeech, rt, gt, bt, r, g, b )
		end
	end

	if settings.AvgCrit and CalculationResults.AvgCrit > CalculationResults.AvgHit then
		frame:AddDoubleLine(L["Avg Crit:"], CalculationResults.AvgCrit .. " (".. CalculationResults.MinCrit .."-".. CalculationResults.MaxCrit ..")", rt, gt, bt, r, g, b )
	end

	if settings.Extra and CalculationResults.Extra then
		frame:AddDoubleLine(L["Avg"] .. " " .. (CalculationResults.ExtraName or L["Additional"]) .. ":", CalculationResults.Extra .. " (" .. CalculationResults.ExtraMin .."-".. CalculationResults.ExtraMax .. ")", rt, gt, bt, r, g, b)
	end

	if settings.Ticks and CalculationResults.Hits and CalculationResults.PerHit then
		frame:AddDoubleLine(L["Hits:"], CalculationResults.Hits .. "x ~" .. CalculationResults.PerHit, rt, gt, bt, r, g, b )

		if CalculationResults.PerCrit and CalculationResults.Crits > 0 then
			frame:AddDoubleLine(L["Crits:"], CalculationResults.Crits .. "x ~" .. CalculationResults.PerCrit, rt, gt, bt, r, g, b )
		end
		if CalculationResults.PerHitHeal then
			frame:AddDoubleLine(L["Hits Heal:"], CalculationResults.Hits .. "x ~" .. CalculationResults.PerHitHeal, rt, gt, bt, r, g, b )
		end
		if baseSpell.DotStacks then
			--L["Ticks"]
			frame:AddDoubleLine(L["Hits:"] .. " (x" .. baseSpell.DotStacks .. ")", CalculationResults.Hits .. "x ~" .. (CalculationResults.PerHit * baseSpell.DotStacks), rt, gt, bt, r, g, b )
			if CalculationResults.PerCrit and CalculationResults.Crits > 0	then	
				frame:AddDoubleLine(L["Crits:"] .. " (x" .. baseSpell.DotStacks .. ")", CalculationResults.Crits .. "x ~" .. (CalculationResults.PerCrit * baseSpell.DotStacks), rt, gt, bt, r, g, b )
			end
		end
		if CalculationResults.Ticks then
			frame:AddDoubleLine(L["Period:"], CalculationResults.Ticks .. "s", rt, gt, bt, r, g, b )
		end
		if CalculationResults.NextTick then
			local rating = math_ceil( CalculationResults.NextTick * self:GetRating("Haste", nil, true) )
			frame:AddDoubleLine(L["Haste for +1 Hit:"], rating, rt, gt, bt, r, g, b )
		end
	end

	if settings.Extra then
		if CalculationResults.DotDmg > 0 then
			frame:AddDoubleLine((healingSpell and L["Hot"] or L["Dot"]) .. ":", CalculationResults.DotDmg, rt, gt, bt, r, g, b )
		end
		if CalculationResults.AoE then
			if CalculationResults.PerTarget then
				frame:AddDoubleLine(L["AoE"] .. ":", CalculationResults.Targets .. "x ~" .. CalculationResults.PerTarget, rt, gt, bt, r, g, b )
			else
				frame:AddDoubleLine(L["AoE"] .. " (" .. CalculationResults.Targets .. "):", CalculationResults.AoE, rt, gt, bt, r, g, b )
			end
		end
		if CalculationResults.CustomText then
			frame:AddDoubleLine(CalculationResults.CustomText .. ":", CalculationResults.CustomTextValue, rt, gt, bt, r, g, b )
		end
		if CalculationResults.CustomText2 then
			frame:AddDoubleLine(CalculationResults.CustomText2 .. ":", CalculationResults.CustomTextValue2, rt, gt, bt, r, g, b )
		end
	end

	if settings.Total and CalculationResults.AvgTotal ~= CalculationResults.AvgHit then
		frame:AddDoubleLine(L["Avg Total"] .. ":", CalculationResults.AvgTotal, rt, gt, bt, r, g, b )
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor4
		r, g, b = c.r, c.g, c.b
	end

	if CalculationResults.Stats then
		local strA = CalculationResults.NextStr and (CalculationResults.NextStr > 0) and CalculationResults.Stats * 0.1 / CalculationResults.NextStr
		local agiA = CalculationResults.NextAgi and (CalculationResults.NextAgi > 0) and CalculationResults.Stats * 0.1 / CalculationResults.NextAgi
		local intA = CalculationResults.NextInt and (CalculationResults.NextInt > 0) and CalculationResults.Stats * 0.1 / CalculationResults.NextInt
		local apA = CalculationResults.NextAP and (CalculationResults.NextAP > 0) and CalculationResults.Stats * 0.1 / CalculationResults.NextAP
		local critA = CalculationResults.NextCrit and (CalculationResults.NextCrit > 0) and CalculationResults.Stats * 0.01 / CalculationResults.NextCrit * self:GetRating("Crit", nil, true )
		local hasA = CalculationResults.Haste and (self:GetRating("Haste",nil,true) + 0.01 * CalculationResults.Haste)
		local hitA = CalculationResults.NextHit and (CalculationResults.NextHit > 0.0) and CalculationResults.Stats * 0.01 / CalculationResults.NextHit * self:GetRating("Hit", nil, true)

		if settings.Next then
			if strA then frame:AddDoubleLine("+10 " .. L["Str"] .. ":", "+" .. DrD_Round(CalculationResults.NextStr, 2), rt, gt, bt, r, g, b) end
			if agiA then frame:AddDoubleLine("+10 " .. L["Agi"] .. ":", "+" .. DrD_Round(CalculationResults.NextAgi, 2), rt, gt, bt, r, g, b) end
			if intA then frame:AddDoubleLine("+10 " .. L["Int"] .. ":", "+" .. DrD_Round(CalculationResults.NextInt, 2), rt, gt, bt, r, g, b ) end
			if apA then frame:AddDoubleLine("+10 " .. L["AP"] .. ":", "+" .. DrD_Round(CalculationResults.NextAP, 2), rt, gt, bt, r, g, b ) end
			if critA then frame:AddDoubleLine("+1% " .. L["Crit"] .. " (" .. self:GetRating("Crit") .. "):", "+" .. DrD_Round(CalculationResults.NextCrit, 2), rt, gt, bt, r, g, b ) end
			if hitA then frame:AddDoubleLine("+1% " .. L["Hit"] .. " (" .. self:GetRating("Hit") .. "):", "+" .. DrD_Round(CalculationResults.NextHit, 2), rt, gt, bt, r, g, b ) end
		end
		if settings.CompareStats then
			local text, value
			local text2, value2
			if strA then
				text = L["Str"]
				value = DrD_Round(strA, 1)
			end
			if agiA then
				local agiA = DrD_Round(agiA,1)
				text = text and (text .. "|" .. L["Agi"]) or L["Agi"]
				value = value and (value .. "/" .. agiA) or agiA
			end
			if intA then
				local intA = DrD_Round(intA,1)
				text = text and (text .. "|" .. L["Int"]) or L["Int"]
				value = value and (value .. "/" .. intA) or intA
			end
			if apA then
				local apA = DrD_Round(apA,1)
				text = text and (text .. "|" .. L["AP"]) or L["AP"]
				value = value and (value .. "/" .. apA) or apA
			end
			if masA then
				local masA = DrD_Round(masA,1)
				text = text and (text .. "|" .. L["Ma"]) or L["Ma"]
				value = value and (value .. "/" .. masA) or masA
			end
			if critA then
				local critA = DrD_Round(critA,1)
				text2 = text2 and (text2 .. "|" .. L["Cr"]) or L["Cr"]
				value2 = value2 and (value2 .. "/" .. critA) or critA
			end
			if hitA then
				local hitA = DrD_Round(hitA, 1)
				text2 = text2 and (text2 .. "|" .. L["Ht"]) or L["Ht"]
				value2 = value2 and (value2 .. "/" .. hitA) or hitA
			end
			if hasA then
				local hasA = DrD_Round(hasA, 1)
				text2 = text2 and (text2 .. "|" .. L["Ha"]) or L["Ha"]
				value2 = value2 and (value2 .. "/" .. hasA) or hasA
			end
			if text then
				frame:AddDoubleLine("+1% " .. (baseSpell.NoNextDPS and L["Damage"] or (spellAbbr .. (CalculationResults.SpamDPS and L["PSC"] or L["PS"]))) .. " (" .. text .. "):", value, rt, gt, bt, r, g, b )
			end
			if text2 then
				frame:AddDoubleLine("+1% " .. (baseSpell.NoNextDPS and L["Damage"] or (spellAbbr .. (CalculationResults.SpamDPS and L["PSC"] or L["PS"]))) .. " (" .. text2 .. "):", value2, rt, gt, bt, r, g, b )
			end
		end
		if settings.CompareStr and strA then
			local text, value = self:CompareTooltip(strA, agiA, intA, apA, masA, critA, hitA, hasA, L["Str"], L["Agi"], L["Int"], L["AP"], L["Ma"], L["Cr"], L["Ht"], L["Ha"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareAgi and agiA then
			local text, value = self:CompareTooltip(agiA, strA, intA, apA, masA, critA, hitA, hasA, L["Agi"], L["Str"], L["Int"], L["AP"], L["Ma"], L["Cr"], L["Ht"], L["Ha"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareInt and intA then
			local text, value = self:CompareTooltip(intA, strA, agiA, apA, masA, critA, hitA, hasA, L["Int"], L["Str"], L["Agi"], L["AP"], L["Ma"], L["Cr"], L["Ht"], L["Ha"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareAP and apA then
			local text, value = self:CompareTooltip(apA, strA, agiA, intA, masA, critA, hitA, hasA, L["AP"], L["Str"], L["Agi"], L["Int"], L["Ma"], L["Cr"], L["Ht"], L["Ha"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareCrit and critA then
			local text, value = self:CompareTooltip(critA, strA, agiA, intA, apA, masA, hitA, hasA, L["Cr"], L["Str"], L["Agi"], L["Int"], L["AP"], L["Ma"], L["Ht"], L["Ha"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareHit and hitA then
			local text, value = self:CompareTooltip(hitA, strA, agiA, intA, apA, masA, critA, hasA, L["Ht"], L["Str"], L["Agi"], L["Int"], L["AP"], L["Ma"], L["Cr"], L["Ha"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareHaste and hasA then
			local text, value = self:CompareTooltip(hasA, strA, agiA, intA, apA, masA, critA, hitA, L["Ha"], L["Str"], L["Agi"], L["Int"], L["AP"], L["Ma"], L["Cr"], L["Ht"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor5
		r, g, b = c.r, c.g, c.b
	end

	if settings.DPS and not baseSpell.NoDPS then
		if CalculationResults.DPSC ~= CalculationResults.DPS then
			frame:AddDoubleLine(spellAbbr .. L["PS"] .. "/" .. spellAbbr .. L["PSC"] .. ":", CalculationResults.DPS .. ((CalculationResults.ExtraDPS and ("+" .. CalculationResults.ExtraDPS)) or "") .. "/" .. CalculationResults.DPSC, rt, gt, bt, r, g, b)
		else
			frame:AddDoubleLine(spellAbbr .. L["PS"] .. ":", CalculationResults.DPS .. ((CalculationResults.ExtraDPS and ("+" .. CalculationResults.ExtraDPS)) or "") , rt, gt, bt, r, g, b)
		end
		if CalculationResults.SpamDPS then
			frame:AddDoubleLine(spellAbbr .. L["PS (spam):"], CalculationResults.SpamDPS, rt, gt, bt, r, g, b)
		end
		if CalculationResults.DPSCD and CalculationResults.Cooldown then
			frame:AddDoubleLine(spellAbbr .. L["PS (CD):"], CalculationResults.DPSCD, rt, gt, bt, r, g, b)
		end
	end

	if settings.DPM and CalculationResults.DPM and not CalculationResults.NoCost and not baseSpell.NoDPM then
		frame:AddDoubleLine(spellAbbr .. (CalculationResults.RunicPower or L["PM:"]), CalculationResults.DPM, rt, gt, bt, r, g, b )
		if CalculationResults.SpamDPM and CalculationResults.SpamDPM ~= CalculationResults.DPM then
			frame:AddDoubleLine(spellAbbr .. L["PM (spam):"], CalculationResults.SpamDPM, rt, gt, bt, r, g, b )
		end
	end

	if settings.Doom and CalculationResults.DOOM and not baseSpell.NoDoom then
		frame:AddDoubleLine(spellAbbr .. L["OOM:"], CalculationResults.DOOM, rt, gt, bt, r, g, b )
	end

	if settings.Casts and CalculationResults.castsBase and not baseSpell.NoCasts then
		frame:AddDoubleLine(L["Casts"] .. ((CalculationResults.castsRegen > 0) and ("+" .. L["Regen"] .. ":") or ":"), CalculationResults.castsBase .. ((CalculationResults.castsRegen > 0 and ("+" .. CalculationResults.castsRegen)) or "") .. ((CalculationResults.SOOM and (" (" .. CalculationResults.SOOM .. "s)")) or ""), rt, gt, bt, r, g, b )
	end

	if settings.ManaUsage then
		if CalculationResults.TrueManaCost then
			frame:AddDoubleLine(L["True Mana Cost:"], CalculationResults.TrueManaCost, rt, gt, bt, r, g, b)
		end
		if CalculationResults.MPS and not CalculationResults.NoCost and not baseSpell.NoMPS then
			frame:AddDoubleLine(L["MPS"] .. ":", CalculationResults.MPS, rt, gt, bt, r, g, b)
		end
		if CalculationResults.GCD then
			frame:AddDoubleLine(L["GCD"] .. ":", CalculationResults.GCD .. "s", rt, gt, bt, r, g, b)
		end
	end

	if settings.Hints then
		if not settings.DefaultColor then
			local c = settings.TooltipTextColor6
			r, g, b = c.r, c.g, c.b
		end
		if spellInfo[name]["Secondary"] and not IsShiftKeyDown() then
			frame:AddLine(L["Hold Shift for secondary tooltip"], r, g, b)
		end
	end
	frame:Show()
end
