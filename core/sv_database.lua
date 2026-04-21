-- MythicFrame Database Component

local _verified = {}
local _pending  = {}

-- Internal: schema access

local function getSchema(tbl)
    return DB_SCHEMAS and DB_SCHEMAS[tbl] or nil
end

local function requireSchema(tbl, op)
    local s = getSchema(tbl)
    if not s then
        print(('[DATABASE] [ERROR] No schema defined for table "%s" (op: %s) — add it to sv_db_schemas.lua'):format(tbl, op))
        return nil
    end
    return s
end

local function schemaInfo(schema)
    local cols, jsonCols = {}, {}
    for name in pairs(schema.cols) do cols[name] = true end
    for _, name in ipairs(schema.jsonCols or {}) do jsonCols[name] = true end
    return cols, jsonCols
end

-- Internal: table creation

local function buildCreateSQL(tbl, schema)
    local defs = { '`_id` INT NOT NULL AUTO_INCREMENT' }
    for name, typedef in pairs(schema.cols) do
        defs[#defs+1] = ('`%s` %s'):format(name, typedef)
    end
    for _, name in ipairs(schema.jsonCols or {}) do
        defs[#defs+1] = ('`%s` LONGTEXT'):format(name)
    end
    defs[#defs+1] = 'PRIMARY KEY (`_id`)'
    for _, idx in ipairs(schema.indexes or {}) do
        defs[#defs+1] = ('INDEX (`%s`)'):format(idx)
    end
    return ('CREATE TABLE IF NOT EXISTS `mfw_%s` (%s) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci'):format(tbl, table.concat(defs, ', '))
end

local function ensureTable(tbl, schema)
    if _verified[tbl] then return end
    while _pending[tbl] do Wait(1) end
    if _verified[tbl] then return end
    _pending[tbl] = true
    MySQL.query.await(buildCreateSQL(tbl, schema))
    _verified[tbl] = true
    _pending[tbl] = nil
end

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    CreateThread(function()
        if DB_SCHEMAS then
            for tbl, schema in pairs(DB_SCHEMAS) do
                ensureTable(tbl, schema)
            end
        end
    end)
end)

-- Internal: row encode / decode

local function decodeRow(row, schema)
    local doc = { _id = row._id }
    for name in pairs(schema.cols) do
        doc[name] = row[name]
    end
    for _, name in ipairs(schema.jsonCols or {}) do
        local raw = row[name]
        if raw and raw ~= '' and raw ~= 'null' then
            doc[name] = json.decode(raw)
        end
    end
    return doc
end

local function buildSelect(tbl, schema)
    local parts = { '`_id`' }
    for name in pairs(schema.cols) do
        parts[#parts+1] = ('`%s`'):format(name)
    end
    for _, name in ipairs(schema.jsonCols or {}) do
        parts[#parts+1] = ('`%s`'):format(name)
    end
    return table.concat(parts, ',')
end

local function encodeField(v)
    if type(v) == 'boolean' then return v and 1 or 0 end
    return v
end

-- Internal: PULL helper — removes matching elements from a Lua array

local function applyPull(arr, match)
    if type(arr) ~= 'table' then return {} end
    local result = {}
    for _, item in ipairs(arr) do
        local matched = true
        for k, v in pairs(match) do
            if item[k] ~= v then matched = false; break end
        end
        if not matched then result[#result+1] = item end
    end
    return result
end

local function buildInsertParts(doc, schema, tblName)
    local cols, jsonCols = schemaInfo(schema)
    local names, vals = {}, {}
    for k, v in pairs(doc) do
        if k ~= '_id' then
            if cols[k] then
                names[#names+1] = ('`%s`'):format(k)
                vals[#vals+1]   = encodeField(v)
            elseif jsonCols[k] then
                names[#names+1] = ('`%s`'):format(k)
                vals[#vals+1]   = json.encode(v)
            else
                print(('[DATABASE] [WARN] Insert: field "%s" not in schema for table "%s", ignored'):format(k, tblName or '?'))
            end
        end
    end
    return names, vals
end

-- Returns setParts, setParams, pullFields (fields with PULL ops handled separately)
local function buildSetParts(fields, schema)
    local cols, jsonCols = schemaInfo(schema)
    local parts, params, pullFields = {}, {}, {}
    for k, v in pairs(fields) do
        if type(v) == 'table' and v.__op then
            if v.__op == 'push' then
                if jsonCols[k] then
                    parts[#parts+1]  = ('`%s`=JSON_ARRAY_APPEND(COALESCE(`%s`,\'[]\'),\'$\',CAST(? AS JSON))'):format(k, k)
                    params[#params+1] = json.encode(v.v)
                else
                    print(('[DATABASE] [WARN] PUSH on "%s": not a jsonCol, ignored'):format(k))
                end
            elseif v.__op == 'pull' then
                if jsonCols[k] then
                    pullFields[k] = v.v
                else
                    print(('[DATABASE] [WARN] PULL on "%s": not a jsonCol, ignored'):format(k))
                end
            end
        elseif cols[k] then
            parts[#parts+1]  = ('`%s`=?'):format(k)
            params[#params+1] = encodeField(v)
        elseif jsonCols[k] then
            parts[#parts+1]  = ('`%s`=?'):format(k)
            params[#params+1] = json.encode(v)
        else
            print(('[DATABASE] [WARN] Update: field "%s" not in schema, ignored'):format(k))
        end
    end
    return parts, params, pullFields
end

-- Internal: WHERE builder

local function buildWhere(where, schema)
    if not where or next(where) == nil then return '1=1', {} end

    local cols, jsonCols = schemaInfo(schema)
    local parts, params = {}, {}

    local function colCond(field, value)
        if type(value) == 'table' and value.__op then
            local op, v = value.__op, value.v
            if     op == 'gt'   then parts[#parts+1] = ('`%s` > ?'):format(field)                             ; params[#params+1] = v
            elseif op == 'lt'   then parts[#parts+1] = ('`%s` < ?'):format(field)                             ; params[#params+1] = v
            elseif op == 'gte'  then parts[#parts+1] = ('`%s` >= ?'):format(field)                            ; params[#params+1] = v
            elseif op == 'lte'  then parts[#parts+1] = ('`%s` <= ?'):format(field)                            ; params[#params+1] = v
            elseif op == 'ne'   then parts[#parts+1] = ('(`%s` != ? OR `%s` IS NULL)'):format(field, field)   ; params[#params+1] = v
            elseif op == 'like' then parts[#parts+1] = ('`%s` LIKE ?'):format(field)                          ; params[#params+1] = v
            elseif op == 'in'   then
                if #v == 0 then parts[#parts+1] = '0=1'; return end
                local ph = {}
                for i = 1, #v do ph[#ph+1] = '?'; params[#params+1] = v[i] end
                parts[#parts+1] = ('`%s` IN (%s)'):format(field, table.concat(ph, ','))
            end
        else
            parts[#parts+1]  = ('`%s` = ?'):format(field)
            params[#params+1] = encodeField(value)
        end
    end

    local function jsonColCond(field, value)
        if type(value) == 'table' and value.__op then
            local op, v = value.__op, value.v
            if op == 'in' then
                local orParts = {}
                for i = 1, #v do
                    orParts[#orParts+1] = ('JSON_CONTAINS(`%s`, JSON_QUOTE(?))'):format(field)
                    params[#params+1] = tostring(v[i])
                end
                if #orParts > 0 then parts[#parts+1] = '(' .. table.concat(orParts, ' OR ') .. ')' end
            elseif op == 'ne' then
                parts[#parts+1] = ('(NOT JSON_CONTAINS(`%s`, JSON_QUOTE(?)) OR `%s` IS NULL)'):format(field, field)
                params[#params+1] = tostring(v)
            end
        else
            parts[#parts+1]  = ('JSON_CONTAINS(`%s`, JSON_QUOTE(?))'):format(field)
            params[#params+1] = tostring(value)
        end
    end

    for field, value in pairs(where) do
        if field == '_id' then
            parts[#parts+1]  = '`_id` = ?'
            params[#params+1] = value
        elseif field == '__or' then
            local orParts, orParams = {}, {}
            for i = 1, #value do
                local sw, sp = buildWhere(value[i], schema)
                if sw ~= '1=1' then
                    orParts[#orParts+1] = '(' .. sw .. ')'
                    for j = 1, #sp do orParams[#orParams+1] = sp[j] end
                end
            end
            if #orParts > 0 then
                parts[#parts+1] = '(' .. table.concat(orParts, ' OR ') .. ')'
                for i = 1, #orParams do params[#params+1] = orParams[i] end
            end
        elseif type(value) == 'table' and value.__op == 'or' then
            local orParts, orParams = {}, {}
            local subs = value.v
            for i = 1, #subs do
                local sw, sp = buildWhere(subs[i], schema)
                if sw ~= '1=1' then
                    orParts[#orParts+1] = '(' .. sw .. ')'
                    for j = 1, #sp do orParams[#orParams+1] = sp[j] end
                end
            end
            if #orParts > 0 then
                parts[#parts+1] = '(' .. table.concat(orParts, ' OR ') .. ')'
                for i = 1, #orParams do params[#params+1] = orParams[i] end
            end
        elseif cols[field] then
            colCond(field, value)
        elseif jsonCols[field] then
            jsonColCond(field, value)
        else
            print(('[DATABASE] [WARN] WHERE: field "%s" not in schema, condition skipped'):format(field))
        end
    end

    return #parts > 0 and table.concat(parts, ' AND ') or '1=1', params
end

-- Internal: async helper

local function exec(cb, fn)
    if type(cb) == 'function' then
        fn(cb)
    else
        local p = promise.new()
        fn(function(r) p:resolve(r) end)
        return Citizen.Await(p)
    end
end

-- Component

_DATABASE = {

    -- Operators
    GT   = function(v)   return { __op = 'gt',   v = v    } end,
    LT   = function(v)   return { __op = 'lt',   v = v    } end,
    GTE  = function(v)   return { __op = 'gte',  v = v    } end,
    LTE  = function(v)   return { __op = 'lte',  v = v    } end,
    NE   = function(v)   return { __op = 'ne',   v = v    } end,
    IN   = function(t)   return { __op = 'in',   v = t    } end,
    LIKE = function(v)   return { __op = 'like', v = v    } end,
    OR   = function(...) return { __op = 'or',   v = {...} } end,
    PUSH = function(v)   return { __op = 'push', v = v    } end,
    PULL = function(v)   return { __op = 'pull', v = v    } end,

    -- Find
    Find = function(self, tbl, where, opts, cb)
        if type(opts) == 'function' then cb, opts = opts, nil end
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Find')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local w, params = buildWhere(where or {}, schema)
            local sql = ('SELECT %s FROM `mfw_%s` WHERE %s'):format(buildSelect(tbl, schema), tbl, w)
            if opts and opts.sort then
                sql = sql .. (' ORDER BY `%s` %s'):format(opts.sort.field, opts.sort.dir or 'ASC')
            end
            if opts and opts.limit then
                sql = sql .. (' LIMIT %d'):format(opts.limit)
            end
            if opts and opts.offset then
                sql = sql .. (' OFFSET %d'):format(opts.offset)
            end
            MySQL.query(sql, params, function(rows)
                if not rows then
                    print(('[DATABASE] [ERROR] Find failed on table "%s"'):format(tbl))
                    done(nil) return
                end
                local out = {}
                for _, r in ipairs(rows) do out[#out+1] = decodeRow(r, schema) end
                done(out)
            end)
        end)
    end,

    -- FindOne
    FindOne = function(self, tbl, where, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'FindOne')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local w, params = buildWhere(where or {}, schema)
            MySQL.query(('SELECT %s FROM `mfw_%s` WHERE %s LIMIT 1'):format(buildSelect(tbl, schema), tbl, w), params, function(rows)
                if not rows then
                    print(('[DATABASE] [ERROR] FindOne failed on table "%s"'):format(tbl))
                    done(nil) return
                end
                done(rows[1] and decodeRow(rows[1], schema) or nil)
            end)
        end)
    end,

    -- FindById
    FindById = function(self, tbl, id, cb)
        return self:FindOne(tbl, { _id = id }, cb)
    end,

    -- FindOneAndUpdate
    FindOneAndUpdate = function(self, tbl, where, fields, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'FindOneAndUpdate')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local w, wParams = buildWhere(where or {}, schema)
            MySQL.query(('SELECT `_id` FROM `mfw_%s` WHERE %s LIMIT 1'):format(tbl, w), wParams, function(rows)
                if not rows or #rows == 0 then done(nil) return end
                local id = rows[1]._id
                local setParts, setParams, pullFields = buildSetParts(fields, schema)
                local function doUpdate(extraParts, extraParams)
                    local allParts  = {}
                    local allParams = {}
                    for i = 1, #setParts    do allParts[#allParts+1]   = setParts[i]    end
                    for i = 1, #extraParts  do allParts[#allParts+1]   = extraParts[i]  end
                    for i = 1, #setParams   do allParams[#allParams+1] = setParams[i]   end
                    for i = 1, #extraParams do allParams[#allParams+1] = extraParams[i] end
                    if #allParts == 0 then done(nil) return end
                    allParams[#allParams+1] = id
                    MySQL.query(('UPDATE `mfw_%s` SET %s WHERE `_id`=?'):format(tbl, table.concat(allParts, ',')), allParams, function(r)
                        if not r then done(nil) return end
                        MySQL.query(('SELECT %s FROM `mfw_%s` WHERE `_id`=?'):format(buildSelect(tbl, schema), tbl), { id }, function(updated)
                            done(updated and updated[1] and decodeRow(updated[1], schema) or nil)
                        end)
                    end)
                end
                if next(pullFields) then
                    MySQL.query(('SELECT %s FROM `mfw_%s` WHERE `_id`=?'):format(buildSelect(tbl, schema), tbl), { id }, function(docRows)
                        if not docRows or #docRows == 0 then done(nil) return end
                        local doc = decodeRow(docRows[1], schema)
                        local pullParts, pullParams = {}, {}
                        for field, match in pairs(pullFields) do
                            pullParts[#pullParts+1]  = ('`%s`=?'):format(field)
                            pullParams[#pullParams+1] = json.encode(applyPull(doc[field], match))
                        end
                        doUpdate(pullParts, pullParams)
                    end)
                else
                    doUpdate({}, {})
                end
            end)
        end)
    end,

    -- Create
    Create = function(self, tbl, doc, cb)
        if type(cb) == 'function' then
            if doc[1] then
                local results, failed = {}, false
                for i = 1, #doc do
                    self:Insert(tbl, doc[i], function(r)
                        if r then results[#results+1] = r else failed = true end
                    end)
                end
                cb(failed and nil or results)
            else
                self:Insert(tbl, doc, cb)
            end
            return
        end
        if doc[1] then
            local results = {}
            for i = 1, #doc do
                local r = self:Insert(tbl, doc[i])
                if not r then return nil end
                results[#results+1] = r
            end
            return results
        end
        return self:Insert(tbl, doc)
    end,

    -- Insert
    Insert = function(self, tbl, doc, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Insert')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local names, vals = buildInsertParts(doc, schema, tbl)
            if #names == 0 then
                print(('[DATABASE] [ERROR] Insert on "%s" — no valid fields in document'):format(tbl))
                done(nil) return
            end
            local ph = {}
            for i = 1, #vals do ph[#ph+1] = '?' end
            MySQL.query(('INSERT INTO `mfw_%s` (%s) VALUES (%s)'):format(tbl, table.concat(names, ','), table.concat(ph, ',')), vals, function(r)
                if not r then
                    print(('[DATABASE] [ERROR] Insert failed on table "%s"'):format(tbl))
                    done(nil) return
                end
                local result = {}
                for k, v in pairs(doc) do result[k] = v end
                result._id = r.insertId
                done(result)
            end)
        end)
    end,

    -- Update
    Update = function(self, tbl, where, fields, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Update')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local setParts, setParams, pullFields = buildSetParts(fields, schema)

            if next(pullFields) then
                local w, wParams = buildWhere(where or {}, schema)
                MySQL.query(('SELECT %s FROM `mfw_%s` WHERE %s'):format(buildSelect(tbl, schema), tbl, w), wParams, function(rows)
                    if not rows or #rows == 0 then done(0) return end
                    local remaining = #rows
                    local affected  = 0
                    for _, row in ipairs(rows) do
                        local doc       = decodeRow(row, schema)
                        local allParts  = {}
                        local allParams = {}
                        for i = 1, #setParts  do allParts[#allParts+1]   = setParts[i]  end
                        for i = 1, #setParams do allParams[#allParams+1] = setParams[i] end
                        for field, match in pairs(pullFields) do
                            allParts[#allParts+1]   = ('`%s`=?'):format(field)
                            allParams[#allParams+1] = json.encode(applyPull(doc[field], match))
                        end
                        allParams[#allParams+1] = row._id
                        MySQL.query(('UPDATE `mfw_%s` SET %s WHERE `_id`=?'):format(tbl, table.concat(allParts, ',')), allParams, function(r)
                            if r then affected = affected + (r.affectedRows or 0) end
                            remaining = remaining - 1
                            if remaining == 0 then done(affected) end
                        end)
                    end
                end)
                return
            end

            if #setParts == 0 then
                print(('[DATABASE] [ERROR] Update on "%s" — no valid fields to set'):format(tbl))
                done(0) return
            end
            local w, wParams = buildWhere(where or {}, schema)
            for i = 1, #wParams do setParams[#setParams+1] = wParams[i] end
            MySQL.query(('UPDATE `mfw_%s` SET %s WHERE %s'):format(tbl, table.concat(setParts, ','), w), setParams, function(r)
                if not r then
                    print(('[DATABASE] [ERROR] Update failed on table "%s"'):format(tbl))
                    done(nil) return
                end
                done(r.affectedRows or 0)
            end)
        end)
    end,

    -- Upsert
    Upsert = function(self, tbl, where, fields, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Upsert')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local w, params = buildWhere(where or {}, schema)
            MySQL.query(('SELECT `_id` FROM `mfw_%s` WHERE %s LIMIT 1'):format(tbl, w), params, function(rows)
                if rows and #rows > 0 then
                    local setParts, setParams = buildSetParts(fields, schema)
                    setParams[#setParams+1] = rows[1]._id
                    MySQL.query(('UPDATE `mfw_%s` SET %s WHERE `_id`=?'):format(tbl, table.concat(setParts, ',')), setParams, function(r)
                        if not r then
                            print(('[DATABASE] [ERROR] Upsert (update) failed on "%s"'):format(tbl))
                            done(nil) return
                        end
                        local result = {}
                        for k, v in pairs(fields) do result[k] = v end
                        result._id = rows[1]._id
                        done(result)
                    end)
                else
                    local doc = {}
                    for k, v in pairs(where)  do if type(k) == 'string' then doc[k] = v end end
                    for k, v in pairs(fields) do doc[k] = v end
                    local names, vals = buildInsertParts(doc, schema, tbl)
                    local ph = {}
                    for i = 1, #vals do ph[#ph+1] = '?' end
                    MySQL.query(('INSERT INTO `mfw_%s` (%s) VALUES (%s)'):format(tbl, table.concat(names, ','), table.concat(ph, ',')), vals, function(r)
                        if not r then
                            print(('[DATABASE] [ERROR] Upsert (insert) failed on "%s"'):format(tbl))
                            done(nil) return
                        end
                        local result = {}
                        for k, v in pairs(doc) do result[k] = v end
                        result._id = r.insertId
                        done(result)
                    end)
                end
            end)
        end)
    end,

    -- Delete
    Delete = function(self, tbl, where, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Delete')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local w, params = buildWhere(where or {}, schema)
            MySQL.query(('DELETE FROM `mfw_%s` WHERE %s'):format(tbl, w), params, function(r)
                if not r then
                    print(('[DATABASE] [ERROR] Delete failed on table "%s"'):format(tbl))
                    done(nil) return
                end
                done(r.affectedRows or 0)
            end)
        end)
    end,

    -- Count
    Count = function(self, tbl, where, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Count')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local w, params = buildWhere(where or {}, schema)
            MySQL.scalar(('SELECT COUNT(*) FROM `mfw_%s` WHERE %s'):format(tbl, w), params, function(n)
                done(n or 0)
            end)
        end)
    end,

    -- Exists
    Exists = function(self, tbl, where, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Exists')
            if not schema then done(false) return end
            ensureTable(tbl, schema)
            local w, params = buildWhere(where or {}, schema)
            MySQL.scalar(('SELECT 1 FROM `mfw_%s` WHERE %s LIMIT 1'):format(tbl, w), params, function(n)
                done(n == 1)
            end)
        end)
    end,

    -- Sum
    Sum = function(self, tbl, where, field, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Sum')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local cols = {}
            for name in pairs(schema.cols) do cols[name] = true end
            if not cols[field] then
                print(('[DATABASE] [ERROR] Sum on "%s": field "%s" is not a scalar column'):format(tbl, field))
                done(nil) return
            end
            local w, params = buildWhere(where or {}, schema)
            MySQL.scalar(('SELECT COALESCE(SUM(`%s`), 0) FROM `mfw_%s` WHERE %s'):format(field, tbl, w), params, function(n)
                done(n or 0)
            end)
        end)
    end,

    -- Increment
    Increment = function(self, tbl, where, field, amount, cb)
        return exec(cb, function(done)
            local schema = requireSchema(tbl, 'Increment')
            if not schema then done(nil) return end
            ensureTable(tbl, schema)
            local cols = {}
            for name in pairs(schema.cols) do cols[name] = true end
            if not cols[field] then
                print(('[DATABASE] [ERROR] Increment on "%s": field "%s" is not a scalar column'):format(tbl, field))
                done(nil) return
            end
            local w, wParams = buildWhere(where or {}, schema)
            local updateParams = { amount }
            for i = 1, #wParams do updateParams[#updateParams+1] = wParams[i] end
            MySQL.query(('UPDATE `mfw_%s` SET `%s`=`%s`+? WHERE %s'):format(tbl, field, field, w), updateParams, function(r)
                if not r or r.affectedRows == 0 then
                    print(('[DATABASE] [ERROR] Increment failed on "%s"."%s"'):format(tbl, field))
                    done(nil) return
                end
                MySQL.scalar(('SELECT `%s` FROM `mfw_%s` WHERE %s LIMIT 1'):format(field, tbl, w), wParams, function(val)
                    done(val)
                end)
            end)
        end)
    end,

    -- Raw
    Raw = function(self, sql, params, cb)
        if type(params) == 'function' then cb, params = params, {} end
        return exec(cb, function(done)
            MySQL.query(sql, params or {}, function(result)
                done(result)
            end)
        end)
    end,
}

-- Make COMPONENTS.Database available before Core:Shared:Ready fires
-- so internal mythic-base scripts (sv_data, sv_init) can use it directly
CreateThread(function()
    while COMPONENTS == nil do Wait(1) end
    COMPONENTS.Database = _DATABASE
end)

AddEventHandler('Proxy:Shared:RegisterReady', function()
    exports['mythic-base']:RegisterComponent('Database', _DATABASE)
end)
