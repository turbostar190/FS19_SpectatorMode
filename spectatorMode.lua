--- Client
-- SpectatorMode
--
-- @author TyKonKet
-- @date 23/12/2016

SpectatorMode = {}
local SpectatorMode_mt = Class(SpectatorMode)

function SpectatorMode:new(mission, i18n, modDirectory, gui, inputManager, dedicatedServerInfo, server, debug)
    local self = setmetatable({}, SpectatorMode_mt)

    self.isServer = mission:getIsServer()
    self.isClient = mission:getIsClient()
    self.mission = mission
    self.i18n = i18n
    self.modDirectory = modDirectory
    self.gui = gui
    self.inputManager = inputManager
    self.debug = debug

    self.spectateGuiEventId = ""
    self.spectateGui = SpectateGui:new(self.isServer, self.isClient)
    local xml = Utils.getFilename("guis/spectateGui.xml", self.modDirectory)
    self.gui:loadGui(xml, "SpectateGui", self.spectateGui)

    if g_server ~= nil then
        self.server = SpectatorModeServer:new(self.isServer, self.isClient, self.debug)
    end

    self.name = "SpectatorMode"
    self.spectating = false
    self.spectated = false
    self.spectatedPlayer = nil
    self.spectatedPlayerIndex = 1
    self.spectatedPlayerObject = nil
    self.spectatedVehicle = nil
    self.delayedCameraChangedDCB = DelayedCallBack:new(SpectatorMode.delayedCameraChanged, self)
    self.delayedCameraChangedDCB.skipOneFrame = true
    self.delayedStopSpectateDCB = DelayedCallBack:new(SpectatorMode.delayedStopSpectate, self)

    self.networkTimeInterpolator = InterpolationTime:new(1.2) -- Steerable

    -- hud
    local uiScale = g_gameSettings:getValue("uiScale")
    self.spectatedOverlayWidth, self.spectatedOverlayHeight = getNormalizedScreenValues(24 * uiScale, 24 * uiScale)
    local _, margin = getNormalizedScreenValues(0, 1 * uiScale)
    self.spectatedOverlay = Overlay:new(Utils.getFilename("huds/spectated.dds", modDirectory), 0 + margin, 1 - self.spectatedOverlayHeight - margin, self.spectatedOverlayWidth, self.spectatedOverlayHeight)

    self.spectateFadeEffectOffsetX, self.spectateFadeEffectOffsetY = getNormalizedScreenValues(3 * uiScale, -3 * uiScale)
    _, self.spectateFadeEffectSize = getNormalizedScreenValues(0, 40 * uiScale)
    self.spectateFadeEffect = FadeEffect:new({ position = { x = 0.5, y = g_safeFrameOffsetY }, size = self.spectateFadeEffectSize, shadow = true, shadowPosition = { x = self.spectateFadeEffectOffsetX, y = self.spectateFadeEffectOffsetY } })

    self.lastPlayer = {}
    self.lastPlayer.mmState = 0
    self.lastPlayer.lightNode = 0
    self.lastPlayer.lastPositionX = 0
    self.lastPlayer.lastPositionY = 0
    self.lastPlayer.lastPositionZ = 0

    FSBaseMission.registerActionEvents = Utils.appendedFunction(FSBaseMission.registerActionEvents, self.inj_fsBaseMission_registerActionEvents)

    -- extending player functions
    Player.writeStream = Utils.appendedFunction(Player.writeStream, PlayerExtensions.writeStream)
    Player.readStream = Utils.appendedFunction(Player.readStream, PlayerExtensions.readStream)
    Player.writeUpdateStream = Utils.appendedFunction(Player.writeUpdateStream, PlayerExtensions.writeUpdateStream)
    Player.readUpdateStream = Utils.appendedFunction(Player.readUpdateStream, PlayerExtensions.readUpdateStream)
    Player.update = Utils.appendedFunction(Player.update, PlayerExtensions.update)
    Player.onEnter = Utils.appendedFunction(Player.onEnter, PlayerExtensions.onEnter)
    Player.drawUIInfo = Utils.overwrittenFunction(Player.drawUIInfo, PlayerExtensions.drawUIInfo)
    Player.getPositionData = Utils.overwrittenFunction(Player.getPositionData, PlayerExtensions.getPositionData)
    --Player.isSpectated = PlayerExtensions.isSpectated

    -- Misc
    BaseMission.requestToEnterVehicle = Utils.overwrittenFunction(BaseMission.requestToEnterVehicle, self.requestToEnterVehicle)
    IngameMap.toggleSize = Utils.overwrittenFunction(IngameMap.toggleSize, self.toggleSize)

    g_messageCenter:subscribe(MessageType.USER_REMOVED, self.onUserRemoved, self)

    return self
