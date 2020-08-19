local an, ns = ...

watched_zones = {
  "Dun Morogh",
  "Ruins of Ahn'Qiraj",
  "Temple of Ahn'Qiraj",
  "Ahn'Qiraj",
  "Blackwing Lair",
  "Molten Core",
  "Onyxia's Lair",
}

local frame=CreateFrame("Frame");
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA");

frame:SetScript("OnEvent",function(self,event,msg,author)
    addon = ns.an.addon
    if event=="ZONE_CHANGED_NEW_AREA" then
      zone = GetRealZoneText();
      if ns.an.hasValue(watched_zones, zone) then
        local ts = time()
        if ns.an.onGoingRaid(zone) == false then
          local newRaid = {
            date = ts,
            zone = zone,
            bosskills = {},
            completed = false,
          }
          table.insert(addon.db.profile.raids, newRaid)
        end
      end
    end
end);
