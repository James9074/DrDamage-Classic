local _, playerClass = UnitClass("player")
local playerHealer = (playerClass == "PRIEST") or (playerClass == "SHAMAN") or (playerClass == "PALADIN") or (playerClass == "DRUID")
local playerCaster = (playerClass == "MAGE") or (playerClass == "PRIEST") or (playerClass == "WARLOCK")
local playerMelee = (playerClass == "ROGUE") or (playerClass == "WARRIOR") or (playerClass == "HUNTER")
local playerHybrid = (playerClass == "DEATHKNIGHT") or (playerClass == "DRUID") or (playerClass == "PALADIN") or (playerClass == "SHAMAN")

--Libraries
local L = LibStub("AceLocale-3.0"):GetLocale("DrDamage", true)
local AC = LibStub("AceConfig-3.0")
local ACD = LibStub("AceConfigDialog-3.0")
local GT = LibStub:GetLibrary("LibGratuity-3.0")
local LSM = LibStub:GetLibrary("LibSharedMedia-3.0", true)
local DrDamage = DrDamage

-- GLOBALS: LibStub, IsAddOnLoaded, Lunar, Macaroon, Nurfed, nUI_DrDamageIntegration, GetSpecializationInfo, CreateFrame, GameFontNormal, UnitRace, InterfaceOptionsFrame, table

--General
local settings
local _G = getfenv(0)
local type = type
local pairs = pairs
local tonumber = tonumber
local math_floor = math.floor
local math_min = math.min
local math_max = math.max
local math_abs = math.abs
local string_match = string.match
local string_format = string.format
local string_find = string.find
local string_sub = string.sub
local string_gsub = string.gsub
local string_len = string.len
local select = select
local next = next

--Module
local GameTooltip = GameTooltip
local UnitBuff = UnitBuff
local UnitDebuff = UnitDebuff
local UnitLevel = UnitLevel
local UnitDamage = UnitDamage
local UnitPower = UnitPower
local UnitPowerMax = UnitPowerMax
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitAttackPower = UnitAttackPower
local UnitIsUnit = UnitIsUnit
local UnitStat = UnitStat
local UnitClassification = UnitClassification
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local BOOKTYPE_SPELL = BOOKTYPE_SPELL
local GetSpellBookItemName = GetSpellBookItemName
local GetSpellInfo = GetSpellInfo
local GetMacroSpell = GetMacroSpell
local GetMacroBody = GetMacroBody
local GetActionInfo = GetActionInfo
local GetPetActionInfo = GetPetActionInfo
local GetActionCooldown = GetActionCooldown
local GetCursorInfo = GetCursorInfo
local GetInventoryItemLink = GetInventoryItemLink
local GetItemInfo = GetItemInfo
local GetItemGem = GetItemGem
local GetTime = GetTime
local GetWeaponEnchantInfo = GetWeaponEnchantInfo
local GetTalentInfo = GetTalentInfo
local GetNumGlyphs = GetNumGlyphs
local GetNumSpecializations = GetNumSpecializations
local GetNumTalents = GetNumTalents
local GetGlyphSocketInfo = GetGlyphSocketInfo
local GetCombatRatingBonus = GetCombatRatingBonus
local GetShapeshiftFormInfo = GetShapeshiftFormInfo
local GetAttackPowerForStat = GetAttackPowerForStat
local GetSpellCritChanceFromIntellect = GetSpellCritChanceFromIntellect
local GetCritChanceFromAgility = GetCritChanceFromAgility
local HasAction = HasAction
local IsEquippedItem = IsEquippedItem
local IsAltKeyDown = IsAltKeyDown
local IsControlKeyDown = IsControlKeyDown
local IsShiftKeyDown = IsShiftKeyDown
local SecureButton_GetModifiedAttribute = SecureButton_GetModifiedAttribute
local SecureButton_GetEffectiveButton = SecureButton_GetEffectiveButton
local ActionButton_GetPagedID = ActionButton_GetPagedID
local InCombatLockdown = InCombatLockdown
--local IsInInstance = IsInInstance
--local GetZonePVPInfo = GetZonePVPInfo
local GetHitModifier = GetHitModifier
local GetSpellHitModifier = GetSpellHitModifier

--Module variables
local playerCompatible, playerEvents, DrD_Font, updateSetItems, dmgMod
local spellInfo, talentInfo, talents, PlayerHealth, TargetHealth
local ModStateEvent, Casts, ManaCost, PowerCost
local PlayerAura = DrDamage.PlayerAura
local TargetAura = DrDamage.TargetAura

--Local functions
function DrDamage.ClearTable(table)
	for k in pairs( table ) do
		table[k] = nil
	end
end
function DrDamage.Round(x, y)
	local temp = 10 ^ y
	return math_floor( x * temp + 0.5 ) / temp
end
function DrDamage.MatchData( data, ... )
	if not data or not ... then
		return false
	end

	if type( data ) == "table" then
		for i = 1, select('#', ...) do
			if data[1] then
				for j = 1, #data do
					for i = 1, select('#', ...) do
						if data[j] == select(i, ...) then
							return true
						end
					end
				end
			else
				if data[select(i, ...)] then
					return true
				end
			end
		end
	else
		for i = 1, select('#', ...) do
			if data == select(i, ...) then
				return true
			end
		end
	end

	return false
end
local function DrD_Set(n)
	return function(info, v)
		settings[n] = v
		DrDamage:ScheduleUpdate(0.4)
	end
end
local DrD_ClearTable = DrDamage.ClearTable
local DrD_Round = DrDamage.Round
local DrD_MatchData = DrDamage.MatchData

--Load actionbar function
local ABfunc, ABdisable, ABtotembar, ABupdate, ABfont
local ABtable, ABobjects, ABrefresh, ABtext1, ABtext2 = {}, {}, {}, {}, {}
local function DrD_DetermineAB()
	--Default
	for i = 1, 6 do
		for j = 1, 12 do
			table.insert(ABobjects,_G[((select(i,"ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton", "BonusActionButton"))..j)])
		end
	end
	if playerClass == "SHAMAN" and settings.DefaultExtraBar then
		for i = 1, 4 do
			table.insert(ABobjects,_G[("MultiCastActionButton"..i)])
		end
	end
	if (playerClass == "WARLOCK" or playerClass == "MAGE") and settings.DefaultExtraBar then
		local func = function(button)
			if button then
				local name = GetPetActionInfo(button:GetID())
				if name then
					local _, rank = GetSpellInfo(name)
					return nil, name, rank, true
				end
			end
		end
		ABrefresh["PetActionButton"] = function()
			for i=1,10 do
				ABtable["PetActionButton"..i] = func
			end
		end
	end
	if playerClass == "PALADIN" and settings.DefaultExtraBar then
		local func = function(button)
			if button then
				local _, name = GetShapeshiftFormInfo(button:GetID())
				if name then
					local _, rank = GetSpellInfo(name)
					return nil, name, rank
				end
			end
		end
		ABrefresh["ShapeshiftButton"] = function()
			for i=1,7 do
				ABtable["ShapeshiftButton"..i] = func
			end
		end
	end
	if IsAddOnLoaded("Bartender4") then
		local func = function(button)
			if button.GetSpellId then
				local spell = button:GetSpellId()
				if spell then
					local name, rank = GetSpellInfo(spell)
					local macro
					if button.GetActionText then
						local text = button:GetActionText()
						if text and text ~= "" then macro = true end
					end
					return nil, name, rank, nil, macro
				end
			end
			if button.GetAction then
				local action, id = button:GetAction()
				if action == "action" then
					return id
				end
			end
		end
		ABrefresh["BT4Button"] = function()
			for i=1,120 do
				ABtable["BT4Button"..i] = func
			end
			if playerClass == "WARLOCK" and settings.DefaultExtraBar then
				local func = function(button)
					if button then
						local name = GetPetActionInfo(button:GetID())
						if name then
							local _, rank = GetSpellInfo(name)
							return nil, name, rank, true
						end
					end
				end			
				for i = 1, 10 do
					ABtable["BT4PetButton"..i] = func
				end
			end
			if playerClass == "SHAMAN" and settings.DefaultExtraBar then
				for i = 1, 4 do
					ABtable["MultiCastActionButton"..i] = ActionButton_GetPagedID
				end
			end
		end
		ABdisable = true
	end
	if nUI_DrDamageIntegration then
		ABrefresh["nUI"] = nUI_DrDamageIntegration( ABtable )
		ABdisable = true
	end
	if IsAddOnLoaded("Nurfed") then
		local func = function(button)
			if button.spell then
				if button.type == "spell" then
					local pid = Nurfed:getspell(button.spell)
					if pid then
						return nil, GetSpellBookItemName(pid, BOOKTYPE_SPELL)
					end
				elseif button.type == "macro" then
					local action, rank = GetMacroSpell(button.spell)
					if action then
						return nil, action, rank
					end
				end
			end
		end
		ABrefresh["Nurfed_Button"] = function()
			for i=1,120 do
				ABtable["Nurfed_Button"..i] = func
			end
		end
		ABdisable = true
	end
	if IsAddOnLoaded("Macaroon") then
		local func = function(button)
			if button.config and button.config.type == "action" then
				return SecureButton_GetModifiedAttribute(button,"action",SecureButton_GetEffectiveButton(button))
			end
			if button.macroshow then
				return nil, string_match(button.macroshow,"[^%(]+"), button.macrorank
			end
			if button.macrospell then
				return nil, string_match(button.macrospell,"[^%(]+"), button.macrorank
			end
		end
		ABrefresh["MacaroonButton"] = function()
			for _, button in pairs(Macaroon.Buttons) do
				ABtable[button[1]:GetName()] = func
			end
		end
		if Macaroon.Button_OnReceiveDrag then
			DrDamage.Button_OnReceiveDrag = function()
				DrDamage:ScheduleUpdate(settings.TimerHideGrid)
			end		
			DrDamage:Hook(Macaroon, "Button_OnReceiveDrag")
		end
		if Macaroon.Button_OnLoad then
			DrDamage.Button_OnLoad = function()
				if not DrDamage.refreshABTimer then
					DrDamage.refreshABTimer = DrDamage:ScheduleTimer("RefreshAB", 1)
				end
			end
			DrDamage:Hook(Macaroon, "Button_OnLoad")
		end
	end
	if IsAddOnLoaded("ReAction") then
		local ReAction = LibStub("AceAddon-3.0"):GetAddon("ReAction", true)
		local func = function(button)
			local btnType = button:GetAttribute("type")
			if btnType == "action" then
			  return SecureButton_GetModifiedAttribute(button,"action",SecureButton_GetEffectiveButton(button))
			elseif btnType == "spell" then
			  return nil, SecureButton_GetModifiedAttribute(button,"spell",SecureButton_GetEffectiveButton(button))
			end
		end
		ABrefresh["ReAction"] = function()
			for _, bar in ReAction:IterateBars() do
				for _, button in bar:IterateButtons() do
					ABtable[button:GetFrame():GetName()] = func
				end
			end
		end
	end	
	if IsAddOnLoaded("Dominos") then
		local func = function(button) return SecureButton_GetModifiedAttribute(button,"action",SecureButton_GetEffectiveButton(button)) end
		ABrefresh["DominosActionButton"] = function()
			for i=1,120 do
				ABtable["DominosActionButton"..i] = func
			end
		end
	end
	if IsAddOnLoaded("IPopBar") then
		local func = function(button) return SecureButton_GetModifiedAttribute(button,"action",SecureButton_GetEffectiveButton(button)) end
		ABrefresh["IPopBarButton"] = function()
			for i=1,120 do
				ABtable["IPopBarButton"..i] = func
			end
		end
	end
	if IsAddOnLoaded("CT_BarMod") then
		--There's an object list available CT_BarMod.actionButtonList, index = actionID, value.hasAction
		local func = function(button)
			if button.object.actionId then return button.object.actionId
			else return button.object.id end
		end
		ABrefresh["CT_BarModActionButton"] = function()
			for i=13,120 do
				ABtable["CT_BarModActionButton"..i] = func
			end
		end
	end
	if IsAddOnLoaded("RDX") then
		local func = function(button) return button:GetAttribute("action") end
		ABrefresh["RDX_ActionBars"] = function()
			for i=1,120 do
				ABtable["VFLButton"..i] = func
			end
		end
	end
	if IsAddOnLoaded("ButtonForge") and ButtonForge_API1 then
		local func = function(button, name) 
			local spell, id = ButtonForge_API1:GetButtonActionInfo(name)
			if spell == "spell" then return id end
		end
		ABrefresh["ButtonForge"] = function()
			local buttons = ButtonForge_API1:GetButtonFrameNames()
			for k in pairs(buttons) do
				ABtable[k] = func
			end
		end
		--ButtonForge_API1.RegisterCallback(self.refreshAB)	
	end	
	if IsAddOnLoaded("LunarSphere") then
		if Lunar and Lunar.DrDamageFunc then
			ABrefresh["LunarSphereButtons"] = function()
				for i = 1, 10 do
					ABtable["LunarMenu" .. i .. "Button"] = Lunar.DrDamageFunc
				end
				for i = 11, 130 do
					ABtable["LunarSub" .. i .. "Button"] = Lunar.DrDamageFunc
				end
			end
		end
	end
	if IsAddOnLoaded("ElvUI") then
		local func = function(button) return SecureButton_GetModifiedAttribute(button,"action",SecureButton_GetEffectiveButton(button)) end
		ABrefresh["ElvUI"] = function()
			for i=1,5 do
				for j=1,12 do
					ABtable["ElvUI_Bar" .. i .. "Button" .. j] = func
				end
			end
		end
	end	
	if not next(ABrefresh) then
		ABrefresh, ABtable = nil, nil
	end
	DrDamage:RefreshAB()
end

function DrDamage:RefreshAB()
	if ABrefresh then
		for k in pairs(ABtable) do
			ABtable[k] = nil
		end
		for _, func in pairs(ABrefresh) do
			func()
		end
		ABfont = true
	end
	self.refreshABTimer = nil
end

