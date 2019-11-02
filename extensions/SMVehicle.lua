--- Vehicles specialization
-- Spectator Mode
--
-- @author *TurboStar*
-- @date 01/09/2019

SMVehicle = {}

function SMVehicle.prerequisitesPresent(specializations)
    return SpecializationUtil.hasSpecialization(Enterable, specializations)
end

function SMVehicle.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "getVehIsSpectated", SMVehicle.getVehIsSpectated)
end

function SMVehicle.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "drawUIInfo", SMVehicle.drawUIInfo)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "addToolCameras", SMVehicle.addToolCameras)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "removeToolCameras", SMVehicle.removeToolCameras)
end

function SMVehicle.registerEventListeners(vehicleType)
    local events = { "onPostLoad",
        --"onUpdateInterpolation",
                     "onUpdate",
                     "onReadUpdateStream",
                     "onWriteUpdateStream",
                     "onCameraChanged",
                     "onAIStart",
                     "onAIEnd" }
    for _, event in pairs(events) do
        SpecializationUtil.registerEventListener(vehicleType, event, SMVehicle)
    end
end

local function isMultiplayer()
    return g_currentMission.missionDynamicInfo.isMultiplayer
end

function SMVehicle:onPostLoad(savegame)
    if not isMultiplayer() then return end
    local spec = self:spectatorMode_getSpecTable()

    spec.camerasLerp = {}
    for _, v in pairs(self.spec_enterable.cameras) do
        spec.camerasLerp[v.cameraNode] = {}
        spec.camerasLerp[v.cameraNode].lastQuaternion = { 0, 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].targetQuaternion = { 0, 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].lastTranslation = { 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].targetTranslation = { 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].interpolationAlpha = 1
        spec.camerasLerp[v.cameraNode].skipNextInterpolationAlpha = false
    end
end

-- https://gdn.giants-software.com/documentation_scripting_fs19.php?version=script&category=69&class=10618#update168138
function SMVehicle:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    local isControlled = self.getIsControlled ~= nil and self:getIsControlled()
    if not isMultiplayer() or not isControlled then return end

    local spec = self:spectatorMode_getSpecTable()
    local specE = self.spec_enterable

    if not specE.isEntered then
        for _, v in pairs(specE.cameras) do
            spec.camerasLerp[v.cameraNode].interpolationAlpha = spec.camerasLerp[v.cameraNode].interpolationAlpha + g_physicsDtUnclamped / self.networkTimeInterpolator.interpolationDuration
            if spec.camerasLerp[v.cameraNode].interpolationAlpha > 1.2 then
                spec.camerasLerp[v.cameraNode].interpolationAlpha = 1.2
            end
            local rx, ry, rz, rw = MathUtil.nlerpQuaternionShortestPath(
                    spec.camerasLerp[v.cameraNode].lastQuaternion[1],
                    spec.camerasLerp[v.cameraNode].lastQuaternion[2],
                    spec.camerasLerp[v.cameraNode].lastQuaternion[3],
                    spec.camerasLerp[v.cameraNode].lastQuaternion[4],
                    spec.camerasLerp[v.cameraNode].targetQuaternion[1],
                    spec.camerasLerp[v.cameraNode].targetQuaternion[2],
                    spec.camerasLerp[v.cameraNode].targetQuaternion[3],
                    spec.camerasLerp[v.cameraNode].targetQuaternion[4],
                    spec.camerasLerp[v.cameraNode].interpolationAlpha
            )
            if rx == rx and ry == ry and rz == rz and rw == rw then
                setQuaternion(v.rotateNode, rx, ry, rz, rw)
            end
            if v.isInside then
                setTranslation(v.cameraPositionNode, spec.camerasLerp[v.cameraNode].targetTranslation[1], spec.camerasLerp[v.cameraNode].targetTranslation[2], spec.camerasLerp[v.cameraNode].targetTranslation[3])
            else
                local tx, ty, tz = MathUtil.vector3Lerp(
                        spec.camerasLerp[v.cameraNode].lastTranslation[1],
                        spec.camerasLerp[v.cameraNode].lastTranslation[2],
                        spec.camerasLerp[v.cameraNode].lastTranslation[3],
                        spec.camerasLerp[v.cameraNode].targetTranslation[1],
                        spec.camerasLerp[v.cameraNode].targetTranslation[2],
                        spec.camerasLerp[v.cameraNode].targetTranslation[3],
                        spec.camerasLerp[v.cameraNode].interpolationAlpha
                )
                if tx == tx and ty == ty and tz == tz then
                    setTranslation(v.cameraPositionNode, tx, ty, tz)
                end
            end
            if v.rotateNode ~= v.cameraPositionNode then
                local wtx, wty, wtz = getWorldTranslation(v.cameraPositionNode)
                local dx = wtx
                local dy = wty
                local dz = wtz
                wtx, wty, wtz = getWorldTranslation(v.rotateNode)
                dx = dx - wtx
                dy = dy - wty
                dz = dz - wtz
                local upx, upy, upz = 0, 1, 0
                if math.abs(dx) < 0.001 and math.abs(dz) < 0.001 then
                    upx = 0.1
                end
                if math.abs(dx) > 0.0001 and math.abs(dy) > 0.0001 and math.abs(dz) > 0.0001 then
                    setDirection(v.cameraNode, dx, dy, dz, upx, upy, upz)
                end
            else
                local wrx, wry, wrz, wrw = getWorldQuaternion(v.rotateNode)
                setQuaternion(v.cameraNode, wrx, wry, wrz, wrw)
            end
            local wtx, wty, wtz = getWorldTranslation(v.cameraPositionNode)
            setTranslation(v.cameraNode, wtx, wty, wtz)
        end
    end

    --TODO: Con AI inserita e guardata a piedi attraverso la spectator lo sterzo non ruota. Dovrebbe esserci una soluzione nella passenger mod
    -- This is needed as the Drivable.lua only shows this for the person who is the vehicle.
    if self.spec_drivable ~= nil and self:getIsAIActive() then
        self:doSteeringWheelUpdate(self.spec_drivable.steeringWheel, dt, 1) -- TODO: Test
    end
    self:raiseActive() -- ??
