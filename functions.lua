local an, ns = ...

local function hasValue(tab, val)
  for index, value in pairs(tab) do
    if value == val then
        return true
    end
  end
  return false
end

local function hasIndex(tab, val)
  for index, value in pairs(tab) do
    if index == val then
        return true
    end
  end
  return false
end

local function bossInInstance(tab, val)
    for index, value in pairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

local function onGoingRaid(zone)
  addon = ns.an.addon
  for index, raid in pairs(addon.db.profile.raids) do
    if raid["completed"] == false and raid["zone"] == zone then
      return index
    end
  end
  return false
end

ns.an.hasValue = hasValue
ns.an.hasIndex = hasIndex
ns.an.onGoingRaid = onGoingRaid
ns.an.bossInInstance = bossInInstance
