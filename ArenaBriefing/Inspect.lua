local _, AB = ...
local API = AB.API
local safe = API.Safe
AB.Inspect = {}
local Inspect = AB.Inspect
local cache, invalid = {}, {}
local pending, lastRequest
local nextSlot = 1
local INTERVAL, TIMEOUT = 2, 5
local function guidValue(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)=="string" and value~="" then return value end
end
local function guidFor(unit) return guidValue(safe(UnitGUID,unit)) end
local function active()
    return not AB.preview and AB.phase=="prep" and API.InArena()
        and API.IsPreparing(API.State()) and safe(InCombatLockdown)==false
end
local function userInspecting()
    return (InspectFrame and safe(InspectFrame.IsShown,InspectFrame))
        or (PlayerSpellsFrame and safe(PlayerSpellsFrame.IsInspecting,PlayerSpellsFrame))
end
function Inspect.Reset()
    cache,invalid={},{}
    pending=nil; nextSlot=1
    -- Keep the request throttle across round changes and world events.
end
function Inspect.Spec(unit)
    local guid=guidFor(unit)
    if guid and invalid[guid] then return nil end
    local spec=API.InspectSpec(unit)
    if guid then
        if spec then cache[guid]=spec end
        return spec or cache[guid]
    end
    return spec
end
function Inspect.Invalidate(unit)
    if not active() then return end
    unit=safe(function() return unit end)
    if unit~="party1" and unit~="party2" then return end
    local guid=guidFor(unit)
    if guid then
        cache[guid]=nil; invalid[guid]=true
        if pending and pending.guid==guid then pending=nil end
    end
end
function Inspect.Ready(value)
    if not active() then pending=nil; return end
    local guid=guidValue(value)
    if not guid or not pending or pending.guid~=guid then return end
    -- Resolve the GUID again: party slots can move while a request is in flight.
    for i=1,(AB.context and AB.context.size or 3)-1 do
        local unit="party"..i
        if guidFor(unit)==guid then
            local spec=API.InspectSpec(unit)
            if spec then
                cache[guid]=spec; invalid[guid]=nil
                AB.Log("inspect ready party"..i.." spec="..spec)
            end
            break
        end
    end
    pending=nil
end
function Inspect.Tick()
    if not active() then pending=nil; return end
    local now=safe(GetTime)
    if type(now)~="number" or now~=now or now==math.huge then return end
    local count=(AB.context and AB.context.size or 3)-1
    local roster={}
    for i=1,count do
        local guid=guidFor("party"..i)
        if guid then roster[guid]=true end
    end
    for guid in pairs(cache) do if not roster[guid] then cache[guid]=nil end end
    for guid in pairs(invalid) do if not roster[guid] then invalid[guid]=nil end end
    if pending and not roster[pending.guid] then pending=nil end
    if pending then
        if now-pending.time<TIMEOUT then return end
        pending=nil; AB.Log("inspect timeout")
    end
    if lastRequest and now-lastRequest<INTERVAL then return end
    if type(NotifyInspect)~="function" or userInspecting() then return end
    for offset=0,count-1 do
        local slot=(nextSlot+offset-1)%count+1
        local unit="party"..slot
        local guid=guidFor(unit)
        if guid and not API.Spec(AB.manual.friendly[slot+1]) and not Inspect.Spec(unit)
            and safe(CanInspect,unit)==true then
            lastRequest=now; nextSlot=slot%count+1
            pending={guid=guid,time=now}
            local ok=pcall(NotifyInspect,unit)
            if not ok then pending=nil end
            AB.Log("inspect request "..unit..(ok and "" or " unavailable"))
            return
        end
    end
    -- Do not ClearInspectPlayer: the inspect service is shared with other addons.
end
