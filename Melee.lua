local _, playerClass = UnitClass("player")
if playerClass ~= "ROGUE" and playerClass ~= "WARRIOR" and playerClass ~= "HUNTER" and playerClass ~= "DRUID" and playerClass ~= "PALADIN" and playerClass ~= "SHAMAN" and playerClass ~= "DEATHKNIGHT" and playerClass ~= "MONK" then return end
local playerHybrid = (playerClass == "DRUID") or (playerClass == "PALADIN") or (playerClass == "SHAMAN") or (playerClass == "DEATHKNIGHT") or (playerClass == "MONK")

--Libraries
DrDamage = DrDamage or LibStub("AceAddon-3.0"):NewAddon("DrDamage","AceConsole-3.0", "AceEvent-3.0", "AceHook-3.0", "AceBucket-3.0", "AceTimer-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("DrDamage", true)
local GT = LibStub:GetLibrary("LibGratuity-3.0")
local DrDamage = DrDamage

--General
local settings
local type = type
local next = next
local pairs = pairs
local tonumber = tonumber
local math_abs = math.abs
local math_floor = math.floor
local math_ceil = math.ceil
local math_min = math.min
local math_max = math.max
local math_modf = math.modf
local string_match = string.match
local string_sub = string.sub
local string_gsub = string.gsub
local select = select

--Module
local GetSpellInfo = GetSpellInfo
local GetSpecialization = GetSpecialization
local GetCritChance = GetCritChance
local GetRangedCritChance = GetRangedCritChance
local GetCombatRating = GetCombatRating
local GetCombatRatingBonus = GetCombatRatingBonus
local GetItemInfo = GetItemInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetComboPoints = GetComboPoints
local GetExpertise = GetExpertise
local GetHitModifier = GetHitModifier
local GetSpellBonusDamage = GetSpellBonusDamage
local GetSpellCritChance = GetSpellCritChance
local GetAttackPowerForStat = GetAttackPowerForStat
local UnitRangedDamage = UnitRangedDamage
local UnitRangedAttack = UnitRangedAttack
local UnitRangedAttackPower = UnitRangedAttackPower
local UnitDamage = UnitDamage
local UnitAttackSpeed = UnitAttackSpeed
local UnitAttackPower = UnitAttackPower
local UnitIsPlayer = UnitIsPlayer
local UnitIsFriend = UnitIsFriend
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitName = UnitName
local UnitLevel = UnitLevel
local UnitGUID = UnitGUID
local UnitStat = UnitStat
local UnitCreatureType = UnitCreatureType
local OffhandHasWeapon = OffhandHasWeapon

--Module variables
local DrD_ClearTable, DrD_Round, DrD_DmgCalc, DrD_BuffCalc
local spellInfo, Calculation, PlayerAura, TargetAura, Consumables

function DrDamage:Melee_OnEnable()
	local ABOptions = self.options.args.General.args.Actionbar.args
	if settings.DisplayType_M then
		if not ABOptions.DisplayType_M.values[settings.DisplayType_M] then
			settings.DisplayType_M = "AvgTotal"
		end
	end
	if settings.DisplayType_M2 then
		if not ABOptions.DisplayType_M2.values[settings.DisplayType_M2] then
			settings.DisplayType_M2 = false
		end
	end

	self:Melee_InventoryChanged(true, true, true)
	if not self:GetWeaponType() then self:ScheduleTimer(function() self:Melee_InventoryChanged(true, true, true); self:UpdateAB() end, 10) end

	self.spellInfo[GetSpellInfo(6603)] = {
		["Name"] = "Attack",
		["ID"] = 6603,
		[0] = { AutoAttack = true, Melee = true, WeaponDamage = 1, NoNormalization = true, MeleeHaste = true },
		[1] = { 0 },
	}
	self:Melee_CheckBaseStats()
	DrD_ClearTable = self.ClearTable
	DrD_Round = self.Round
	DrD_BuffCalc = self.BuffCalc
	spellInfo = self.spellInfo
	PlayerAura = self.PlayerAura
	TargetAura = self.TargetAura
	Consumables = self.Consumables
	Calculation = self.Calculation
end

function DrDamage:Melee_RefreshConfig()
	settings = self.db.profile
end

local oldValues = 0
function DrDamage:Melee_CheckBaseStats()
	local newValues =
	--Melee hit rating
	GetCombatRating(6)
	+ self:GetAP()
	+ self:GetRAP()
	+ GetCritChance()
	+ GetRangedCritChance()
	+ GetHitModifier()
	+ UnitAttackSpeed("player")
	+ UnitDamage("player")
	+ select(3,UnitDamage("player"))
	+ UnitRangedDamage("player")
	+ select(2,UnitRangedDamage("player"))
	+ GetExpertise()

	if newValues ~= oldValues then
		oldValues = newValues
		return true
	end

	return false
end

local mhType, ohType--, rgType
function DrDamage:GetWeaponType()
	return mhType, ohType--, rgType
end

--local mhMin, mhMax, ohMin, ohMax, rgMin, rgMax = 0, 0, 0, 0, 0, 0
--local rgSpeed = 2.8
local mhMin, mhMax, ohMin, ohMax= 0, 0, 0, 0
local mhSpeed, ohSpeed = 2.4, 2.4

function DrDamage:Melee_InventoryChanged(mhslot, ohslot)--, rangedslot)
	if mhslot then
		local mh = GetInventoryItemLink("player", 16)
		if mh and GT:SetInventoryItem("player", 16) then
			for i = 3, GT:NumLines() do
				local line = GT:GetLine(i,true)
				line = line and string_match(line,"%d.%d+")
				if line then
					mhSpeed = tonumber((string_gsub(line,",","%.")))
					mhMin, mhMax = string_match(GT:GetLine(i), "(%d+)[^%d]+(%d+)")
					mhMin = tonumber(mhMin) or 0
					mhMax = tonumber(mhMax) or 0
					break
				end
			end
			mhType = select(7,GetItemInfo(mh))
		else
			mhType = nil
			mhMin, mhMax = 0, 0
			mhSpeed = UnitAttackSpeed("player")
		end
	end
	if ohslot then
		local oh = GetInventoryItemLink("player", 17)
		if oh and GT:SetInventoryItem("player", 17) then
			for i = 3, GT:NumLines() do
				local line = GT:GetLine(i,true)
				line = line and string_match(line,"%d.%d+")
				if line then
					ohSpeed = tonumber((string_gsub(line,",","%.")))
					ohMin, ohMax = string_match(GT:GetLine(i), "(%d+)[^%d]+(%d+)")
					ohMin = tonumber(ohMin) or 0
					ohMax = tonumber(ohMax) or 0
					break
				end
			end
			ohType = select(7,GetItemInfo(oh))
		else
			ohType = nil
			ohSpeed = 2.4
		end
	end
	--[[
	if rangedslot then
		local ranged = GetInventoryItemLink("player", 18)
		if ranged and GT:SetInventoryItem("player", 18) then
			for i = 3, GT:NumLines() do
				local line = GT:GetLine(i,true)
				line = line and string_match(line,"%d.%d+")
				if line then
					rgSpeed = tonumber((string_gsub(line,",","%.")))
					rgMin, rgMax = string_match(GT:GetLine(i), "(%d+)[^%d]+(%d+)")
					rgMin = tonumber(rgMin) or 0
					rgMax = tonumber(rgMax) or 0
					break
				end


			end
			rgType = select(7,GetItemInfo(ranged))
		else
			rgType = nil
			rgMin, rgMax = 0, 0
			rgSpeed = UnitRangedDamage("player")
		end
	end
	--]]
end

function DrDamage:GetMainhandBase()
	return mhMin, mhMax
end

function DrDamage:GetOffhandBase()
	return ohMin, ohMax
end

--[[
function DrDamage:GetRangedBase()
	return rgMin, rgMax
end
--]]

function DrDamage:GetWeaponSpeed()
	return mhSpeed, ohSpeed--, rgSpeed
end

function DrDamage:GetRAP()
	local baseAP, posBuff, negBuff = UnitRangedAttackPower("player")
	return baseAP + posBuff + negBuff
end

local normalizationTable = {
	--[[
	"Daggers"
	"One-Handed Axes"
	"One-Handed Maces"
	"One-Handed Swords"
	"Fist Weapons"
	"Two-Handed Axes"
	"Two-Handed Maces"
	"Two-Handed Swords"
	"Polearms"
	"Staves"
	"Fishing Poles"
	--]]
	[GetSpellInfo(1180)] = 1.7,
	[GetSpellInfo(196)] = 2.4,
	[GetSpellInfo(198)] = 2.4,
	[GetSpellInfo(201)] = 2.4,
	[GetSpellInfo(15590)] = 2.4,
	[GetSpellInfo(197)] = 3.3,
	[GetSpellInfo(199)] = 3.3,
	[GetSpellInfo(202)] = 3.3,
	[GetSpellInfo(200)] = 3.3,
	[GetSpellInfo(227)] = 3.3,
	[GetSpellInfo(7738)] = 3.3,
}
function DrDamage:GetNormM()
	return mhType and normalizationTable[mhType] or 2, ohType and normalizationTable[ohType] or 2
end

function DrDamage:WeaponDamage(calculation, wspd)
	local min, max, omin, omax, mod
	local normM, normM_O, bonus, obonus, baseAP

	if calculation.ranged then
		_, min, max, _, _, mod = UnitRangedDamage("player")
		normM = wspd and spd or 2.8
		baseAP = self:GetRAP()
	else
		min, max, omin, omax, _, _, mod = UnitDamage("player")
		baseAP = self:GetAP()
		if wspd or calculation.requiresForm then
			normM = mhSpeed
			normM_O = ohSpeed
		else
			normM, normM_O = self:GetNormM()
		end
	end
	--Main-hand calculation
	local mainhand = (normM / 14) * calculation.AP - (mhSpeed / 14) * baseAP
	bonus = normM / 14
	mod = calculation.wDmgM * mod --This is used to divide out possible bonuses included in the range returned by the API.
	min = min/mod + mainhand
	max = max/mod + mainhand
	--Off-hand calculation
	if calculation.offHand then
		local offhand = ((normM_O /14) * calculation.AP - (ohSpeed / 14) * baseAP) * calculation.offHdmgM
		obonus = normM_O / 14
		omin = omin/mod + offhand
		omax = omax/mod + offhand
	end
	return min, max, omin, omax, bonus, obonus
