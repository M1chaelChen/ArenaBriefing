local _, AB = ...
AB.API = {}
local API = AB.API
-- Reject secrets BEFORE any comparison, concatenation, indexing or arithmetic.
function API.Safe(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if not ok then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end
local safe = API.Safe
function API.Spec(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value) == "number" and AB.specs[value] then return value end
end
function API.InArena()
    local function kind() local _, instanceType = IsInInstance(); return instanceType end
    return safe(kind) == "arena"
end
function API.State()
    return safe(C_PvP and C_PvP.GetActiveMatchState)
end
function API.IsPreparing(state)
    local states = Enum and Enum.PvPMatchState
    return states and (state == states.Waiting or state == states.StartUp) or false
end
function API.PlayerSpec()
    local info = C_SpecializationInfo or {}
    local index = safe(info.GetSpecialization or GetSpecialization)
    if not index then return nil end
    return API.Spec(safe(info.GetSpecializationInfo or GetSpecializationInfo, index))
end
function API.InspectSpec(unit)
    local info=C_SpecializationInfo or {}
    return API.Spec(safe(info.GetInspectSpecialization or GetInspectSpecialization,unit))
end
function API.Map()
    local id=safe(function() return select(8,GetInstanceInfo()) end)
    if type(id)~="number" or id<=0 or id%1~=0 then id=nil end
    local name=safe(GetInstanceInfo)
    if type(name)~="string" or name=="" then name=nil end
    return id,name
end
function API.Snapshot(manual)
    manual = manual or {friendly={},enemy={}}
    local count = safe(GetNumArenaOpponentSpecs)
    local size = (count == 2 or count == 3) and count or nil
    if not size then
        local group = safe(GetNumGroupMembers)
        size = (group == 2 or group == 3) and group or 3
    end
    local shuffle = safe(C_PvP and (C_PvP.IsRatedSoloShuffle or C_PvP.IsSoloShuffle))
    local ctx = {size=size,mode=shuffle and "Solo Shuffle" or (size.."v"..size),friendly={},enemy={},sources={friendly={},enemy={}}}
    local version=safe(GetBuildInfo)
    ctx.clientVersion=type(version)=="string" and version or nil
    ctx.mapID,ctx.mapName = API.Map()
    ctx.playerSpec = API.Spec(manual.friendly[1]) or API.PlayerSpec()
    local known = 0
    for i=1,size do
        local friendly
        if i==1 then friendly=ctx.playerSpec
        else friendly=AB.Inspect.Spec("party"..(i-1)) end
        -- Never mistake a full Shuffle lobby for this round's enemy team.
        local enemy = count == size and API.Spec(safe(GetArenaOpponentSpec,i)) or nil
        ctx.friendly[i] = API.Spec(manual.friendly[i]) or friendly or 0
        ctx.enemy[i] = API.Spec(manual.enemy[i]) or enemy or 0
        ctx.sources.friendly[i] = manual.friendly[i] and "manual" or (ctx.friendly[i] ~= 0 and "detected" or "unknown")
        ctx.sources.enemy[i] = manual.enemy[i] and "manual" or (ctx.enemy[i] ~= 0 and "detected" or "unknown")
        if ctx.friendly[i] ~= 0 then known=known+1 end
        if ctx.enemy[i] ~= 0 then known=known+1 end
    end
    ctx.complete = known == size*2
    ctx.known = known
    return ctx
end
function API.Signature(ctx)
    return tostring(ctx.mapID or 0)..":"..(ctx.mapName or "")..":"..ctx.mode..":"..table.concat(ctx.friendly,",")..":"..table.concat(ctx.enemy,",")
        ..":"..table.concat(ctx.sources.friendly,",")..":"..table.concat(ctx.sources.enemy,",")
end
