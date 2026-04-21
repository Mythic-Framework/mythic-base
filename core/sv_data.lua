local _data = {}
local _inserting = {}

COMPONENTS.Default = {
    _required = { 'Add' },
    _name = { 'base' },
    _protected = true,

    Add = function(self, collection, date, data)
        CreateThread(function()
            while _inserting[collection] ~= nil do Wait(10) end
            _inserting[collection] = true

            for _, v in ipairs(data) do v.default = true end

            local db = COMPONENTS.Database
            local existing = db:FindOne('defaults', { collection = collection })

            if not existing or existing.date < date then
                db:Delete(collection, { default = true })
                for _, doc in ipairs(data) do
                    db:Insert(collection, doc)
                end
                db:Upsert('defaults', { collection = collection }, { collection = collection, date = date })
            end

            _inserting[collection] = nil
        end)
    end,

    AddAuth = function(self, collection, date, data)
        CreateThread(function()
            while _inserting[collection] ~= nil do Wait(10) end
            _inserting[collection] = true

            for _, v in ipairs(data) do v.default = true end

            local db = COMPONENTS.Database
            local existing = db:FindOne('defaults', { collection = collection })

            if not existing or existing.date < date then
                db:Delete(collection, { default = true })
                for _, doc in ipairs(data) do
                    db:Insert(collection, doc)
                end
                db:Upsert('defaults', { collection = collection }, { collection = collection, date = date })
            end

            _inserting[collection] = nil
        end)
    end,
}
