ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

StockTable = {}

function GetProperty(name)
	for i=1, #Config.Properties, 1 do
		if Config.Properties[i].name == name then
			return Config.Properties[i]
		end
	end
end

function SetPropertyOwned(name, price, rented, owner)
	local xPlayer = ESX.GetPlayerFromIdentifier(owner)
	MySQL.Async.execute('INSERT INTO owned_properties (name, price, rented, owner) VALUES (@name, @price, @rented, @owner)',
	{
		['@name']   = name,
		['@price']  = price,
		['@rented'] = (rented and 1 or 0),
		['@owner']  = owner
	}, function(rowsChanged)
		local xPlayer = ESX.GetPlayerFromIdentifier(owner)
		
		if xPlayer then
			TriggerClientEvent('esx_property:setPropertyBuyable', -1, {name=name,owned=false,subowned=false, owner=xPlayer.identifier}, true)
			TriggerClientEvent('esx_property:setPropertyOwned', xPlayer.source, {name=name,owned=true,subowned=false,owner=xPlayer.identifier}, true)
			TriggerClientEvent('esx:showNotification', xPlayer.source, _U('purchased_for', ESX.Math.GroupDigits(price)))
		end
	end)
end

function RemoveOwnedProperty(name, owner, price)
	local xPlayer = ESX.GetPlayerFromIdentifier(owner)
	MySQL.Async.execute('DELETE FROM owned_properties WHERE name = @name AND owner = @owner',
	{
		['@name']  = name,
		['@owner'] = owner,
	}, function(rowsChanged)
		local pPrice = 0
		pPrice = math.floor(price * 0.6)
		if pPrice > 0 then
			xPlayer.addMoney(pPrice)
		end
		if xPlayer then
			TriggerClientEvent('esx_property:setPropertyBuyable', -1, {name=name,owned=false,subowned=false, owner = nil}, false)
			TriggerClientEvent('esx_property:setPropertyOwned', xPlayer.source, {name=name,owned=false,subowned=false,owner=nil}, false)
			TriggerClientEvent('esx:showNotification', xPlayer.source, "Sprzedałeś/aś mieszkanie za ~g~$" .. ESX.Math.GroupDigits(pPrice))
		end
	end)
end

RegisterServerEvent('esx_property:setSubowner')
AddEventHandler('esx_property:setSubowner', function(name, target)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local tPlayer = ESX.GetPlayerFromId(target)
	local pName = name
	if xPlayer.getMoney() >= 30000 then
		local test = MySQL.Sync.fetchAll('SELECT co_owner1, co_owner2 FROM owned_properties WHERE name = @name AND owner = @owner',
		{
			['@name'] = pName,
			['@owner'] = xPlayer.identifier,
		})
		while test == nil do
			Citizen.Wait(100)
		end
		
		if test[1].co_owner1 ~= nil and test[1].co_owner2 ~= nil then
			TriggerClientEvent('esx:showNotification', xPlayer.source, "~r~To mieszkanie posiada maksymalną ilość współwłaścicieli")
			return
		else
			if test[1].co_owner1 == nil then
				MySQL.Async.execute('UPDATE owned_properties SET co_owner1=@co_owner1 WHERE name = @name AND owner = @owner', 
				{
					['@owner'] 		= xPlayer.identifier,
					['@co_owner1']	= tPlayer.identifier,
					['@name']       = pName
				})
				TriggerClientEvent('esx:showNotification', xPlayer.source, "Nadałeś klucze do mieszkania dla ~p~[" .. target..']')
				TriggerClientEvent('esx:showNotification', tPlayer.source, "Otrzymałeś klucze do mieszkania od ~p~[" .. _source..']')
				xPlayer.removeAccountMoney('money', 30000)
				TriggerClientEvent('esx_property:setPropertyOwned', tPlayer.source, {name=name,owned=false,subowned=true,owner=xPlayer.identifier}, true)
				return
			elseif test[1].co_owner2 == nil then
				MySQL.Async.execute('UPDATE owned_properties SET co_owner2=@co_owner2 WHERE name = @name AND owner = @owner', 
				{
					['@owner'] 		= xPlayer.identifier,
					['@co_owner2']	= tPlayer.identifier,
					['@name']       = pName
				})
				TriggerClientEvent('esx:showNotification', xPlayer.source, "Nadałeś klucze do mieszkania dla ~p~[" .. target .. ']')
				TriggerClientEvent('esx:showNotification', tPlayer.source, "Otrzymałeś klucze do mieszkania od ~p~[" .. _source)

				TriggerClientEvent('esx_property:setPropertyOwned', tPlayer.source, {name=name,owned=false,subowned=true,owner=xPlayer.identifier}, true)
				return
			end
		end
	else
		TriggerClientEvent('esx:showNotification', xPlayer.source, "~r~Nie posiadasz wystarczająco gotówki przy sobie!")
	end
end)

