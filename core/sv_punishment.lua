COMPONENTS.Punishment = {
	_required = { "CheckBan", "Kick", "Unban", "Ban" },
	_name = "base",
	CheckBan = function(self, key, value)
		local result = COMPONENTS.Database:FindOne('bans', { [key] = value, active = true })
		if not result then return nil end
		if result.expires ~= -1 and result.expires < os.time() then
			COMPONENTS.Database:Update('bans', { _id = result._id }, { active = false })
			return nil
		end
		return result
	end,
	Kick = function(self, source, reason, issuer)
		local tPlayer = COMPONENTS.Fetch:Source(source)

		if not tPlayer then
			return { success = false }
		end

		if issuer ~= "Pwnzor" then
			if source == issuer then
				return { success = false, message = "Cannot Ban Yourself!" }
			end

			local iPlayer = COMPONENTS.Fetch:Source(issuer)
			if not iPlayer then
				return { success = false }
			end

			if iPlayer.Permissions:GetLevel() <= tPlayer.Permissions:GetLevel() then
				return { success = false, message = "Insufficient Permissions" }
			end

			COMPONENTS.Punishment.Actions:Kick(source, reason, iPlayer:GetData("Name"))

			COMPONENTS.Logger:Info(
				"Punishment",
				string.format("%s [%s] Kicked By %s [%s] For %s",
					tPlayer:GetData("Name"), tPlayer:GetData("AccountID"),
					iPlayer:GetData("Name"), iPlayer:GetData("AccountID"), reason),
				{ console = true, file = true, database = true, discord = { embed = true, type = "inform" } },
				{ account = tPlayer:GetData("AccountID"), identifier = tPlayer:GetData("Identifier"), reason = reason,
				  issuer = string.format("%s [%s]", iPlayer:GetData("Name"), iPlayer:GetData("AccountID")) }
			)

			return { success = true, Name = tPlayer:GetData("Name"), AccountID = tPlayer:GetData("AccountID"), reason = reason }
		else
			COMPONENTS.Punishment.Actions:Kick(source, reason, issuer)

			COMPONENTS.Logger:Info(
				"Punishment",
				string.format("%s [%s] Kicked By %s For %s",
					tPlayer:GetData("Name"), tPlayer:GetData("AccountID"), issuer, reason),
				{ console = true, file = true, database = true, discord = { embed = true, type = "inform", webhook = GetConvar("discord_pwnzor_webhook", "") } },
				{ account = tPlayer:GetData("AccountID"), identifier = tPlayer:GetData("Identifier"), reason = reason, issuer = issuer }
			)

			return { success = true, Name = tPlayer:GetData("Name"), AccountID = tPlayer:GetData("AccountID"), reason = reason }
		end
	end,
}

