local isClassic = WOW_PROJECT_ID == (WOW_PROJECT_CLASSIC or 2)
local isBCC = WOW_PROJECT_ID == (WOW_PROJECT_BURNING_CRUSADE_CLASSIC or 5)
local isWrath = WOW_PROJECT_ID == (WOW_PROJECT_WRATH_CLASSIC or 11)
local catID
if isWrath then
	catID = 5
elseif isBCC or isClassic then
	catID = 6
else--retail or cataclysm classic and later
	catID = 4
end
local mod	= DBM:NewMod("Geddon", "DBM-Raids-Vanilla", catID)
local L		= mod:GetLocalizedStrings()

mod:SetRevision("@file-date-integer@")
mod:SetCreatureID(DBM:IsSeasonal("SeasonOfDiscovery") and 228433 or 12056)
mod:SetEncounterID(668)
mod:SetModelID(12129)
mod:SetHotfixNoticeRev(20240724000000)

if DBM:IsSeasonal("SeasonOfDiscovery") then
	mod:SetUsedIcons(8, 7, 6)
else
	mod:SetUsedIcons(8)
end

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_AURA_APPLIED 20475 19659 461090 461105 462402",
	"SPELL_AURA_REMOVED 20475 461090 461105 462402",
	"SPELL_CAST_SUCCESS 19695 19659 20478 20475 461090 461105 462402 461110 461121"
)

-- 461090 461105 462402 seem to be bombs on SoD (only confirmed first one at heat level 1)

--[[
(ability.id = 19695 or ability.id = 19659 or ability.id = 20478 or ability.id = 461090 or ability.id = 461105 or ability.id = 462402 or ability.id = 461110 or ability.id = 461121) and type = "cast"
--]]
local warnInferno		= mod:NewSpellAnnounce(19695, 3)
local warnBomb			= mod:NewTargetNoFilterAnnounce(20475, 4)
local warnArmageddon	= mod:NewSpellAnnounce(20478, 3)

local specWarnBomb		= mod:NewSpecialWarningYou(20475, nil, nil, nil, 3, 2)
local yellBomb			= mod:NewYell(20475)
local yellBombFades		= mod:NewShortFadesYell(20475)
local specWarnInferno	= mod:NewSpecialWarningRun(19695, "Melee", nil, nil, 4, 2)
local specWarnIgnite	= mod:NewSpecialWarningDispel(19659, "RemoveMagic", nil, nil, 1, 2)
local specWarnGTFO		= mod:NewSpecialWarningGTFO(19698, nil, nil, nil, 1, 8)

local timerInfernoCD	= mod:NewCDTimer(21, 19695, nil, nil, nil, 2)--21-27.9 (24-30 on sod?)
local timerInferno		= mod:NewBuffActiveTimer(8, 19695, nil, nil, nil, 2)
local timerIgniteManaCD	= mod:NewCDTimer(27, 19659, nil, nil, nil, 2)--27-33
local timerBombCD		= mod:NewCDTimer(13.3, 20475, nil, nil, nil, 3)--13.3-21
local timerBomb			= mod:NewTargetTimer(8, 20475, nil, nil, nil, 3)
local timerArmageddon	= mod:NewCastTimer(8, 20478, nil, nil, nil, 2)

mod:AddSetIconOption("SetIconOnBombTarget", 20475, false, 0, {8, 7, 6}) -- up to 3 bombs on heat level 3 (TODO: confirm)

function mod:OnCombatStart(delay)
	--timerIgniteManaCD:Start(7-delay)--7-19, too much variation for first
	timerBombCD:Start(11-delay)
	if not self:IsTank() and (self:IsEvent() or not self:IsTrivial()) then--Only want to warn if it's a threat
		self:RegisterShortTermEvents(
			"SPELL_DAMAGE 19698",
			"SPELL_MISSED 19698"
		)
	end
end

function mod:OnCombatEnd()
	self:UnregisterShortTermEvents()
end

local bombIcon = 8

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpell(20475, 461090, 461105, 462402) then
		timerBomb:Start(args.destName)
		if self.Options.SetIconOnBombTarget then
			self:SetIcon(args.destName, bombIcon)
			bombIcon = bombIcon - 1
		end
		if args:IsPlayer() then
			specWarnBomb:Show()
			specWarnBomb:Play("runout")
			if self:IsEvent() or not self:IsTrivial() then
				yellBomb:Yell()
				yellBombFades:Countdown(8)
			end
		else
			warnBomb:CombinedShow(0.3, args.destName)
		end
	elseif args:IsSpell(19659) and self:CheckDispelFilter("magic") then
		specWarnIgnite:CombinedShow(0.3, args.destName)
		specWarnIgnite:ScheduleVoice(0.3, "helpdispel")
	end
end

function mod:SPELL_AURA_REMOVED(args)
	if args:IsSpell(20475, 461090, 461105, 462402) then
		timerBomb:Stop(args.destName)
		if self.Options.SetIconOnBombTarget then
			self:SetIcon(args.destName, 0)
		end
		if args:IsPlayer() then
			yellBombFades:Cancel()
		end
	end
end

function mod:SPELL_CAST_SUCCESS(args)
	if args:IsSpell(19695, 461110) then
		if self:IsEvent() or not self:IsTrivial() then
			specWarnInferno:Show()
			specWarnInferno:Play("aesoon")
		else
			warnInferno:Show()
		end
		timerInferno:Start()
		timerInfernoCD:Start()
	elseif args:IsSpell(19659) then
		timerIgniteManaCD:Start()
	elseif args:IsSpell(20478, 461121) then
		warnArmageddon:Show()
		timerArmageddon:Start()
	elseif args:IsSpell(20475, 461090, 461105, 462402) then
		bombIcon = 8
		timerBombCD:Start()
	end
end

do
	local Inferno = DBM:GetSpellName(19695)--Classic Note
	function mod:SPELL_DAMAGE(_, _, _, _, destGUID, destName, _, _, spellId, spellName)
		if (spellId == 19698 or spellName == Inferno) and destGUID == UnitGUID("player") and self:AntiSpam(2, 1) then
			specWarnGTFO:Show(spellName)
			specWarnGTFO:Play("watchfeet")
		end
	end
	mod.SPELL_MISSED = mod.SPELL_DAMAGE
end