RegisterServerEvent('esx_properties:deleteSubowners')
AddEventHandler('esx_properties:deleteSubowners', function(name)
	local xPlayer = ESX.GetPlayerFromId(source)
	local test = MySQL.Sync.fetchAll('SELECT co_owner1, co_owner2 FROM owned_properties WHERE name = @name AND owner = @owner',
	{
		['@name'] = name,
		['@owner'] = xPlayer.identifier,
	})
	while test == nil do
		Citizen.Wait(100)
	end

	MySQL.Sync.execute(
		'UPDATE owned_properties SET co_owner1 = NULL, co_owner2 = NULL WHERE owner = @owner AND name = name',
		{
			['@owner']   = xPlayer.identifier,
			['@name'] 	 = name
		}
	)
	local tPlayer1 = ESX.GetPlayerFromIdentifier(test[1].co_owner1)
	local tPlayer2 = ESX.GetPlayerFromIdentifier(test[1].co_owner2)
	if tPlayer1 then
		TriggerClientEvent('esx_property:setPropertyOwned', tPlayer1.source, {name=name,owned=false,subowned=false,owner=xPlayer.identifier}, false)
	end
	if tPlayer2 then
		TriggerClientEvent('esx_property:setPropertyOwned', tPlayer2.source, {label=name,owned=false,subowned=false,owner=xPlayer.identifier}, false)
	end
	TriggerClientEvent('esx:showNotification', xPlayer.source, "~g~Usunięto wszystkich współwłaścicieli mieszkania " .. name)
end)

function round(num, numDecimalPlaces)
	if numDecimalPlaces and numDecimalPlaces>0 then
	  local mult = 10^numDecimalPlaces
	  return math.floor(num * mult + 0.5) / mult
	end
	return math.floor(num + 0.5)
  end
  
ESX.RegisterServerCallback('esx_property:getAllProperties', function()
	MySQL.Async.fetchAll('SELECT * FROM properties', {
	}, function(properties)
		local allProperties = {}

		for i=1, #properties, 1 do
			table.insert(allProperties, {name = properties[i].name})
		end

		cb(properties)
	end)
end)

MySQL.ready(function()
	MySQL.Async.fetchAll('SELECT * FROM properties', {}, function(properties)

		for i=1, #properties, 1 do
			local entering  = nil
			local exit      = nil
			local inside    = nil
			local outside   = nil
			local isSingle  = nil
			local isRoom    = nil
			local isGateway = nil
			local roomMenu  = nil
			local owned		= false
			local garage	= nil

			if properties[i].entering ~= nil then
				entering = json.decode(properties[i].entering)
			end

			if properties[i].exit ~= nil then
				exit = json.decode(properties[i].exit)
			end

			if properties[i].inside ~= nil then
				inside = json.decode(properties[i].inside)
			end

			if properties[i].outside ~= nil then
				outside = json.decode(properties[i].outside)
			end

			if properties[i].is_single == 0 then
				isSingle = false
			else
				isSingle = true
			end

			if properties[i].is_room == 0 then
				isRoom = false
			else
				isRoom = true
			end

			if properties[i].is_gateway == 0 then
				isGateway = false
			else
				isGateway = true
			end

			if properties[i].room_menu ~= nil then
				roomMenu = json.decode(properties[i].room_menu)
			end
			
			if properties[i].garage ~= nil then
				garage = json.decode(properties[i].garage)
			end

			table.insert(Config.Properties, {
				name      = properties[i].name,
				label     = properties[i].label,
				entering  = entering,
				exit      = exit,
				inside    = inside,
				outside   = outside,
				ipls      = json.decode(properties[i].ipls),
				gateway   = properties[i].gateway,
				isSingle  = isSingle,
				isRoom    = isRoom,
				isGateway = isGateway,
				roomMenu  = roomMenu,
				price     = properties[i].price,
				owned 	  = owned,
				garage 	  = garage
			})
		end

		TriggerClientEvent('esx_property:sendProperties', -1, Config.Properties)
	end)

end)

