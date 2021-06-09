local DrDamage = DrDamage
local GetSpellInfo = GetSpellInfo
local UnitStat = UnitStat
local math_floor = math.floor
DrDamage.PlayerAura = {}
DrDamage.TargetAura = {}
DrDamage.Consumables = {}
DrDamage.Calculation = {}

function DrDamage.SafeGetSpellInfo(...)
	local name, rank, icon, cost, isFunnel, powerType, castTime = GetSpellInfo(...)
	--@debug@
	if not name then
		local id = ...
		DrDamage:Print("SpellID does not exist: " .. id)
	end
	--@end-debug@
	return name or "", rank, icon or "", cost or 0, isFunnel, powerType, castTime
end

local function DrD_LoadAuras()
	local L = LibStub("AceLocale-3.0"):GetLocale("DrDamage", true)
	local playerClass = select(2,UnitClass("player"))
	local DK = (playerClass == "DEATHKNIGHT")
	local Hunter = (playerClass == "HUNTER")
	local Rogue = (playerClass == "ROGUE")
	local Mage = (playerClass == "MAGE")
	local Paladin = (playerClass == "PALADIN")
	local Warrior = (playerClass == "WARRIOR")
	local Priest = (playerClass == "PRIEST")
	local Warlock = (playerClass == "WARLOCK")
	local Druid = (playerClass == "DRUID")
	local Shaman = (playerClass == "SHAMAN")
	local Monk = (playerClass == "MONK")
	local playerHealer = Priest or Shaman or Paladin or Druid
	local playerCaster = Mage or Priest or Warlock
	local playerMelee = Rogue or Warrior or Hunter
	local playerHybrid = DK or Druid or Paladin or Shaman

	local Aura = DrDamage.PlayerAura
	local GetSpellInfo = DrDamage.SafeGetSpellInfo
	local horde = (UnitFactionGroup("player") == "Horde")
	local UnitBuff = UnitBuff
	local select = select

	--[[ NOTES:
	 	School = "Spells" means it applies to both heals and spells
	 	School = "Damage Spells" means it applies to all damaging spells
		School = "Healing" applies only to heals
		School = "Physical" applies only to abilities dealing physical damage, which is the default in melee module unless otherwise specified
		School = "All" applies to everything
		No school or spell applies to everything but healing
		Caster = true or Melee = true limits it to respective modules
	--]]

	--20% Crit Damage
		--Skull Banner (may need to verify aura id)
		Aura[GetSpellInfo(114206)] = { ActiveAura = "Skull Banner", Value = 0.20, Category = "+20% crit dmg", ID = 114206, ModType = "critM" }
	--+30% Haste
		--Ancient Hysteria
		Aura[GetSpellInfo(90355)] = { School = "All", Category = "30% haste", ID = 90355, CustomHaste = true, Multiply = true, Mods = { ["haste"] = 0.3 }, NoManual = not Hunter }
		--Time Warp
		Aura[GetSpellInfo(80353)] = { School = "All", Category = "30% haste", ID = 80353, CustomHaste = true, Multiply = true, Mods = { ["haste"] = 0.3 }, NoManual = not Mage }	
		if horde then
			--Bloodlust
			Aura[GetSpellInfo(2825)] = { School = "All", Category = "30% haste", ID = 2825, CustomHaste = true, Multiply = true, Mods = { ["haste"] = 0.3 } }
		else
			--Heroism
			Aura[GetSpellInfo(32182)] = { School = "All", Category = "30% haste", ID = 32182, CustomHaste = true, Multiply = true, Mods = { ["haste"] = 0.3 } }
		end
	--+5% crit
		--Leader of the Pack (Druid)
		Aura[GetSpellInfo(17007)] = { School = "All", Category = "+5% crit", ID = 17007, Mods = { ["spellCrit"] = 5, ["meleeCrit"] = 5 } }
		--Legacy of the White Tiger (Monk)
		Aura[GetSpellInfo(116781)] = { School = "All", Category = "+5% crit", ID = 116781, Mods = { ["spellCrit"] = 5, ["meleeCrit"] = 5 } }
		--Bellowing Roar (Hunter Pet)
		Aura[GetSpellInfo(97229)] = { School = "All", Category = "+5% crit", ID = 97229, Mods = { ["spellCrit"] = 5, ["meleeCrit"] = 5 }, NoManual = not Hunter }
		--Terrifying Roar (Hunter Pet)
		Aura[GetSpellInfo(90309)] = { School = "All", Category = "+5% crit", ID = 90309, Mods = { ["spellCrit"] = 5, ["meleeCrit"] = 5 }, NoManual = not Hunter }
		--Fearless Roar (Hunter Pet)
		Aura[GetSpellInfo(126373)] = { School = "All", Category = "+5% crit", ID = 126373, Mods = { ["spellCrit"] = 5, ["meleeCrit"] = 5 }, NoManual = not Hunter}
		--Furious Howl (Hunter Pet)
		Aura[GetSpellInfo(24604)] = { School = "All", Category = "+5% crit", ID = 24604, Mods = { ["spellCrit"] = 5, ["meleeCrit"] = 5 }, NoManual = not Hunter}		
	--5% Str/Agi/Int
		--Blessing of Kings (Paladin)
		Aura[GetSpellInfo(20217)] = { School = "All", Category = "+5% All Stats", ID = 20217,
			ModType = function(calculation)
				calculation.strM = calculation.strM * 1.05
				calculation.agiM = calculation.agiM * 1.05
				calculation.intM = calculation.intM * 1.05
			end,
			Mods = {
				[1] = function(calculation)
					if not calculation.customStats then
						calculation.str_mod = (calculation.str_mod or 0) + 0.05 * UnitStat("player",1)
						calculation.agi_mod = (calculation.agi_mod or 0) + 0.05 * UnitStat("player",2)
						calculation.int_mod = (calculation.int_mod or 0) + 0.05 * UnitStat("player",4)
					end
				end
			},
		}
		--Mark of the Wild (Druid)
		Aura[GetSpellInfo(1126)] = { School = "All", Category = "+5% All Stats", ID = 1126, NoManual = not Druid,
			ModType = function(calculation)
				calculation.strM = calculation.strM * 1.05
				calculation.agiM = calculation.agiM * 1.05
				calculation.intM = calculation.intM * 1.05
			end,
			Mods = {
				[1] = function(calculation)
					if not calculation.customStats then
						calculation.str_mod = (calculation.str_mod or 0) + 0.05 * UnitStat("player",1)
						calculation.agi_mod = (calculation.agi_mod or 0) + 0.05 * UnitStat("player",2)
						calculation.int_mod = (calculation.int_mod or 0) + 0.05 * UnitStat("player",4)
					end
				end
			},
		}
		--Legacy of the Emperor (Monk)
		Aura[GetSpellInfo(115921)] = { School = "All", Category = "+5% All Stats", ID = 115921, NoManual = not Monk,
			ModType = function(calculation)
				calculation.strM = calculation.strM * 1.05
				calculation.agiM = calculation.agiM * 1.05
				calculation.intM = calculation.intM * 1.05
			end,
			Mods = {
				[1] = function(calculation)
					if not calculation.customStats then
						calculation.str_mod = (calculation.str_mod or 0) + 0.05 * UnitStat("player",1)
						calculation.agi_mod = (calculation.agi_mod or 0) + 0.05 * UnitStat("player",2)
						calculation.int_mod = (calculation.int_mod or 0) + 0.05 * UnitStat("player",4)
					end
				end
			},
		}		
		--Embrace of the Shale Spider (Hunter)
		Aura[GetSpellInfo(90363)] = { School = "All", Category = "+5% All Stats", ID = 90363, NoManual = not Hunter,
			ModType = function(calculation)
				calculation.strM = calculation.strM * 1.05
				calculation.agiM = calculation.agiM * 1.05
				calculation.intM = calculation.intM * 1.05
			end,
			Mods = {
				[1] = function(calculation)
					if not calculation.customStats then
						calculation.str_mod = (calculation.str_mod or 0) + 0.05 * UnitStat("player",1)
						calculation.agi_mod = (calculation.agi_mod or 0) + 0.05 * UnitStat("player",2)
						calculation.int_mod = (calculation.int_mod or 0) + 0.05 * UnitStat("player",4)
					end
				end
			},
		}
	--+n Mastery (+3000 at level 90)
		--Blessing of Might (Paladin)
		Aura[GetSpellInfo(19740)] = { ID = 19740, School = "All", Category = "+Mastery",
			Mods = { [1] =
				function(calculation, baseSpell, ActiveAuras)
					local bonus = math_floor( DrDamage:ScaleData(1.7545, nil, nil, nil, true) + 0.5 )
					calculation.mastery = calculation.mastery + calculation.masteryM * DrDamage:GetRating("Mastery", bonus)
				end 
			},
		}
		--Grace of Air (Shaman)
		Aura[GetSpellInfo(116956)] = { ID = 116956, School = "All", Category = "+Mastery",
			Mods = { [1] =
				function(calculation, baseSpell, ActiveAuras)
					local bonus = math_floor( DrDamage:ScaleData(1.7545, nil, nil, nil, true) + 0.5 )
					calculation.mastery = calculation.mastery + calculation.masteryM * DrDamage:GetRating("Mastery", bonus)
				end, 
			},
		}
		--Roar of Courage (Hunter Cat)
		Aura[GetSpellInfo(93435)] = { ID = 93435, School = "All", Category = "+Mastery", NoManual = not Hunter,
			Mods = { [1] =
				function(calculation, baseSpell, ActiveAuras)
					local bonus = math_floor( DrDamage:ScaleData(1.7545, nil, nil, nil, true) + 0.5 )
					calculation.mastery = calculation.mastery + calculation.masteryM * DrDamage:GetRating("Mastery", bonus)
				end, 
			},
		}
		--Spirit Beast Blessing (Hunter Spirit Beast)
		Aura[GetSpellInfo(128997)] = { ID = 128997, School = "All", Category = "+Mastery", NoManual = not Hunter,
			Mods = { [1] =
				function(calculation, baseSpell, ActiveAuras)
					local bonus = math_floor( DrDamage:ScaleData(1.7545, nil, nil, nil, true) + 0.5 )
					calculation.mastery = calculation.mastery + calculation.masteryM * DrDamage:GetRating("Mastery", bonus)
				end, 
			},
		}		
	if playerCaster or playerHybrid then
		if not DK then
			--+10% Spell Power
				--Dark Intent (Warlock)
				Aura[GetSpellInfo(109773)] = { ID = 109773, School = "All", ModType = "SPM", Value = 0.1, Category = "+10% SP", Mods = { [1] = function(calculation) calculation.SP_bonus = (calculation.SP_bonus or 0) + 0.1 * calculation.SP end }, }
				--Burning Wrath (Shaman)
				Aura[GetSpellInfo(77747)] = { ID = 77747, School = "All", ModType = "SPM", Value = 0.1, Category = "+10% SP", Mods = { [1] = function(calculation) calculation.SP_bonus = (calculation.SP_bonus or 0) + 0.1 * calculation.SP end },  }
			--+10% Spell Power and 5% Crit	
				--Arcane Brilliance (Mage)
				Aura[GetSpellInfo(1459)] = { ID = 1459, School = "All", ModType = "SPM", Value = 0.1, Category = "+10% SP", SkipCategoryMod = true,
					Mods = { [1] = 
						function(calculation, baseSpell, ActiveAuras)
							if not ActiveAuras["+10% SP"] then
								calculation.SP_bonus = (calculation.SP_bonus or 0) + 0.1 * calculation.SP
								ActiveAuras["+10% SP"] = true
							end
							if not ActiveAuras["+5% crit"] then
								calculation.spellCrit = calculation.spellCrit + 5
								calculation.meleeCrit = calculation.meleeCrit + 5
								ActiveAuras["+5% crit"] = true
							end
						end, 
					}, 
				}
				--Dalaran Brilliance (Mage)
				Aura[GetSpellInfo(61316)] = { ID = 61316, School = "All", ModType = "SPM", Value = 0.1, Category = "+10% SP", SkipCategoryMod = true, NoManual = not Mage,
					Mods = { [1] = 
						function(calculation, baseSpell, ActiveAuras)
							if not ActiveAuras["+10% SP"] then
								calculation.SP_bonus = (calculation.SP_bonus or 0) + 0.1 * calculation.SP
								ActiveAuras["+10% SP"] = true
							end
							if not ActiveAuras["+5% crit"] then
								calculation.spellCrit = calculation.spellCrit + 5
								calculation.meleeCrit = calculation.meleeCrit + 5
								ActiveAuras["+5% crit"] = true
							end
						end, 
					}, 
				}
				--Still Water (Hunter Pet)
				Aura[GetSpellInfo(126309)] = { ID = 126309, School = "All", ModType = "SPM", Value = 0.1, Category = "+10% SP", SkipCategoryMod = true, NoManual = not Hunter,
					Mods = { [1] = 
						function(calculation, baseSpell, ActiveAuras)
							if not ActiveAuras["+10% SP"] then
								calculation.SP_bonus = (calculation.SP_bonus or 0) + 0.1 * calculation.SP
								ActiveAuras["+10% SP"] = true
							end
							if not ActiveAuras["+5% crit"] then
								calculation.spellCrit = calculation.spellCrit + 5
								calculation.meleeCrit = calculation.meleeCrit + 5
								ActiveAuras["+5% crit"] = true
							end
						end, 
					}, 
				}
			--+5% spell haste
				--Elemental Oath (Shaman)
				Aura[GetSpellInfo(51470)] = { ID = 51470, School = "Spells", Category = "+5% haste", Caster = true, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return baseSpell.MeleeHaste and v or v * 1.05 end } }
				--Mind Quickening (Priest - Shadowform)
				Aura[GetSpellInfo(49868)] = { ID = 49868, School = "Spells", Category = "+5% haste", Caster = true, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return baseSpell.MeleeHaste and v or v * 1.05 end } }
				--Moonkin Aura (Druid)
				Aura[GetSpellInfo(24907)] = { ID = 24907, School = "Spells", Category = "+5% haste", Caster = true, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return baseSpell.MeleeHaste and v or v * 1.05 end } }				
				--Energizing Spores (Hunter - Pet)
				Aura[GetSpellInfo(135678)] = { ID = 135678, School = "Spells", Category = "+5% haste", Caster = true, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return baseSpell.MeleeHaste and v or v * 1.05 end }, NoManual = not Hunter }					
		end
	end
	if playerHybrid or playerMelee then
		--+10% AP
			--Battle Shout (Warrior)
			Aura[GetSpellInfo(6673)] = { ID = 6673, Category = "+10% AP", ModType = "APM", Value = 0.1,
					Mods = { [1] = function(calculation) calculation.AP_bonus = (calculation.AP_bonus or 0) + 0.1 * calculation.AP end }, 
			}
			--Horn of Winter (Death Knight)
			Aura[GetSpellInfo(57330)] = { ID = 57330, Category = "+10% AP", ModType = "APM", Value = 0.1,
					Mods = { [1] = function(calculation) calculation.AP_bonus = (calculation.AP_bonus or 0) + 0.1 * calculation.AP end },
			}			
			--Trueshot Aura (Hunter)
			Aura[GetSpellInfo(19506)] = { ID = 19506, Category = "+10% AP", ModType = "APM", Value = 0.1,
					Mods = { [1] = function(calculation) calculation.AP_bonus = (calculation.AP_bonus or 0) + 0.1 * calculation.AP end }, 
			}
		--+10% melee haste		
			--Unholy Aura (Death Knight)
			Aura[GetSpellInfo(55610)] = { ID = 55610, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return (baseSpell.WeaponDPS or baseSpell.NextMelee or baseSpell.MeleeHaste) and 1.1 * v or v end }, Category = "+Meleehaste", NoManual = not DK }
			--Swiftblade's Cunning (Rogue)
			Aura[GetSpellInfo(113742)] = { ID = 113742, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return (baseSpell.WeaponDPS or baseSpell.NextMelee or baseSpell.MeleeHaste) and 1.1 * v or v end }, Category = "+Meleehaste", NoManual = not Rogue }
			--Unleashed Rage (Shaman)
			Aura[GetSpellInfo(30809)] = { ID = 30809, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return (baseSpell.WeaponDPS or baseSpell.NextMelee or baseSpell.MeleeHaste) and 1.1 * v or v end }, Category = "+Meleehaste", NoManual = not Shaman }			
			--Cackling Howl (Hunter Pet)
			Aura[GetSpellInfo(128432)] = { ID = 128432, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return (baseSpell.WeaponDPS or baseSpell.NextMelee or baseSpell.MeleeHaste) and 1.1 * v or v end }, Category = "+Meleehaste", NoManual = not Hunter }
			--Serpent's Swiftness (Hunter Pet)
			Aura[GetSpellInfo(128433)] = { ID = 128433, CustomHaste = true, Mods = { ["haste"] = function(v, baseSpell) return (baseSpell.WeaponDPS or baseSpell.NextMelee or baseSpell.MeleeHaste) and 1.1 * v or v end }, Category = "+Meleehaste", NoManual = not Hunter }	
	end
	if playerHealer then
	--Buffs
		--Luck of the Draw (Random LFG Bonus)
		Aura[GetSpellInfo(72221)] = { School = "Healing", Caster = true, Value = 0.05, Apps = 1, NoManual = true }
		--Strength of Wrynn
		Aura[GetSpellInfo(73762)] = { School = { "Healing", "Pet" }, Caster = true, NoManual = true, ModType =
			function( calculation )
				calculation.dmgM = calculation.dmgM * 1.3
				calculation.dmgM_absorb = (calculation.dmgM_absorb or 1) * 1.3
			end
		}
		--Hellscream's Warsong
		Aura[GetSpellInfo(73816)] = { School = { "Healing", "Pet" }, Caster = true, NoManual = true, ModType =
			function( calculation, _, _, index )
				calculation.dmgM = calculation.dmgM * 1.3
				calculation.dmgM_absorb = (calculation.dmgM_absorb or 1) * 1.3
			end
		}
	--Debuffs
		--Wretching Bile (Stratholme)
		Aura[GetSpellInfo(52527)] = { School = "Healing", Caster = true, Value = -0.35, NoManual = true }
	end
	if playerHealer or playerCaster or playerHybrid then
		--Shadow Crash ((Valithria Dreamwalker)
		Aura[GetSpellInfo(63277)] = { School = "Spells", Not = { "Absorb", "Utility", "Pet" }, ModType = function(calculation) calculation.dmgM = calculation.dmgM * (calculation.healingSpell and 0.25 or 2) end, NoManual = true, }
		--Debilitating Strike (Melee damage done reduced by 75%)
		Aura[GetSpellInfo(37578)] = { School = "Damage Spells", Value = 1/(1-0.75) - 1, NoManual = true }
		--Bonegrinder (Melee damage done reduced by 75%)
		Aura[GetSpellInfo(43952)] = Aura[GetSpellInfo(37578)]
		--Hammer Drop (Physical damage done reduced by 5%)
		Aura[GetSpellInfo(57759)] = { School = "Damage Spells", Apps = 1, NoManual = true, ModType =
			function(calculation, _, _, _, apps)
				calculation.dmgM = calculation.dmgM * 1/(1-0.05 * apps)
			end
		}
		-- -10% physical damage
		--Weakened Blows (Thunder Clap, Scarlet Fever, Thrash, Keg Smash, Hammer of the Righteous, Earth Shock, 
		Aura[GetSpellInfo(115798)] = { School = "Damage Spells", ModType = "dmgM_Physical", Value = 1/1.1, Multiply = true, NoManual = true }
		--Demoralizing Shout (Hunter Pet)
		Aura[GetSpellInfo(50256)] = Aura[GetSpellInfo(115798)]
		--Demoralizing screech (Hunter Pet)
		Aura[GetSpellInfo(24423)] = Aura[GetSpellInfo(115798)]
		--Curse of Enfeeblement (-20%)
		Aura[GetSpellInfo(109466)] = { School = "Damage Spells", ModType = "dmgM_Physical", Value = 1/1.2, Multiply = true, NoManual = true }
	end
--Target
	Aura = DrDamage.TargetAura

--Buffs
	--Damage decrease
		--Icebound Fortitude (Death Knight) NOTE: Does not take into account the talent Sanguine Fortitude
		Aura[GetSpellInfo(48792)] = { Value = -0.2, NoManual = true }
		--Bone Shield (Death Knight)
		Aura[GetSpellInfo(49222)] = { Value = -0.2, NoManual = true }
		--Will of the Necropolis (Death Knight)
		Aura[GetSpellInfo(81162)] = { Value = -0.25, NoManual = true }
		--Blood Presence (Death Knight)
		Aura[GetSpellInfo(48263)] = { Value = -0.1, NoManual = true }
		--Dispersion (Priest)
		Aura[GetSpellInfo(47585)] = { Value = -0.9, NoManual = true }
		--Shadowform (Priest)
		Aura[GetSpellInfo(15473)] = { Value = -0.15, NoManual = true }
		--Pain Suppression (Priest)
		Aura[GetSpellInfo(33206)] = { Value = -0.4, NoManual = true }
		--Focused Will (Priest)
		Aura[GetSpellInfo(45243)] = { Apps = 2, NoManual = true, ModType =
			function( calculation, _, _, _, apps, _, rank )
				if UnitExists("target") and not UnitIsFriend("target","player") then
					calculation.dmgM = calculation.dmgM * (1 - 0.1 * apps)
				end
			end
		}
		--Ardent Defender (Paladin)
		Aura[GetSpellInfo(31850)] = { Value = -0.2, NoManual = true }
		--Safeguard (Warrior)
		Aura[GetSpellInfo(114029)] = { Value = -0.2, Ranks = 2, NoManual = true }
		--Shield Wall (Warrior)
		Aura[GetSpellInfo(871)] = { Value = -0.4, NoManual = true }
		--TODO: Defensive stance? Battle Stance?
		--Survival Instincts (Druid)
		Aura[GetSpellInfo(61336)] = { Value = -0.5, NoManual = true }
		--Barkskin (Druid)
		Aura[GetSpellInfo(22812)] = { Value = -0.2, NoManual = true }
		--Cheating Death (Rogue)
		Aura[GetSpellInfo(45182)] = { Value = -0.8, NoManual = true }
		--Shamanistic Rage (Shaman)
		Aura[GetSpellInfo(30823)] = { Value = -0.3, NoManual = true }
		--Soul Link (Warlock)
		Aura[GetSpellInfo(108415)] = { Value = -0.5, NoManual = true }
		--Stoneform (Dwarf Racial)
		Aura[GetSpellInfo(65116)] = { Value = -0.1, NoManual = true }
--Debuffs
	--+10% Damage
		--Brutal Assault
		Aura[GetSpellInfo(46393)] = { Value = 0.1, Apps = 1, NoManual = true }
		--Focused Assault
		Aura[GetSpellInfo(46392)] = { Value = 0.1, Apps = 1, NoManual = true }
	--+5% Magic Damage
		--Curse of the Elements (Warlock)
		Aura[GetSpellInfo(1490)] = { Value = 0.05, Category = "+5% dmg", ID = 1490, ModType = "dmgM_Magic" }
		--Master Poisoner (Rogue)
		Aura[GetSpellInfo(93068)] = { Value = 0.05, Category = "+5% dmg", ID = 93068, ModType = "dmgM_Magic", NoManual = not Rogue }		
		--Fire Breath (Hunter pet)
		Aura[GetSpellInfo(34889)] = { Value = 0.05, Category = "+5% dmg", ID = 34889, ModType = "dmgM_Magic", NoManual = not Hunter }
		--Lightning Breath (Hunter pet)
		Aura[GetSpellInfo(24844)] = { Value = 0.05, Category = "+5% dmg", ID = 24844, ModType = "dmgM_Magic", NoManual = not Hunter }
	if playerCaster or playerHybrid then
		--Anti-Magic Shell
		Aura[GetSpellInfo(48707)] = { School = "Damage Spells", Value = -0.75, NoManual = true }
		--Anti-Magic Zone
		Aura[GetSpellInfo(50461)] = { School = "Damage Spells", Value = -0.75, NoManual = true }
	end
	--Buffs
	if playerHealer then
		--Vampiric Blood
		Aura[GetSpellInfo(55233)] = { School = "Healing", Caster = true, Value = 0.25, NoManual = true }
		--Divine Hymn
		Aura[GetSpellInfo(64843)] = { School = "Healing", Caster = true, Value = 0.1, NoManual = true }
		--Guardian Spirit
		Aura[GetSpellInfo(47788)] = { School = "Healing", Caster = true, Value = 0.6, NoManual = true }
	--Debuffs
	--Player
		--25% healing
			--Mortal Wounds (Mortal Strike, Wild Strike, Rising Sun Kick)
			Aura[GetSpellInfo(115804)] = { School = "Healing", Caster = true, Value = -0.25, Category = "Mortal Strike", ID = 115804, NoManual = Rogue }
			--Wound Poison (Rogue)
			Aura[GetSpellInfo(8680)] = { School = "Healing", Caster = true, Value = -0.25, Category = "Mortal Strike", ID = 8680, NoManual = not Rogue }		
			--Widow Venom (Hunter)
			Aura[GetSpellInfo(82654)] = { School = "Healing", Caster = true, Value = -0.25, Category = "Mortal Strike", ID = 115804, NoManual = true }
			--Mortal Cleave (Warlock pet)
			Aura[GetSpellInfo(115625)] = Aura[GetSpellInfo(82654)]
			--Monstrous bite (Hunter pet)
			Aura[GetSpellInfo(54680)] = Aura[GetSpellInfo(82654)]	
		--10% healing
			--Legion Strike (Felguard)
			Aura[GetSpellInfo(30213)] = { School = "Healing", Caster = true, Value = -0.1, Category = "Mortal Strike", NoManual = true, ID = 30213 }
	--NPC
	--10% reduction
		--Chop
		Aura[GetSpellInfo(43410)] = { School = "Healing", Caster = true, Value = -0.1, Category = "Mortal Strike", NoManual = true }
	--50% reduction (Mortal Strike)
		--Mortal Cleave (random mobs)
		Aura[GetSpellInfo(22859)] = { School = "Healing", Caster = true, Value = -0.5, Category = "Mortal Strike", NoManual = true }
	--75% reduction
		--Veil of Shadow (Multiple places)
		Aura[GetSpellInfo(17820)] = { School = "Healing", Caster = true, Value = -0.75, Category = "Mortal Strike", NoManual = true }
		--Veil of Shadow Alternate (Different Localized name)
		Aura[GetSpellInfo(69633)] = Aura[GetSpellInfo(17820)]
		--Gehennas' Curse
		Aura[GetSpellInfo(19716)] = Aura[GetSpellInfo(17820)]
	end
	if playerMelee or playerHybrid then
	--Debuffs
	--Player
		--+4% physical damage
			--Physical Vulnerability (All player abilities cause this - Brittle Bones, Ebon Plaguepringer, Judgements of the Bold, Colossus Smash)
			Aura[GetSpellInfo(81326)] = { School = "Physical", Melee = true, Value = 0.04, Category = "+4% Physical", ID = 81326 }
			--Gore (Hunter Pet)
			Aura[GetSpellInfo(35290)] = { School = "Physical", Melee = true, Value = 0.04, Category = "+4% Physical", ID = 35290, NoManual = true }
			--Ravage (Hunter Pet)
			Aura[GetSpellInfo(50518)] = Aura[GetSpellInfo(35290)]
			--Stampede (Hunter Pet)
			Aura[GetSpellInfo(57386)] = Aura[GetSpellInfo(35290)]
			--Acid Spit (Hunter Pet)
			Aura[GetSpellInfo(55749)] = Aura[GetSpellInfo(35290)]
		---12% Armor
			--Weakened Armor (All armor debuffs do this now, so no need to have individual ones)
			Aura[GetSpellInfo(113746)] = { School = "Physical", Melee = true, Apps = 3, Value = 0.04, ModType = "armorM", Category = "-12% Armor", Manual = GetSpellInfo(113746), ID = 113746 }			
		---20% Armor
			--Shattering Throw
			Aura[GetSpellInfo(64382)] = { School = "Physical", Melee = true, Value = 0.2, ModType = "armorM", Category = "-20% Armor", ID = 7386, NoManual = not Warrior }
	end

	local Consumables = DrDamage.Consumables
	--Mastery Rating food (MoP)
	Consumables[string.format(L["+%d Mastery Rating Food"],200)] = { School = "All", Mods = { ["mastery"] = function(v, baseSpell, calculation) return v + calculation.masteryM * DrDamage:GetRating("Mastery", 200, true) end }, Category = "Food", Alt = GetSpellInfo(87549) }
	--Monk's Elixir (MoP)
	Consumables[GetSpellInfo(105688)] = { ID = 105688, School = "All", Mods = { ["mastery"] = function(v, baseSpell, calculation) return v + calculation.masteryM * DrDamage:GetRating("Mastery", 750, true) end }, Category = "Battle Elixir" }
	if (playerCaster or playerHybrid or playerHealer) and not DK then
		--Spell Power Food (Not in MoP)
		--Consumables[string.format(L["+%d Spell Power Food"],46)] = { School = "All", Mods = { ["SP_mod"] = 46, }, Category = "Food", Alt = GetSpellInfo(57327) }
		--Intellect Food (MoP)
		Consumables[string.format(L["+%d Intellect Food"],300)] = { School = "All", Mods = { ["int"] = 300, }, Category = "Food", Alt = GetSpellInfo(57327) }
		--Spirit Food (MoP)
		Consumables[string.format(L["+%d Spirit Food"],300)] = { School = "All", Mods = { ["spi"] = 300, }, Category = "Food", Alt = GetSpellInfo(57327) }
		--Flask of the Warm Sun (MoP)
		Consumables[GetSpellInfo(105691)] = { ID = 105691, School = "All", Mods = { ["int"] = 1000 }, Category = "Battle Elixir", Category2 = "Guardian Elixir" }
		--Elixir of Peace (MoP)
		Consumables[GetSpellInfo(105685)] = { ID = 105685, School = "All", Caster = true, Mods = { ["spi"] = 750 }, Category = "Battle Elixir" }
		--Flask of Falling Leaves (MoP)
		Consumables[GetSpellInfo(105693)] = { ID = 105693, School = "All", Caster = true, Mods = { ["spi"] = 1000 }, Category = "Battle Elixir", Category2 = "Guardian Elixir" }
	end
	if playerMelee or playerHybrid then
		--AP Food (Not in MoP)
		--Consumables[string.format(L["+%d AP Food"],80)] = { Mods = { ["AP_mod"] = 80 }, Category = "Food", Alt = GetSpellInfo(57079) }
		--Agility Food (MoP)
		Consumables[string.format(L["+%d Agility Food"],300)] = { School = "All", Mods = { ["agi"] = 300, }, Category = "Food", Alt = GetSpellInfo(57327) }
		--Strength Food (MoP)
		Consumables[string.format(L["+%d Strength Food"],300)] = { School = "All", Mods = { ["str"] = 300, }, Category = "Food", Alt = GetSpellInfo(57327) }
		--Flask of Spring Blossoms (MoP)
		Consumables[GetSpellInfo(105689)] = { ID = 105689, Mods = { ["agi"] = 1000 }, Category = "Battle Elixir", Category2 = "Guardian Elixir" }
		--Flask of Winter's Bite (MoP)
		Consumables[GetSpellInfo(105696)] = { ID = 105696, Mods = { ["str"] = 1000 }, Category = "Battle Elixir", Category2 = "Guardian Elixir" }
		--Elixir of Weaponry (MoP)
		Consumables[GetSpellInfo(105683)] = {  ID = 105683, Melee = true, Mods = { ["expertise"] = function(v) return v + DrDamage:GetRating("Expertise", 750, true) end }, Category = "Battle Elixir" }
		--Expertise Rating Food (MoP)
		Consumables[string.format(L["+%d Expertise Rating Food"],300)] = { Melee = true, Mods = { ["expertise"] = function(v) return v + DrDamage:GetRating("Expertise", 300, true) end }, Alt = GetSpellInfo(33263), Category = "Food" }
	end
--CUSTOM
	--Mad Hozen Elixir (MoP)
	Consumables[GetSpellInfo(105682)] = { School = "All", Category = "Battle Elixir", ID = 105682,
		Mods = {
			function(calculation, baseSpell)
				if not baseSpell.NoManualRatings then
					local value = DrDamage:GetRating("Crit", 750, true)
					calculation.spellCrit = calculation.spellCrit + value
					calculation.meleeCrit = calculation.meleeCrit + value
				end
			end
		}
	}
	--Critical Strike Rating Food (MoP)
	Consumables[string.format(L["+%d Critical Strike Rating Food"],200)] = { School = "All", Alt = GetSpellInfo(33263), Category = "Food",
		Mods = {
			function(calculation, baseSpell)
				if not baseSpell.NoManualRatings then
					local value = DrDamage:GetRating("Crit", 200, true)
					calculation.spellCrit = calculation.spellCrit + value
					calculation.meleeCrit = calculation.meleeCrit + value
				end
			end
		}
	}
	--Elixir of Perfection (MoP)
	Consumables[GetSpellInfo(105686)] = { Category = "Battle Elixir", ID = 105686,
		Mods = {
			function(calculation, baseSpell)
				if not baseSpell.NoManualRatings then
					calculation.spellHit = calculation.spellHit + DrDamage:GetRating("Hit", 750, true)
					calculation.meleeHit = calculation.meleeHit + DrDamage:GetRating("Hit", 750, true)
				end
			end
		},
	}
	--Hit Rating Food (MoP)
	Consumables[string.format(L["+%d Hit Rating Food"],300)] = { Alt = GetSpellInfo(33263), Category = "Food",
		Mods = {
			function(calculation, baseSpell)
				if not baseSpell.NoManualRatings then
					calculation.spellHit = calculation.spellHit + DrDamage:GetRating("Hit", 300, true)
					calculation.meleeHit = calculation.meleeHit + DrDamage:GetRating("Hit", 300, true)
				end
			end
		},
	}
	--Elixir of the Rapids (MoP)
	Consumables[GetSpellInfo(105684)] = { School = "All", Category = "Battle Elixir", ID = 105684,
		Mods = {
			function(calculation, baseSpell)
				if not baseSpell.NoManualRatings then
					local base = DrDamage:GetRating("Haste", calculation.hasteRating, true)/100
					calculation.haste = (calculation.haste / (1 + base)) * (1 + base + DrDamage:GetRating("Haste", 750, true)/100)
				end
			end
		},
	}
	--Haste Rating Food (MoP)
	Consumables[string.format(L["+%d Haste Rating Food"],200)] = { School = "All", Alt = GetSpellInfo(33263), Category = "Food",
		Mods = {
			function(calculation, baseSpell)
				if not baseSpell.NoManualRatings then
					local base = DrDamage:GetRating("Haste", calculation.hasteRating, true)/100
					calculation.haste = (calculation.haste / (1 + base)) * (1 + base + DrDamage:GetRating("Haste", 200, true)/100)
				end
			end
		},

	}
end

DrD_LoadAuras()
DrD_LoadAuras = nil