end

--Static values
local baseSpiM = (select(2,UnitRace("player")) == "Human") and 1.03 or 1
local troll = (select(2,UnitRace("player")) == "Troll")

--Static tables
local powerTypes = { [0] = L["DPM"], [1] = L["DPR"], [2] = L["DPF"], [3] = L["DPE"], [6] = L["DPRP"] }
local powerTypeNames = { [0] = L["Mana"], [1] = L["Rage"], [2] = L["Focus"], [3] = L["Energy"], [6] = L["Runic Power"] }
local schoolTable = { ["Holy"] = 2, ["Fire"] = 3, ["Nature"] = 4, ["Frost"] = 5, ["Shadow"] = 6, ["Arcane"] = 7 }
local mobArmor = {
	--Death Knight dummies
		--Initiate's Training Dummy (level 55)
		[32545] = 3230,
		--Disciple's Training Dummy (level 65)
		[32542] = 5210,
		--Veteran's Training Dummy (level 75)
		[32543] = 8250,
		--Ebon Knight's Training Dummy (level 80)
		[32546] = 9730,
	--Training Dummy (level 60)
	[39424] = 3750,
	--Training Dummy (level 70)
	[39680] = 6710,
	--Training Dummy (level 80)
	[43008] = 9690,
	--Training Dummy (level 85)
	--TODO: verify
	[14080] = 11100,
}

--Temporary tables
local calculation = {}
local ActiveAuras = {}
local playerAuraTable = {}
local targetAuraTable = {}
local Talents = {}
local CalculationResults = {}

