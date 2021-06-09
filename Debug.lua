local _, playerClass = UnitClass("player")
local playerHealer = (playerClass == "PRIEST") or (playerClass == "SHAMAN") or (playerClass == "PALADIN") or (playerClass == "DRUID")
local playerCaster = (playerClass == "MAGE") or (playerClass == "PRIEST") or (playerClass == "WARLOCK")
local playerMelee = (playerClass == "ROGUE") or (playerClass == "WARRIOR") or (playerClass == "HUNTER")
local playerHybrid = (playerClass == "DEATHKNIGHT") or (playerClass == "DRUID") or (playerClass == "PALADIN") or (playerClass == "SHAMAN")
local DrD_ClearTable = DrDamage.ClearTable
local GT = LibStub:GetLibrary("LibGratuity-3.0")

--[[
local drd_events = { ["PLAYER_ENTERING_WORLD"] = true, ["UNIT_AURA"] = true, ["LEARNED_SPELL_IN_TAB"] = true, ["UPDATE_MACROS"] = true, ["PLAYER_TARGET_CHANGED"] = true, ["EXECUTE_CHAT_LINE"] = true, ["UPDATE_SHAPESHIFT_FORM"] = true, ["AceDB20_ResetDB"] = true, ["UNIT_INVENTORY_CHANGED"] = true, ["CHARACTER_POINTS_CHANGED"] = true, ["PLAYER_TALENT_UPDATE"] = true, ["GLYPH_ADDED"] = true, ["GLYPH_UPDATED"] = true, ["GLYPH_REMOVED"] = true, ["ACTIONBAR_PAGE_CHANGED"] = true, ["ACTIONBAR_HIDEGRID"] = true }
local drd_char = { ["UNIT_COMBO_POINTS"] = true, ["UNIT_RAGE"] = true, ["UNIT_ENERGY"] = true, ["UNIT_MANA"] = true }
local drd_test = { ["UNIT_PORTRAIT_UPDATE"] = true, ["UNIT_MODEL_CHANGED"] = true }
local frame = CreateFrame("Frame")
frame:SetScript("OnEvent",
	function(this, event,arg1,arg2,arg3)
		if event == "CHAT_MSG_ADDON" then return end
		if event == "COMBAT_LOG_EVENT" then return end
		if event == "COMBAT_LOG_EVENT_UNFILTERED" then return end
		if event == "CHAT_MSG_CHANNEL" then return end
		if event == "WORLD_MAP_UPDATE" then return end
		if event == "UPDATE_WORLD_STATES" then return end
		if event == "CURSOR_UPDATE" then return end
		if event == "COMPANION_UPDATE" then return end
		if event == "TABARD_CANSAVE_CHANGED" then return end
		if event == "UPDATE_INVENTORY_DURABILITY" then return end
		if event == "UPDATE_MOUSEOVER_UNIT" then return end
		if event == "FRIENDLIST_UPDATE" then return end
		if event == "UNIT_POWER" then return end
		if event == "BAG_UPDATE_COOLDOWN" then return end

		if drd_events[event] then
		--	DrDamage:Print("CORE EVENT: " .. event, arg1, arg2, arg3)
		end
		if drd_char[event] then
		--	DrDamage:Print("CHAR EVENT: " .. event, arg1, arg2, arg3)
		end
		if drd_test[event] then
		--	DrDamage:Print("TEST EVENT: " .. event, arg1, arg2, arg3)
		end
		DrDamage:Print(event,arg1,arg2,arg3)
	end)

frame:RegisterAllEvents()
--]]

local i = 1
local max1, max2, SP1, SP2
function DrDamage:C(name)
	if i == 1 then
		_, max1 = DrDamage.spellInfo[name]["Base"](self.spellInfo[name][1])
		SP1 = GetSpellBonusDamage(2)
		i = 2
	else
		_, max2 = DrDamage.spellInfo[name]["Base"](self.spellInfo[name][1])
		SP2 = GetSpellBonusDamage(2)
		self:Print("Coefficient: ", math.abs(max2-max1)/math.abs(SP2-SP1))
		i = 1
		max1, max2, SP1, SP2 = nil
	end
