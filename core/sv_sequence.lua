local _cachedSeq = {}
local _loading = {}
local _migrationComplete = false

local function MigrateFromMongoDB()
    if _migrationComplete then
        return
    end

    local p = promise.new()

    COMPONENTS.Logger:Info("Sequence", "Checking for unmigrated sequences in MongoDB...")

    COMPONENTS.Database.Game:find({
        collection = "sequence",
        query = {
            ["$or"] = {
                { migrated = false },
                { migrated = { ["$exists"] = false } }
            }
        },
    }, function(success, results)
        if not success then
            COMPONENTS.Logger:Error("Sequence", "Failed to fetch sequences from MongoDB for migration")
            p:resolve(false)
            return
        end

        if #results == 0 then
            COMPONENTS.Logger:Info("Sequence", "No unmigrated sequences found in MongoDB")
            _migrationComplete = true
            p:resolve(true)
            return
        end

        COMPONENTS.Logger:Info("Sequence",
            string.format("Found %d unmigrated sequences, starting migration...", #results))

        local migratedCount = 0
        local failedCount = 0

        for _, doc in ipairs(results) do
            if doc.key and doc.current then
                local seqP = promise.new()

                local inserted = MySQL.rawExecute.await(
                    "INSERT INTO sequence (id, sequence) VALUES(?, ?) ON DUPLICATE KEY UPDATE sequence = GREATEST(sequence, VALUES(sequence))",
                    { doc.key, doc.current }
                )

                if inserted then
                    COMPONENTS.Database.Game:updateOne({
                        collection = "sequence",
                        query = { key = doc.key },
                        update = { ["$set"] = { migrated = true } },
                    }, function(updateSuccess)
                        if updateSuccess then
                            if not _cachedSeq[doc.key] or _cachedSeq[doc.key].sequence < doc.current then
                                _cachedSeq[doc.key] = {
                                    id = doc.key,
                                    sequence = doc.current,
                                    dirty = false,
                                }
                            end

                            migratedCount = migratedCount + 1
                            COMPONENTS.Logger:Trace("Sequence",
                                string.format("Migrated sequence: ^2%s^7 (value=%d)", doc.key, doc.current))
                        else
                            failedCount = failedCount + 1
                            COMPONENTS.Logger:Error("Sequence",
                                string.format("Failed to mark sequence as migrated in MongoDB: %s", doc.key))
                        end
                        seqP:resolve()
                    end)
                else
                    failedCount = failedCount + 1
                    COMPONENTS.Logger:Error("Sequence", string.format("Failed to insert sequence into SQL: %s", doc.key))
                    seqP:resolve()
                end

                Citizen.Await(seqP)
            end
        end

        if migratedCount > 0 then
            COMPONENTS.Logger:Info("Sequence",
                string.format("Successfully migrated %d sequences from MongoDB to SQL", migratedCount))
        end

        if failedCount > 0 then
            COMPONENTS.Logger:Warn("Sequence",
                string.format("%d sequences failed to migrate (will retry on next startup)", failedCount))
        end

        _migrationComplete = (failedCount == 0)
        p:resolve(true)
    end)

    return Citizen.Await(p)
end

COMPONENTS.Sequence = {
    Get = function(self, key)
        if _cachedSeq[key] ~= nil then
            _cachedSeq[key].sequence = _cachedSeq[key].sequence + 1
            _cachedSeq[key].dirty = true
            return _cachedSeq[key].sequence
        else
            _cachedSeq[key] = {
                id = key,
                sequence = 1,
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
                    query =
                    "INSERT INTO sequence (id, sequence) VALUES(?, ?) ON DUPLICATE KEY UPDATE sequence = VALUES(sequence)",
                    values = {
                        k,
                        v.sequence,
                    },
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
        CREATE TABLE IF NOT EXISTS `sequence` (
            `id` VARCHAR(64) NOT NULL COLLATE 'utf8mb4_unicode_520_ci',
            `sequence` BIGINT(20) NOT NULL DEFAULT '1',
            PRIMARY KEY (`id`) USING BTREE
        )
        COLLATE='utf8mb4_unicode_520_ci'
        ENGINE=InnoDB
    ]])

    COMPONENTS.Logger:Info("Sequence", "Ensured sequence table exists")

    local t = MySQL.rawExecute.await("SELECT id, sequence FROM sequence")
    if t then
        for k, v in ipairs(t) do
            _cachedSeq[v.id] = {
                id = v.id,
                sequence = v.sequence,
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
