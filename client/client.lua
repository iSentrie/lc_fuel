-- Shared variables
Utils = Utils or exports['lc_utils']:GetUtils()
cachedTranslations = {}
mainUiOpen = false

fuelNozzle = 0
fuelRope = 0
currentPump = 0

-- Local variables
local fuelDecor = "_FUEL_LEVEL"
local currentConsumption = 0.0
local fuelSynced = false
local closestVehicleToPump = 0

-----------------------------------------------------------------------------------------------------------------------------------------
-- Threads
-----------------------------------------------------------------------------------------------------------------------------------------

-- Thread to handle the fuel consumption
function createFuelConsumptionThread()
	CreateThread(function()
		local currentVehiclePlate = nil
		local currentVehicleFuelType = "default" -- default while the callback loads
		DecorRegister(fuelDecor, 1)
		while true do
			Wait(1000)
			local ped = PlayerPedId()
			if IsPedInAnyVehicle(ped, false) then
				local vehicle = GetVehiclePedIsIn(ped, false)
				if GetPedInVehicleSeat(vehicle, -1) == ped and not IsVehicleBlacklisted(vehicle) then
					if currentVehiclePlate == nil then
						currentVehicleFuelType = getVehicleFuelTypeFromServer(vehicle)
					end
					HandleFuelConsumption(vehicle, currentVehicleFuelType)
				end
			else
				currentVehicleFuelType = "default"
				currentVehiclePlate = nil
				fuelSynced = false
			end
		end
	end)
end

function HandleFuelConsumption(vehicle, fuelType)
	if not DecorExistOn(vehicle, fuelDecor) then
		SetFuel(vehicle, math.random(200, 800) / 10)
	elseif not fuelSynced then
		SetFuel(vehicle, GetFuel(vehicle))
		fuelSynced = true
	end

	if GetIsVehicleEngineRunning(vehicle) then
		currentConsumption = Config.FuelUsage[Utils.Math.round(GetVehicleCurrentRpm(vehicle), 1)] * (Config.FuelConsumptionPerClass[GetVehicleClass(vehicle)] or 1.0) * (Config.FuelConsumptionPerFuelType[fuelType] or 1.0) / 10
		SetFuel(vehicle, GetVehicleFuelLevel(vehicle) - currentConsumption)

		validateDieselFuelMismatch(vehicle, fuelType)
	end
end

function validateDieselFuelMismatch(vehicle, fuelType)
	if (fuelType == "diesel" and not IsVehicleDiesel(vehicle)) or (fuelType ~= "diesel" and IsVehicleDiesel(vehicle)) then
		SetTimeout(5000, function()
			if IsVehicleDriveable(vehicle, false) then
				SetVehicleEngineHealth(vehicle, 0.0)
				SetVehicleUndriveable(vehicle, true)
				exports['lc_utils']:notify("error", Utils.translate("vehicle_wrong_fuel"))
			end
		end)
	end
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- UI
-----------------------------------------------------------------------------------------------------------------------------------------

function clientOpenUI(pump, pumpModel, isElectric)
	currentPump = pump
	local ped = PlayerPedId()
	local playerCoords = GetEntityCoords(ped)
	closestVehicleToPump = GetClosestVehicle(playerCoords)
	pumpLocation = nil

	if closestVehicleToPump and #(playerCoords - GetEntityCoords(closestVehicleToPump)) < 5 then
		-- Load the nearest vehicle fuel and plate (fuel type)
		local vehicleFuel = GetFuel(closestVehicleToPump)
		local vehiclePlate = GetVehicleNumberPlateText(closestVehicleToPump)
		TriggerServerEvent("lc_fuel:serverOpenUI", isElectric, pumpModel, vehicleFuel, vehiclePlate)
	else
		-- Allow the user to open the UI even without vehicles nearby
		TriggerServerEvent("lc_fuel:serverOpenUI", isElectric, pumpModel)
	end
end

RegisterNetEvent('lc_fuel:clientOpenUI')
AddEventHandler('lc_fuel:clientOpenUI', function(data)
	data.currentFuelType = dealWithDefaultFuelType(closestVehicleToPump, data.currentFuelType)
	SendNUIMessage({
		openMainUI = true,
		data = data
	})
	mainUiOpen = true
	FreezeEntityPosition(PlayerPedId(), true)
	SetNuiFocus(true,true)
end)

RegisterNUICallback('post', function(body, cb)
	if cooldown == nil then
		cooldown = true

		if body.event == "close" then
			closeUI()
		elseif body.event == "notify" then
			exports['lc_utils']:notify(body.data.type,body.data.msg)
		elseif body.event == "changeVehicleFuelType" then
			changeVehicleFuelType(closestVehicleToPump, body.data.selectedFuelType)
		else
			TriggerServerEvent('lc_fuel:'..body.event,body.data)
		end
		cb(200)

		SetTimeout(5,function()
			cooldown = nil
		end)
	end
end)

function closeUI()
	mainUiOpen = false
	FreezeEntityPosition(PlayerPedId(), false)
	SetNuiFocus(false,false)
	SendNUIMessage({ hideMainUI = true })
end

RegisterNetEvent('lc_fuel:closeUI')
AddEventHandler('lc_fuel:closeUI', function()
	closeUI()
end)

-----------------------------------------------------------------------------------------------------------------------------------------
-- Exports
-----------------------------------------------------------------------------------------------------------------------------------------

function GetFuel(vehicle)
	if not DoesEntityExist(vehicle) then
		warn(("[GetFuel] Vehicle entity does not exist. Received: %s. This is usually caused by a misconfiguration in the export."):format(tostring(vehicle)))
		return 0
	end
	return DecorGetFloat(vehicle, fuelDecor)
end

function SetFuel(vehicle, fuel)
	if not DoesEntityExist(vehicle) then
		warn(("[SetFuel] Vehicle entity does not exist. Received: %s. This is usually caused by a misconfiguration in the export."):format(tostring(vehicle)))
		return
	end

	if type(fuel) ~= "number" or fuel < 0 or fuel > 100 then
		warn(("[SetFuel] Invalid fuel value received: %s. Fuel must be a number between 0 and 100."):format(tostring(fuel)))
		return
	end

	SetVehicleFuelLevel(vehicle, fuel + 0.0)
	DecorSetFloat(vehicle, fuelDecor, GetVehicleFuelLevel(vehicle))
end

-- Just another way to call the exports in case someone does it like this...
function getFuel(vehicle)
	GetFuel(vehicle)
end

function setFuel(vehicle, fuel)
	SetFuel(vehicle, fuel)
end

-----------------------------------------------------------------------------------------------------------------------------------------
-- Utils
-----------------------------------------------------------------------------------------------------------------------------------------

