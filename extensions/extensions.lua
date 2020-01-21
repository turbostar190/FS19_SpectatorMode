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

-- Bad workaround to fix 'positionSmoothingParameter' > 0 in indoor pickup cameras
-- VehicleCamera.lua
function SMUtils.fixPosSmoothParameterCamera(c, match)
    print(string.format("Spectator Mode: fixing 'positionSmoothingParameter' on '%s'", match))
    --print(string.format("cameraNode %s cameraPositionNode %s rotateNode %s", tostring(c.cameraNode), tostring(c.cameraPositionNode), tostring(c.rotateNode)))

    if c.isInside then
        c.positionSmoothingParameter = 0.128 -- 0.095
        c.lookAtSmoothingParameter = 0.176 -- 0.12
    else
        c.positionSmoothingParameter = 0.016
        c.lookAtSmoothingParameter = 0.022
    end

    -- create a node which indicates the target position of the camera
    c.cameraPositionNode = createTransformGroup("cameraPositionNode")
    local camIndex = getChildIndex(c.cameraNode)
    link(getParent(c.cameraNode), c.cameraPositionNode, camIndex)
    local x, y, z = getTranslation(c.cameraNode)
    local rx, ry, rz = getRotation(c.cameraNode)
    setTranslation(c.cameraPositionNode, x, y, z)
    setRotation(c.cameraPositionNode, rx, ry, rz)

    unlink(c.cameraNode)
    --print(string.format("cameraNode %s cameraPositionNode %s rotateNode %s", tostring(c.cameraNode), tostring(c.cameraPositionNode), tostring(c.rotateNode)))

    if c.rotateNode == nil or c.rotateNode == c.cameraNode then
        c.rotateNode = c.cameraPositionNode
    end
    --print(string.format("cameraNode %s cameraPositionNode %s rotateNode %s", tostring(c.cameraNode), tostring(c.cameraPositionNode), tostring(c.rotateNode)))

    c.origRotX, c.origRotY, c.origRotZ = getRotation(c.rotateNode)
    c.rotX = c.origRotX
    c.rotY = c.origRotY
    c.rotZ = c.origRotZ

    c.origTransX, c.origTransY, c.origTransZ = getTranslation(c.cameraPositionNode)
    c.transX = c.origTransX
    c.transY = c.origTransY
    c.transZ = c.origTransZ

    local transLength = MathUtil.vector3Length(c.origTransX, c.origTransY, c.origTransZ) + 0.00001 -- prevent division by zero
    c.zoom = transLength
    c.zoomTarget = transLength
    c.zoomLimitedTarget = -1

    local trans1OverLength = 1.0 / transLength
    c.transDirX = trans1OverLength * c.origTransX
    c.transDirY = trans1OverLength * c.origTransY
    c.transDirZ = trans1OverLength * c.origTransZ

    table.insert(c.raycastNodes, c.rotateNode)

    local sx, sy, sz = getScale(c.cameraNode)
    if sx ~= 1 or sy ~= 1 or sz ~= 1 then
        --g_logManager:xmlWarning(self.vehicle.configFileName, "Vehicle camera with scale found for camera '%s'. Resetting to scale 1", key)
        setScale(c.cameraNode, 1, 1, 1)
    end

    --TODO: Non è più sincronizzata il movimento della camera remota

    --print(string.format("cameraNode %s cameraPositionNode %s rotateNode %s", tostring(c.cameraNode), tostring(c.cameraPositionNode), tostring(c.rotateNode)))
    --DebugUtil.printTableRecursively(self.spec_enterable.cameras, " ", 0, 3)
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
