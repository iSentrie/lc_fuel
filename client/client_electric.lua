-- Do not load anything here if electric is disabled
if not Config.Electric.enabled then
	return
end

local electricChargers = {}

-----------------------------------------------------------------------------------------------------------------------------------------
-- Threads
-----------------------------------------------------------------------------------------------------------------------------------------

-- Load the custom electric charger models
function createElectricModelsThread()
	for _, chargerData in pairs(Config.Electric.chargersLocation) do
		RequestModel(chargerData.prop)

		while not HasModelLoaded(chargerData.prop) do
			Wait(50)
		end

		local heading = chargerData.location.w + 180.0
		local electricCharger = CreateObject(chargerData.prop, chargerData.location.x, chargerData.location.y, chargerData.location.z, false, true, true)
		SetEntityHeading(electricCharger, heading)
		FreezeEntityPosition(electricCharger, true)
		table.insert(electricChargers, electricCharger)
	end
end

-- Thread to detect near electric chargers
function createElectricMarkersThread()
	CreateThread(function()
		while true do
			local ped = PlayerPedId()
			local playerCoords = GetEntityCoords(ped)
			local pump, pumpModel = GetClosestPump(playerCoords, true)

			while pump and pump > 0 and #(playerCoords - GetEntityCoords(pump)) < 2.0 do
				playerCoords = GetEntityCoords(ped)
				if not mainUiOpen and not DoesEntityExist(fuelNozzle) then
					Utils.Markers.showHelpNotification(cachedTranslations.open_recharge, true)
					if IsControlJustPressed(0,38) then
						clientOpenUI(pump, pumpModel, true)
					end
				end
				Wait(2)
			end
			Wait(1000)
		end
	end)
end

function createElectricTargetsThread()
	local pumpModels = {}  -- This will be the final list without duplicates
	local seenModels = {}  -- This acts as a set to track unique values

	for _, chargerData in pairs(Config.Electric.chargersLocation) do
		local model = chargerData.prop
		if not seenModels[model] then
			seenModels[model] = true  -- Mark model as seen
			table.insert(pumpModels, model)  -- Insert only if it's not a duplicate
		end
	end

	-- Pass unique models to the target creation function
	Utils.Target.createTargetForModel(pumpModels, openElectricUICallback, cachedTranslations.open_recharge_target, "fas fa-plug", "#00a413")
end

function openElectricUICallback()
	local ped = PlayerPedId()
	local playerCoords = GetEntityCoords(ped)
	local pump, pumpModel = GetClosestPump(playerCoords, true)
	if pump then
		clientOpenUI(pump, pumpModel, true)
	else
		exports['lc_utils']:notify("error", Utils.translate("pump_not_found"))
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Utils
-----------------------------------------------------------------------------------------------------------------------------------------

AddEventHandler('onResourceStop', function(resourceName)
	if GetCurrentResourceName() ~= resourceName then return end

	deleteAllElectricChargers()
end)

function deleteAllElectricChargers()
	for k, v in ipairs(electricChargers) do
		DeleteEntity(v)
	end
end