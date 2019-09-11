--
-- SpectatorMode
--
-- @author TyKonKet
-- @date 03/01/2017

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
    --print("findUserByNickname start " .. tostring(nickname))
    --DebugUtil.printTableRecursively(self.userManager.users, "", 0, 3)
    --print("findUserByNickname end " .. tostring(nickname))
    for _, user in ipairs(self.userManager.users) do
        if user.nickname == nickname then
            return user
        end
    end
    return nil
end

function FSBaseMission:getPlayerByName(name)
    --print("getPlayerByName start " .. tostring(name))
    --DebugUtil.printTableRecursively(g_currentMission.players, "", 0, 3)
    --print("getPlayerByName end " .. tostring(name))
    for _, v in pairs(g_currentMission.players) do
        if v.visualInformation.playerName == name then
            return v
        end
    end
    return nil
end
