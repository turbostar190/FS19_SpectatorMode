--
-- SpectatorMode
--
-- @author TyKonKet
-- @date 20/01/2017
VehicleExtensions = {}

function VehicleExtensions.installSpecialization(vehicleTypeManager, specializationManager, modDirectory, modName)
    specializationManager:addSpecialization("SMVehicle", "vehicleExtensionsSpec", Utils.getFilename("extensions/vehicleExtensionsSpec.lua", modDirectory), nil) -- Nil is important here

    for typeName, typeEntry in pairs(vehicleTypeManager:getVehicleTypes()) do

        if SpecializationUtil.hasSpecialization(Enterable, typeEntry.specializations) then
            vehicleTypeManager:addSpecialization(typeName, modName .. ".SMVehicle")
        end

    end
end
