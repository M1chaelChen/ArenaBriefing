local _, AB = ...
AB.UI = {}
local UI = AB.UI
local localized = {}
local function updateLabel(entry)
    entry.widget:SetText(type(entry.key)=="function" and entry.key() or AB.L(entry.key,unpack(entry.args)))
end
function UI.Localize(widget,key,...)
    local entry={widget=widget,key=key,args={...}}
    localized[#localized+1]=entry
    updateLabel(entry)
end
function UI.RefreshLanguage()
    for _,entry in ipairs(localized) do updateLabel(entry) end
    if UI.englishCheck then UI.englishCheck:SetChecked(AB.db.forceEnglish) end
    UI.RefreshSelectors()
    GameTooltip:Hide()
end
local function text(parent, size, color)
    local t = parent:CreateFontString(nil,"OVERLAY","GameFontNormal")
    t:SetFontObject(size == "small" and GameFontHighlightSmall or GameFontHighlight)
    t:SetJustifyH("LEFT"); t:SetJustifyV("TOP")
    if color then t:SetTextColor(unpack(color)) end
    return t
end
local function button(parent, label, width, onClick)
    local b = CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(width,24); UI.Localize(b,label); b:SetScript("OnClick",onClick)
    return b
end
local function window(name, width, height)
    local f = CreateFrame("Frame",name,UIParent,"BackdropTemplate")
    f:SetSize(width,height); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
    f:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8",edgeFile="Interface/Buttons/WHITE8X8",edgeSize=1})
    f:SetBackdropColor(0.035,0.055,0.075,0.97); f:SetBackdropBorderColor(0.2,0.65,0.7,1)
    f:SetClampedToScreen(true); f:EnableMouse(true); f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    local close = CreateFrame("Button",nil,f,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-2,-2)
    f:Hide()
    return f
end
function UI.Create()
    local f = window("ArenaBriefingPanel",440,590)
    UI.frame=f
    local title=text(f); title:SetPoint("TOPLEFT",16,-15); UI.Localize(title,"ARENA BRIEFING"); title:SetTextColor(0.35,0.9,0.85)
    UI.status=text(f,"small"); UI.status:SetPoint("TOPLEFT",16,-40); UI.status:SetWidth(405)
    local scroll = CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-82); scroll:SetPoint("BOTTOMRIGHT",-32,80)
    local content=CreateFrame("Frame",nil,scroll); content:SetSize(385,800); scroll:SetScrollChild(content)
    UI.content=content
    UI.roster=text(content,"small"); UI.roster:SetPoint("TOPLEFT"); UI.roster:SetWidth(380)
    UI.rows={}
    for i=1,5 do
        local row=CreateFrame("Frame",nil,content); row:SetWidth(380); row:EnableMouse(true)
        row.heading=text(row); row.heading:SetPoint("TOPLEFT"); row.heading:SetWidth(380); row.heading:SetTextColor(0.35,0.9,0.85)
        row.body=text(row); row.body:SetPoint("TOPLEFT",0,-21); row.body:SetWidth(380)
        row.why=text(row,"small"); row.why:SetWidth(380); row.why:SetTextColor(0.7,0.76,0.8)
        row:SetScript("OnEnter",function(self)
            if self.category then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText(AB.L(AB.glossary[self.category]),1,1,1,1,true); if self.source then GameTooltip:AddLine("Skill Capped | "..AB.knowledge.patch.." | "..AB.knowledge.checked,0.4,0.9,0.8,true); GameTooltip:AddLine(self.source.url,1,1,1,true) end; GameTooltip:Show() end
        end)
        row:SetScript("OnLeave",function() GameTooltip:Hide() end)
        UI.rows[i]=row
    end
    UI.attribution=text(content,"small"); UI.attribution:SetWidth(380)
    local settings=button(f,"Settings / teams",125,function() UI.Settings() end); settings:SetPoint("BOTTOMLEFT",12,12)
    local history=button(f,"History",85,function() AB.Review.Show() end); history:SetPoint("BOTTOMLEFT",145,12)
    UI.footer=text(f,"small"); UI.footer:SetPoint("BOTTOMRIGHT",-12,18); UI.Localize(UI.footer,"Pack %s | %s",AB.pack.version,AB.pack.patch)
    f:SetScript("OnDragStop",function(self)
        self:StopMovingOrSizing()
        local point,_,relativePoint,x,y=self:GetPoint()
        AB.db.position={point=point,relativePoint=relativePoint,x=x,y=y}
    end)
    UI.shareButtons={}
    for i, channel in ipairs({"PARTY", "INSTANCE_CHAT"}) do
        local destination=channel
        local b=button(f,channel=="PARTY" and "Send to party" or "Send to instance",195,
            function() AB.Chat.Send(destination) end)
        b:SetPoint("BOTTOMLEFT",12+(i-1)*210,44)
        b:SetScript("OnEnter",function(self)
            local _, reason=AB.Chat.Availability(destination)
            GameTooltip:SetOwner(self,"ANCHOR_TOP"); GameTooltip:SetText(AB.L(reason),1,1,1,1,true); GameTooltip:Show()
        end)
        b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        -- Keep tooltips available when the action is disabled.
        if b.SetMotionScriptsWhileDisabled then b:SetMotionScriptsWhileDisabled(true) end
        UI.shareButtons[channel]=b
    end
    UI.ApplySettings()
    UI.RefreshSharing()
