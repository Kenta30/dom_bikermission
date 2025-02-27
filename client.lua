local Target = exports.ox_target
local Input = lib.inputDialog
local Zone = lib.zones

local function requestModels(model)
    RequestModel(model)
    while not HasModelLoaded(model) do 
        Wait(500)
    end 
end 

local function setupMissionOnEnter()
    missionSphere:remove()
    RemoveBlip(targetBlip)
    local model = Config.Mission.NPCModel
    requestModels(model)
    local carmodel = Config.Mission.CarModel
    requestModels(carmodel)
    missionNPCTable = {}
    TargetCar = CreateVehicle(Config.Mission.CarModel, Config.Mission.CarLocation, true, false)
    for i = 1, #Config.Mission.NPCLocations, 1 do 
        missionNPCTable[i] = CreatePed(1, Config.Mission.NPCModel, Config.Mission.NPCLocations[i], true, false)
        GiveWeaponToPed(missionNPCTable[i], `weapon_pistol`, 250, false, true)
        SetCurrentPedWeapon(missionNPCTable[i], `weapon_pistol`, true)
        SetPedCombatAbility(missionNPCTable[i], 100)
        SetPedRelationshipGroupHash(missionNPCTable[i], 'AGGRESSIVE_INVESTIGATE')
        Wait(500)
    end
    SetModelAsNoLongerNeeded(model)
    SetModelAsNoLongerNeeded(carmodel)

    Citizen.CreateThread(function()
        local toggle = true
        local gotDropOff = false
        while toggle do 
            if not IsEntityDead(PlayerPedId()) then 
                lib.onCache('vehicle', function(value)
                    if not value then return end
                    if value == TargetCar and gotDropOff == false and GlobalState.inMission == true then 
                        toggle = false
                        gotDropOff = true
                        local randomDropOff = math.random(1, #Config.Mission.DropOffLocations)
                        lib.notify(Config.Notification.GotDropOff)
                        local dropOffBlip = AddBlipForCoord(Config.Mission.DropOffLocations[randomDropOff])
                            SetBlipColour(dropOffBlip, 3)
                            SetBlipHiddenOnLegend(dropOffBlip, true)
                            SetBlipRoute(dropOffBlip, true)
                            SetBlipDisplay(dropOffBlip, 8)
                            SetBlipRouteColour(dropOffBlip, 3)

                        local function DropOffOnEnter()
                            RemoveBlip(dropOffBlip)
                            local CarOptions = {{
                                name = 'DropOff:option1',
                                icon = Config.Mission.DropOffTargetIcon,
                                distance = Config.StartMission.TargetDistance,
                                label = Config.Mission.DropOffTargetLabel,
                                onSelect = function()
                                    TriggerServerEvent('dom_bikerMission:reward')
                                end 

                            }}

                            Target:addLocalEntity(TargetCar, CarOptions)
                        end 

                        dropOffBox = Zone.box({
                            coords = Config.Mission.DropOffLocations[randomDropOff],
                            size = Config.Mission.DropOffSize,
                            debug = Config.Debug,
                            onEnter = DropOffOnEnter
                        })
                    end 
                end)                
                Wait(1000)
            else 
                toggle = false
                TriggerServerEvent('dom_bikermission:inMissionFalse')
            end 
        end 
    end)
end 

function setUpMission()
    missionSphere = Zone.sphere({
        coords = Config.Mission.ZoneLocation,
        radius = Config.Mission.ZoneRadius,
        debug = Config.Debug,
        onEnter = setupMissionOnEnter
    })
end 

local function startMissionBoxOnExter()
    local model = Config.StartMission.NPCModel
    requestModels(model)

    startMissionNPC = CreatePed(1, Config.StartMission.NPCModel, Config.StartMission.NPCLocation, Config.StartMission.Heading, false, false)
        FreezeEntityPosition(startMissionNPC, true)
        SetEntityInvincible(startMissionNPC, true)
        SetBlockingOfNonTemporaryEvents(startMissionNPC, true)
        SetModelAsNoLongerNeeded(model)

    local startMissionOptions = {{
        name = 'startMission:option1',
        icon = Config.StartMission.TargetIcon,
        distance = Config.StartMission.TargetDistance,
        label = Config.StartMission.TargetLabel,
        onSelect = function()
            if GlobalState.inMission or GlobalState.completedJob then 
                lib.notify(Config.Notification.CantStartMission)
            else 
                TriggerServerEvent('dom_bikermission:inMissionTrue')
                lib.notify(Config.Notification.StartMission)
                setUpMission()
                targetBlip = AddBlipForCoord(Config.Mission.CarLocation)
                    SetBlipColour(targetBlip, 3)
                    SetBlipHiddenOnLegend(targetBlip, true)
                    SetBlipRoute(targetBlip, true)
                    SetBlipDisplay(targetBlip, 8)
                    SetBlipRouteColour(targetBlip, 3)
            end 
        end 
    }}
    Target:addLocalEntity(startMissionNPC, startMissionOptions)
end 

local function startMissionBoxOnExit()
    DeleteEntity(startMissionNPC)
end

local startMissionBox = Zone.box({
    coords = Config.StartMission.ZoneLocation,
    size = Config.StartMission.ZoneSize,
    rotation = Config.StartMission.ZoneRotation,
    debug = Config.Debug,
    onEnter = startMissionBoxOnExter,
    onExit = startMissionBoxOnExit
})

RegisterNetEvent('dom_bikerMission:CompleteJob', function()
    DeleteEntity(TargetCar)
    dropOffBox:remove()
    lib.notify(Config.Notification.CompletedJob)
    TriggerServerEvent('dom_bikermission:completedJobTrue')
end)
