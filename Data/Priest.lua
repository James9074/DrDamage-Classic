if select(2, UnitClass("player")) ~= "PRIEST" then return end
local GetSpellInfo = DrDamage.SafeGetSpellInfo
local UnitExists = UnitExists
local UnitIsFriend = UnitIsFriend
local UnitIsUnit = UnitIsUnit
local UnitHealth = UnitHealth
local UnitHealthMax = UnitHealthMax
local UnitPowerMax = UnitPowerMax
local math_min = math.min
local select = select
local IsSpellKnown = IsSpellKnown
local shadow_orbs_last = 0

function DrDamage:PlayerData()
	--Health Updates (All healing, Shadow Word: Death, Flash Heal)
	self.TargetHealth = { [1] = 0.501, [2] = 0.251, [0.251] = { [GetSpellInfo(32379)] = true, [GetSpellInfo(2061)] = true } }
	--Shadowfiend 4.0
	self.ClassSpecials[GetSpellInfo(34433)] = function()
		return 0.3 * UnitPowerMax("player",0), false, true
	end
	--Dispersion 4.0
	self.ClassSpecials[GetSpellInfo(47585)] = function()
		return 0.36 * UnitPowerMax("player",0), false, true
	end
	--Dispel Magic 4.0
	self.ClassSpecials[GetSpellInfo(527)] = function()
		--Glyph of Dispel Magic 4.0
		if self:HasGlyph(55677) then
			local heal
			if UnitExists("target") and UnitIsFriend("target","player") then
				heal = 0.03 * UnitHealthMax("target")
			else
				heal = 0.03 * UnitHealthMax("player")
			end
			return heal, true
		end
	end
--GENERAL
	self.Calculation["Stats"] = function( calculation, ActiveAuras, Talents, spell, baseSpell )
		local mastery = calculation.mastery
		local masteryLast = calculation.masteryLast
		local spec = calculation.spec
		if spec == 1 then
			if mastery > 0 and mastery ~= masteryLast then
				if calculation.healingSpell and calculation.subType == "Absorb" then
					local masteryBonus = calculation.masteryBonus
					if masteryBonus then
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					local bonus = 1 + (mastery * 0.01)
					calculation.dmgM = calculation.dmgM * bonus
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
			if IsSpellKnown(47515) and (calculation.healingSpell and calculation.subType ~= "Absorb") then
				--Divine Aegis creates a bubble equal to the healing of the original spell, based on crit chance, and prevents healing spells from
				--having a critical strike.  This should be affected by mastery.
				local daicon = "|T" .. select(3,GetSpellInfo(47515)) .. ":16:16:1:-1|t"
				local masteryBonus = calculation.masteryBonus
				local masteryLast = calculation.masteryLast
				--Spells can no longer crit once Divine Aegis is learned
				calculation.critM = 0
				--Base of extraCrit is equal to the healing spell itself.
				calculation.extraCrit = 1
				--Chance to proc the extra absorb is the critical strike chance
				calculation.extraChance = calculation.critPerc * 0.01
				--If mastery is known, then add the multiplier on top of that from mastery.
				if mastery > 0 and mastery ~= masteryLast then
					if masteryBonus then
						--Divide it back out to get the real bonus
						calculation.dmgM = calculation.dmgM / masteryBonus
					end
					local bonusabsorb = 1 + (mastery * 0.01)
					local bonus = 1 + ((mastery * 0.01) * 0.5)
					calculation.dmgM = calculation.dmgM * bonus
					calculation.extraCrit = calculation.extraCrit * bonusabsorb
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonusabsorb
				end
				calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. daicon) or daicon
			end
		elseif spec == 2 then
			if mastery > 0 and mastery ~= masteryLast then
				if baseSpell.DirectHeal then
					baseSpell.NoDotHaste = true
					local bonus = mastery * 0.01 
					calculation.hybridDotDmg = bonus * (0.5 * (calculation.minDam + calculation.maxDam))
					calculation.SPBonus_dot = bonus * calculation.SPBonus
					calculation.eDuration = 6
					calculation.sTicks = 1
					calculation.dotStacks = true
					calculation.masteryLast = mastery
				end
			end
		elseif spec == 3 then
			if mastery > 0 and mastery ~= masteryLast then
				if ActiveAuras["Shadow Orb"] then
					calculation.dmgM = calculation.dmgM / (1 + ActiveAuras["Shadow Orb"] * (0.1 + (calculation.masteryBonus or 0)))
					--Additional damage from Shadow Orbs due to Mastery.
					--Mastery: Shadow Orb Power
					local bonus = mastery * 0.01 
					calculation.dmgM = calculation.dmgM * (1 + ActiveAuras["Shadow Orb"] * (0.1 + bonus))
					calculation.masteryLast = mastery
					calculation.masteryBonus = bonus
				end
			end
		end
		if calculation.spi ~= 0 then
			if IsSpellKnown(47573) then
				--Grants you spell hit rating equal to 50%/100% of any Spirit gained from items or effects.
				local rating = calculation.spi 
				calculation.hitPerc = calculation.hitPerc + self:GetRating("Hit", rating, true)
			end
		end
	end
	self.Calculation["PRIEST"] = function ( calculation, ActiveAuras, _, spell, baseSpell )
		--General stats
		if IsSpellKnown(89745) then
			calculation.intM = calculation.intM * 1.05
		end
		--Specialization
		local spec = calculation.spec
		if ActiveAuras["Shadowform"] then
			calculation.dmgM = calculation.dmgM * 1.25
		end
		if IsSpellKnown(87336) and baseSpell.SpiritualHealing then
			calculation.dmgM = calculation.dmgM * 1.25
		end
	end
