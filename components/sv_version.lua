local _pending    = {}
local _registered = {}
local _queued     = 0
local _running    = false
local _startTime  = nil

local function PrintReport()
  if #_pending == 0 then
    _running = false
    return
  end

  local outdated  = {}
  local errors    = {}
  for i = 1, #_pending do
    local d = _pending[i]
    if d.status == 'outdated' then outdated[#outdated + 1] = d
    elseif d.status == 'error' then errors[#errors + 1] = d end
  end

  table.sort(outdated, function(a, b) return a.name < b.name end)
  table.sort(errors,   function(a, b) return a.name < b.name end)

  local n_out = #outdated
  local n_err = #errors

  COMPONENTS.Logger:Info('Version', '')
  COMPONENTS.Logger:Info('Version', '^5=======================================================^0')
  COMPONENTS.Logger:Info('Version', '^5          MYTHIC FRAMEWORK — VERSION REPORT         ^0')
  COMPONENTS.Logger:Info('Version', '^5=======================================================^0')

  if n_out == 0 and n_err == 0 then
    COMPONENTS.Logger:Info('Version', ('^2  ✓  All %d resources are up to date!^0'):format(#_pending))
  else
    for i = 1, n_out do
      local d = outdated[i]
      COMPONENTS.Logger:Warn('Version', ('  ^1✗^0  %-30s ^1%s^0 → ^2%s^0  ^3%s^0'):format(d.name, d.current, d.newest, d.repoUrl))
    end
    for i = 1, n_err do
      local d = errors[i]
      COMPONENTS.Logger:Warn('Version', ('  ^3?^0  %-30s ^3Unable to check^0'):format(d.name))
    end
    COMPONENTS.Logger:Info('Version', '^5-----------------------------------------------------^0')
    COMPONENTS.Logger:Info('Version', ('^2  ✓  %d up to date^0   ^1✗  %d outdated^0   ^3?  %d unable to check^0'):format(#_pending - n_out - n_err, n_out, n_err))
  end

  COMPONENTS.Logger:Info('Version', '^5=======================================================^0')
  COMPONENTS.Logger:Info('Version', '')

  _pending   = {}
  _queued    = 0
  _running   = false
  _startTime = nil
end

COMPONENTS.Version = {
  _protected = true,
  _required = { 'Check' },
  _name = 'base',

  ---Used this so we dont print all over the damm console - clean and only runs once 
  ---@param repo string GitHub repo e.g. Mythic-Framework/Mythic-VersionCheckers
  ---@param resource string Must be passed explicitly — GetCurrentResourceName() resolves to mythic-base inside this component
  Check = function(self, repo, resource)
    if not resource then return end
    if _registered[resource] then return end
    _registered[resource] = true
    _queued = _queued + 1

    if not _running then
      _startTime = GetGameTimer()
      _running   = true
      Citizen.CreateThread(function()
        while true do
          local snapshot = _queued
          Citizen.Wait(4000)
          -- Require at least 8s since first Check() so late-starting resources can join the batch
          local elapsed = GetGameTimer() - _startTime
          if elapsed >= 8000 and _queued == snapshot and #_pending >= _queued then
            PrintReport()
            return
          end
        end
      end)
    end

    local repoUrl = GetResourceMetadata(resource, 'repository', 0) or ('https://github.com/%s'):format(repo)
    local current = (GetResourceMetadata(resource, 'version', 0) or ''):gsub('%s+', ''):gsub('^v', '')
    local name    = resource:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)
    local url     = ('https://raw.githubusercontent.com/%s/main/%s.txt'):format(repo, resource)

    PerformHttpRequest(url, function(statusCode, body)
      local entry = { name = name, current = current, repoUrl = repoUrl, status = 'error' }
      if statusCode == 200 and body then
        entry.newest = body:gsub('%s+', '')
        entry.status = entry.newest == current and 'ok' or 'outdated'
      end
      _pending[#_pending + 1] = entry
    end)
  end,
}

--- Treys toes told me it was time 😆