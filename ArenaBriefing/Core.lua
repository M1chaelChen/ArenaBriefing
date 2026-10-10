local _, AB = ...
AB.manual={friendly={},enemy={}}
AB.phase="outside"
function AB.Print(message) print("|cff59e6d9"..AB.L("Arena Briefing")..":|r "..message) end
function AB.Log(message)
    if not AB.db or not AB.db.debug then return end
    local log=AB.db.diagnostics
    log[#log+1]=message
    if #log>80 then table.remove(log,1) end
end
function AB.ToggleDebug()
    AB.db.debug=not AB.db.debug
    AB.Print(AB.L("Diagnostics %s. /arenabrief diagnostics shows the log.",AB.db.debug and AB.L("enabled") or AB.L("disabled")))
end
function AB.Clear()
    AB.Inspect.Reset()
    AB.manual={friendly={},enemy={}}; AB.context=nil; AB.result=nil; AB.signature=nil; AB.preview=nil; AB.previewMapID=nil
    AB.UI.frame:Hide()
    AB.UI.RefreshSharing()
    if AB.UI.settings then AB.UI.settings:Hide() end
end
function AB.CanEdit()
    return AB.API.Safe(InCombatLockdown) == false and (AB.phase=="prep" or AB.preview~=nil)
end
function AB.SetEnglish(enabled)
    if AB.API.Safe(InCombatLockdown)~=false then return false end
    AB.db.forceEnglish=enabled==true
    AB.ApplyLanguage()
    AB.UI.RefreshLanguage()
    -- Translate the existing context without reading a new roster or clearing overrides.
    if AB.context then
        AB.result=AB.Evaluate(AB.context,AB.result and AB.result.provider)
        AB.UI.Render(AB.context,AB.result,AB.preview)
    end
    AB.Review.Render()
    return true
end
function AB.Refresh(force)
    if not AB.CanEdit() then return end
    local ctx
    if AB.preview then
        local sample=AB.examples[AB.preview]
        ctx={mode=sample.mode,size=sample.size,friendly={},enemy={},sources={friendly={},enemy={}},known=0}
        for _,side in ipairs({"friendly","enemy"}) do
            for i=1,ctx.size do
                ctx[side][i]=AB.manual[side][i] or sample[side][i]
                ctx.sources[side][i]=AB.manual[side][i] and "manual" or "example"
                if AB.specs[ctx[side][i]] then ctx.known=ctx.known+1 end
            end
        end
        ctx.mapID=AB.previewMapID or sample.mapID
        ctx.playerSpec=ctx.friendly[1]; ctx.complete=ctx.known==ctx.size*2
    else ctx=AB.API.Snapshot(AB.manual) end
    local signature=AB.API.Signature(ctx)
    if force or signature~=AB.signature then
        AB.signature=signature; AB.context=ctx; AB.result=AB.Evaluate(ctx)
        AB.UI.Render(ctx,AB.result,AB.preview)
        AB.UI.RefreshSelectors()
        AB.Log("roster "..signature)
    end
end
function AB.SetSpec(side,index,id)
    if not AB.CanEdit() then AB.Print(AB.L("Team selection is only available in preparation or preview.")); return false end
    if (side~="friendly" and side~="enemy") or not index or index<1 or index>3 or index%1~=0 then return false end
    if AB.context and index>AB.context.size then return false end
    if id~=nil and not AB.specs[id] then AB.Print(AB.L("Unknown specialization ID.")); return false end
    AB.manual[side][index]=id; AB.Refresh(true); return true
end
function AB.Preview(mode,mapID)
    if AB.API.InArena() or AB.API.Safe(InCombatLockdown) then AB.Print(AB.L("Preview is available outside arenas and combat.")); return end
    mode=AB.examples[mode] and mode or "3v3"
    if mapID and not AB.maps[mapID] then AB.Print(AB.L("Unknown preview map ID.")); return end
    AB.Clear(); AB.preview=mode; AB.previewMapID=mapID; AB.Refresh(true); AB.UI.frame:Show()
end
function AB.Tick()
    if not AB.db then return end
    AB.UI.RefreshSharing()
    local arena=AB.API.InArena()
    if not arena then
        AB.History.Observe(false)
        if AB.phase~="outside" then AB.Clear(); AB.phase="outside"; AB.Log("left arena") end
        return
    end
    local state=AB.API.State()
    local preparing=AB.API.IsPreparing(state) and AB.API.Safe(InCombatLockdown) == false
    local nextPhase=preparing and "prep" or "frozen"
    if AB.phase~=nextPhase then
        if nextPhase=="prep" then
            AB.Clear(); AB.phase="prep"; AB.Refresh(true); AB.UI.frame:Show()
        else
            if AB.phase=="outside" then AB.Clear() end
            AB.phase="frozen"; AB.UI.Collapse()
        end
        AB.Log("phase "..nextPhase.." state="..tostring(state))
    end
    if preparing then AB.Inspect.Tick(); AB.Refresh(false)
    else AB.Inspect.Reset() end
    AB.History.Observe(true,state)
end
local function loadSettings()
    ArenaBriefingDB=type(ArenaBriefingDB)=="table" and ArenaBriefingDB or {}
    AB.db=ArenaBriefingDB
    AB.db.scale=tonumber(AB.db.scale) or 1
    if AB.db.scale~=AB.db.scale or AB.db.scale<0.8 or AB.db.scale>1.4 then AB.db.scale=1 end
    AB.db.autoReview=AB.db.autoReview~=false
    AB.db.forceEnglish=AB.db.forceEnglish==true
    AB.ApplyLanguage()
    AB.db.keepVisible=AB.db.keepVisible==true; AB.db.debug=AB.db.debug==true
    AB.db.diagnostics=type(AB.db.diagnostics)=="table" and AB.db.diagnostics or {}
    while #AB.db.diagnostics>80 do table.remove(AB.db.diagnostics,1) end
    local p=AB.db.position
    local anchors={TOP=true,BOTTOM=true,LEFT=true,RIGHT=true,CENTER=true,TOPLEFT=true,TOPRIGHT=true,BOTTOMLEFT=true,BOTTOMRIGHT=true}
    if p and (type(p)~="table" or not anchors[p.point] or not anchors[p.relativePoint] or type(p.x)~="number" or type(p.y)~="number") then AB.db.position=nil end
end
function AB.Command(message)
    local cmd,rest=message:match("^(%S*)%s*(.-)%s*$"); cmd=string.lower(cmd or "")
    if cmd=="preview" then
        local mode,map=rest:match("^(%S*)%s*(%S*)$")
        if not mode or (map~="" and not tonumber(map)) then AB.Print(AB.L("Usage: /arenabrief preview [2v2|3v3|shuffle] [instanceID]"))
        else AB.Preview(mode,map~="" and tonumber(map) or nil) end
    elseif cmd=="history" or cmd=="review" then AB.Review.Show()
    elseif cmd=="settings" then AB.UI.Settings()
    elseif cmd=="debug" then AB.ToggleDebug()
    elseif cmd=="diagnostics" then
        AB.Print(AB.L("Client %s; phase=%s; pack=%s",tostring(AB.API.Safe(GetBuildInfo)),AB.phase,AB.pack.version))
        AB.Print(AB.L("APIs: matchState=%s; opponentSpec=%s; teammateSpec=%s",tostring(type(C_PvP and C_PvP.GetActiveMatchState)=="function"),tostring(type(GetArenaOpponentSpec)=="function"),tostring(type(GetInspectSpecialization)=="function")))
        if AB.signature then AB.Print(AB.L("Current snapshot: %s",AB.signature)) end
        for _,line in ipairs(AB.db.diagnostics) do AB.Print(line) end
    elseif cmd=="set" then
        local side,slot,spec=rest:match("^(%a+)%s+(%d+)%s+(%S+)$")
        if not side or (spec~="auto" and not tonumber(spec)) then AB.Print(AB.L("Usage: /arenabrief set friendly|enemy SLOT SPEC_ID|auto"))
        else AB.SetSpec(side,tonumber(slot),spec~="auto" and tonumber(spec) or nil) end
    elseif cmd=="hide" then AB.UI.frame:Hide()
    elseif cmd=="" or cmd=="show" then
        if AB.context then AB.UI.frame:Show() else AB.Print(AB.L("No briefing yet. Use /arenabrief preview or /arenabrief settings.")) end
    else AB.Print(AB.L("Commands: show, hide, settings, history, review, preview [2v2|3v3|shuffle], set, debug, diagnostics")) end
end
AB.events=CreateFrame("Frame")
AB.events:SetScript("OnEvent",function(_,event,name)
    if event=="ADDON_LOADED" then
        if name~="ArenaBriefing" then return end
        loadSettings(); AB.History.Init(); AB.UI.Create()
        SLASH_ARENABRIEFING1="/arenabrief"; SlashCmdList.ARENABRIEFING=AB.Command
        AB.Tick()
        AB.ticker=C_Timer.NewTicker(0.5,AB.Tick)
    elseif AB.db then
        if event=="INSPECT_READY" then AB.Inspect.Ready(name) end
        if event=="PLAYER_SPECIALIZATION_CHANGED" then AB.Inspect.Invalidate(name) end
        if event=="PLAYER_ENTERING_WORLD" then AB.Clear(); AB.phase="outside" end
        if event=="PLAYER_REGEN_DISABLED" then
            AB.Inspect.Reset()
            AB.UI.Collapse(); AB.Review.Hide()
            if AB.phase=="prep" then AB.phase="frozen" end
        else AB.Tick() end
    end
end)
for _,event in ipairs({"ADDON_LOADED","PLAYER_ENTERING_WORLD","ZONE_CHANGED_NEW_AREA","PVP_MATCH_STATE_CHANGED",
    "ARENA_PREP_OPPONENT_SPECIALIZATIONS","GROUP_ROSTER_UPDATE","PLAYER_SPECIALIZATION_CHANGED","INSPECT_READY","PLAYER_REGEN_DISABLED","UPDATE_BATTLEFIELD_SCORE"}) do
    AB.events:RegisterEvent(event)
end
