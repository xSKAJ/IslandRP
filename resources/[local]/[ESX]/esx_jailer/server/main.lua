ESX = nil

TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

--[[
RegisterCommand("jail", function(src, args, raw)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	--if xPlayer.group == 'admin' or xPlayer.group == 'superadmin' or xPlayer.group == 'moderator' or xPlayer.group == 'support' or xPlayer.job.name == 'police' then
		--[[if args[1] and GetPlayerName(args[1]) ~= nil and tonumber(args[2]) then
			TriggerEvent('esx_grzibi:naura123', tonumber(args[1]), tonumber(args[2] * 60))
		else
			TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid player ID or jail time!' } } )
		end
		print('jebacpis')
	--end
end)]]
-- unjail
RegisterCommand('unjail', function(source, args, user)
	if xPlayer.group == 'admin' or xPlayer.group == 'superadmin' or xPlayer.group == 'moderator' or xPlayer.group == 'support' or xPlayer.group == 'best' then
		if args[1] then
			if GetPlayerName(args[1]) ~= nil then
				TriggerEvent('esx_jailer:unjailQuesthype', tonumber(args[1]))
			else
				TriggerClientEvent('chat:addMessage', source, { args = { '^1SYSTEM', 'Invalid player ID!' } } )
			end
		else
			TriggerEvent('esx_jailer:unjailQuesthype', source)
		end
	end
end, false)

-- send to jail and register in database
RegisterServerEvent('esx_grzibi:naura123')
AddEventHandler('esx_grzibi:naura123', function(target, jailTime)
	local source = _source
	local sourceXPlayer = ESX.GetPlayerFromId(_source)
	if sourceXPlayer.job.name ~= 'police' then
		print('ktos probuje zbanowac')
		exports['miner']:ban(source, "Czemu tak robisz?")
	else
	local identifier = GetPlayerIdentifiers(target)[1]
	MySQL.Async.fetchAll('SELECT * FROM jail WHERE identifier=@id', {['@id'] = identifier}, function(result)
		if result[1] ~= nil then
			MySQL.Async.execute("UPDATE jail SET jail_time=@jt WHERE identifier=@id", {['@id'] = identifier, ['@jt'] = jailTime})
		else
			MySQL.Async.execute("INSERT INTO jail (identifier,jail_time) VALUES (@identifier,@jail_time)", {['@identifier'] = identifier, ['@jail_time'] = jailTime})
		end
	end)
	
		-- local xPlayers = ESX.GetPlayers()

		-- for i=1, #xPlayers, 1 do

  		-- 	local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
  		-- 	--TriggerClientEvent('xjail:notify', xPlayer.source, ESX.Round(jailTime / 60), target)

		-- end

	TriggerClientEvent('esx_policejob:unrestrain', target)
	TriggerClientEvent('esx_jailer:jailhype', target, jailTime)
	end
end)

-- should the player be in jail?
RegisterServerEvent('esx_jailer:checkJailhype')
AddEventHandler('esx_jailer:checkJailhype', function()
	local _source = source
	local sourceXPlayer = ESX.GetPlayerFromId(_source)
	
	-- local player = source -- cannot parse source to client trigger for some weird reason
	-- local identifier = GetPlayerIdentifiers(player)[1] -- get steam identifier
	-- if sourceXPlayer.job.name ~= 'police' then
	-- 	exports['miner']:ban(source, "Czemu tak robisz?")
	-- else
	if sourceXPlayer then 
		MySQL.Async.fetchAll('SELECT * FROM jail WHERE identifier=@id', {['@id'] = sourceXPlayer.identifier}, function(result)
			if result[1] ~= nil then
				-- local xPlayers = ESX.GetPlayers()

				-- for i=1, #xPlayers, 1 do

					-- local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
					-- TriggerClientEvent('xjail:notify', -1, ESX.Round(result[1].jail_time / 60))

				-- end
				--TriggerClientEvent('chat:addMessage', -1, { args = { _U('judge'), _U('jailed_msg', GetPlayerName(player), ESX.Round(result[1].jail_time / 60)) }, color = { 147, 196, 109 } })
				TriggerClientEvent('esx_jailer:jailhype', _source, tonumber(result[1].jail_time))
			end
		end)
	end
-- end
end)

-- unjail via command
RegisterServerEvent('esx_jailer:unjailQuesthype')
AddEventHandler('esx_jailer:unjailQuesthype', function(source)
	if source ~= nil then
		unjail(source)
	end
end)

-- unjail after time served
RegisterServerEvent('esx_jailer:unjailTimehype')
AddEventHandler('esx_jailer:unjailTimehype', function()
	unjail(source)
end)

-- keep jailtime updated
RegisterServerEvent('esx_jailer:updateRemaininghype')
AddEventHandler('esx_jailer:updateRemaininghype', function(jailTime)
	local identifier = GetPlayerIdentifiers(source)[1]
	MySQL.Async.fetchAll('SELECT * FROM jail WHERE identifier=@id', {['@id'] = identifier}, function(result)
		if result[1] ~= nil then
			MySQL.Async.execute("UPDATE jail SET jail_time=@jt WHERE identifier=@id", {['@id'] = identifier, ['@jt'] = jailTime})
		end
	end)
end)

function unjail(target)
	local identifier = GetPlayerIdentifiers(target)[1]
	MySQL.Async.fetchAll('SELECT * FROM jail WHERE identifier=@id', {['@id'] = identifier}, function(result)
		if result[1] ~= nil then
			MySQL.Async.execute('DELETE from jail WHERE identifier = @id', {['@id'] = identifier})
			-- local xPlayers = ESX.GetPlayers()

			-- for i=1, #xPlayers, 1 do

  				-- local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
  				TriggerClientEvent('xunjail:notify', -1, target)

			-- end
			--TriggerClientEvent('chat:addMessage', -1, { args = { _U('judge'), _U('unjailed', GetPlayerName(target)) }, color = { 147, 196, 109 } })
		end
	end)

	TriggerClientEvent('esx_jailer:unjailhype', target)
end

RegisterServerEvent('esx_jailer:sendToJailPanelhype')
AddEventHandler('esx_jailer:sendToJailPanelhype', function(target, jailTime, powod)
	local identifier = GetPlayerIdentifiers(target)[1]
	MySQL.Async.fetchAll('SELECT * FROM jail WHERE identifier=@id', {['@id'] = identifier}, function(result)
		if result[1] ~= nil then
			MySQL.Async.execute("UPDATE jail SET jail_time=@jt WHERE identifier=@id", {['@id'] = identifier, ['@jt'] = jailTime})
		else
			MySQL.Async.execute("INSERT INTO jail (identifier,jail_time) VALUES (@identifier,@jail_time)", {['@identifier'] = identifier, ['@jail_time'] = jailTime})
		end
	end)
	
		-- local xPlayers = ESX.GetPlayers()

		-- for i=1, #xPlayers, 1 do

  		-- 	local xPlayer = ESX.GetPlayerFromId(xPlayers[i])
  			TriggerClientEvent('xjail:notify', -1, ESX.Round(jailTime / 60), target, powod)

		-- end

	--TriggerClientEvent('chat:addMessage', -1, { args = { _U('judge'), _U('jailed_msg', GetPlayerName(target), ESX.Round(jailTime / 60)) }, color = { 147, 196, 109 } })
	TriggerClientEvent('esx_policejob:unrestrain', target)
	TriggerClientEvent('esx_jailer:jailhype', target, jailTime)
end)