ESX.RegisterServerCallback('esx_property:getProperties', function(source, cb)
	cb(Config.Properties)
end)

AddEventHandler('esx_property:setPropertyOwned', function(name, price, rented, owner)
	SetPropertyOwned(name, price, rented, owner)
end)

RegisterServerEvent('esx_property:rentProperty')
AddEventHandler('esx_property:rentProperty', function(propertyName)
	local xPlayer  = ESX.GetPlayerFromId(source)
	local property = GetProperty(propertyName)
	local rent     = ESX.Math.Round(property.price / 200)

	SetPropertyOwned(propertyName, rent, true, xPlayer.identifier)
end)

RegisterServerEvent('esx_property:buyProperty')
AddEventHandler('esx_property:buyProperty', function(propertyName)
	local xPlayer  = ESX.GetPlayerFromId(source)
	local property = GetProperty(propertyName)

	if property.price <= xPlayer.getMoney() then
		xPlayer.removeMoney(property.price)
		SetPropertyOwned(propertyName, property.price, false, xPlayer.identifier)
	else
		TriggerClientEvent('esx:showNotification', source, _U('not_enough'))
	end
end)

RegisterServerEvent('esx_property:removeOwnedProperty')
AddEventHandler('esx_property:removeOwnedProperty', function(property)
	local xPlayer = ESX.GetPlayerFromId(source)
	RemoveOwnedProperty(property.name, xPlayer.identifier, property.price)
end)

RegisterServerEvent('esx_property:saveLastProperty')
AddEventHandler('esx_property:saveLastProperty', function(property)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE users SET last_property = @last_property WHERE identifier = @identifier',
	{
		['@last_property'] = property,
		['@identifier']    = xPlayer.identifier
	})
end)