--Options table
DrDamage.options = { type='group', args = {} }
--Defaults table
DrDamage.defaults = {
	profile = {
		--Actionbar
		DisplayType = "AvgTotal",
		DisplayType2 = false,
		DisplayType_M = "AvgTotal",
		DisplayType_M2 = false,
		--
		ABText = true,
		DefaultAB = true,
		DefaultExtraBar = true,
		UpdateShift = false,
		UpdateAlt = false,
		UpdateCtrl = false,
		SwapCalc = false,
		HideAMacro = true,
		HideHotkey = false,
		DisableUpdates = false,
		ShortenText = false,
		Font = GameFontNormal:GetFont(),
		FontEffect = "OUTLINE",
		FontSize = 10,
		FontXPosition = 0,
		FontYPosition = 0,
		FontXPosition2 = 0,
		FontYPosition2 = 0,
		FontColorDmg = { r = 1, g = 1, b = 0.2 },
		FontColorHeal = { r = 0.4, g = 1.0, b = 0.3 },
		FontColorMana = { r = 0.4, g = 0.8, b = 1.0 },
		FontColorEnergy = { r = 1.0, g = 1.0, b = 0 },
		FontColorRage = { r = 1.0, g = 0.0, b = 0.0 },
		FontColorCasts1 = { r = 0.4, g = 1.0, b = 0.3 },
		FontColorCasts2 = { r = 1, g = 1, b = 0.2 },
		FontColorCasts3 = { r = 1, g = 0.08, b = 0.08 },
		--Actionbar update delays
		TimerPlayerAura = 0.75,
		TimerTargetAura = 1.5,
		TimerUnitHealth = 2.5,
		TimerUnitPower = 3,
		TimerComboPoints = 0,
		TimerTarget = 0.5,
		TimerStealth = 0.5,
		TimerModifier = 0.3,
		TimerActionbarPage = 0,
		TimerHideGrid = 0.1,
		TimerInventory = 1.5,		
		--Tooltip
		Tooltip = "Always",
		Hints = true,
		PlusDmg = false,
		Coeffs = true,
		DispCrit = true,
		DispHit = true,
		AvgHit = true,
		AvgCrit = true,
		Ticks = true,
		Total = true,
		Extra = true,
		DPS = true,
		DPM = true,
		DPP = true,
		Doom = true,
		Casts = true,
		ManaUsage = false,
		Next = false,
		--Comparisons
		CompareStats = true,
		CompareStr = true,
		CompareAgi = true,
		CompareInt = true,
		CompareAP = false,
		CompareExp = false,
		CompareMastery = false,
		CompareHit = false,
		CompareCrit = false,
		CompareHaste = false,
		--Tooltip colors
		DefaultColor = false,
		TooltipTextColor1 = { r = 1.0, g = 1.0, b = 1.0 },
		TooltipTextColor2 = { r = 0.0, g = 0.7, b = 0.0 },
		TooltipTextColor3 = { r = 0.8, g = 0.8, b = 0.9 },
		TooltipTextColor4 = { r = 0.3, g = 0.6, b = 0.5 },
		TooltipTextColor5 = { r = 0.8, g = 0.1, b = 0.1 },
		TooltipTextColor6 = { r = 0.0, g = 1.0, b = 0.0 },
		--Custom Stats
		Custom = false,
		CustomAdd = true,
		Str = 0,
		Agi = 0,
		Int = 0,
		Spi = 0,
		SP = 0,
		AP = 0,
		HitRating = 0,
		CritRating = 0,
		HasteRating = 0,
		ExpertiseRating = 0,
		MasteryRating = 0,
		--Calculation
		HitCalc = true,
		CritDepression = false,
		TwoRoll = true,
		TwoRoll_M = true,
		ManaConsumables = false,
		Dodge = true,
		Parry = false,
		Glancing = true,
		TargetAmount = 1,
		ComboPoints = 0,
		TargetLevel = 3,
		ArmorCalc = "Auto",
		Armor = 0,
		ArmorMitigation = 0,
		Resilience = 0,
		--Buffs
		PlayerAura = {},
		TargetAura = {},
		Consumables = {},
	}
}

function DrDamage:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("DrDamageDB", self.defaults)
	settings = self.db.profile
	AC:RegisterOptionsTable("DrDamage", self.options)
	self:RegisterChatCommand("drd", function() self:OpenConfig() end)
	self:RegisterChatCommand("drdmg", function() self:OpenConfig() end)
	self:RegisterChatCommand("drdamage", function() self:OpenConfig() end)
	local LDB = LibStub:GetLibrary("LibDataBroker-1.1", true)
	if LDB then
		LDB:NewDataObject("DrDamage", {
			type = "launcher",
			icon = "Interface\\Icons\\Spell_Holy_SearingLightPriest",
			OnClick = function(clickedframe, button)
				self:OpenConfig()
			end,
		})
	end
end

function DrDamage:OnEnable()
	if self.PlayerData then
		self.ClassSpecials = {}
		self.DmgCalculation = {}
		self.SetBonuses = {}
		self.talents = {}
		self.BaseTalents = {}
		self:PlayerData()
		self.PlayerData = nil
		PlayerHealth = self.PlayerHealth
		TargetHealth = self.TargetHealth
		spellInfo = self.spellInfo
		talentInfo = self.talentInfo
		talents = self.talents
		self:CommonData()
		self.CommonData = nil
	elseif not self.spellInfo and not self.talentInfo then
		return
	end

	self:RefreshConfig()
	self:RegisterEvent("PLAYER_ENTERING_WORLD", function() self:UnregisterEvent("PLAYER_ENTERING_WORLD"); self:ScheduleTimer("Load", 3) end)
end

function DrDamage:OnDisable()
	if playerCompatible then
		local tempType = settings.ABText
		settings.ABText = false
		self:UpdateAB()
		settings.ABText = tempType
	end
end

local AuraIterate
function DrDamage:Load()
	if self.GeneralOptions then
		self:GeneralOptions()
		self.GeneralOptions = nil
	end
	if self.Caster_OnEnable then
		self:Caster_OnEnable()
		self.Caster_OnEnable = nil
	end
	if self.Melee_OnEnable then
		self:Melee_OnEnable()
		self.Melee_OnEnable = nil
	end
	if DrD_DetermineAB then
		DrD_DetermineAB()
		DrD_DetermineAB = nil
	end
	if not playerCompatible then
		--Create reverse lookup table
		local lookup = {}
		for k, v in pairs( spellInfo ) do
			if v["ID"] then
				lookup[v["Name"]] = v["ID"]
			end
		end
		--Make talent spell tables better suited for iteration
		for k in pairs( talentInfo ) do
			local talent = talentInfo[k]
			for i=1,#talent do
				local spelltable = talent[i].Spells
				if type(spelltable) == "table" then
					for j = 1, #spelltable do
						spelltable[spelltable[j]] = true
						spelltable[j] = nil
					end
				end
			end
		end
		--Make buff spell tables better suited for iteration
		for _, v in pairs( PlayerAura ) do
			local spells = v.Spells
			if spells then
				if type(spells) == "table" then
					for i=1,#spells do
						if not tonumber(spells[i]) then
							local id = lookup[spells[i]]
							if id and GetSpellInfo(id) then
								spells[GetSpellInfo(id)] = true
							--@debug@
							else
								self:Print("Player aura spell matching failed for: " .. spells[i])
							--@end-debug@
							end
							spells[i] = nil
						elseif GetSpellInfo(spells[i]) then
							spells[GetSpellInfo(spells[i])] = true
							spells[i] = nil
						--@debug@
						else
							self:Print("Player aura spellID does not exist: " .. spells[i])
						--@end-debug@
						end
					end
				else
					--@debug@
					local temp = spells
					--@end-debug@
					if not tonumber(spells) then
						spells = lookup[spells]
					end
					if spells and GetSpellInfo(spells) then
						v.Spells = GetSpellInfo(spells)
					--@debug@
					else
						self:Print("Player aura spellID does not exist: " .. (spells or temp))
					--@end-debug@
					end
				end
			end
		end
		for _, v in pairs( TargetAura ) do
			local spells = v.Spells
			if spells then
				 if type(spells) == "table" then
					for i=1,#spells do
						if not tonumber(spells[i]) then
							local id = lookup[spells[i]]
							if id and GetSpellInfo(id) then
								spells[GetSpellInfo(id)] = true
							--@debug@
							else
								self:Print("Target aura spell matching failed for: " .. spells[i])
							--@end-debug@
							end
							spells[i] = nil
						elseif GetSpellInfo(spells[i]) then
							spells[GetSpellInfo(spells[i])] = true
							spells[i] = nil
						--@debug@
						else
							self:Print("Target aura spellID does not exist: " .. spells[i])
						--@end-debug@
						end
					end
				else
					--@debug@
					local temp = spells
					--@end-debug@
					if not tonumber(spells) then
						spells = lookup[spells]
					end
					if spells and GetSpellInfo(spells) then
						v.Spells = GetSpellInfo(spells)
					--@debug@
					else
						self:Print("Target aura spellID does not exist: " .. (spells or temp))
					--@end-debug@
					end
				end
			end
		end
		--Create talent and buff tables
		for name, spell in pairs( spellInfo ) do
			if spell[0] and type(spell[0]) ~= "function" then
				spell["Talents"] = {}
				spell["PlayerAura"] = {}
				spell["TargetAura"] = {}
				spell["Consumables"] = {}
				AuraIterate(name, spell, spell["PlayerAura"], PlayerAura)
				AuraIterate(name, spell, spell["TargetAura"], TargetAura)
				AuraIterate(name, spell, spell["Consumables"], self.Consumables)
				if spell["Secondary"] then
					spell = spell["Secondary"]
					spell["Talents"] = {}
					spell["PlayerAura"] = {}
					spell["TargetAura"] = {}
					spell["Consumables"] = {}
					AuraIterate(name, spell, spell["PlayerAura"], PlayerAura)
					AuraIterate(name, spell, spell["TargetAura"], TargetAura)
					AuraIterate(name, spell, spell["Consumables"], self.Consumables)
				end
			end
		end
		lookup = nil
		AuraIterate = nil
	end

	--A few options checks
	if (settings.Font ~= self.defaults.profile.Font) and not CreateFrame("Frame"):CreateFontString("DrDamage-Font"):SetFont(settings.Font,10) then
		settings.Font = GameFontNormal:GetFont()
	end
	if settings.TargetLevel > 3 or settings.TargetLevel < 0 then
		settings.TargetLevel = 3
	end
	local nocaster = (not settings.DisplayType and not settings.DisplayType2)
	local nomelee = (not settings.DisplayType_M and not settings.DisplayType_M2)
	if playerCaster and nocaster or playerMelee and nomelee or playerHybrid and nocaster and nomelee then
		settings.ABText = false
	end
	if LSM then
		LSM.RegisterCallback(self, "LibSharedMedia_Registered", function(event, media)
			if media == "font" then
				self.options.args.General.args.Actionbar.args.Font.values = LSM:HashTable("font")
			end
		end)
		LSM.RegisterCallback(self, "LibSharedMedia_SetGlobal", function(event, media, key)
			if media == "font" then
				DrD_Font = LSM:Fetch("font")
				ABfont = true
				self:UpdateAB()
			end
		end)
	end
	Casts = (settings.DisplayType2 == "Casts")
	ManaCost = (settings.DisplayType2 == "ManaCost")
	PowerCost = (settings.DisplayType_M2 == "PowerCost")
	DrD_Font = DrD_Font or settings.Font

	--Run startup functions
	self:LoadData()
	--self:ZONE_CHANGED_NEW_AREA()
	self:MetaGems()
	self:UpdateGlyphs()
	self:UpdateTalents()
	playerCompatible = true

	--Apply hooks and register events
	self:SecureHook(GameTooltip, "SetAction")
	self:SecureHook(GameTooltip, "SetSpellBookItem")
	--self:SecureHook(GameTooltip, "SetTalent")
	self:SecureHook(GameTooltip, "SetTrainerService", "SetShapeshift" )
	self:SecureHook(GameTooltip, "SetSpellByID")
	if playerClass == "PALADIN" then
		self:SecureHook(GameTooltip, "SetShapeshift")
	end
	if playerClass == "WARLOCK" or playerClass == "MAGE" then
		self:SecureHook(GameTooltip, "SetPetAction", "SetShapeshift")
	end

	self:RegisterEvent("CHARACTER_POINTS_CHANGED","UPDATE_TALENTS")
	self:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED","UPDATE_TALENTS")
	self:RegisterEvent("GLYPH_ADDED", "UpdateGlyphs")
	self:RegisterEvent("GLYPH_UPDATED", "UpdateGlyphs")
	self:RegisterEvent("GLYPH_REMOVED", "UpdateGlyphs")
	self:RegisterEvent("PLAYER_LEVEL_UP")
	self:RegisterBucketEvent("PLAYER_EQUIPMENT_CHANGED", 0.3)
	--self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig", true)
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig", true)
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig", true, true)

	if settings.ABText then
		self:TextEvents()
	end
end

function DrDamage:TextEvents()
	if not playerEvents then
		if settings.UpdateAlt or settings.UpdateCtrl or settings.UpdateShift then
			self:RegisterEvent( "MODIFIER_STATE_CHANGED" )
			ModStateEvent = true
		end
		if PlayerHealth or TargetHealth then
			self:RegisterBucketEvent("UNIT_HEALTH", settings.TimerUnitHealth)
		else
			self.UNIT_HEALTH = nil
		end
		if playerClass == "SHAMAN" or playerClass == "ROGUE" or playerClass == "DEATHKNIGHT" then
			self:RegisterBucketEvent("UNIT_INVENTORY_CHANGED", settings.TimerInventory)
		else
			self.UNIT_INVENTORY_CHANGED = nil
		end
		if (playerClass == "WARLOCK" or playerClass == "MAGE") and settings.DefaultExtraBar then
			self:RegisterEvent("PET_BAR_HIDEGRID")
			self:RegisterEvent("PET_SPELL_POWER_UPDATE", "UpdatePetSpells")
			self:RegisterBucketEvent("PET_BAR_UPDATE", 1.5, "UpdatePetSpells")
		else
			self.PET_BAR_HIDEGRID = nil
		end
		if playerClass == "DRUID" or playerClass == "ROGUE" then
			self:RegisterEvent("UNIT_COMBO_POINTS")
			self:RegisterEvent("UPDATE_STEALTH")	
		else
			self.UNIT_COMBO_POINTS = nil
			self.UPDATE_STEALTH = nil
		end
		--if playerClass == "DRUID" then
			self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "ScheduleUpdate", 0.5)	
		--end
		if playerClass == "SHAMAN" and settings.DefaultExtraBar then
			self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
			ABtotembar = true
		end
		if playerClass == "DRUID" or playerClass == "WARRIOR" or playerClass == "PALADIN" or Casts then
			self.powerBucket = self:RegisterBucketEvent("UNIT_POWER", settings.TimerUnitPower)
		end
		self:RegisterEvent("EXECUTE_CHAT_LINE")
		self:RegisterEvent("PLAYER_TARGET_CHANGED")
		self:RegisterEvent("UNIT_AURA")
		self:RegisterEvent("ACTIONBAR_HIDEGRID")
		self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
		self:RegisterEvent("UPDATE_MACROS", "ScheduleUpdate", 1)
		--self:RegisterEvent("LEARNED_SPELL_IN_TAB", "ScheduleUpdate", 1)
		playerEvents = true
	end
end

function DrDamage:RefreshConfig(cb, reset)
	if self.Caster_RefreshConfig then self:Caster_RefreshConfig() end
	if self.Melee_RefreshConfig then self:Melee_RefreshConfig() end
	settings = self.db.profile
	if reset then
		DrD_Font = DrDamage.defaults.profile.Font
	end
	if cb then
		ManaCost = (settings.DisplayType2 == "ManaCost")
		PowerCost = (settings.DisplayType_M2 == "PowerCost")
		ABfont = true
		self:UpdateAB()
	end
end

function DrDamage:OpenConfig()
	InterfaceOptionsFrame:Hide()
	ACD:SetDefaultSize("DrDamage", 850, 725)
	ACD:Open("DrDamage")
	ACD:SelectGroup("DrDamage", "General", "Actionbar")
	--Dirty hack to make numbers properly appear in 'range' sliders
	ACD:Open("DrDamage")
end

function DrDamage:CommonData()
	if select(2, UnitRace("player")) == "Draenei" then
		self.ClassSpecials[GetSpellInfo(28880) or "Gift of the Naaru"] = function()
			local target = UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("target","player") and "target" or "player"
			return 0.2 * UnitHealthMax(target), true
		end
	end
	if select(2, UnitRace("player")) == "BloodElf" then
		if playerClass == "PALADIN" or playerClass == "PRIEST" or playerClass == "MAGE" or playerClass == "WARLOCK" then
			self.ClassSpecials[GetSpellInfo(28730) or "Arcane Torrent"] = function()
				return 0.06 * UnitPowerMax("player",0), false, true
			end
		end
	end
	if select(2, UnitRace("player")) == "Goblin" then
		--self.ClassSpecials[GetSpellInfo(69041) or "Rocket Barrage"] = function()
		--end
		spellInfo[GetSpellInfo(69041)] = {
					["Name"] = "Rocket Barrage",
					["ID"] = 69041,
					[0] = { School = "Fire", NoCrits = true, SpellHit = true, Cooldown = 120, APBonus = 0.25, SPBonus = 0.429, Unresistable = true, NoSchoolTalents = true, NoCasts = true },
					[1] = { 1, 1, },
		}
		self.Calculation["Rocket Barrage"] = function( calculation )
			local levelbonus = calculation.playerLevel * 2
			--local intbonus = 0.50193 * calculation.intM * math_max(0,UnitStat("player",4) + calculation.int)
			calculation.minDam = calculation.minDam + levelbonus --+ intbonus
			calculation.maxDam = calculation.minDam
		end
	end