end

function SpectatorMode:print(text, ...)
    if self.debug then
        local pre = "[ ]"
        if self.spectating then
            pre = "[S]"
        end
        local start = string.format("%s[%s(%s)] -> ", self.name, getDate("%H:%M:%S"), pre)
        local ptext = string.format(text, ...)
        print(string.format("%s%s", start, ptext))
    end
end

---This is called before anything of the game has been created.
-- The vehicle types must not be initialized yet to make any changes to them.
function SpectatorMode.installSpecialization(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization("SMV", "SMVehicle", Utils.getFilename("extensions/SMVehicle.lua", modDirectory), nil) -- Nil is important here

    for typeName, typeEntry in pairs(vehicleTypeManager:getVehicleTypes()) do
        if SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".SMV") --TODO: Spec is registestered with prefix modName... change to spec_SMV
        end
    end
end

function SpectatorMode:inj_fsBaseMission_registerActionEvents()
    --print("inj_fsBaseMission_registerActionEvents")
    g_spectatorMode:registerActionEvents()
end

function SpectatorMode:registerActionEvents()
    if self.isClient then
        local _, eventId = g_inputBinding:registerActionEvent(InputAction.SM_TOGGLE, self, self.toggleActionEvent, false, true, false, true)
        self.spectateGuiEventId = eventId
        --self:print(string.format("smToggle: %s , smSwitchActorNext: %s , smSwitchActorPrevious: %s", tostring(g_spectatorMode.smToggle), tostring(g_spectatorMode.smSwitchActorNext), tostring(g_spectatorMode.smSwitchActorPrevious)))
    end
end

function SpectatorMode:toggleActionEvent()
    --print("toggleActionEvent()")
    if g_currentMission.controlledVehicle == nil then
        --print("toggleActionEvent() -> g_spectatorMode.spectating " .. tostring(g_spectatorMode.spectating) .. " self.spectating " .. tostring(self.spectating))
        if self.spectating then
            self:stopSpectate()
        else
            if self.gui.currentGui == nil then
                self:showGui()
            end
        end
    end
end

function SpectatorMode:showGui()
    self.spectateGui:setSpectableUsers(self:getSpectableUsers())
    if not self.mission.isSynchronizingWithPlayers then
        self.gui:showDialog("SpectateGui")
    end
end

function SpectatorMode:getSpectableUsers()
    local spectableUsers = {}
    for _, p in pairs(g_currentMission.players) do
        if not p.isDedicatedServer and not p:getIsSpectated() and g_currentMission.player.visualInformation.playerName ~= p.visualInformation.playerName then
            table.insert(spectableUsers, p.visualInformation.playerName)
        end
    end
    return spectableUsers
end

function SpectatorMode:getNextPlayerIndex()
    if self.spectatedPlayerIndex == #self:getSpectableUsers() then
        return 1
    else
        return self.spectatedPlayerIndex + 1
    end
end

function SpectatorMode:getPreviousPlayerIndex()
    if self.spectatedPlayerIndex == 1 then
        return #self:getSpectableUsers()
    else
        return self.spectatedPlayerIndex - 1
    end
end

--[[function SpectateGui:startSpectateNextActionEvent()
	self:print("startSpectateNextActionEvent()")
	if g_currentMission.controlledVehicle == nil then
		self:print("startSpectateNextActionEvent() -> self.spectating " .. tostring(self.spectating))
		if self.spectating then
			g_spectatorMode:stopSpectate()
			g_spectatorMode:startSpectate(SpectatorMode:getNextPlayerIndex())
		end
	end
end
function SpectateGui:startSpectatePreviousActionEvent()
	self:print("startSpectatePreviousActionEvent()")
	if g_currentMission.controlledVehicle == nil then
		self:print("startSpectatePreviousActionEvent() -> self.spectating " .. tostring(self.spectating))
		if self.spectating then
			g_spectatorMode:stopSpectate()
			g_spectatorMode:startSpectate(SpectatorMode:getPreviousPlayerIndex())
		end
	end
end]]

