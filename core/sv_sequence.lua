local _cachedSeq = {}
local _loadingPromises = {}

COMPONENTS.Sequence = {
    Get = function(self, key)
        if _cachedSeq[key] then
            _cachedSeq[key].value = _cachedSeq[key].value + 1
            _cachedSeq[key].dirty = true
            return _cachedSeq[key].value
        end

        if not _loadingPromises[key] then
            local p = promise.new()
            _loadingPromises[key] = p

            COMPONENTS.Database.Game:findOne({
                collection = "sequence",
                query = { key = key },
            }, function(success, results)
                local currentValue = 1

                if success and #results > 0 then
                    currentValue = results[1].current + 1
                end

                _cachedSeq[key] = {
                    value = currentValue,
                    dirty = true,
                }

                COMPONENTS.Database.Game:updateOne({
                    collection = "sequence",
                    query = { key = key },
                    update = { ["$set"] = { current = currentValue } },
                    options = { upsert = true }
                }, function(updateSuccess)
                    if not updateSuccess then
                        COMPONENTS.Logger:Error("Sequence", "Failed to immediately persist sequence number for key: " .. key)
                    end
                end)

                p:resolve(_cachedSeq[key])
                _loadingPromises[key] = nil
            end)
        end

        local seqData = Citizen.Await(_loadingPromises[key])
        return seqData.value
    end,

    Save = function(self)
        for k, v in pairs(_cachedSeq) do
            if v.dirty then
                local p = promise.new()
                COMPONENTS.Database.Game:updateOne({
                    collection = "sequence",
                    query = { key = k },
                    update = { ["$set"] = { current = v.value } },
                    options = { upsert = true }
                }, function(success)
                    if success then
                        COMPONENTS.Logger:Trace("Sequence", string.format("Saved Sequence: ^2%s^7 (value=%d)", k, v.value))
                    else
                        COMPONENTS.Logger:Error("Sequence", string.format("Failed saving Sequence: %s", k))
                    end
                    v.dirty = not success
                    p:resolve(success)
                end)
                Citizen.Await(p)
            end
        end
    end,
}

AddEventHandler("Core:Shared:Ready", function()
    COMPONENTS.Tasks:Register("sequence_save", 1, function()
        COMPONENTS.Sequence:Save()
    end)
end)

AddEventHandler("Core:Server:ForceSave", function()
    COMPONENTS.Sequence:Save()
end)