end

function DrDamage:GeneralOptions()
	self.options.args.General = {
		type = 'group',
		name = "DrDamage",
		order = 1,
		args = {
			Actionbar = {
				type = 'group',
				name = L["Actionbar"],
				desc = L["Actionbar options."],
				order = 50,
				args = {
					AddonTitle = {
						type = 'header',
						name = "DrDamage " .. GetAddOnMetadata("DrDamage", "version"),
						order = 0,
					},
					DisplayTypeText = {
						type= 'description',
						order = 1,
						name= L["Choose what to display on the actionbar."],
					},					
					DisplayType = {
						type = 'select',
						name = "1. " .. (playerHybrid and L["Spells"] or ""),
						desc = L["Choose what to display on the actionbar."],
						order = 2,
						hidden = playerMelee,
						values = {
							["Avg"] = L["Average"],
							["AvgHit"] = L["Average Hit"],
							["PerHit"] = L["Per Hit"],
							["AvgHitTotal"] = L["Average Hit + Extra"],
							["AvgTotal"] = L["Average Total"],
							["MinHit"] = L["Min Hit"],
							["MaxHit"] = L["Max Hit"],
							["AvgCrit"] = L["Average Crit"],
							["MinCrit"] = L["Min Crit"],
							["MaxCrit"] = L["Max Crit"],
							["MaxTotal"] = L["Max Total"],
							["DPS"] = L["DPS"],
							["DPSC"] = L["DPSC"],
							["DPSCD"] = L["DPSCD"],
							["DPM"] = L["DPM"],
							["MPS"] = L["MPS"],
							["CastTime"] = L["Cast Time"],
							["1"] = L["Disabled"],
						},
						get = function() return settings["DisplayType"] or "1" end,
						set = function(info, v)
								if v == "1" then
									settings["DisplayType"] = false
								else
									settings["DisplayType"] = v
									if not settings.ABText then
										settings.ABText = true
										self:TextEvents()
									end
								end
								self:UpdateAB()
						end,
					},
					DisplayType2 = {
						type = 'select',
						name = "2. " .. (playerHybrid and L["Spells"] or ""),
						desc = L["Choose what to display on the actionbar."],
						order = 3,
						hidden = playerMelee,
						values = {
							["Avg"] = L["Average"],
							["AvgHit"] = L["Average Hit"],
							["PerHit"] = L["Per Hit"],
							["AvgHitTotal"] = L["Average Hit + Extra"],
							["AvgTotal"] = L["Average Total"],
							["MinHit"] = L["Min Hit"],
							["MaxHit"] = L["Max Hit"],
							["AvgCrit"] = L["Average Crit"],
							["MinCrit"] = L["Min Crit"],
							["MaxCrit"] = L["Max Crit"],
							["MaxTotal"] = L["Max Total"],
							["DPS"] = L["DPS"],
							["DPSC"] = L["DPSC"],
							["DPSCD"] = L["DPSCD"],
							["DPM"] = L["DPM"],
							["MPS"] = L["MPS"],
							["CastTime"] = L["Cast Time"],
							["ManaCost"] = L["Mana Cost"],
							["Casts"] = L["Casts"],
							["1"] = L["Disabled"],
						},
						get = function() return settings["DisplayType2"] or "1" end,
						set = function(info, v)
								if v == "1" then
									settings["DisplayType2"] = false
								else
									settings["DisplayType2"] = v
									if not settings.ABText then
										settings.ABText = true
										self:TextEvents()
									end						
									if v == "Casts" then
										if not self.powerBucket then
											self.powerBucket = self:RegisterBucketEvent("UNIT_POWER", 3)
										end
									end
								end
								ManaCost = (v == "ManaCost")
								Casts = (v == "Casts")								
								self:UpdateAB()
						end,
					},
					NewLine1 = {
						type= 'description',
						order = 4,
						name= '',
					},
					DisplayType_M = {
						type = 'select',
						name = "1. " .. (playerHybrid and (L["Melee"] .. "/" .. L["Ranged"]) or ""),
						desc = L["Choose what to display on the actionbar."],
						order = 5,
						hidden = playerCaster,
						values = {
							["Avg"] = L["Average"],
							["AvgTotal"] = L["Average Total"],
							["AvgHit"] = L["Average Hit"],
							["AvgHitTotal"] = L["Average Hit + Extra"],
							["MinHit"] = L["Min Hit"],
							["MaxHit"] = L["Max Hit"],
							["MaxTotal"] = L["Max Total"],
							["AvgCrit"] = L["Average Crit"],
							["MinCrit"] = L["Min Crit"],
							["MaxCrit"] = L["Max Crit"],
							["DPM"] = (playerClass == "ROGUE" and L["DPE"] or playerClass == "WARRIOR" and L["DPR"] or playerClass == "DRUID" and L["DPP"] or L["DPM"]),
							["1"] = L["Disabled"],
						},
						get = function() return settings["DisplayType_M"] or "1" end,
						set = function(info,v)
							if v == "1" then
								settings["DisplayType_M"] = false
							else
								settings["DisplayType_M"] = v
								if not settings.ABText then
									settings.ABText = true
									self:TextEvents()
								end
							end
							self:UpdateAB()
						end,
					},
					DisplayType_M2 = {
						type = 'select',
						name = "2. " .. (playerHybrid and (L["Melee"] .. "/" .. L["Ranged"]) or ""),
						desc = L["Choose what to display on the actionbar."],
						order = 6,
						hidden = playerCaster,
						values = {
							["Avg"] = L["Average"],
							["AvgTotal"] = L["Average Total"],
							["AvgHit"] = L["Average Hit"],
							["AvgHitTotal"] = L["Average Hit + Extra"],
							["MinHit"] = L["Min Hit"],
							["MaxHit"] = L["Max Hit"],
							["MaxTotal"] = L["Max Total"],
							["AvgCrit"] = L["Average Crit"],
							["MinCrit"] = L["Min Crit"],
							["MaxCrit"] = L["Max Crit"],
							["DPM"] = (playerClass == "ROGUE" and L["DPE"] or playerClass == "WARRIOR" and L["DPR"] or playerClass == "DRUID" and L["DPP"] or L["DPM"]),
							["DPS"] = L["DPS"],
							["DPSCD"] = L["DPSCD"],
							["PowerCost"] = L["Power Cost"],
							["1"] = L["Disabled"],
						},
						get = function() return settings["DisplayType_M2"] or "1" end,
						set = function(info,v)
							if v == "1" then
								settings["DisplayType_M2"] = false
							else
								settings["DisplayType_M2"] = v
								if not settings.ABText then
									settings.ABText = true
									self:TextEvents()
								end
							end
							PowerCost = (v == "PowerCost")
							self:UpdateAB()
						end,
					},
					Update = {
						type = 'multiselect',
						name = L["Actionbar"],
						order = 22,
						width = 'full',
						values = {
								["ABText"] = L["Actionbar text on/off"],
								["DefaultAB"] =	L["Default actionbar support"],
								["DefaultExtraBar"] = L["Default totem, pet and aura bar support (Reload UI)"],
								["SwapCalc"] = L["Swap calculation for double purpose abilities"],
								["UpdateShift"] = L["Update the actionbar with shift key"],
								["UpdateAlt"] = L["Update the actionbar with alt key"],
								["UpdateCtrl"] = L["Update the actionbar with ctrl key"],
								["HideAMacro"] = L["Hide macro name text"],
								["HideHotkey"] = L["Hide hotkey text"],
								["DisableUpdates"] = L["Disable actionbar updates in combat"],
								["ShortenText"] = L["Shorten large number text"],
							},
						get = function(v, k) return settings[k] end,
						set = function(info, k, v)
							if (k == "UpdateShift") or (k == "UpdateAlt") or (k == "UpdateCtrl") then
								settings[k] = v
								if v and not ModStateEvent then
									self:RegisterEvent("MODIFIER_STATE_CHANGED")
									ModStateEvent = true
								elseif ModStateEvent and not settings.UpdateAlt and not settings.UpdateCtrl and not settings.UpdateShift then
									self:UnregisterEvent("MODIFIER_STATE_CHANGED")
									ModStateEvent = false
								end
							else
								if (k == "DefaultAB") then
									if v then
										settings.DefaultAB = true
										self:UpdateAB()
									else
										self:UpdateAB(nil, nil, true)
										settings.DefaultAB = false
									end
								else
									settings[k] = v
									self:UpdateAB()
									if (k == "ABText") and v and not playerEvents then
										self:TextEvents()
									end
								end
							end

						end,
					},
					FontXPosition = {
						type = 'range',
						name = "1. " .. L["Text X Position"],
						min = -20,
						max = 20,
						step = 1,
						order = 31,
						get = function() return settings["FontXPosition"] end,
						set = function(i, v)
							settings["FontXPosition"] = v
							ABfont = true
							self:UpdateAB()
						end,
					},
					FontYPosition = {
						type = 'range',
						name = "1. " ..L["Text Y Position"],
						min = -40,
						max = 40,
						step = 1,
						order = 32,
						get = function() return settings["FontYPosition"] end,
						set = function(i, v)
							settings["FontYPosition"] = v
							ABfont = true
							self:UpdateAB()
						end,
					},
					NewLine2 = {
						type= 'description',
						order = 33,
						name= '',
					},
					FontXPosition2 = {
						type = 'range',
						name = "2. " .. L["Text X Position"],
						min = -20,
						max = 20,
						step = 1,
						order = 36,
						disabled = function() return not (settings.DisplayType2 or settings.DisplayType_M2) end,
						get = function() return settings["FontXPosition2"] end,
						set = function(i, v)
							settings["FontXPosition2"] = v
							ABfont = true
							self:UpdateAB()
						end,
					},
					FontYPosition2 = {
						type = 'range',
						name = "2. " .. L["Text Y Position"],
						min = -40,
						max = 40,
						step = 1,
						order = 37,
						disabled = function() return not (settings.DisplayType2 or settings.DisplayType_M2) end,
						get = function() return settings["FontYPosition2"] end,
						set = function(i, v)
							settings["FontYPosition2"] = v
							ABfont = true
							self:UpdateAB()
						end,
					},
					NewLine3 = {
						type= 'description',
						order = 38,
						name= '',
					},
					FontSize = {
						type = 'range',
						name = L["Font Size"],
						min = 4,
						max = 24,
						step = 1,
						order = 60,
						get = function() return settings["FontSize"] end,
						set = function(i, v)
							settings["FontSize"] = v
							ABfont = true
							self:UpdateAB()
						end,
					},
					UpdateAB = {
						type = 'execute',
						name = L["Update Actionbar"],
						desc = L["Forces an update to the actionbar."],
						order = 61,
						func = function() ABfont = true; self:UpdateAB() end,
					},
					NewLine4 = {
						type= 'description',
						order = 62,
						name= '',
					},
					FontEffect = {
						type = 'select',
						name = L["Font Effect"],
						values = { ["OUTLINE"] = L["Outline"], ["THICKOUTLINE"] = L["ThickOutline"], [""] = L["None"] },
						order = 65,
						get =	function() return settings["FontEffect"] end,
						set = 	function(i, v)
							settings["FontEffect"] = v
							ABfont = true
							self:UpdateAB()
						end,
					},
					TextTitle = {
						type = 'header',
						name = L["Text color"],
						order = 67,
					},
					FontColorDmg = {
						type = 'color',
						name = L["Damage text color"],
						order = 70,
						get = function() return settings.FontColorDmg.r, settings.FontColorDmg.g, settings.FontColorDmg.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorDmg.r = rr
							settings.FontColorDmg.g = gg
							settings.FontColorDmg.b = bb
							self:UpdateAB()
						end,
					},
					FontColorHeal = {
						type = 'color',
						name = L["Heal text color"],
						order =75,
						get = function() return settings.FontColorHeal.r, settings.FontColorHeal.g, settings.FontColorHeal.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorHeal.r = rr
							settings.FontColorHeal.g = gg
							settings.FontColorHeal.b = bb
							self:UpdateAB()
						end,
					},
					NewLine5 = {
						type= 'description',
						order = 76,
						name= '',
						hidden = (playerClass ~= "DRUID")
					},
					FontColorMana = {
						type = 'color',
						name = L["Mana text color"],
						order = 80,
						hidden = (playerMelee or playerClass == "DEATHKNIGHT"),
						get = function() return settings.FontColorMana.r, settings.FontColorMana.g, settings.FontColorMana.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorMana.r = rr
							settings.FontColorMana.g = gg
							settings.FontColorMana.b = bb
							self:UpdateAB()
						end,
					},
					FontColorRage = {
						type = 'color',
						name = L["Rage text color"],
						order = 82,
						hidden = (playerClass ~= "DRUID" and playerClass ~= "WARRIOR"),
						get = function() return settings.FontColorRage.r, settings.FontColorRage.g, settings.FontColorRage.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorRage.r = rr
							settings.FontColorRage.g = gg
							settings.FontColorRage.b = bb
							self:UpdateAB()
						end,
					},
					FontColorEnergy = {
						type = 'color',
						name = L["Energy text color"],
						order = 83,
						hidden = (playerClass ~= "DRUID" and playerClass ~= "ROGUE"),
						get = function() return settings.FontColorEnergy.r, settings.FontColorEnergy.g, settings.FontColorEnergy.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorEnergy.r = rr
							settings.FontColorEnergy.g = gg
							settings.FontColorEnergy.b = bb
							self:UpdateAB()
						end,
					},
					NewLine6 = {
						type= 'description',
						order = 84,
						name= '',
						hidden = (playerClass == "DRUID")
					},
					FontColorCasts1 = {
						type = 'color',
						name = L["Casts text color"] .. " 1",
						order = 85,
						hidden = playerMelee or playerClass == "DEATHKNIGHT",
						get = function() return settings.FontColorCasts1.r, settings.FontColorCasts1.g, settings.FontColorCasts1.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorCasts1.r = rr
							settings.FontColorCasts1.g = gg
							settings.FontColorCasts1.b = bb
							self:UpdateAB()
						end,
					},
					FontColorCasts2 = {
						type = 'color',
						name = L["Casts text color"] .. " 2",
						order = 90,
						hidden = playerMelee or playerClass == "DEATHKNIGHT",
						get = function() return settings.FontColorCasts2.r, settings.FontColorCasts2.g, settings.FontColorCasts2.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorCasts2.r = rr
							settings.FontColorCasts2.g = gg
							settings.FontColorCasts2.b = bb
							self:UpdateAB()
						end,
					},
					FontColorCasts3 = {
						type = 'color',
						name = L["Casts text color"] .. " 3",
						order = 95,
						hidden = playerMelee or playerClass == "DEATHKNIGHT",
						get = function() return settings.FontColorCasts3.r, settings.FontColorCasts3.g, settings.FontColorCasts3.b end,
						set = function(info,rr,gg,bb)
							settings.FontColorCasts3.r = rr
							settings.FontColorCasts3.g = gg
							settings.FontColorCasts3.b = bb
							self:UpdateAB()
						end,
					},
					TimerTitle = {
						type = 'header',
						name = L["Actionbar update timers"],
						order = 100,
					},
					UpdateTimer1 = {
						type = 'range',
						name = L["Player aura"],
						min = 0.1,
						max = 30,
						step = 0.1,
						order = 105,
						get = function() return settings["TimerPlayerAura"] end,
						set = function(i, v) settings["TimerPlayerAura"] = v end,
					},
					UpdateTimer2 = {
						type = 'range',
						name = L["Target aura"],
						min = 0.1,
						max = 30,
						step = 0.1,
						order = 110,
						get = function() return settings["TimerTargetAura"] end,
						set = function(i, v) settings["TimerTargetAura"] = v end,
					},
					UpdateTimer11 = {
						type = 'range',
						name = L["Weapon buff"],
						desc = L["Changes require reloading UI to apply."],
						min = 0.5,
						max = 30,
						step = 0.1,
						order = 112,
						hidden = (playerClass ~= "SHAMAN") and (playerClass ~= "ROGUE") and (playerClass ~= "DEATHKNIGHT"),
						get = function() return settings["TimerInventory"] end,
						set = function(i, v) settings["TimerInventory"] = v end,
					},					
					UpdateTimer3 = {
						type = 'range',
						name = L["Unit health"],
						desc = L["Changes require reloading UI to apply."],
						min = 0.1,
						max = 30,
						step = 0.1,
						order = 115,
						get = function() return settings["TimerUnitHealth"] end,
						set = function(i, v) settings["TimerUnitHealth"] = v end,
					},
					UpdateTimer4 = {
						type = 'range',
						name = L["Player power"],
						desc = L["Changes require reloading UI to apply."],
						min = 0.1,
						max = 30,
						step = 0.1,
						order = 120,
						get = function() return settings["TimerUnitPower"] end,
						set = function(i, v) settings["TimerUnitPower"] = v end,
					},
					UpdateTimer5 = {
						type = 'range',
						name = L["Combo points"],
						min = 0,
						max = 30,
						step = 0.1,
						order = 125,
						hidden = (playerClass ~= "DRUID") and (playerClass ~= "ROGUE"),
						get = function() return settings["TimerComboPoints"] end,
						set = function(i, v) settings["TimerComboPoints"] = v end,
					},
					UpdateTimer6 = {
						type = 'range',
						name = L["Target change"],
						min = 0,
						max = 30,
						step = 0.1,
						order = 130,
						get = function() return settings["TimerTarget"] end,
						set = function(i, v) settings["TimerTarget"] = v end,
					},
					UpdateTimer7 = {
						type = 'range',
						name = L["Stealth"],
						min = 0.2,
						max = 30,
						step = 0.1,
						order = 135,
						hidden = (playerClass ~= "DRUID") and (playerClass ~= "ROGUE"),
						get = function() return settings["TimerStealth"] end,
						set = function(i, v) settings["TimerStealth"] = v end,
					},
					UpdateTimer8 = {
						type = 'range',
						name = L["Modifier key"],
						min = 0.1,
						max = 5,
						step = 0.1,
						order = 140,
						get = function() return settings["TimerModifier"] end,
						set = function(i, v) settings["TimerModifier"] = v end,
					},
					UpdateTimer9 = {
						type = 'range',
						name = L["Actionbar page"],
						min = 0,
						max = 5,
						step = 0.1,
						order = 145,
						get = function() return settings["TimerActionbarPage"] end,
						set = function(i, v) settings["TimerActionbarPage"] = v end,
					},
					UpdateTimer10 = {
						type = 'range',
						name = L["Drag spell"],
						min = 0.1,
						max = 5,
						step = 0.1,
						order = 150,
						get = function() return settings["TimerHideGrid"] end,
						set = function(i, v) settings["TimerHideGrid"] = v end,
					},
				},
			},
			Tooltip = {
				type = 'group',
				name = L["Tooltip"],
				desc = L["Tooltip options."],
				order = 55,
				args = {
					DisplayTooltip = {
						type = 'select',
						name = L["Display tooltip"] ,
						values = {
							["Always"] = L["Always"],
							["Never"] = L["Never"],
							["Combat"] = L["Disable in combat"],
							["Alt"] = L["With Alt"],
							["Ctrl"] = L["With Ctrl"],
							["Shift"]= L["With Shift"]
						},
						order = 5,
						get = function() return settings.Tooltip end,
						set = function(info, k, v)
							settings.Tooltip = k
						end,
					},
					Hints = {
						type = 'toggle',
						name = L["Display tooltip hints"],
						order = 10,
						width = 'full',
						get = function() return settings["Hints"] end,
						set = function(i, v) self:ClearTooltip(); settings["Hints"] = v end,
					},
					Tooltip = {
						type = 'multiselect',
						name = L["Display"],
						order = 15,
						values = {
							["Coeffs"] = L["Show coefficients"],
							["DispCrit"]= L["Show crit %"],
							["DispHit"] = L["Show hit %"],
							["AvgHit"] = L["Show avg and hit range"],
							["AvgCrit"] = L["Show avg crit and crit range"],
							["Ticks"] = L["Show per tick"],
							["Total"] = L["Show avg total"],
							["Extra"] = L["Show additional effects"],
							["Next"] = L["Show stat increase values"],
							["DPS"] = L["Show DPS/HPS"],
							["CompareStats"] = L["Show stats for 1% increase"],
						},
						get = function(v, k) return settings[k] end,
						set = function(info, k, v) self:ClearTooltip(); settings[k] = v end,
					},
					Compare = {
						type = 'multiselect',
						name = L["Compare stats"],
						desc = L["Compare the selected stat to other stats in the tooltip."],
						order = 20,
						values = {
							["CompareMastery"] = L["Mastery rating"],
							["CompareCrit"] = L["Critical strike rating"],
							["CompareHit"] = L["Hit rating"],
						},
						get = function(v, k) return settings[k] end,
						set = function(info, k, v) self:ClearTooltip(); settings[k] = v end,
					},
					TooltipTextTitle = {
						type = 'header',
						name = L["Tooltip text color"],
						order = 20,
					},
					DefaultColor = {
						type = 'toggle',
						name = L["Default tooltip colors"],
						order = 25,
						width = 'full',
						get = function() return settings["DefaultColor"] end,
						set = function(i, v) self:ClearTooltip(); settings["DefaultColor"] = v end,
					},
					TooltipTextColor1 = {
						type = 'color',
						name = L["Tooltip text color"] .. " 1",
						order = 65,
						get = function() return settings.TooltipTextColor1.r, settings.TooltipTextColor1.g, settings.TooltipTextColor1.b end,
						set = function(info,rr,gg,bb)
							self:ClearTooltip()
							settings.TooltipTextColor1.r = rr
							settings.TooltipTextColor1.g = gg
							settings.TooltipTextColor1.b = bb
						end,
					},
					TooltipTextColor2 = {
						type = 'color',
						name = L["Tooltip text color"] .. " 2",
						order = 70,
						get = function() return settings.TooltipTextColor2.r, settings.TooltipTextColor2.g, settings.TooltipTextColor2.b end,
						set = function(info,rr,gg,bb)
							self:ClearTooltip()
							settings.TooltipTextColor2.r = rr
							settings.TooltipTextColor2.g = gg
							settings.TooltipTextColor2.b = bb
						end,
					},
					TooltipTextColor3 = {
						type = 'color',
						name = L["Tooltip text color"] .. " 3",
						order = 75,
						get = function() return settings.TooltipTextColor3.r, settings.TooltipTextColor3.g, settings.TooltipTextColor3.b end,
						set = function(info,rr,gg,bb)
							self:ClearTooltip()
							settings.TooltipTextColor3.r = rr
							settings.TooltipTextColor3.g = gg
							settings.TooltipTextColor3.b = bb
						end,
					},
					TooltipTextColor4 = {
						type = 'color',
						name = L["Tooltip text color"] .. " 4",
						order = 80,
						get = function() return settings.TooltipTextColor4.r, settings.TooltipTextColor4.g, settings.TooltipTextColor4.b end,
						set = function(info,rr,gg,bb)
							self:ClearTooltip()
							settings.TooltipTextColor4.r = rr
							settings.TooltipTextColor4.g = gg
							settings.TooltipTextColor4.b = bb
						end,
					},
					TooltipTextColor5 = {
						type = 'color',
						name = L["Tooltip text color"] .. " 5",
						order = 85,
						get = function() return settings.TooltipTextColor5.r, settings.TooltipTextColor5.g, settings.TooltipTextColor5.b end,
						set = function(info,rr,gg,bb)
							self:ClearTooltip()
							settings.TooltipTextColor5.r = rr
							settings.TooltipTextColor5.g = gg
							settings.TooltipTextColor5.b = bb
						end,
					},
					TooltipTextColor6 = {
						type = 'color',
						name = L["Tooltip text color"] .. " 6",
						order = 90,
						get = function() return settings.TooltipTextColor6.r, settings.TooltipTextColor6.g, settings.TooltipTextColor6.b end,
						set = function(info,rr,gg,bb)
							self:ClearTooltip()
							settings.TooltipTextColor6.r = rr
							settings.TooltipTextColor6.g = gg
							settings.TooltipTextColor6.b = bb
						end,
					},
				},

			},
			Calculation = {
				type = 'group',
				name = L["Calculation"],
				desc = L["Calculation options."],
				order = 60,
				args = {
					General = {
						type = 'multiselect',
						name = L["Calculation"],
						width = 'full',
						values = {
							["HitCalc"] = L["Hit calculation"],
							["CritDepression"] = L["Crit depression calculation"],
						},
						order = 10,
						get = function(v, k) return settings[k] end,
						set = function(info, k, v)
							settings[k] = v
							self:UpdateAB()
						end,
					},
					TargetAmount = {
						type = 'range',
						name = L["Amount of targets"],
						desc = L["Select the maximum amount of targets for your AoE abilities."],
						min = 1,
						max = 20,
						step = 1,
						order = 45,
						get = function() return settings["TargetAmount"] end,
						set = function(info, v) settings["TargetAmount"] = v; self:UpdateAB() end,
					},
					ComboPoints = {
						type = 'range',
						name = L["Combo points"],
						desc = L["Manually set the amount of calculated combo points. When 0 is selected, the calculation is based on the current amount."],
						min = 0,
						max = 5,
						step = 1,
						order = 50,
						hidden = (playerClass ~= "ROGUE" and playerClass ~= "DRUID"),
						get = function() return settings["ComboPoints"] end,
						set = function(info,v) settings["ComboPoints"] = v; self:UpdateAB() end,
					},
					MitigationTitle = {
						type = 'header',
						name = L["Target mitigation calculation"],
						order = 55,
					},
					TargetLevel = {
						type = 'select',
						name = L["Target level"],
						desc = L["Target level compared to your level. Set as 3 for boss calculation."],
						values = {
							[0] = L["Current Target"],
							[1] = "+1",
							[2] = "+2",
							[3] = "+3",
						},
						order = 60,
						get = function() return settings["TargetLevel"] end,
						set = function(info, v) settings["TargetLevel"] = v; self:UpdateAB() end,
					},
					ArmorCalc = {
						type = 'select',
						name = L["Armor calculation"],
						values = {
							["Auto"] = L["Automatic"] .. "/" .. L["Manual"],
							["Boss"] = L["Boss"],
							["Manual"] = L["Manual"],
							["None"] = L["None"],
						},
						order = 65,
						hidden = playerCaster,
						get = function() return settings["ArmorCalc"] end,
						set = function(info, v) settings["ArmorCalc"] = v; self:UpdateAB() end,
					},
					NewLine1 = {
						type= 'description',
						order = 70,
						name= '',
					},
					Armor = {
						type = 'range',
						name = L["Target armor"],
						desc = L["Estimated target armor for non-boss enemies."],
						min = 0,
						max = 50000,
						step = 1,
						order = 75,
						hidden = playerCaster,
						disabled = function() return (settings.ArmorMitigation > 0) end,
						get = function()
							if settings.ArmorMitigation > 0 then
								settings.Armor = 0
								return math_floor(self:GetArmor(settings.ArmorMitigation) + 0.5)
							else
								return settings.Armor
							end
						end,
						set = function(info,v) settings["Armor"] = v; self:UpdateAB() end,
					},
					ArmorMitigation = {
						type = 'range',
						name = L["Target armor"] .. " %",
						desc = L["Estimated target armor for non-boss enemies."],
						min = 0,
						max = 75,
						order = 77,
						hidden = playerCaster,
						disabled = function() return (settings.Armor > 0) end,
						get = function()
							if settings.Armor > 0 then
								settings.ArmorMitigation = 0
								return self:GetMitigation(settings.Armor) * 100
							else
								return settings.ArmorMitigation * 100
							end
						end,
						set = function(info,v) settings["ArmorMitigation"] = v / 100; self:UpdateAB() end,
					},
					Resilience = {
						type = 'range',
						name = L["Target resilience"],
						desc = L["Input your target's resilience."],
						min = 0,
						max = 50000,
						step = 1,
						order = 80,
						get = function() return settings["Resilience"] end,
						set = function(info,v) settings["Resilience"] = v; self:UpdateAB() end,
					},
				},
			},
			Custom = {
				type = 'group',
				name = L["Modify Stats"],
				--desc = "",
				order = 95,
				args = {
					Custom = {
						type = 'toggle',
						name = L["Use custom stats"],
						desc = L["Manually set stats are used in calculations."],
						descStyle = 'inline',
						order = 50,
						width = 'full',
						get = function() return settings["Custom"] end,
						set = function(info, v) settings["Custom"] = v; self:UpdateAB() end,
					},
					CustomAdd = {
						type = 'toggle',
						name = L["Add custom stats"],
						desc = L["Manually set stats are added to your stats in calculations."],
						descStyle = 'inline',
						order = 55,
						width = 'full',
						get = function() return settings["CustomAdd"] end,
						set = function(info, v) settings["CustomAdd"] = v; self:UpdateAB() end,
					},
					Strength = {
						type = 'range',
						name = L["Strength"],
						desc = L["Input strength to use in calculations."],
						min = -20000,
						max = 20000,
						step = 1,
						order = 60,
						hidden = playerCaster,
						get = function() return settings["Str"] end,
						set = DrD_Set("Str"),
					},
					Agility = {
						type = 'range',
						name = L["Agility"],
						desc = L["Input agility to use in calculations."],
						min = -20000,
						max = 20000,
						step = 1,
						order = 65,
						hidden = playerCaster,
						get = function() return settings["Agi"] end,
						set = DrD_Set("Agi"),
					},
					Intellect = {
						type = 'range',
						name = L["Intellect"],
						desc = L["Input intellect to use in calculations."],
						min = -20000,
						max = 20000,
						step = 1,
						order = 70,
						hidden = playerMelee,
						get = function() return settings["Int"] end,
						set = DrD_Set("Int"),
					},
					Spirit = {
						type = 'range',
						name = L["Spirit"],
						desc = L["Input spirit to use in calculations."],
						min = -20000,
						max = 20000,
						step = 1,
						order = 75,
						hidden = playerMelee,
						get = function() return settings["Spi"] end,
						set = DrD_Set("Spi"),
					},
					SP = {
						type = 'range',
						name = L["Spell power"],
						desc = L["Input spell power to use in calculations."],
						min = -50000,
						max = 50000,
						step = 1,
						order = 105,
						hidden = playerMelee or (playerClass == "DEATHKNIGHT"),
						get = function() return settings["SP"] end,
						set = DrD_Set("SP"),
					},
					AP = {
						type = 'range',
						name = L["AP"] .. " / " .. L["RAP"],
						desc = L["Input attack power to use in calculations."],
						min = -50000,
						max = 50000,
						step = 1,
						order = 106,
						hidden = playerCaster,
						get = function() return settings["AP"] end,
						set = DrD_Set("AP"),
					},
					CritRating = {
						type = 'range',
						name = L["Critical strike rating"],
						desc = L["Input critical strike rating to use in calculations."],
						min = -5000,
						max = 50000,
						step = 1,
						order = 110,
						get = function() return settings["CritRating"] end,
						set = DrD_Set("CritRating"),
					},
					HitRating = {
						type = 'range',
						name = L["Hit rating"],
						desc = L["Input hit rating to use in calculations."],
						min = -5000,
						max = 50000,
						step = 1,
						order = 115,
						get = function() return settings["HitRating"] end,
						set = DrD_Set("HitRating"),
					},
					HasteRating = {
						type = 'range',
						name = L["Haste rating"],
						desc = L["Input haste rating to use in calculations."],
						min = -5000,
						max = 50000,
						step = 1,
						order = 120,
						get = function() return settings["HasteRating"] end,
						set = DrD_Set("HasteRating"),
					},
					ExpertiseRating = {
						type = 'range',
						name = L["Expertise rating"],
						desc = L["Input expertise rating to use in calculations."],
						min = -5000,
						max = 50000,
						step = 1,
						order = 125,
						hidden = playerCaster,
						get = function() return settings["ExpertiseRating"] end,
						set = DrD_Set("ExpertiseRating"),
					},
					MasteryRating = {
						type = 'range',
						name = L["Mastery rating"],
						desc = L["Input mastery rating to use in calculations."],
						min = -5000,
						max = 50000,
						step = 1,
						order = 130,
						get = function() return settings["MasteryRating"] end,
						set = DrD_Set("MasteryRating"),
					},
					--[[
					ManaPer5 = {
						type = 'range',
						name = L["Mana per 5"],
						desc = L["Input MP5 to use in calculations."],
						min = -5000,
						max = 50000,
						step = 1,
						order = 125,
						hidden = playerMelee or (playerClass == "DEATHKNIGHT"),
						get = function() return settings["MP5"] end,
						set = DrD_Set("MP5"),
					},
					--]]
				},
			},
			Aura = {
				type = 'group',
				name = L["Modify Buffs/Debuffs"],
				desc = L["Choose what buffs/debuffs to always include into calculations."],
				order = 100,
				args = {
					Player = {
						type = 'multiselect',
						name = L["Player"],
						desc = L["Choose player buffs/debuffs."],
						order = 1,
						values = {},
						get = function(v, k) return settings["PlayerAura"][k] end,
						set = function(info, k, v)
							local cat = PlayerAura[k].Category
							if v and cat then
								for n in pairs( settings["PlayerAura"] ) do
									local ocat = PlayerAura[n].Category
									if ocat and (cat == ocat) then
										settings["PlayerAura"][n] = nil
									end
								end
							end
							settings["PlayerAura"][k] = v or nil
							self:UpdateAB()
						end,
					},
					Target = {
						type = 'multiselect',
						name = L["Target"],
						desc = L["Choose target buffs/debuffs."],
						values = {},
						order = 3,
						get = function(v, k) return settings["TargetAura"][k] end,
						set = function(info, k, v)
							local cat = TargetAura[k].Category
							if v and cat then
								for n in pairs( settings["TargetAura"] ) do
									local ocat = TargetAura[n].Category
									if ocat and (cat == ocat) then
										settings["TargetAura"][n] = nil
									end
								end
							end
							settings["TargetAura"][k] = v or nil
							self:UpdateAB()
						end,
					},
					Consumables = {
						type = 'multiselect',
						name = L["Consumables"],
						desc = L["Choose consumables to include."],
						values = {},
						order = 2,
						get = function(v, k) return settings["Consumables"][k] end,
						set = function(info, k, v)
							local cat = self.Consumables[k].Category
							local cat2 = self.Consumables[k].Category2
							if v and cat then
								for n in pairs( settings.Consumables ) do
									local ocat = self.Consumables[n].Category
									local ocat2 = self.Consumables[n].Category2
									if ocat and (cat == ocat or cat2 and cat2 == ocat or ocat2 and (cat == ocat2 or cat2 and ocat2 == cat2)) then
										settings.Consumables[n] = nil
									end
								end
							end
							settings["Consumables"][k] = v or nil
							self:UpdateAB()
						end,
					},
				},
			},
			Talents = {
				type = "group",
				name = L["Modify Talents"],
				desc = L["Modify talents manually. Modified talents are not saved between sessions."],
				order = 150,
				args = {
					Reset = {
						type = "execute",
						name = L["Reset Talents"],
						desc = L["Reset talents to your current talent configuration."],
						order = 0,
						--disabled = function() return self.CustomTalents end,
						func = function() self:UpdateTalents() end,
					},
					Remove = {
						type = "execute",
						name = L["Remove Talents"],
						desc = L["Removes all talents from your current configuration."],
						order = 1,
						--disabled = function() return self.CustomTalents end,
						func = function()
							for k in pairs( talents ) do
								if talentInfo[k].Manual then
									talents[k] = 0
								else
									talents[k] = nil
								end
							end
							self:UpdateTalents(true)
						end,
					},
				} ,
			},
			Reset = {
				type = 'group',
				name = L["Reset Options"],
				order = 200,
				args = {
					Reset = {
						type = 'execute',
						name = L["Reset Options"],
						confirm = true,
						order = 2,
						func = function() self.db:ResetProfile() end,
					},
				},
			},
		},
	}
	local optionsTable = self.options.args.General.args
	if playerCaster or playerHybrid then
		local tree = optionsTable.Calculation.args.General.values
		tree["TwoRoll"] = L["Two roll calculation"] .. " (" .. L["Spells"] .. ")"
		if playerClass ~= "DEATHKNIGHT" then
			tree["ManaConsumables"] = L["Include mana consumables"]
			tree = optionsTable.Tooltip.args.Tooltip.values
			tree["DPM"] = L["Show DPM/HPM"]
			tree["Doom"] = L["Show damage/healing until OOM"]
			tree["Casts"] = L["Show total casts and time until OOM"]
			tree["PlusDmg"] = L["Show efficient spellpower"]
			tree["ManaUsage"] = L["Show additional mana usage information"]
			tree = optionsTable.Tooltip.args.Compare.values
			tree["CompareInt"] = L["Intellect"]
			tree["CompareHaste"] = L["Haste rating"]
		else
			local types = optionsTable.Actionbar.args.DisplayType_M.values
			types["DPM"] = nil
			types = optionsTable.Actionbar.args.DisplayType_M2.values
			types["DPM"] = nil
			types = optionsTable.Actionbar.args.DisplayType.values
			types["DPM"] = nil
			types["MPS"] = nil
			types["CastTime"] = nil
			types = optionsTable.Actionbar.args.DisplayType2.values
			types["DPM"] = nil
			types["MPS"] = nil
			types["CastTime"] = nil
			types["ManaCost"] = nil
			types["Casts"] = nil
		end
		if playerHybrid then
			if playerClass ~= "DRUID" then
				optionsTable.Actionbar.args.DisplayType_M2.values["PowerCost"] = nil
			end
		end
	end
	if playerMelee or playerHybrid then
		local tree = optionsTable.Tooltip.args.Tooltip.values
		tree["DPP"] = L["Show damage per power"]
		tree = optionsTable.Tooltip.args.Compare.values
		tree["CompareStr"] = L["Strength"]
		tree["CompareAgi"] = L["Agility"]
		tree["CompareExp"] = L["Expertise rating"]
		tree["CompareAP"] = (playerClass == "HUNTER") and (L["AP"] .. "/" .. L["RAP"]) or L["AP"]
		tree = optionsTable.Calculation.args.General.values
		tree["Dodge"] = L["Dodge calculation"]
		tree["Parry"] = L["Parry calculation"]
		tree["Glancing"] = L["Glancing blow calculation"]
		tree["TwoRoll_M"] = L["Two roll calculation"] .. " (" .. L["Melee"] .. "/" .. L["Ranged"] .. ")"
	end
	if LSM then
		optionsTable.Actionbar.args.Font = {
			type = 'select',
			name = L["Font"],
			desc = L["Font"],
			values = LSM:HashTable("font"),
			order = 66,
			get = function()
				if LSM:GetGlobal("font") then
					return LSM:GetGlobal("font")
				end
				for k, v in pairs(LSM:HashTable("font")) do
					if settings["Font"] == v then
						return k
					end
				end
			end,
			set = function(info, v, k)
				if not LSM:GetGlobal("font") then
					settings.Font = LSM:Fetch("font",v)
					DrD_Font = settings.Font
					ABfont = true
					self:UpdateAB()
				end
			end,
		}
		if LibStub("AceGUISharedMediaWidgets-1.0") then
			optionsTable.Actionbar.args.Font.dialogControl = 'LSM30_Font'
		end
		if LSM:GetGlobal("font") then
			DrD_Font = LSM:Fetch("font")
		end

	end
	local auraTable = optionsTable.Aura.args.Player.values
	local double = {}
	for k,v in pairs( PlayerAura ) do
		if not v.Update and not v.NoManual then
			local manual = v.Manual
			if not manual or not double[manual] then
				if v.ID and GetSpellInfo(v.ID) then
					auraTable[k] = "|T" .. select(3,GetSpellInfo(v.ID)) .. ":17:17:-2:0|t" .. (manual or k)
				else
					auraTable[k] = manual or k
				end
				double[(manual or k)] = true
			else
				settings["PlayerAura"][k] = nil
			end
		else
			settings["PlayerAura"][k] = nil
		end
	end
	auraTable = optionsTable.Aura.args.Target.values
	double = {}
	for k,v in pairs( TargetAura ) do
		if not v.Update and not v.NoManual then
			local manual = v.Manual
			if not manual or not double[manual] then
				if v.ID and GetSpellInfo(v.ID) then
					auraTable[k] = "|T" .. select(3,GetSpellInfo(v.ID)) .. ":17:17:-2:0|t" .. (manual or k)
				else
					auraTable[k] = manual or k
				end
				double[(manual or k)] = true
			else
				settings["TargetAura"][k] = nil
			end
		else
			settings["TargetAura"][k] = nil
		end
	end
	auraTable = optionsTable.Aura.args.Consumables.values
	for k,v in pairs( self.Consumables ) do
		if v.Category == "Food" then
			auraTable[k] = "|TInterface\\Icons\\Spell_Misc_Food:17:17:-2:0|t" .. k
		elseif v.ID and GetSpellInfo(v.ID) then
			auraTable[k] = "|T" .. select(3,GetSpellInfo(v.ID)) .. ":17:17:-2:0|t" .. k
		elseif select(10,GetItemInfo(k)) then
			auraTable[k] = "|T" .. select(10,GetItemInfo(k)) .. ":17:17:-2:0|t" .. k
		else
			auraTable[k] = k
		end
	end
	local talentTable = optionsTable.Talents.args
	for t = 1, GetNumSpecializations() do
		for i = 1, GetNumTalents(t) do
			local talentName, icon, _, _, _, maxRank = GetTalentInfo(t, i)
			if talentInfo[talentName] and not talentInfo[talentName].NoManual then
				talentTable[(string_gsub(talentName," +", ""))] = {
					type = 'range',
					name = "|T" .. icon .. ":20:20:-5:0|t" .. talentName,
					--disabled = function() return self.CustomTalents end,
					min = 0,
					max = maxRank,
					step = 1,
					order = 3 + i + (t-1) * 50,
					get = 	function() return talents[talentName] or 0 end,
					set = 	function(info, v)
								if v == 0 and not talentInfo[talentName].Manual then
									talents[talentName] = nil
								else
									talents[talentName] = v
								end
								self:UpdateTalents(true)
							end,
				}
			end
		end
		talentTable[("Tab" .. t)] = {
			type = 'header',
			name = --[["|T" .. select(2,GetSpecializationInfo(t)) .. ":30:30:-7:0|t" ..--]] select(2,GetSpecializationInfo(t)),
			order = 2 + (t-1) * 49,
		}
	end
	AC:RegisterOptionsTable("DrDamage-Main", {
		type = 'group',
		name = "DrDamage",
		args = {
			Config = {
				type = "execute",
				name = L["Standalone Config"],
				func = self.OpenConfig,
			}
		}
	})
	AC:RegisterOptionsTable("DrDamage-Actionbar", optionsTable.Actionbar)
	AC:RegisterOptionsTable("DrDamage-Tooltip", optionsTable.Tooltip)
	AC:RegisterOptionsTable("DrDamage-Calculation", optionsTable.Calculation)
	AC:RegisterOptionsTable("DrDamage-Custom", optionsTable.Custom)
	AC:RegisterOptionsTable("DrDamage-Aura", optionsTable.Aura)
	AC:RegisterOptionsTable("DrDamage-Talents", optionsTable.Talents)
	AC:RegisterOptionsTable("DrDamage-Reset", optionsTable.Reset)
	ACD:AddToBlizOptions("DrDamage-Main", "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Actionbar", optionsTable.Actionbar.name, "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Tooltip", optionsTable.Tooltip.name, "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Calculation", optionsTable.Calculation.name, "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Custom", optionsTable.Custom.name, "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Aura", optionsTable.Aura.name, "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Talents", optionsTable.Talents.name, "DrDamage")
	ACD:AddToBlizOptions("DrDamage-Reset", optionsTable.Reset.name, "DrDamage")