function DrDamage:MeleeCalc( name, rank, tooltip, modify, debug )
	if not spellInfo or not name then return end

	local spellTable = spellInfo[name]
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

	calculation.melee = true
	calculation.name = name
	calculation.spellName = spellName
	calculation.tooltipName = textLeft
	calculation.tooltipName2 = textRight
	calculation.offHdmgM = 0.5
	calculation.bDmgM = 1
	calculation.bDmgM_O = 1
	calculation.wDmgM = 1
	calculation.dmgM_Add = 0
	calculation.dmgM_dd_Add = 0
	calculation.dmgM_dd = 1
	calculation.dmgM_Extra = 1
	calculation.dmgM_Extra_Add = 0
	calculation.dmgM_Magic = 1
	calculation.dmgM_Physical = 1
	calculation.mitigation = 1
	calculation.bleedBonus = 1
	calculation.finalMod = 0
	calculation.NoCrits = baseSpell.NoCrits
	calculation.eDuration = baseSpell.eDuration or 0
	--calculation.castTime = baseSpell.castTime or 0
	calculation.WeaponDamage = baseSpell.WeaponDamage
	calculation.DualAttack = baseSpell.DualAttack and 1
	calculation.cooldown = baseSpell.Cooldown or 0
	calculation.requiresForm = baseSpell.requiresForm
	calculation.hits = baseSpell.Hits
	calculation.aoe = baseSpell.AoE
	calculation.targets = settings.TargetAmount
	calculation.E_eDuration = baseSpell.E_eDuration
	calculation.E_canCrit = baseSpell.E_canCrit
	calculation.extra = spell.Extra or 0
	calculation.extraDamage = baseSpell.APBonus_extra
	calculation.extraDamageSP = baseSpell.SPBonus_extra
	calculation.extraChance = 1
	calculation.extraChance_O = 1
	calculation.expertise, calculation.expertise_O = GetExpertise()
	calculation.spd, calculation.ospd = UnitAttackSpeed("player")
	calculation.rspd =  UnitRangedDamage("player")
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
	calculation.freeCrit = 0
	calculation.hitPerc = 0
	calculation.spellCrit = 0
	calculation.spellHit = 0
	calculation.meleeCrit = 0
	calculation.meleeHit = 0
	calculation.armorM = 0
	calculation.APBonus = baseSpell.APBonus or 0
	calculation.SPBonus = baseSpell.SPBonus or 0
	calculation.APM = 1
	calculation.SPM = 1
	calculation.AP_mod = 0
	calculation.SP_mod = 0	
	calculation.SP = GetSpellBonusDamage(baseSpell.SP or 2)
	calculation.actionCost = select(4,GetSpellInfo(baseSpell.SpellCost or spellID or name)) or 0
	calculation.baseCost = calculation.actionCost
	calculation.powerType = select(6,GetSpellInfo(spellID or name)) or 4
	calculation.spec = GetSpecialization()
	--@debug@
	calculation.spec = debug or GetSpecialization()
	--@end-debug@

	--Determine levels used to calculate
	local playerLevel, targetLevel, boss = self:GetLevels()
	if settings.TargetLevel > 0 then
		targetLevel = playerLevel + settings.TargetLevel
	end
	calculation.playerLevel = playerLevel
	calculation.targetLevel = targetLevel

	if settings.ComboPoints == 0 then
		calculation.Melee_ComboPoints = GetComboPoints("player")
	else
		calculation.Melee_ComboPoints = settings.ComboPoints
	end

	if type( baseSpell.School ) == "table" then
		calculation.school = baseSpell.School[1]
		calculation.group = baseSpell.School[2]
		calculation.subType = baseSpell.School[3]
	else
		calculation.school = baseSpell.School or "Physical"
	end

	if calculation.group == "Ranged" then
		calculation.ranged = true
		calculation.AP = self:GetRAP()
		calculation.critPerc = GetRangedCritChance()
		calculation.critM = 1 --(baseSpell.SpellCrit or baseSpell.SpellCritM) and 1 or 1
		calculation.dmgM = baseSpell.NoGlobalMod and 1 or select(6,UnitRangedDamage("player"))
		calculation.haste = 1 + (GetCombatRatingBonus(19)/100)
		calculation.hasteRating = GetCombatRating(19)
	else
		calculation.ranged = false
		calculation.AP = self:GetAP()
		calculation.critPerc = baseSpell.SpellCrit and GetSpellCritChance(schoolTable[baseSpell.SpellCrit] or 1) or GetCritChance()
		calculation.critM = 1 --(baseSpell.SpellCrit or baseSpell.SpellCritM) and 1 or 1
		calculation.dmgM = baseSpell.NoGlobalMod and 1 or select(7,UnitDamage("player"))
		calculation.haste = 1 + (GetCombatRatingBonus(18)/100)
		calculation.hasteRating = GetCombatRating(18)
		calculation.offHand = OffhandHasWeapon() and (baseSpell.AutoAttack or baseSpell.DualAttack or baseSpell.OffhandAttack)
	end
	
	if troll and not UnitIsFriend("player","target") and not baseSpell.NoGlobalMod then
		local creature = UnitCreatureType("target")
		if creature and creature == L["Beast"] then
			calculation.dmgM = calculation.dmgM * 1.05
		end
	end

	--Checks
	calculation.physical = (calculation.school == "Physical")
	calculation.unarmed = (calculation.school == "Physical" and not calculation.ranged) and not mhType or baseSpell.requiresForm
	if baseSpell.Weapon and baseSpell.Weapon ~= mhType
	or baseSpell.Offhand and baseSpell.Offhand ~= ohType
	or baseSpell.OffhandAttack and not ohType
	or calculation.ranged and not mhType
	or calculation.unarmed and not baseSpell.AutoAttack and not baseSpell.NoWeapon and not baseSpell.requiresForm then
		calculation.zero = true
	end

	calculation.spd = calculation.spd * calculation.haste
	calculation.ospd = calculation.ospd and calculation.ospd * calculation.haste
	calculation.rspd = calculation.rspd and calculation.rspd * calculation.haste

	if baseSpell.SpellHit then
		calculation.hit = self:GetSpellHit(playerLevel, targetLevel)
	else
		calculation.hit, calculation.hitO = self:GetMeleeHit(playerLevel, targetLevel, calculation.ranged)
	end
	
	--CORE: CRIT DEPRESSION, GLANCING BLOWS, DODGE, PARRY
	if settings.TargetLevel > 0 or not UnitIsPlayer("target") then
		local deltaLevel = targetLevel - playerLevel
		calculation.critDepression = boss and 3 or (deltaLevel > 0) and deltaLevel
		if not baseSpell.Unavoidable and (not baseSpell.SpellHit or baseSpell.Avoidable) then
			if boss then
				calculation.dodge = 7.5 - (calculation.dodgeMod or 0)
				calculation.parry = 7.5 - (calculation.parryMod or 0)
			elseif deltaLevel >= 0 then
				--Dodge chance: 0 = 3%, +1 = 4.5%, +2 = 6%, +3 = 7.5%
				--Parry chance: 0 = 3%, +1 = 4.5%, +2 = 6%, +3 = 7.5%
				calculation.dodge = 3 + (deltaLevel * 1.5) - (calculation.dodgeMod or 0)
				calculation.parry = 3 + (deltaLevel * 1.5) - (calculation.parryMod or 0)
			end
			if baseSpell.AutoAttack or baseSpell.Glancing then
				if boss then
					calculation.glancing = 24
					calculation.glancingM = 0.75
				elseif deltaLevel >= 0 then
					calculation.glancing = (deltaLevel + 1) * 6
					calculation.glancingM = 1 - (deltaLevel + 1) * 0.0625
				end
			end
			if baseSpell.NoParry or calculation.ranged then
				calculation.parry = nil
			end
			if calculation.NoDodge then
				calculation.dodge = nil
			end
		end
	end	

	--CORE: Manual variables from profile:
	if settings.Custom then
		if settings.CustomAdd then
			calculation.str = settings.Str
			calculation.agi = settings.Agi
			calculation.int = settings.Int
			calculation.spi = settings.Spi
			calculation.SP_mod = settings.SP
			calculation.AP_mod = settings.AP
		else
			--Do not allow stats below 0
			calculation.str = math_max(0, settings.Str)
			calculation.agi = math_max(0, settings.Agi)
			calculation.int = math_max(0, settings.Int)
			calculation.spi = math_max(0, settings.Spi)
			calculation.customStats = true
			--Attack Power (Agility/Strength)
			--[[
			if calculation.ranged then
				calculation.AP = calculation.AP - UnitStat("player",2) * self:GetAgiToRAP()
				calculation.AP_mod = math_max(0, settings.AP)
			else
				local strToAP = GetAttackPowerForStat(1,UnitStat("player",1))
				local agiToAP = GetAttackPowerForStat(2,UnitStat("player",2))
				calculation.AP = calculation.AP - strToAP - agiToAP
				calculation.AP_mod = math_max(0, settings.AP)
			end
			--]]
			calculation.AP = 0
			calculation.AP_mod = math_max(0, settings.AP)
			--Crit chance (Agility/Intellect)
			if baseSpell.SpellCrit then
				calculation.critPerc = calculation.critPerc - self:GetCritChanceFromIntellect()
			else
				calculation.critPerc = calculation.critPerc - self:GetCritChanceFromAgility()
			end
			--Spell Power (Intellect)
			calculation.SP = 0 --calculation.SP - math_max(0,UnitStat("player",4)-10)
			calculation.SP_mod = math_max(0, settings.SP)
			--Ratings
			calculation.expertise = 0
			calculation.expertise_O = 0
			calculation.haste = 1 --calculation.haste - GetCombatRatingBonus(calculation.ranged and 19 or 18)/100
			calculation.hasteRating = 0 --calculation.hasteRating - GetCombatRating(calculation.ranged and 19 or 18)
			calculation.critPerc = calculation.critPerc - GetCombatRatingBonus((baseSpell.SpellCrit and 11 or 9))
			calculation.hitPerc = calculation.hitPerc - GetCombatRatingBonus((baseSpell.SpellHit and 8 or 6))
		end
		calculation.expertise = math_max(0, calculation.expertise + self:GetRating("Expertise", settings.ExpertiseRating, true))
		calculation.expertise_O = math_max(0, (calculation.expertise_O or 0) + self:GetRating("Expertise", settings.ExpertiseRating, true))
		calculation.haste = math_max(1,(calculation.haste + 0.01 * self:GetRating("Haste", settings.HasteRating, true)))
		calculation.hasteRating = math_max(0, calculation.hasteRating + settings.HasteRating)
		calculation.spellHit = self:GetRating("Hit", settings.HitRating, true)
		calculation.meleeHit = calculation.spellHit
		calculation.spellCrit = self:GetRating("Crit", settings.CritRating, true)
		calculation.meleeCrit = calculation.meleeCrit
	end

	calculation.minDam = spell[1]
	calculation.maxDam = (spell[2] or spell[1])	

	--TALENTS
	for i=1,#spellTalents do
		local talentValue = spellTalents[i]
		local modType = spellTalents["ModType" .. i]

		if calculation[modType] then
			if spellTalents["Multiply" .. i] then
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

	--BUFF/DEBUFF CALCULATION
	for index=1,40 do
		local buffName, rank, texture, apps = UnitBuff("player",index)
		if buffName then
			if spellPlayerAura[buffName] then
				DrD_BuffCalc( PlayerAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, "player" )
				playerAuraTable[buffName] = true
			end
		else break end
	end
	for index=1,40 do
		local buffName, rank, texture, apps = UnitDebuff("player",index)
		if buffName then
			if spellPlayerAura[buffName] then
				DrD_BuffCalc( PlayerAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, "player" )
				playerAuraTable[buffName] = true
			end
		else break end
	end
	for index=1,40 do
		local buffName, rank, texture, apps = UnitDebuff("target",index)
		if buffName then
			if spellTargetAura[buffName] then
				DrD_BuffCalc( TargetAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, "target" )
				targetAuraTable[buffName] = true
			end
		else break end
	end
	if next(settings["PlayerAura"]) or debug then
		for buffName in pairs(debug and spellPlayerAura or settings["PlayerAura"]) do
			if spellPlayerAura[buffName] and not playerAuraTable[buffName] then
				DrD_BuffCalc( PlayerAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName )
			end
		end
	end
	if next(settings["TargetAura"]) or debug then
		for buffName in pairs(debug and spellTargetAura or settings["TargetAura"]) do
			if spellTargetAura[buffName] and not targetAuraTable[buffName] then
				DrD_BuffCalc( TargetAura[buffName], calculation, ActiveAuras, Talents, baseSpell, buffName )
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

	--CORE: Sum up crit and hit
	if baseSpell.SpellCrit then
		calculation.critPerc = calculation.critPerc + calculation.spellCrit
	else
		calculation.critPerc = calculation.critPerc + calculation.meleeCrit
	end
	if baseSpell.SpellHit then
		calculation.hitPerc = calculation.hitPerc + calculation.spellHit
	else
		calculation.hitPerc = calculation.hitPerc + calculation.meleeHit
	end

	--Store global modifier
	calculation.dmgM_global = calculation.dmgM

	--Add magic damage buffs
	if schoolTable[calculation.school] then
		calculation.dmgM = calculation.dmgM * calculation.dmgM_Magic
		if not baseSpell.NoGlobalMod then
			calculation.dmgM = calculation.dmgM / calculation.dmgM_Physical
		end
	end

	--ADD CLASS SPECIFIC MODS
	if Calculation[playerClass] then
		Calculation[playerClass]( calculation, ActiveAuras, Talents, spell, baseSpell )
	end
	if Calculation[spellName] then
		Calculation[spellName]( calculation, ActiveAuras, Talents, spell, baseSpell )
	end

	--Calculate haste modifiers
	calculation.spd = calculation.spd / calculation.haste
	calculation.ospd = calculation.ospd and calculation.ospd / calculation.haste
	calculation.rspd = calculation.rspd and calculation.rspd / calculation.haste

	--CRIT MODIFIER CALCULATION (NEEDS TO BE DONE AFTER TALENTS)
	local baseCrit = 1 --(baseSpell.SpellCrit or baseSpell.SpellCritM) and 1 or 1
	local metaGem = (1 + baseCrit) * self.Damage_critMBonus * (1 + (calculation.critM - baseCrit) / baseCrit)
	calculation.critM = calculation.critM + metaGem

	--CORE: ARMOR
	if settings.ArmorCalc ~= "None" and (calculation.physical and not baseSpell.eDuration and not baseSpell.Bleed or baseSpell.Armor) and not baseSpell.NoArmor then
		local armor = 0
		if boss and (settings.ArmorCalc == "Auto") or (settings.ArmorCalc == "Boss") then
			armor = 24835
		elseif settings.ArmorCalc == "Auto" then
			--/print tonumber(string.sub(UnitGUID("target"),9,12),16)
			local GUID = not UnitIsPlayer("target") and UnitGUID("target")
			local targetID = GUID and tonumber(string_sub(GUID,9,12),16)
			armor = targetID and mobArmor[targetID] or (settings.Armor > 0) and settings.Armor or (settings.ArmorMitigation > 0) and self:GetArmor(settings.ArmorMitigation)
		elseif settings.ArmorCalc == "Manual" then
			armor = (settings.Armor > 0) and settings.Armor or (settings.ArmorMitigation > 0) and self:GetArmor(settings.ArmorMitigation)
		end
		if armor then
			calculation.armorM = math_min(1, calculation.armorM)
			--Apply armor debuffs (eg. Sunder Armor)
			armor = armor * (1 - calculation.armorM) -- + calculation.armorMod
			calculation.armorIgnore = calculation.armorM
			calculation.armor = armor
			calculation.mitigation = 1 - DrDamage:GetMitigation(calculation.armor)
		end
	end

	--CORE: Save damage modifier for tooltip display before mitigation modifiers
	calculation.dmgM_Display = calculation.dmgM * calculation.dmgM_dd * (1 + calculation.dmgM_Add + calculation.dmgM_dd_Add) * (baseSpell.Bleed and calculation.bleedBonus or 1)

	--CORE: RESILIENCE
	if settings.Resilience > 0 then
		calculation.dmgM = calculation.dmgM * math_min(1, 0.99 ^ (settings.Resilience / self:GetRating("PVPResilience")) - 0.4)
		if calculation.E_dmgM then
			calculation.E_dmgM = calculation.E_dmgM * math_min(1, 0.99 ^ (settings.Resilience / self:GetRating("PVPResilience"))- 0.4)
		end
		if calculation.extraWeaponDamage_dmgM then
			calculation.extraWeaponDamage_dmgM = calculation.extraWeaponDamage_dmgM * math_min(1, 0.99 ^ (settings.Resilience / self:GetRating("PVPResilience"))- 0.4)
		end
	end

	--AND NOW CALCULATE
	local avgTotal = DrD_DmgCalc( baseSpell, spell, false, false, tooltip )

	if tooltip and not calculation.zero and not baseSpell.NoNext then
		if settings.Next or settings.CompareStats or settings.CompareStr or settings.CompareAgi or settings.CompareInt or settings.CompareAP or settings.CompareCrit or settings.CompareHit or settings.CompareExp then
			local avgTotal = DrD_DmgCalc( baseSpell, spell, true )
			CalculationResults.Stats = avgTotal
			if calculation.APBonus > 0 or calculation.WeaponDamage then
				calculation.AP_mod = calculation.AP_mod + 10
				CalculationResults.NextAP = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.AP_mod = calculation.AP_mod - 10
			end
			if calculation.SPBonus > 0 then
				calculation.int = calculation.int + 10
				CalculationResults.NextInt = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.int = calculation.int - 10
			end
			calculation.agi = calculation.agi + 10
			CalculationResults.NextAgi = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
			calculation.agi = calculation.agi - 10
			if not calculation.ranged and GetAttackPowerForStat(1,100) > 0 then
				calculation.str = calculation.str + 10
				CalculationResults.NextStr = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
				calculation.str = calculation.str - 10
			end
			if not baseSpell.Unresistable then
				if calculation.dodge or calculation.parry then
					calculation.expertise = calculation.expertise + 1
					CalculationResults.NextExp = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
					calculation.expertise = calculation.expertise - 1
				end
				local temp = settings.HitCalc and avgTotal or DrD_DmgCalc( baseSpell, spell, true, true )
				calculation.hitPerc = calculation.hitPerc + 1
				CalculationResults.NextHit = DrD_DmgCalc( baseSpell, spell, true, true ) - temp
				calculation.hitPerc = calculation.hitPerc - 1
			end
			if not calculation.NoCrits then
				calculation.critPerc = calculation.critPerc + 1
				if calculation.E_critPerc then calculation.E_critPerc = calculation.E_critPerc + 1 end
				if calculation.E_critPerc_O then calculation.E_critPerc_O = calculation.E_critPerc_O + 1 end
				if calculation.extra_critPerc then calculation.extra_critPerc = calculation.extra_critPerc + 1 end
				CalculationResults.NextCrit = DrD_DmgCalc( baseSpell, spell, true ) - avgTotal
			end
		end
	end

	DrD_ClearTable( Talents )
	DrD_ClearTable( ActiveAuras )
	DrD_ClearTable( playerAuraTable )
	DrD_ClearTable( targetAuraTable )

	return settings.DisplayType_M and CalculationResults[settings.DisplayType_M], settings.DisplayType_M2 and CalculationResults[settings.DisplayType_M2], CalculationResults, calculation, debug and ActiveAuras
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
	calculation.customStats = false
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

	--CORE: Initialize variables
	local dmgM_Extra = calculation.dmgM_Extra * calculation.dmgM * (1 + calculation.dmgM_Add + calculation.dmgM_Extra_Add) * (not calculation.extraCrit and (baseSpell.BleedExtra and calculation.bleedBonus or 1) or 1)
	local dmgM = calculation.dmgM * calculation.dmgM_dd * (1 + calculation.dmgM_Add + calculation.dmgM_dd_Add) * (baseSpell.Bleed and calculation.bleedBonus or 1)
	calculation.AP = calculation.AP + calculation.AP_mod
	calculation.SP = calculation.SP + calculation.SP_mod
	calculation.AP_mod = 0
	calculation.SP_mod = 0
	local AP = math_max(0, calculation.AP)
	local SP = math_max(0, calculation.SP)
	local APmod, APoh = 0
	local minDam, maxDam = calculation.minDam * calculation.bDmgM, calculation.maxDam * calculation.bDmgM
	local minDam_O, maxDam_O
	local minCrit, maxCrit
	local minCrit_O, maxCrit_O
	local avgHit, avgHit_O
	local avgCrit,avgCrit_O
	local avgTotal
	local avgTotal_O = 0
	local eDuration = calculation.eDuration
	local baseDuration = baseSpell.eDuration
	local hits = calculation.hits
	local perHit, ticks
	local hitPenaltyAvg, aoe, aoeO

	--CORE: Sum up hit chance
	local hit, hitO = calculation.hit + calculation.hitPerc, (calculation.hitO or calculation.hit) + calculation.hitPerc
	local hitPerc = hit
	local hitPerc_O = hitO
	local hitDW = baseSpell.AutoAttack and calculation.offHand and (hit - 19)
	local hitDWO = hitDW and (hitO - 19)

	--CORE: Minimum hit: 0%, Maximum hit: 100%
	if hitPerc > 100 then hitPerc = 100 elseif hitPerc < 0 then hitPerc = 0 end
	if hitPerc_O > 100 then hitPerc_O = 100 elseif hitPerc_O < 0 then hitPerc_O = 0 end
	if hitDW then
		if hitDW > 100 then hitDW = 100 elseif hitDW < 0 then hitDW = 0 end
		if hitDWO > 100 then hitDWO = 100 elseif hitDWO < 0 then hitDWO = 0 end
	end

	--CORE: Critical hit chance & Calculate crit cap (103% - miss - glancing - dodge rate - parry rate)
	local critCap = 100 + (settings.CritDepression and calculation.critDepression or 0) - (100 - (hitDW or hitPerc)) - (calculation.glancing or 0)
	local critPerc = calculation.critPerc
	local dodge, parry
	if calculation.dodge then
		dodge = calculation.dodge - calculation.expertise 
		if dodge < 0 then dodge = 0 end
		critCap = critCap - dodge
	end
	if calculation.parry and settings.Parry then
		parry = calculation.parry - math_max(0,calculation.expertise - calculation.dodge)
		if parry < 0 then parry = 0 end
		critCap = critCap - parry
	end
	if critCap < 0 then critCap = 0 end
	if critPerc > critCap then
		critPerc = critCap
		if baseSpell.AutoAttack then calculation.critCapNote = true end
	end
	if settings.CritDepression and calculation.critDepression then
		critPerc = critPerc - calculation.critDepression
	end
	if critPerc > 100 then
		critPerc = 100
	elseif critPerc < 0 then
		critPerc = 0
	end

	--CORE: Weapon Damage multiplier
	if calculation.WeaponDamage then
		local min, max
		min, max, minDam_O, maxDam_O, APmod, APoh = DrDamage:WeaponDamage(calculation, baseSpell.NoNormalization)
		minDam = minDam + min * calculation.WeaponDamage
		maxDam = maxDam + max * calculation.WeaponDamage
		--CORE: Off-hand attacks
		if calculation.offHand then
			--if calculation.ExtraMain then
			--	local min, max = DrDamage:WeaponDamage(calculation, baseSpell.NoNormalization)
			--	minDam_O = calculation.offHdmgM * (min * calculation.WeaponDamage + calculation.minDam * calculation.bDmgM)
			--	maxDam_O = calculation.offHdmgM * (max * calculation.WeaponDamage + calculation.maxDam * calculation.bDmgM)
			--elseif baseSpell.AutoAttack or calculation.DualAttack then
			if baseSpell.AutoAttack or calculation.DualAttack then
				minDam_O = minDam_O * calculation.WeaponDamage + calculation.minDam * calculation.bDmgM * calculation.bDmgM_O * (calculation.DualAttack or 1)
				maxDam_O = maxDam_O * calculation.WeaponDamage + calculation.maxDam * calculation.bDmgM * calculation.bDmgM_O * (calculation.DualAttack or 1)
				APmod = APmod + (APoh or 0)
			elseif baseSpell.OffhandAttack then
				minDam = minDam_O * calculation.WeaponDamage + calculation.minDam * calculation.bDmgM
				maxDam = maxDam_O * calculation.WeaponDamage + calculation.maxDam * calculation.bDmgM
				minDam_O = nil
				maxDam_O = nil
				APmod = (APoh or 0)
			end
		end
	end
	--CORE: Combo point calculation
	if baseSpell.ComboPoints then
		local cp = calculation.Melee_ComboPoints
		if cp > 0 then
			if spell.PerCombo then
				minDam = minDam + spell.PerCombo * cp
				maxDam = maxDam + spell.PerCombo * cp
				if baseSpell.TicksPerCombo then
					local nticks = baseSpell.TicksPerCombo * (cp - 1)
					minDam = (baseSpell.DotHits + nticks) * minDam
					maxDam = (baseSpell.DotHits + nticks) * maxDam
					eDuration = eDuration + baseSpell.Ticks * nticks
					baseDuration = baseDuration + baseSpell.Ticks * nticks
					--APmod = APmod + (calculation.APBonus / baseSpell.DotHits) * nticks
				end
			end
			if calculation.APBonus > 0 then
				minDam = minDam + calculation.APBonus * cp * AP
				maxDam = maxDam + calculation.APBonus * cp * AP
				APmod = APmod + calculation.APBonus * cp
			end
		else
			calculation.zero = true
		end
	else
	--CORE: AP and SP modifier for non-combo point abilities
		if calculation.APBonus > 0 then
			minDam = minDam + calculation.APBonus * AP
			maxDam = maxDam + calculation.APBonus * AP
			APmod = APmod + calculation.APBonus
		end
		if calculation.SPBonus > 0 then
			minDam = minDam + calculation.SPBonus * SP
			maxDam = maxDam + calculation.SPBonus * SP
		end
	end

	--CORE: Calculate final min-max range
	local modDuration = baseDuration and eDuration > baseDuration and (1 + (eDuration - baseDuration) / baseDuration) or 1
	minDam = dmgM * calculation.mitigation * minDam * modDuration + (baseDuration and 0 or calculation.finalMod * calculation.mitigation)
	maxDam = dmgM * calculation.mitigation * maxDam * modDuration + (baseDuration and 0 or calculation.finalMod * calculation.mitigation)
	if nextCalc then
		minDam = (baseSpell.eDot and hits or 1) * minDam
		maxDam = (baseSpell.eDot and hits or 1) * maxDam
	else
		minDam = (baseSpell.eDot and hits or 1) * math_floor(minDam)
		maxDam = (baseSpell.eDot and hits or 1) * math_ceil(maxDam)
	end

	--CORE: Show zero for not available abilities
	if calculation.zero then
		minDam = 0
		maxDam = 0
	end

	--CORE: Sum min and max to averages
	avgHit = (minDam + maxDam) / 2

	--CORE: Crit calculation
	local critBonus = 0
	local critBonus_O = 0
	if not calculation.NoCrits then
		minCrit = minDam + minDam * calculation.critM
		maxCrit = maxDam + maxDam * calculation.critM
		avgCrit = (minCrit + maxCrit) / 2
		critBonus = (critPerc / 100) * avgHit * calculation.critM
		avgTotal = avgHit + critBonus
	else
		avgCrit = avgHit
		avgTotal = avgHit
	end

	--CORE: Crit calculation for off-hand and dual attack
	if calculation.offHand and not baseSpell.OffhandAttack then
		minDam_O = dmgM * calculation.mitigation * minDam_O + calculation.finalMod * calculation.bDmgM_O
		maxDam_O = dmgM * calculation.mitigation * maxDam_O + calculation.finalMod * calculation.bDmgM_O
		avgHit_O = (minDam_O + maxDam_O)/2
		if not calculation.NoCrits then
			minCrit_O = minDam_O + minDam_O * calculation.critM
			maxCrit_O = maxDam_O + maxDam_O * calculation.critM
			avgCrit_O = (minCrit_O + maxCrit_O) / 2
			critBonus_O = (critPerc / 100) * avgHit_O * calculation.critM * (calculation.OffhandChance or 1)
			avgTotal_O = avgHit_O * (calculation.OffhandChance or 1) + critBonus_O
		else
			avgTotal_O = avgHit_O * (calculation.OffhandChance or 1)
		end
	end

	local extraDam, extraAvg, extraMin, extraMax, extraAvgM, extraAvgO
	local perTarget, targets
	if not calculation.zero then
		--CORE: Extra damage effect calculation
		if calculation.extraDamage then
			local extra = 0
			local extra_O = 0
			local extraDam_O = 0
			local extraAvgTotal = 0
			local extraAvgTotal_O = 0
			local critBonus_Extra = 0
			local critBonus_Extra_O = 0
			extraMin = 0
			extraMax = 0
			--Extra effect chance is based on crit chance
			if calculation.extraChanceCrit then
				calculation.extraChance = critPerc / 100
			end
			--if calculation.extraAvgChanceCrit then
			--	calculation.extraAvgChance = critPerc / 100
			--end
			if calculation.extraWeaponDamageChanceCrit then
				calculation.extraWeaponDamageChance = critPerc / 100
			end
			--Extra effect is derived from crit value (eg. Righteous Vengeance)
			if calculation.extraCrit then
				local value = calculation.extraCrit * (baseSpell.BleedExtra and calculation.bleedBonus or 1)
				extra = avgCrit * value
				extraMin = minCrit * value
				extraMax = maxCrit * value
				extraAvgTotal = extra * (calculation.extraCritChance or calculation.extraChance)
			end
			--Extra effect is derived from avg value
			--Main-hand (eg. Necrosis)
			if calculation.extraAvg then
				local value = calculation.extraAvg * dmgM_Extra / (dmgM * (calculation.extraAvgM and 1 or calculation.mitigation))
				extra = extra + avgTotal * value
				extraMin = extraMin + minDam * value
				extraMax = extraMax + (maxCrit or maxDam) * value
				extraAvgTotal = extraAvgTotal + avgTotal * value * (calculation.extraAvgChance or calculation.extraChance)
			end
			--Off-hand (eg. Necrosis)
			if calculation.extraAvg_O then
				local value = calculation.extraAvg_O * dmgM_Extra / (dmgM * (calculation.extraAvgM and 1 or calculation.mitigation))
				extra_O  = avgTotal_O * value
				extraMin = extraMin + minDam_O * value
				extraMax = extraMax + (maxCrit_O or maxDam_O) * value
				extraAvgTotal_O = extra_O * (calculation.extraAvgChance or calculation.extraChance)
			end
			--Extra effect is a multiplier of weapon damage
			--Main-hand (eg. Blood-Caked Blade, Deep Wounds)
			if calculation.extraWeaponDamage then
				local min, max  = DrDamage:WeaponDamage(calculation, not calculation.extraWeaponDamageNorm)
				local value = calculation.extraWeaponDamage * (calculation.extraWeaponDamage_dmgM or dmgM_Extra) * (calculation.extraWeaponDamageM and calculation.mitigation or 1)
				local bonus =  0.5 * (min + max) * value
				extra = extra + bonus
				extraMin = extraMin + min * value
				extraMax = extraMax + max * value
				extraAvgTotal = extraAvgTotal + bonus * (calculation.extraWeaponDamageChance or calculation.extraChance)
			end
			--Off-hand (eg. Blood-Caked Blade, Deep Wounds)
			if calculation.extraWeaponDamage_O then
				local _, _, min, max  = DrDamage:WeaponDamage(calculation, not calculation.extraWeaponDamageNorm)
				local value = calculation.extraWeaponDamage_O * (calculation.extraWeaponDamage_dmgM or dmgM_Extra) * (calculation.extraWeaponDamageM and calculation.mitigation or 1)
				local bonus =  0.5 * (min + max)
				extra_O = extra_O + bonus
				extraMin = extraMin + min * value
				extraMax = extraMax + max * value
				extraAvgTotal_O = extraAvgTotal_O + bonus * (calculation.extraWeaponDamageChance or calculation.extraChance)
			end
			--Extra damage chance on ticks (Venomous Wounds)
			if calculation.extraTickDamage then
				local value = calculation.extraTickDamage + calculation.extraTickDamageBonus * AP
				local ticks = math_floor( eDuration / baseSpell.Ticks + 0.5)
				extra = extra + value
				extraMin = extraMin + value
				extraMax = extraMax + value
				extraAvgTotal = extraAvgTotal + value * ticks * calculation.extraTickDamageChance
				if calculation.extraTickDamageCost then
					calculation.actionCost = calculation.actionCost - ticks * calculation.extraTickDamageChance * calculation.extraTickDamageCost
				end
			end
			--Module effect can crit
			if calculation.extra_canCrit then
				if calculation.extra_critPerc then
					if calculation.extra_critPerc > 100 then calculation.extra_critPerc = 100
					elseif calculation.extra_critPerc < 0 then calculation.extra_critPerc = 0 end
				end
				critBonus_Extra = extra * ((calculation.extra_critPerc or critPerc) / 100) * (calculation.extra_critM or calculation.critM)
				critBonus_Extra_O = extra_O * ((calculation.extra_critPerc or critPerc) /100) * (calculation.extra_critM or calculation.critM)
				extraMax = extraMax * (1 + (calculation.extra_critM or calculation.critM))
			end
			--Main-hand extra damage effect from modules
			extraDam = (baseSpell.Hits_extra or 1) * math_ceil((calculation.extra + calculation.extraDamage * AP + (calculation.extraDamageSP or 0) * SP) * (calculation.E_dmgM or dmgM_Extra) * (calculation.extraM and calculation.mitigation or 1) + (calculation.extraDamBonus or 0))
			--Off-hand extra damage effect from modules (Poisons, Flametongue, Frostbrand)
			extraDam_O = (baseSpell.Hits_extra or 1) * math_ceil(((calculation.extra_O or 0) + (calculation.extraDamage_O or 0) * AP + (calculation.extraDamageSP_O or 0) * SP) * (calculation.E_dmgM or dmgM_Extra) * (calculation.extraM and calculation.mitigation or 1) + (calculation.extraDamBonus_O or 0))
			--Extended duration for extra damage effect
			if calculation.E_eDuration and baseSpell.E_eDuration and calculation.E_eDuration > baseSpell.E_eDuration then
				local modDuration = 1 + (calculation.E_eDuration - baseSpell.E_eDuration) / baseSpell.E_eDuration
				extraDam = extraDam * modDuration
			end
			--Extra effect can crit
			if calculation.E_canCrit then
				if calculation.E_critPerc then
					if calculation.E_critPerc > 100 then calculation.E_critPerc = 100
					elseif calculation.E_critPerc < 0 then calculation.E_critPerc = 0 end
				end
				if calculation.E_critPerc_O then
					if calculation.E_critPerc_O > 100 then calculation.E_critPerc_O = 100
					elseif calculation.E_critPerc_O < 0 then calculation.E_critPerc_O = 0 end
				end
				critBonus_Extra = critBonus_Extra + extraDam * ((calculation.E_critPerc or critPerc) / 100) * (calculation.E_critM or calculation.critM) * calculation.extraChance
				critBonus_Extra_O = critBonus_Extra_O + extraDam_O * ((calculation.E_critPerc_O or critPerc) / 100) * (calculation.E_critM or calculation.critM) * calculation.extraChance_O
				extraMax = extraMax + (extraDam + extraDam_O) * (1 + (calculation.E_critM or calculation.critM))
			else
				extraMax = extraMax + extraDam + extraDam_O
			end
			--Adds extra effect to minimum damage
			extraMin = extraMin + extraDam + extraDam_O
			--Sums up main-hand average extra effect
			extraAvgM = extraDam * calculation.extraChance + extraAvgTotal + critBonus_Extra
			--Sums up main-hand average for DPS calculation
			avgTotal = avgTotal + extraAvgM
			--Sums up off-hand average extra effect
			extraAvgO = extraDam_O * calculation.extraChance_O + extraAvgTotal_O + critBonus_Extra_O
			--Sums up off-hand average for DPS calculation
			avgTotal_O = avgTotal_O + extraAvgO
			--Sums the average extra effect
			extraAvg = extraAvgM + extraAvgO
			--The amount of damage done on combined successful procs, non-crit
			extraDam = extraDam + extraDam_O + extra + extra_O
			--AP bonus from extra module
			APmod = APmod + calculation.extraDamage + (calculation.extraDamage_O or 0)
		end
		--CORE: Per hit/tick calculation
		if baseSpell.eDuration and baseSpell.Ticks then
			ticks = math_floor(eDuration / baseSpell.Ticks + 0.5)
			perHit = avgHit / ticks
		elseif hits then
			perHit = avgTotal + avgTotal_O
		elseif extraDam and baseSpell.E_eDuration and baseSpell.E_Ticks then
			ticks = math_floor(calculation.E_eDuration / baseSpell.E_Ticks + 0.5)
			perHit = extraDam / ticks
		elseif extraDam and calculation.extraTicks then
			ticks = calculation.extraTicks
			perHit = extraDam / ticks
		end

		--CORE: Hit calculation
		if not baseSpell.Unresistable then
			local hit, hitO = 100, 100
			local avoidance, avoidanceO = 0, 0
			local calc
			if settings.HitCalc or hitCalc then
				hit = hitDW or hitPerc
				hitO = hitDWO or hitPerc_O
				calc = true
			end
			if settings.Parry and parry then
				avoidance = parry
				avoidanceO = parry
				calc = true
			end
			if settings.Dodge and dodge then
				avoidance = avoidance + dodge
				avoidanceO = avoidanceO + dodge
				calc = true
			end
			if settings.Glancing and calculation.glancing then
				avoidance = avoidance + calculation.glancing * calculation.glancingM
				avoidanceO = avoidanceO + calculation.glancing * calculation.glancingM
				calc = true
			end
			if calc then
				local tworoll = settings.TwoRoll_M and not baseSpell.AutoAttack and not baseSpell.AutoShot or baseSpell.SpellHit and settings.TwoRoll
				avoidance = avoidance / 100
				avoidanceO = avoidanceO / 100

				avgTotal = math_max(0, avgTotal - (avgTotal - critBonus) * avoidance - (avgTotal - (tworoll and 0 or critBonus)) * (1 - 0.01 * hit))
				hitPenaltyAvg = avgHit * avoidance + (avgHit + (tworoll and critBonus or 0)) * (1 - 0.01 * hit)

				if avgTotal_O > 0 then
					avgTotal_O = math_max(0, avgTotal_O - (avgTotal_O - critBonus_O) * avoidanceO - (avgTotal_O - (tworoll and 0 or critBonus_O)) * (1 - 0.01 * hitO))
				end
			end
		end

		--CORE: Multiple hit calculation
		if hits and not ticks then
			avgTotal = avgTotal + (hits - 1) * avgTotal
			if calculation.DualAttack then
				avgTotal_O = avgTotal_O + (hits - 1) * avgTotal_O
			end
			--Not needed currently
			--if avgTotalMod then
			--	avgTotalMod = avgTotalMod + (hits - 1) * avgTotal
			--end
		end
		if (calculation.aoe or baseSpell.E_AoE) and calculation.targets > 1 then
			targets = (type(calculation.aoe) == "number") and math_min(calculation.targets, calculation.aoe) or calculation.targets
			if baseSpell.E_AoE and not calculation.aoe then
				perTarget = extraAvg
				aoe = (targets - 1) * perTarget
			elseif baseSpell.ChainFactor then
				local chain = baseSpell.ChainFactor
				aoe = avgTotal * (chain + (targets >= 3 and chain^2 or 0))
			elseif baseSpell.MixedAoE then
				local aoeM = calculation.aoeM or 1
				perTarget = (avgTotal - extraAvg) * aoeM + extraAvg
				aoe = (targets - 1) * perTarget
				if aoeM < 1 then
					targets = targets - 1
				end
			elseif calculation.NoExtraAoE then
				local aoeM = calculation.aoeM or 1
				perTarget = (avgTotal + avgTotal_O - extraAvg) * aoeM
				aoe = (targets - 1) * (avgTotal - extraAvgM) * aoeM
				aoeO = (targets - 1) * (avgTotal_O - extraAvgO) * aoeM
				if aoeM < 1 then
					targets = targets - 1
				end
			else
				local aoeM = calculation.aoeM or 1
				perTarget = (avgTotal + avgTotal_O) * aoeM
				aoe = (targets - 1) * avgTotal * aoeM
				aoeO = (targets - 1) * avgTotal_O * aoeM
				if aoeM < 1 then
					targets = targets - 1
				end
			end
			avgTotal = avgTotal + aoe
			avgTotal_O = avgTotal_O + (aoeO or 0)
			--TODO: Do we want this?
			--if baseSpell.E_AoE and ticks then
			--	ticks = ticks * targets
			--end
		end

		--CORE: Windfury calculation
		if calculation.WindfuryBonus then
			local min, max = DrDamage:WeaponDamage(calculation, true)
			local bspd = DrDamage:GetWeaponSpeed()
			local value = dmgM * calculation.mitigation * (calculation.WindfuryDmgM or 1) * 3
			local bonus = bspd * calculation.WindfuryBonus / 14
			local avgWf = (0.5 * (min+max) + bonus) * value
			local avgTotalWf =  avgWf * (1 + calculation.critM * critPerc / 100) * (hitPerc / 100) * calculation.WindfuryChance * ((hitDW or hitPerc) / 100)
			extraDam = (extraDam or 0) + avgWf
			extraAvg = (extraAvg or 0) + avgTotalWf
			extraMin = (extraMin or 0) + (min + bonus) * value
			extraMax = (extraMax or 0) + (max + bonus) * value * (1 + calculation.critM)
			avgTotal = avgTotal + avgTotalWf
		end
		if calculation.WindfuryBonus_O then
			local _, _, min, max = DrDamage:WeaponDamage(calculation, true)
			local _, bspd = DrDamage:GetWeaponSpeed()
			local value = dmgM * calculation.mitigation * (calculation.WindfuryDmgM or 1) * 3
			local bonus = bspd * calculation.WindfuryBonus_O / 14
			local avgWf_O = (0.5 * (min+max) + bonus) * value
			local avgTotalWf_O = avgWf_O * (1 + calculation.critM * critPerc / 100) * (hitPerc_O / 100) * calculation.WindfuryChance * ((hitDWO or hitPerc_O) / 100)
			extraDam = (extraDam or 0) + avgWf_O
			extraAvg = (extraAvg or 0) + avgTotalWf_O
			extraMin = (extraMin or 0) + (min + bonus) * value
			extraMax = (extraMax or 0) + (max + bonus) * (1 + calculation.critM)
			avgTotal_O = avgTotal_O + avgTotalWf_O
		end
	else
		avgTotal = 0
		avgTotal_O = 0
	end

	local avgCombined = avgTotal + avgTotal_O

	if nextCalc then
		return avgCombined
	else
		--CORE: DPS calculation
		local DPS, DPSCD
		if calculation.customDPS then
			DPS = calculation.customDPS
		elseif baseSpell.AutoAttack or baseSpell.WeaponDPS then
			if hits then DPS = (avgTotal / hits) / calculation.spd
			else DPS = avgTotal / calculation.spd end

			if calculation.ospd then
				DPS = DPS + avgTotal_O / calculation.ospd
			end
		elseif baseSpell.DPSrg then
			DPS = avgTotal / calculation.rspd
		else
			if baseSpell.Channeled then
				DPS = avgCombined / (baseSpell.Channeled / math_max(1,calculation.haste))
			elseif eDuration > 0 then
				if calculation.customHaste then
					eDuration = eDuration / math_max(1,calculation.haste)
				end
				DPS = avgCombined / eDuration
			elseif extraDam and calculation.E_eDuration then
				if calculation.WeaponDPS then
					DPS = (avgCombined - extraAvg) / calculation.spd + extraAvg / calculation.E_eDuration
				else
					DPS = avgCombined / calculation.E_eDuration
				end
			end
			if calculation.cooldown > 0 then
				DPSCD = DrD_Round(avgCombined / calculation.cooldown,1)
			end
			--if calculation.castTime then
			--	DPS = avgCombined / calculation.castTime
			--end
		end
		local extraDPS
		if calculation.extra_DPS and DPS then
			extraDPS = (calculation.E_dmgM or dmgM) * (calculation.extraStacks_DPS or 1) * (calculation.extra_DPS + calculation.extraDamage_DPS * AP) / calculation.extraDuration_DPS
			if calculation.extra_DPS_canCrit then
				extraDPS = extraDPS * (1 + 0.01 * (calculation.E_critPerc or critPerc) * (calculation.E_critM or calculation.critM))		
			end
			DPS = DPS + extraDPS
		end
		--if calculation.procPerc then
		--	DPS = DPS * calculation.procPerc
		--end

		DrD_ClearTable( CalculationResults )

		CalculationResults.Avg =			math_floor(math_max(0, avgHit - (hitPenaltyAvg or 0) + critBonus + 0.5))
		CalculationResults.AvgHit = 		math_floor(avgHit + 0.5)
		CalculationResults.AvgHitTotal = 	math_floor(avgHit + (extraDam or 0) + 0.5)
		CalculationResults.AvgTotal = 		math_floor(avgTotal + avgTotal_O + 0.5)
		CalculationResults.MinHit = 		math_floor(minDam)
		CalculationResults.MaxHit = 		math_ceil(maxDam)
		CalculationResults.MaxTotal = 		math_ceil((maxCrit or maxDam) + (maxCrit_O or maxDam_O or 0) + (extraMax or 0) + (aoe or 0) + (aoeO or 0))
		
		if not calculation.NoCrits and not calculation.hits then
			CalculationResults.MinCrit = 	math_floor(minCrit)
			CalculationResults.MaxCrit = 	math_ceil(maxCrit)
			CalculationResults.AvgCrit = 	math_floor(avgCrit + 0.5)
		else
			CalculationResults.MinCrit = 	CalculationResults.MinHit
			CalculationResults.MaxCrit = 	CalculationResults.MaxHit
			CalculationResults.AvgCrit =	CalculationResults.AvgHit
		end
		if DPS then
			CalculationResults.DPS = DrD_Round(DPS,1)
			if eDuration > 0 then
				CalculationResults.DPS_Duration = DrD_Round(eDuration, 2)
			elseif calculation.E_eDuration then
				CalculationResults.DPS_Duration = DrD_Round(calculation.E_eDuration, 2)
			end
		end
		if DPSCD then
			CalculationResults.DPSCD = DPSCD
		end

		if tooltip or settings.DisplayType_M == "DPM" or settings.DisplayType_M2 == "DPM" or settings.DisplayType_M2 == "PowerCost" then
			if powerTypes[calculation.powerType] and calculation.actionCost > 0 then
				CalculationResults.PowerType = powerTypes[calculation.powerType]
				if calculation.freeCrit > 0 then
					calculation.actionCost = calculation.actionCost - calculation.actionCost * calculation.freeCrit * (critPerc / 100) * (hitPerc / 100)
				end
				--TODO: Do we want this cost or what the tooltip displays?
				if calculation.baseCost ~= calculation.actionCost then
					CalculationResults.PowerCost = math_floor(calculation.actionCost + 0.5)
				end
				CalculationResults.DPM = DrD_Round(avgCombined / calculation.actionCost, 1)
			end
			if not CalculationResults.DPM then
				CalculationResults.DPM = "\226\136\158"
			end
		end
		if tooltip then
			CalculationResults.Hit = 		DrD_Round(hitDW or hitPerc, 2)
			CalculationResults.AP = 		math_floor(AP + 0.5)
			CalculationResults.Ranged =		calculation.ranged
			CalculationResults.DmgM = 		DrD_Round(calculation.dmgM_Display, 3)
			CalculationResults.APBonus = 	DrD_Round(APmod, 3)

			if settings.Parry and parry then
				CalculationResults.Parry = DrD_Round(parry, 2)
			end
			if settings.Dodge and dodge then
				CalculationResults.Dodge = DrD_Round(dodge, 2)
			end
			if settings.Glancing and calculation.glancing then
				CalculationResults.Glancing = calculation.glancing
			end
			if calculation.mitigation < 1 then
				CalculationResults.Mitigation = DrD_Round((1 - calculation.mitigation) * 100, 2)
				CalculationResults.ArmorPen = DrD_Round(calculation.armorIgnore * 100, 2)
			end
			if not calculation.NoCrits or calculation.E_canCrit then
				CalculationResults.CritM =	DrD_Round( 100 + calculation.critM * 100, 2)
				CalculationResults.Crit = 	DrD_Round(critPerc, 2)
			end
			if avgHit_O then
				CalculationResults.AvgTotalM =	math_floor(avgTotal + 0.5)
				CalculationResults.AvgHitO = 	math_floor(avgHit_O + 0.5)
				CalculationResults.MinHitO = 	math_floor(minDam_O)
				CalculationResults.MaxHitO = 	math_ceil(maxDam_O)
				CalculationResults.HitO =		DrD_Round(hitDWO or hitPerc_O, 2)
				CalculationResults.AvgTotalO =  math_floor(avgTotal_O + 0.5)
				if not calculation.NoCrits then
					CalculationResults.MinCritO = 	math_floor(minCrit_O)
					CalculationResults.MaxCritO = 	math_ceil(maxCrit_O)
					CalculationResults.AvgCritO = 	math_floor(avgCrit_O + 0.5)
				end
			end
			if extraDam then
				CalculationResults.Extra = 		math_floor(extraAvg + 0.5)
				CalculationResults.ExtraMin =	math_floor(extraMin)
				CalculationResults.ExtraMax = 	math_ceil(extraMax)
				CalculationResults.ExtraName =	calculation.extraName
			end
			if extraDPS then
				CalculationResults.ExtraDPS = DrD_Round( extraDPS, 1)
				CalculationResults.ExtraNameDPS = calculation.extraName_DPS
			end
			if (calculation.SPBonus > 0 or calculation.extraDamageSP) then
				CalculationResults.SP = math_floor( SP + 0.5 )
				CalculationResults.SPBonus = DrD_Round( calculation.SPBonus + (calculation.extraDamageSP or 0), 3 )
			end
			if perHit then
				if ticks and (not calculation.NoCrits and not baseSpell.E_eDuration and not calculation.extraTicks or baseSpell.E_eDuration and calculation.E_canCrit) then
					CalculationResults.PerCrit = math_floor( perHit * (1 + (not baseSpell.eDuration and calculation.E_critM or calculation.critM)) + 0.5 )
					CalculationResults.Crits = math_floor( ticks * (critPerc / 100) + 0.5 )
					ticks = ticks - CalculationResults.Crits
				end
				CalculationResults.Hits = 	ticks or hits
				CalculationResults.PerHit =	DrD_Round(perHit, 1)
			end
			if perTarget then
				CalculationResults.Targets = 	targets
				CalculationResults.PerTarget = 	math_floor(perTarget + 0.5)
			end
			--if calculation.procPerc then
			--	CalculationResults.ProcChance = DrD_Round(calculation.procPerc * 100,2)
			--end
			if calculation.tooltipName then
				CalculationResults.Name = calculation.tooltipName
			end
			if calculation.tooltipName2 then
				CalculationResults.Name2 = calculation.tooltipName2
			end
			--if calculation.coeff then
			--	CalculationResults.Coeff = DrD_Round(calculation.coeff, 3)
			--	CalculationResults.CoeffV = math_floor(calculation.coeffv + 0.5)
			--end
			if baseSpell.AutoAttack then
				CalculationResults.CritCap = DrD_Round(critCap, 2)
				if calculation.critCapNote then
					CalculationResults.CritCapNote = true
				end
			end
			--if calculation.hybridnote then
			--	CalculationResults.HybridNote = true
			--end
		end
		return avgCombined
	end