function SpectatorMode:delete()
    self.spectatedOverlay:delete()
end

function SpectatorMode:update(dt)
    self.spectateFadeEffect:update(dt)
    self.delayedCameraChangedDCB:update(dt)
    self.delayedStopSpectateDCB:update(dt)
    if self.debug and self.lastCamera ~= getCamera() then
        self:print("update() CameraChanged(from:%s to:%s)", self.lastCamera, getCamera())
        self.lastCamera = getCamera()
    end
end

function SpectatorMode:draw()
    self.spectateFadeEffect:draw()
    if self.spectatedVehicle ~= nil then
        if self.spectatedVehicle.spec_drivable ~= nil then
            --g_currentMission:drawVehicleHud(self.spectatedVehicle)
            -- TODO: Not Working
            --g_currentMission:drawHudIcon()
            -- g_vehicleSchemaDisplay:drawVehicleSchemaOverlays(self.spectatedVehicle)
            --g_currentMission:drawVehicleSchemaOverlays(self.spectatedVehicle)
        end
    end
    if self.spectated then
        self.spectatedOverlay:render()
    end
    if g_currentMission.controlledVehicle == nil then
        --self:print(string.format("update() :: smToggle: %s , smSwitchActorNext: %s , smSwitchActorPrevious: %s", tostring(g_spectatorMode.smToggle), tostring(g_spectatorMode.smSwitchActorNext), tostring(g_spectatorMode.smSwitchActorPrevious)))
        if self.spectating then
            g_inputBinding:setActionEventText(self.spectateGuiEventId, g_i18n:getText("SM_STOP"))
        else
            g_inputBinding:setActionEventText(self.spectateGuiEventId, g_i18n:getText("SM_START"))
        end
        g_inputBinding:setActionEventActive(self.spectateGuiEventId, true)
        g_inputBinding:setActionEventTextVisibility(self.spectateGuiEventId, true)
    else
        g_inputBinding:setActionEventActive(self.spectateGuiEventId, false)
        g_inputBinding:setActionEventTextVisibility(self.spectateGuiEventId, false)
    end
end

function SpectatorMode:startSpectate(playerIndex)
    --self.lastPlayer.lastPositionX, self.lastPlayer.lastPositionY, self.lastPlayer.lastPositionZ = getTranslation(g_currentMission.player.graphicsRootNode)
    g_currentMission.player.pickedUpObjectOverlay:setIsVisible(false)
    g_currentMission.isPlayerFrozen = true
    self.lastPlayer.lightNode = g_currentMission.player.lightNode
    g_currentMission.player.lightNode = nil -- disable ability to toggle player light
    self.spectating = true
    self.spectatedPlayer = self:getSpectableUsers()[playerIndex]
    self.spectatedPlayerIndex = playerIndex
    self.spectatedPlayerObject = g_currentMission:getPlayerByName(self.spectatedPlayer)
    self.spectatedPlayerObject:setWoodWorkVisibility(false, false)
    self.spectatedPlayerObject:setVisibility(false)
    g_currentMission.hasSpecialCamera = true
    self:print("Event.send(SpectateEvent:new(start:true, spectatorName:%s, actorName:%s))", g_currentMission.player.visualInformation.playerName, self.spectatedPlayer)
    Event.sendToServer(SpectateEvent:new(true, g_currentMission.player.visualInformation.playerName, self.spectatedPlayer))
    self.lastPlayer.mmState = g_currentMission.hud.ingameMap.state
    self.spectateFadeEffect:play(self.spectatedPlayer)
    --g_currentMission.player:onLeave()
end

function SpectatorMode:stopSpectate(disconnect)
    --TODO: Detach camera where event happens. Now it follows player still after stopping spectate
    g_currentMission.hud.ingameMap:toggleSize(self.lastPlayer.mmState, true)
    g_currentMission.hasSpecialCamera = false
    self:setVehicleActiveCamera(nil)
    self:print("Event.send(SpectateEvent:new(start:false, spectatorName:%s, actorName:%s))", g_currentMission.player.visualInformation.playerName, self.spectatedPlayer)
    Event.sendToServer(SpectateEvent:new(false, g_currentMission.player.visualInformation.playerName, self.spectatedPlayer))
    if not disconnect then
        self.delayedStopSpectateDCB:call(100, self.spectatedPlayerObject, self.spectatedVehicle)
    end
    --self.spectatedPlayerObject:setVisibility(true)
    self.spectatedPlayerObject:setWoodWorkVisibility(true, true)