end

--UPDATE FUNCTIONS:
function DrDamage:ScheduleUpdate(timer)
	if timer > 0 then
		if ABupdate then
			if self:TimeLeft(ABupdate) > timer then
				self:CancelTimer(ABupdate)
				ABupdate = self:ScheduleTimer("UpdateAB", timer)
			end
		else
			ABupdate = self:ScheduleTimer("UpdateAB", timer)
		end
	else
		self:UpdateAB()
	end
end

--EVENTS
local oldMana = UnitPower("player",0)
local trigger = 20 + UnitLevel("player") * 3
function DrDamage:UNIT_POWER( units )
	if units["player"] then
		if settings.DisableUpdates and InCombatLockdown() then return end
		if self.Calculation["UNIT_POWER"] then
			self.Calculation["UNIT_POWER"]()
		end
		if Casts then
			local newMana = UnitPower("player",0)
			if math_abs(newMana - oldMana) >= trigger then
				oldMana = newMana
				self:UpdateAB(nil, true)
			end
		end
	end
end

--Event for weapon buff updates (rogue poisons, shaman weapon spells, death knight runes)
local mbuff, obuff
function DrDamage:UNIT_INVENTORY_CHANGED(units)
	if units["player"] then
		if settings.DisableUpdates and InCombatLockdown() then return end
		local buff = self:GetWeaponBuff()
		local buff2 = self:GetWeaponBuff(true)
		if buff ~= mbuff or buff2 ~= obuff then
			mbuff = buff
			obuff = buff2
			self:UpdateAB()
		end
	end