end


function DrDamage:MeleeTooltip( frame, name, rank )
	local value = select(3,self:MeleeCalc(name, rank, true))
	if not value then return end

	local baseSpell = spellInfo[name][0]
	if type(baseSpell) == "function" then baseSpell = baseSpell(rank) end

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

	if settings.Coeffs then
		--if CalculationResults.Coeff then
		--	frame:AddDoubleLine(L["Coeffs"] .. ":", CalculationResults.Coeff .. "*" .. CalculationResults.CoeffV, rt, gt, bt, r, g, b  )
		--else
			frame:AddDoubleLine(L["Coeffs"] .. ":", (CalculationResults.SP and (CalculationResults.SPBonus .. "*" .. CalculationResults.SP .. "/") or "") .. CalculationResults.APBonus .. "*" .. CalculationResults.AP, rt, gt, bt, r, g, b  )
		--end
		frame:AddDoubleLine(L["Multiplier:"], (CalculationResults.DmgM * 100) .. "%", rt, gt, bt, r, g, b  )
		if CalculationResults.CritM then
			frame:AddDoubleLine(L["Crit Multiplier:"], CalculationResults.CritM .. "%", rt, gt, bt, r, g, b  )
		end
		if CalculationResults.Mitigation then
			local arp = CalculationResults.ArmorPen and CalculationResults.ArmorPen > 0
			frame:AddDoubleLine(arp and (L["Armor"] .. "/" .. L["ArP"] .. ":") or (L["Armor"] .. ":"), CalculationResults.Mitigation .. "%" .. (arp and ("/" .. CalculationResults.ArmorPen .. "%") or ""), rt, gt, bt, r, g, b )
		end
		--if CalculationResults.ProcChance then
		--	frame:AddDoubleLine(L["Proc Chance:"], CalculationResults.ProcChance .. "%", rt, gt, bt, r, g, b )
		--end
		if CalculationResults.Dodge or CalculationResults.Parry or CalculationResults.Glancing then
			frame:AddDoubleLine((CalculationResults.Dodge and L["Dodge"] or "") .. (CalculationResults.Parry and (CalculationResults.Dodge and ("/" .. L["Parry"]) or L["Parry"]) or "") .. (CalculationResults.Glancing and ((CalculationResults.Dodge or CalculationResults.Parry) and ("/" .. L["Glancing"]) or L["Glancing"]) or "") .. ":", (CalculationResults.Dodge and (CalculationResults.Dodge .. "%") or "") .. (CalculationResults.Parry and (CalculationResults.Dodge and ("/" .. CalculationResults.Parry .. "%") or (CalculationResults.Parry .. "%")) or "") .. (CalculationResults.Glancing and ((CalculationResults.Dodge or CalculationResults.Parry) and ("/" .. CalculationResults.Glancing .. "%") or (CalculationResults.Glancing .. "%")) or ""), rt, gt, bt, r, g, b )
		end
	end

	if settings.DispCrit and CalculationResults.Crit then
		frame:AddDoubleLine(L["Crit:"], CalculationResults.Crit .. "%", rt, gt, bt, r, g, b )
		if CalculationResults.CritCap then
			frame:AddDoubleLine(L["Crit Cap:"], CalculationResults.CritCap .. "%", rt, gt, bt, r, g, b )
		end
	end

	if settings.DispHit and not baseSpell.Unresistable then
		frame:AddDoubleLine(L["Hit:"], CalculationResults.Hit .. "%", rt, gt, bt, r, g, b )
		if CalculationResults.HitO then
			frame:AddDoubleLine(L["Off-Hand"] .. " " .. L["Hit:"], CalculationResults.HitO .. "%", rt, gt, bt, r, g, b )
		end
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor3
		r, g, b = c.r, c.g, c.b
	end

	if settings.AvgHit or settings.AvgCrit then
		if CalculationResults.AvgHitO then
			frame:AddLine(L["Main Hand:"])
		end
	end
	if settings.AvgHit then
		frame:AddDoubleLine(L["Avg"] .. ":", CalculationResults.AvgHit .. " (".. CalculationResults.MinHit .."-".. CalculationResults.MaxHit ..")", rt, gt, bt, r, g, b )
	end
	if settings.AvgCrit and CalculationResults.AvgCrit > CalculationResults.AvgHit then
		frame:AddDoubleLine(L["Avg Crit:"], CalculationResults.AvgCrit .. " (".. CalculationResults.MinCrit .."-".. CalculationResults.MaxCrit ..")", rt, gt, bt, r, g, b )
	end

	if settings.Total and CalculationResults.AvgTotalM then
		frame:AddDoubleLine(L["Avg Total"] ..":", CalculationResults.AvgTotalM, rt, gt, bt, r, g, b)
	end

	if CalculationResults.AvgHitO and (settings.AvgHit or settings.AvgCrit) then
		frame:AddLine(L["Off-Hand"] .. ":")
		if settings.AvgHit then
			frame:AddDoubleLine(L["Avg"] .. ":", CalculationResults.AvgHitO .. " (".. CalculationResults.MinHitO .."-".. CalculationResults.MaxHitO ..")", rt, gt, bt, r, g, b )
		end
		if settings.AvgCrit and CalculationResults.AvgCritO then
			frame:AddDoubleLine(L["Avg Crit:"], CalculationResults.AvgCritO .. " (".. CalculationResults.MinCritO .."-".. CalculationResults.MaxCritO ..")", rt, gt, bt, r, g, b )
		end
		if settings.Total and CalculationResults.AvgTotalO then -- and CalculationResults.AvgTotalO > CalculationResults.AvgHitO then
			frame:AddDoubleLine(L["Avg Total"] .. ":", CalculationResults.AvgTotalO, rt, gt, bt, r, g, b  )
		end
	end
	if settings.Total and CalculationResults.AvgTotalO then
		frame:AddLine("---")
	end
	if settings.Extra and CalculationResults.Extra then
		frame:AddDoubleLine(L["Avg"] .. " " .. (CalculationResults.ExtraName or L["Additional"]) .. ":", CalculationResults.Extra .. " (" .. CalculationResults.ExtraMin .."-".. CalculationResults.ExtraMax .. ")", rt, gt, bt, r, g, b)
		--L["Max"] --This is to keep it in the localization app in case further need
	end
	if settings.Ticks then
		if CalculationResults.Hits and CalculationResults.PerHit and not baseSpell.NoHits then
			frame:AddDoubleLine(L["Dot"] .. " " .. L["Hits:"], CalculationResults.Hits .. "x ~" .. CalculationResults.PerHit, rt, gt, bt, r, g, b )
		end
		if CalculationResults.PerCrit and CalculationResults.Crits > 0 then
			frame:AddDoubleLine(L["Dot"] .. " " .. L["Crits:"], CalculationResults.Crits .. "x ~" .. CalculationResults.PerCrit, rt, gt, bt, r, g, b )
		end
		if CalculationResults.Targets then
			frame:AddDoubleLine(L["AoE"] .. ":", CalculationResults.Targets .. "x ~" .. CalculationResults.PerTarget, rt, gt, bt, r, g, b )
		end
	end
	if settings.Total then
		if CalculationResults.AvgTotalO then
			frame:AddDoubleLine(L["Combined Total:"], CalculationResults.AvgTotal, rt, gt, bt, r, g, b  )
		else
			frame:AddDoubleLine(L["Avg Total"] .. ":", CalculationResults.AvgTotal, rt, gt, bt, r, g, b)
		end
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor4
		r, g, b = c.r, c.g, c.b
	end

	local bType
	if CalculationResults.Ranged then
		bType = L["RAP"]
	else
		bType = L["AP"]
	end

	if CalculationResults.Stats then
		local strA = CalculationResults.NextStr and CalculationResults.NextStr > 0 and CalculationResults.Stats * 0.1 / CalculationResults.NextStr
		local agiA = CalculationResults.NextAgi and CalculationResults.NextAgi > 0 and CalculationResults.Stats * 0.1 / CalculationResults.NextAgi
		local intA = CalculationResults.NextInt and CalculationResults.NextInt > 0 and CalculationResults.Stats * 0.1 / CalculationResults.NextInt
		local apA = CalculationResults.NextAP and CalculationResults.NextAP > 0 and CalculationResults.Stats * 0.1 / CalculationResults.NextAP
		local critA = CalculationResults.NextCrit and CalculationResults.NextCrit > 0 and CalculationResults.Stats * 0.01 / CalculationResults.NextCrit * self:GetRating("Crit", nil, true)
		local expA = CalculationResults.NextExp and CalculationResults.NextExp > 0 and CalculationResults.Stats * 0.01 / CalculationResults.NextExp * self:GetRating("Expertise",nil,true)
		local hitA = CalculationResults.NextHit and CalculationResults.NextHit > 0 and CalculationResults.Stats * 0.01 / CalculationResults.NextHit * self:GetRating("Hit", nil, true)

		if settings.Next then
			if strA then frame:AddDoubleLine("+10 " .. L["Str"] .. ":", "+" .. DrD_Round(CalculationResults.NextStr, 2), rt, gt, bt, r, g, b) end
			if agiA then frame:AddDoubleLine("+10 " .. L["Agi"] .. ":", "+" .. DrD_Round(CalculationResults.NextAgi, 2), rt, gt, bt, r, g, b) end
			if intA then frame:AddDoubleLine("+10 " .. L["Int"] .. ":", "+" .. DrD_Round(CalculationResults.NextInt, 2), rt, gt, bt, r, g, b) end
			if apA then frame:AddDoubleLine("+10 " .. bType .. ":", "+" .. DrD_Round(CalculationResults.NextAP, 2), rt, gt, bt, r, g, b ) end
			if expA then frame:AddDoubleLine("+1 " .. L["Expertise"] .. " (" .. self:GetRating("Expertise") .. "):", "+" .. DrD_Round(CalculationResults.NextExp, 2), rt, gt, bt, r, g, b ) end
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
				text = text and (text .. "|" .. bType) or bType
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
				local hitA = DrD_Round(hitA,1)
				text2 = text2 and (text2 .. "|" .. L["Ht"]) or L["Ht"]
				value2 = value2 and (value2 .. "/" .. hitA) or hitA
			end
			if expA then
				local expA = DrD_Round(expA,1)
				text2 = text2 and (text2 .. "|" .. L["Exp"]) or L["Exp"]
				value2 = value2 and (value2 .. "/" .. expA) or expA
			end
			if text then
				frame:AddDoubleLine("+1% " .. L["Damage"] .. " (" .. text .. "):", value, rt, gt, bt, r, g, b )
			end
			if text2 then
				frame:AddDoubleLine("+1% " .. L["Damage"] .. " (" .. text2 .. "):", value2, rt, gt, bt, r, g, b )
			end
		end
		if settings.CompareStr and strA then
			local text, value = self:CompareTooltip(strA, agiA, intA, apA, masA, critA, hitA, expA, L["Str"], L["Agi"], L["Int"], bType, L["Ma"], L["Cr"], L["Ht"], L["Exp"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareAgi and agiA then
			local text, value = self:CompareTooltip(agiA, strA, intA, apA, masA, critA, hitA, expA, L["Agi"], L["Str"], L["Int"], bType, L["Ma"], L["Cr"], L["Ht"], L["Exp"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareInt and intA then
			local text, value = self:CompareTooltip(intA, strA, agiA, apA, masA, critA, hitA, expA, L["Int"], L["Str"], L["Agi"], bType, L["Ma"], L["Cr"], L["Ht"], L["Exp"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareAP and apA then
			local text, value = self:CompareTooltip(apA, strA, agiA, intA, masA, critA, hitA, expA, bType, L["Str"], L["Agi"], L["Int"], L["Ma"], L["Cr"], L["Ht"], L["Exp"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareCrit and critA then
			local text, value = self:CompareTooltip(critA, strA, agiA, intA, apA, masA, hitA, expA, L["Cr"], L["Str"], L["Agi"], L["Int"], bType, L["Ma"], L["Ht"], L["Exp"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareHit and hitA then
			local text, value = self:CompareTooltip(hitA, strA, agiA, intA, apA, masA, critA, expA, L["Ht"], L["Str"], L["Agi"], L["Int"], bType, L["Ma"], L["Cr"], L["Exp"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
		if settings.CompareExp and expA then
			local text, value = self:CompareTooltip(expA, strA, agiA, intA, apA, masA, critA, hitA, L["Exp"], L["Str"], L["Agi"], L["Int"], bType, L["Ma"], L["Cr"], L["Ht"])
			if text then frame:AddDoubleLine(text, value, rt, gt, bt, r, g, b ) end
		end
	end

	if not settings.DefaultColor then
		local c = settings.TooltipTextColor5
		r, g, b = c.r, c.g, c.b
	end

	if not baseSpell.NoDPS and settings.DPS then
		local extra
		if settings.Extra and CalculationResults.ExtraDPS then
			frame:AddDoubleLine(L["DPS"] .. " (" .. CalculationResults.ExtraNameDPS .. "):", CalculationResults.ExtraDPS, rt, gt, bt, r, g, b)
			extra = CalculationResults.ExtraDPS
		end
		if CalculationResults.DPS and (not extra or extra and CalculationResults.DPS > extra) then
			frame:AddDoubleLine(L["DPS"] .. ((CalculationResults.DPS_Duration and " (" .. CalculationResults.DPS_Duration .. "s):") or ":"), CalculationResults.DPS, rt, gt, bt, r, g, b )
		end
		if CalculationResults.DPSCD then
			frame:AddDoubleLine(L["DPS (CD):"], CalculationResults.DPSCD, rt, gt, bt, r, g, b )
		end
	end

	if settings.DPP and CalculationResults.DPM and CalculationResults.PowerType and not baseSpell.NoDPM then
		frame:AddDoubleLine( CalculationResults.PowerType .. ":", CalculationResults.DPM, rt, gt, bt, r, g, b )
	end

	if settings.Hints then
		if not settings.DefaultColor then
			local c = settings.TooltipTextColor6
			r, g, b = c.r, c.g, c.b
		end
		if CalculationResults.CritCapNote then
			frame:AddLine(L["Crit cap reached"], r, g, b)
		end
		--if CalculationResults.HybridNote then
		--	frame:AddLine("Hint: Add enemy armor from options", r, g, b)
		--end
	end
	frame:Show()
end