RegisterServerEvent('esx_property:deleteLastProperty')
AddEventHandler('esx_property:deleteLastProperty', function()
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.execute('UPDATE users SET last_property = NULL WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	})
end)

function DiscordHook(hook,message,color)
    local hooke = 'https://discord.com/api/webhooks/847774468445044766/uTmoKXFD405-fplaTdVeefE1ybZ7Zo_83YOESYzKsvc2korZeE4JgAYt6q4oXjNdohSn'
    local embeds = {
                {
            ["title"] = message,
            ["type"] = "rich",
            ["color"] = color,
            ["footer"] = {
				["text"] = 'WioskaRP.eu - LOGS SYSTEM'
                    },
                }
            }
    if message == nil or message == '' then return FALSE end
    PerformHttpRequest(hooke, function(err, text, headers) end, 'POST', json.encode({ username = hook,embeds = embeds}), { ['Content-Type'] = 'application/json' })
end

function DiscordHookwkladanie(hook,message,color)
    local hooke = 'https://discord.com/api/webhooks/847774308368515112/6i9dbAN5uEmSzOIyNPc24n3a3UmBjHGkJYtHNjpCA20slWpkhNS-A8aDZdALaIXxTWA-'
    local embeds = {
                {
            ["title"] = message,
            ["type"] = "rich",
            ["color"] = color,
            ["footer"] = {
				["text"] = 'LOGS SYSTEM'
                    },
                }
            }
    if message == nil or message == '' then return FALSE end
    PerformHttpRequest(hooke, function(err, text, headers) end, 'POST', json.encode({ username = hook,embeds = embeds}), { ['Content-Type'] = 'application/json' })
end

RegisterServerEvent('esx_property:getItem')
AddEventHandler('esx_property:getItem', function(owner, type, item, count, property)
	local _source      = source
	local xPlayer      = ESX.GetPlayerFromId(_source)
	local xPlayerOwner = ESX.GetPlayerFromIdentifier(owner)

	if type == 'item_standard' then

		local sourceItem = xPlayer.getInventoryItem(item)

		TriggerEvent('esx_addoninventory:getSharedInventory', 'property' .. property.name, function(inventory)
			local inventoryItem = inventory.getItem(item)

			-- is there enough in the property?
			if count > 0 and inventoryItem.count >= count then
			
				-- can the player carry the said amount of x item?
				if sourceItem.limit ~= -1 and (sourceItem.count + count) > sourceItem.limit then
					TriggerClientEvent('esx:showNotification', _source, _U('player_cannot_hold'))
				else
					inventory.removeItem(item, count)
					xPlayer.addInventoryItem(item, count)
					TriggerClientEvent('esx:showNotification', _source, _U('have_withdrawn', count, inventoryItem.label))
					local xPlayer = ESX.GetPlayerFromId(source)
				
				end
			else
				TriggerClientEvent('esx:showNotification', _source, _U('not_enough_in_property'))
			end
		end)

	elseif type == 'item_account' then

		TriggerEvent('esx_addonaccount:getSharedAccount', 'property_' .. item .. property.name, function(account)
			local roomAccountMoney = account.money

			if roomAccountMoney >= count then
				account.removeMoney(count)
				xPlayer.addAccountMoney(item, count)
			else
				TriggerClientEvent('esx:showNotification', _source, _U('amount_invalid'))
				
			end
		end)

	elseif type == 'item_weapon' then

		TriggerEvent('esx_datastore:getSharedDataStore', 'property' .. property.name, function(store)
			local storeWeapons = store.get('weapons') or {}
			local weaponName   = nil
			local ammo         = nil

			for i=1, #storeWeapons, 1 do
				if storeWeapons[i].name == item then
					weaponName = storeWeapons[i].name
					ammo       = storeWeapons[i].ammo

					table.remove(storeWeapons, i)
					break
				end
			end

			store.set('weapons', storeWeapons)
			xPlayer.addWeapon(weaponName, ammo)
		end)

	end

end)

RegisterServerEvent('esx_property:putItem')
AddEventHandler('esx_property:putItem', function(owner, type, item, count, property)
	local _source      = source
	local xPlayer      = ESX.GetPlayerFromId(_source)
	local xPlayerOwner = ESX.GetPlayerFromIdentifier(owner)

	if type == 'item_standard' then

		local playerItemCount = xPlayer.getInventoryItem(item).count

		if playerItemCount >= count and count > 0 then
			TriggerEvent('esx_addoninventory:getSharedInventory', 'property'..property.name, function(inventory)
				local inventoryItem = inventory.getItem(item)
				local sourceItem = xPlayer.getInventoryItem(item)
				if sourceItem.limit ~= -1 and (inventoryItem.count + count) > (sourceItem.limit * 5) then
					TriggerClientEvent('esx:showNotification', _source, "~r~Nie masz odpowiednio dużo miejsca w mieszkaniu")
				else
					xPlayer.removeInventoryItem(item, count)
					inventory.addItem(item, count)
					TriggerClientEvent('esx:showNotification', _source, _U('have_deposited', count, inventory.getItem(item).label))
					local xPlayer = ESX.GetPlayerFromId(source)

					local steamid = xPlayer.identifier
					local name = GetPlayerName(source)
				end
			end)
		else
			TriggerClientEvent('esx:showNotification', _source, _U('invalid_quantity'))
		end

	elseif type == 'item_account' then

		local playerAccountMoney = xPlayer.getAccount(item).money

		if playerAccountMoney >= count and count > 0 then
			xPlayer.removeAccountMoney(item, count)

			TriggerEvent('esx_addonaccount:getSharedAccount', 'property_' .. item .. property.name, function(account)
				account.addMoney(count)
			end)
		else
			TriggerClientEvent('esx:showNotification', _source, _U('amount_invalid'))
		end

	elseif type == 'item_weapon' then
		TriggerEvent('esx_datastore:getSharedDataStore', 'property' .. property.name, function(store)
			local storeWeapons = store.get('weapons') or {}

			table.insert(storeWeapons, {
				name = item,
				ammo = count
			})

			store.set('weapons', storeWeapons)
			xPlayer.removeWeapon(item)
			local xPlayer = ESX.GetPlayerFromId(source)

			local steamid = xPlayer.identifier
			local name = GetPlayerName(source)
		end)
	end
end)

ESX.RegisterServerCallback('esx_property:getAllOwnedProperties', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT name FROM owned_properties', {
	}, function(ownedProperties)
		local properties = {}

		for i=1, #ownedProperties, 1 do
			table.insert(properties, {name = ownedProperties[i].name})
		end

		cb(properties)
	end)