function getVehicleFuelTypeFromServer(vehicle)
	local returnFuelType = nil

	Utils.Callback.TriggerServerCallback('lc_fuel:getVehicleFuelType', function(fuelType)
		returnFuelType = dealWithDefaultFuelType(vehicle, fuelType)
	end, GetVehicleNumberPlateText(vehicle))

	while returnFuelType == nil do
		Wait(10)
	end
	return returnFuelType
end

function dealWithDefaultFuelType(vehicle, fuelType)
	-- Define if the vehicle is diesel or gasoline for the ones that have never been refueled
	if fuelType == "default" then
		if IsVehicleDiesel(vehicle) then
			fuelType = "diesel"
		else
			fuelType = "regular"
		end
	end
	return fuelType
end

function changeVehicleFuelType(vehicle, fuelType)
	local ped = PlayerPedId()
	local playerCoords = GetEntityCoords(ped)
	if vehicle and #(playerCoords - GetEntityCoords(vehicle)) < 5 then
		SetFuel(vehicle, 0.0)
		exports['lc_utils']:notify("info",Utils.translate("vehicle_tank_emptied"))
		TriggerServerEvent("lc_fuel:setVehicleFuelType", GetVehicleNumberPlateText(vehicle), fuelType)
	else
		exports['lc_utils']:notify("error",Utils.translate("vehicle_not_found"))
	end
end

function GetPumpOffset(pump)
	local heightOffset = { forward = 0.0, right = 0.0, up = 2.1 }
	local pumpModel = GetEntityModel(pump)

	for _, v in pairs(Config.Electric.chargersProps) do
		if pumpModel == joaat(v.prop) then
			heightOffset = v.ropeOffset
		end
	end

	for _, v in pairs(Config.GasPumpProps) do
		if pumpModel == joaat(v.prop) then
			heightOffset = v.ropeOffset
		end
	end

	return heightOffset
end

function CreateRopeToPump(pumpCoords)
	local offset = GetPumpOffset(currentPump)

	RopeLoadTextures()
	while not RopeAreTexturesLoaded() do
		Wait(0)
	end

	local forwardVector, rightVector, upVector, _ = GetEntityMatrix(currentPump)

	-- Adjust the offsets
	local forwardOffset = forwardVector * offset.forward
	local rightoffset = rightVector * offset.right
	local upOffset = upVector * offset.up
	local finalOffset = forwardOffset + rightoffset + upOffset

	local ropeObj = AddRope(pumpCoords.x + finalOffset.x, pumpCoords.y + finalOffset.y, pumpCoords.z + finalOffset.z, 0.0, 0.0, 0.0, 4.0, 1, 10.0, 0.0, 1.0, false, false, false, 1.0, true)
	while not ropeObj do
		Wait(0)
	end
	ActivatePhysics(ropeObj)
	Wait(100)

	local nozzlePos = GetOffsetFromEntityInWorldCoords(fuelNozzle, 0.0, -0.033, -0.195)
	AttachEntitiesToRope(ropeObj, currentPump, fuelNozzle, pumpCoords.x + finalOffset.x, pumpCoords.y + finalOffset.y, pumpCoords.z + finalOffset.z, nozzlePos.x, nozzlePos.y, nozzlePos.z, 30.0, false, false, nil, nil)
	return ropeObj
end

function GetVehicles()
    return GetGamePool('CVehicle')
end

function GetClosestVehicle(coords, modelFilter)
    return GetClosestEntity(GetVehicles(), false, coords, modelFilter)
end

function GetClosestEntity(entities, isPlayerEntities, coords, modelFilter)
    local closestEntity, closestEntityDistance, filteredEntities = -1, -1, nil

    if coords then
        coords = vector3(coords.x, coords.y, coords.z)
    else
        local playerPed = PlayerPedId()
        coords = GetEntityCoords(playerPed)
    end

    if modelFilter then
        filteredEntities = {}

        for _, entity in pairs(entities) do
            if modelFilter[GetEntityModel(entity)] then
                filteredEntities[#filteredEntities + 1] = entity
            end
        end
    end

    for k, entity in pairs(filteredEntities or entities) do
        local distance = #(coords - GetEntityCoords(entity))

        if closestEntityDistance == -1 or distance < closestEntityDistance then
            closestEntity, closestEntityDistance = isPlayerEntities and k or entity, distance
        end
    end

    return closestEntity, closestEntityDistance
end

function GetVehicleCapPos(vehicle)
	local closestCapPos
	local tanks = { "petrolcap", "petroltank", "petroltank_l", "petroltank_r", "wheel_lr", "wheel_lf", "engine"}
	for _, v in pairs(tanks) do
		local vehicleTank = GetEntityBoneIndexByName(vehicle, v)
		if vehicleTank ~= -1 then
			closestCapPos = GetWorldPositionOfEntityBone(vehicle, vehicleTank)
			break
		end
	end
	return closestCapPos
end

function Round(num, numDecimalPlaces)
	error("Do not use this")
end

function IsVehicleBlacklisted(vehicle)
	if vehicle and vehicle ~= 0 then
		local vehicleHash = GetEntityModel(vehicle)
		-- Blacklist electric vehicles if electric recharge is disabled
		if not Config.Electric.enabled and Config.Electric.vehiclesListHash[vehicleHash] then
			return true
		end

		-- Check if the vehicle is in the blacklist
		if Config.BlacklistedVehiclesHash[vehicleHash] then
			return true
		end
		return false
	end
	return true
end

function IsVehicleDiesel(vehicle)
	if vehicle and vehicle ~= 0 then
		local vehicleHash = GetEntityModel(vehicle)
		-- Check if the vehicle is in the diesel list
		if Config.DieselVehiclesHash[vehicleHash] then
			return true
		end
	end
	return false
end

function GetClosestPump(coords, isElectric)
	if isElectric then
		local pump = nil
		local currentPumpModel = nil
		for i = 1, #Config.Electric.chargersProps, 1 do
			currentPumpModel = Config.Electric.chargersProps[i].prop
			pump = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, joaat(currentPumpModel), true, true, true)
			if pump ~= 0 then break end
		end
		return pump, currentPumpModel
	else
		local pump = nil
		local currentPumpModel = nil
		for i = 1, #Config.GasPumpProps, 1 do
			currentPumpModel = Config.GasPumpProps[i].prop
			pump = GetClosestObjectOfType(coords.x, coords.y, coords.z, 1.0, joaat(currentPumpModel), true, true, true)
			if pump ~= 0 then break end
		end
		return pump, currentPumpModel
	end
end