end

function DrDamage:TestAll()
	self.debug = true
	local spells = 0
	self:UpdateTalents(false,true)
	for k, v in pairs( self.spellInfo ) do
		self:Print(k)
		local baseSpell = self.spellInfo[k][0]
		for i=1,#self.spellInfo[k] do
			if playerCaster or playerHybrid and not baseSpell.Melee then
				for j = 1, 3 do self:CasterCalc(k, i, true, nil, j) end
				if not baseSpell.NoTooltip then self:CasterTooltip( GameTooltip, k, i ) end
			elseif playerMelee or playerHybrid and baseSpell.Melee then
				for j = 1, 3 do self:MeleeCalc(k, i, true, nil, j) end
				if not baseSpell.NoTooltip then self:MeleeTooltip( GameTooltip, k, i ) end
			end
		end
		if v["Secondary"] then
			local baseSpell = self.spellInfo[k]["Secondary"][0]
			self.db.profile.SwapCalc = not self.db.profile.SwapCalc
			for i=1,#self.spellInfo[k]["Secondary"] do
				if playerCaster or playerHybrid and not baseSpell.Melee then
					for j = 1, 3 do self:CasterCalc(k, i, true, nil, j) end
					if not baseSpell.NoTooltip then self:CasterTooltip( GameTooltip, k, i ) end
				elseif playerMelee or playerHybrid and baseSpell.Melee then
					for j = 1, 3 do self:MeleeCalc(k, i, true, nil, j) end
					if not baseSpell.NoTooltip then self:MeleeTooltip( GameTooltip, k, i ) end
				end
			end
			self.db.profile.SwapCalc = not self.db.profile.SwapCalc			
		end
		spells = spells + 1
	end
	self.debug = false
	self:Print( "Tested: " .. spells .. " spells.")
end

function DrDamage:Debug()
	self.debug = not self.debug
	self:Print( "Debug: ", self.debug )
end

