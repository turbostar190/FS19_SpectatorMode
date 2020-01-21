--- Main loader
-- SpectatorMode
--
-- @author TyKonKet
-- @date 04/01/2017

local modDirectory = g_currentModDirectory
local modName = g_currentModName
local debugActive = true

source(modDirectory .. "spectatorMode.lua")
source(modDirectory .. "spectatorModeServer.lua")
source(modDirectory .. "extensions/extensions.lua")
source(modDirectory .. "extensions/playerExtensions.lua")
source(modDirectory .. "guis/spectateGui.lua")
source(modDirectory .. "events/cameraChangeEvent.lua")
source(modDirectory .. "events/minimapChangeEvent.lua")
source(modDirectory .. "events/spectatedEvent.lua")
source(modDirectory .. "events/spectateEvent.lua")
source(modDirectory .. "events/spectateRejectedEvent.lua")
source(modDirectory .. "utils/delayedCallBack.lua")
source(modDirectory .. "utils/fadeEffect.lua")

local spectatorMode

function isActive(mission)
    return mission ~= nil and mission.missionDynamicInfo.isMultiplayer or g_currentMission.missionDynamicInfo.isMultiplayer
end

function init()
    FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, unload)

    Mission00.load = Utils.prependedFunction(Mission00.load, load)

    VehicleTypeManager.validateVehicleTypes = Utils.prependedFunction(VehicleTypeManager.validateVehicleTypes, validateVehicleTypes)
end

function validateVehicleTypes(vehicleTypeManager)
    SMUtils.mergeI18N(g_i18n) --Utils class?
    SpectatorMode.installSpecialization(g_vehicleTypeManager, g_specializationManager, modDirectory, modName)
end

function load(mission)
    if not isActive(mission) then return end
    assert(g_spectatorMode == nil)

    spectatorMode = SpectatorMode:new(mission, g_i18n, modDirectory, g_gui, g_gui.inputManager, g_dedicatedServerInfo, g_server, debugActive)

    getfenv(0)["g_spectatorMode"] = spectatorMode

    addModEventListener(spectatorMode)
end

function unload()
    if not isActive() then return end

    removeModEventListener(spectatorMode)

    if spectatorMode ~= nil then
        spectatorMode:delete()
        spectatorMode = nil -- Allows garbage collecting
        getfenv(0)["g_spectatorMode"] = nil
    end
end

init()

function Vehicle:spectatorMode_getSpecTable()
    local spec = self["spec_" .. modName .. ".SMV"]
    if spec ~= nil then
        return spec
    end

    return self["spec_SMV"]
end