end

DrDamage.healingMod = 1
--[[
function DrDamage:ZONE_CHANGED_NEW_AREA(event)
	local _, instance = IsInInstance()
	local old = self.healingMod
	if instance == "pvp" or instance == "arena" or GetZonePVPInfo() == "combat" then
		self.healingMod = 0.9
	else
		self.healingMod = 1
	end
	if event and (self.healingMod ~= old) then
		self:UpdateAB()
	end
end
--]]

--Triggers after an ability is placed on the actionbar, doesn't work without a slight delay
function DrDamage:ACTIONBAR_HIDEGRID()
	local cursor = GetCursorInfo()
	if cursor == "spell" or cursor == "macro" then
		self:ScheduleUpdate(settings.TimerHideGrid)
	end
end

--Triggers after an ability is placed on the pet actionbar
function DrDamage:PET_BAR_HIDEGRID()
	self:ScheduleUpdate(settings.TimerHideGrid)
end

function DrDamage:ACTIONBAR_PAGE_CHANGED()
	self:ScheduleUpdate(settings.TimerActionbarPage)
end

function DrDamage:UPDATE_STEALTH()
	self:ScheduleUpdate(settings.TimerStealth)
end

function DrDamage:UNIT_COMBO_POINTS(event, unit)
	if settings.ComboPoints == 0 and unit == "player" then
		self:ScheduleUpdate(settings.TimerComboPoints)
	end
end

--Castsequence macro update triggers
local MacroTimer, Trigger
function DrDamage:MacroTrigger()
	Trigger = nil
	MacroTimer = nil
	if not ABtotembar then
		self:UnregisterEvent("ACTIONBAR_SLOT_CHANGED")
	end