function convertConfigVehiclesDisplayNameToHash()
	Config.BlacklistedVehiclesHash = {}
	for _, value in pairs(Config.BlacklistedVehicles) do
		Config.BlacklistedVehiclesHash[joaat(value)] = true
	end
	Config.Electric.vehiclesListHash = {}
	for _, value in pairs(Config.Electric.vehiclesList) do
		Config.Electric.vehiclesListHash[joaat(value)] = true
	end
	Config.DieselVehiclesHash = {}
	for _, value in pairs(Config.DieselVehicles) do
		Config.DieselVehiclesHash[joaat(value)] = true
	end
	-- Config.TankSizesHash = {}
	-- for key, value in pairs(Config.TankSizes) do
	-- 	Config.TankSizesHash[joaat(key)] = value
	-- end
	Config.CustomVehicleParametersHash = {}
	Utils.Table.deepMerge(Config.HiddenCustomVehicleParameters, Config.CustomVehicleParameters)
	for key, value in pairs(Config.HiddenCustomVehicleParameters) do
		Config.CustomVehicleParametersHash[joaat(key)] = value
	end
	Config.CustomVehicleParametersHash.default = Config.CustomVehicleParameters.default -- Adds back the default
end

RegisterNetEvent('lc_fuel:Notify')
AddEventHandler('lc_fuel:Notify', function(type,message)
	exports['lc_utils']:notify(type,message)
end)

Citizen.CreateThread(function()
	Wait(1000)
	SetNuiFocus(false,false)
	SetNuiFocusKeepInput(false)
	FreezeEntityPosition(PlayerPedId(), false)

	Utils.loadLanguageFile(Lang)

	cachedTranslations = {
		open_refuel = Utils.translate('open_refuel'),
		open_refuel_target = Utils.translate('open_refuel_target'),
		open_recharge = Utils.translate('open_recharge'),
		open_recharge_target = Utils.translate('open_recharge_target'),
		interact_with_vehicle = Utils.translate('interact_with_vehicle'),
		return_nozzle = Utils.translate('return_nozzle'),
	}

	convertConfigVehiclesDisplayNameToHash()

	-- Load NUI variables
	SendNUIMessage({
		utils = { config = Utils.Config, lang = Utils.Lang },
		resourceName = GetCurrentResourceName()
	})

	-- Gas
	if Utils.Config.custom_scripts_compatibility.target == "disabled" then
		createGasMarkersThread()
	else
		createGasTargetsThread()
	end
	createCustomPumpModelsThread()

	-- Electrics
	if Config.Electric.enabled then
		CreateThread(function()
			createElectricModelsThread()

			if Utils.Config.custom_scripts_compatibility.target == "disabled" then
				createElectricMarkersThread()
			else
				createElectricTargetsThread()
			end
		end)
	end

	-- Other threads
	createFuelConsumptionThread()
	if Config.JerryCan.enabled then
		createJerryCanThread()
	end
end)

if Config.EnableHUD then
	local function DrawAdvancedText(x,y ,w,h,sc, text, r,g,b,a,font,jus)
		SetTextFont(font)
		SetTextProportional(0)
		SetTextScale(sc, sc)
		N_0x4e096588b13ffeca(jus)
		SetTextColour(r, g, b, a)
		SetTextDropShadow(0, 0, 0, 0,255)
		SetTextEdge(1, 0, 0, 0, 255)
		SetTextDropShadow()
		SetTextOutline()
		SetTextEntry("STRING")
		AddTextComponentString(text)
		DrawText(x - 0.1+w, y - 0.02+h)
	end

	local mph = "0"
	local kmh = "0"
	local fuel = "0"
	local displayHud = false

	local x = 0.01135
	local y = 0.002

	Citizen.CreateThread(function()
		while true do
			local ped = PlayerPedId()

			if IsPedInAnyVehicle(ped, false) then
				local vehicle = GetVehiclePedIsIn(ped, false)
				local speed = GetEntitySpeed(vehicle)

				mph = tostring(math.ceil(speed * 2.236936))
				kmh = tostring(math.ceil(speed * 3.6))
				fuel = tostring(Utils.Math.round(GetVehicleFuelLevel(vehicle),2))

				displayHud = true
			else
				displayHud = false

				Citizen.Wait(500)
			end

			Citizen.Wait(50)
		end
	end)

	Citizen.CreateThread(function()
		while true do
			if displayHud then
				DrawAdvancedText(0.130 - x, 0.77 - y, 0.005, 0.0028, 0.6, mph, 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.174 - x, 0.77 - y, 0.005, 0.0028, 0.6, kmh, 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.2155 - x, 0.77 - y, 0.005, 0.0028, 0.6, fuel, 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.2615 - x, 0.77 - y, 0.005, 0.0028, 0.6, tostring(currentConsumption), 255, 255, 255, 255, 6, 1)
				DrawAdvancedText(0.145 - x, 0.7765 - y, 0.005, 0.0028, 0.4, "mp/h              km/h                  Fuel                Consumption", 255, 255, 255, 255, 6, 1)
			else
				Citizen.Wait(50)
			end

			Citizen.Wait(0)
		end
	end)
end

AddEventHandler('onResourceStop', function(resourceName)
	if GetCurrentResourceName() ~= resourceName then return end

	deleteRopeAndNozzleProp()
end)

function deleteRopeAndNozzleProp()
	if DoesRopeExist(fuelRope) then
		RopeUnloadTextures()
		DeleteRope(fuelRope)
	end
	if DoesEntityExist(fuelNozzle) then
		DeleteEntity(fuelNozzle)
	end
end