COMPONENTS.Punishment.Unban = {
	BanID = function(self, id, issuer)
		if COMPONENTS.Punishment:CheckBan("_id", id) then
			local iPlayer = COMPONENTS.Fetch:Source(issuer)
			local results = COMPONENTS.Database:Find('bans', { _id = id, active = true })
			if COMPONENTS.Punishment.Actions:Unban(results, iPlayer) then
				COMPONENTS.Chat.Send.Server:Single(iPlayer:GetData("Source"), string.format("%s Has Been Revoked", id))
			end
		end
	end,
	AccountID = function(self, aId, issuer)
		if COMPONENTS.Punishment:CheckBan("account", aId) then
			local tPlayer = COMPONENTS.Fetch:PlayerData("AccountID", aId)
			local dbf = false
			if tPlayer == nil then
				tPlayer = COMPONENTS.Fetch:Website("account", aId)
				dbf = true
			end
			local iPlayer = COMPONENTS.Fetch:Source(issuer)
			local results = COMPONENTS.Database:Find('bans', { account = aId, active = true })
			if COMPONENTS.Punishment.Actions:Unban(results, iPlayer) then
				COMPONENTS.Chat.Send.Server:Single(
					iPlayer:GetData("Source"),
					string.format("%s (Account: %s) Has Been Unbanned", tPlayer:GetData("Name"), tPlayer:GetData("AccountID"))
				)
			end
			if dbf then tPlayer:DeleteStore() end
		else
			local iPlayer = COMPONENTS.Fetch:Source(issuer)
			local tPlayer = COMPONENTS.Fetch:PlayerData("AccountID", aId)
			COMPONENTS.Chat.Send.Server:Single(
				iPlayer:GetData("Source"),
				string.format("%s (Account: %s) Is Not Banned", tPlayer and tPlayer:GetData("Name") or "Unknown", aId)
			)
		end
	end,
	Identifier = function(self, identifier, issuer)
		if COMPONENTS.Punishment:CheckBan("identifier", identifier) then
			local tPlayer = COMPONENTS.Fetch:PlayerData("Identifier", identifier)
			local dbf = false
			if tPlayer == nil then
				tPlayer = COMPONENTS.Fetch:Website("identifier", identifier)
				dbf = true
			end
			local iPlayer = COMPONENTS.Fetch:Source(issuer)
			local results = COMPONENTS.Database:Find('bans', { identifier = identifier, active = true })
			if COMPONENTS.Punishment.Actions:Unban(results, iPlayer) then
				COMPONENTS.Chat.Send.Server:Single(
					iPlayer:GetData("Source"),
					string.format("%s (Identifier: %s) Has Been Unbanned", tPlayer:GetData("Name"), tPlayer:GetData("Identifier"))
				)
			end
			if dbf then tPlayer:DeleteStore() end
		else
			local iPlayer = COMPONENTS.Fetch:Source(issuer)
			local tPlayer = COMPONENTS.Fetch:PlayerData("Identifier", identifier)
			COMPONENTS.Chat.Send.Server:Single(
				iPlayer:GetData("Source"),
				string.format("%s (Identifier: %s) Is Not Banned", tPlayer and tPlayer:GetData("Name") or "Unknown", identifier)
			)
		end
	end,
}

