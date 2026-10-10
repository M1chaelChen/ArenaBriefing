local _, AB = ...
AB.Chat = {}
local Chat = AB.Chat
local cooldown = 10
local function sender()
    return C_ChatInfo and C_ChatInfo.SendChatMessage or SendChatMessage
end
function Chat.Availability(channel)
    if channel ~= "PARTY" and channel ~= "INSTANCE_CHAT" then return false, "Unsupported team channel." end
    if not AB.context or not AB.result or AB.preview or AB.phase ~= "prep"
        or not AB.API.InArena() or not AB.API.IsPreparing(AB.API.State())
        or AB.API.Safe(InCombatLockdown) ~= false then
        return false, "Share a live briefing during arena preparation. Previews cannot be sent."
    end
    local category = channel == "PARTY" and (LE_PARTY_CATEGORY_HOME or 1) or (LE_PARTY_CATEGORY_INSTANCE or 2)
    if AB.API.Safe(IsInGroup, category) ~= true
        or (channel == "PARTY" and AB.API.Safe(IsInRaid, category) == true) then
        return false, channel == "PARTY" and "No home party is available." or "No instance group is available."
    end
    if type(sender()) ~= "function" then return false, "Team chat is unavailable in this client." end
    local now = AB.API.Safe(GetTime)
    if not now then return false, "Team chat is unavailable in this client." end
    if Chat.lastAttempt and now - Chat.lastAttempt < cooldown then return false, "Wait 10 seconds between shares." end
    return true, "Send the briefing and source note to this channel. Explanations stay in your panel."
end
-- Chat limits are bytes, not characters. Cut only at a UTF-8 boundary.
local function fit(text)
    text = text:gsub("[\r\n]", " "):gsub("|", "")
    if #text <= 255 then return text end
    local cut = 252
    while cut > 0 do
        local nextByte = text:byte(cut + 1)
        if not nextByte or nextByte < 128 or nextByte >= 192 then break end
        cut = cut - 1
    end
    return text:sub(1, cut) .. "..."
end
function Chat.Lines(result)
    local prefix = AB.L("[Arena Briefing] ")
    if not result.complete then prefix = AB.L("[Arena Briefing: partial roster] ") end
    local lines = {}
    for i, r in ipairs(result.recommendations) do
        if i > 5 then break end
        local map = i == 1 and result.mapID and AB.maps[result.mapID]
        local title = map and (r.title .. " (" .. AB.L(map.name) .. ")") or r.title
        lines[#lines + 1] = fit(prefix .. title .. ": " .. r.text)
    end
    if result.review then lines[#lines + 1] = fit(prefix .. result.review) end
    return lines
end
function Chat.Send(channel)
    local allowed, reason = Chat.Availability(channel)
    if not allowed then AB.Print(AB.L(reason)); return false end
    -- Use only the currently displayed result; do not re-evaluate or queue messages.
    local lines = Chat.Lines(AB.result)
    Chat.lastAttempt = AB.API.Safe(GetTime)
    for _, line in ipairs(lines) do
        local ok = pcall(sender(), line, channel)
        if not ok then
            AB.Print(AB.L("Chat submission failed; some lines may already have been sent."))
            if AB.UI.RefreshSharing then AB.UI.RefreshSharing() end
            return false
        end
    end
    if AB.UI.RefreshSharing then AB.UI.RefreshSharing() end
    return true
end