end

function SMVehicle:doSteeringWheelUpdate(steeringWheel, dt, direction)
    if steeringWheel ~= nil then
        local maxRotation = steeringWheel.outdoorRotation
        local activeCamera = self.spec_enterable.activeCamera
        if activeCamera ~= nil and activeCamera.isInside then
            maxRotation = steeringWheel.indoorRotation
        end

        if self.rotatedTime == nil then
            self.rotatedTime = 0
        end

        local rotation = self.rotatedTime * maxRotation
        if steeringWheel.lastRotation ~= rotation then
            steeringWheel.lastRotation = rotation
            setRotation(steeringWheel.node, 0, rotation * direction, 0)
        end
    end
end

function SMVehicle:onWriteUpdateStream(streamId, connection)
    if not isMultiplayer() then return end

    --if not connection:getIsServer() then
    local spec = self:spectatorMode_getSpecTable()
    local specE = self.spec_enterable
    if self.isServer and not specE.isEntered then
        for _, v in pairs(specE.cameras) do
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetQuaternion[1])
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetQuaternion[2])
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetQuaternion[3])
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetQuaternion[4])
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetTranslation[1])
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetTranslation[2])
            streamWriteFloat32(streamId, spec.camerasLerp[v.cameraNode].targetTranslation[3])
        end
    else
        for _, v in pairs(specE.cameras) do
            local x, y, z, w = getQuaternion(v.rotateNode)
            streamWriteFloat32(streamId, x)
            streamWriteFloat32(streamId, y)
            streamWriteFloat32(streamId, z)
            streamWriteFloat32(streamId, w)
            x, y, z = getTranslation(v.cameraPositionNode)
            streamWriteFloat32(streamId, x)
            streamWriteFloat32(streamId, y)
            streamWriteFloat32(streamId, z)
        end
    end
    --end
end

function SMVehicle:onReadUpdateStream(streamId, timestamp, connection)
    if not isMultiplayer() then return end

    --if connection:getIsServer() then
    local spec = self:spectatorMode_getSpecTable()
    for _, v in pairs(self.spec_enterable.cameras) do
        local x, y, z, w, tx, ty, tz = 0
        x = streamReadFloat32(streamId)
        y = streamReadFloat32(streamId)
        z = streamReadFloat32(streamId)
        w = streamReadFloat32(streamId)
        tx = streamReadFloat32(streamId)
        ty = streamReadFloat32(streamId)
        tz = streamReadFloat32(streamId)
        spec.camerasLerp[v.cameraNode].lastQuaternion = { getQuaternion(v.rotateNode) }
        spec.camerasLerp[v.cameraNode].targetQuaternion = { x, y, z, w }
        spec.camerasLerp[v.cameraNode].lastTranslation = { getTranslation(v.cameraPositionNode) }
        spec.camerasLerp[v.cameraNode].targetTranslation = { tx, ty, tz }
        spec.camerasLerp[v.cameraNode].interpolationAlpha = 0
        if spec.camerasLerp[v.cameraNode].skipNextInterpolationAlpha then
            spec.camerasLerp[v.cameraNode].interpolationAlpha = 1
            spec.camerasLerp[v.cameraNode].skipNextInterpolationAlpha = false
        end
    end
    --end
end

