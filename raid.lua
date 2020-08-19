local an, ns = ...

local frame=CreateFrame("Frame");-- 
frame:RegisterEvent("GROUP_FORMED");
frame:RegisterEvent("GROUP_ROSTER_UPDATE");

frame:SetScript("OnEvent",function(self,event,msg,author)
    if event=="GROUP_FORMED" and UnitIsGroupLeader("unit") then
      if not IsInRaid() then
        ConvertToRaid();
        ns.an.inviteGuild();
      end
      if lootmethod ~= "master" then
        SetLootMethod("master", GetUnitName("player"));
      end
      if GetLootThreshold() ~= 4 then
        hg__wait(2, lootThresholdDelay);
      end
    end
    if event=="GROUP_ROSTER_UPDATE" then
      local numTotal = (GetNumGroupMembers());
      if numTotal > 1 and not IsInRaid() then
        ConvertToRaid()
        ns.an.inviteGuild();
      end
      for i=1,numTotal do
        name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i);
        if name == nil then
          return
        end
        guildName, guildRankName, guildRankIndex = GetGuildInfo(name);
        if rank < 1 and (guildRankName == "Officer" or guildRankName == "Officer alt") then
          PromoteToAssistant(name);
        end
      end
    end
end);

local waitTable = {};
local waitFrame = nil;

function hg__wait(delay, func, ...)
  if(type(delay)~="number" or type(func)~="function") then
    return false;
  end
  if(waitFrame == nil) then
    waitFrame = CreateFrame("Frame","WaitFrame", UIParent);
    waitFrame:SetScript("onUpdate",function (self,elapse)
      local count = #waitTable;
      local i = 1;
      while(i<=count) do
        local waitRecord = tremove(waitTable,i);
        local d = tremove(waitRecord,1);
        local f = tremove(waitRecord,1);
        local p = tremove(waitRecord,1);
        if(d>elapse) then
          tinsert(waitTable,i,{d-elapse,f,p});
          i = i + 1;
        else
          count = count - 1;
          f(unpack(p));
        end
      end
    end);
  end
  tinsert(waitTable,{delay,func,{...}});
  return true;
end

function lootThresholdDelay() 
  SetLootThreshold(4);
end