COMPONENTS.Punishment.Ban = {
	Source = function(self, source, expires, reason, issuer)
		local tPlayer = COMPONENTS.Fetch:Source(source)
		local iPlayer

		if not tPlayer then
			return { success = false }
		end

		if issuer ~= "Pwnzor" then
			if source == issuer then
				return { success = false, message = "Cannot Ban Yourself!" }
			end

			iPlayer = COMPONENTS.Fetch:Source(issuer)
			if not iPlayer then return { success = false } end

			if iPlayer.Permissions:GetLevel() < tPlayer.Permissions:GetLevel() then
				return { success = false, message = "Insufficient Permissions" }
			end

			issuer = string.format("%s [%s]", iPlayer:GetData("Name"), iPlayer:GetData("AccountID"))
		end

		local expStr = "Never"
		if expires ~= -1 then
			expires = (os.time() + ((60 * 60 * 24) * expires))
			expStr = os.date("%Y-%m-%d at %I:%M:%S %p", expires)
		end

		local banStr = expires == -1
			and string.format("%s Was Permanently Banned By %s for %s", tPlayer:GetData("Name"), issuer, reason)
			or  string.format("%s Was Banned By %s Until %s for %s", tPlayer:GetData("Name"), issuer, expStr, reason)

		local result = COMPONENTS.Punishment.Actions:Ban(
			tPlayer:GetData("Source"), tPlayer:GetData("AccountID"), tPlayer:GetData("Identifier"),
			tPlayer:GetData("Name"), tPlayer:GetData("Tokens"), reason, expires, expStr, issuer,
			iPlayer and iPlayer:GetData("AccountID") or -1, false
		)

		if result then
			COMPONENTS.Logger:Info("Punishment", banStr,
				{ console = true, file = true, database = true, discord = { embed = true, type = "info" } },
				{ player = tPlayer:GetData("Name"), identifier = tPlayer:GetData("Identifier"), reason = reason, issuer = issuer, expires = expStr }
			)
		end

		return { success = result ~= false, Name = tPlayer:GetData("Name"), AccountID = tPlayer:GetData("AccountID"), expires = expires, reason = reason, banStr = banStr }
	end,
	AccountID = function(self, aId, expires, reason, issuer)
		local iPlayer = COMPONENTS.Fetch:Source(issuer)
		if not iPlayer then return { success = false } end

		if iPlayer:GetData("AccountID") == tonumber(aId) then
			return { success = false, message = "Cannot Ban Yourself!" }
		end

		local tPlayer = COMPONENTS.Fetch:PlayerData("AccountID", tonumber(aId))
		issuer = string.format("%s [%s]", iPlayer:GetData("Name"), iPlayer:GetData("AccountID"))

		local dbf = false
		if tPlayer == nil then
			tPlayer = COMPONENTS.Fetch:Website("account", tonumber(aId))
			dbf = true
		end

		local expStr = "Never"
		if expires ~= -1 then
			expires = (os.time() + ((60 * 60 * 24) * expires))
			expStr = os.date("%Y-%m-%d at %I:%M:%S %p", expires)
		end

		local banStr = expires == -1
			and string.format("%s (Account: %s) Was Permanently Banned By %s. Reason: %s",
				tPlayer and tPlayer:GetData("Name") or "Unknown", aId, issuer, reason)
			or  string.format("%s (Account: %s) Was Banned By %s Until %s. Reason: %s",
				tPlayer and tPlayer:GetData("Name") or "Unknown", aId, issuer, expStr, reason)

		local tPerms = 0
		if tPlayer then
			for _, v in ipairs(tPlayer:GetData("Groups") or {}) do
				local g = COMPONENTS.Config.Groups[tostring(v)]
				if g and g.PermLevel > tPerms then tPerms = g.PermLevel end
			end
		else
			tPerms = 99
		end

		if iPlayer.Permissions:GetLevel() <= tPerms then
			return { success = false, message = "Insufficient Permissions" }
		end

		if COMPONENTS.Punishment.Actions:Ban(
			tPlayer and tPlayer:GetData("Source") or nil, tonumber(aId),
			tPlayer and tPlayer:GetData("Identifier") or nil,
			tPlayer and tPlayer:GetData("Name") or tostring(aId),
			tPlayer and tPlayer:GetData("Tokens") or {}, reason, expires, expStr, issuer,
			iPlayer:GetData("AccountID"), false
		) then
			COMPONENTS.Logger:Info("Punishment", banStr,
				{ console = true, file = true, database = true, discord = { embed = true, type = "info" } },
				{ account = tonumber(aId), reason = reason, issuer = issuer, expires = expStr }
			)
			if dbf and tPlayer then tPlayer:DeleteStore() end
			return { success = true, AccountID = tonumber(aId), reason = reason, expires = expires, banStr = banStr }
		end
	end,
	Identifier = function(self, identifier, expires, reason, issuer)
		local iPlayer = COMPONENTS.Fetch:Source(issuer)
		if not iPlayer then return { success = false } end

		if iPlayer:GetData("Identifier") == identifier then
			return { success = false, message = "Cannot Ban Yourself!" }
		end

		local tPlayer = COMPONENTS.Fetch:PlayerData("Identifier", identifier)
		issuer = string.format("%s [%s]", iPlayer:GetData("Name"), iPlayer:GetData("AccountID"))

		local dbf = false
		if tPlayer == nil then
			tPlayer = COMPONENTS.Fetch:Website("identifier", identifier)
			dbf = true
		end

		local expStr = "Never"
		if expires ~= -1 then
			expires = (os.time() + ((60 * 60 * 24) * expires))
			expStr = os.date("%Y-%m-%d at %I:%M:%S %p", expires)
		end

		local banStr = expires == -1
			and string.format("%s (Identifier: %s) Was Permanently Banned By %s. Reason: %s",
				tPlayer and tPlayer:GetData("Name") or "Unknown", identifier, issuer, reason)
			or  string.format("%s (Identifier: %s) Was Banned By %s Until %s. Reason: %s",
				tPlayer and tPlayer:GetData("Name") or "Unknown", identifier, issuer, expStr, reason)

		local tPerms = 0
		for _, v in ipairs(tPlayer and tPlayer:GetData("Groups") or {}) do
			local g = COMPONENTS.Config.Groups[tostring(v)]
			if g and g.PermLevel > tPerms then tPerms = g.PermLevel end
		end

		if iPlayer.Permissions:GetLevel() <= tPerms then
			return { success = false, message = "Insufficient Permissions" }
		end

		if COMPONENTS.Punishment.Actions:Ban(
			tPlayer and tPlayer:GetData("Source") or nil,
			tPlayer and tPlayer:GetData("AccountID") or nil,
			identifier,
			tPlayer and tPlayer:GetData("Name") or identifier,
			tPlayer and tPlayer:GetData("Tokens") or {}, reason, expires, expStr, issuer,
			iPlayer:GetData("AccountID"), false
		) then
			COMPONENTS.Logger:Info("Punishment", banStr,
				{ console = true, file = true, database = true, discord = { embed = true, type = "info" } },
				{ identifier = identifier, reason = reason, issuer = issuer, expires = expStr }
			)
			if dbf and tPlayer then tPlayer:DeleteStore() end
			return { success = true, Identifier = identifier, reason = reason, expires = expires, banStr = banStr }
		end
	end,
}

