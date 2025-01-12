local Core = exports.vorp_core:GetCore()
local activeJobs = {}
local onDutyConductors = {}
local assignedJobs = {}
local dutyTimers = {}

local function sendToDiscord(webhookType, message)
    local webhook = Config.Webhooks[webhookType]
    if not webhook or webhook == "" then
        print("Webhook URL not set for:", webhookType) 
        return
    end

    PerformHttpRequest(webhook, function(err, text, headers) end, "POST", json.encode({
        content = message
    }), {["Content-Type"] = "application/json"})
end


AddEventHandler("playerDropped", function(reason)
    local source = source

    -- Handle Conductor Logic
    if onDutyConductors[source] then
        onDutyConductors[source] = nil
        dutyTimers[source] = nil
        print("Player dropped, removed from duty: Source", source) 

        local user = Core.getUser(source)
        if user then
            local character = user.getUsedCharacter
            sendToDiscord("conductor", character.firstname .. " " .. character.lastname .. " went OFF DUTY due to disconnect.")
        end
    end

    -- Handle Medical Jobs
    if activeMedicalJobs and type(activeMedicalJobs) == "table" then
        for i, job in ipairs(activeMedicalJobs) do
            if job.requestedBy == source then
                -- Process the job as intended
                jobTracking[job.requestedBy] = nil
    
                -- Notify doctors about the job removal
                for _, doctorId in ipairs(exports["syn_society"]:GetPlayersOnDuty("doctor")) do
                    TriggerClientEvent("fists-jobs:updateMedicalJobList", doctorId, activeMedicalJobs)
                    TriggerClientEvent("fists-jobs:notify", doctorId, "A job has been removed due to the requester disconnecting.")
                end
                table.remove(activeMedicalJobs, i)
                print("Medical request cleared for disconnected player: " .. source) 
                break
            end
        end
    else
        print("Error: activeMedicalJobs is not a valid table.")
    end

    -- Clear assigned doctor's job if they disconnect
    if activeMedicalJobs and type(activeMedicalJobs) == "table" then
        for i, job in ipairs(activeMedicalJobs) do
            if job.acceptedBySource == source then
                TriggerClientEvent("fists-jobs:notifyRight", job.requestedBy, "The assigned doctor has disconnected, and the job has been cleared.")
                jobTracking[job.requestedBy] = nil
                TriggerClientEvent("fists-jobs:clearGps", source)
                table.remove(activeMedicalJobs, i)
                print("Doctor's assigned job cleared for disconnected player: " .. source) 
                break
            end
        end
    else
        print("Error: activeMedicalJobs is not a valid table for assigned doctor clearing.")
    end
end)


Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000) -- Every minute
        if not activeMedicalJobs or type(activeMedicalJobs) ~= "table" then
            activeMedicalJobs = {}
            print("Warning: activeMedicalJobs was nil and has been reinitialized.")
        end
    end
end)


local function getSalaryByGrade(jobGrade)
    local salary = Config.Jobs.easttrain.salary["jobGrade" .. jobGrade]
    return salary or 0
end

RegisterServerEvent("fists-jobs:setDuty")
AddEventHandler("fists-jobs:setDuty", function(onDuty)
    local source = source 
    print("fists-jobs:setDuty event triggered. OnDuty:", onDuty, "Source:", source) 

    local user = Core.getUser(source)
    if not user then
        print("User not found for source:", source) 
        TriggerClientEvent("fists-jobs:notify", source, "Failed to set duty. User not found!")
        return
    end

    local character = user.getUsedCharacter
    local job = character.job
    local jobGrade = character.jobGrade 
    print("User job:", job, "Job Grade:", jobGrade) 

    if job ~= "easttrain" then
        TriggerClientEvent("fists-jobs:notify", source, "You are not authorized for this job!")
        return
    end

    if onDuty then
        onDutyConductors[source] = true
        TriggerClientEvent("fists-jobs:notify", source, "You are now on duty!")
        sendToDiscord("conductor", character.firstname .. " " .. character.lastname .. " is now ON DUTY.")

        dutyTimers[source] = true
        Citizen.CreateThread(function()
            while dutyTimers[source] do
                Citizen.Wait(Config.Jobs.easttrain.salaryTime * 60000)
                if dutyTimers[source] then
                    local salary = getSalaryByGrade(jobGrade)
                    if salary > 0 then
                        character.addCurrency(0, salary)
                        sendToDiscord("conductor", character.firstname .. " " .. character.lastname .. " has been paid $" .. salary .. ".")
                        TriggerClientEvent("fists-jobs:notify", source, "You have been paid $" .. salary .. ".")
                    else
                        print("No salary configured for Job Grade:", jobGrade) 
                    end
                end
            end
        end)
    else
        onDutyConductors[source] = nil
        TriggerClientEvent("fists-jobs:notify", source, "You are now off duty!")
        sendToDiscord("conductor", character.firstname .. " " .. character.lastname .. " is now OFF DUTY.")

        dutyTimers[source] = nil
    end
end)