end
function DrDamage:EXECUTE_CHAT_LINE()
	Trigger = true
	if MacroTimer then
		self:CancelTimer(MacroTimer)
	end
	MacroTimer = self:ScheduleTimer("MacroTrigger", 0.5)
	if not ABtotembar then
		self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
	end
end
function DrDamage:ACTIONBAR_SLOT_CHANGED(_, id)
	if Trigger then
		local gtype, pid = GetActionInfo(id)
		if gtype == "macro" then
			local name = GetMacroSpell(pid)
			if name and spellInfo[name] then
				self:ScheduleTimer("UpdateAB", 0.5, id)
				Trigger = nil
			end
		end
	elseif ABtotembar and (id == 133 or id == 134 or id == 135 or id == 136) then
		self:ScheduleTimer("UpdateAB", 0.25, id)
	end
end

--Main-hand, Off-hand, Ranged slot and meta gem updates
function DrDamage:PLAYER_EQUIPMENT_CHANGED(slot)
	if self.Melee_InventoryChanged then
		self:Melee_InventoryChanged(slot[16], slot[17], slot[18])
	end
	updateSetItems = true
	self:MetaGems()
	self:UpdateAB()
end

function DrDamage:MetaGems()
	self.Damage_critMBonus = 0
	self.Healing_critMBonus = 0
	local helm = GetInventoryItemLink("player", 1)
	if helm then
		for i = 1, 3 do
			local mgem = tonumber(string_match(select(2, GetItemGem(helm, i)) or "",".-item:(%d+).*"))
			--34220 - Chaotic Skyfire Diamond, 41285 - Chaotic Skyflare Diamond
			--32409 - Relentless Earthstorm Diamond, 41398 - Relentless Earthsiege Diamond,
			--52291 - Chaotic Shadowspirit Diamond, 68778 - Agile Shadowspirit Diamond
			--68779 - Reverberating Shadowspirit Diamond, 68780 - Burning Shadowspirit Diamond
			--76884 - Agile Primal Diamond
			--76885 - Burning Primal Diamond
			--76886 - Reverberating Primal Diamond
			if mgem == 34220 or mgem == 41285 or
				mgem == 32409 or mgem == 41398 or
				mgem == 52291 or mgem == 68778 or
				mgem == 68779 or mgem == 68780 or
				mgem == 76884 or mgem == 76885 or
				mgem == 76886 then
					if not self:IsMetaGemInactive() then
						self.Damage_critMBonus = 0.03
						self.Healing_critMBonus = 0.03
					end
					break
			--41376 - Revitalizing Skyflare Diamond, 52297 - Revitalizing Shadowspirit Diamond
			--76888 - Revitalizing Primal Diamond
			elseif mgem == 41376 or mgem == 52297 then
				if not self:IsMetaGemInactive() then
					self.Healing_critMBonus = 0.03
				end
				break
			end
		end
	end
end

--Event for checking if the meta gem is greyed out in the head slot tooltip
function DrDamage:IsMetaGemInactive()
	if GT:SetInventoryItem("player", 1) then
		for j = 1, GT:NumLines() do
			if GT:GetLine(j) and string_find(GT:GetLine(j), "|cff808080.*808080") then
				return true
			end
		end
	end
end

--Event for skills and talents that update on certain health percentages
local pHealth, tHealth = 1, 1
function DrDamage:UNIT_HEALTH(units)
	if settings.DisableUpdates and InCombatLockdown() then return end
	if PlayerHealth and units["player"] then
		local value = PlayerHealth[1]
		local health = UnitHealth("player")/UnitHealthMax("player")
		if (health < value) ~= (pHealth < value) then
			self:UpdateAB(PlayerHealth[value])
		end
		pHealth = health
	end
	if TargetHealth and units["target"] then
		local health = UnitHealth("target")/UnitHealthMax("target")
		for i=1,#TargetHealth do
			local value = tonumber(TargetHealth[i]) or UnitHealth("player")/UnitHealthMax("player")
			if (health < value) ~= (tHealth < value) then
				if TargetHealth[value] then
					self:UpdateAB(TargetHealth[value])
				else
					self:UpdateAB()
					tHealth = health
					return
				end
			end
		end
		tHealth = health
	end
end

function DrDamage:PLAYER_TARGET_CHANGED()
	if settings.DisableUpdates and InCombatLockdown() then return end
	self:ScheduleUpdate(settings.TimerTarget)
	self:TargetAuraUpdate(true)
	tHealth = TargetHealth and (UnitHealth("target")/UnitHealthMax("target"))
end

local PlayerAuraTimer, TargetAuraTimer
function DrDamage:UNIT_AURA(event, unit)
	if settings.DisableUpdates and InCombatLockdown() then return end
	if unit == "player" then
		if not PlayerAuraTimer then
			PlayerAuraTimer = self:ScheduleTimer("PlayerAuraUpdate", settings.TimerPlayerAura)
		end
	elseif unit == "target" then
		if not TargetAuraTimer then
			TargetAuraTimer = self:ScheduleTimer("TargetAuraUpdate", settings.TimerTargetAura)
		end
	end
end

local oPlayerAura, nPlayerAura = {}, {}
local oTargetAura, nTargetAura = {}, {}

function DrDamage:PlayerAuraUpdate()
	PlayerAuraTimer = nil
	if dmgMod ~= select(7,UnitDamage("player"))
	or self.Caster_CheckBaseStats and self:Caster_CheckBaseStats()
	or self.Melee_CheckBaseStats and self:Melee_CheckBaseStats() then
		self:UpdateAB()
		return
	end
	--[[ Enable if ever needed
	if self.Calculation["PlayerAura"] then
		local update, spell = self.Calculation["PlayerAura"]
		if update then
			return self:UpdateAB(spell)
		end
	end
	--]]
	for i=1,40 do
		local name, rank, texture, count = UnitBuff("player",i)
		if name then
			if PlayerAura[name] then
				nPlayerAura[name] = rank .. count
			end
		else
			break
		end
	end
	for i=1,40 do
		local name, rank, texture, count = UnitDebuff("player",i)
		if name then
			if PlayerAura[name] then
				nPlayerAura[name] = rank .. count
			end
		else
			break
		end
	end
	local buffName, multi
	--Buff/debuff gained or count/rank changed
	for k,v in pairs(nPlayerAura) do
		if not oPlayerAura[k] or oPlayerAura[k] ~= v then
			multi = buffName
			buffName = k
		end
	end
	--Buff/debuff lost
	for k,v in pairs(oPlayerAura) do
		if not nPlayerAura[k] then
			multi = buffName
			buffName = k
		end
		oPlayerAura[k] = nil
	end
	--Copy new table to old and clear
	for k,v in pairs(nPlayerAura) do
		oPlayerAura[k] = v
		nPlayerAura[k] = nil
	end
	if buffName then
		self:UpdateAB(not multi and PlayerAura[buffName].Spells)
	end
end

function DrDamage:TargetAuraUpdate(changed)
	TargetAuraTimer = nil
	if self.Calculation["TargetAura"] then
		local update, spell = self.Calculation["TargetAura"]()
		if update and not changed then self:UpdateAB(spell) end
	end
	if playerHealer then
		for i=1,40 do
			local name, rank, texture, count, _, _, _, unit = UnitBuff("target",i)
			if name then
				if TargetAura[name] then
					if unit and TargetAura[name].SelfCastBuff then
						if UnitIsUnit("player",unit) then
							nTargetAura[name] = rank .. count
						end
					else
						nTargetAura[name] = rank .. count
						--nTargetAura[name.."|"..texture] = rank .. count
					end
				end
			else break end
		end
	end
	for i=1,40 do
		local name, rank, texture, count, _, _, _, unit = UnitDebuff("target",i)
		if name then
			if TargetAura[name] then
				if unit and TargetAura[name].SelfCast then
					if UnitIsUnit("player",unit) then
						nTargetAura[name] = rank .. count
					end
				else
					nTargetAura[name] = rank .. count
					--nTargetAura[name.."|"..texture] = rank .. count
				end
			end
		else break end
	end
	local buffName, multi
	--Buff/debuff gained or count/rank changed
	for k,v in pairs(nTargetAura) do
		if not oTargetAura[k] or oTargetAura[k] ~= v then
			multi = buffName
			buffName = k
			--buffName = string_match(k,"[^|]+")
		end
	end
	--Buff/debuff lost
	for k,v in pairs(oTargetAura) do
		if not nTargetAura[k] then
			multi = buffName
			buffName = k
			--buffName = string_match(k,"[^|]+")
		end
		oTargetAura[k] = nil
	end
	--Copy new table to old and clear
	for k,v in pairs(nTargetAura) do
		oTargetAura[k] = v
		nTargetAura[k] = nil
	end
	if TargetAura[buffName] and not changed then
		self:UpdateAB(not multi and TargetAura[buffName].Spells)
	end
end

--Event for actionbar modifier key updates
local ModTimer
local oldState = GetTime()
function DrDamage:MODIFIER_STATE_CHANGED(event, state)
	if settings.DisableUpdates and InCombatLockdown() then return end
	if (state == "LALT" or state == "RALT") and settings.UpdateAlt or (state == "LCTRL" or state == "RCTRL") and settings.UpdateCtrl or (state == "LSHIFT" or state == "RSHIFT") and settings.UpdateShift then
		local newState = GetTime()
		if newState - oldState < settings.TimerModifier then
			if ModTimer then
				self:CancelTimer(ModTimer)
				ModTimer = nil
			end
		else
			ModTimer = self:ScheduleTimer("ModifierUpdate", settings.TimerModifier)
		end
		oldState = newState
	end
end

function DrDamage:ModifierUpdate()
	ModTimer = nil
	self:UpdateAB()
end

--Talent updates
local TalentTimer, TalentIterate
function DrDamage:UPDATE_TALENTS()
	if not TalentTimer then
		TalentTimer = self:ScheduleTimer("UpdateTalents", 0.75)
	end
end
function DrDamage:UpdateTalents(manual, all)
	TalentTimer = nil
	if not manual and not self.CustomTalents then
		DrD_ClearTable( talents )
		for t = 1, GetNumSpecializations() do
			for i = 1, GetNumTalents(t) do
				local talentName, _, _, _, currRank, maxRank = GetTalentInfo(t, i)
				if talentInfo[talentName] then
					if currRank ~= 0 or all then
						talents[talentName] = all and maxRank or currRank
					end
					if talentInfo[talentName].Manual then
						self.BaseTalents[(talentInfo[talentName].Manual)] = currRank
					end
				end
			end
		end
	end
	--Load talents into appropriate spell data
	for _, spell in pairs( spellInfo ) do
		TalentIterate( spell["Name"], spell[0], spell["Talents"] )
		if spell["Secondary"] then
			TalentIterate( spell["Secondary"]["Name"], spell["Secondary"][0], spell["Secondary"]["Talents"] )
		end
	end
	self:ScheduleUpdate(0.5)
end
TalentIterate = function( name, baseSpell, endtable )
	if not baseSpell or type(baseSpell) == "function" then return end
	DrD_ClearTable( endtable )
	local melee = baseSpell.Melee
	local school = baseSpell.School
	local s1,s2,s3
	if type(school) == "table" then
		s1 = school[1]
		s2 = school[2]
		s3 = school[3]
	else
		s1 = school or "Physical"
	end
	for talentName, talentRank in pairs( talents ) do
		local talentTable = talentInfo[talentName]
		for i=1,#talentTable do
			local talent = talentTable[i]
			if (melee and talent.Melee or talent.Caster and not melee or (not talent.Melee and not talent.Caster)) then
				local spells = talent.Spells
				if not DrD_MatchData(talent.Not,name,s2,s3) then
					if DrD_MatchData(spells,name,s3) or not baseSpell.NoSchoolTalents and DrD_MatchData(spells, "All", s1) or not baseSpell.NoTypeTalents and DrD_MatchData(spells, s2) then
						local number = #endtable + 1
						local modtype = talent.ModType
						local multiply = talent.Multiply
						endtable["Multiply"..number] = multiply
						endtable[number] = type(talent.Effect) == "table" and talent.Effect[talentRank] or talent.Effect * talentRank
						if not modtype then
							endtable[("ModType"..number)] = multiply and "dmgM" or "dmgM_Add"
						elseif modtype == "SpellDamage" then
							endtable[("ModType"..number)] = multiply and "SPBonus" or "SPBonus_Add"
						else
							endtable[("ModType"..number)] = modtype
						end
						--@debug@
						endtable[talentName] = number
						--@end-debug@
					end
				end
			end
		end
	end
end

function DrDamage:PLAYER_LEVEL_UP(event, level)
	self:LoadData(level)
	self:UpdateAB()
end

local SetItems = {}
function DrDamage:GetSetAmount(set)
	--@debug@
	if self.debug then
		return 8
	end
	--@end-debug@
	if not updateSetItems and SetItems[set] then
		return SetItems[set]
	end

	if updateSetItems then
		DrD_ClearTable( SetItems )
		updateSetItems = false
	end

	local amount = 0
	local setData = self.SetBonuses[set]
	if setData then
		for i = 1, #setData do
			if IsEquippedItem(setData[i]) then
				amount = amount + 1
			end
		end
	end
	SetItems[set] = amount
	return amount
end

local Glyphs = {}
function DrDamage:HasGlyph(glyph)
	--@debug@
	if self.debug then
		return true
	end
	--@end-debug@
	return Glyphs[glyph]
end

function DrDamage:UpdateGlyphs(event)
	DrD_ClearTable(Glyphs)
	for i=1,GetNumGlyphs() do
		local _, _, _, id = GetGlyphSocketInfo(i)
		if id then Glyphs[id] = true end
	end
	if event then
		self:ScheduleUpdate(2)
	end
end

local lines = {}
local savedname, savedrank
local autoattack = GetSpellInfo(6603)

function DrDamage:ClearTooltip()
	if savedname then
		for i = 1, #lines do
			lines[i]["Left"] = nil
			lines[i]["Right"] = nil
			lines[i]["Rl"] = nil
			lines[i]["Gl"] = nil
			lines[i]["Bl"] = nil
			lines[i]["Rr"] = nil
			lines[i]["Gr"] = nil
			lines[i]["Br"] = nil
		end
		savedname = nil
		savedrank = nil
	end
end

function DrDamage:RedoTooltip(frame, name, rank)
	if savedname and savedname == name and savedrank == rank then
		frame:AddLine(" ")
		for i=1, #lines do
			if lines[i]["Right"] then
				frame:AddDoubleLine(lines[i]["Left"], lines[i]["Right"], lines[i]["Rl"], lines[i]["Gl"], lines[i]["Bl"], lines[i]["Rr"], lines[i]["Gr"], lines[i]["Br"])
			elseif lines[i]["Left"] and lines[i]["Left"] ~= " " then
				frame:AddLine(lines[i]["Left"], lines[i]["Rl"], lines[i]["Gl"], lines[i]["Bl"])
			end
		end
		frame:Show()
		return true
	end
end

function DrDamage:SaveTooltip(name, rank, size)
	local start
	local line = 1
	for i= size, GameTooltip:NumLines() do
		if not start and _G[("GameTooltipTextRight" .. i)]:GetText() then
			start = true
			savedname = name
			savedrank = rank
		end
		if start then
			if not lines[line] then
				lines[line] = {}
			end
			lines[line]["Left"] = _G[("GameTooltipTextLeft" .. i)]:GetText()
			lines[line]["Right"] = _G[("GameTooltipTextRight" .. i)]:GetText()
			lines[line]["Rl"], lines[line]["Gl"], lines[line]["Bl"] = _G[("GameTooltipTextLeft" .. i)]:GetTextColor()
			lines[line]["Rr"], lines[line]["Gr"], lines[line]["Br"] = _G[("GameTooltipTextRight" .. i)]:GetTextColor()
			line = line + 1
		end
	end
