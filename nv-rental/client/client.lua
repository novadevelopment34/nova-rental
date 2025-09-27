local QBCore = exports['qb-core']:GetCoreObject()
RegisterNetEvent('QBCore:Client:UpdateObject', function() QBCore = exports['qb-core']:GetCoreObject() end)
Peds = {}
Targets = {}

--==== [ FUNCTIONS ] ====--

function loadAnimDict(dict)	
    if Config.Debug then 
        print("^5Debug^7: ^2Loading Anim Dictionary^7: '^6"..dict.."^7'") 
    end 
    while not HasAnimDictLoaded(dict) do 
        RequestAnimDict(dict) Wait(5) 
    end
end

function unloadAnimDict(dict) 
    if Config.Debug then 
        print("^5Debug^7: ^2Removing Anim Dictionary^7: '^6"..dict.."^7'") 
    end 
    RemoveAnimDict(dict) 
end

function loadModel(entity)
    if Config.Debug then 
        print("^5Debug^7: ^2Loading Model^7: '^6"..entity.."^7'") 
    end 
    while not HasModelLoaded(entity) do
        RequestModel(entity) Wait(5) 
    end
end

function unloadModel(entity) 
    if Config.Debug then 
        print("^5Debug^7: ^2Removing Model^7: '^6"..entity.."^7'") 
    end 
    SetModelAsNoLongerNeeded(entity) 
end

function setPed(model, coords, freeze, collision, scenario, anim)
    loadModel(model)
    local ped = CreatePed(0, model, coords.x, coords.y, coords.z-1.03, coords.w, false, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, freeze or true)
    if collision then SetEntityNoCollisionEntity(ped, PlayerPedId(), false) end
    if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    if anim then
        loadAnimDict(anim[1])
        TaskPlayAnim(ped, anim[1], anim[2], 1.0, 1.0, -1, 1, 0.2, 0, 0, 0)
    end
    if Config.Debug then print("^5Debug^7: ^6Ped ^2Created for location^7: '^6"..model.."^7'") end
    return ped
end

--==== [ RENTAL COUNTDOWN ] ====--
local countdownActive = false
local remainingTime = 0
local rentedVehicle = nil
local isTextShown = false

function StartRentalCountdown(rentalTime)
    if countdownActive then return end
    countdownActive = true
    remainingTime = tonumber(rentalTime) * 60
    isTextShown = false

    Citizen.CreateThread(function()
        while countdownActive and remainingTime > 0 do
            Citizen.Wait(1000)
            remainingTime = remainingTime - 1

            local ped = PlayerPedId()
            local currentVehicle = GetVehiclePedIsIn(ped, false)

            if currentVehicle == rentedVehicle then
                local minutes = math.floor(remainingTime / 60)
                local seconds = remainingTime % 60
                exports['qb-core']:DrawText('Kalan Süre: ' .. string.format("%02d:%02d", minutes, seconds), '')
                isTextShown = true
            else
                if isTextShown then
                    exports['qb-core']:HideText()
                    isTextShown = false
                end
            end
        end

        if remainingTime <= 0 then
            countdownActive = false
            if isTextShown then exports['qb-core']:HideText() end
            TriggerEvent("qb-rental:noRemainingTime", rentedVehicle)
            rentedVehicle = nil
            isTextShown = false
        end
    end)
end

function StopRentalCountdown()
    remainingTime = 0
    countdownActive = false
    rentedVehicle = nil
    if isTextShown then exports['qb-core']:HideText() end
    isTextShown = false
end

--==== [ EVENTS ] ====--

RegisterNetEvent("qb-rental:vehiclelist", function()
    local options = {}

    for i = 1, #Config.vehicleList do
        local vehicle = Config.vehicleList[i]
        if Config.Debug then 
            print(("^5Debug^7: ^6Vehicle ^2Created for location^7: '^6%s^7'"):format(vehicle.model)) 
        end

        options[#options+1] = {
            title = vehicle.name,
            description = "$" .. vehicle.price .. ".00",
            icon = 'car',
            onSelect = function()
                TriggerEvent("qb-rental:attemptvehiclespawn", {
                    id = vehicle.model,
                    price = vehicle.price
                })
            end
        }
    end

    lib.registerContext({
        id = 'qb_rental_menu',
        title = 'Vehicle Rental',
        options = options
    })

    lib.showContext('qb_rental_menu')
end)

RegisterNetEvent("qb-rental:attemptvehiclespawn", function(vehicle)
    for i, v in ipairs(Config.vehicleSpawn) do
        if DoesEntityExist(GetClosestVehicle(v.workSpawn.coords.x, v.workSpawn.coords.y, v.workSpawn.coords.z, 3.0, 0, 70)) then
            QBCore.Functions.Notify("There is a vehicle nearby, please move it.", "error")
            return
        end
    end

    local rentalOptions = {}
    for _, option in ipairs(Config.rentalTimes) do
        rentalOptions[#rentalOptions+1] = {
            label = option.text .. " ($" .. option.fees .. ")",
            value = option.value
        }
    end

    local dialog = lib.inputDialog("Nova Araç Kiralama", {
        {
            type = 'select',
            label = 'Kiralama Süresi',
            description = 'Araç kiralama süresini seç',
            required = true,
            options = rentalOptions,
            default = rentalOptions[1].value
        }
    })

    if dialog then
        local selectedValue = tonumber(dialog[1])
        local selectedOption = nil

        for _, option in ipairs(Config.rentalTimes) do
            if option.value == selectedValue then
                selectedOption = option
                break
            end
        end

        if selectedOption then
            local selectedFee = selectedOption.fees
            TriggerServerEvent("qb-rental:attemptPurchase", vehicle.id, vehicle.price, selectedValue, selectedFee)
        else
            print("Yanlış Kiralama Zamanı Seçildi.")
        end
    else
        print("Kiralama İptal Edildi.")
    end
end)

