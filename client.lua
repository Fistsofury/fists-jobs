local Core = exports.vorp_core:GetCore()
local FeatherMenu = exports['feather-menu'].initiate()
BccUtils = exports['bcc-utils'].initiate()
local isOnDuty = false
local JobMenu, JobPage
local activeJobs = {} 

Citizen.CreateThread(function()
    Citizen.Wait(500) 

    if not Config then
        print("Config is nil on Client!")
        return
    end

    if not Config.Jobs then
        print("Config.Jobs is nil on Client!")
        return
    end

    if not Config.Jobs.easttrain then
        print("Config.Jobs.easttrain is nil on Client!")
        return
    end

    print("Registering Commands:", Config.Jobs.easttrain.onDutyCommand, Config.Jobs.easttrain.offDutyCommand)

    RegisterCommand(Config.Jobs.easttrain.onDutyCommand, function()
        TriggerServerEvent("fists-jobs:setDuty", true)
    end, false)

    RegisterCommand(Config.Jobs.easttrain.offDutyCommand, function()
        TriggerServerEvent("fists-jobs:setDuty", false)
    end, false)
end)




RegisterCommand("calltrain", function()
    TriggerServerEvent("fists-jobs:checkConductors")

    RegisterNetEvent("fists-jobs:receiveConductorStatus")
    AddEventHandler("fists-jobs:receiveConductorStatus", function(hasConductors)
        if not hasConductors then
            Core.NotifyTip("No conductors are on duty!", 4000)
            return
        end

        local coords = GetEntityCoords(PlayerPedId())
        local closestStation, stationName = nil, nil

        for name, station in pairs(Config.Stations) do
            local distance = #(vector3(station.x, station.y, station.z) - coords)
            if not closestStation or distance < closestStation then
                closestStation = distance
                stationName = name
            end
        end

        if stationName then
            local stationsMenu = {}
            for name in pairs(Config.Stations) do
                table.insert(stationsMenu, { text = name, value = name })
            end

            -- Sort stations alphabetically
            table.sort(stationsMenu, function(a, b)
                return a.text < b.text
            end)

            local menu = FeatherMenu:RegisterMenu("train:call:menu", {
                top = "40%",
                left = "20%",
                ["720width"] = "400px",
                contentslot = {
                    style = {
                        ['height'] = '400',
                        ['min-height'] = '300px'
                    }
                },
                draggable = true
            })

            local page = menu:RegisterPage("calltrain:page")

            local selectedStation = nil 

            page:RegisterElement("header", { value = "Train Call Menu", slot = "header" })
            page:RegisterElement("dropdown", {
                label = "Select Destination",
                options = stationsMenu,
                slot = "content"
            }, function(data)
                if not selectedStation then
                    selectedStation = data.value 
                    TriggerServerEvent("fists-jobs:requestJob", stationName, data.value)
                    menu:Close() -- Ensure the menu closes properly
                end
            end)

            page:RegisterElement("button", { label = "Cancel", slot = "footer" }, function()
                menu:Close()
            end)

            menu:Open({ startupPage = page })
        else
            Core.NotifyTip("No station nearby!", 4000)
        end
    end)
end)


RegisterCommand("accept", function()
    TriggerServerEvent("fists-jobs:fetchJobs")
end)

RegisterNetEvent("fists-jobs:notify")
AddEventHandler("fists-jobs:notify", function(message)
    Core.NotifyTip(message, 4000)
end)

RegisterNetEvent("fists-jobs:updateJobList")
AddEventHandler("fists-jobs:updateJobList", function(updatedJobs)
    activeJobs = updatedJobs -- Update the locally declared activeJobs variable
end)

RegisterNetEvent("fists-jobs:openJobsMenu")
AddEventHandler("fists-jobs:openJobsMenu", function(jobs)
    local menu = FeatherMenu:RegisterMenu("train:jobs:menu", {
        top = "30%",
        left = "20%",
        ["720width"] = "500px",
        contentslot = {
            style = {
                ['height'] = '400',
                ['min-height'] = '300px'
            }
        },
        draggable = true
    })
    local page = menu:RegisterPage("jobslist:page")

    page:RegisterElement("header", { value = "Available Jobs", slot = "header" })

    for i, job in ipairs(jobs) do
        page:RegisterElement("textdisplay", {
            value = "Job " .. i .. ": From " .. job.fromStation .. " to " .. job.toStation,
            slot = "content"
        })

        page:RegisterElement("button", { label = "Accept Job " .. i, slot = "content" }, function()
            TriggerServerEvent("fists-jobs:acceptJob", job)
            menu:Close() -- Ensure the menu closes after accepting
        end)
    end

    if #jobs == 0 then
        page:RegisterElement("textdisplay", {
            value = "No available jobs.",
            slot = "content"
        })
    end

    page:RegisterElement("button", { label = "Close", slot = "footer" }, function()
        menu:Close() -- Explicitly close the menu
    end)

    menu:Open({ startupPage = page })
end)

local activeMedicalJobs = {} -- Track medical jobs on client

-- `/calldoctor` Command
RegisterCommand("calldoctor", function()
    local playerCoords = GetEntityCoords(PlayerPedId())
    local nearestTown = GetNearestTown(playerCoords)

    -- Send the request to the server with player details
    TriggerServerEvent("fists-jobs:sendHelpRequest", playerCoords, nearestTown)
end)

