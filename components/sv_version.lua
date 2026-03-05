COMPONENTS.Version = {
  _protected = true,
  _required = { "Check" },
  _name = "base",

  ---Checks the version of the invoking resource
  ---@param repo string (GitHub repo, e.g. Mythic-Framework/mythic-base)
  Check = function(self, repo, resource)
    resource = resource or GetInvokingResource() or GetCurrentResourceName()

    local versionUrl = ("https://raw.githubusercontent.com/%s/main/%s.txt"):format(repo, resource)
    local repoUrl = ("https://github.com/%s"):format(repo)

    PerformHttpRequest(versionUrl, function(err, newestVersion)
      local currentVersion = GetResourceMetadata(resource, "version", 0)
      local resourceRepo = GetResourceMetadata(resource, "repository", 0)

      local resourceName = resource:gsub("(%a)([%w]*)", function(a, b)
        return a:upper() .. b
      end)

      if not newestVersion then
        COMPONENTS.Logger:Warn("Version", ("[%s] Unable to perform version check"):format(resourceName))
        return
      end

      local newest = (newestVersion or ""):gsub("%s+", "")
      local current = (currentVersion or ""):gsub("%s+", "")

      if newest == current then
        COMPONENTS.Logger:Info(
          "Version",
          ("^5[%s]^0 Running latest version (^2%s^0)"):format(resourceName, current)
        )
      else
        COMPONENTS.Logger:Warn("Version", "")
        COMPONENTS.Logger:Warn("Version", "^5=======================================================^0")
        COMPONENTS.Logger:Warn("Version", ("^5  %s^0"):format(resourceName))
        COMPONENTS.Logger:Warn("Version", "^5=======================================================^0")
        COMPONENTS.Logger:Warn("Version", "^1  UPDATE AVAILABLE^0")
        COMPONENTS.Logger:Warn("Version", "")
        COMPONENTS.Logger:Warn("Version", ("  Installed:  ^1%s^0"):format(current))
        COMPONENTS.Logger:Warn("Version", ("  Latest:     ^2%s^0"):format(newest))
        COMPONENTS.Logger:Warn("Version", "")
        COMPONENTS.Logger:Warn("Version", ("  Update Now: ^3%s^0"):format(resourceRepo or repoUrl))
        COMPONENTS.Logger:Warn("Version", "^5=======================================================^0")
        COMPONENTS.Logger:Warn("Version", "")
      end
    end)
  end
}