RegisterNetEvent('qb-rental:noRemainingTime', function()
    local car = GetVehiclePedIsIn(PlayerPedId(), true)

    if car ~= 0 then
        local plate = GetVehicleNumberPlateText(car)
        if string.find(tostring(plate), Config.RentalPlateMark) then
            QBCore.Functions.TriggerCallback('qb-rental:server:hasrentalpapers', function(HasItem) 
                if HasItem then
                    TriggerServerEvent('qb-rental:server:notimereturn')
                    QBCore.Functions.DeleteVehicle(car)
                    StopRentalCountdown()
                end
            end)
        end
    end
end)

RegisterNetEvent("qb-rental:vehiclespawn", function(data, minute)
    local model = data
    local closestDist = 10000
    local closestSpawn = nil
    local pcoords = GetEntityCoords(PlayerPedId())
    local CurrentPlate = nil

    for i, v in ipairs(Config.vehicleSpawn) do
        local dist = #(v.workSpawn.coords - pcoords)
        if dist < closestDist then
            closestDist = dist
            closestSpawn = v.workSpawn
        end
    end

    QBCore.Functions.SpawnVehicle(model, function(veh)
        SetVehicleNumberPlateText(veh, Config.RentalPlateMark..tostring(math.random(1000, 9999)))
        SetEntityHeading(veh, closestSpawn.heading)
        exports['cdn-fuel']:SetFuel(veh, 100.0)
        TaskWarpPedIntoVehicle(PlayerPedId(), veh, -1)
        SetEntityAsMissionEntity(veh, true, true)
        TriggerEvent("vehiclekeys:client:SetOwner", QBCore.Functions.GetPlate(veh))
        SetVehicleEngineOn(veh, true, true)
        CurrentPlate = QBCore.Functions.GetPlate(veh)

TriggerServerEvent("qb-rental:giverentalpaperServer", model, CurrentPlate)

        rentedVehicle = veh
        StartRentalCountdown(minute)
    end, closestSpawn.coords, true)
end)

--==== [ THREADS ] ====--
CreateThread(function()
    for _, rental in pairs(Config.Locations["rentalstations"]) do
        if Config.Debug then print("^5Debug^7: ^6Blip ^2Created for location^7: '^6"..rental.label.."^7'") end
        if Config.Blip then
            local blip = AddBlipForCoord(rental.coords.x, rental.coords.y, rental.coords.z)
            SetBlipSprite(blip, 326)
            SetBlipAsShortRange(blip, true)
            SetBlipScale(blip, 0.5)
            SetBlipColour(blip, 5)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(rental.label)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

RegisterNetEvent("qb-rental:returnvehicle", function()
    local car = GetVehiclePedIsIn(PlayerPedId(), true)

    if car ~= 0 then
        -- Boşlukları temizle ve üst harfe çevir
        local plate = string.gsub(GetVehicleNumberPlateText(car), "^%s*(.-)%s*$", "%1")
        local vehname = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(car)))

        -- Debug: Plaka kontrolü
        if Config.Debug then
            print("^5Debug^7: Plaka: "..plate.." | Aranıyor: "..Config.RentalPlateMark)
        end

        if string.find(string.upper(plate), string.upper(Config.RentalPlateMark), 1, true) then
            QBCore.Functions.TriggerCallback('qb-rental:server:hasrentalpapers', function(HasItem)
                if HasItem then
                    TriggerServerEvent('qb-rental:server:payreturn', vehname)
                    QBCore.Functions.DeleteVehicle(car)
                    StopRentalCountdown()
                    QBCore.Functions.Notify("Araç başarıyla teslim alındı.", "success")
                else
                    QBCore.Functions.Notify("Araç evrakları olmadan teslim alınamaz.", "error")
                end
            end)
        else
            QBCore.Functions.Notify("Bu araç kiralık değildir.", "error")
        end
    else
        QBCore.Functions.Notify("Yakınlarda kiralık bir araç göremiyorum.", "error")
    end
end)



CreateThread(function()
    for _, rental in pairs(Config.Locations["rentalstations"]) do
        Peds[#Peds+1] = setPed(rental.model, rental.coords, true, false, rental.scenario)
        if Config.Debug then print("^5Debug^7: ^6Ped ^2Created for location^7: '^6"..rental.label.."^7'") end
        Targets['rental'.._] = exports['qb-target']:AddCircleZone("rental".._, rental.coords, 1.0, {
            name = "rental".._,
            debugPoly = Config.Debug,
            useZ = true,
        }, {
            options = {
                {
                    event = "qb-rental:vehiclelist",
                    icon = "fas fa-circle",
                    label = "Araç Kirala",
                },
                {
                    event = "qb-rental:returnvehicle",
                    icon = "fas fa-circle",
                    label = "Aracı Bırak (%50 iade)",
                },
            },
            distance = 3.5
        })
    end
end)

--==== [ CLEANUP ] ====--
AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then end
    for k in pairs(Peds) do DeleteEntity(Peds[k]) end
    for k in pairs(Targets) do exports['qb-target']:RemoveZone(k) end
    exports['qb-core']:HideText()
end)
