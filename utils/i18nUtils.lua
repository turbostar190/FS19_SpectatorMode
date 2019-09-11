--
-- CreatorTools
--
-- @author TyKonKet
-- @date 15/02/2017

-- Thanks to Jos
-- Ripped from Seasons
function mergeI18N(i18n)
    -- We can copy all our translations to the global table because we prefix everything with SM_
    -- The mod-based l10n lookup only really works for vehicles, not UI and script mods.
    local global = getfenv(0).g_i18n.texts
    for key, text in pairs(i18n.texts) do
        global[key] = text
    end
end

--TODO: Mai testato in FS19
function parseI18N()
    for k, v in pairs(g_i18n.texts) do
        local nv = v
        for m in nv:gmatch("$input_.-;") do
            local input = m:gsub("$input_", ""):gsub(";", "")
            --nv = nv:gsub(m, InputBinding.getKeysNamesOfDigitalAction(InputBinding[input]))
            nv = nv:gsub(m, InputAction.getKeyboardInputActionKey(InputAction[input]))
        end
        g_i18n.texts[k] = nv
    end
end