-- Callback for the onCameraChanged event, which is triggered when the active camera
-- is changed. This event is raised by the Enterable specialization in the
-- setActiveCameraIndex function.
function SMVehicle:onCameraChanged(activeCamera, camIndex)
    if not isMultiplayer() then return end
    print("spec onCameraChanged - camIndex: " .. camIndex)

    if not g_spectatorMode.spectating then
        local cameraType = CameraChangeEvent.CAMERA_TYPE_VEHICLE
        if activeCamera.isInside then
            cameraType = CameraChangeEvent.CAMERA_TYPE_VEHICLE_INDOOR
        end
        g_spectatorMode:print("Steerable.send(CameraChangeEvent:new(controllerName:%s, cameraNode:%s, camIndex:%s, cameraType:%s, toServer:true))", g_currentMission.player.visualInformation.playerName, activeCamera.cameraNode, camIndex, cameraType)
        Event.sendToServer(CameraChangeEvent:new(g_currentMission.player.visualInformation.playerName, activeCamera.cameraNode, camIndex, cameraType, true))
    end
end

function SMVehicle:getVehIsSpectated()
    if not isMultiplayer() then return end

    if g_spectatorMode ~= nil and self.spectatedVehicle ~= nil then
        --if g_spectatorMode.spectating and self:getControllerName() == g_spectatorMode.spectatedPlayer then
        if g_spectatorMode.spectating and self == g_spectatorMode.spectatedVehicle then
            return true
        end
    end
    return false
end

function SMVehicle:drawUIInfo(superFunc)
    if superFunc ~= nil then
        superFunc(self)
    end
    if not isMultiplayer() then return end

    local spec = self:spectatorMode_getSpecTable()

    local spectated = self.getVehIsSpectated ~= nil
    if spectated then
        spectated = self:getVehIsSpectated()
    end

    if (not spec.isEntered and not spectated) and self.isClient and self:getIsActive() and spec.isControlled and not g_gui:getIsGuiVisible() and not g_flightAndNoHUDKeysEnabled then
        local x, y, z = getWorldTranslation(spec.nicknameRendering.node)
        local x1, y1, z1 = getWorldTranslation(getCamera())
        local distSq = MathUtil.vector3LengthSq(x - x1, y - y1, z - z1)
        if distSq <= 100 * 100 then
            x = x + spec.nicknameRendering.offset[1]
            y = y + spec.nicknameRendering.offset[2] + 0.2
            z = z + spec.nicknameRendering.offset[3]
            Utils.renderTextAtWorldPosition(x, y, z, g_currentMission.player.visualInformation.playerName, getCorrectTextSize(0.02), 0)
        end
    end
end

function SMVehicle:addToolCameras(superFunc, cameras)
    print("SMVehicle:addToolCameras()")
    if superFunc ~= nil then
        superFunc(self, cameras)
    end
    if not isMultiplayer() then return end

    local spec = self:spectatorMode_getSpecTable()

    for _, v in pairs(cameras) do
        spec.camerasLerp[v.cameraNode] = {}
        spec.camerasLerp[v.cameraNode].lastQuaternion = { 0, 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].targetQuaternion = { 0, 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].lastTranslation = { 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].targetTranslation = { 0, 0, 0 }
        spec.camerasLerp[v.cameraNode].interpolationAlpha = 1
        spec.camerasLerp[v.cameraNode].skipNextInterpolationAlpha = false
    end
end

function SMVehicle:removeToolCameras(superFunc, cameras)
    print("SMVehicle:removeToolCameras()")
    if superFunc ~= nil then
        superFunc(self, cameras)
    end
    if not isMultiplayer() then return end

    local spec = self:spectatorMode_getSpecTable()

    for _, v in pairs(cameras) do
        spec.camerasLerp[v.cameraNode] = nil
    end
end

function SMVehicle:onAIStart()
    if not isMultiplayer() then return end

    local spec = self.spec_enterable
    print("AIVehicleExtensions:onStartAiVehicle self:getVehIsSpectated() " .. tostring(self:getVehIsSpectated()) .. " spec.activeCamera.isInside " .. tostring(spec.activeCamera.isInside))
    if self:getVehIsSpectated() and spec.activeCamera.isInside then
        --self:getActiveCamera()
        spec.vehicleCharacter:setCharacterVisibility(false) --TODO: Switch to getAllowCharacterVisibilityUpdate overwritten function
    end
end

function SMVehicle:onAIEnd()
    if not isMultiplayer() then return end

    local spec = self.spec_enterable
    print("AIVehicleExtensions:onStopAiVehicle self:getVehIsSpectated() " .. tostring(self:getVehIsSpectated()) .. " spec.activeCamera.isInside " .. tostring(spec.activeCamera.isInside))
    if self:getVehIsSpectated() and spec.activeCamera.isInside then
        spec.vehicleCharacter:setCharacterVisibility(false)
    end
end