--[[    if self.spectatedVehicle ~= nil then
        g_currentMission.player:moveToExitPoint(self.spectatedVehicle)
    else
        local x, y, z = getTranslation(self.spectatedPlayerObject.rootNode)
        g_currentMission.player:moveToAbsoluteInternal(x, y, z)
    end]]
    self.spectatedPlayerObject = nil
    self.spectatedPlayer = nil
    --self.spectatedPlayerIndex = nil
    self.spectatedVehicle = nil
    g_currentMission.player.pickedUpObjectOverlay:setIsVisible(true)
    g_currentMission.isPlayerFrozen = false
    g_currentMission.player.lightNode = self.lastPlayer.lightNode -- enable ability to toggle player light
    --setTranslation(self.lastPlayer.lastPositionX, self.lastPlayer.lastPositionY, self.lastPlayer.lastPositionZ)
    --g_currentMission.player:onEnter()
    self.spectating = false
end

function SpectatorMode:spectateRejected(reason)
    self:print(("spectateRejected(reason:%s)"):format(reason))
    self:stopSpectate()
    if reason == SpectateRejectedEvent.REASON_DEDICATED_SERVER then
        g_currentMission:showBlinkingWarning(g18n:getText("SM_ERROR_SPECTATE_DEDICATED_SERVER"), 3000)
    elseif reason == SpectateRejectedEvent.REASON_YOURSELF then
        g_currentMission:showBlinkingWarning(g18n:getText("SM_ERROR_SPECTATE_YOURSELF"), 3000)
    end
end

function SpectatorMode:delayedStopSpectate(spectatedPlayerObject, spectatedVehicle)
    if spectatedPlayerObject ~= self.spectatedPlayerObject then
        spectatedPlayerObject:setVisibility(true)
        spectatedPlayerObject:setWoodWorkVisibility(false, false)
    end
    if spectatedVehicle ~= nil and spectatedVehicle ~= self.spectatedVehicle then
        spectatedVehicle.spec_enterable.vehicleCharacter:setCharacterVisibility(true) --getAllowCharacterVisibilityUpdate TODO: Move to spec?
    end
end

-- Called from event 'cameraChangeEvent'
function SpectatorMode:cameraChanged(actorName, cameraId, cameraIndex, cameraType)
    self:print(string.format("cameraChanged(actorName:%s, cameraId:%s, cameraIndex:%s, cameraType:%s)", actorName, cameraId, cameraIndex, cameraType))
    if cameraType == CameraChangeEvent.CAMERA_TYPE_PLAYER then
        self.delayedCameraChangedDCB:call(20, actorName, cameraId, cameraIndex, cameraType)
    else
        self:delayedCameraChanged(actorName, cameraId, cameraIndex, cameraType)
    end
end

