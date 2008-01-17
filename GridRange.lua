-- GridRange.lua
--
-- A TBC range library

--{{{ Libraries

local L = AceLibrary("AceLocale-2.2"):new("Grid")
local BS = AceLibrary("Babble-Spell-2.2")

--}}}

GridRange = Grid:NewModule("GridRange")

local ranges, checks, rangelist
local select = select
local IsSpellInRange = IsSpellInRange
local CheckInteractDistance = CheckInteractDistance
local UnitIsVisible = UnitIsVisible
local BOOKTYPE_SPELL = BOOKTYPE_SPELL

local invalidSpells = {
	[BS["Mend Pet"]] = true,
	[BS["Health Funnel"]] = true,
}

local function addRange(range, check)
	-- 100 yards is the farthest possible range
	if range > 100 then return end
	
	if not checks[range] then
		ranges[#ranges + 1] = range
		table.sort(ranges)
		checks[range] = check
	end
end

local function checkRange10(unit)
	return CheckInteractDistance(unit, 3)
end

local function checkRange28(unit)
	return CheckInteractDistance(unit, 4)
end

local function checkRange100(unit)
	return UnitIsVisible(unit)
end

local function initRanges()
	ranges, checks = {}, {}
	addRange(10, checkRange10)
	addRange(28, checkRange28)
	addRange(100, checkRange100)
end

function GridRange:ScanSpellbook()
	local gratuity = AceLibrary("Gratuity-2.0")

	initRanges()

	-- using IsSpellInRange doesn't work for dead players.
	-- reschedule the spell scanning for when the player is alive
	if UnitIsDeadOrGhost("player") then
		self:RegisterEvent("PLAYER_UNGHOST", "ScanSpellbook")
		self:RegisterEvent("PLAYER_ALIVE", "ScanSpellbook")
	elseif self:IsEventRegistered("PLAYER_UNGHOST") then
		self:UnregisterEvent("PLAYER_UNGHOST")
		self:UnregisterEvent("PLAYER_ALIVE")
	end

	local i = 1
	while true do
		local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
		if not name then break end
		-- beneficial spell with a range
		if not invalidSpells[name] and IsSpellInRange(i, BOOKTYPE_SPELL, "player") then
			gratuity:SetSpell(i, BOOKTYPE_SPELL)
			local range = select(3, gratuity:Find(L["(%d+) yd range"], 2, 2))
			if range then
				local index = i -- we have to create an upvalue
				addRange(tonumber(range), function (unit) return IsSpellInRange(index, BOOKTYPE_SPELL, unit) == 1 end)
				self:Debug("%d %s (%s) has range %s", i, name, rank, range)
			end
		end
		i = i + 1
	end

	self:TriggerEvent("Grid_RangesUpdated")
	rangelist = nil
end

function GridRange:OnEnable()
	self.super.OnEnable(self)

	self:ScanSpellbook()
	self:RegisterEvent("LEARNED_SPELL_IN_TAB", "ScanSpellbook")
	self:RegisterEvent("CHARACTER_POINTS_CHANGED", "ScanSpellbook")
end

function GridRange:GetUnitRange(unit)
	for _, range in ipairs(ranges) do
		if checks[range](unit) then
			return range
		end
	end
end

function GridRange:GetRangeCheck(range)
	return checks[range]
end

function GridRange:GetAvailableRangeList()
	if not ranges or rangelist then return rangelist end
	
	rangelist = {}
	for r in self:AvailableRangeIterator() do
		rangelist[tostring(r)] = L["%d yards"]:format(r)
	end
	return rangelist
end

function GridRange:AvailableRangeIterator()
	local i = 0
	return function ()
		i = i + 1
		return ranges[i]
	end
end
