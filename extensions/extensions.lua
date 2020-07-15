--
-- SpectatorMode
--
-- @author TyKonKet
-- @date 03/01/2017

SMUtils = {}

-- Thanks to Jos
-- Ripped from Seasons
function SMUtils.mergeI18N(i18n)
    -- We can copy all our translations to the global table because we prefix everything with SM_
    -- The mod-based l10n lookup only really works for vehicles, not UI and script mods.
    local global = getfenv(0).g_i18n.texts
    for key, text in pairs(i18n.texts) do
        global[key] = text
    end
end

-- Taken from AutoDrive
function SMUtils.renderTable(posX, posY, textSize, inputTable, maxDepth)
    maxDepth = maxDepth or 2
    local function renderTableRecursively(posX, posY, textSize, inputTable, depth, maxDepth, i)
        if depth >= maxDepth then
            return i
        end
        for k, v in pairs(inputTable) do
            local offset = i * textSize * 1.05
            setTextAlignment(RenderText.ALIGN_RIGHT)
            renderText(posX, posY - offset, textSize, tostring(k) .. " :")
            setTextAlignment(RenderText.ALIGN_LEFT)
            if type(v) ~= "table" then
                renderText(posX, posY - offset, textSize, " " .. tostring(v))
            end
            i = i + 1
            if type(v) == "table" then
                i = renderTableRecursively(posX + textSize * 2, posY, textSize, v, depth + 1, maxDepth, i)
            end
        end
        return i
    end
    local i = 0
    setTextColor(1, 1, 1, 1)
    setTextBold(false)
    textSize = getCorrectTextSize(textSize)
    for k, v in pairs(inputTable) do
        local offset = i * textSize * 1.05
        setTextAlignment(RenderText.ALIGN_RIGHT)
        renderText(posX, posY - offset, textSize, tostring(k) .. " :")
        setTextAlignment(RenderText.ALIGN_LEFT)
        if type(v) ~= "table" then
            renderText(posX, posY - offset, textSize, " " .. tostring(v))
        end
        i = i + 1
        if type(v) == "table" then
            i = renderTableRecursively(posX + textSize * 2, posY, textSize, v, 1, maxDepth, i)
        end
    end
end

-- Event methods extensions
function Event.sendToServer(event)
    g_client:getServerConnection():sendEvent(event)
end

-- Utils methods extensions
function Utils.getNumBits(range)
    return math.min(math.max(math.ceil(math.log(range, 2)), 1), 31)
end

-- g_currentMission extensions
function FSBaseMission:findUserByNickname(nickname)
    for _, user in ipairs(self.userManager.users) do
        if user.nickname == nickname then
            return user
        end
    end
    return nil
end

function FSBaseMission:getPlayerByName(name)
    for _, v in pairs(g_currentMission.players) do
        if v.visualInformation.playerName == name then
            return v
        end
    end
    return nil
end