-- Do not change this, use the Config.CustomVehicleParameters in config.lua
Config.HiddenCustomVehicleParameters = {
	-- Cars
	["asbo"] = { distance = 2.5, nozzleOffset = { forward = 0.0, right = -0.21, up = 0.50} },
	["blista"] = { distance = 2.5, nozzleOffset = { forward = 0.0, right = -0.21, up = 0.50} },			
	["brioso"] = { distance = 2.5, nozzleOffset = { forward = 0.0, right = -0.10, up = 0.60} },		
	["club"] = { distance = 2.5, nozzleOffset = { forward = -0.2, right = -0.13, up = 0.50} },
	["kanjo"] = { distance = 2.5, nozzleOffset = { forward = -0.2, right = -0.17, up = 0.50} },
	["issi2"] = { distance = 2.5, nozzleOffset = { forward = -0.2, right = -0.15, up = 0.50} },
	["issi3"] = { distance = 2.5, nozzleOffset = { forward = -0.27, right = -0.13, up = 0.54} },
	["issi4"] = { distance = 2.5, nozzleOffset = { forward = -0.27, right = -0.13, up = 0.70} },
	["issi5"] = { distance = 2.5, nozzleOffset = { forward = -0.27, right = -0.13, up = 0.70} },
	["issi6"] = { distance = 2.5, nozzleOffset = { forward = -0.27, right = -0.13, up = 0.70} },
	["panto"] = { distance = 2.5, nozzleOffset = { forward = -0.10, right = -0.15, up = 0.65} },
	["prairie"] = { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.20, up = 0.45} },
	["rhapsody"] = { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.20, up = 0.45} },
	["brioso2"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.13, up = 0.40} },
	["weevil"] = { distance = 2.5, nozzleOffset = { forward = -0.02, right = -0.03, up = 0.63} },
	["issi7"] = { distance = 2.5, nozzleOffset = { forward = -0.03, right = -0.12, up = 0.57} },
	["blista2"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.23, up = 0.50} },	
	["blista3"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.23, up = 0.50} },	
	["brioso3"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.06, up = 0.40} },
	["boor"] = { distance = 2.5, nozzleOffset = { forward = 0.0, right = -0.18, up = 0.50} },	
	["asea"] = { distance = 2.5, nozzleOffset = { forward = -0.28, right = -0.21, up = 0.50} },
	["asterope"] = { distance = 2.5, nozzleOffset = { forward = -0.28, right = -0.16, up = 0.50} },
	["cog55"] = { distance = 2.5, nozzleOffset = { forward = -0.44, right = -0.21, up = 0.45} },
	["cognoscenti"] = { distance = 2.5, nozzleOffset = { forward = -0.44, right = -0.21, up = 0.45} },
	["emperor"] = { distance = 2.5, nozzleOffset = { forward = -0.44, right = -0.22, up = 0.40} },
	["fugitive"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.15, up = 0.40} },
	["glendale"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.22, up = 0.40} },
	["glendale2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.22, up = 0.30} },
	["ingot"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.23, up = 0.45} },
	["intruder"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.23, up = 0.40} },
	["premier"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.16, up = 0.52} },
	["primo"] = { distance = 2.5, nozzleOffset = { forward = -0.52, right = -0.18, up = 0.40} },
	["primo2"] = { distance = 2.5, nozzleOffset = { forward = -0.52, right = -0.20, up = 0.35} },
	["regina"] = { distance = 2.5, nozzleOffset = { forward = -0.52, right = -0.24, up = 0.40} },
	["stafford"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.17, up = 0.50} },
	["stanier"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.21, up = 0.40} },
	["stratum"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.25, up = 0.35} },
	["stretch"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.21, up = 0.35} },
	["superd"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.23, up = 0.40} },
	["tailgater"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.45} },
	["warrener"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.45} },
	["washington"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.22, up = 0.45} },
	["tailgater2"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.14, up = 0.45} },
	["cinquemila"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.21, up = 0.55} },
	["astron"] = { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.22, up = 0.55} },	
	["baller7"] = { distance = 2.5, nozzleOffset = { forward = -0.62, right = -0.16, up = 0.60} },		
	["comet7"] = { distance = 2.5, nozzleOffset = { forward = -0.37, right = -0.19, up = 0.45} },	
	["deity"] = { distance = 2.5, nozzleOffset = { forward = -0.37, right = -0.21, up = 0.50} },		
	["jubilee"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.16, up = 0.60} },		
	["oracle"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.40} },		
	["oracle"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.40} },	
	["schafter2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.45} },	
	["warrener2"] = { distance = 2.5, nozzleOffset = { forward = -0.02, right = -0.20, up = 0.40} },		
	["rhinehart"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.15, up = 0.50} },	
	["eudora"] = { distance = 2.5, nozzleOffset = { forward = 0.29, right = -0.38, up = 0.22} },

	["rebla"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.19, up = 0.60} },	
	["baller"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.23, up = 0.60} },		
	["baller2"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.17, up = 0.60} },	
	["baller3"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.17, up = 0.60} },	
	["baller4"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.17, up = 0.60} },	
	["baller5"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.17, up = 0.60} },		
	["baller6"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.17, up = 0.60} },			
	["bjxl"] = { distance = 2.5, nozzleOffset = { forward = -0.0, right = -0.21, up = 0.60} },		
	["cavalcade"] = { distance = 2.5, nozzleOffset = { forward = -0.0, right = -0.21, up = 0.65} },	
	["cavalcade2"] = { distance = 2.5, nozzleOffset = { forward = -0.0, right = -0.21, up = 0.65} },	
	["contender"] = { distance = 2.5, nozzleOffset = { forward = 0.75, right = -0.17, up = 0.50} },
	["dubsta"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.17, up = 0.70} },	
	["dubsta2"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.17, up = 0.70} },
	["fq2"] = { distance = 2.5, nozzleOffset = { forward = -0.32, right = -0.23, up = 0.53} },
	["granger"] = { distance = 2.5, nozzleOffset = { forward = 0.65, right = -0.27, up = 0.60} },
	["granger2"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.26, up = 0.60} },
	["gresley"] = { distance = 2.5, nozzleOffset = { forward = 0.05, right = -0.17, up = 0.66} },
	["habanero"] = { distance = 2.5, nozzleOffset = { forward = -0.47, right = -0.17, up = 0.50} },	
	["huntley"] = { distance = 2.5, nozzleOffset = { forward = 0.07, right = -0.24, up = 0.65} },	
	["landstalker"] = { distance = 2.5, nozzleOffset = { forward = 0.40, right = -0.23, up = 0.60} },	
	["landstalker2"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.24, up = 0.60} },	
	["novak"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.21, up = 0.60} },	
	["patriot"] = { distance = 2.5, nozzleOffset = { forward = 0.2, right = -0.22, up = 0.75} },	
	["patriot2"] = { distance = 2.5, nozzleOffset = { forward = 0.2, right = -0.22, up = 0.75} },
	["patriot3"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.29, up = 0.65} },
	["radi"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.17, up = 0.60} },
	["rocoto"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.20, up = 0.60} },
	["seminole"] = { distance = 2.5, nozzleOffset = { forward = -0.0, right = -0.20, up = 0.65} },
	["seminole2"] = { distance = 2.5, nozzleOffset = { forward = -0.0, right = -0.20, up = 0.55} },
	["serrano"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.19, up = 0.60} },
	["toros"] = { distance = 2.5, nozzleOffset = { forward = -0.26, right = -0.26, up = 0.68} },	
	["xls"] = { distance = 2.5, nozzleOffset = { forward = -0.0, right = -0.20, up = 0.65} },

	["cogcabrio"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.50} },
	["exemplar"] = { distance = 2.5, nozzleOffset = { forward = -0.27, right = -0.19, up = 0.45} },	
	["f620"] = { distance = 2.5, nozzleOffset = { forward = -0.29, right = -0.25, up = 0.40} },		
	["felon"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.18, up = 0.40} },		
	["felon2"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.18, up = 0.40} },	
	["jackal"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.11, up = 0.50} },	
	["oracle2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.15, up = 0.50} },	
	["sentinel"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.11, up = 0.50} },
	["sentinel2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.11, up = 0.50} },
	["windsor"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.15, up = 0.50} },
	["windsor2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.15, up = 0.50} },
	["zion"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.17, up = 0.50} },
	["zion2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.17, up = 0.50} },
	["previon"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.21, up = 0.50} },
	["champion"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.11, up = 0.40} },
	["futo"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.15, up = 0.40} },
	["sentinel3"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.22, up = 0.30} },
	["kanjosj"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.45} },
	["postlude"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.15, up = 0.45} },
	["tahoma"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.35} },
	["broadway"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.35} },

	["dominator7"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.45} },
	["blade"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.31, up = 0.40} },
	["buccaneer"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.28, up = 0.40} },
	["chino"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.28, up = 0.35} },
	["chino2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.25, up = 0.25} },
	["clique"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.21, up = 0.25} },
	["coquette3"] = { distance = 2.5, nozzleOffset = { forward = 0.43, right = -0.31, up = 0.25} },
	["deviant"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} },
	["dominator"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} },
	["dominator2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} },
	["dominator3"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.40} },
	["dominator4"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.21, up = 0.40} },
	["dominator7"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.40} },
	["dominator8"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.40} },
	["dukes"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.31, up = 0.40} },
	["dukes2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.31, up = 0.40} },
	["dukes3"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.25, up = 0.40} },
	["faction"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.17, up = 0.40} },
	["faction2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.16, up = 0.30} },
	["faction3"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.16, up = 0.70} },
	["ellie"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.05, up = 0.67} },
	["gauntlet"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.25, up = 0.40} },
	["gauntlet2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.25, up = 0.40} },
	["gauntlet3"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.25, up = 0.50} },
	["gauntlet4"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.18, up = 0.45} },
	["gauntlet5"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.25, up = 0.50} },
	["hermes"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.31, up = 0.20} },
	["hotknife"] = { distance = 2.5, nozzleOffset = { forward = 0.40, right = -0.00, up = 0.30} },
	["hustler"] = { distance = 2.5, nozzleOffset = { forward = -0.62, right = 0.05, up = 0.20} },
	["impaler"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.27, up = 0.35} },
	["impaler2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.24, up = 0.35} },
	["impaler3"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.22, up = 0.45} },
	["impaler4"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.23, up = 0.35} },
	["imperator"] = { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.15, up = 0.65} },
	["imperator2"] = { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.15, up = 0.65} },
	["imperator3"] = { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.15, up = 0.65} },
	["lurcher"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.30, up = 0.35} },
	["nightshade"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.07, up = 0.35} },
	["phoenix"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.23, up = 0.35} },
	["picador"] = { distance = 2.5, nozzleOffset = { forward = 0.75, right = -0.23, up = 0.45} },
	["ratloader2"] = { distance = 2.5, nozzleOffset = { forward = 1.05, right = -0.07, up = 0.35} },
	["ruiner"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.23, up = 0.35} },
	["ruiner2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.25, up = 0.35} },
	["sabregt"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.20, up = 0.35} },
	["sabregt2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.20, up = 0.30} },
	["slamvan"] = { distance = 2.5, nozzleOffset = { forward = 0.90, right = 0.03, up = 0.25} },
	["slamvan2"] = { distance = 2.5, nozzleOffset = { forward = 0.90, right = -0.18, up = 0.30} },
	["slamvan3"] = { distance = 2.5, nozzleOffset = { forward = 0.85, right = -0.03, up = 0.10} },
	["stalion"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.23, up = 0.35} },
	["stalion2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.23, up = 0.35} },
	["tampa"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.20, up = 0.35} },
	["tulip"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.23, up = 0.35} },
	["vamos"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.25, up = 0.39} },
	["vigero"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.22, up = 0.39} },
	["virgo"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.22, up = 0.39} },
	["virgo2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.28, up = 0.30} },
	["virgo3"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.25, up = 0.30} },
	["voodoo"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.29, up = 0.42} },
	["yosemite"] = { distance = 2.5, nozzleOffset = { forward = 1.20, right = -0.29, up = 0.25} },
	["yosemite2"] = { distance = 2.5, nozzleOffset = { forward = 1.22, right = -0.13, up = 0.35} },
	["buffalo4"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.22, up = 0.50} },
	["manana"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.25, up = 0.30} },
	["manana2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.25, up = 0.30} },
	["tampa2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.10, up = 0.30} },
	["ruiner4"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.19, up = 0.35} },
	["vigero2"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.50} },
	["weevil2"] = { distance = 2.5, nozzleOffset = { forward = 1.90, right = 0.15, up = 0.25} },
	["buffalo5"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.50} },
	["tulip2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.24, up = 0.35} },
	["clique2"] = { distance = 2.5, nozzleOffset = { forward = 0.05, right = -0.26, up = 0.60} }, 
	["brigham"] = { distance = 2.5, nozzleOffset = { forward = 0.15, right = -0.30, up = 0.40} }, 
	["greenwood"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.21, up = 0.50} },

	["ardent"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.19, up = 0.35} },
	["btype"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.05, up = 0.78} },
	["btype2"] = { distance = 2.5, nozzleOffset = { forward = 0.36, right = 0.07, up = 0.55} },
	["btype3"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.05, up = 0.78} },
	["casco"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.21, up = 0.30} },
	["deluxo"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.13, up = 0.40} },	
	["dynasty"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.21, up = 0.40} },	
	["fagaloa"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.21, up = 0.35} },		
	["feltzer3"] = { distance = 2.5, nozzleOffset = { forward = -0.31, right = -0.13, up = 0.55} },		
	["gt500"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.19, up = 0.25} },		
	["infernus2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.27, up = 0.35} },		
	["jb700"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.21, up = 0.35} },	
	["jb7002"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.21, up = 0.35} },	
	["mamba"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.13, up = 0.50} },	
	["michelli"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.18, up = 0.30} },	
	["monroe"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.21, up = 0.30} },	
	["nebula"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.30} },	
	["peyote"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.26, up = 0.30} },	
	["peyote3"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.26, up = 0.30} },	
	["pigalle"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.30} },	
	["rapidgt3"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.30} },	
	["retinue"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.30} },	
	["retinue2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.30} },	
	["savestra"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.15, up = 0.40} },	
	["stinger"] = { distance = 2.5, nozzleOffset = { forward = -0.02, right = -0.13, up = 0.65} },	
	["stingergt"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.20, up = 0.30} },			
	["stromberg"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.23, up = 0.35} },		
	["swinger"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.28, up = 0.25} },		
	["torero"] = { distance = 2.5, nozzleOffset = { forward = 0.75, right = -0.21, up = 0.35} },	
	["tornado"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.28, up = 0.25} },	
	["tornado2"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.28, up = 0.25} },	
	["tornado5"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.28, up = 0.25} },
	["turismo2"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.23, up = 0.40} },
	["viseris"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.18, up = 0.40} },
	["z190"] = { distance = 2.5, nozzleOffset = { forward = -0.68, right = -0.10, up = 0.47} },
	["ztype"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.23, up = 0.30} },
	["zion3"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.23, up = 0.30} },
	["cheburek"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.20, up = 0.30} },
	["toreador"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.22, up = 0.35} },
	["peyote2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.28, up = 0.30} },
	["coquette2"] = { distance = 2.5, nozzleOffset = { forward = 0.43, right = -0.24, up = 0.25} },

	["alpha"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.21, up = 0.40} },
	["banshee"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.09, up = 0.40} },
	["bestiagts"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.25, up = 0.45} },
	["buffalo"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.35} },
	["buffalo2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.35} },
	["carbonizzare"] = { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.27, up = 0.50} },
	["comet2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.35} },	
	["comet3"] = { distance = 2.5, nozzleOffset = { forward = -0.52, right = -0.07, up = 0.20} },	
	["comet4"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.20, up = 0.35} },	
	["comet5"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.35} },	
	["coquette"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.28, up = 0.25} },
	["coquette4"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.28, up = 0.25} },
	["drafter"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.18, up = 0.45} },	
	["elegy"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.28, up = 0.30} },
	["elegy2"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.18, up = 0.50} },
	["feltzer2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.15, up = 0.45} },	
	["flashgt"] = { distance = 2.5, nozzleOffset = { forward = -0.31, right = -0.26, up = 0.50} },
	["furoregt"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.50} },
	["gb200"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.20, up = 0.40} },
	["komoda"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} },
	["italigto"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.27, up = 0.40} },
	["jugular"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.16, up = 0.55} },
	["jester"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.23, up = 0.35} },
	["jester2"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.23, up = 0.35} },
	["jester3"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.16, up = 0.40} },
	["kuruma"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.19, up = 0.40} },
	["kuruma2"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.19, up = 0.40} },
	["locust"] = { distance = 2.5, nozzleOffset = { forward = 0.44, right = 0.00, up = 0.61} },
	["lynx"] = { distance = 2.5, nozzleOffset = { forward = 0.43, right = -0.24, up = 0.40} },
	["massacro"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.21, up = 0.42} },
	["massacro2"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.21, up = 0.42} },
	["neo"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.23, up = 0.42} },
	["ninef"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.24, up = 0.35} },
	["ninef2"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.24, up = 0.35} },
	["omnis"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.27, up = 0.31} },
	["paragon"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.25, up = 0.40} },
	["pariah"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.19, up = 0.45} },
	["penumbra"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.19, up = 0.50} },
	["penumbra2"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.40} },
	["rapidgt"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.17, up = 0.40} },
	["rapidgt2"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.17, up = 0.40} },
	["raptor"] = { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.40, up = 0.25} },
	["revolter"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.17, up = 0.45} },
	["ruston"] = { distance = 2.5, nozzleOffset = { forward = 0.53, right = -0.00, up = 0.53} },
	["schafter3"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.40} },
	["schafter4"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.40} },
	["schlagen"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.40} },
	["seven70"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.23, up = 0.30} },
	["specter"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.23, up = 0.30} },
	["streiter"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.08, up = 0.50} },
	["sugoi"] = { distance = 2.5, nozzleOffset = { forward = -0.25, right = -0.15, up = 0.50} }, 
	["sultan"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} }, 
	["sultan2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} }, 
	["surano"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.26, up = 0.40} }, 
	["tropos"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.08, up = 0.40} }, 
	["verlierer2"] = { distance = 2.5, nozzleOffset = { forward = 1.60, right = -0.19, up = 0.30} }, 
	["vstr"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.17, up = 0.55} }, 
	["zr350"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.21, up = 0.35} }, 
	["calico"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.16, up = 0.45} }, 
	["futo2"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.19, up = 0.35} }, 
	["euros"] = { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.15, up = 0.55} }, 
	["remus"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.16, up = 0.45} }, 
	["comet6"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.35} },
	["growler"] = { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.23, up = 0.45} },
	["vectre"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.17, up = 0.45} },
	["cypher"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.21, up = 0.45} },
	["sultan3"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.40} }, 
	["rt3000"] = { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.17, up = 0.45} }, 
	["sultanrs"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.13, up = 0.40} }, 
	["visione"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.10, up = 0.40} }, 
	["cheetah2"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.20, up = 0.35} }, 
	["stingertt"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.25, up = 0.35} }, 
	["sentinel4"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.35} }, 
	["sm722"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.35} }, 
	["tenf"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.23, up = 0.43} }, 
	["tenf2"] = { distance = 2.5, nozzleOffset = { forward = 0.43, right = -0.15, up = 0.43} }, 
	["everon2"] = { distance = 2.5, nozzleOffset = { forward = -1.03, right = -0.24, up = 0.50} }, 
	["issi8"] = { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.21, up = 0.55} }, 
	["corsita"] = { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.24, up = 0.30} }, 
	["gauntlet6"] = { distance = 2.5, nozzleOffset = { forward = -0.60, right = -0.21, up = 0.31} },
	["coureur"] = { distance = 2.5, nozzleOffset = { forward = -0.10, right = -0.22, up = 0.45} },
	["r300"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.26, up = 0.40} },
	["panthere"] = { distance = 2.5, nozzleOffset = { forward = -0.30, right = -0.14, up = 0.40} },

	["adder"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.19, up = 0.50} },
	["autarch"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.23, up = 0.30} },
	["banshee2"] = { distance = 2.5, nozzleOffset = { forward = -0.55, right = -0.09, up = 0.40} },
	["bullet"] = { distance = 2.5, nozzleOffset = { forward = -0.00, right = -0.30, up = 0.05} },
	["cheetah"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.31, up = 0.35} }, 
	["entity2"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.27, up = 0.35} }, 
	["entityxf"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.31, up = 0.35} }, 
	["emerus"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.28, up = 0.35} }, 
	["fmj"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.23, up = 0.30} }, 
	["furia"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.26, up = 0.35} }, 
	["gp1"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.27, up = 0.30} }, 
	["infernus"] = { distance = 1.5, nozzleOffset = { forward = 0.91, right = -0.14, up = 0.65} }, 
	["italigtb"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.20, up = 0.35} }, 
	["italigtb2"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.20, up = 0.40} }, 
	["krieger"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.21, up = 0.25} }, 
	["le7b"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.35, up = 0.25} }, 
	["nero"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.29, up = 0.25} }, 
	["nero2"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.29, up = 0.25} }, 
	["osiris"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.27, up = 0.25} }, 
	["penetrator"] = { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.25, up = 0.25} }, 
	["pfister811"] = { distance = 2.5, nozzleOffset = { forward = 0.75, right = -0.28, up = 0.35} }, 
	["prototipo"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.27, up = 0.35} }, 
	["reaper"] = { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.15, up = 0.35} }, 
	["s80"] = { distance = 2.5, nozzleOffset = { forward = 0.40, right = -0.31, up = 0.30} }, 
	["sc1"] = { distance = 2.5, nozzleOffset = { forward = 0.40, right = -0.25, up = 0.30} }, 
	["sheava"] = { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.17, up = 0.35} },
	["t20"] = { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.27, up = 0.30} },
	["taipan"] = { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.25, up = 0.30} },
	["tempesta"] = { distance = 2.5, nozzleOffset = { forward = 0.25, right = -0.10, up = 0.60} },
	["thrax"] = { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.22, up = 0.30} },
	["tigon"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.27, up = 0.30} },
	["turismor"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.28, up = 0.30} },
	["tyrant"] = { distance = 2.5, nozzleOffset = { forward = 0.30, right = -0.29, up = 0.50} },
	["tyrus"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.26, up = 0.30} },
	["vacca"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.32, up = 0.35} },
	["vagner"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.29, up = 0.35} },
	["xa21"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.27, up = 0.35} },
	["zentorno"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.29, up = 0.35} },
	["zorrusso"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.27, up = 0.35} },
	["ignus"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.32, up = 0.35} },
	["zeno"] = { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.24, up = 0.35} },
	["deveste"] = { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.21, up = 0.25} },
	["lm87"] = { distance = 2.5, nozzleOffset = { forward = 0.40, right = -0.34, up = 0.25} },
	["torero2"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.28, up = 0.35} },
	["entity3"] =  { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.27, up = 0.25} }, 
	["virtue"] =  { distance = 2.5, nozzleOffset = { forward = 0.45, right = -0.19, up = 0.35} }, 

	["bfinjection"] =  { distance = 2.5, nozzleOffset = { forward = 0.60, right = 0.02, up = 0.35} }, 
	["bifta"] =  { distance = 1.5, nozzleOffset = { forward = 0.03, right = -0.65, up = 0.10} }, 


	-- offroad	
	["blazer"] =  { distance = 1.5, nozzleOffset = { forward = -0.08, right = -0.29, up = 0.20} }, 
	["blazer2"] =  { distance = 1.5, nozzleOffset = { forward = -0.05, right = -0.25, up = 0.25} }, 
	["blazer3"] =  { distance = 1.5, nozzleOffset = { forward = -0.05, right = -0.25, up = 0.15} }, 
	["blazer4"] =  { distance = 1.5, nozzleOffset = { forward = -0.00, right = -0.22, up = 0.12} }, 
	["blazer5"] =  { distance = 1.5, nozzleOffset = { forward = -0.10, right = -0.55, up = 0.25} }, 
	["brawler"] =  { distance = 2.5, nozzleOffset = { forward = -0.16, right = -0.13, up = 0.90} }, 
	["caracara"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.16, up = 0.80} }, 
	["caracara2"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.16, up = 0.80} }, 
	["dubsta3"] =  { distance = 2.5, nozzleOffset = { forward = -0.75, right = -0.97, up = 0.40} },
	["dune"] =  { distance = 2.5, nozzleOffset = { forward = 0.05, right = -0.65, up = 0.05} }, 
	["everon"] =  { distance = 2.5, nozzleOffset = { forward = -0.80, right = -0.04, up = 0.80} }, 
	["freecrawler"] =  { distance = 2.5, nozzleOffset = { forward = -0.10, right = -0.20, up = 1.00} }, 
	["hellion"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.17, up = 0.40} }, 
	["hellion"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.17, up = 0.40} }, 
	["kalahari"] =  { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.17, up = 0.40} }, 
	["kamacho"] =  { distance = 2.5, nozzleOffset = { forward = 1.05, right = -0.02, up = 0.60} }, 
	["mesa3"] =  { distance = 2.5, nozzleOffset = { forward = 0.25, right = 0.02, up = 0.85} },
	["outlaw"] =  { distance = 2.5, nozzleOffset = { forward = 0.60, right = -0.13, up = 0.70} },
	["rancherxl"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.23, up = 0.50} },
	["rebel2"] =  { distance = 2.5, nozzleOffset = { forward = 1.10, right = -0.09, up = 0.55} },
	["riata"] =  { distance = 2.5, nozzleOffset = { forward = 0.90, right = -0.02, up = 0.80} },
	["sandking"] =  { distance = 2.5, nozzleOffset = { forward = 0.90, right = -0.17, up = 0.70} },
	["sandking2"] =  { distance = 2.5, nozzleOffset = { forward = 0.90, right = -0.17, up = 0.70} },
	["trophytruck"] =  { distance = 2.5, nozzleOffset = { forward = 0.90, right = -0.10, up = 0.70} },
	["trophytruck2"] =  { distance = 2.5, nozzleOffset = { forward = 0.90, right = -0.10, up = 0.70} },
	["vagrant"] =  { distance = 2.5, nozzleOffset = { forward = 0.35, right = 0.15, up = 0.25} }, 
	["verus"] =  { distance = 1.5, nozzleOffset = { forward = 0.00, right = -0.30, up = 0.08} }, 
	["winky"] = { distance = 2.5, nozzleOffset = { forward = -1.00, right = -0.19, up = 0.50} }, 
	["yosemite3"] = { distance = 2.5, nozzleOffset = { forward = 0.83, right = -0.19, up = 0.50} }, 
	["mesa"] =  { distance = 2.5, nozzleOffset = { forward = 0.30, right = -0.11, up = 0.66} },
	["ratel"] =  { distance = 2.5, nozzleOffset = { forward = 0.61, right = 0.16, up = 1.11} },
	["l35"] =  { distance = 2.5, nozzleOffset = { forward = 0.80, right = -0.17, up = 0.55} },
	["monstrociti"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.23, up = 0.45} },
	["draugur"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.16, up = 0.80} },

	-- truck	
	["guardian"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.16, up = 0.40} },
	["mixer2"] =  { distance = 2.5, nozzleOffset = { forward = 0.0, right = 0.11, up = -0.06} , nozzleRotation = { x = 0, y = 0, z = 180} },



	-- truck 2
	["slamtruck"] =  { distance = 2.5, nozzleOffset = { forward = 0.70, right = -0.28, up = 0.26} },	
	["utillitruck"] = { distance = 2.5, nozzleOffset = { forward = 0.0, right = -1.21, up = 0.50} },	
	["utillitruck"] = { distance = 2.5, nozzleOffset = { forward = 0.0, right = -1.21, up = 0.50} },


	-- van
	["bison"] =  { distance = 2.5, nozzleOffset = { forward = 0.70, right = -0.28, up = 0.26} },	
	["bobcatxl"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.28, up = 0.35} },	
	["burrito3"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.25, up = 0.35} },	
	["gburrito2"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.22, up = 0.35} },	
	["rumpo"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.25, up = 0.35} },		
	["journey"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.34, up = 0.45} },	
	["minivan"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.20, up = 0.45} },	
	["minivan2"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.20, up = 0.45} },	
	["paradise"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.23, up = 0.45} },	
	["rumpo3"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.23, up = 0.45} },	
	["speedo"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.24, up = 0.45} },
	["speedo4"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.24, up = 0.45} },
	["surfer"] =  { distance = 2.5, nozzleOffset = { forward = 0.00, right = -0.29, up = 0.45} },
	["youga3"] =  { distance = 2.5, nozzleOffset = { forward = 0.55, right = -0.18, up = 0.45} },
	["youga"] =  { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.23, up = 0.45} },
	["youga2"] =  { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.25, up = 0.40} },
	["youga4"] =  { distance = 2.5, nozzleOffset = { forward = 0.35, right = -0.30, up = 0.40} },
	["moonbeam"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.28, up = 0.40} },
	["moonbeam2"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.24, up = 0.40} },
	["boxville"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.24, up = 0.40} },
	["boxville2"] =  { distance = 2.5, nozzleOffset = { forward = -2.20, right = -0.30, up = 0.05} },
	["boxville3"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.24, up = 0.40} },
	["boxville4"] =  { distance = 2.5, nozzleOffset = { forward = -2.20, right = -0.30, up = 0.05} },
	["boxville5"] =  { distance = 2.5, nozzleOffset = { forward = -2.20, right = -0.30, up = 0.05} },
	["pony"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.24, up = 0.40} },
	["pony2"] =  { distance = 2.5, nozzleOffset = { forward = 0.40, right = -0.26, up = 0.40} },
	["journey2"] =  { distance = 2.5, nozzleOffset = { forward = -0.65, right = -0.34, up = 0.45} },	
	["surfer3"] =  { distance = 2.5, nozzleOffset = { forward = 0.00, right = -0.29, up = 0.45} },
	["speedo5"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.24, up = 0.45} },
	["mule2"] =  { distance = 2.5, nozzleOffset = { forward = -0.50, right = -0.35, up = 0.75} },
	["taco"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.24, up = 0.45} },


	-- Lqpd, ems ....
	["riot"] =  { distance = 2.5, nozzleOffset = { forward = -0.80, right = -1.30, up = 0.30} },
	["riot2"] = { distance = 2.5, nozzleOffset = { forward = -0.70, right = -0.09, up = 0.65} }, 	
	["pbus"] = { distance = 2.5, nozzleOffset = { forward = -0.70, right = -0.30, up = 0.65} }, 		
	["police"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.17, up = 0.50} }, 		
	["police2"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.24, up = 0.50} }, 		
	["police3"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.17, up = 0.50} }, 		
	["police4"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.17, up = 0.50} }, 			
	["sheriff"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.17, up = 0.50} }, 			
	["sheriff2"] = { distance = 2.5, nozzleOffset = { forward = 0.70, right = -0.28, up = 0.60} }, 		
	["policeold1"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.24, up = 0.60} }, 		
	["policeold2"] = { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.16, up = 0.40} }, 	
	["policet"] = { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.26, up = 0.60} }, 		
	["policeb"] = { distance = 2.5, nozzleOffset = { forward = -0.18, right = -0.18, up = 0.10}, nozzleRotation = { x = 0, y = 0, z = 60} },	
	["polmav"] = { distance = 3.0, nozzleOffset = { forward = 0.12, right = -0.60, up = -0.45}, nozzleRotation = { x = 0, y = 0, z = 20} },	
	["ambulance"] = { distance = 2.5, nozzleOffset = { forward = 2.95, right = -0.08, up = 0.50} }, 	
	["firetruk"] =  { distance = 2.5, nozzleOffset = { forward = 0.50, right = -0.32, up = 0.70} , nozzleRotation = { x = 0, y = 0, z = 0} },	
	["lguard"] = { distance = 2.5, nozzleOffset = { forward = 0.67, right = -0.27, up = 0.57} }, 		
	["pranger"] = { distance = 2.5, nozzleOffset = { forward = 0.67, right = -0.27, up = 0.57} }, 		
	["fbi"] = { distance = 2.5, nozzleOffset = { forward = -0.45, right = -0.24, up = 0.40} },		
	["fbi2"] = { distance = 2.5, nozzleOffset = { forward = 0.67, right = -0.27, up = 0.57} }, 		
	["predator"] = { distance = 3.5, nozzleOffset = { forward = 1.80, right = 1.58, up = 0.17}, nozzleRotation = { x = 0, y = 0, z = 180} },		


	-- Electric cars
	["voltic"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.14, up = 0.45} },
	["voltic2"] =  { distance = 2.5, nozzleOffset = { forward = -0.12, right = 0.12, up = 0.57} },
	["caddy"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.09, up = 0.53} },
	["caddy2"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.09, up = 0.35} },
	["caddy3"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.09, up = 0.35} },
	["surge"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.14, up = 0.45} },
	["iwagen"] =  { distance = 2.5, nozzleOffset = { forward = -0.40, right = -0.16, up = 0.50} },
	["raiden"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.13, up = 0.50} },
	["airtug"] =  { distance = 2.5, nozzleOffset = { forward = -0.20, right = -0.18, up = 0.47} },
	["neon"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.16, up = 0.50} },
	["omnisegt"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.16, up = 0.40} },
	["cyclone"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.16, up = 0.45} },
	["tezeract"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.16, up = 0.48} },
	["imorgon"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.16, up = 0.48} },	
	["dilettante"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.14, up = 0.48} },		
	["dilettante2"] =  { distance = 2.5, nozzleOffset = { forward = -0.05, right = -0.14, up = 0.48} },		
	["khamelion"] =  { distance = 2.5, nozzleOffset = { forward = -0.35, right = -0.20, up = 0.48} },			

	["rcbandito"] =  { distance = 2.5, nozzleOffset = { forward = -0.12, right = 0.12, up = 0.22} },


	-- Motorcycles

	["akuma"] = { distance = 2.5, nozzleOffset = { forward = 0.01, right = -0.20, up = 0.20} },
	["avarus"] = { distance = 2.5, nozzleOffset = { forward = 0.02, right = -0.18, up = 0.10} },
}