end

function DrDamage:SetSpell( frame, slot )
	if slot then self:SetSpellBookItem( frame, slot ) end
end

function DrDamage:SetSpellBookItem( frame, slot )
	local name, rank = GetSpellBookItemName(slot,BOOKTYPE_SPELL)
	self:CreateTooltip(frame, name, rank)
end

function DrDamage:SetShapeshift( frame, slot )
	local name, rank = frame:GetSpell()
	self:CreateTooltip(frame, name, rank)
end

local passive = select(2,GetSpellInfo(16213))
function DrDamage:SetSpellByID( frame, id )
	if id then
		local name, rank = GetSpellInfo(id)
		if rank ~= passive then
			self:CreateTooltip(frame, name, rank)
		end
	end
end

function DrDamage:SetAction( frame, slot )
	local gtype, pid = GetActionInfo(slot)
	local size = GameTooltip:NumLines() + 1
	local cd = GetActionCooldown(slot) > 0
	local name, rank, macro

	if (gtype == "spell" and pid ~= 0) then
		name, rank = GetSpellInfo(pid)
	elseif gtype == "macro" then
		name, rank = GetMacroSpell(pid)
		local macrotext = GetMacroBody(pid)
		if macrotext then
			macro = string_find(macrotext, "target=") or string_find(macrotext, "@")
		end
	end
	self:CreateTooltip(frame, name, rank, size, cd or macro)
end

function DrDamage:CreateTooltip( frame, name, rank, size, save )
	if name and spellInfo[name] then
		if settings.Tooltip == "Never" then return end
		if settings.Tooltip == "Combat" and InCombatLockdown() then return end
		if settings.Tooltip == "Alt" and not IsAltKeyDown() then return end
		if settings.Tooltip == "Ctrl" and not IsControlKeyDown() then return end
		if settings.Tooltip == "Shift" and not IsShiftKeyDown() then return end
		if size then if self:RedoTooltip(frame, name, rank) then return end end

		local baseSpell = spellInfo[name][0]
		if type(baseSpell) == "function" then baseSpell = baseSpell(rank) end

		if baseSpell and not baseSpell.NoTooltip then
			if playerCaster or playerHybrid and not baseSpell.Melee then
				self:CasterTooltip( frame, name, rank )
			elseif playerMelee or playerHybrid and baseSpell.Melee then
				self:MeleeTooltip( frame, name, rank )
			end
		end
		if size then
			if savedname then
				self:ClearTooltip()
			end
			if save and not spellInfo[name]["Secondary"] then
				self:SaveTooltip(name, rank, size)
			end
		end
	end
end

function DrDamage:UpdateAB(spell, mana, disable)
	--	Used for debugging updates.
	--[[
	if spell then
		self:Print( "Update AB: Spell" )

		if type( spell ) == "table" then
			for k in pairs( spell ) do
				self:Print( "Updating: " .. k )
			end
		else
			self:Print( "Updating: " .. spell )
		end
	else
		self:Print( "Update AB: All" )
	end
	--]]
	--Enable if needed
	--if ABfunc then
	--	ABfunc()
	--end
	if ABtable then
		for name, func in pairs(ABtable) do
			self:CheckAction(_G[name], name, func, spell, mana)
		end
	end
	if not ABdisable and settings.DefaultAB then
		for i = 1, #ABobjects do
			local button = ABobjects[i]
			self:CheckAction(button, button:GetName(), ActionButton_GetPagedID, spell, mana, disable)
		end
	end
	if not spell and not mana then	
		if ABupdate then
			self:CancelTimer(ABupdate)
			ABupdate = nil
		end
		ABfont = nil
		dmgMod = select(7, UnitDamage("player"))
	end
	self:ClearTooltip()
end

local DrD_CreateText
function DrDamage:CheckAction(button, framename, func, spell, mana, disable, name, rank, pet)
	local macro
	if button then
		if not spell and not mana then
			local text = ABtext1[framename]
			if text then text:SetText(nil) end
			text = ABtext2[framename]
			if text then text:SetText(nil) end
		end
		if not settings.ABText or disable then return end
		local id
		if button:IsVisible() then
			id, name, rank, pet, macro = func(button)
			local uid = spell and (type(spell) == "number")
			if id then
				if not HasAction(id) then return end
				if uid then
					if spell == id then
						local text = ABtext1[framename]
						if text then text:SetText(nil) end
						text = ABtext2[framename]
						if text then text:SetText(nil) end
					else
						return 
					end
				end
			end
			if uid then spell = nil end
		else
			return
		end
		if id then
			local gtype, pid = GetActionInfo(id)
			if gtype == "spell" and pid ~= 0 then
				name, rank = GetSpellInfo(pid)
			elseif gtype == "macro" then
				name, rank = GetMacroSpell(pid)
				macro = true
			end
		end		
	end
	if name then
		if spell and not DrD_MatchData(spell, name) then return end
		local r, g, b, manatext
		if Casts then
			--if tonumber(rank) and GetSpellInfo(name) then
			--	rank = string_gsub(select(2,GetSpellInfo(name)),"%d+", rank)
			--end
			local _, _, _, manaCost, _, powerType = GetSpellInfo(name--[[,rank--]])
			if manaCost and (manaCost > 0) and powerType == 0 then
				local mana = pet and UnitPower("pet",0) or UnitPower("player",0)
				local text = math_floor(mana / manaCost)
				local ctable
				if text >= 10 then
					ctable = settings.FontColorCasts1
				elseif text >= 5 then
					ctable = settings.FontColorCasts2
				else
					ctable = settings.FontColorCasts3
				end
				local r, g, b = ctable.r, ctable.g, ctable.b
				manatext = DrD_CreateText(button, framename, text, true, nil, nil, r, g, b)
			end
			if mana then return end
		end
		if ManaCost or PowerCost then
			--if tonumber(rank) and GetSpellInfo(name) then
			--	rank = string_gsub(select(2,GetSpellInfo(name)),"%d+", rank)
			--end
			local _, _, _, manaCost, _, powerType = GetSpellInfo(name, rank)
			if manaCost and (manaCost > 0) and (ManaCost and powerType == 0 or PowerCost and (playerMelee and powerType == 0 or powerType == 1 or powerType == 3)) then
				local ctable = (powerType == 1) and settings.FontColorRage or (powerType == 3) and settings.FontColorEnergy or settings.FontColorMana
				r, g, b = ctable.r, ctable.g, ctable.b
				manatext = DrD_CreateText(button, framename, manaCost, true, nil, nil, r, g, b)
				if ManaCost and not PowerCost and settings.DisplayType_M2 then
					r, g, b = nil, nil, nil
				end
			end
		end
		if spellInfo[name] then
			local baseSpell = settings.SwapCalc and spellInfo[name]["Secondary"] and spellInfo[name]["Secondary"][0] or spellInfo[name][0]
			if type(baseSpell) == "function" then baseSpell = baseSpell(rank) end

			if baseSpell then
				local text, text2, healingSpell
				if playerCaster or playerHybrid and not baseSpell.Melee then
					healingSpell = type(baseSpell.School) == "table" and baseSpell.School[2] == "Healing"
					text, text2 = self:CasterCalc(name, rank)
				elseif playerMelee or playerHybrid and baseSpell.Melee then
					text, text2 = self:MeleeCalc(name, rank)
				end
				if text2 then
					text2 = DrD_CreateText(button, framename, text2, true, nil, healingSpell, r, g, b)
				end
				return DrD_CreateText(button, framename, text, nil, macro, healingSpell), text2 or manatext
			end
		end
		if self.ClassSpecials[name] then
			--rank = rank and tonumber(string_match(rank,"%d+"))
			local text, healing, mana, full, r, g, b = self.ClassSpecials[name](--[[rank--]])
			if type(text) == "number" then
				--if healing then
				--	text = text * self.healingMod
				--end
				if not full then
					text = math_floor(text + 0.5)
				end
			end
			if mana then
				local color = settings.FontColorMana
				r, g, b = color.r, color.g, color.b
			end
			return DrD_CreateText(button, framename, text, nil, macro, healing, r, g, b)
		end
	end
end

DrD_CreateText = function(button, framename, text, second, macro, healing, r, g, b )
	if not text then
		return
	else
		if settings.ShortenText and type(text) == "number" then
			if text >= 1e5 then
				text = math_floor(text/1000 + 0.5) .. "k"
			elseif text >= 1e4 then
				text = DrD_Round(text/1000,1) .. "k"
			--elseif text >= 1e4 then
			end
		end
	end
	if not r then
		local color = healing and settings.FontColorHeal or settings.FontColorDmg
		r,g,b = color.r, color.g, color.b
	end
	if button then
		local drd
		if second then
			drd = ABtext2[framename]
		else
			drd = ABtext1[framename]
		end
		if drd then
			if ABfont then
				if second then
					drd:SetPoint("TOPLEFT", button, "TOPLEFT", -15 + settings.FontXPosition2, settings.FontYPosition2 - 1)
					drd:SetPoint("TOPRIGHT", button, "TOPRIGHT", 15 + settings.FontXPosition2, settings.FontYPosition2 - 1)
				else
					drd:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -15 + settings.FontXPosition, settings.FontYPosition + 3)
					drd:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 15 + settings.FontXPosition, settings.FontYPosition + 3)
				end
				drd:SetFont(DrD_Font, settings.FontSize, settings.FontEffect)
			end
			drd:SetTextColor(r,g,b)
			drd:SetText(text)
			drd:Show()
		else
			if second then
				drd = button:CreateFontString(framename .. "drd2", "OVERLAY")
				ABtext2[framename] = drd
				drd:SetPoint("TOPLEFT", button, "TOPLEFT", -15 + settings.FontXPosition2, settings.FontYPosition2 - 1)
				drd:SetPoint("TOPRIGHT", button, "TOPRIGHT", 15 + settings.FontXPosition2, settings.FontYPosition2 - 1)
			else
				drd = button:CreateFontString(framename .. "drd", "OVERLAY")
				ABtext1[framename] = drd
				drd:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -15 + settings.FontXPosition, settings.FontYPosition + 3)
				drd:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 15 + settings.FontXPosition, settings.FontYPosition + 3)
			end
			drd:SetFont(DrD_Font, settings.FontSize, settings.FontEffect)
			drd:SetJustifyH("CENTER")
			drd:SetTextColor(r,g,b)
			drd:SetText(text)
			drd:Show()
		end
		if second then
			if settings.HideHotkey then
				local hotkey = _G[button:GetName().."HotKey"]
				if hotkey then hotkey:Hide() end
			end
		else
			if macro and settings.HideAMacro then
				local macro = _G[button:GetName().."Name"]
				if macro then macro:Hide() end
				if button.actionName then
					button.actionName:Hide()
				end
			end
		end
	else
		return "|cff".. string_format("%02x%02x%02x", r * 255, g * 255, b * 255) .. text .. "|r"
	end
end

local ratingTypes = {
	["Hit"] = 8,
	["Expertise"] = 8,
	["Haste"] = 10,
	["Mastery"] = 14,	
	["Crit"] = 14,
	["PVPPower"] = 7.964177131652832,
	["PVPResilience"] = 9.291540145874023,
}
local ratingTable = {
	["Hit"] = { [86] = 130, [87] = 166, [88] = 211, [89] = 269, [90] = 340 },
	["Expertise"] = { [86] = 130, [87] = 166, [88] = 211, [89] = 269, [90] = 340 },
	["Haste"] = { [86] = 162, [87] = 208, [88] = 264, [89] = 336, [90] = 425 },
	["Mastery"] = { [86] = 228, [87] = 290, [88] = 370, [89] = 470, [90] = 600 },
	["Crit"] = { [86] = 228, [87] = 290, [88] = 370, [89] = 470, [90] = 600 },
	["PVPPower"] = { [81] = 32.596549987792969, [82] = 40.687507629394531, [83] = 50.786758422851562, [84] = 63.392799377441406, [85] = 79.127845764160156, [86] = 100, [87] = 128, [88] = 163, [89] = 208, [90] = 265 },
	["PVPResilience"] = { [81] = 38.029308319091797, [82] = 47.468757629394531, [83] = 59.251216888427734, [84] = 73.958267211914062, [85] = 92.315818786621094, [86] = 115, [87] = 150, [88] = 190, [89] = 245, [90] = 310 },
}

function DrDamage:GetRating( rType, convertR, full )
	local playerLevel = UnitLevel("player")
	local base = ratingTypes[rType] or rType
	local rating, value

	if ratingTable[rType][playerLevel] then
		rating = ratingTable[rType][playerLevel]
	else
		if playerLevel > 85 then
			local delta = math_min(5, playerLevel - 85)
			rating = base * select(delta, 18.744572754, 24.683429565, 30.622286377, 36.561143188, 42.5)
		elseif playerLevel > 80 then
			local delta = math_min(5, playerLevel - 80)
			rating = base * select(delta, 4.3056015014648, 5.6539749145508, 7.4275451660156, 9.7527236938477, 12.8057159423828)
		elseif playerLevel > 70 then
			rating = base * (82/52) * ((131/63)^((playerLevel - 70)/10))
		elseif playerLevel > 60 then
			rating = base * 82 / (262 - 3 * playerLevel)
		elseif playerLevel > 10 then
			rating = base * ((playerLevel - 8) / 52)
		elseif 	playerLevel <= 10 then
			rating = base / 26
		end
	end
	value = convertR and convertR/rating or rating
	value = full and value or DrD_Round(value,2)
	return value
end

function DrDamage:GetAP()
	local baseAP, posBuff, negBuff = UnitAttackPower("player")
	return baseAP + posBuff + negBuff
end

function DrDamage:GetArmor( value )
	local playerLevel = UnitLevel("player")
	if playerLevel > 85 then
		return value * (4037.5 * playerLevel - 317117.5) / (1 - value)
	elseif playerLevel > 80 then
		return value * (2167.5 * playerLevel - 158167.5) / (1 - value)
	elseif playerLevel > 59 then
		return value * (467.5 * playerLevel - 22167.5) / (1 - value)
	else
		return value * (400 + 85 * playerLevel) / (1 - value)
	end
end

function DrDamage:GetMitigation( armor )
	local playerLevel = UnitLevel("player")
	if playerLevel > 85 then
		return math_min(0.75, armor / (armor + 4037.5 * playerLevel - 317117.5))
	elseif playerLevel > 80 then
		return math_min(0.75, armor / (armor + 2167.5 * playerLevel - 158167.5))
	elseif playerLevel > 59 then
		return math_min(0.75, armor / (armor + 467.5 * playerLevel - 22167.5))
	else
		return math_min(0.75, armor / (armor + 85 * playerLevel + 400))
	end
end

function DrDamage:GetLevels()
	local playerLevel = UnitLevel("player")
	local targetLevel = UnitLevel("target")
	local boss

	if (UnitClassification("target") == "worldboss") then
		targetLevel = playerLevel + 3
		boss = true
	elseif targetLevel == 0 then
		targetLevel = playerLevel
	elseif targetLevel == -1 then
		targetLevel = playerLevel + 10
	end

	return playerLevel, math_max(playerLevel - 4, math_min(playerLevel + 10, targetLevel)), boss
end

--CORE: Base spell hit chance
local hitDataMOB = { [-4] = 100, [-3] = 99, [-2] = 98, [-1] = 97, [0] = 94, 91, 88, 85, 72, 61, 50, 39, 28, 17, 6 }
--local hitDataPlayer = { [-4] = 100, [-3] = 99, [-2] = 98, [-1] = 97, [0] = 96, 95, 94, 87, 80, 73, 66, 59, 52, 45, 38 }