RegisterServerEvent("fists-jobs:checkConductors")
AddEventHandler("fists-jobs:checkConductors", function()
    local source = source
    local hasConductors = next(onDutyConductors) ~= nil
    TriggerClientEvent("fists-jobs:receiveConductorStatus", source, hasConductors)
end)

RegisterServerEvent("fists-jobs:requestJob")
AddEventHandler("fists-jobs:requestJob", function(fromStation, toStation)
    local source = source
    local user = Core.getUser(source)
    if not user then return end
    local character = user.getUsedCharacter

    local jobDetails = {
        fromStation = fromStation,
        toStation = toStation,
        requestedBy = source,
        requesterName = character.firstname .. " " .. character.lastname 
    }

    table.insert(activeJobs, jobDetails)
    local webhook = Config.Jobs.easttrain.webhook
    local discordMessage = string.format(
        "**New Train Request**\nRequester: %s\nFrom: %s\nTo: %s",
        jobDetails.requesterName, fromStation, toStation
    )
    sendToDiscord("conductor", discordMessage)

    -- Notify all on-duty conductors
    for conductor, _ in pairs(onDutyConductors) do
        TriggerClientEvent("fists-jobs:notify", conductor, "New train request! Use /accept to view details.")
    end
end)

RegisterServerEvent("fists-jobs:fetchJobs")
AddEventHandler("fists-jobs:fetchJobs", function()
    local source = source
    if not onDutyConductors[source] then
        TriggerClientEvent("fists-jobs:notify", source, "You are not on duty!")
        return
    end

    TriggerClientEvent("fists-jobs:openJobsMenu", source, activeJobs)
end)

RegisterServerEvent("fists-jobs:acceptJob")
AddEventHandler("fists-jobs:acceptJob", function(jobDetails)
    local source = source
    local user = Core.getUser(source)
    if not user then return end
    local character = user.getUsedCharacter

    -- Find and remove the job from the active jobs list
    for i, job in ipairs(activeJobs) do
        if job.fromStation == jobDetails.fromStation and job.toStation == jobDetails.toStation and job.requestedBy == jobDetails.requestedBy then
            table.remove(activeJobs, i)

            -- Log Discord
            local webhook = Config.Jobs.easttrain.webhook
            local discordMessage = string.format(
                "**Job Accepted**\nConductor: %s\nFrom: %s\nTo: %s\nRequester: %s",
                character.firstname .. " " .. character.lastname,
                jobDetails.fromStation,
                jobDetails.toStation,
                job.requesterName
            )
            sendToDiscord("conductor", discordMessage)
            break
        end
    end

    for conductor, _ in pairs(onDutyConductors) do
        TriggerClientEvent("fists-jobs:updateJobList", conductor, activeJobs)
        if conductor ~= source then
            TriggerClientEvent("fists-jobs:notify", conductor, "Job from " .. jobDetails.fromStation .. " to " .. jobDetails.toStation .. " has been accepted by another conductor.")
        end
    end

    TriggerClientEvent("fists-jobs:notify", jobDetails.requestedBy, "A conductor is on the way!")
    TriggerClientEvent("fists-jobs:notify", source, "You have accepted the job!")
end)
------------------------------------------------------------------------Doctor Logic -------------------------------------------------
local activeMedicalJobs = {} 
local jobTracking = {}

local function IsPlayerOnDuty(job)
    local ondutyPlayers = exports["syn_society"]:GetPlayersOnDuty(job)
    return ondutyPlayers, #ondutyPlayers > 0
end
-- `/sendhelp` Handler
RegisterServerEvent("fists-jobs:sendHelpRequest")
AddEventHandler("fists-jobs:sendHelpRequest", function(coords, nearestTown)
    local source = source
    local user = Core.getUser(source)
    if not user then return end
    local character = user.getUsedCharacter

    -- Check if the player already has a job in the queue
    for _, job in ipairs(activeMedicalJobs) do
        if job.requestedBy == source then
            TriggerClientEvent("fists-jobs:notify", source, "You already have a pending medical request.")
            return
        end
    end

    -- Check if there are doctors online
    local doctorsOnline, hasDoctors = IsPlayerOnDuty("doctor")
    if not hasDoctors then
        TriggerClientEvent("fists-jobs:notifyRight", source, "No doctors are on duty!")
        return
    end

    -- Add the job to the queue
    local jobDetails = {
        reason = "Needs medical help",
        nearestTown = nearestTown,
        coords = coords,
        requestedBy = source,
        requesterName = character.firstname .. " " .. character.lastname,
        acceptedBy = nil
    }

    table.insert(activeMedicalJobs, jobDetails)


    for _, doctorId in ipairs(doctorsOnline) do
        TriggerClientEvent("fists-jobs:notify", doctorId, "New medical alert received! Use /med to view details.")
    end
    TriggerClientEvent("fists-jobs:notifyRight", source, "Your request for medical assistance has been sent.")
end)