--TALENTS
	local daicon = "|T" .. select(3,GetSpellInfo(47515)) .. ":16:16:1:-1|t"
	self.Calculation["Divine Aegis"] = function( calculation, value )
		if calculation.spellName == "Prayer of Healing" then
			calculation.extraAvg = value
		else
			calculation.extraCrit = value / (calculation.hits or 1)
			calculation.extraChanceCrit = true
		end
		calculation.extraName = daicon
	end
	self.Calculation["Test of Faith"] = function( calculation, value )
		local target = calculation.target
		if target and UnitHealth(target) ~= 0 and (UnitHealth(target) / UnitHealthMax(target)) <= 0.5 then
			calculation.dmgM = calculation.dmgM * (1 + value)
		end
	end
--ABILITIES
	self.Calculation["Mind Flay"] = function ( calculation, ActiveAuras )
		--PW Insanity
		if IsSpellKnown(139139) and ActiveAuras["Devouring Plague"] then
			bonus = 1 + (shadow_orbs_last * 0.33333)
			calculation.dmgM = calculation.dmgM * bonus
		end
	end
	local shadowy_apparition_icon = "|T" .. select(3,GetSpellInfo(78203)) .. ":16:16:1:-1|t"
	self.Calculation["Shadow Word: Pain"] = function ( calculation, ActiveAuras )
		if self:GetSetAmount( "T14 Damage" ) >= 2 then
			calculation.critPerc = calculation.critPerc + 10
		end
		if self:GetSetAmount( "T14 Damage" ) >= 4 then
			calculation.hits = calculation.hits + 1
		end
		if IsSpellKnown(78203) then
			local bonus = 1
			calculation.extra = self:ScaleData(0.375) * bonus
			calculation.extraDamage = 0.375
			calculation.extraBonus = true
			calculation.extraCanCrit = true --Let's assume this crits for now
			calculation.extraChance = calculation.critPerc * 0.01
			calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. shadowy_apparition_icon) or shadowy_apparition_icon
		end
	end
	self.Calculation["Lightwell"] = function( calculation )
		--Glyph of Lightwell 4.0
		if self:HasGlyph(55673) then
			--TODO: stacks??
			calculation.hits = calculation.hits + 2
		end
	end
	self.Calculation["Shadow Word: Death"] = function( calculation, ActiveAuras )
		if self:GetSetAmount( "T13 Damage" ) >= 2 then
			calculation.dmgM_Add = calculation.dmgM_Add + 0.55
		end		
	end
	self.Calculation["Smite"] = function( calculation, ActiveAuras )
		--Glyph of Smite MoP
		if self:HasGlyph(55692) and ActiveAuras["Holy Fire"] then
 			calculation.dmgM = calculation.dmgM * 1.2
		end
	end
		
	local glyph = GetSpellInfo(52817)
	local glyphicon = "|TInterface\\Icons\\INV_Glyph_MajorPriest:16:16:1:-1|t"	
	self.Calculation["Power Word: Shield"] = function( calculation, _ )
		local auraMod = calculation.dmgM
		local spec = calculation.spec
		-- Rapture
		if IsSpellKnown(47536) then
			calculation.Cooldown = 0
			calculation.manaCost = calculation.manaCost * 0.75
		end
		--Divine Aegis, once known, allows this spell to crit.  So, if this isn't known, the spell doesn't crit for twice the heal.
		if (not IsSpellKnown(47515)) then
			calculation.critM = 0
		end
		-- As of 5.2, these specs get modifiers for PW:S
		if spec == 1 then
			calculation.dmgM = calculation.dmgM * 1.1277
		end
	end
	self.Calculation["Circle of Healing"] = function( calculation )
		--Glyph of Circle of Healing 4.0
		if self:HasGlyph(55675) then
			calculation.aoe = calculation.aoe + 1
		end
		if self:GetSetAmount( "T14 Healing" ) >= 4 then
			calculation.cooldown = calculation.cooldown - 4
		end
                if self:GetSetAmount( "T15 Healing" ) >= 4 then
                        calculation.extra = 100000
                        calculation.extraDamage = 0
                        calculation.extraChance = 0.4
                        calculation.extraName = calculation.extraName and (calculation.extraName .. " + T15 4pc ") or "T15 4pc"
                end
	end
	self.Calculation["Divine Hymn"] = function( calculation )
		if calculation.targets > 1 then
			calculation.hits = calculation.hits * math_min(5, calculation.targets)
		end
	end
	self.Calculation["Prayer of Mending"] = function( calculation )
		--Glyph of Prayer of Mending (4.0.6)
		if self:HasGlyph(55685) then
			calculation.finalMod_M = 1.6
			calculation.hits = calculation.hits - 1
		end
		if self:GetSetAmount( "T15 Healing" ) >= 2 then	
			calculation.chainBonus = 1.1
		end
	end
	self.Calculation["Desperate Prayer"] = function( calculation )
		calculation.minDam = 0.3 * UnitHealthMax("player")
		calculation.maxDam = calculation.minDam
	end
	self.Calculation["Renew"] = function ( calculation )
		if self:HasGlyph(119872) then
			calculation.dmgM = calculation.dmgM * 1.333
		end
		if IsSpellKnown(95649) then
			calculation.dmgM = calculation.dmgM * 1.15
		end
	end
	self.Calculation["Penance"] = function (calculation)
		if self:GetSetAmount( "T14 Healing" ) >= 4 then
			calculation.cooldown = calculation.cooldown - 3
		end
		if self:GetSetAmount( "T15 Healing" ) >= 4 then
			calculation.extra = 100000
			calculation.extraDamage = 0
			calculation.extraChance = 0.4
			calculation.extraName = calculation.extraName and (calculation.extraName .. " + T15 4pc ") or "T15 4pc"
		end
	end
	self.Calculation["Devouring Plague"] = function (calculation)
		local shadoworbs = math_min(3,UnitPower("player",13))
		if shadoworbs > 0 then
			calculation.dmgM = calculation.dmgM * shadoworbs
			shadow_orbs_last = shadoworbs
		end
	end
	self.Calculation["Flash Heal"] = function (calculation)
		if self:GetSetAmount( "T14 Healing" ) >= 2 then
			calculation.manaCost = calculation.manaCost * 0.8
		end
	end
	self.Calculation["Vampiric Touch"] = function (calculation)
		if self:GetSetAmount( "T15 Damage" ) >= 4 then
			-- This is probably a given that shadowy apparitions is Known, but just in case...
			if IsSpellKnown(87532) then
				local bonus = 1
				calculation.extra = self:ScaleData(0.375) * bonus
				calculation.extraDamage = 0.375
				calculation.extraBonus = true
				calculation.extraCanCrit = true --Let's assume this crits for now
				calculation.extraChance = 0.1
				calculation.extraName = calculation.extraName and (calculation.extraName .. "+" .. shadowy_apparition_icon) or shadowy_apparition_icon
			end
		end
	end

