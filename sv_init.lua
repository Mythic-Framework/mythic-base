AddEventHandler("Core:Shared:Ready", function()
	COMPONENTS.Default:AddAuth('roles', 1662066295, {
		{ Abv = "Whitelisted", Name = "Whitelisted", QueuePriority = 0, QueueMessage = "",  PermLevel = 0,   PermGroup = ""      },
		{ Abv = "Staff",       Name = "Staff",       QueuePriority = 0, QueueMessage = "",  PermLevel = 50,  PermGroup = "staff" },
		{ Abv = "Admin",       Name = "Admin",       QueuePriority = 0, QueueMessage = "",  PermLevel = 75,  PermGroup = "admin" },
		{ Abv = "Owner",       Name = "Owner",       QueuePriority = 0, QueueMessage = "",  PermLevel = 100, PermGroup = "admin" },
	})

	local results = COMPONENTS.Database:Find('roles', {})
	if not results or #results == 0 then
		COMPONENTS.Logger:Critical("Core", "Failed to Load User Groups", {
			console = true,
			file = true,
		})
		return
	end

	COMPONENTS.Config.Groups = {}
	for k, v in ipairs(results) do
		COMPONENTS.Config.Groups[v.Abv] = v
	end

	COMPONENTS.Logger:Info("Core", string.format("Loaded %s User Groups", #results), {
		console = true,
	})

	COMPONENTS.Version:Check('Mythic-Framework/Mythic-VersionCheckers', 'mythic-base')
end)