RegisterServerEvent("fists-jobs:fetchMedicalJobs")
AddEventHandler("fists-jobs:fetchMedicalJobs", function()
    local source = source
    local user = Core.getUser(source)
    if not user or user.getUsedCharacter.job ~= "doctor" then return end

    TriggerClientEvent("fists-jobs:openMedicalJobsMenu", source, activeMedicalJobs)
end)

RegisterServerEvent("fists-jobs:acceptMedicalJob")
AddEventHandler("fists-jobs:acceptMedicalJob", function(jobDetails)
    local source = source
    local user = Core.getUser(source)
    if not user then return end
    local character = user.getUsedCharacter

    for i, job in ipairs(activeMedicalJobs) do
        if job.reason == jobDetails.reason and job.nearestTown == jobDetails.nearestTown and job.requestedBy == jobDetails.requestedBy then
            if job.acceptedBy then
                TriggerClientEvent("fists-jobs:notify", source, "This job has already been accepted by " .. job.acceptedBy .. ".")
                return
            end

            job.acceptedBy = character.firstname .. " " .. character.lastname
            TriggerClientEvent("fists-jobs:notifyRight", job.requestedBy, "A doctor is on the way!")
            TriggerClientEvent("fists-jobs:notify", source, "You have accepted the medical job!")

            -- Notify other doctors about the acceptance
            for _, doctorId in ipairs(exports["syn_society"]:GetPlayersOnDuty("doctor")) do
                TriggerClientEvent("fists-jobs:updateMedicalJobList", doctorId, activeMedicalJobs)
                if doctorId ~= source then
                    TriggerClientEvent("fists-jobs:notify", doctorId, "Job accepted by " .. job.acceptedBy)
                end
            end
            TriggerClientEvent("fists-jobs:setGps", source, job.coords)

            -- Log to Discord
            local discordMessage = string.format(
                "**Medical Job Accepted**\nDoctor: %s\nRequester: %s\nReason: %s\nNearest Town: %s",
                character.firstname .. " " .. character.lastname,
                job.requesterName,
                job.reason,
                job.nearestTown
            )
            sendToDiscord("medical", discordMessage)

            -- Start distance tracking loop
            jobTracking[jobDetails.requestedBy] = true
            Citizen.CreateThread(function()
                while jobTracking[jobDetails.requestedBy] do
                    Citizen.Wait(30000) -- Update every 30 seconds

                    if jobTracking[jobDetails.requestedBy] then
                        local doctorCoords = GetEntityCoords(GetPlayerPed(source)) -- Doctor's current location
                        local distance = #(vector3(job.coords.x, job.coords.y, job.coords.z) - doctorCoords)
                        TriggerClientEvent("fists-jobs:notifyDistance", job.requestedBy, math.floor(distance))
                    end
                end
            end)

            break
        end
    end
end)


-- Clear Medical Job
RegisterServerEvent("fists-jobs:clearMedicalJob")
AddEventHandler("fists-jobs:clearMedicalJob", function(jobDetails)
    for i, job in ipairs(activeMedicalJobs) do
        if job.reason == jobDetails.reason and job.nearestTown == jobDetails.nearestTown and job.requestedBy == jobDetails.requestedBy then
            table.remove(activeMedicalJobs, i)

            -- Stop distance tracking
            jobTracking[jobDetails.requestedBy] = nil

            -- Notify all doctors
            for _, doctorId in ipairs(exports["syn_society"]:GetPlayersOnDuty("doctor")) do
                TriggerClientEvent("fists-jobs:updateMedicalJobList", doctorId, activeMedicalJobs)
            end

            -- Notify the requester
            TriggerClientEvent("fists-jobs:notify", job.requestedBy, "Your medical alert has been cleared.")

            -- Clear GPS and blip for the assigned doctor
            if job.acceptedBySource then
                TriggerClientEvent("fists-jobs:clearGps", job.acceptedBySource)
                TriggerClientEvent("fists-jobs:clearBlip", job.acceptedBySource) 
                TriggerClientEvent("fists-jobs:notify", job.acceptedBySource, "The medical job you accepted has been cleared.")
            else
                print("No doctor was assigned to this job.")
            end

            -- Log to Discord
            local webhook = Config.Jobs.easttrain.webhook
            local discordMessage = string.format(
                "**Medical Job Cleared**\nReason: %s\nNearest Town: %s\nAccepted By: %s",
                job.reason,
                job.nearestTown,
                job.acceptedBy or "No doctor assigned"
            )
            sendToDiscord("medical", discordMessage)

            break
        end
    end
end)


