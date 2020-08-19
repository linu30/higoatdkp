local an, ns = ...

local function IsAllowedOnAttendanceSets(player)
  local numTotal = (GetNumGroupMembers());
  for i=1,numTotal do
    name, rank, subgroup, level, class, fileName, zone, online, isDead, role, isML = GetRaidRosterInfo(i);
    if name == player:gsub("%-TenStorms", "") then
      return false
    end
  end
  for k, v in pairs(ns.an.guildMemberList) do
    if k == player then
      return true
    end
  end
  return false
end


local function sendGuildMessage(msg, extraMsg)
  local divider = ("*"):rep(10)
  SendChatMessage(divider, "GUILD")
  SendChatMessage(msg, "GUILD")
  if extraMsg then
    SendChatMessage(extraMsg, "GUILD")
  end
  SendChatMessage(divider, "GUILD")
end


local function handleInvites(player)
  addon = ns.an.addon
  if addon.db.profile.guildInvites ~= true then
    local reply = "Sorry friend, raid inivtes have not been opened up yet!"
    SendChatMessage(reply, "WHISPER", nil, player);
  else
    InviteUnit(player);
  end
end


local function handleDKP(reply, addon, player)
  if not addon.attendanceEnabled then
    reply = ns.an.L["<HGDKP>: There are no active attendance calls open right now"]
  else 
    if not IsAllowedOnAttendanceSets(player) then
      reply = ns.an.L["<HGDKP>: %q can't be added to this attendance set."]:format(player:gsub("%-TenStorms", ""))
    else
      local raidId = addon.currentRaid
      local bossName = addon.currentBoss
      local attendance = addon.db.profile.raids[raidId]["bosskills"][bossName].attendance
      local inRaid = false
      for k, v in pairs(attendance) do
        if v == player:gsub("%-TenStorms", "") then
          inRaid = true
        end
      end
      if inRaid == true then
        reply = ns.an.L["<HGDKP>: %q has already been added to the attendance list"]:format(player:gsub("%-TenStorms", ""))
      else 
        reply = ns.an.L["<HGDKP>: %q has been added to the attendance list"]:format(player:gsub("%-TenStorms", ""))
        attendance[#attendance+1] =  player:gsub("%-TenStorms", "")
        addon.db.profile.raids[raidId]["bosskills"][bossName]["attendance"] = attendance
      end
    end
  end
  SendChatMessage(reply, "WHISPER", nil, player)
end

local Frame=CreateFrame("Frame");
Frame:RegisterEvent("CHAT_MSG_WHISPER");
Frame:SetScript("OnEvent",function(self,event,msg,player)
  if event~="CHAT_MSG_WHISPER" then
    return
  end
  if msg:find("^<HGDKP>") then return true end
  local reply = ""
  addon = ns.an.addon
  msg = msg:lower()
  if msg ~= "hgdkp" and msg ~= "hginv" then return true 
  elseif msg == "hginv" then
    handleInvites(player)
  elseif msg == "hgdkp" then
    handleDKP(reply, addon, player)
  end
end);

ns.an.sendGuildMessage = sendGuildMessage
