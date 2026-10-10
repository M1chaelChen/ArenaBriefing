local _, AB = ...
AB.History = {}
local H, safe = AB.History, AB.API.Safe
local function number(value)
    if issecretvalue and issecretvalue(value) then return nil end
    if type(value)=="number" and value==value and value~=math.huge and value~=-math.huge then return value end
end
local function field(row,key)
    return number(safe(function() return row[key] end))
end
local function copy(value)
    if type(value)~="table" then return value end
    local result={}; for k,v in pairs(value) do result[k]=copy(v) end; return result
end
local function clock() return number(safe(GetTime)) end
function H.Init()
    ArenaBriefingHistoryDB=type(ArenaBriefingHistoryDB)=="table" and ArenaBriefingHistoryDB or {}
    H.db=ArenaBriefingHistoryDB
    H.db.records=type(H.db.records)=="table" and H.db.records or {}
    local clean={}
    for _,r in ipairs(H.db.records) do
        if type(r)=="table" and type(r.rounds)=="table" and type(r.id)=="number" then
            if r.status=="recording" then r.status="interrupted"; r.outcome="unknown" end
            clean[#clean+1]=r
            if #clean>=100 then break end
        end
    end
    H.db.records=clean
    local largest=0; for _,r in ipairs(clean) do largest=math.max(largest,r.id) end
    H.db.nextID=largest+1
    H.match=nil; H.round=nil; H.prepared=nil; H.lastState=nil; H.deadline=nil
end
function H.Begin()
    if not H.match then
        local context=H.prepared and copy(H.prepared.context) or nil
        H.match={id=H.db.nextID,status="recording",outcome="unknown",rounds={},context=context,
            timestamp=number(safe(GetServerTime)),packVersion=AB.pack.version,partial=not context}
        H.db.nextID=H.db.nextID+1
        table.insert(H.db.records,1,H.match)
        while #H.db.records>100 do table.remove(H.db.records) end
    end
    H.round={context=H.prepared and copy(H.prepared.context) or nil,
        briefing=H.prepared and copy(H.prepared.result) or nil,outcome="unknown"}
    H.match.rounds[#H.match.rounds+1]=H.round
    H.roundStart=clock(); H.prepared=nil
end
function H.EndRound()
    if not H.round then return end
    local now=clock()
    if now and H.roundStart then H.round.observedDuration=math.max(0,now-H.roundStart) end
    H.round=nil; H.roundStart=nil
end
function H.CollectFinal()
    if not H.match or H.match.status~="complete" then return end
    if not AB.API.InArena() or AB.API.State()~=(Enum and Enum.PvPMatchState.Complete) then return end
    local duration=number(safe(C_PvP and C_PvP.GetActiveMatchDuration))
    if duration and duration>=0 then H.match.duration=duration end
    local guid=safe(UnitGUID,"player")
    local row=guid and safe(C_PvP and C_PvP.GetScoreInfoByPlayerGuid,guid)
    if type(row)=="table" then
        local stats=H.match.stats or {}
        for _,key in ipairs({"damageDone","healingDone","deaths","killingBlows","rating","ratingChange"}) do
            local v=field(row,key)
            if v and (key=="ratingChange" or v>=0) then stats[key]=v end
        end
        if next(stats) then H.match.stats=stats end
        -- Arena team index comes from the final player scoreboard, not character faction.
        local team=field(row,"faction")
        local winner=number(safe(C_PvP and C_PvP.GetActiveMatchWinner))
        local shuffle=#H.match.rounds>1 or (H.match.context and H.match.context.mode=="Solo Shuffle")
        if not shuffle and H.match.context and (team==0 or team==1) and (winner==0 or winner==1) then
            H.match.outcome=team==winner and "win" or "loss"
        end
    end
    if AB.Review and AB.Review.selected==H.match then AB.Review.Render() end
end
function H.Observe(inArena,state)
    if not H.db then return end
    if AB.Review and AB.Review.pending and (not inArena or state==(Enum and Enum.PvPMatchState.Complete)) and safe(InCombatLockdown)==false then
        local pending=AB.Review.pending; AB.Review.pending=nil; AB.Review.AutoOpen(pending)
    end
    local states=Enum and Enum.PvPMatchState
    if not states then return end
    if not inArena then
        if H.match and H.match.status=="recording" then
            H.EndRound(); H.match.status="interrupted"; H.match.outcome="unknown"
            if AB.Review then AB.Review.AutoOpen(H.match) end
        end
        H.match=nil; H.prepared=nil; H.round=nil; H.lastState=nil; H.deadline=nil
        return
    end
    if AB.API.IsPreparing(state) and AB.API.Safe(InCombatLockdown)==false then
        if H.lastState~=state and not AB.API.IsPreparing(H.lastState) then
            H.EndRound()
            if H.match and H.match.status=="complete" then H.match=nil end
            if AB.Review then AB.Review.Hide() end
        end
        if AB.context and not AB.preview and AB.phase=="prep" then
            H.prepared={context=copy(AB.context),result=copy(AB.result)}
        end
    elseif state==states.Engaged and H.lastState~=state then
        if AB.Review then AB.Review.Hide() end
        H.Begin()
    elseif state==states.PostRound then
        H.EndRound()
    elseif state==states.Complete and H.match then
        if H.match.status=="recording" then
            H.EndRound(); H.match.status="complete"
            H.deadline=(clock() or 0)+30
            H.CollectFinal()
            if AB.Review then AB.Review.AutoOpen(H.match) end
        elseif not H.deadline or (clock() or 0)<=H.deadline then H.CollectFinal() end
    end
    if state~=nil then H.lastState=state end
end
function H.Prompts(record,round)
    local prompts={AB.L("Review prompts, not detected mistakes. No combat timeline or positioning was recorded.")}
    if record.status=="interrupted" or record.partial then
        prompts[#prompts+1]=AB.L("Recording is incomplete. Avoid drawing conclusions from missing results or statistics.")
    end
    local ctx=round and round.context
    if ctx then
        local spec=AB.specs[ctx.playerSpec]
        if spec and spec.role=="healer" then
            prompts[#prompts+1]=AB.L("Could you keep teammates in healing sight while preserving an escape route?")
        else
            prompts[#prompts+1]=AB.L("Did you coordinate pressure with your partner and stay within support range?")
        end
        local briefing=round.briefing
        if briefing then
            for _,r in ipairs(briefing.recommendations or {}) do
                if r.category=="positioning" then prompts[#prompts+1]=AB.L("Revisit your positioning plan: %s",r.text) end
            end
        end
    end
    if record.stats and record.stats.deaths and record.stats.deaths>0 then
        prompts[#prompts+1]=AB.L("A death appears in the final totals. Review defensive coordination; these totals cannot show why you died.")
    end
    prompts[#prompts+1]=AB.L("Choose one adjustment to try next match. Damage or healing totals alone do not establish a mistake.")
    return prompts
end
