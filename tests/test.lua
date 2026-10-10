GetLocale=function() return TEST_LOCALE or "enUS" end
local passed=0
local function test(name, fn)
    local ok,err=pcall(fn)
    if not ok then error(name..": "..tostring(err)) end
    passed=passed+1; print("PASS "..name)
end
local function eq(a,b) assert(a==b,tostring(a).." ~= "..tostring(b)) end
local frames={}
local function frame()
    local f={shown=false,scripts={},text="",height=20}
    setmetatable(f,{__index=function(self,key)
        if key=="CreateFontString" then return function() return frame() end end
        if key=="SetScript" then return function(s,k,v) s.scripts[k]=v end end
        if key=="SetText" then return function(s,v) s.text=v end end
        if key=="GetStringHeight" then return function(s) return math.ceil(#s.text/50)*14 end end
        if key=="SetHeight" then return function(s,v) s.height=v end end
        if key=="Show" then return function(s) s.shown=true end end
        if key=="Hide" then return function(s) s.shown=false end end
        if key=="SetChecked" then return function(s,v) s.checked=v end end
        if key=="GetChecked" then return function(s) return s.checked end end
        if key=="GetPoint" then return function() return "CENTER",nil,"CENTER",12,24 end end
        if key=="SetScale" then return function(s,v) s.scale=v end end
        if key=="SetEnabled" then return function(s,v) s.enabled=v end end
        return function() end
    end})
    frames[#frames+1]=f; return f
end
CreateFrame=frame; UIParent=frame(); GameTooltip=frame()
GameFontHighlight={}; GameFontHighlightSmall={}; SlashCmdList={}
local arena,state,combat=false,0,false
local enemies={259,256}; local friendly={71,105}; local size=2
local secret={}; issecretvalue=function(v) return rawequal(v,secret) end
InCombatLockdown=function() return combat end
IsInInstance=function() return arena,arena and "arena" or "none" end
Enum={PvPMatchState={Inactive=0,Waiting=1,StartUp=2,Engaged=3,PostRound=4,Complete=5}}
C_PvP={GetActiveMatchState=function() return state end}
C_SpecializationInfo={GetSpecialization=function() return 1 end,GetSpecializationInfo=function() return friendly[1] end}
GetInspectSpecialization=function(unit) return friendly[tonumber(unit:match("%d+"))+1] end
local rosterReads=0
GetNumArenaOpponentSpecs=function() rosterReads=rosterReads+1; return size end
GetArenaOpponentSpec=function(i) return enemies[i] end
GetNumGroupMembers=function() return size end
GetBuildInfo=function() return "12.1.0" end
C_Timer={NewTicker=function(_,callback) return {callback=callback} end}
ArenaBriefingDB={scale="bad",position={point="invalid"},diagnostics={}}
local AB={}
for line in io.lines("ArenaBriefing/ArenaBriefing.toc") do
    if line:match("%.lua$") then assert(loadfile("ArenaBriefing/"..line))("ArenaBriefing",AB) end
end
local function event(name,arg) AB.events.scripts.OnEvent(AB.events,name,arg) end
local function rec(result,category)
    for _,r in ipairs(result.recommendations) do if r.category==category then return r end end
end
local function context(player,enemy,friend)
    return {mode="3v3",size=#enemy,playerSpec=player,enemy=enemy,friendly=friend or {player,105,64},complete=true}
end

test("TOC initialization and corrupted settings",function()
    event("ADDON_LOADED","SomethingElse"); eq(AB.db,nil)
    event("ADDON_LOADED","ArenaBriefing"); eq(AB.db.scale,1); eq(AB.db.position,nil)
    assert(SlashCmdList.ARENABRIEFING); eq(AB.phase,"outside")
end)
test("all 40 specs return five unique recommendations",function()
    local n=0
    for id in pairs(AB.specs) do
        n=n+1; local r=AB.Evaluate(context(id,{71,64,105},{id,64,105}))
        eq(#r.recommendations,5); eq(#r.matchedRuleIDs,5)
        local seen={}
        for _,v in ipairs(r.recommendations) do assert(not seen[v.category]); seen[v.category]=true; assert(#v.text>0 and #v.why>0) end
    end
    eq(n,40)
end)
test("determinism, duplicate specs and provider fallback",function()
    local c=context(64,{71,71,105}); local a=AB.Evaluate(c); local b=AB.Evaluate(c,"missing")
    eq(table.concat(a.matchedRuleIDs,","),table.concat(b.matchedRuleIDs,","))
    eq(rec(a,"positioning").ruleID,"pattern.melee")
end)
test("Rogue Mage specific threat overrides generic threats",function()
    eq(rec(AB.Evaluate(context(64,{259,64,256})),"threats").ruleID,"matchup.rogue-mage")
end)
test("composition patterns and sourced control guidance",function()
    eq(rec(AB.Evaluate(context(71,{64,267,105})),"positioning").ruleID,"pattern.casters")
    eq(rec(AB.Evaluate(context(71,{71,253,105})),"positioning").ruleID,"pattern.mixed")
    eq(rec(AB.Evaluate(context(71,{71,253,105})),"cc").ruleID,"sc.counters.cyclone")
end)
test("partial and unknown rosters avoid enemy composition claims",function()
    local c=context(9999,{71,0,9999},{0,0,0}); c.complete=false
    local r=AB.Evaluate(c); eq(rec(r,"target").ruleID,"general.target")
    eq(rec(r,"positioning").ruleID,"general.positioning"); eq(r.complete,false)
end)
test("friendly healerless advice overrides healer-dependent guidance",function()
    local r=AB.Evaluate(context(259,{71,70},{259,64}))
    eq(rec(r,"opening").ruleID,"friendly.healerless")
    eq(rec(r,"positioning").ruleID,"friendly.healerless-position")
    eq(rec(r,"threats").ruleID,"enemy.healerless")
end)
test("secret, missing and failing APIs are rejected",function()
    eq(AB.API.Safe(nil),nil); eq(AB.API.Safe(function() error("restricted") end),nil)
    eq(AB.API.Safe(function() return secret end),nil); eq(AB.API.Spec(secret),nil)
    enemies={secret,0}; local c=AB.API.Snapshot(); eq(c.enemy[1],0); eq(c.complete,false)
    enemies={259,256}
end)
test("manual sources and partial inspection data",function()
    friendly={71,0}
    local c=AB.API.Snapshot({friendly={[2]=105},enemy={[1]=64}})
    eq(c.complete,true); eq(c.sources.friendly[2],"manual"); eq(c.enemy[1],64)
    friendly={71,105}
end)
test("Shuffle lobby count never becomes a fabricated enemy team",function()
    local original=GetNumArenaOpponentSpecs
    GetNumArenaOpponentSpecs=function() return 6 end
    local c=AB.API.Snapshot(); eq(c.enemy[1],0); eq(c.enemy[2],0); eq(c.complete,false)
    GetNumArenaOpponentSpecs=original
end)
test("missing opponent APIs allow manual fallback",function()
    local original=GetArenaOpponentSpec; GetArenaOpponentSpec=nil
    local c=AB.API.Snapshot({friendly={},enemy={64,256}})
    eq(c.enemy[1],64); eq(c.complete,true)
    GetArenaOpponentSpec=original
end)
test("preview renders and settings callbacks work",function()
    AB.Preview("3v3"); eq(AB.preview,"3v3"); eq(AB.UI.frame.shown,true)
    eq(#AB.UI.rows,5); assert(AB.UI.content.height>0)
    AB.UI.Settings(); eq(AB.UI.settings.shown,true)
    AB.UI.frame.scripts.OnDragStop(AB.UI.frame); eq(AB.db.position.x,12)
    local root={CreateButton=function(self,_,callback) if callback then self.callback=callback end; return self end}
    MenuUtil={CreateContextMenu=function(_,builder) builder(nil,root) end}
    AB.UI.Picker(AB.UI.selectors[1].button,"friendly",1); assert(root.callback)
    AB.UI.rows[1].scripts.OnEnter(AB.UI.rows[1]); AB.UI.rows[1].scripts.OnLeave()
end)
test("entry replaces preview; overrides change and clear",function()
    arena=true; state=2; AB.Tick(); eq(AB.preview,nil); eq(AB.phase,"prep")
    eq(AB.context.mode,"2v2"); eq(AB.context.enemy[1],259)
    assert(AB.SetSpec("enemy",1,64)); eq(AB.context.enemy[1],64)
    assert(AB.SetSpec("enemy",1,nil)); eq(AB.context.enemy[1],259)
    assert(not AB.SetSpec("enemy",3,64)); assert(not AB.SetSpec("enemy",1,9999))
end)
test("delayed roster updates without reopening dismissed panel",function()
    AB.UI.frame:Hide(); enemies={0,256}; AB.Tick(); eq(AB.context.complete,false)
    enemies={259,256}; AB.Tick(); eq(AB.context.complete,true); eq(AB.UI.frame.shown,false)
end)
test("combat freezes evaluation and roster access",function()
    local result=AB.result; local reads=rosterReads
    combat=true; state=3; event("PLAYER_REGEN_DISABLED"); AB.Tick()
    eq(AB.phase,"frozen"); eq(AB.UI.frame.shown,false); eq(AB.result,result); eq(rosterReads,reads)
    assert(not AB.SetSpec("enemy",1,64)); AB.Command("show"); eq(AB.UI.frame.shown,true)
    enemies={64,256}; event("ARENA_PREP_OPPONENT_SPECIALIZATIONS"); eq(AB.result,result)
end)
test("six Shuffle rounds clear manual overrides and recalculate",function()
    size=3; C_PvP.IsRatedSoloShuffle=function() return true end
    for round=1,6 do
        state=4; combat=false; AB.Tick()
        enemies=round%2==0 and {71,70,105} or {64,267,256}
        friendly={270,577,253}; state=2; AB.Tick()
        eq(AB.phase,"prep"); eq(AB.context.mode,"Solo Shuffle"); eq(AB.context.enemy[1],enemies[1])
        eq(AB.manual.enemy[1],nil); eq(AB.UI.frame.shown,true)
        AB.SetSpec("enemy",1,259); eq(AB.context.enemy[1],259)
        state=3; combat=true; AB.Tick(); eq(AB.phase,"frozen")
    end
end)
test("keep-visible setting and mid-combat reload",function()
    combat=false; state=2; AB.Tick(); AB.db.keepVisible=true
    combat=true; state=3; AB.Tick(); eq(AB.UI.frame.shown,true)
    event("PLAYER_ENTERING_WORLD"); eq(AB.context,nil); eq(AB.UI.frame.shown,false)
    combat=false; state=2; AB.Tick(); assert(AB.context)
end)
test("unknown combat status prevents preparation reads",function()
    state=2; combat=false
    local original=InCombatLockdown
    InCombatLockdown=function() return secret end
    local reads=rosterReads; AB.Tick(); eq(AB.phase,"frozen"); eq(rosterReads,reads)
    InCombatLockdown=original
end)
test("unavailable phase fails closed and leave clears state",function()
    state=secret; AB.Tick(); eq(AB.phase,"frozen")
    arena=false; AB.Tick(); eq(AB.context,nil); eq(AB.phase,"outside"); eq(AB.manual.enemy[1],nil)
end)
test("slash validation and capped diagnostics",function()
    AB.db.debug=true; for i=1,100 do AB.Log("phase test "..i) end; eq(#AB.db.diagnostics,80)
    AB.Command("preview 2v2"); eq(AB.context.size,2)
    AB.Command("set enemy 1 64"); eq(AB.context.enemy[1],64)
    AB.Command("set enemy 1 auto"); eq(AB.context.enemy[1],259)
    AB.Command("set enemy 1 nonsense"); eq(AB.context.enemy[1],259)
end)
test("locale selection, formatted strings and English fallback",function()
    eq(AB.locale,TEST_LOCALE or "enUS")
    local chinese=AB.locale=="zhCN"
    eq(AB.L("Preview"),chinese and "预览" or "Preview")
    eq(AB.L("untranslated fallback"),"untranslated fallback")
    eq(AB.L("Start with %s (enemy %d).","TARGET",2),chinese and "先集火TARGET（敌方 2 号）。" or "Start with TARGET (enemy 2).")
    eq(AB.SpecLabel(64),chinese and "冰霜法师" or "Frost Mage")
    eq(AB.SpecLabel(0),chinese and "未知专精" or "Unknown spec")
end)
test("translated spec labels, personal advice and glossary coverage",function()
    if AB.locale~="zhCN" then return end
    for _,spec in pairs(AB.specs) do
        assert(AB.L(spec.name)~=spec.name,spec.name)
        assert(AB.L(spec.class)~=spec.class,spec.class)
    end
    for _,description in pairs(AB.glossary) do assert(AB.L(description)~=description,description) end
    for _,pair in pairs(AB.personal) do
        for _,description in ipairs(pair) do assert(AB.L(description)~=description,description) end
    end
end)
test("every bundled strategy branch is translated without changing rule IDs",function()
    local cases={
        context(0,{0,0},{0,0}), context(71,{64,267,105}), context(64,{71,70,105}),
        context(270,{71,253,105}), context(259,{259,64,256}), context(71,{71,70},{71,64}),
    }
    for id in pairs(AB.specs) do cases[#cases+1]=context(id,{71,64,105},{id,64,105}) end
    for _,c in ipairs(cases) do
        local actual=AB.Evaluate(c)
        local saved=AB.locale; AB.locale="enUS"; local english=AB.Evaluate(c); AB.locale=saved
        eq(table.concat(actual.matchedRuleIDs,","),table.concat(english.matchedRuleIDs,","))
        if saved=="zhCN" then
            for _,r in ipairs(actual.recommendations) do
                assert(r.title:find("[\128-\255]"),r.title)
                assert(r.text:find("[\128-\255]"),r.text)
                assert(r.why:find("[\128-\255]"),r.why)
            end
        end
    end
    AB.Preview("shuffle")
    if AB.locale=="zhCN" then
        assert(AB.UI.status.text:find("单排轮斗",1,true))
        assert(AB.UI.roster.text:find("我方队伍",1,true))
        assert(AB.UI.rows[1].heading.text:find("建议集火目标",1,true))
    end
end)
local sent,now,home,instance,raid={},100,true,false,false
GetTime=function() return now end
IsInGroup=function(category) return category==1 and home or category==2 and instance end
IsInRaid=function() return raid end
C_ChatInfo={SendChatMessage=function(message,channel) sent[#sent+1]={message=message,channel=channel} end}
local function prepareShare()
    arena=true; state=2; combat=false; size=3
    friendly={270,577,253}; enemies={64,267,256}
    AB.phase="outside"; AB.Tick()
end
test("sharing never sends automatically and blocks preview",function()
    AB.Preview("3v3")
    assert(not AB.Chat.Send("PARTY")); eq(#sent,0)
    prepareShare(); eq(#sent,0)
    eq(AB.UI.shareButtons.PARTY.enabled,true)
    eq(AB.UI.shareButtons.INSTANCE_CHAT.enabled,false)
end)
test("party button sends the displayed advice and footer",function()
    local expected=AB.Chat.Lines(AB.result)
    AB.UI.shareButtons.PARTY.scripts.OnClick()
    eq(#sent,6)
    for i=1,6 do eq(sent[i].channel,"PARTY"); eq(sent[i].message,expected[i]); assert(#sent[i].message<=255) end
    eq(AB.UI.shareButtons.PARTY.enabled,false)
    assert(not AB.Chat.Send("PARTY")); eq(#sent,6)
end)
test("instance channel is explicit and shares cooldown with party",function()
    instance=true
    assert(not AB.Chat.Send("INSTANCE_CHAT")); eq(#sent,6)
    now=110; AB.Tick(); eq(AB.UI.shareButtons.INSTANCE_CHAT.enabled,true)
    AB.UI.shareButtons.INSTANCE_CHAT.scripts.OnClick()
    eq(#sent,12); eq(sent[12].channel,"INSTANCE_CHAT")
    home=false; now=120
    assert(not AB.Chat.Send("PARTY")); eq(#sent,12)
    assert(not AB.Chat.Send("RAID")); eq(#sent,12)
    home=true; raid=true; assert(not AB.Chat.Send("PARTY")); raid=false
end)
test("stale phase, combat, round end and arena exit cannot send",function()
    state=3; assert(not AB.Chat.Send("INSTANCE_CHAT")) -- state changed before ticker
    state=2; combat=true; assert(not AB.Chat.Send("INSTANCE_CHAT"))
    combat=false; state=4; AB.Tick(); assert(not AB.Chat.Send("INSTANCE_CHAT"))
    arena=false; AB.Tick(); assert(not AB.Chat.Send("INSTANCE_CHAT")); eq(#sent,12)
end)
test("chat errors stop submission and missing APIs disable share",function()
    prepareShare(); now=130
    local normal=C_ChatInfo.SendChatMessage; local attempts=0
    C_ChatInfo.SendChatMessage=function() attempts=attempts+1; error("blocked") end
    assert(not AB.Chat.Send("INSTANCE_CHAT")); eq(attempts,1); eq(#sent,12)
    C_ChatInfo.SendChatMessage=nil; now=140
    assert(not AB.Chat.Availability("INSTANCE_CHAT"))
    SendChatMessage=normal; assert(AB.Chat.Send("INSTANCE_CHAT")); eq(#sent,18)
    SendChatMessage=nil; C_ChatInfo.SendChatMessage=normal
end)
test("chat byte limits preserve UTF-8 and identify partial rosters",function()
    local r={complete=false,recommendations={{title="Test",text=string.rep("中",120)}}}
    local line=AB.Chat.Lines(r)[1]
    local prefix=AB.L("[Arena Briefing: partial roster] ").."Test: "
    eq(line:sub(1,#prefix),prefix); assert(#line<=255); eq(line:sub(-3),"...")
    local body=line:sub(#prefix+1,-4)
    eq(#body%3,0); eq(body,string.rep("中",#body/3))
    r.recommendations[1].text="a|b\nc\rd"
    line=AB.Chat.Lines(r)[1]; assert(not line:find("[|\r\n]"))
end)
test("new round shares a fresh result without queued old messages",function()
    state=4; AB.Tick(); now=150; eq(#sent,18)
    enemies={71,70,105}; state=2; AB.Tick(); eq(#sent,18)
    assert(AB.Chat.Send("INSTANCE_CHAT")); eq(#sent,24)
    eq(sent[19].message,AB.Chat.Lines(AB.result)[1])
end)
test("same teams receive different terrain advice on different maps",function()
    local c=context(64,{71,70,105}); c.mapID=1505
    local pillar=AB.Evaluate(c); c.mapID=1672; local bridge=AB.Evaluate(c)
    assert(rec(pillar,"positioning").text~=rec(bridge,"positioning").text)
    eq(rec(bridge,"positioning").ruleID,"map.1672.melee")
    eq(rec(pillar,"target").ruleID,rec(bridge,"target").ruleID)
    c.enemy={64,267,105}; eq(rec(AB.Evaluate(c),"positioning").ruleID,"map.1672.casters")
    c.friendly={64,71,70}; eq(rec(AB.Evaluate(c),"positioning").ruleID,"map.1672.healerless")
end)
test("all terrain profiles are localized and fit shared chat",function()
    for id,map in pairs(AB.maps) do
        local c=context(64,{64,267,105}); c.mapID=id
        local result=AB.Evaluate(c)
        if map.terrain then
            eq(rec(result,"positioning").ruleID,"map."..id..".casters")
            if AB.locale=="zhCN" then
                assert(AB.L(map.name)~=map.name)
                assert(AB.L(AB.terrain[map.terrain])~=AB.terrain[map.terrain])
            end
        end
        local lines=AB.Chat.Lines(result)
        assert(lines[1]:find(AB.L(map.name),1,true))
        assert(lines[5]:find(rec(result,"positioning").text,1,true),"truncated terrain advice: "..id)
    end
end)
test("unknown and unprofiled maps retain composition guidance",function()
    local c=context(64,{71,70,105}); c.mapID=999999; c.mapName="Future Arena"
    eq(rec(AB.Evaluate(c),"positioning").ruleID,"pattern.melee")
    eq(AB.MapLabel(c),"Future Arena")
    c.mapID=2759; eq(rec(AB.Evaluate(c),"positioning").ruleID,"pattern.melee")
    c.mapID=nil; c.mapName=nil; eq(AB.MapLabel(c),AB.L("Unknown arena"))
end)
test("map adapter validates IDs and rejects secret or missing data",function()
    local id=1505
    GetInstanceInfo=function() return "Test Arena","arena",0,"",0,0,false,id end
    eq(AB.API.Map(),1505)
    id=secret; eq(AB.API.Map(),nil)
    id="1505"; eq(AB.API.Map(),nil)
    id=0; eq(AB.API.Map(),nil)
    GetInstanceInfo=nil; eq(AB.API.Map(),nil)
end)
test("late map data refreshes preparation and freezes in combat",function()
    local id=0
    GetInstanceInfo=function() return "Test Arena","arena",0,"",0,0,false,id end
    prepareShare(); eq(AB.context.mapID,nil)
    id=1672; AB.Tick(); eq(AB.context.mapID,1672)
    assert(AB.UI.roster.text:find(AB.L("Blade's Edge Arena"),1,true))
    local result=AB.result; combat=true; state=3; id=1505; AB.Tick()
    eq(AB.result,result); eq(AB.context.mapID,1672)
    arena=false; combat=false; AB.Tick(); eq(AB.context,nil)
    GetInstanceInfo=nil
end)
test("preview map selection validates input and resets between previews",function()
    AB.Command("preview 3v3 1672"); eq(AB.context.mapID,1672)
    AB.Command("preview 3v3 999999"); eq(AB.context.mapID,1672)
    AB.Command("preview 3v3 invalid"); eq(AB.context.mapID,1672)
    AB.Command("preview 2v2"); eq(AB.context.mapID,1505)
    AB.Command("preview shuffle"); eq(AB.context.mapID,2563)
end)
local scoreCalls=0
local score,winner,matchDuration=nil,nil,nil
local function resetHistory()
    ArenaBriefingHistoryDB={}; AB.History.Init(); AB.Review.Hide()
    AB.db.autoReview=true; scoreCalls=0; score=nil; winner=nil; matchDuration=nil
    arena=false; state=0; combat=false; AB.phase="outside"; AB.Clear()
    size=3; friendly={64,258,256}; enemies={71,70,105}
    GetTime=function() return now end
    GetServerTime=function() return 1800000000+now end
    UnitGUID=function() return "player-guid-test" end
    C_PvP.IsRatedSoloShuffle=function() return false end
    C_PvP.GetScoreInfoByPlayerGuid=function(guid) eq(guid,"player-guid-test"); scoreCalls=scoreCalls+1; return score end
    C_PvP.GetActiveMatchWinner=function() return winner end
    C_PvP.GetActiveMatchDuration=function() return matchDuration end
end
local function startFight()
    arena=true; state=2; combat=false; AB.Tick()
    state=3; combat=true; AB.Tick()
end
local function finishFight()
    state=5; combat=false; AB.Tick()
end
test("history saves original briefing and reads scores only on completion",function()
    resetHistory(); now=200; startFight()
    eq(#AB.History.db.records,1); eq(scoreCalls,0)
    local r=AB.History.db.records[1]
    eq(r.status,"recording"); eq(#r.rounds,1); assert(r.rounds[1].briefing)
    assert(r.rounds[1].context~=AB.context)
    now=245; score={faction=0,damageDone=123456,healingDone=0,deaths=0,ratingChange=12}; winner=0; matchDuration=45
    finishFight(); eq(r.status,"complete"); eq(r.outcome,"win"); eq(r.duration,45)
    eq(r.rounds[1].observedDuration,45); eq(r.stats.healingDone,0)
    eq(AB.Review.frame.shown,true); eq(AB.Review.selected,r)
    AB.Tick(); eq(#AB.History.db.records,1)
end)
test("late scoreboard data enriches the same record without reopening",function()
    resetHistory(); now=300; startFight(); now=320; finishFight()
    local r=AB.History.db.records[1]; eq(r.outcome,"unknown"); eq(r.stats,nil)
    AB.Review.Hide(); score={faction=1,damageDone=55,healingDone=secret,deaths=1,ratingChange=-9}; winner=0
    now=321; event("UPDATE_BATTLEFIELD_SCORE")
    eq(r.outcome,"loss"); eq(r.stats.damageDone,55); eq(r.stats.healingDone,nil)
    eq(r.stats.ratingChange,-9); eq(AB.Review.frame.shown,false); eq(#AB.History.db.records,1)
    local calls=scoreCalls; now=351; AB.Tick(); eq(scoreCalls,calls)
end)
test("whole secret rows, erroring APIs and unknown results fail safely",function()
    resetHistory(); now=400; startFight(); score=secret; winner=secret; matchDuration=secret; finishFight()
    local r=AB.History.db.records[1]; eq(r.stats,nil); eq(r.outcome,"unknown"); eq(r.duration,nil)
    C_PvP.GetScoreInfoByPlayerGuid=function() error("restricted") end
    AB.Tick(); eq(r.outcome,"unknown")
end)
test("six Shuffle rounds retain context but never assign session totals to rounds",function()
    resetHistory(); C_PvP.IsRatedSoloShuffle=function() return true end
    now=500
    for i=1,6 do
        enemies=i%2==0 and {64,267,256} or {71,70,105}
        startFight(); now=now+30
        if i<6 then state=4; combat=false; AB.Tick(); eq(scoreCalls,0) end
    end
    score={faction=0,damageDone=9999,deaths=3}; winner=0; finishFight()
    eq(#AB.History.db.records,1)
    local r=AB.History.db.records[1]; eq(#r.rounds,6); eq(r.outcome,"unknown"); eq(r.stats.damageDone,9999)
    for i,round in ipairs(r.rounds) do
        eq(round.outcome,"unknown"); eq(round.stats,nil); eq(round.observedDuration,30)
        eq(round.context.enemy[1],i%2==0 and 64 or 71)
    end
    AB.Review.roundButton.scripts.OnClick(); eq(AB.Review.roundIndex,2)
end)
test("leaving early stores incomplete record and reload marks unfinished capture",function()
    resetHistory(); now=700; startFight(); now=710; arena=false; combat=false; AB.Tick()
    local r=AB.History.db.records[1]; eq(r.status,"interrupted"); eq(r.outcome,"unknown")
    eq(r.rounds[1].observedDuration,10); eq(scoreCalls,0)
    now=720; startFight(); AB.History.Init()
    eq(AB.History.db.records[1].status,"interrupted"); eq(#AB.History.db.records,2)
    AB.Tick(); eq(#AB.History.db.records,3); eq(AB.History.db.records[1].partial,true)
    eq(AB.History.db.records[1].rounds[1].context,nil)
end)
test("preview cannot create history and missing active-phase observations are not invented",function()
    resetHistory(); AB.Preview("shuffle"); AB.Tick(); eq(#AB.History.db.records,0)
    arena=true; state=5; AB.Tick(); eq(#AB.History.db.records,0)
end)
test("auto-open preference, combat deferral and next-round hiding",function()
    resetHistory(); now=800; startFight(); AB.db.autoReview=false; finishFight()
    eq(AB.Review.frame.shown,false)
    AB.Command("history"); eq(AB.Review.frame.shown,true)
    arena=false; AB.Tick(); startFight(); eq(AB.Review.frame.shown,false)
    AB.db.autoReview=true; state=5; combat=true; AB.Tick(); assert(AB.Review.pending)
    combat=false; AB.Tick(); eq(AB.Review.frame.shown,true); eq(AB.Review.pending,nil)
end)
test("history retention and browsing are bounded and per-character",function()
    resetHistory(); AB.db.autoReview=false
    for i=1,105 do
        now=900+i*2; startFight(); finishFight(); arena=false; AB.Tick()
    end
    eq(#AB.History.db.records,100); eq(AB.History.db.records[1].id,105)
    eq(AB.History.db.records[100].id,6); eq(AB.db.records,nil)
    AB.Command("review"); eq(AB.Review.selected.id,105)
    AB.Review.older.scripts.OnClick(); eq(AB.Review.selected.id,104)
    AB.Review.newer.scripts.OnClick(); eq(AB.Review.selected.id,105)
end)
test("review prompts remain questions and support Simplified Chinese",function()
    local r=AB.History.db.records[1]; local prompts=AB.History.Prompts(r,r.rounds[1])
    eq(prompts[1],AB.L("Review prompts, not detected mistakes. No combat timeline or positioning was recorded."))
    assert(#prompts>=3)
    if AB.locale=="zhCN" then
        for _,prompt in ipairs(prompts) do assert(prompt:find("[\128-\255]"),prompt) end
        assert(AB.Review.text.text:find("复盘提示",1,true))
    end
end)
-- Model a cold client: reads stay zero until NotifyInspect + INSPECT_READY,
-- and each new inspection evicts Blizzard's previous inspection result.
local inspectNow,inspectRequests,inspectGUIDs,inspectResult,inspectable
local inspectReads=0
local function setupInspection()
    arena=false; combat=false; state=0; AB.phase="outside"; AB.Clear()
    inspectNow=(inspectNow or 2000)+20
    inspectRequests={}; inspectGUIDs={party1="teammate-a",party2="teammate-b"}
    inspectResult={}; inspectable={party1=true,party2=true}
    friendly={65,0,0}; enemies={252,71,105}; size=3
    GetTime=function() return inspectNow end
    UnitGUID=function(unit) return inspectGUIDs[unit] end
    GetInspectSpecialization=function(unit)
        inspectReads=inspectReads+1
        return inspectResult[inspectGUIDs[unit]] or 0
    end
    CanInspect=function(unit) return inspectable[unit] end
    NotifyInspect=function(unit)
        inspectRequests[#inspectRequests+1]=unit; inspectResult={}
    end
    InspectFrame=nil; PlayerSpellsFrame=nil
    C_PvP.IsRatedSoloShuffle=function() return false end
    C_PvP.GetScoreInfoByPlayerGuid=nil
    arena=true; state=2
end
local function inspectionReady(guid,spec)
    inspectResult={[guid]=spec}; event("INSPECT_READY",guid)
end
test("cold first run requests both teammate specs and retains the first result",function()
    setupInspection(); AB.Tick()
    eq(AB.context.friendly[1],65); eq(AB.context.friendly[2],0); eq(AB.context.friendly[3],0)
    eq(#inspectRequests,1); eq(inspectRequests[1],"party1")
    AB.UI.frame:Hide()
    event("INSPECT_READY","unrelated-player"); event("INSPECT_READY",secret)
    inspectNow=inspectNow+2; AB.Tick(); eq(#inspectRequests,1)
    inspectionReady("teammate-a",64)
    eq(#inspectRequests,2); eq(inspectRequests[2],"party2")
    eq(AB.context.friendly[2],64); eq(AB.context.complete,false)
    inspectionReady("teammate-b",259)
    eq(AB.context.friendly[2],64); eq(AB.context.friendly[3],259)
    eq(AB.context.complete,true); eq(AB.context.sources.friendly[2],"detected")
    eq(AB.UI.frame.shown,false)
    inspectNow=inspectNow+10; AB.Tick(); eq(#inspectRequests,2)
end)
test("inspection throttle and timeout let both teammates get a turn",function()
    setupInspection(); AB.Tick()
    inspectNow=inspectNow+1; AB.Tick(); eq(#inspectRequests,1)
    inspectNow=inspectNow+3.9; AB.Tick(); eq(#inspectRequests,1)
    inspectNow=inspectNow+0.1; AB.Tick(); eq(inspectRequests[2],"party2")
    inspectionReady("teammate-b",259)
    inspectNow=inspectNow+1; AB.Tick(); eq(#inspectRequests,2)
    inspectNow=inspectNow+1; AB.Tick(); eq(inspectRequests[3],"party1")
    inspectionReady("teammate-a",64); eq(AB.context.complete,true)
end)
test("uninspectable teammates are retried after they become available",function()
    setupInspection(); inspectable.party1=false; AB.Tick()
    eq(inspectRequests[1],"party2"); inspectionReady("teammate-b",259)
    inspectNow=inspectNow+2; AB.Tick(); eq(#inspectRequests,1)
    inspectable.party1=true; AB.Tick(); eq(inspectRequests[2],"party1")
    inspectionReady("teammate-a",64); eq(AB.context.complete,true)
end)
test("in-flight results follow identity when party slots swap",function()
    setupInspection(); AB.Tick()
    inspectGUIDs.party1,inspectGUIDs.party2="teammate-b","teammate-a"
    inspectionReady("teammate-a",64)
    eq(AB.context.friendly[2],0); eq(AB.context.friendly[3],64)
    inspectNow=inspectNow+2; AB.Tick(); eq(inspectRequests[2],"party1")
    inspectionReady("teammate-b",259)
    eq(AB.context.friendly[2],259); eq(AB.context.friendly[3],64)
end)
test("departed teammates and new rounds cannot inherit cached specs",function()
    setupInspection(); AB.Tick(); inspectionReady("teammate-a",64)
    inspectGUIDs.party1="teammate-c"; inspectNow=inspectNow+2
    event("GROUP_ROSTER_UPDATE"); eq(AB.context.friendly[2],0)
    inspectionReady("teammate-b",259)
    inspectNow=inspectNow+2; AB.Tick(); eq(inspectRequests[3],"party1")
    inspectGUIDs.party1="teammate-d"
    inspectionReady("teammate-c",71); eq(AB.context.friendly[2],0)
    state=4; AB.Tick(); inspectResult={}
    inspectNow=inspectNow+2; state=2; AB.Tick()
    eq(AB.context.friendly[2],0); eq(AB.context.friendly[3],0)
    inspectionReady("teammate-c",71); eq(AB.context.friendly[2],0)
end)
test("spec changes invalidate old cached and API data until a new response",function()
    setupInspection(); AB.Tick(); inspectionReady("teammate-a",64)
    inspectNow=inspectNow+2; event("PLAYER_SPECIALIZATION_CHANGED","party1")
    eq(AB.context.friendly[2],0); eq(inspectRequests[2],"party2")
    inspectionReady("teammate-b",259)
    inspectNow=inspectNow+2; AB.Tick(); eq(inspectRequests[3],"party1")
    inspectionReady("teammate-a",63); eq(AB.context.friendly[2],63)
end)
test("manual teammate choices remain authoritative and auto resumes inspection",function()
    setupInspection(); AB.manual.friendly[2]=71; AB.manual.friendly[3]=105
    -- Establish preparation first, since entering it intentionally clears overrides.
    NotifyInspect=nil; AB.Tick(); AB.SetSpec("friendly",2,71); AB.SetSpec("friendly",3,105)
    NotifyInspect=function(unit) inspectRequests[#inspectRequests+1]=unit end
    AB.Tick(); eq(#inspectRequests,0); eq(AB.context.friendly[2],71)
    AB.SetSpec("friendly",2,nil); AB.Tick(); eq(inspectRequests[1],"party1")
    AB.SetSpec("friendly",2,70); inspectionReady("teammate-a",64)
    eq(AB.context.friendly[2],70); eq(AB.context.sources.friendly[2],"manual")
    AB.SetSpec("friendly",2,nil); eq(AB.context.friendly[2],64)
end)
test("inspection stops before reading rosters when combat begins",function()
    setupInspection(); AB.Tick(); local reads=inspectReads; local result=AB.result
    combat=true; state=3; event("INSPECT_READY","teammate-a")
    inspectNow=inspectNow+10; event("PLAYER_REGEN_DISABLED"); AB.Tick()
    eq(#inspectRequests,1); eq(inspectReads,reads); eq(AB.result,result)
    eq(AB.context.friendly[2],0)
    arena=false; combat=false; AB.Tick(); event("INSPECT_READY","teammate-a")
    eq(#inspectRequests,1); eq(AB.context,nil)
end)
test("standard inspect windows pause requests and errors remain retryable",function()
    setupInspection(); InspectFrame={IsShown=function() return true end}; AB.Tick()
    eq(#inspectRequests,0); InspectFrame=nil
    PlayerSpellsFrame={IsInspecting=function() return true end}; AB.Tick(); eq(#inspectRequests,0)
    PlayerSpellsFrame=nil
    local notify=NotifyInspect; NotifyInspect=function() error("temporarily unavailable") end
    AB.Tick(); NotifyInspect=notify; AB.Tick(); eq(#inspectRequests,0)
    inspectNow=inspectNow+2; AB.Tick(); eq(inspectRequests[1],"party2")
end)
test("missing and restricted inspection APIs never invent teammate specs",function()
    setupInspection(); UnitGUID=function() return secret end; AB.Tick(); eq(#inspectRequests,0)
    UnitGUID=function(unit) return inspectGUIDs[unit] end
    CanInspect=function() return secret end; AB.Tick(); eq(#inspectRequests,0)
    CanInspect=function() return true end; NotifyInspect=nil; AB.Tick(); eq(#inspectRequests,0)
    GetInspectSpecialization=function() return secret end
    AB.Tick(); eq(AB.context.friendly[2],0); eq(AB.context.complete,false)
    GetInspectSpecialization=nil; AB.Tick(); eq(AB.context.friendly[2],0)
end)
test("two-player preparation requests only its one teammate",function()
    setupInspection(); size=2; AB.Tick(); eq(inspectRequests[1],"party1")
    inspectionReady("teammate-a",64); eq(AB.context.complete,true)
    inspectNow=inspectNow+10; AB.Tick(); eq(#inspectRequests,1)
end)
test("inspection adapter supports the namespaced API",function()
    setupInspection(); GetInspectSpecialization=nil
    C_SpecializationInfo.GetInspectSpecialization=function() return 64 end
    AB.Tick(); eq(AB.context.friendly[2],64); eq(#inspectRequests,0)
    C_SpecializationInfo.GetInspectSpecialization=nil
end)

test("Skill Capped candidate sets ignore roster ordering and do not rank by slot",function()
    local c=context(71,{64,71,256}); c.mode="Solo Shuffle"
    local a=rec(AB.Evaluate(c),"target")
    eq(a.ruleID,"sc.targets.candidates"); assert(a.text:find(AB.SpecLabel(71),1,true))
    assert(not a.text:find(AB.SpecLabel(64),1,true))
    c.enemy={256,71,64}; eq(rec(AB.Evaluate(c),"target").text,a.text)
    c.enemy={64,267,256}; assert(rec(AB.Evaluate(c),"target").text:find(AB.SpecLabel(267),1,true))
end)
test("target source remains Shuffle-specific and caster guidance is conditional",function()
    local c=context(64,{71,70,105}); c.mode="Solo Shuffle"
    eq(rec(AB.Evaluate(c),"target").ruleID,"sc.targets.caster")
    c.mode="3v3"; eq(rec(AB.Evaluate(c),"target").ruleID,"general.target")
    c.mode="2v2"; eq(rec(AB.Evaluate(c),"target").sourceID,nil)
    c.mode="Solo Shuffle"; c.enemy={71,0,105}; eq(rec(AB.Evaluate(c),"target").sourceID,nil)
end)
test("patch mismatch disables sourced tactics while preserving general terrain",function()
    local c=context(71,{64,267,256}); c.mode="Solo Shuffle"; c.mapID=1672; c.clientVersion="12.2.0"
    local result=AB.Evaluate(c)
    for _,r in ipairs(result.recommendations) do eq(r.sourceID,nil) end
    assert(rec(result,"positioning").ruleID:match("^map%."))
    eq(result.review,AB.L("Source patch differs; general rules only"))
    c.clientVersion="12.1.5"; assert(rec(AB.Evaluate(c),"target").sourceID)
end)
test("sourced recommendations carry provenance and remain localized",function()
    for _,class in ipairs({"Warrior","Mage","Druid","Warlock","Rogue","Monk"}) do
        local ids={Warrior=71,Mage=64,Druid=102,Warlock=267,Rogue=259,Monk=269}
        local c=context(71,{ids[class],65}); c.size=2
        local r=rec(AB.Evaluate(c),"threats")
        eq(r.sourceID,"counters"); eq(r.source.patch,"12.1"); eq(r.source.checked,"2026-10-03")
        assert(r.source.url:find("skill%-capped.com"))
        if AB.locale=="zhCN" then assert(r.text:find("[\128-\255]")) end
    end
    local c=context(71,{267,65}); eq(rec(AB.Evaluate(c),"cc").ruleID,"sc.counters.warlock")
    c.enemy={266,65}; eq(rec(AB.Evaluate(c),"cc").ruleID,"enemy.healer")
end)
test("source footer and saved briefing provenance reach UI and history",function()
    resetHistory(); now=1800; C_PvP.IsRatedSoloShuffle=function() return true end
    friendly={71,64,105}; enemies={267,71,256}; startFight()
    local briefing=AB.History.db.records[1].rounds[1].briefing
    eq(rec(briefing,"target").sourceID,"targets")
    assert(not AB.UI.rows[1].heading.text:find("[SC]",1,true))
    eq(AB.UI.attribution.text,briefing.review)
    local lines=AB.Chat.Lines(briefing)
    for _,line in ipairs(lines) do assert(not line:find("[SC]",1,true)); assert(#line<=255) end
    assert(lines[#lines]:find(briefing.review,1,true))
    finishFight(); assert(AB.Review.text.text:find(AB.knowledge.sources.targets.url,1,true))
end)
local function englishToggle(enabled)
    AB.UI.englishCheck:SetChecked(enabled)
    AB.UI.englishCheck.scripts.OnClick(AB.UI.englishCheck)
end
test("English toggle translates existing UI and preview without losing selections",function()
    resetHistory(); AB.SetEnglish(false); AB.Preview("3v3"); AB.UI.Settings()
    AB.SetSpec("friendly",2,64); AB.UI.frame:Hide()
    local original=AB.result.recommendations[1].text
    local signature=AB.signature; local ctx=AB.context; local reads=rosterReads
    local sentBefore=#sent
    englishToggle(true)
    eq(AB.locale,"enUS"); eq(AB.db.forceEnglish,true); eq(AB.UI.englishCheck:GetChecked(),true)
    eq(AB.context,ctx); eq(AB.signature,signature); eq(rosterReads,reads)
    eq(AB.manual.friendly[2],64); eq(AB.UI.selectors[2].button.text,"Frost Mage")
    eq(AB.UI.shareButtons.PARTY.text,"Send to party")
    assert(AB.UI.roster.text:find("Your team:",1,true))
    for _,r in ipairs(AB.result.recommendations) do
        assert(not (r.title..r.text..r.why):find("[\128-\255]"))
    end
    eq(AB.UI.frame.shown,false); eq(AB.UI.settings.shown,true); eq(#sent,sentBefore)
    englishToggle(false)
    eq(AB.locale,TEST_LOCALE); eq(AB.db.forceEnglish,false)
    eq(AB.result.recommendations[1].text,original); eq(AB.manual.friendly[2],64)
    if TEST_LOCALE=="zhCN" then
        eq(AB.UI.selectors[2].button.text,"冰霜法师")
        eq(AB.UI.shareButtons.PARTY.text,"发送到小队")
    end
end)
test("both team buttons send the displayed English briefing and source note",function()
    resetHistory(); now=2200; arena=true; state=2; AB.Tick(); AB.UI.Settings()
    AB.SetSpec("friendly",2,64); AB.SetSpec("friendly",3,256)
    englishToggle(true); AB.Tick()
    home=true; instance=true; raid=false
    sent={}; AB.Chat.lastAttempt=nil
    local expected=AB.Chat.Lines(AB.result)
    for _,channel in ipairs({"PARTY","INSTANCE_CHAT"}) do
        now=now+10; AB.UI.shareButtons[channel].scripts.OnClick()
        local offset=#sent-#expected
        for i,line in ipairs(expected) do
            eq(sent[offset+i].channel,channel); eq(sent[offset+i].message,line)
            assert(not line:find("[\128-\255]")); assert(#line<=255)
        end
    end
    eq(#sent,2*#expected)
    local count=#sent; englishToggle(false); eq(#sent,count)
    now=now+10; AB.UI.shareButtons.PARTY.scripts.OnClick()
    local restored=AB.Chat.Lines(AB.result)
    eq(#sent,count+#restored)
    for i,line in ipairs(restored) do eq(sent[count+i].message,line) end
    if TEST_LOCALE=="zhCN" then assert(sent[#sent].message:find("[\128-\255]")) end
end)
test("language changes preserve saved historical briefing text",function()
    resetHistory(); AB.SetEnglish(false); now=2300; startFight(); finishFight()
    local round=AB.History.db.records[1].rounds[1]
    local saved=round.briefing.recommendations[1].text
    AB.UI.Settings(); englishToggle(true)
    eq(AB.Review.newer.text,"Newer"); eq(AB.Review.roundButton.text,"Next round")
    eq(round.briefing.recommendations[1].text,saved)
    assert(AB.Review.text.text:find("Original briefing (saved language)",1,true))
    englishToggle(false)
end)
test("combat blocks language changes and leaves the frozen briefing intact",function()
    resetHistory(); AB.SetEnglish(false); now=2400; startFight()
    local result=AB.result; local reads=rosterReads
    assert(not AB.SetEnglish(true)); eq(AB.db.forceEnglish,false)
    eq(AB.locale,TEST_LOCALE); eq(AB.result,result); eq(rosterReads,reads)
    combat=false; arena=false; AB.Tick()
end)
test("saved English preference is applied before startup UI and survives reload",function()
    AB.SetEnglish(true)
    local reloaded={}
    for line in io.lines("ArenaBriefing/ArenaBriefing.toc") do
        if line:match("%.lua$") then assert(loadfile("ArenaBriefing/"..line))("ArenaBriefing",reloaded) end
    end
    reloaded.events.scripts.OnEvent(reloaded.events,"ADDON_LOADED","ArenaBriefing")
    eq(reloaded.db.forceEnglish,true); eq(reloaded.locale,"enUS")
    eq(reloaded.UI.shareButtons.PARTY.text,"Send to party")
    reloaded.UI.Settings(); eq(reloaded.UI.englishCheck:GetChecked(),true)
    reloaded.SetEnglish(false); eq(reloaded.locale,TEST_LOCALE)
    AB.SetEnglish(false)
end)
test("invalid saved language preference defaults to the client language",function()
    AB.db.forceEnglish="true"
    local reloaded={}
    for line in io.lines("ArenaBriefing/ArenaBriefing.toc") do
        if line:match("%.lua$") then assert(loadfile("ArenaBriefing/"..line))("ArenaBriefing",reloaded) end
    end
    reloaded.events.scripts.OnEvent(reloaded.events,"ADDON_LOADED","ArenaBriefing")
    eq(reloaded.db.forceEnglish,false); eq(reloaded.locale,TEST_LOCALE)
end)
print("\n"..passed.." tests passed (Lua ".._VERSION..")")
