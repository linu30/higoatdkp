local an, ns = ...

local function inviteGuild()
  addon = ns.an.addon
  if addon.db.profile.guildInvites ~= true then
    return
  end
  for i = 1, GetNumGuildMembers(true) do
    local name, rank, rankIndex, level, _, _, _, _, online, _, class = GetGuildRosterInfo(i)
    if online and level == 60 then
      InviteUnit(name)
    end
  end
end

ns.an.inviteGuild = inviteGuild
