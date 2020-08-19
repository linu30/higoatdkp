local an, ns = ...
local announcementStart = nil
local attendanceEnabled = false

bosses = {
  ["Ruins of Ahn'Qiraj"]={ "Moam", "General Rajaxx", "Kurinnaxx", "Ayamiss the Hunter", "Buru the Gorger", "Ossirian the Unscarred" },
  ["Temple of Ahn'Qiraj"]={ "The Prophhet Skeram", "Battleguard Sartura", "Fankriss the Unyielding", "Lord Kri", "Viscidus", "Emperor Vek'nilash", "Ouro", "C'thun" , "Princess Huhuran" },
  ["Ahn'Qiraj"]={ "The Prophhet Skeram", "Battleguard Sartura", "Fankriss the Unyielding", "Lord Kri", "Viscidus", "Emperor Vek'nilash", "Ouro", "C'thun" , "Princess Huhuran" },
  ["Blackwing Lair"]={ "Razorgore the Untamed", "Vaelastrasz the Corrupt", "Broodlord Lashlayer", "Firemaw", "Flamegor", "Ebonroc", "Chromaggus", "Nefarian" },
  ["Molten Core"]={ "Lucifron", "Magmadar", "Gehennas", "Garr", "Baron Geddon", "Shazzrah", "Sulfuron Harbinger", "Golemagg the Incinerator", "Majordomo Executus", "Ragnaros" },
  ["Onyxia's Lair"]={ "Onyxia" },
  ["Dun Morogh"]={ "Large Crag Boar", "Elder Crag Boar", "Winter Wolf", "Ice Claw Bear" },
}

local frame=CreateFrame("Frame");
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED");

frame:SetScript("OnEvent",function(self,event, ...)
  local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags = CombatLogGetCurrentEventInfo();
  if event == "COMBAT_LOG_EVENT_UNFILTERED" then
    if subEvent == "UNIT_DIED" then
      zone = GetRealZoneText();
      if ns.an.hasValue(watched_zones, zone) and ns.an.bossInInstance(bosses[zone], destName) then
        addKill(ns.an.addon, timestamp, destName, zone);
      end
    end
  end
end);


function addKill(self, timestamp, bossName, zone)
  self.attendanceEnabled = true
  addon = ns.an.addon
  activeRaid = ns.an.onGoingRaid(zone)
  if not activeRaid then
    local ts = time()
    local newRaid = {
      date = ts,
      zone = zone,
      bosskills = {},
      completed = false,
    }
    table.insert(addon.db.profile.raids, newRaid)
    activeRaid = ns.an.onGoingRaid(zone)
  end
  addon.db.profile.raids[activeRaid]["bosskills"][bossName] = {}
  addon.db.profile.raids[activeRaid]["bosskills"][bossName]["killTime"] = timestamp
  addon.db.profile.raids[activeRaid]["bosskills"][bossName]["attendance"] = {}
  self.currentRaid = activeRaid
  self.currentBoss = bossName
  local numTotal = (GetNumGroupMembers());
  for i=1,numTotal do
    name, _, _, _, _, _, _, _, _, _, _ = GetRaidRosterInfo(i);
    table.insert(addon.db.profile.raids[activeRaid]["bosskills"][bossName]["attendance"], name)
  end


  local totalBosses = table.getn(bosses[zone])
  local killedBosses = 0
  for _, _ in pairs(addon.db.profile.raids[activeRaid]["bosskills"]) do
    killedBosses = killedBosses + 1
  end
  if killedBosses == totalBosses then
    -- End the raid here since we killed the last boss
    addon.db.profile.raids[activeRaid]["completed"] = true
  end
  announcementStart = GetTime()
  if addon.db.profile.announceAttendance ~= false then
    announceKill(bossName)
    if addon.db.profile.announceRepeat > 0 then
      for delay = addon.db.profile.announceRepeat, addon.db.profile.announceTimeout * 60 - 1, addon.db.profile.announceRepeat do
        self:ScheduleEvent("Repeat" .. delay, announceKill, delay, bossName)
      end
    end
    self:ScheduleEvent("Timeout", attendanceTimeout, addon.db.profile.announceTimeout * 60, self)
  end

  if type(ShutUp_Disable) == "function" then
    ShutUp_Disable()
  end
end

function announceKill(bossName)
  addon = ns.an.addon
  local divider = ("*"):rep(10)
  local secondsRemaining = addon.db.profile.announceTimeout * 60 - (GetTime() - announcementStart)
  local remainingStr = ns.an.L["<HGDKP>: (%d minutes and %d seconds remaining)"]:format(secondsRemaining / 60, secondsRemaining % 60)
  str = ns.an.L["<HGDKP>: %s down! Whisper me 'hgdkp' to be added to the DKP list."]:format(bossName)
  ns.an.sendGuildMessage(str, remainingStr)
end

function attendanceTimeout()
  addon = ns.an.addon
  local str = ns.an.L["<HGDKP>: If you haven't whispered me by now, you're too late."]
  ns.an.sendGuildMessage(str)
  if type(ShutUp_Enable) == "function" then
    ShutUp_Enable()
  end
  addon.attendanceEnabled = false
end

