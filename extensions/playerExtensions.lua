--- Player extensions
-- SpectatorMode
--
-- @author TyKonKet
-- @date 20/01/2017
PlayerExtensions = {}

function PlayerExtensions:writeStream(streamId, connection)
    if not connection:getIsServer() and connection ~= self.networkInformation.creatorConnection then
        local isDedicatedServer = g_dedicatedServerInfo and g_currentMission.player.visualInformation.playerName == self.visualInformation.playerName
        streamWriteBool(streamId, isDedicatedServer == true)
    end
end

function PlayerExtensions:readStream(streamId, connection)
    if not self.isOwner and connection:getIsServer() then
        self.isDedicatedServer = streamReadBool(streamId)
    end
end

function PlayerExtensions:writeUpdateStream(streamId, connection, dirtyMask)
    if not connection:getIsServer() and connection ~= self.networkInformation.creatorConnection then
        -- server code (send data to client)
        local x, y, z, w = getQuaternion(self.cameraNode)
        streamWriteFloat32(streamId, x)
        streamWriteFloat32(streamId, y)
        streamWriteFloat32(streamId, z)
        streamWriteFloat32(streamId, w)
        streamWriteFloat32(streamId, self.camY)
        streamWriteUInt8(streamId, getFovY(self.cameraNode))
    elseif self.isOwner and connection:getIsServer() then
        -- client code (send data to server)
        streamWriteFloat32(streamId, self.camY)
        streamWriteUInt8(streamId, getFovY(self.cameraNode))
    end
end

function PlayerExtensions:readUpdateStream(streamId, timestamp, connection)
    if not self.isOwner and connection:getIsServer() then
        self.lastQuaternion = {
            getQuaternion(self.cameraNode)
        }
        self.networkInformation.interpolationTime:startNewPhaseNetwork()
        self.networkInformation.interpolatorQuaternion:setTargetQuaternion(streamReadFloat32(streamId), streamReadFloat32(streamId), streamReadFloat32(streamId), streamReadFloat32(streamId))
        local physicsIndex = getPhysicsUpdateIndex()
        table.insert(self.networkInformation.history, {index=self.networkInformation.index, physicsIndex = physicsIndex})
        self.networkInformation.updateTargetTranslationPhysicsIndex = physicsIndex -- update until the current physics index is simulated
        self.networkInformation.interpolationTime.interpolationAlpha = 0
        if self.skipNextInterpolationAlpha then
            self.networkInformation.interpolationTime.interpolationAlpha = 1
            self.skipNextInterpolationAlpha = false
        end
        local cx, _, cz = getTranslation(self.cameraNode)
        setTranslation(self.cameraNode, cx, streamReadFloat32(streamId), cz)
        setFovY(self.cameraNode, streamReadUInt8(streamId))
    elseif not self.isOwner and not connection:getIsServer() then
        self.camY = streamReadFloat32(streamId)
        setFovY(self.cameraNode, streamReadUInt8(streamId))
    end
end

function PlayerExtensions:update(dt)
    if not self.isServer and not self.isEntered then
        self.networkInformation.interpolationTime.interpolationAlpha = self.networkInformation.interpolationTime.interpolationAlpha + g_physicsDtUnclamped / 75
        if self.networkInformation.interpolationTime.interpolationAlpha > 1.2 then
            self.networkInformation.interpolationTime.interpolationAlpha = 1.2
        end
        local qx, qy, qz, qw = self.networkInformation.interpolatorQuaternion:getInterpolatedValues(self.networkInformation.interpolationTime.interpolationAlpha)
        setQuaternion(self.cameraNode, qx, qy, qz, qw)
    end
end

function PlayerExtensions:onEnter(isOwner)
    if isOwner then
        if not g_spectatorMode.spectating then
            g_spectatorMode:print("Player.send(CameraChangeEvent:new(controllerName:%s, cameraNode:%s, camIndex:%s, cameraType:%s, toServer:true))", g_currentMission.player.visualInformation.playerName, self.cameraNode, 0, CameraChangeEvent.CAMERA_TYPE_PLAYER)
            Event.sendToServer(CameraChangeEvent:new(g_currentMission.player.visualInformation.playerName, self.cameraNode, 0, CameraChangeEvent.CAMERA_TYPE_PLAYER, true))
        end
    elseif g_spectatorMode ~= nil then
        if self.visualInformation.playerName == g_spectatorMode.spectatedPlayer then
            self:setVisibility(false)
        end
    end
end

function PlayerExtensions:drawUIInfo(superFunc)
    local spectated
    if self.getIsSpectated ~= nil then
        spectated = self:getIsSpectated()
    end
    if not spectated then
        superFunc(self)
--[[        if self.isClient and self.isControlled and not self.isEntered then
            if not g_gui:getIsGuiVisible() and not g_flightAndNoHUDKeysEnabled then
                local x, y, z = getTranslation(self.graphicsRootNode)
                local x1, y1, z1 = getWorldTranslation(getCamera())
                local diffX = x - x1
                local diffY = y - y1
                local diffZ = z - z1
                local dist = MathUtil.vector3LengthSq(diffX, diffY, diffZ)
                if dist <= 100 * 100 then
                    y = y + self.baseInformation.tagOffset[2]
                    Utils.renderTextAtWorldPosition(x, y, z, self.visualInformation.playerName, getCorrectTextSize(0.02), 0)
                end
            end
        end]]
    end
end

function PlayerExtensions:getPositionData(superFunc)
    if g_spectatorMode ~= nil and g_spectatorMode.spectating then
        if g_spectatorMode.spectatedVehicle ~= nil then
            local vehicle = g_spectatorMode.spectatedVehicle
            local posX, posY, posZ = getTranslation(vehicle.rootNode)
            local dx, _, dz = localDirectionToWorld(vehicle.rootNode, 0, 0, 1)

            local yRot
            if vehicle.spec_drivable ~= nil and vehicle.spec_drivable.reverserDirection == -1 then
                yRot = MathUtil.getYRotationFromDirection(dx, dz)
            else
                yRot = MathUtil.getYRotationFromDirection(dx, dz) + math.pi
            end

            return posX, posY, posZ, yRot
--[[        else
            local pl = g_spectatorMode.spectatedPlayerObject
            local posX, posY, posZ = getTranslation(pl.rootNode)
            if pl.isClient and pl.isControlled and pl.isEntered then
                return posX, posY, posZ, pl.rotY
            else
                return posX, posY, posZ, pl.graphicsRotY
            end]]
        end
    end

    return superFunc(self)
end

function Player:getIsSpectated()
    if g_spectatorMode ~= nil then
        if g_spectatorMode.spectating and self.visualInformation.playerName == g_spectatorMode.spectatedPlayer then
            return true
        end
    end
    return false
end