function SpectatorMode:delayedCameraChanged(actorName, cameraId, cameraIndex, cameraType)
    self:print(string.format("delayedCameraChanged(actorName:%s, cameraId:%s, cameraIndex:%s, cameraType:%s)", actorName, cameraId, cameraIndex, cameraType))
    if cameraType == CameraChangeEvent.CAMERA_TYPE_PLAYER then
        setCamera(self.spectatedPlayerObject.cameraNode)
        self:setVehicleActiveCamera(nil)
        self.spectatedVehicle = nil
        self.spectatedPlayerObject.skipNextInterpolationAlpha = true
        self.spectatedPlayerObject.interpolationAlpha = 1
        --VehicleSchemaDisplay:setVehicle(nil)
        --SpeedMeterDisplay:setVehicle(nil)
    elseif cameraType == CameraChangeEvent.CAMERA_TYPE_VEHICLE then
        --print("g_currentMission.controlledVehicles start")
        --DebugUtil.printTableRecursively(g_currentMission.controlledVehicles, "", 0, 1)
        --print("g_currentMission.controlledVehicles end")
        for _, v in pairs(g_currentMission.controlledVehicles) do
            print("v:getControllerName() " .. tostring(v:getControllerName()) .. " actorName " .. actorName)
            if v:getControllerName() == actorName then
                local spec = v:spectatorMode_getSpecTable()
                setCamera(v.spec_enterable.cameras[cameraIndex].cameraNode)
                v.spec_enterable.vehicleCharacter:setCharacterVisibility(true)
                self.spectatedVehicle = v
                self:setVehicleActiveCamera(cameraIndex)
                --VehicleSchemaDisplay:setVehicle(v)
                --SpeedMeterDisplay:setVehicle(v)
                spec.camerasLerp[v.spec_enterable.cameras[cameraIndex].cameraNode].skipNextInterpolationAlpha = true
                spec.camerasLerp[v.spec_enterable.cameras[cameraIndex].cameraNode].interpolationAlpha = 1
                --g_currentMission.hud:showVehicleName(v)
            end
        end
    elseif cameraType == CameraChangeEvent.CAMERA_TYPE_VEHICLE_INDOOR then
        --print("g_currentMission.controlledVehicles indoor start")
        for _, v in pairs(g_currentMission.controlledVehicles) do
            --print("g_currentMission.controlledVehicles indoor end")
            print("indoor v:getControllerName() " .. tostring(v:getControllerName()) .. " actorName " .. actorName)
            if v:getControllerName() == actorName then
                local spec = v:spectatorMode_getSpecTable()
                setCamera(v.spec_enterable.cameras[cameraIndex].cameraNode)
                v.spec_enterable.vehicleCharacter:setCharacterVisibility(false)
                self.spectatedVehicle = v
                self:setVehicleActiveCamera(cameraIndex)
                --VehicleSchemaDisplay:setVehicle(v)
                --SpeedMeterDisplay:setVehicle(v)
                spec.camerasLerp[v.spec_enterable.cameras[cameraIndex].cameraNode].skipNextInterpolationAlpha = true
                spec.camerasLerp[v.spec_enterable.cameras[cameraIndex].cameraNode].interpolationAlpha = 1
            end
        end
    end
end

function SpectatorMode:setVehicleActiveCamera(cameraIndex)
    self:print(string.format("setVehicleActiveCamera(cameraIndex:%s) self.spectatedVehicle ~= nil %s", cameraIndex, tostring(self.spectatedVehicle ~= nil)))
    if self.spectatedVehicle ~= nil then
        local useMirror = false
        if cameraIndex ~= nil then
            self.spectatedVehicle:setActiveCameraIndex(cameraIndex)
            --print("userMirror " .. tostring(self.spectatedVehicle:getActiveCamera().useMirror))
            useMirror = self.spectatedVehicle:getActiveCamera().useMirror
        end
        if self.spectatedVehicle.setMirrorVisible ~= nil then
            self.spectatedVehicle:setMirrorVisible(useMirror)
        end
    end
end

function SpectatorMode:minimapChange(aName, mmState)
    self:print("minimapChange(aName:%s, state:%s)", aName, mmState)
    g_currentMission.hud.ingameMap:toggleSize(mmState, true, true)
end

function SpectatorMode:requestToEnterVehicle(superFunc, vehicle)
    g_spectatorMode:print("requestToEnterVehicle() g_spectatorMode.spectating " .. tostring(g_spectatorMode.spectating))
    if not g_spectatorMode.spectating then
        if superFunc ~= nil then
            superFunc(self, vehicle)
        end
    end
end

function SpectatorMode:toggleSize(superFunc, state, force, noEventSend)
    if superFunc ~= nil then
        superFunc(self, state, force)
    end
    if state == nil then
        state = g_gameSettings:getValue("ingameMapState")
    end
    g_spectatorMode:print("toggleSize(state:%s, force:%s, noEventSend:%s)", state, force, noEventSend)
    if not noEventSend then
        g_spectatorMode:print("Event.send(MinimapChangeEvent:new(controllerName:%s, state:%s, toServer:true))", g_currentMission.player.visualInformation.playerName, state)
        Event.sendToServer(MinimapChangeEvent:new(g_currentMission.player.visualInformation.playerName, state, true))
    end
end

function SpectatorMode:onUserRemoved(player)
    -- print("onUserRemoved start")
    -- DebugUtil.printTableRecursively(player, "-", 0, 3)
    -- print("onUserRemoved playername: " .. tostring(player.playerName) .. " g_player " .. tostring(g_spectatorMode.spectatedPlayer))
    -- print("spectating " .. tostring(g_spectatorMode.spectating))
    if g_spectatorMode.spectating and player.nickname == g_spectatorMode.spectatedPlayer then
        self:print("Stopping spectating player " .. tostring(player.visualInformation.playerName))
        g_spectatorMode:stopSpectate(true)
    end
    -- print("onUserRemoved end")
end
