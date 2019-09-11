--- Server
-- SpectatorMode
--
-- @author TyKonKet
-- @date 23/01/2017

SpectatorModeServer = {}
local SpectatorModeServer_mt = Class(SpectatorModeServer)

function SpectatorModeServer:new(isServer, isClient, debug)
    local self = setmetatable({}, SpectatorModeServer_mt)
    self.name = "SpectatorModeServer"
    self.isServer = isServer
    self.isClient = isClient
    self.debug = debug
    self.clients = {}
    return self
end

function SpectatorModeServer:print(text, ...)
    if self.debug then
        local start = string.format("[%s(%s)] -> ", self.name, getDate("%H:%M:%S"))
        local ptext = string.format(text, ...)
        print(string.format("%s%s", start, ptext))
    end
end

function SpectatorModeServer:addSubscriber(sName, connection, aName)
    self:print("addSubscriber(sName:%s, connection:%s, aName:%s)", sName, connection, aName)
    if g_dedicatedServerInfo ~= nil and g_currentMission.player.visualInformation.playerName == aName then
        connection:sendEvent(SpectateRejectedEvent:new(SpectateRejectedEvent.REASON_DEDICATED_SERVER))
        return
    end
    if sName == aName then
        self:print("SpectateRejectedEvent:new(SpectateRejectedEvent.REASON_YOURSELF)")
        connection:sendEvent(SpectateRejectedEvent:new(SpectateRejectedEvent.REASON_YOURSELF))
        return
    end
    self:ensureAName(aName)
    self.clients[aName].subscribers[sName] = {}
    self.clients[aName].subscribers[sName].connection = connection
    self.clients[aName].subscribers[sName].aName = aName
    self.clients[aName].subscribers[sName].spectatorName = sName
    if self.clients[aName].subscribersCount == 0 then
        self:print("    SpectatedEvent:new(true)")
        g_currentMission:findUserByNickname(aName).connection:sendEvent(SpectatedEvent:new(true))
    end
    self.clients[aName].subscribersCount = self.clients[aName].subscribersCount + 1
    --send event to new subscriber
    self:print("    CameraChangeEvent:new(aName:%s, cameraId:%s, cameraIndex:%s, cameraType:%s, toServer:false)", aName, self.clients[aName].cameraId, self.clients[aName].cameraIndex, self.clients[aName].cameraType)
    connection:sendEvent(CameraChangeEvent:new(aName, self.clients[aName].cameraId, self.clients[aName].cameraIndex, self.clients[aName].cameraType, false))
    self:print("    MinimapChangeEvent:new(aName:%s, mmState:%s, toServer:false)", aName, self.clients[aName].mmState)
    connection:sendEvent(MinimapChangeEvent:new(aName, self.clients[aName].mmState, false))
end

function SpectatorModeServer:removeSubscriber(sName, aName)
    self:print("removeSubscriber(sName:%s, aName:%s", sName, aName)
    if self.clients[aName] ~= nil and self.clients[aName].subscribers ~= nil and self.clients[aName].subscribers[sName] ~= nil then
        self.clients[aName].subscribers[sName] = nil
    end
    if self.clients[aName].subscribersCount == 1 then
        local user = g_currentMission:findUserByNickname(aName)
        if user ~= nil and user.connection ~= nil then
            self:print("    SpectatedEvent:new(false)")
            user.connection:sendEvent(SpectatedEvent:new(false))
        end
    end
    self.clients[aName].subscribersCount = self.clients[aName].subscribersCount - 1
end

function SpectatorModeServer:cameraChange(aName, cameraId, cameraIndex, cameraType)
    self:print("cameraChange(aName:%s, cameraId:%s, cameraIndex:%s, cameraType:%s)", aName, cameraId, cameraIndex, cameraType)
    self:ensureAName(aName)
    self.clients[aName].cameraId = cameraId
    self.clients[aName].cameraIndex = cameraIndex
    self.clients[aName].cameraType = cameraType
    local event = CameraChangeEvent:new(aName, cameraId, cameraIndex, cameraType, false)
    for _, v in pairs(self.clients[aName].subscribers) do
        -- send event to subscribers
        self:print("    to %s", v.spectatorName)
        v.connection:sendEvent(event)
    end
end

function SpectatorModeServer:minimapChange(aName, mmState)
    self:print("minimapChange(aName:%s, state:%s)", aName, mmState)
    self:ensureAName(aName)
    self.clients[aName].mmState = mmState
    local event = MinimapChangeEvent:new(aName, mmState, false)
    for _, v in pairs(self.clients[aName].subscribers) do
        -- send event to subscribers
        self:print("    to %s", v.spectatorName)
        v.connection:sendEvent(event)
    end
end

function SpectatorModeServer:ensureAName(aName)
    if self.clients[aName] == nil then
        self.clients[aName] = {}
    end
    if self.clients[aName].subscribers == nil then
        self.clients[aName].subscribers = {}
    end
    if self.clients[aName].subscribersCount == nil then
        self.clients[aName].subscribersCount = 0
    end
    if self.clients[aName].mmState == nil then
        self.clients[aName].mmState = 0
    end
end