--[[
--Used for harvesting base value increases:
function DrDamage:HarvestValues(id, rk)
	local name, rank
	if rk then
		GT:SetHyperlink(GetSpellLink(id, rk))
		name, rank = GetSpellInfo(id, rk)
	else
		GT:SetHyperlink(GetSpellLink(id))
		name, rank = GetSpellInfo(id)
	end
	rank = rank and tonumber(string.match(rank,"%d+")) --or 1
	local min, max = string.match(GT:GetLine(GT:NumLines()),"(%d+) to (%d+)")
	if not min then
		min = string.match(GT:GetLine(GT:NumLines()),"causing (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"Transfers (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"Causes (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"doing (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"absorbing (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"Absorbs (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"deals (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"that causes (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"and causes (%d+) ")
		min = min or string.match(GT:GetLine(GT:NumLines()),"for (%d+) every")
		min = min or string.match(GT:GetLine(GT:NumLines()),"for (%d+) ")
		--min = min or string.match(GT:GetLine(GT:NumLines()),"(%d+)%.")
	end
	if not max then
		max = min
	end
	self:Print(name, rank, min, max)
	return name, rank, min, max
end

function DrDamage:Wowhead()
	local stuff = ""
	local table = {}
	local i = 1
	for k in string.gmatch(stuff,"spell=(%d+)") do
		table[i] = k
		i = i + 1
	end
	return table
end

local harvesttable = {}
local ranktable = {}
function DrDamage:Harvest(input,remove,rpercent,secondary,force)
	if input and input == 1 then
		input = DrDamage:Wowhead()
	end
	if input then
		local error
		if not remove then remove = 0 end
		if not rpercent then rpercent = 0 end
		DrD_ClearTable( harvesttable )
		DrD_ClearTable( ranktable )
		local entries = 0
		if (type(input) == "table") then
			self:Print("Using wowhead IDs")
			ranktable = input
		elseif GetSpellInfo(input,"Rank 1") then
			self:Print("Using spellbook ranks")
			for i = 1, 20 do
				if GetSpellInfo(input, "Rank " .. i) then
					ranktable[i] = "Rank " .. i
				end
			end
		else
			self:Print("Using spellID iterate")
			local j = 1
			for i=1,100000 do
				local sname, srank = GetSpellInfo(i)
				srank = srank and string.match(srank,"%d+")
				if input == sname and srank then
					ranktable[j] = i
					j = j + 1
				end
			end
		end
		for _, k in ipairs(ranktable) do
			entries = entries + 1
			local name, rank, min, max
			if (type(k) == "string") then
				name, rank, min, max = DrDamage:HarvestValues(input, k)
				ChatFrame1:AddMessage(GetSpellLink(input, k))
			else
				name, rank, min, max = DrDamage:HarvestValues(k)
				ChatFrame1:AddMessage(GetSpellLink(k))
			end
			local data = secondary and DrDamage.spellInfo[name] and DrDamage.spellInfo[name]["Secondary"] or DrDamage.spellInfo[name]
			if name and rank and data and data[rank] and min and max then
				local oldmin, oldmax, spellLevel = data[rank][1], data[rank][2]
				if harvesttable[rank] and ((harvesttable[rank][1] ~= min) or (harvesttable[rank][2] ~= max)) then
					self:Print("WARNING: Rank " .. rank .. " already exists in table with different values.")
					error = true
				else
					harvesttable[rank] = { min, max, oldmin, oldmax, data[rank] }
				end
			end
		end
		self:Print("NOTE: Spell ID entries: " .. entries)
		if #harvesttable > 0 then
			for i=1,#harvesttable do
				local val = harvesttable[i]
				if val then
					self:Print( "Rank " .. i .. ": " .. val[1] .. "-" .. val[2] .. " from " .. val[3] .. "-" .. val[4] )
				else
					self:Print( "Rank " .. i .. ": Error")
					error = true
				end

			end
			if not error or force then
				self:Print("Difference table:")
				for i=1,#harvesttable do
					local val = harvesttable[i]
					local rankstring = "[" .. i .. "]" .. " = { " .. val[3] .. ", " .. val[4] .. ", " .. (val[1] - val[3] - remove - rpercent * val[3]) .. ", " .. (val[2] - val[4] - remove - rpercent * val[4])
					for k, v in pairs(val[5]) do
						if type(k) ~= "number" then
							rankstring = rankstring .. ", " .. k .. " = " .. v
						end
					end
					rankstring = rankstring .. ", },"
					ChatFrame1:AddMessage( rankstring )
				end
			end
		end
	end
end


local calctable = {
	["group"] = false,
	["subType"] = false,
	["healingSpell"] = false,
	["physical"] = false,
	["name"] = false,
	["spellName"] = false,
}
setmetatable(calctable, { __index = function() return 0 end })
local empty = {}

function DrDamage:GetModifier(school, Talents, baseSpell)
	DrD_ClearTable( empty )
	--empty.SpellCrit = false
	--empty.MeleeCrit = false
	--empty.MeleeHaste = false
	calctable.school = school
	calctable.dmgM = 1
	calctable.dmgM_dot = 1
	calctable.dmgM_Extra = 1
	calctable.critPerc = 0
	calctable.hitPerc = 0
	calctable.critM = 0
	calctable.haste = 1

	for index=1,40 do
		local buffName, rank, texture, apps = UnitBuff("player",index)
		if buffName then
			local aura = self.PlayerAura[buffName]
			if aura and not aura.Update then
				self.BuffCalc( aura, calctable, empty, Talents or empty, baseSpell or empty, buffName, index, apps, texture, rank )
				empty[buffName] = true
			end
		else break end
	end
	for index=1,40 do
		local buffName, rank, texture, apps = UnitDebuff("target",index)
		if buffName then
			local aura = self.TargetAura[buffName]
			if aura and not aura.Update then
				self.BuffCalc( aura, calctable, empty, Talents or empty, baseSpell or empty, buffName, index, apps, texture, rank )
				empty[buffName] = true
			end
		else break end
	end
	if next(settings["PlayerAura"]) then
		for buffName in pairs(settings["PlayerAura"]) do
			local aura = self.PlayerAura[buffName]
			if aura and not empty[buffName] then
				self.BuffCalc( aura, calctable, empty, Talents or empty, baseSpell or empty, buffName )
			end
		end
	end
	if next(settings["TargetAura"]) then
		for buffName in pairs(settings["TargetAura"]) do
			local aura = self.TargetAura[buffName]
			if aura and not empty[buffName] then
				self.BuffCalc( aura, calctable, empty, Talents or empty, baseSpell or empty, buffName )
			end
		end
	end
	return calctable.dmgM, calctable.critPerc
end
--]]

--[[
function DrDamage:ScanTooltip(id, range, order, over, pattern, ...)
	GT:SetSpellByID(id)
	local text = GT:GetLine(GT:NumLines())
	local min, max
	if not pattern then
		if range then
			pattern = "(%d+)%s?%D%D?%D?%D?%s?(%d+)"
			--self:Print(text)
			--pattern = "(%d+)%s?%-%s?(%d+)" end
		else pattern = "%d+[^%d%%]" end
	end
	if over then
		local i = 1
		for w in string.gmatch(text,pattern) do
			w = tonumber(w)
			if w > over then
				if not order or i == order then
					min = w
					break
				end
				i = i + 1
			end
		end
	elseif order then
		local i = 1
		for w1, w2 in string.gmatch(text,pattern) do
			if i == order then
				min, max = tonumber(w1), tonumber(w2)
				break
			end
			i = i + 1
		end
	elseif ... then
		for w in string.gmatch(text,pattern) do
			min = tonumber(w)
			local ignore = false
			for i = 1, select('#', ...) do
				if select(i, ...) == min then
					ignore = true
					break
				end
			end
			if not ignore then break end
		end
	else
		min, max = string.match(text,pattern)
		min = tonumber(min)
		max = tonumber(max)
	end
	if not min then
		min = 0
	end
	if not max then
		max = min
	end
	return min, max
end

function DrDamage:IB2(k, v, func)
		local spell, baseSpell = v[1], v[0]
		local min, max, dot, dmgM, bMin, bMax = func(spell)
		--@debug@
		self:Print(k," tooltip ", min ,"-", max)
		if dot then
		self:Print(k," tooltip dot ", dot)
		end
		--@end-debug@
		local calculation = DrDamage:Calc(k, false, false, true)
		local bonus = (calculation.modDuration or 1) * (calculation.SPBonus * calculation.SP + calculation.APBonus * calculation.AP) / (baseSpell.Hits or 1)
		min = math_max(0, (min / (dmgM or calculation.dmgM) - bonus) / calculation.bDmgM )
		max = math_max(0, (max / (dmgM or calculation.dmgM) - bonus) / calculation.bDmgM )
		spell[1] = min * (bMin or 1)
		spell[2] = max * (bMax or 1)
		if dot then
			dot = dot / calculation.dmgM_dot - calculation.SPBonus_dot * calculation.SP * calculation.modDuration
			spell.hybridDotDmg = math_max(0, dot)
		end
		--@debug@
		self:Print(k," multiplier at ", (dmgM or calculation.dmgM))
		--self:Print(k," bonus at ", bonus)
		--self:Print(k," base ", min ,"-", max)
		--if dot then self:Print(k, " dot value set to ", dot) end
		--@end-debug@
end
--]]