function DrDamage:GetSpellHit(playerLevel, targetLevel)
	--local player = (settings.TargetLevel == 0) and UnitIsPlayer("target")
	local delta = math_min(10,math_max(-4,targetLevel - playerLevel))
	--return (player and hitDataPlayer[delta] or hitDataMOB[delta]) + GetCombatRatingBonus(8) + GetSpellHitModifier()
	return hitDataMOB[delta] + GetCombatRatingBonus(8) + GetSpellHitModifier()
end

--CORE: Base melee/ranged hit chance
local baseHit = { [-4] = 100, [-3] = 100, [-2] = 99, [-1] = 98, [0] = 97, 95.5, 94, 92.5, 90, 88, 86, 84, 82, 80, 78 }

function DrDamage:GetMeleeHit(playerLevel, targetLevel, ranged)
		local delta = math_min(10,math_max(-4,targetLevel - playerLevel))
		local hit = baseHit[delta] + (ranged and GetCombatRatingBonus(7) or GetCombatRatingBonus(6)) + GetHitModifier()
		return hit, hit
end

local WeaponBuffScan = GetTime()
local WeaponBuff, WeaponBuffRank
function DrDamage:GetWeaponBuff(off)
	local mh, _, _, oh = GetWeaponEnchantInfo()
	local name, rank, buff

	if not off and mh then
		if GetTime() > WeaponBuffScan then
			WeaponBuffScan = GetTime() + 2
			GT:SetInventoryItem("player", 16)
			_, _, buff = GT:Find("^([^%(]+) %(%d+ [^%)]+%)$", nil, nil, false, true)
			if buff then
				name, rank = string_match(buff,"^(.*) (%d+)$")
			end
			WeaponBuff, WeaponBuffRank = name or buff, rank
		end
		return WeaponBuff, WeaponBuffRank
	elseif off and oh then
		GT:SetInventoryItem("player", 17)
		_, _, buff = GT:Find("^([^%(]+) %(%d+ [^%)]+%)$", nil, nil, false, true)
		if buff then
			name, rank = string_match(buff,"^(.*) (%d+)$")
		end
	end
	return name or buff, rank
end

function DrDamage:Calc(name, rank, tooltip, modify, debug)
	if not spellInfo or not name then return end
	if not spellInfo[name] then return end
	local baseSpell = settings.SwapCalc and spellInfo[name]["Secondary"] and spellInfo[name]["Secondary"][0] or spellInfo[name][0]
	if type(baseSpell) == "function" then baseSpell = baseSpell(rank) end
	if baseSpell then
		if playerCaster or playerHybrid and not baseSpell.Melee then
			return self:CasterCalc(name, rank, tooltip, modify, debug)
		elseif playerMelee or playerHybrid and baseSpell.Melee then
			return self:MeleeCalc(name, rank, tooltip, modify, debug)
		end
	end
end

--Load aura iteration function
AuraIterate = function(name, spell, auratable, bufftable)
	local baseSpell = spell[0]
	local spellName = spell["Name"]
	local baseSchool = baseSpell.School
	local school, group, subType
	if type(baseSchool) == "table" then
		school = baseSchool[1]
		group = baseSchool[2]
		subType = baseSchool[3]
	else
		school = baseSchool or "Physical"
	end
	local healing = DrD_MatchData(baseSchool, "Healing")
	local caster = playerCaster or playerHybrid and not baseSpell.Melee
	local melee = playerMelee or playerHybrid and baseSpell.Melee
	local spell = caster and not DrD_MatchData(baseSchool, "Melee") or melee and DrD_MatchData(baseSchool, "Spell")
	local utility = (group == "Absorb") or (group == "Utility") or (group == "Pet")

	for buff, data in pairs(bufftable) do
		if not data.Update and (caster and (data.Caster or not data.Melee) or melee and (data.Melee or not data.Caster)) then
			if not data.Not or data.Not and not DrD_MatchData(data.Not, spellName, group, subType) then
				local buffschool = data.School
				if data.Spells and DrD_MatchData(data.Spells, name)
				or not healing and (not buffschool and not data.Spells or DrD_MatchData(buffschool, school))
				or spell and (DrD_MatchData(buffschool, "Spells") or not healing and not utility and DrD_MatchData(buffschool, "Damage Spells"))
				or healing and DrD_MatchData(buffschool, "Healing")
				or DrD_MatchData(buffschool, "All", group, subType) then
						auratable[buff] = true
				end
			end
		end
	end
end

function DrDamage.BuffCalc( data, calculation, ActiveAuras, Talents, baseSpell, buffName, index, apps, texture, rank, target )
	if index then
		if data.BuffID and select(11,UnitBuff(target,index)) ~= data.BuffID then
			return
		end
		if data.DebuffID and select(11,UnitDebuff(target,index)) ~= data.DebuffID then
			return
		end
		if data.Texture and texture and not string_find(texture, data.Texture) then
			return
		end
		if data.SelfCast then
			local unit = select(8,UnitDebuff(target,index))
			if not unit or not UnitIsUnit("player",unit) then return end
		end
		if data.SelfCastBuff then
			local unit = select(8,UnitBuff(target,index))
			if not unit or not UnitIsUnit("player",unit) then return end
		end
	end
	--Process active aura table
	if data.ActiveAura then
		if data.Ranks then
			ActiveAuras[data.ActiveAura] = rank and tonumber(string_match(rank,"%d+")) or data.Ranks
		elseif data.Index then
			ActiveAuras[data.ActiveAura] = index or 0
		else
			if apps and apps > 0 then
				ActiveAuras[data.ActiveAura] = apps
			else
				ActiveAuras[data.ActiveAura] = data.Apps or (ActiveAuras[data.ActiveAura] or 0) + 1
			end
		end
	end
	--Process category
	if data.Category and not data.SkipCategory and (not data.SkipCategoryMod or index) then
		if ActiveAuras[data.Category] then return
		else ActiveAuras[data.Category] = true end
	end
	--Process manually added buffs
	if not index and data.Mods --[[or baseSpell.CustomHaste and data.CustomHaste--]] then
		for k, v in pairs(data.Mods) do
			if type(k) == "number" then
				v(calculation, baseSpell, ActiveAuras)
			elseif calculation[k] then
				if type(v) == "function" then
					calculation[k] = v(calculation[k], baseSpell, calculation)
				else
					if data.Multiply then
						calculation[k] = calculation[k] * (1 + v)
					else
						calculation[k] = calculation[k] + v
					end
				end
			end
		end
	end
	--Determine modtype
	local modType = data.ModType
	if modType and type(modType) == "function" then
		apps = apps or data.Apps
		rank = rank and tonumber(string_match(rank,"%d+")) or data.Ranks
		modType( calculation, ActiveAuras, Talents, index, apps, texture, rank, target )
	else
		local value = data.Value
		if not value then return end
		if data.Ranks then
			rank = rank and tonumber(string_match(rank,"%d+")) or data.Ranks
			value = (type(value) == "table") and value[rank] or value * rank
		end
		if data.Apps then
			apps = apps or data.Apps
			value = (type(value) == "table") and value[apps] or value * apps
		end
		if not modType then
			calculation.dmgM = calculation.dmgM * (1 + value)
		elseif calculation[modType] then
			if data.Multiply then
				calculation[modType] = calculation[modType] * (1 + value)
			else
				calculation[modType] = calculation[modType] + value
			end
		end
	end
end

function DrDamage:CompareTooltip(...)
	local value = select(1,...)
	local n = select("#",...) / 2
	local text, text2
	for i = 2, n do
		local stat = select(i,...)
		if stat then
			stat = DrD_Round(stat / value, 2)
			local abbr = select(i+n,...)
			text = text and (text .. "|" .. abbr) or abbr
			text2 = text2 and (text2 .. "/" .. stat) or stat
		end
	end
	if text then
		text = "+1 " .. select(1 + n,...) .. " (" .. text .. "):"
		return text, text2
	end
end

function DrDamage:LoadData(level)
	local playerLevel = tonumber(level) or UnitLevel("player")
	--local temp1 = GetCVar("SpellTooltip_DisplayAvgValues")
	--local temp2 = GetCVar("UberTooltips")
	--local temp3 = GetCVar("showNewbieTips")
	--SetCVar("SpellTooltip_DisplayAvgValues",0)
	--SetCVar("UberTooltips",1)
	--SetCVar("showNewbieTips",0)
	for k,v in pairs(self.spellInfo) do
		if v["Data"] then
			self:Scale(k, v, v["Data"], playerLevel)
		end
		if v["Data2"] then v["Data2"](v[0], v[1], playerLevel) end
		if v["Secondary"] then
			if v["Secondary"]["Data"] then
				self:Scale(k, v["Secondary"], v["Secondary"]["Data"], playerLevel)
			end
		end
	end
	--SetCVar("SpellTooltip_DisplayAvgValues",temp1)
	--SetCVar("UberTooltips",temp2)
	--SetCVar("showNewbieTips",temp3)
end

function DrDamage:Scale(k, v, t, playerLevel)
	local spell, baseSpell = v[1], v[0]
	local scaler = self.Scaling[playerLevel]
	local c_scale = t["c_scale"]
	if c_scale then
		c_scale = c_scale + (1 - c_scale) * math_min(1, playerLevel / (t["c_scale_level"] or 80))
	else
		c_scale = 1
	end
	if t["ct_min"] and t["ct_max"] and playerLevel < 20 then
		local delta = (playerLevel - 1) * (t["ct_max"] - t["ct_min"])/19
		local penalty = (t["ct_min"] + delta) / t["ct_max"]
		c_scale = c_scale * penalty
	end
	if t[1] then
		local avg = t[1] * scaler * c_scale
		local delta = 0.5 * t[1] * (t[2] or 0) * scaler * c_scale
		spell[1] = avg - delta
		spell[2] = avg + delta
	end
	if t[3] then
		baseSpell.SPBonus = t[3] * c_scale
	end
	if t[4] then
		spell.hybridDotDmg = t[4] * scaler * c_scale
		if t[6] then
			baseSpell.SPBonus_dot = t[6] * c_scale
		end
	end
	if t["extra"] then
		spell.Extra = t["extra"] * scaler * c_scale
	end
	if t["perCombo"] then
		spell.PerCombo = t["perCombo"] * scaler * c_scale
	end
	if t["weaponDamage"] then
		if t["PPL"] and t["PPL_start"] and playerLevel > t["PPL_start"] then
			baseSpell.WeaponDamage = t["weaponDamage"] + math_min(80 - t["PPL_start"], playerLevel - t["PPL_start"]) * 0.01 * t["PPL"]
		else
			baseSpell.WeaponDamage = t["weaponDamage"]
		end
		if t["weaponDamageM"] then
			spell[1] = spell[1] * baseSpell.WeaponDamage
			spell[2] = spell[2] * baseSpell.WeaponDamage
		end
	end
	if t["APBonus"] then
		if t["PPL"] and t["PPL_start"] and playerLevel > t["PPL_start"] then
			baseSpell.APBonus = t["APBonus"] + math_min(80 - t["PPL_start"], playerLevel - t["PPL_start"]) * 0.01 * t["PPL"]
		else
			baseSpell.APBonus = t["APBonus"] * c_scale
		end
	end
end

function DrDamage:ScaleData(base, range, level, c_scale, general)
	local playerLevel = level or UnitLevel("player")
	local scaler = general and self.GeneralScaling[playerLevel] or self.Scaling[playerLevel]
	if c_scale then
		c_scale = c_scale + (1 - c_scale) * math_min(1, playerLevel / 80)
	else
		c_scale = 1
	end
	local avg = base * scaler * c_scale
	local delta = 0.5 * base * (range or 0) * scaler * c_scale
	return avg, avg - delta, avg + delta
end

local baseMeleeCrit = {
	["DEATHKNIGHT"] = 5,
	["DRUID"] = 7.48,
	["HUNTER"] = -1.53,
	["ROGUE"] = -0.3,
	["MAGE"] = 3.45,
	["PALADIN"] = 5,
	["PRIEST"] = 3.18,
	["SHAMAN"] = 2.92,
	["WARLOCK"] = 2.62,
	["WARRIOR"] = 5,
	["MONK"] = 7.48,
}
local baseSpellCrit = {
	["DEATHKNIGHT"] = 0,
	["DRUID"] = 1.85,
	["HUNTER"] = 0,
	["ROGUE"] = 0,
	["MAGE"] = 0.91,
	["PALADIN"] = 3.34,
	["PRIEST"] = 1.24,
	["SHAMAN"] = 2.2,
	["WARLOCK"] = 1.7,
	["WARRIOR"] = 0,
	["MONK"] = 1.85,
}
function DrDamage:GetCritChanceFromAgility()
	return GetCritChanceFromAgility("player") - baseMeleeCrit[playerClass]
end
function DrDamage:GetCritChanceFromIntellect()
	return GetSpellCritChanceFromIntellect("player") - baseSpellCrit[playerClass]
end

local AgiToRAP = {
 	["DEATHKNIGHT"] = 0,
	["DRUID"] = 0,
	["HUNTER"] = 2,
	["ROGUE"] = 1,
	["MAGE"] = 0,
	["PALADIN"] = 0,
	["PRIEST"] = 0,
	["SHAMAN"] = 0,
	["WARLOCK"] = 0,
	["WARRIOR"] = 1,
}
function DrDamage:GetAgiToRAP()
	return AgiToRAP[playerClass]
end

function DrDamage:StatCalc( calculation, baseSpell )
	if calculation.str ~= 0 then
		if calculation.customStats then
			calculation.str = math_max(0,calculation.str - 10)
		end
		if not calculation.ranged then
			local strToAP = GetAttackPowerForStat(1,11)
			calculation.AP_mod = calculation.AP_mod + calculation.str * strToAP
		end
		calculation.str = 0
	end
	if calculation.agi ~= 0 then
		if calculation.melee and not baseSpell.SpellCrit or calculation.caster and baseSpell.MeleeCrit then
			calculation.critPerc = calculation.critPerc + calculation.agi * ((GetCritChanceFromAgility("player") - baseMeleeCrit[playerClass]) / UnitStat("player",2))
		end
		if calculation.customStats then
			calculation.agi = math_max(0,calculation.agi - 10)
		end
		if calculation.ranged then
			calculation.AP_mod = calculation.AP_mod + calculation.agi * AgiToRAP[playerClass]
		else
			local agiToAP = GetAttackPowerForStat(2,11)
			calculation.AP_mod = calculation.AP_mod + calculation.agi * agiToAP
		end
		calculation.agi = 0
	end
	local regenRatio = calculation.regenRatio
	if calculation.caster and calculation.spi ~= 0 and (regenRatio and regenRatio > 0.01) then
		local spi = UnitStat("player",5)
		local baseRegen = calculation.spiritRegen
		local regenCoeff = baseRegen / spi
		if settings.customStats then
			calculation.combatRegen = calculation.combatRegen + regenCoeff * calculation.spi * regenRatio
			calculation.baseSpi = calculation.spi
		else
			if calculation.baseSpi then
				calculation.combatRegen = calculation.combatRegen - regenCoeff * calculation.baseSpi * regenRatio
			else
				calculation.combatRegen = calculation.combatRegen - baseRegen * regenRatio
			end
			calculation.baseSpi = math_max(0, (calculation.baseSpi or spi) + calculation.spi)
			calculation.combatRegen = calculation.combatRegen + regenCoeff * calculation.baseSpi * regenRatio
		end
		calculation.spi = 0
	end
	if calculation.int ~= 0 then
		if calculation.caster and not baseSpell.MeleeCrit or calculation.melee and baseSpell.SpellCrit then
			calculation.critPerc = calculation.critPerc + calculation.int * ((GetSpellCritChanceFromIntellect("player") - baseSpellCrit[playerClass]) / UnitStat("player",4))
		end
		if calculation.customStats then
			calculation.int = math_max(0,calculation.int - 10)
		end
		calculation.SP_mod = calculation.SP_mod + calculation.int
		calculation.int = 0
	end
end