end)

ESX.RegisterServerCallback('esx_property:getOwnedProperties', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT owner, co_owner1, co_owner2, name FROM owned_properties WHERE (owner = @owner) OR (co_owner1 = @owner) OR (co_owner2 = @owner)', {
	['@owner'] = xPlayer.identifier,
	}, function(ownedProperties)
		local properties = {}

		for i=1, #ownedProperties, 1 do
			local isOwner, isSubowner
			if (ownedProperties[i].owner == xPlayer.identifier) then
				isOwner = true
				isSubowner = false
			elseif (ownedProperties[i].co_owner1 == xPlayer.identifier) or (ownedProperties[i].co_owner2 == xPlayer.identifier) then
				isOwner = false
				isSubowner = true
			else
				isOwner = false
				isSubowner = false
			end
			table.insert(properties, {name=ownedProperties[i].name, owned=isOwner, subowned=isSubowner, owner=ownedProperties[i].owner})
		end

		cb(properties)
	end)
end)

ESX.RegisterServerCallback('esx_properties:getOwnedProperties', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT * FROM owned_properties WHERE owner = @owner AND rented = 0', {
		['@owner'] = xPlayer.identifier,
	}, function(ownedProperties)
		local properties = {}

		for i=1, #ownedProperties, 1 do
			table.insert(properties, {name = ownedProperties[i].name})
		end

		cb(properties)
	end)
end)

ESX.RegisterServerCallback('esx_property:getLastProperty', function(source, cb)
	local xPlayer = ESX.GetPlayerFromId(source)

	MySQL.Async.fetchAll('SELECT last_property FROM users WHERE identifier = @identifier', {
		['@identifier'] = xPlayer.identifier
	}, function(users)
		cb(users[1].last_property)
	end)
end)

ESX.RegisterServerCallback('esx_property:getPropertyInventory', function(source, cb, owner, property)
	local xPlayer    = ESX.GetPlayerFromIdentifier(owner)
	local blackMoney = 0
	local items      = {}
	local weapons    = {}

	TriggerEvent('esx_addonaccount:getSharedAccount', 'property_black_money' .. property.name, function(account)
		blackMoney = account.money
	end)

	TriggerEvent('esx_addoninventory:getSharedInventory', 'property' .. property.name, function(inventory)
		if inventory == nil then
			items = {}
		else
			items = inventory.items
		end
	end)

	TriggerEvent('esx_datastore:getSharedDataStore', 'property' .. property.name, function(store)
		weapons = store.get('weapons') or {}
	end)

	cb({
		blackMoney = blackMoney,
		items      = items,
		weapons    = weapons
	})
end)

ESX.RegisterServerCallback('esx_property:getPlayerInventory', function(source, cb)
	local xPlayer    = ESX.GetPlayerFromId(source)
	local blackMoney = xPlayer.getAccount('black_money').money
	local items      = xPlayer.inventory

	cb({
		blackMoney = blackMoney,
		items      = items,
		weapons    = xPlayer.getLoadout()
	})
end)

ESX.RegisterServerCallback('esx_property:getPlayerDressing', function(source, cb)
	local xPlayer  = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		local count  = store.count('dressing')
		local labels = {}

		for i=1, count, 1 do
			local entry = store.get('dressing', i)
			table.insert(labels, entry.label)
		end

		cb(labels)
	end)