COMPONENTS.Punishment.Actions = {
	Kick = function(self, tSource, reason, issuer)
		DropPlayer(tSource, string.format("Kicked From The Server By %s\nReason: %s", issuer, reason))
	end,
	Ban = function(self, tSource, tAccount, tIdentifier, tName, tTokens, reason, expires, expStr, issuer, issuerId, mask)
		-- Find existing active ban by account or identifier
		local existing = nil
		if tAccount then
			existing = COMPONENTS.Database:FindOne('bans', { account = tAccount, active = true })
		end
		if not existing and tIdentifier then
			existing = COMPONENTS.Database:FindOne('bans', { identifier = tIdentifier, active = true })
		end

		-- Merge token sets
		local mergedTokens = {}
		local tokenSet = {}
		for _, t in ipairs(tTokens or {}) do tokenSet[t] = true end
		if existing and existing.tokens then
			for _, t in ipairs(existing.tokens) do tokenSet[t] = true end
		end
		for t in pairs(tokenSet) do mergedTokens[#mergedTokens + 1] = t end

		local banDoc = {
			account    = tAccount,
			identifier = tIdentifier,
			expires    = expires,
			reason     = reason,
			issuer     = issuer,
			active     = true,
			started    = os.time(),
			tokens     = mergedTokens,
		}

		local result
		if existing then
			COMPONENTS.Database:Update('bans', { _id = existing._id }, banDoc)
			result = existing
		else
			result = COMPONENTS.Database:Insert('bans', banDoc)
		end

		if not result then return false end

		local data = COMPONENTS.WebAPI:Request("POST", "admin/ban", {
			account    = tAccount,
			identifier = tIdentifier,
			duration   = expires,
			issuer     = issuerId,
		}, {})
		if data.code ~= 200 then
			COMPONENTS.Logger:Info("Punishment", ("Failed To Ban Account %s On Website"):format(tAccount),
				{ console = true, discord = { embed = true, type = "error" } })
		end

		if mask then reason = "💙 From Pwnzor 🙂" end

		if tSource ~= nil then
			if expires ~= -1 then
				DropPlayer(tSource, string.format(
					"You're Banned, Appeal At https://mythicrp.com/\n\nReason: %s\nExpires: %s\nID: %s",
					reason, expStr, result._id))
			else
				DropPlayer(tSource, string.format(
					"You're Permanently Banned, Appeal At https://mythicrp.com/\n\nReason: %s\nID: %s",
					reason, result._id))
			end
		end

		return true
	end,
	Unban = function(self, ids, issuer)
		local _ids = {}
		for _, v in ipairs(ids) do
			COMPONENTS.Database:Update('bans', { _id = v._id, active = true }, { active = false })

			local data = COMPONENTS.WebAPI:Request("DELETE", "admin/ban", {
				type       = v.account ~= nil and "account" or "identifier",
				account    = v.account,
				identifier = v.identifier,
				issuer     = issuer:GetData("AccountID"),
			}, {})
			if data.code ~= 200 then
				COMPONENTS.Logger:Info("Punishment",
					("Failed To Revoke Site Ban For Account: %s & Identifier: %s"):format(v.account, v.identifier),
					{ console = true, discord = { embed = true, type = "error" } })
			end

			table.insert(_ids, v._id)
		end

		COMPONENTS.Logger:Info("Punishment",
			string.format("%s Bans Revoked By %s [%s]", #ids, issuer:GetData("Name"), issuer:GetData("AccountID")),
			{ console = true, file = true, database = true, discord = { embed = true, type = "info" } },
			{ issuer = string.format("%s [%s]", issuer:GetData("Name"), issuer:GetData("AccountID")) },
			_ids
		)
	end,
}