RegisterServerEvent("fists-jobs:cancelHelpRequest")
AddEventHandler("fists-jobs:cancelHelpRequest", function()
    local source = source
    local user = Core.getUser(source)
    if not user then return end
    local character = user.getUsedCharacter
    local playerName = character.firstname .. " " .. character.lastname

    for i, job in ipairs(activeMedicalJobs) do
        if job.requestedBy == source then
            local jobDetails = table.remove(activeMedicalJobs, i)

            -- Clear tracking for the requester
            jobTracking[jobDetails.requestedBy] = nil

            -- Notify doctors about the job cancellation
            for _, doctorId in ipairs(exports["syn_society"]:GetPlayersOnDuty("doctor")) do
                TriggerClientEvent("fists-jobs:updateMedicalJobList", doctorId, activeMedicalJobs)
                TriggerClientEvent("fists-jobs:notify", doctorId, string.format("Job %d was cancelled by %s.", i, playerName))
            end

            -- Clear GPS and blip for the assigned doctor, if any
            if jobDetails.acceptedBySource then
                TriggerClientEvent("fists-jobs:clearGps", jobDetails.acceptedBySource)
                TriggerClientEvent("fists-jobs:clearBlip", jobDetails.acceptedBySource) 
                TriggerClientEvent("fists-jobs:notify", jobDetails.acceptedBySource, "The medical job you accepted has been cancelled.")
            end

            -- Notify the requester
            TriggerClientEvent("fists-jobs:notify", source, "Your medical request has been cancelled.")

            -- Log cancellation to Discord
            local discordMessage = string.format(
                "**Medical Job Cancelled**\nCancelled By: %s\nNearest Town: %s\nAccepted By: %s\nReason: %s",
                playerName,
                jobDetails.nearestTown or "Unknown",
                jobDetails.acceptedBy or "Not yet accepted",
                jobDetails.reason or "No reason provided"
            )
            sendToDiscord("medical", discordMessage)

            print("Medical job cancelled by player: " .. playerName) 
            break
        end
    end
end)




Citizen.CreateThread(function()
    while true do
        Citizen.Wait(30000) -- Every 30 seconds

        for i, job in ipairs(activeMedicalJobs) do
            if not job.acceptedBy then
                local positionInQueue = i
                TriggerClientEvent("fists-jobs:notifyQueuePosition", job.requestedBy, positionInQueue, #activeMedicalJobs)
            end
        end
    end
end)


AddEventHandler("vorp_core:Server:OnPlayerRespawn", function(source)
    local user = Core.getUser(source)
    if not user then return end

    local character = user.getUsedCharacter
    local playerName = character.firstname .. " " .. character.lastname

    -- Prepare Discord Message
    local discordMessage = "**Player Respawned**\nName: " .. playerName
    local failRpFlag = false  

    for i, job in ipairs(activeMedicalJobs) do
        if job.requestedBy == source then
            failRpFlag = true
            jobTracking[job.requestedBy] = nil

            -- Notify doctors
            for _, doctorId in ipairs(exports["syn_society"]:GetPlayersOnDuty("doctor")) do
                TriggerClientEvent("fists-jobs:updateMedicalJobList", doctorId, activeMedicalJobs)
                TriggerClientEvent("fists-jobs:notify", doctorId, "A job has been removed due to the requester respawning.")
            end
            TriggerClientEvent("fists-jobs:notifyRight", source, "Your medical request has been cleared due to respawn.")
            discordMessage = discordMessage .. "\n**Fail RP Detected**: Player respawned with an active alert.\nNearest Town: " .. job.nearestTown
            table.remove(activeMedicalJobs, i)
            print("Medical request cleared for respawned player: " .. source) 
            break
        end
    end

    -- Clear doctor's assigned job if they respawn
    for i, job in ipairs(activeMedicalJobs) do
        if job.acceptedBySource == source then
            -- Notify the requester
            TriggerClientEvent("fists-jobs:notifyRight", job.requestedBy, "The assigned doctor has respawned, and the job has been cleared.")
            jobTracking[job.requestedBy] = nil

            TriggerClientEvent("fists-jobs:clearGps", source)

            discordMessage = discordMessage .. "\nAlert Status: **Doctor's assigned job cleared**\nRequester: " .. job.requesterName
            table.remove(activeMedicalJobs, i)
            print("Doctor's assigned job cleared for respawned player: " .. source) 
            break
        end
    end


    if failRpFlag then
        discordMessage = discordMessage .. "\n**ACTION REQUIRED**: This may indicate fail RP. Investigate."
    end

    -- Final Discord Log
    sendToDiscord("medical", discordMessage)

end)