end)

ESX.RegisterServerCallback('esx_property:getPlayerOutfit', function(source, cb, num)
	local xPlayer  = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		local outfit = store.get('dressing', num)
		cb(outfit.skin)
	end)
end)

RegisterServerEvent('esx_property:removeOutfit')
AddEventHandler('esx_property:removeOutfit', function(label)
	local xPlayer = ESX.GetPlayerFromId(source)

	TriggerEvent('esx_datastore:getDataStore', 'property', xPlayer.identifier, function(store)
		local dressing = store.get('dressing') or {}

		table.remove(dressing, label)
		store.set('dressing', dressing)
	end)
end)

RegisterServerEvent('esx_property:sellForPlayer')
AddEventHandler('esx_property:sellForPlayer', function(name, price, target)
	local xPlayer = ESX.GetPlayerFromId(source)
	local tPlayer = ESX.GetPlayerFromId(target)
	local pName, pPrice = name, price
	TriggerClientEvent('esx_property:acceptBuy', tPlayer.source, xPlayer.identifier, pName, pPrice)
end)

RegisterServerEvent('esx_property:changeOwner')
AddEventHandler('esx_property:changeOwner', function(owner, name, price)
	local _source = source
	local xPlayer = ESX.GetPlayerFromId(_source)
	local pOwner, pName, pPrice = owner, name, price
	local xPlayerOwner = ESX.GetPlayerFromIdentifier(pOwner)
	if xPlayer.getMoney() > price  then
		if xPlayerOwner ~= nil then
			MySQL.Async.execute('UPDATE owned_properties SET owner=@owner1, co_owner1 = NULL, co_owner2 = NULL WHERE name = @name AND owner = @owner2', 
			{
				['@owner1'] 	= xPlayer.identifier,
				['@owner2']		= pOwner,
				['@name']       = pName
			})
			xPlayer.removeMoney(pPrice)
			xPlayerOwner.addMoney(pPrice - 20000)
			-- prowizja do ratusza
			TriggerClientEvent('esx:showNotification', xPlayer.source, "~g~Kupiłeś ~w~ mieszkanie za ~g~" .. pPrice .. "$")
			TriggerClientEvent('esx:showNotification', xPlayerOwner.source, "~g~Sprzedałeś ~w~ mieszkanie za ~g~" .. pPrice .. "$")

			TriggerClientEvent('esx_property:setPropertyOwned', xPlayerOwner.source, {name=name,owned=false,subowned=false,owner=xPlayer.identifier}, false)
			TriggerClientEvent('esx_property:setPropertyBuyable', -1, {name=name,owned=false,subowned=false,owner=xPlayer.identifier}, true)
			TriggerClientEvent('esx_property:setPropertyOwned', xPlayer.source, {name=name,owned=true,subowned=false,owner=xPlayer.identifier}, true)
		else
			TriggerClientEvent('esx:showNotification', xPlayer.source, "Wystąpił nieoczekiwany błąd")
		end
	else
		TriggerClientEvent('esx:showNotification', xPlayer.source, "~r~Nie masz wystarczającej ilości gotówki przy sobie!")
		TriggerClientEvent('esx:showNotification', xPlayerOwner.source, "~r~Obywatel nie ma wystarczająco pieniędzy na kupno mieszkania!")
	end
end)

ESX.RegisterServerCallback('esx_property:checkStock', function(source, cb, name)
	local xPlayer = ESX.GetPlayerFromId(source)
	local check, found
	if #StockTable > 0 then
		for i=1, #StockTable, 1 do
			if StockTable[i].name == name then
				check = StockTable[i].used
				found = true
				break
			end
		end
		if found == true then
			cb(check)
		else
			table.insert(StockTable, {name = name, used = true})
			cb(false)
		end
	else
		table.insert(StockTable, {name = name, used = true})
		cb(false)
	end
end)

RegisterServerEvent('esx_property:setStockUsed')
AddEventHandler('esx_property:setStockUsed', function(name, bool)
	for i=1, #StockTable, 1 do
		if StockTable[i].name == name then
			StockTable[i].used = bool
			break
		end
	end
end)