RegisterCommand("cmedic", function()
    TriggerServerEvent("fists-jobs:cancelHelpRequest")
end)


-- `/med` Command for doctors
RegisterCommand("med", function()
    TriggerServerEvent("fists-jobs:fetchMedicalJobs")
end)

function GetNearestTown(coords)
    local nearestTown = nil
    local shortestDistance = nil

    for townName, townData in pairs(Config.TownHashes) do
        local distance = #(coords - townData.coords)
        if not shortestDistance or distance < shortestDistance then
            shortestDistance = distance
            nearestTown = townName
        end
    end

    return nearestTown or "Unknown Location"
end

local activeBlip = nil -- Track the active blip


-- Set GPS and Blip for Medical Task
RegisterNetEvent("fists-jobs:setGps")
AddEventHandler("fists-jobs:setGps", function(coords)
    -- Set GPS waypoint
    BccUtils.Misc.SetGps(coords.x, coords.y, coords.z)
    Core.NotifyTip("GPS route set to the patient's location.", 4000)
    if activeBlip then
        BccUtils.Blips:RemoveBlip(activeBlip.rawblip)
        activeBlip = nil
    end

    -- Create a new blip
    Citizen.CreateThread(function()
        activeBlip = BccUtils.Blips:SetBlip(
            'Patient Location',        -- Blip name
            'blip_special_series_1',  -- Blip sprite (adjust as needed)
            0.5,                       -- Blip scale
            coords.x, coords.y, coords.z
        )
        -- Notify the player that the blip is set
        Core.NotifyTip("Blip added to map for patient location.", 4000)
    end)
end)

-- Clear GPS and Blip when Task is Complete
RegisterNetEvent("fists-jobs:clearGps")
AddEventHandler("fists-jobs:clearGps", function()
    -- Remove GPS waypoint
    BccUtils.Misc.RemoveGps()

    -- Remove the blip if it exists
    if activeBlip then
        BccUtils.Blips:RemoveBlip(activeBlip.rawblip)
        activeBlip = nil
    end

    -- Notify the player
    Core.NotifyTip("Task cleared. GPS route and blip removed.", 4000)
end)

RegisterNetEvent("fists-jobs:clearBlip")
AddEventHandler("fists-jobs:clearBlip", function()
    if activeBlip then
        BccUtils.Blips:RemoveBlip(activeBlip.rawblip) 
        activeBlip = nil
        Core.NotifyTip("Blip cleared for the canceled job.", 4000)
    end
end)


RegisterNetEvent("fists-jobs:notifyDistance")
AddEventHandler("fists-jobs:notifyDistance", function(distance)
    Core.NotifyRightTip(string.format("The doctor is approximately %d meters away from your location.", distance), 60000) -- Persistent for 1 minute
end)


-- Update Medical Jobs
RegisterNetEvent("fists-jobs:updateMedicalJobList")
AddEventHandler("fists-jobs:updateMedicalJobList", function(jobs)
    activeMedicalJobs = jobs
end)

RegisterNetEvent("fists-jobs:notifyRight")
AddEventHandler("fists-jobs:notifyRight", function(message)
    Core.NotifyRightTip(message, 60000) -- Persistent for 1 minute
end)

RegisterNetEvent("fists-jobs:notifyQueuePosition")
AddEventHandler("fists-jobs:notifyQueuePosition", function(position, totalJobs)
    Core.NotifyRightTip(string.format("You are position %d in the queue. %d requests ahead of you. Use /cmedic to cancel request", position, position - 1), 60000) -- Persistent for 1 minute
end)


RegisterNetEvent("fists-jobs:openMedicalJobsMenu")
AddEventHandler("fists-jobs:openMedicalJobsMenu", function(jobs)
    local menu = FeatherMenu:RegisterMenu("medical:jobs:menu", {
        top = "30%",
        left = "20%",
        ["720width"] = "500px",
        contentslot = {
            style = {
                ['height'] = '400px', 
                ['min-height'] = '300px'
            }
        },
        draggable = true
    })
    local page = menu:RegisterPage("medicaljobslist:page")

    page:RegisterElement("header", { value = "Medical Alerts", slot = "header" })

    for i, job in ipairs(jobs) do
        local doctorAssigned = job.acceptedBy and ("Accepted by: " .. job.acceptedBy) or "Not yet accepted"
        page:RegisterElement("textdisplay", {
            value = string.format("Job %d:\nReason: %s\nNearest Town: %s\n%s", i, job.reason, job.nearestTown, doctorAssigned),
            slot = "content"
        })

        -- Show Accept button only if the job hasn't been accepted
        if not job.acceptedBy then
            page:RegisterElement("button", { label = "Accept Job " .. i, slot = "content" }, function()
                TriggerServerEvent("fists-jobs:acceptMedicalJob", job)
                menu:Close()
            end)
        else
            page:RegisterElement("textdisplay", {
                value = "This job has already been accepted.",
                slot = "content"
            })
        end

        -- Add Clear button for all jobs
        page:RegisterElement("button", { label = "Clear Job " .. i, slot = "content" }, function()
            TriggerServerEvent("fists-jobs:clearMedicalJob", job)
            menu:Close()
        end)
    end

    if #jobs == 0 then
        page:RegisterElement("textdisplay", { value = "No active medical jobs.", slot = "content" })
    end

    page:RegisterElement("button", { label = "Close", slot = "footer" }, function()
        menu:Close()
    end)

    menu:Open({ startupPage = page })
end)