end
function UI.RefreshSharing()
    for channel,b in pairs(UI.shareButtons or {}) do
        local allowed=AB.Chat.Availability(channel)
        b:SetEnabled(allowed)
    end
end
function UI.ApplySettings()
    UI.frame:SetScale(AB.db.scale)
    local p=AB.db.position
    if p then UI.frame:ClearAllPoints(); UI.frame:SetPoint(p.point,UIParent,p.relativePoint,p.x,p.y) end
end
local function roster(ctx, side)
    local names={}
    for i=1,ctx.size do
        local source=ctx.sources and ctx.sources[side][i]
        names[#names+1]=i..". "..AB.SpecLabel(ctx[side][i])..(source=="manual" and AB.L(" [manual]") or "")
    end
    return table.concat(names," / ")
end
function UI.Render(ctx, result, preview)
    UI.status:SetText((preview and AB.L("PREVIEW | ") or "")..AB.L(ctx.mode).." | "..(ctx.complete and AB.L("Composition ready") or AB.L("Partial roster - general guidance where needed")))
    UI.roster:SetText(AB.L("Arena: %s",AB.MapLabel(ctx))..((not AB.maps[ctx.mapID] or not AB.maps[ctx.mapID].terrain) and AB.L(" (general terrain advice)") or "").."\n\n"..AB.L("Your team: %s\n\nOpponents: %s",roster(ctx,"friendly"),roster(ctx,"enemy")))
    local y=UI.roster:GetStringHeight()+20
    for i,r in ipairs(result.recommendations) do
        local row=UI.rows[i]; row.category=r.category; row.source=r.source or false
        row:ClearAllPoints(); row:SetPoint("TOPLEFT",0,-y)
        row.heading:SetText(i.."  "..r.title); row.body:SetText(r.text); row.why:SetText(r.why)
        row.why:ClearAllPoints(); row.why:SetPoint("TOPLEFT",0,-25-row.body:GetStringHeight())
        local height=25+row.body:GetStringHeight()+row.why:GetStringHeight()+20
        row:SetHeight(height); y=y+height
    end
    UI.attribution:ClearAllPoints(); UI.attribution:SetPoint("TOPLEFT",0,-y)
    UI.attribution:SetText(result.review)
    UI.content:SetHeight(y+UI.attribution:GetStringHeight()+20)
    UI.RefreshSharing()
end
function UI.Collapse()
    UI.RefreshSharing()
    if not AB.db.keepVisible then UI.frame:Hide() end
    if UI.settings then UI.settings:Hide() end
end
function UI.Picker(buttonFrame,side,index)
    if not AB.CanEdit() then AB.Print(AB.L("Team selection is available only during preparation or preview.")); return end
    if not MenuUtil or not MenuUtil.CreateContextMenu then AB.Print(AB.L("Use /arenabrief set %s %d SPEC_ID (or auto).",side,index)); return end
    MenuUtil.CreateContextMenu(buttonFrame,function(_,root)
        root:CreateButton(AB.L("Automatic / unknown"),function() AB.SetSpec(side,index,nil) end)
        local classes={}
        for id,s in pairs(AB.specs) do
            classes[s.class]=classes[s.class] or {}; table.insert(classes[s.class],id)
        end
        local names={}; for name in pairs(classes) do names[#names+1]=name end; table.sort(names)
        for _,name in ipairs(names) do
            local child=root:CreateButton(AB.L(name))
            table.sort(classes[name],function(a,b) return AB.specs[a].name < AB.specs[b].name end)
            for _,id in ipairs(classes[name]) do
                local specID=id
                child:CreateButton(AB.L(AB.specs[specID].name),function() AB.SetSpec(side,index,specID) end)
            end
        end
    end)
end
function UI.RefreshSelectors()
    if not UI.selectors then return end
    for _,entry in ipairs(UI.selectors) do
        local id=AB.manual[entry.side][entry.index]
        entry.button:SetText(id and AB.SpecLabel(id) or AB.L("Automatic / unknown"))
        entry.button:SetEnabled(AB.CanEdit() and (not AB.context or entry.index<=AB.context.size))
    end
end
function UI.Settings()
    if InCombatLockdown() then AB.Print(AB.L("Open settings outside combat.")); return end
    if not UI.settings then
        local f=window("ArenaBriefingSettings",420,570); UI.settings=f
        local title=text(f); title:SetPoint("TOPLEFT",16,-16); UI.Localize(title,"Arena Briefing settings")
        local check=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); check:SetPoint("TOPLEFT",12,-45)
        local label=text(f); label:SetPoint("LEFT",check,"RIGHT",3,0); UI.Localize(label,"Keep briefing visible during combat")
        check:SetChecked(AB.db.keepVisible); check:SetScript("OnClick",function(self) AB.db.keepVisible=self:GetChecked() == true end)
        local english=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); english:SetPoint("TOPLEFT",12,-79)
        UI.englishCheck=english
        local englishLabel=text(f,"small"); englishLabel:SetPoint("LEFT",english,"RIGHT",3,0); englishLabel:SetWidth(350)
        UI.Localize(englishLabel,"Use English (including team messages)")
        english:SetScript("OnClick",function(self)
            AB.SetEnglish(self:GetChecked()==true); self:SetChecked(AB.db.forceEnglish)
        end)
        local scale=button(f,function() return AB.L("Scale: ")..AB.db.scale end,130,function(self)
            AB.db.scale=AB.db.scale>=1.4 and 0.8 or math.floor((AB.db.scale+0.1)*10+0.5)/10
            UI.ApplySettings(); self:SetText(AB.L("Scale: ")..AB.db.scale)
        end); scale:SetPoint("TOPLEFT",16,-125)
        local reset=button(f,"Reset position",130,function() AB.db.position=nil; UI.frame:ClearAllPoints(); UI.frame:SetPoint("CENTER") end); reset:SetPoint("LEFT",scale,"RIGHT",12,0)
        local help=text(f,"small"); help:SetPoint("TOPLEFT",16,-166); help:SetWidth(380)
        UI.Localize(help,"Choose missing specs before the gates open. Your team slot 1 is you; slots 2-3 are party1-2. Enemy slots are arena1-3. Choices reset each round.")
        UI.selectors={}
        local y=228
        for _,side in ipairs({"friendly","enemy"}) do
            for i=1,3 do
                local sideKey,slot=side,i
                local l=text(f,"small"); l:SetPoint("TOPLEFT",16,-y-5); UI.Localize(l,function() return AB.L(sideKey=="friendly" and "Your team " or "Enemy ")..slot end)
                local b=button(f,"Automatic / unknown",270,function(self) UI.Picker(self,sideKey,slot) end); b:SetPoint("TOPLEFT",125,-y)
                UI.selectors[#UI.selectors+1]={button=b,side=side,index=i}; y=y+34
            end
            y=y+10
        end
        local preview=button(f,"Preview",105,function() AB.Preview("3v3") end); preview:SetPoint("BOTTOMLEFT",16,55)
        local debug=button(f,"Diagnostics",110,function() AB.ToggleDebug() end); debug:SetPoint("LEFT",preview,"RIGHT",12,0)
        local note=text(f,"small"); note:SetPoint("BOTTOMLEFT",16,16); note:SetWidth(380)
        UI.Localize(note,"General strategy suggestions, not live calls.\nStrategy pack %s / %s - expert review pending.",AB.pack.version,AB.pack.patch)
    end
    UI.englishCheck:SetChecked(AB.db.forceEnglish)
    UI.RefreshSelectors(); UI.settings:Show()
end
