local function CheckVersion()
    PerformHttpRequest('https://raw.githubusercontent.com/Mythic-Framework/Mythic-VersionCheckers/main/mythic-base.txt', function(err, newestVersion, headers)
        local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')
        local resourceName = GetCurrentResourceName():gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)

        if not newestVersion then
            print('^3[' .. resourceName .. ']^0 Unable to perform version check.')
            return
        end

        local isLatestVersion = newestVersion:gsub('%s+', '') == currentVersion:gsub('%s+', '')
        if isLatestVersion then
            print(('^5[%s]^0 Running latest version (^2%s^0)'):format(resourceName, currentVersion))
        else
            print('')
            print('^5=======================================================^0')
            print(('^5  %s^0'):format(resourceName))
            print('^5=======================================================^0')
            print('^1  UPDATE AVAILABLE^0')
            print('')
            print(('  Installed:  ^1%s^0'):format(currentVersion))
            print(('  Latest:     ^2%s^0'):format(newestVersion:gsub('%s+', '')))
            print('')
            print('  Update Now: ^3https://github.com/Mythic-Framework/mythic-base^0')
            print('^5=======================================================^0')
            print('')
        end
    end)
end

CheckVersion()