--SETS
	self.SetBonuses["T13 Damage"] = { 78682, 78703, 78722, 78750, 78731, 76348, 76347, 76346, 76345, 76344, 78777, 78798, 78817, 78845, 78826 }
	self.SetBonuses["T14 Healing"] = { 86699, 86700, 86701, 86702, 86703, 85359, 85360, 85361, 85362, 85363, 87114, 87115, 87116, 87117, 87118 }
	self.SetBonuses["T14 Damage"] = { 86704, 86705, 86706, 86707, 86708, 85364, 85365, 85366, 85367, 85368, 87119, 87120, 87121, 87122, 87123 }
	self.SetBonuses["T15 Healing"] = { 95295, 95296, 95297, 95298, 95299, 95925, 95926, 95927, 95928, 95929, 96669, 96670, 96671, 96672, 96673 }
	self.SetBonuses["T15 Damage"] = { 95930, 95931, 95392, 95393, 95394, 95300, 95301, 95302, 95303, 95304, 96674, 96675, 96676, 96677, 96678 }
--AURA
--Player
	--Shadowform MoP
	self.PlayerAura[GetSpellInfo(15473)] = { School = "Shadow", ActiveAura = "Shadowform", ID = 15473 }
	--Shadow Orb MoP
	self.PlayerAura[GetSpellInfo(95740)] = { Spells = "Devouring Plague", ActiveAura = "Shadow Orb", Apps = 3, ID = 95740, }
	--Inner Will MoP
	self.PlayerAura[GetSpellInfo(73413)] = { Update = true }
	--Serendipity MoP
	self.PlayerAura[GetSpellInfo(63735)] = { Update = true, Spells = { "Greater Heal", "Prayer of Healing" } }
	--Inner Focus MoP
	self.PlayerAura[GetSpellInfo(89485)] = { Spells = { "Flash Heal", "Greater Heal", "Prayer of Healing" }, ID = 89485, NoManual = true, ModType =
		function (calculation)
			calculation.critPerc = 100
		end
 	}
	--Evangelism MoP
	self.PlayerAura[GetSpellInfo(81662)] = { Spells = { "Penance", "Smite", "Holy Fire" }, NoManual = true, Apps = 5, Value = 0.04 }
	--Archangel MoP
	self.PlayerAura[GetSpellInfo(81700)] = { School = "Healing", NoManual = true, Apps = 5, Value = 0.05 }
	--Chakra: Chastise MoP
	self.PlayerAura[GetSpellInfo(81209)] = { ID = 81209, School = { "Shadow", "Holy" }, NoManual = true, Value = 0.5 }
	--Chakra: Sanctuary MoP
	self.PlayerAura[GetSpellInfo(81206)] = { ID = 81206, Spells = { "Prayer of Healing", "Circle of Healing", "Divine Hymn", "Holy Word: Sanctuary", "Halo-Healing", "Halo-Shadow", "Cascade-Healing", "Cascade-Shadow", "Divine Star-Healing", "Divine Star-Shadow" }, NoManual = true, ModType =
		function( calculation )
			calculation.dmgM = calculation.dmgM * 1.25
			if calculation.spellName == "Circle of Healing" then
				calculation.cooldown = calculation.cooldown - 2
			end
		end
	}
	--Chakra: Serenity MoP
	self.PlayerAura[GetSpellInfo(81208)] = { ID = 81208, Spells = { "Heal", "Flash Heal", "Greater Heal", "Desperate Prayer", "Binding Heal", "Holy Word: Serenity", "Renew" }, NoManual = true, Value = 0.25 }
	--Grace MoP
	self.PlayerAura[GetSpellInfo(47517)] = { Spells = { "Flash Heal", "Greater Heal", "Heal", "Penance" }, Apps = 3, SelfCastBuff = true, ID = 47517, Value = 0.1 }
	--Twist of Fate MoP
	self.PlayerAura[GetSpellInfo(123254)] = { School = "Spells", ID = 123254, Value = 0.15 }
	--Surge of Darkness
	self.PlayerAura[GetSpellInfo(87160)] = { ID = 87160, Spells = "Mind Spike", Value = 0.5, ModType = "dmgM" }
	--Power Infusion
	self.PlayerAura[GetSpellInfo(10060)] = { School = "Spells", Caster = true, Multiply = true, Mods = { ["haste"] = 0.2, ["manaCost"] = -0.2, ["dmgM"] = 0.05 }, ID = 10060 }
