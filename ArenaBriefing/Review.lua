local _, AB = ...
AB.Review={index=1,roundIndex=1}
local R=AB.Review
local function value(v) return v~=nil and tostring(v) or AB.L("Unavailable") end
local outcomes={win="Win",loss="Loss",unknown="Unknown"}
local statuses={recording="In progress",complete="Complete",interrupted="Incomplete recording"}
local function label(parent,text,x,y)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y); f:SetWidth(490); f:SetJustifyH("LEFT"); f:SetJustifyV("TOP"); f:SetText(text)
    return f
end
local function button(parent,text,x,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetSize(120,24); b:SetPoint("BOTTOMLEFT",x,12); AB.UI.Localize(b,text); b:SetScript("OnClick",fn); return b
end
function R.Create()
    if R.frame then return end
    local f=CreateFrame("Frame","ArenaBriefingReview",UIParent,"BackdropTemplate"); R.frame=f
    f:SetSize(550,600); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile="Interface/Buttons/WHITE8X8",edgeFile="Interface/Buttons/WHITE8X8",edgeSize=1})
    f:SetBackdropColor(0.035,0.055,0.075,0.97); f:SetBackdropBorderColor(0.2,0.65,0.7,1)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart",function(self) if AB.API.Safe(InCombatLockdown)==false then self:StartMoving() end end)
    f:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT",-2,-2)
    AB.UI.Localize(label(f,"",16,-16),"Match history & review")
    local scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",16,-50); scroll:SetPoint("BOTTOMRIGHT",-32,50)
    local content=CreateFrame("Frame",nil,scroll); content:SetSize(490,900); scroll:SetScrollChild(content)
    R.content=content; R.text=label(content,"",0,0)
    R.newer=button(f,"Newer",12,function() R.index=math.max(1,R.index-1); R.roundIndex=1; R.Select() end)
    R.older=button(f,"Older",142,function() R.index=math.min(#AB.History.db.records,R.index+1); R.roundIndex=1; R.Select() end)
    R.roundButton=button(f,"Next round",272,function()
        if R.selected then R.roundIndex=R.roundIndex%math.max(1,#R.selected.rounds)+1; R.Render() end
    end)
    R.auto=CreateFrame("CheckButton",nil,f,"UICheckButtonTemplate"); R.auto:SetPoint("TOPRIGHT",-150,-12)
    local autoText=R.auto:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); autoText:SetPoint("LEFT",R.auto,"RIGHT",0,0); AB.UI.Localize(autoText,"Auto-open")
    R.auto:SetScript("OnClick",function(self) AB.db.autoReview=self:GetChecked()==true end)
end
function R.Hide() R.pending=nil; if R.frame then R.frame:Hide() end end
function R.Select()
    R.selected=AB.History.db.records[R.index]; R.Render()
end
function R.Render()
    if not R.text then return end
    R.auto:SetChecked(AB.db.autoReview)
    local record=R.selected
    if not record then R.text:SetText(AB.L("No matches recorded yet. Play an arena match to start your history.")); R.content:SetHeight(100)
    else
        local round=record.rounds[R.roundIndex]
        local ctx=round and round.context or record.context
        local lines={AB.L("Match %d of %d",R.index,#AB.History.db.records),
            AB.L("Status: %s | Result: %s",AB.L(statuses[record.status] or "Unknown"),AB.L(outcomes[record.outcome] or "Unknown"))}
        if record.timestamp then lines[#lines+1]=AB.L("Recorded: %s",date and date("%Y-%m-%d %H:%M",record.timestamp) or tostring(record.timestamp)) end
        if ctx then
            lines[#lines+1]=AB.L("Arena: %s",AB.MapLabel(ctx)).." | "..AB.L(ctx.mode)
            for _,side in ipairs({"friendly","enemy"}) do
                local names={}
                for i=1,ctx.size do
                    names[#names+1]=AB.SpecLabel(ctx[side][i])..(ctx.sources and ctx.sources[side][i]=="manual" and AB.L(" [manual]") or "")
                end
                lines[#lines+1]=AB.L(side=="friendly" and "Your team " or "Enemy ")..table.concat(names," / ")
            end
        else lines[#lines+1]=AB.L("Preparation context unavailable (joined or reloaded mid-fight).") end
        lines[#lines+1]=AB.L("Session duration: %s seconds",value(record.duration))
        lines[#lines+1]=AB.L("Observed round %d of %d | observed duration: %s seconds",R.roundIndex,#record.rounds,value(round and round.observedDuration and math.floor(round.observedDuration)))
        lines[#lines+1]=AB.L("Round outcomes are unavailable; session totals are not individual-round statistics.")
        lines[#lines+1]="\n"..AB.L("Your final scoreboard totals (whole session)")
        local stats=record.stats or {}
        for _,item in ipairs({{"damageDone","Damage"},{"healingDone","Healing"},{"deaths","Deaths"},{"killingBlows","Killing blows"},{"ratingChange","Rating change"}}) do
            lines[#lines+1]=AB.L(item[2])..": "..value(stats[item[1]])
        end
        lines[#lines+1]="\n"..AB.L("Review prompts")
        for _,prompt in ipairs(AB.History.Prompts(record,round)) do lines[#lines+1]="- "..prompt end
        if round and round.briefing then
            lines[#lines+1]="\n"..AB.L("Original briefing (saved language)").." | "..round.briefing.packVersion
            for _,r in ipairs(round.briefing.recommendations) do lines[#lines+1]=r.title..": "..r.text..(r.source and ("\nSkill Capped: "..r.source.url) or "") end
        end
        R.text:SetText(table.concat(lines,"\n\n")); R.content:SetHeight(R.text:GetStringHeight()+20)
    end
    R.newer:SetEnabled(R.index>1); R.older:SetEnabled(R.index<#AB.History.db.records)
    R.roundButton:SetEnabled(record~=nil and #record.rounds>1)
end
function R.Show(record)
    if AB.API.Safe(InCombatLockdown)~=false then AB.Print(AB.L("Open match history outside combat.")); return end
    R.Create(); R.index=1; R.roundIndex=1
    if record then for i,r in ipairs(AB.History.db.records) do if r==record then R.index=i; break end end end
    R.Select(); R.frame:Show()
end
function R.AutoOpen(record)
    if AB.db.autoReview then
        if AB.API.Safe(InCombatLockdown)==false then R.Show(record) else R.pending=record end
    end
end
