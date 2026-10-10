local _, AB = ...
-- Curated summaries of public references, not an API feed or endorsed product.
AB.knowledge = {
    checked="2026-10-03", patch="12.1", publisher="Skill Capped",
    sources={
        targets={title="Best Targets - Solo Shuffle Guide",url="https://www.skill-capped.com/wowarticles/general/best-targets/",scope="Solo Shuffle",published="2025-12-24"},
        counters={title="How to Counter Every Class in WoW PvP",url="https://www.skill-capped.com/wowarticles/general/class-ability-counters/",scope="Arena / Solo Shuffle",published="2026-06-04"},
    },
    -- Membership only: the guide does not establish an ordering within these groups.
    generalTargets={[251]=true,[252]=true,[263]=true,[71]=true,[72]=true,[253]=true,[254]=true,[255]=true},
    meleeTargets={[265]=true,[266]=true,[267]=true,[258]=true,[102]=true,[103]=true},
    counters={
        Warrior="Deny Warrior burst uptime with roots or cover.",
        Mage="Plan offensive dispels against Mage protection and Alter Time.",
        Druid="Disrupt Cyclone; avoid giving the Druid repeated control.",
        Warlock="Contest Chaos Bolt or Unstable Affliction casts when present.",
        Rogue="Coordinate stun pressure after the Rogue spends their trinket.",
        Monk="Spread so Leg Sweep cannot catch multiple teammates.",
    },
}
for _,source in pairs(AB.knowledge.sources) do source.patch=AB.knowledge.patch; source.checked=AB.knowledge.checked end
function AB.KnowledgeStatus(ctx)
    if ctx.clientVersion and not ctx.clientVersion:match("^12%.1%.") then return "Source patch differs; general rules only" end
    return "Skill Capped references + general rules; not endorsed"
end
function AB.ApplyKnowledge(ctx,offer)
    if ctx.clientVersion and not ctx.clientVersion:match("^12%.1%.") then return end
    local own=AB.specs[ctx.playerSpec]
    local complete=true
    local classes={}
    for i=1,ctx.size do
        local spec=AB.specs[ctx.enemy[i]]
        if not spec then complete=false
        elseif spec.role~="tank" then classes[spec.class]=true end
    end
    if ctx.mode=="Solo Shuffle" and complete and own and own.role=="damage" then
        if own.style=="caster" then
            offer("target",55,"sc.targets.caster","Pressure an exposed enemy; switch when their position denies your casts.",
                "A pre-match principle, not a prediction of enemy positioning.","targets")
        else
            local candidates,seen={},{}
            for i=1,ctx.size do
                local id=ctx.enemy[i]
                if not seen[id] and (AB.knowledge.generalTargets[id] or (own.style=="melee" and AB.knowledge.meleeTargets[id])) then
                    candidates[#candidates+1]=id; seen[id]=true
                end
            end
            table.sort(candidates) -- stable display, not a vulnerability score
            local names={}; for _,id in ipairs(candidates) do names[#names+1]=AB.SpecLabel(id) end
            if #names>0 then
                offer("target",55,"sc.targets.candidates",AB.L("Discuss %s; choose by reachability.",table.concat(names," / ")),
                    "Candidates are unranked; agree with your partner before committing.","targets")
            end
        end
    end
    local tips={}
    local ordered={}; for class in pairs(classes) do ordered[#ordered+1]=class end; table.sort(ordered)
    for _,class in ipairs(ordered) do
        if AB.knowledge.counters[class] and #tips<2 then tips[#tips+1]=AB.L(AB.knowledge.counters[class]) end
    end
    if #tips>0 then
        offer("threats",15,"sc.counters",table.concat(tips," "),
            "Plan with available abilities; no talents or cooldown states are assumed.","counters")
    end
    if classes.Druid then
        offer("cc",25,"sc.counters.cyclone","Reserve a stop for Cyclone if the enemy uses it.",
            "Coordinate who stops it rather than spending both interrupts together.","counters")
    elseif classes.Warlock then
        local affliction,destruction=false,false
        for _,id in ipairs(ctx.enemy) do affliction=affliction or id==265; destruction=destruction or id==267 end
        if affliction or destruction then
            offer("cc",25,"sc.counters.warlock",affliction and "Plan to interrupt Unstable Affliction." or "Plan to interrupt Chaos Bolt.",
                "This is an interrupt-planning prompt, not a live cast alert.","counters")
        end
    end
end
