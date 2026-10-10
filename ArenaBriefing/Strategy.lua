local _, AB = ...
AB.providers = {}
function AB.RegisterProvider(name, provider)
    assert(type(name) == "string" and type(provider) == "function", "Invalid strategy provider")
    AB.providers[name] = provider
end
local order = {"target", "opening", "cc", "threats", "positioning"}
local titles = {target="Suggested target",opening="Opening plan",cc="Crowd control",threats="Major threats",positioning="Positioning"}
local function bundled(ctx)
    local slots, matched = {}, {}
    local function offer(category, priority, id, text, why, sourceID)
        local old = slots[category]
        if not old or priority > old.priority then
            slots[category] = {category=category,title=AB.L(titles[category]),priority=priority,ruleID=id,text=AB.L(text),why=AB.L(why),sourceID=sourceID,source=sourceID and AB.knowledge.sources[sourceID] or nil}
        end
    end
    offer("target",0,"general.target","Agree on one accessible opponent.","Shared pressure is more useful than splitting damage; don't chase out of healing range.")
    offer("opening",0,"general.opening","Wait until your team is ready before committing.","An isolated opener makes it harder for your teammates to help.")
    offer("cc",0,"general.cc","Control an opponent away from your team's target.","Coordinate control instead of overlapping effects that shorten each other.")
    offer("threats",0,"general.threats","Keep a defensive answer for the enemy's opening pressure.","Use a defensive before falling too far behind; avoid spending everything together.")
    offer("positioning",0,"general.positioning","Keep a clear route to your healer or partner.","Pillars can block enemy spells, but they also block friendly healing.")
    local own = AB.specs[ctx.playerSpec]
    if own then
        local p = AB.personal[own.role == "damage" and own.style or own.role]
        offer("opening",10,"player."..own.id,p[1],p[2])
    end
    local healer, melee, caster, damage, enemyKnown = nil,0,0,0,0
    local rogue, mage, warlock = false,false,false
    for i=1,ctx.size do
        local id = (ctx.enemy or {})[i]
        local s = AB.specs[id]
        if s then
            enemyKnown = enemyKnown + 1
            if s.role == "healer" then healer = healer or i end
            if s.role == "damage" then
                damage = damage + 1
                if s.style == "melee" then melee = melee + 1 end
                if s.style == "caster" then caster = caster + 1 end
            end
            rogue = rogue or s.class == "Rogue"
            mage = mage or s.class == "Mage"
            warlock = warlock or s.class == "Warlock"
        end
    end
    -- Only make team-composition claims when every enemy slot is known.
    if enemyKnown == ctx.size then
        if healer then
            offer("cc",20,"enemy.healer",AB.L("Control %s during shared pressure.",AB.SpecLabel(ctx.enemy[healer])),"Time control with your partner's damage; don't abandon safe positioning just to land it.")
        else
            offer("threats",20,"enemy.healerless","Expect a fast exchange against a team without a healer.","Preserve health early and avoid trading all your defensive tools for a small damage gain.")
        end
        if melee >= 2 then
            offer("positioning",20,"pattern.melee","Avoid stacking where both melee opponents can hit your team.","Draw pressure toward cover your healer can use, and help a focused teammate create distance.")
        elseif caster >= 2 then
            offer("positioning",20,"pattern.casters","Use a pillar to limit simultaneous enemy casts.","Move out with your partner for pressure, then return to cover without cutting off your healer.")
        elseif melee > 0 and damage > melee then
            offer("positioning",20,"pattern.mixed","Separate the melee's chase from their ranged partner's sightline.","Use terrain to reduce coordinated pressure while staying reachable by your own team.")
        end
        if rogue and mage then
            offer("threats",30,"matchup.rogue-mage","Plan who answers the first coordinated control-and-damage attempt.","Avoid both teammates spending escape tools on the same setup; recover position together afterward.")
        elseif warlock then
            offer("threats",10,"enemy.warlock","Don't let a chase pull your team far from cover.","Choose pressure windows together; sustained exposure gives the enemy more time to cast.")
        end
    end
    local friendlyKnown, friendlyHealer = 0, false
    for i=1,ctx.size do
        local s = AB.specs[(ctx.friendly or {})[i]]
        if s then friendlyKnown=friendlyKnown+1; friendlyHealer=friendlyHealer or s.role=="healer" end
    end
    if friendlyKnown == ctx.size and not friendlyHealer then
        offer("opening",40,"friendly.healerless","Coordinate an early pressure window, with a route to retreat.","Without a dedicated healer, prolonged open-field trades are costly; protect each other during recovery.")
        offer("positioning",40,"friendly.healerless-position","Keep cover and a retreat route available to both teammates.","Reset together when pressure fails; don't leave a partner isolated.")
        offer("target",40,"friendly.healerless-target","Pressure one reachable damage dealer together.","Agree on the target before opening; don't trade your escape route for a chase.")
    end
    AB.ApplyKnowledge(ctx,offer)
    local mapText,mapRule = AB.MapPosition(ctx,{
        own=own,enemyKnown=enemyKnown==ctx.size,melee=melee,caster=caster,
        healerless=friendlyKnown==ctx.size and not friendlyHealer,
    })
    if mapText then
        local previous=slots.positioning
        offer("positioning",50,mapRule,mapText,previous.text.." "..previous.why)
    end
    local recommendations = {}
    for _, category in ipairs(order) do
        recommendations[#recommendations+1] = slots[category]
        matched[#matched+1] = slots[category].ruleID
    end
    return {mapID=ctx.mapID,mapLabel=AB.MapLabel(ctx),recommendations=recommendations,matchedRuleIDs=matched,packVersion=AB.pack.version,
        patch=AB.pack.patch,review=AB.L(AB.KnowledgeStatus(ctx)),complete=ctx.complete == true,provider="bundled"}
end
AB.RegisterProvider("bundled", bundled)
function AB.Evaluate(context, provider)
    return (AB.providers[provider or "bundled"] or AB.providers.bundled)(context)
end
