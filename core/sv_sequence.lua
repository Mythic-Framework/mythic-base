local _cachedSeq = {}
local _migrationComplete = false

local function MigrateFromMongoDB()
    -- MongoDB removed; migration no longer needed
end

COMPONENTS.Sequence = {
    Get = function(self, key)
        if _cachedSeq[key] ~= nil then
            _cachedSeq[key].value = _cachedSeq[key].value + 1
            _cachedSeq[key].dirty = true
            return _cachedSeq[key].value
        else
            _cachedSeq[key] = {
                id = key,
                value = 1,
                dirty = true,
            }
            return 1
        end
    end,

    Save = function(self)
        local queries = {}
        for k, v in pairs(_cachedSeq) do
            if v.dirty then
                table.insert(queries, {
                    query = "INSERT INTO `mfw_sequence` (`id`, `value`) VALUES(?, ?) ON DUPLICATE KEY UPDATE `value` = VALUES(`value`)",
                    values = { k, v.value },
                })
                v.dirty = false
            end
        end

        if #queries > 0 then
            MySQL.transaction(queries)
        end
    end,
}

AddEventHandler("Core:Server:StartupReady", function()
    MySQL.rawExecute.await([[
        CREATE TABLE IF NOT EXISTS `mfw_sequence` (
            `id` VARCHAR(64) NOT NULL COLLATE 'utf8mb4_unicode_520_ci',
            `value` BIGINT(20) NOT NULL DEFAULT '1',
            PRIMARY KEY (`id`) USING BTREE
        )
        COLLATE='utf8mb4_unicode_520_ci'
        ENGINE=InnoDB
    ]])

    COMPONENTS.Logger:Info("Sequence", "Ensured mfw_sequence table exists")

    local t = MySQL.rawExecute.await("SELECT `id`, `value` FROM `mfw_sequence`")
    if t then
        for k, v in ipairs(t) do
            _cachedSeq[v.id] = {
                id = v.id,
                value = v.value,
                dirty = false,
            }
        end
        COMPONENTS.Logger:Info("Sequence", string.format("Loaded %d sequences from SQL", #t))
    end
end)

AddEventHandler("Core:Shared:Ready", function()
    CreateThread(function()
        MigrateFromMongoDB()
    end)

    COMPONENTS.Tasks:Register("sequence_save", 1, function()
        COMPONENTS.Sequence:Save()
    end)
end)

AddEventHandler("Core:Server:ForceSave", function()
    COMPONENTS.Sequence:Save()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if (GetCurrentResourceName() ~= resourceName) then return end
    COMPONENTS.Sequence:Save()
end)