--Target
	--Holy Fire MoP
	self.TargetAura[GetSpellInfo(14914)] = { Spells = "Smite", ActiveAura = "Holy Fire", ID = 14914 }
	--Divine Hymn MoP
	self.TargetAura[GetSpellInfo(64844)] = { School = "Healing", Value = 0.1, Not = "Divine Hymn", NoManual = true }
	--Grace MoP
	--self.TargetAura[GetSpellInfo(47517)] = { Spells = { "Flash Heal", "Greater Heal", "Heal", "Penance" }, Apps = 3, SelfCastBuff = true, ID = 47517, Value = 0.1 }
	--Holy Word: Serenity MoP
	self.TargetAura[GetSpellInfo(88684)] = { School = "Healing", SelfCastBuff = true, ID = 88684, ModType = "critPerc", Value = 25 }
	--Devouring Plague
	self.TargetAura[GetSpellInfo(2944)] = { School = "Shadow", ID = 2944, ActiveAura = "Devouring Plague" }
	--SPELLS
	self.spellInfo = {
		[GetSpellInfo(15407)] = {
			-- Checked in 4.2
			["Name"] = "Mind Flay",
			["ID"] = 15407,
			["Data"] = { 1, 0, 0.5 },
			[0] = { School = "Shadow",  Hits = 3, sTicks = 1, Channeled = 3 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(2944)] = {
			-- Checked in 4.2
			["Name"] = "Devouring Plague",
			["ID"] = 2944,
			["Data"] = { 1.5659, 0, 0.786, 0.261, 0, 0.131 },
			[0] = { School = "Shadow", eDuration = 6, Hits_dot = 6, sTicks = 1, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(589)] = {
			-- Checked in 4.2
			["Name"] = "Shadow Word: Pain",
			["ID"] = 589,
			["Data"] = { 0.59399 * 1.25, 0, 0.293 * 1.25, 0.59399 * 1.25, 0, 0.293 * 1.25 },
			[0] = { School = "Shadow", Hits_dot = 6, eDuration = 18 , sTicks = 3 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(34914)] = {
			-- Checked in 4.2
			["Name"] = "Vampiric Touch",
			["ID"] = 34914,
			["Data"] = { 0.059 * 1.2, 0, 0.346 * 1.2 },
			[0] = { School = "Shadow", eDot = true, Hits = 5, eDuration = 15, sTicks = 3, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(32379)] = {
			-- Checked in 4.2
			["Name"] = "Shadow Word: Death",
			["ID"] = 32379,
			["Data"] = { 2.078 * 1.15, 0, 1.876 * 1.15 },
			[0] = { School = "Shadow",  Cooldown = 8, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(8092)] = {
			-- Checked in 4.2
			["Name"] = "Mind Blast",
			["ID"] = 8092,
			["Data"] = { 2.638, 0.0549, 1.909 },
			[0] = { School = "Shadow", Cooldown = 8, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(73510)] = {
			-- Checked in 4.2
			["Name"] = "Mind Spike",
			["ID"] = 73510,
			["Data"] = { 1.277, 0.054, 1.304 },
			[0] = { School = "Shadow", },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(17)] = {
			-- Checked in 4.2
			["Name"] = "Power Word: Shield",
			["ID"] = 17,
			["Data"] = { 18.51499, 0, 1.871 },
			[0] = { School = { "Holy", "Healing", "Absorb" }, Cooldown = 6, NoDPS = true, NoDoom = true, NoSchoolTalents = true, NoTypeTalents = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(2050)] = {
			-- Checked in 4.2
			["Name"] = "Heal",
			["ID"] = 2050,
			["Data"] = { 10.145, 0.15, 1.024, ["ct_min"] = 1500, ["ct_max"] = 3000 },
			[0] = { School = { "Holy", "Healing" }, DirectHeal = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(2060)] = {
			-- Checked in 4.2
			["Name"] = "Greater Heal",
			["ID"] = 2060,
			["Data"] = { 21.658, 0.15, 2.190 },
			[0] = { School = { "Holy", "Healing" }, DirectHeal = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(596)] = {
			-- Checked in 4.2
			["Name"] = "Prayer of Healing",
			["ID"] = 596,
			["Data"] = { 8.280, 0.055, 0.838 },
			[0] = { School = { "Holy", "Healing" }, DirectHeal = true, AoE = 5 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(34861)] = {
			-- Checked in 4.2
			["Name"] = "Circle of Healing",
			["ID"] = 34861,
			["Data"] = { 4.613, 0.1, 0.467 },
			[0] = { School = { "Holy", "Healing" }, AoE = 5, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(2061)] = {
			-- Checked in 4.2
			["Name"] = "Flash Heal",
			["ID"] = 2061,
			["Data"] = { 16.245 * 0.8, 0.15, 1.642 * 0.8 },
			[0] = { School = { "Holy", "Healing" }, DirectHeal = true, SpiritualHealing = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(19236)] = {
			-- Checked in 4.2
			["Name"] = "Desperate Prayer",
			["ID"] = 19236,
			[0] = { School = { "Holy", "Healing" }, DirectHeal = true, NoCrits = true, Cooldown = 120, NoDoom = true, SelfHeal = true, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(139)] = {
			-- Checked in 4.2
			["Name"] = "Renew",
			["ID"] = 139,
			["Data"] = { 2.563999 * 0.8, 0, 0.259 * 0.8 },
			[0] = { School = { "Holy", "Healing" }, Hits = 4, eDuration = 12, sTicks = 3, eDot = true, SpiritualHealing = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(32546)] = {
			-- Checked in 4.2
			["Name"] = "Binding Heal",
			["ID"] = 32546,
			["Data"] = { 9.494 * 0.8, 0.25, 0.8989 * 0.8 },
			[0] = { School = { "Holy", "Healing" }, DirectHeal = true, SpiritualHealing = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(33076)] = {
			-- Checked in 4.2
			["Name"] = "Prayer of Mending",
			["ID"] = 33076,
			["Data"] = { 5.64 * 0.8, 0, 0.571 * 0.8 },
			[0] = { School = { "Holy", "Healing" }, Cooldown = 10, Hits = 5, NoDPS = true, NoPeriod = true, SpiritualHealing = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(88625)] = {
			-- Checked in 4.2
			["Name"] = "Holy Word: Chastise",
			["ID"] = 88625,
			["Data"] = { 0.633, 0.115, 0.614 },
			[0] = { School = "Holy", Cooldown = 30 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(88685)] = {
			-- Checked in 4.2
			["Name"] = "Holy Word: Sanctuary",
			["ID"] = 88685,
			["Data"] = { 0.48, 0.173, 0.058 },
			[0] = { School = { "Holy", "Healing" }, Cooldown = 40, Hits = 15, AoE = 6, eDot = true, eDuration = 30, sTicks = 2, },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(88684)] = {
			-- Checked in 4.2
			["Name"] = "Holy Word: Serenity",
			["ID"] = 88684,
			["Data"] = { 12.810, 0.16, 1.30 },
			[0] = { School = { "Holy", "Healing" }, Cooldown = 10, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(585)] = {
			-- Checked in 4.0.3
			["Name"] = "Smite",
			["ID"] = 585,
			["Data"] = { 2.25, 0.115, 0.856, ["ct_min"] = 1500, ["ct_max"] = 2500 },
			[0] = { School = "Holy", },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(14914)] = {
			-- Checked in 4.2
			["Name"] = "Holy Fire",
			["ID"] = 14914,
			["Data"] = { 1.083, 0.238, 1.11, 0.054, 0, 0.0312 },
			[0] = { School = "Holy",  Cooldown = 10, Hits_dot = 7, eDuration = 7, sTicks = 1 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(132157)] = {
			-- Provided by glyph in Mists.
			["Name"] = "Holy Nova",
			["ID"] = 132157,
			["Data"] = { 1.94, 0.15, 0.247 },
			["Text1"] = GetSpellInfo(132157),
			["Text2"] = GetSpellInfo(37455),
			[0] = { School = { "Holy", "Healing", "Holy Nova Heal" }, AoE = 5 },
			[1] = { 0, 0 },
			["Secondary"] = {
					["Name"] = "Holy Nova",
					["ID"] = 132157,
					["Data"] = { 0.316, 0.15, 0.143 },
					["Text1"] = GetSpellInfo(132157),
					["Text2"] = GetSpellInfo(48360),
					[0] = { School = { "Holy", "Holy Nova Damage" }, AoE = true },
					[1] = { 0, 0 },
			}
		},
		[GetSpellInfo(724)] = {
			["Name"] = "Lightwell",
			["ID"] = 724,
			["Data"] = { 3 * 5.465 * 1.15, 0, 3 * 0.553 * 1.15 },
			[0] = { School = { "Holy", "Healing" }, Cooldown = 180, Hits = 3, eDot = true, eDuration = 6, sTicks = 2, Stacks = 15 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(64843)] = {
			-- Checked in 4.2
			["Name"] = "Divine Hymn",
			["ID"] = 64843,
			["Data"] = { 7.612, 0, 1.542 },
			[0] = { School = { "Holy", "Healing" }, eDot = true, eDuration = 8, sTicks = 2, Hits = 4, Cooldown = 360, Channeled = 8, DirectHeal = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(48045)] = {
			-- Checked in 4.2
			["Name"] = "Mind Sear",
			["ID"] = 48045,
			["Data"] = { 0.30, 0.080, 0.30 },
			[0] = { School = "Shadow", Hits = 5, Channeled = 5, AoE = true },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(47540)] = {
			-- Checked in 4.2
			["Name"] = "Penance",
			["ID"] = 47540,
			["Data"] = { 8.3091, 0.122, 1.12 },
			[0] = { School = { "Holy", "Healing" }, Cooldown = 10, Hits = 3, Channeled = 2 },
			[1] = { 0, 0 },
			["Secondary"] = {
					["Name"] = "Penance",
					["ID"] = 47540,
					["Data"] = { 1.0301, 0.122, 0.838 },
					[0] = { School = "Holy", Cooldown = 10,  Hits = 3, Channeled = 2, },
					[1] = { 0, 0 },
			}
		},
		[GetSpellInfo(121148)] = {
			["Name"] = "Cascade-Healing",
			["ID"] = 121148,
			["Data"] = { 12, 0, 1.225 },
			["Text1"] = GetSpellInfo(121148),
			["Text2"] = GetSpellInfo(120785),
			[0] = { School = { "Holy", "Healing" }, AoE = 6, Cooldown = 25, DirectHeal = true },
			[1] = { 0, 0 },
			["Secondary"] = {
				["Name"] = "Cascade-Shadow",
				["ID"] = 120785,
				["Data"] = { 12, 0, 1.225 },
				["Text1"] = GetSpellInfo(121148),
				["Text2"] = GetSpellInfo(120785),
				[0] = { School = { "Holy", "Shadow" }, AoE = 6, Cooldown = 25 },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(122121)] = {
			["Name"] = "Divine Star-Shadow",
			["ID"] = 122121,
			["Data"] = { 4.4952, 0.5, 0.455 },
			["Text1"] = GetSpellInfo(110744),
			["Text2"] = GetSpellInfo(110744),
			[0] = { School = { "Shadow", "Holy" }, AoE = true, Cooldown = 15 },
			[1] = { 0, 0 },
			["Secondary"] = {
				["Name"] = "Divine Star-Healing",
				["ID"] = 122121,
				["Data"] = { 7.4924, 0.5, 0.758 },
				["Text1"] = GetSpellInfo(110744),
				["Text2"] = GetSpellInfo(110744),
				[0] = { School = { "Holy", "Healing", "Shadow" }, AoE = true, Cooldown = 15, DirectHeal = true },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(120696)] = {
			["Name"] = "Halo-Shadow",
			["ID"] = 120696,
			["Data"] = { 19.266, 0.5, 1.95 },
			["Text1"] = GetSpellInfo(120696),
			["Text2"] = GetSpellInfo(120696),
			[0] = { School = { "Shadow", "Holy" }, AoE = true, Cooldown = 40 },
			[1] = { 0, 0 },
			["Secondary"] = {
				["Name"] = "Halo-Healing",
				["Data"] = { 32.11, 0.5, 3.25 },
				["ID"] = 120692,
				["Text1"] = GetSpellInfo(120692),
				["Text2"] = GetSpellInfo(120692),
				[0] = { School = { "Holy", "Healing", "Shadow" }, AoE = true, Cooldown = 40, DirectHeal = true },
				[1] = { 0, 0 },
			},
		},
		[GetSpellInfo(129250)] = {
			["Name"] = "Power Word: Solace",
			["ID"] = 129250,
			["Data"] = { 1.0829, 0.115, 1.11, 0.3802, 0, 0.0312 },
			[0] = { School = { "Holy" }, Cooldown = 10, eDuration = 7, sTicks = 1, Hits_dot = 7 },
			[1] = { 0, 0 },
		},
		[GetSpellInfo(129240)] = { 
			["Name"] = "Power Word: Insanity",
			["ID"] = 129249,
			["Data"] = { 2.90, 0.054, 2.90 },
			[0] = { School = { "Shadow" } } , 
			[1] = { 0, 0 },
		},
	}
	self.talentInfo = {
	--DISCIPLINE:
		[GetSpellInfo(63574)] = {	[1] = { Effect = -1, Spells = "Power Word: Shield", ModType = "cooldown" }, },
	--HOLY:
		[GetSpellInfo(95649)] = {	[1] = { Effect = -0.5, Spells = "Renew", ModType = "castTime" }, },
	--SHADOW:
		--[GetSpellInfo(15273)] = { 	[1] = { Effect = -0.5, Spells = "Mind Blast", ModType = "cooldown" }, },
	}
end
