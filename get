local player = game:GetService("Players").LocalPlayer
local Plots = workspace:FindFirstChild("Plots")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bases = ReplicatedStorage:FindFirstChild("Bases")
local RunService = game:GetService("RunService")
local connections = {}
local updatePending = false
local lastPollTime = 0
local plotLockdownState = {}

local dataStore = ReplicatedStorage:FindFirstChild("PetData") or Instance.new("Folder")
if not dataStore.Parent then
    dataStore.Name = "PetData"
    dataStore.Parent = ReplicatedStorage
end

local function getFloorFromSlotCount(slotCount)
    if slotCount >= 1 and slotCount <= 10 then
        return 1
    elseif slotCount >= 11 and slotCount <= 18 then
        return 2
    elseif slotCount >= 19 and slotCount <= 23 then
        return 3
    else
        return "Unknown"
    end
end

local function parseGenerationValue(text)
    if not text or typeof(text) ~= "string" then return 0 end
    if string.find(text, "Infinity") then
        return math.huge
    end
    local multipliers = {
        k = 1e3, m = 1e6, b = 1e9, t = 1e12, qa = 1e15, qi = 1e18, sx = 1e21,
        sp = 1e24, oc = 1e27, no = 1e30, de = 1e33, un = 1e36, du = 1e39,
        tr = 1e42, qu = 1e45, qt = 1e48, se = 1e51, st = 1e54, og = 1e57,
        nn = 1e60, vi = 1e63, ce = 1e66
    }
    local cleanText = string.lower(text)
    cleanText = string.gsub(cleanText, "[$%s,]", "")
    cleanText = string.gsub(cleanText, "/s$", "")
    local numStr, suffix = string.match(cleanText, "^([%d%.]+)(%a*)$")
    if not numStr then
        numStr = string.match(cleanText, "^[%d%.]+")
        if not numStr then return 0 end
        suffix = ""
    end
    local value = tonumber(numStr)
    if not value then return 0 end
    if suffix and suffix ~= "" then
        local multiplier = multipliers[suffix]
        if multiplier then
            value = value * multiplier
        end
    end
    return value
end

local function getPlotOwnerName(plot)
    if not plot then return nil end
    local plotSign = plot:FindFirstChild("PlotSign")
    if plotSign then
        local surfaceGui = plotSign:FindFirstChildOfClass("SurfaceGui")
        if surfaceGui then
            local frame = surfaceGui:FindFirstChildOfClass("Frame")
            if frame then
                local textLabel = frame:FindFirstChild("TextLabel")
                if textLabel then
                    local ownerName = string.match(textLabel.Text, "^(%S+)'s Base$")
                    if ownerName then
                        return ownerName
                    end
                    if textLabel.Text == "Empty Base" then
                        return "Empty"
                    end
                end
            end
        end
    end
    return nil
end

local function getPurchaseData(plot)
    local purchaseData = {}
    local purchasesFolder = plot:FindFirstChild("Purchases")
    if purchasesFolder then
        local plotBlock = purchasesFolder:FindFirstChild("PlotBlock")
        if plotBlock then
            local mainPart = plotBlock:FindFirstChild("Main")
            if mainPart then
                local billboardGui = mainPart:FindFirstChild("BillboardGui")
                if billboardGui then
                    local remainingTimeLabel = billboardGui:FindFirstChild("RemainingTime")
                    if remainingTimeLabel and remainingTimeLabel:IsA("TextLabel") then
                        purchaseData.RemainingTime = remainingTimeLabel.Text
                    end
                end
            end
        end
    end
    return purchaseData
end

local function updateValue(parent, name, value, type)
	local valueInstance = parent:FindFirstChild(name)
	if not valueInstance or not valueInstance:IsA(type) then
		if valueInstance then valueInstance:Destroy() end
		valueInstance = Instance.new(type)
		valueInstance.Name = name
		valueInstance.Parent = parent
	end
	if valueInstance.Value ~= value then
		valueInstance.Value = value
	end
	return valueInstance
end

local function updateBestPetData(bestPetData)
    local bestPetFolder = dataStore:FindFirstChild("BestPet") or Instance.new("Folder")
    if not bestPetFolder.Parent then
        bestPetFolder.Name = "BestPet"
        bestPetFolder.Parent = dataStore
    end

    local isBestPetMine = bestPetData and (bestPetData.owner == player.Name or bestPetData.owner == player.DisplayName)
    
    if not bestPetData or isBestPetMine then
        if #bestPetFolder:GetChildren() > 0 then
            bestPetFolder:ClearAllChildren()
        end
        return
    end

    updateValue(bestPetFolder, "name", bestPetData.name, "StringValue")
    updateValue(bestPetFolder, "generation_value", tostring(bestPetData.generation_value), "StringValue")
    updateValue(bestPetFolder, "mutation", bestPetData.mutation, "StringValue")
    updateValue(bestPetFolder, "price", bestPetData.price, "StringValue")
    updateValue(bestPetFolder, "rarity", bestPetData.rarity, "StringValue")
    updateValue(bestPetFolder, "is_stolen", bestPetData.is_stolen, "BoolValue")
    updateValue(bestPetFolder, "is_in_machine", bestPetData.is_in_machine, "BoolValue")
    updateValue(bestPetFolder, "floor", tostring(bestPetData.floor), "StringValue")
    updateValue(bestPetFolder, "podium_id", tostring(bestPetData.podium_id), "StringValue")
    updateValue(bestPetFolder, "owner", bestPetData.owner, "StringValue")
    updateValue(bestPetFolder, "plotguid", bestPetData.plotguid, "StringValue")
end

local function updateReplicatedStorageData(data, bestPet)
    local playerDataFolder = dataStore:FindFirstChild("PlayerData") or Instance.new("Folder")
    if not playerDataFolder.Parent then
        playerDataFolder.Name = "PlayerData"
        playerDataFolder.Parent = dataStore
    end

    local processedPlots = {}
    for _, plotData in ipairs(data.plots) do
        local folderName = plotData.owner
        if folderName == "Empty" then
            folderName = "Empty_" .. plotData.plotguid
        end
        
        local plotFolder = playerDataFolder:FindFirstChild(folderName) or Instance.new("Folder")
        if not plotFolder.Parent then
            plotFolder.Name = folderName
            plotFolder.Parent = playerDataFolder
        end
        processedPlots[plotFolder.Name] = true

        if plotData.owner == "Empty" then
            updateValue(plotFolder, "is_empty", true, "BoolValue")
            updateValue(plotFolder, "plotguid", plotData.plotguid, "StringValue")
            for _, child in ipairs(plotFolder:GetChildren()) do
                if child.Name ~= "is_empty" and child.Name ~= "plotguid" then
                    child:Destroy()
                end
            end
        else
            updateValue(plotFolder, "is_empty", false, "BoolValue")
            updateValue(plotFolder, "owner", plotData.owner, "StringValue")
            updateValue(plotFolder, "is_mine", plotData.is_mine, "BoolValue")
            updateValue(plotFolder, "plot_id", plotData.plot_id, "StringValue")
            updateValue(plotFolder, "plotguid", plotData.plotguid, "StringValue")

            local summaryFolder = plotFolder:FindFirstChild("summary") or Instance.new("Folder")
            if not summaryFolder.Parent then
                summaryFolder.Name = "summary"
                summaryFolder.Parent = plotFolder
            end
            updateValue(summaryFolder, "floor", tostring(plotData.summary.floor), "StringValue")
            updateValue(summaryFolder, "total_slots", tostring(plotData.summary.total_slots), "StringValue")
            updateValue(summaryFolder, "occupied_slots", tostring(plotData.summary.occupied_slots), "StringValue")
            updateValue(summaryFolder, "empty_slots", tostring(plotData.summary.empty_slots), "StringValue")

            local podsFolder = plotFolder:FindFirstChild("pods") or Instance.new("Folder")
            if not podsFolder.Parent then
                podsFolder.Name = "pods"
                podsFolder.Parent = plotFolder
            end
            
            local processedPods = {}
            if plotData.pods then
                for _, pod in ipairs(plotData.pods) do
                    local podiumFolderName = "podium_" .. pod.podium_id
                    local podiumFolder = podsFolder:FindFirstChild(podiumFolderName) or Instance.new("Folder")
                    if not podiumFolder.Parent then
                        podiumFolder.Name = podiumFolderName
                        podiumFolder.Parent = podsFolder
                    end
                    processedPods[podiumFolder.Name] = true
                    
                    updateValue(podiumFolder, "is_empty", pod.is_empty, "BoolValue")

                    local petFolder = podiumFolder:FindFirstChild("pet")
                    if pod.pet then
                        if not petFolder then
                            petFolder = Instance.new("Folder")
                            petFolder.Name = "pet"
                            petFolder.Parent = podiumFolder
                        end
                        updateValue(petFolder, "name", pod.pet.name, "StringValue")
                        updateValue(petFolder, "generation_value", tostring(pod.pet.generation_value), "StringValue")
                        updateValue(petFolder, "is_stolen", pod.pet.is_stolen, "BoolValue")
                        updateValue(petFolder, "is_in_machine", pod.pet.is_in_machine, "BoolValue")
                        updateValue(petFolder, "mutation", pod.pet.mutation, "StringValue")
                        updateValue(petFolder, "price", pod.pet.price, "StringValue")
                        updateValue(petFolder, "rarity", pod.pet.rarity, "StringValue")
                    elseif petFolder then
                        petFolder:Destroy()
                    end
                end
            end
            for _, child in ipairs(podsFolder:GetChildren()) do
                if not processedPods[child.Name] then
                    child:Destroy()
                end
            end

            local basetimeFolder = plotFolder:FindFirstChild("basetime")
            if plotData.purchase_data and next(plotData.purchase_data) ~= nil then
                if not basetimeFolder then
                    basetimeFolder = Instance.new("Folder")
                    basetimeFolder.Name = "basetime"
                    basetimeFolder.Parent = plotFolder
                end
                updateValue(basetimeFolder, "is_locked", plotData.is_locked, "BoolValue")
                updateValue(basetimeFolder, "RemainingTime", plotData.purchase_data.RemainingTime, "StringValue")
            elseif basetimeFolder then
                basetimeFolder:Destroy()
            end
        end
    end

    for _, child in ipairs(playerDataFolder:GetChildren()) do
        if not processedPlots[child.Name] then
            child:Destroy()
        end
    end
    
    updateBestPetData(bestPet)
end

local function getFloorFromPodiumId(podiumId)
    if podiumId >= 1 and podiumId <= 10 then
        return 1
    elseif podiumId >= 11 and podiumId <= 18 then
        return 2
    elseif podiumId >= 19 and podiumId <= 23 then
        return 3
    else
        return "Unknown"
    end
end

local function runDataGeneration()
    if not Plots then return end
    
    local allPlots = {}
    local totalOccupiedSlots = 0
    local totalEmptySlots = 0
    local totalPlotsCount = #Plots:GetChildren()
    local occupiedPlotsCount = 0
    local emptyPlotsCount = 0
    local bestPet = nil
    local bestGenerationValue = -1
	local processedGuids = {}

    for _, plot in ipairs(Plots:GetChildren()) do
		local guid = plot.Name
		processedGuids[guid] = true
        local plotOwner = getPlotOwnerName(plot)
        local isMine = plotOwner == player.Name or plotOwner == player.DisplayName
        local plotData = {
            owner = plotOwner,
            plot_id = plotOwner and plotOwner ~= "Empty" and plotOwner .. "'s Base" or "Empty Base",
            is_mine = isMine,
            plotguid = guid
        }

        if plotOwner ~= "Empty" then
            occupiedPlotsCount = occupiedPlotsCount + 1
        else
            emptyPlotsCount = emptyPlotsCount + 1
        end

        local occupiedSlots = 0
        local emptySlots = 0
        local totalSlots = 0
        local pods = {}
        local animalPodiums = plot:FindFirstChild("AnimalPodiums")
        if animalPodiums then
            totalSlots = #animalPodiums:GetChildren()
            for _, numberedPodium in ipairs(animalPodiums:GetChildren()) do
                local podiumId = tonumber(numberedPodium.Name) or 0
                local podData = { podium_id = podiumId, is_empty = true }
                local baseModel = numberedPodium:FindFirstChild("Base")
                if baseModel then
                    local spawnPart = baseModel:FindFirstChild("Spawn")
                    if spawnPart and spawnPart:FindFirstChild("Attachment") then
                        local animalOverhead = spawnPart.Attachment:FindFirstChild("AnimalOverhead")
                        if animalOverhead then
                            local generationLabel = animalOverhead:FindFirstChild("Generation")
                            local displayNameLabel = animalOverhead:FindFirstChild("DisplayName")
                            if generationLabel and displayNameLabel then
                                local textValue = generationLabel.Text
                                local generationValue = parseGenerationValue(textValue)
                                
                                local isStolen = false
                                local isInMachine = false
                                local stolenLabel = animalOverhead:FindFirstChild("Stolen")
                                if stolenLabel and stolenLabel.Visible then
                                    local stolenText = stolenLabel.Text
                                    isStolen = string.match(stolenText, "STOLEN") ~= nil
                                    isInMachine = string.match(stolenText, "IN MACHINE") ~= nil
                                end
                                
                                podData.is_empty = false
                                local mutationLabel = animalOverhead:FindFirstChild("Mutation")
                                local priceLabel = animalOverhead:FindFirstChild("Price")
                                local rarityLabel = animalOverhead:FindFirstChild("Rarity")
                                
                                local pet = {
                                    name = displayNameLabel.Text,
                                    generation_value = (generationValue == math.huge) and "Infinity" or generationValue,
                                    mutation = mutationLabel and mutationLabel.Text or "N/A",
                                    price = priceLabel and priceLabel.Text or "N/A",
                                    rarity = rarityLabel and rarityLabel.Text or "N/A",
                                    is_stolen = isStolen,
                                    is_in_machine = isInMachine,
                                    owner = plotOwner,
                                    floor = getFloorFromPodiumId(podiumId),
                                    podium_id = podiumId,
                                    plotguid = guid
                                }
                                podData.pet = pet
                                occupiedSlots = occupiedSlots + 1

                                local parsedValue = (typeof(pet.generation_value) == "string" and pet.generation_value == "Infinity") and math.huge or tonumber(pet.generation_value)
                                if (not isMine) and parsedValue > bestGenerationValue then
                                    bestGenerationValue = parsedValue
                                    bestPet = pet
                                end
                            else
                                emptySlots = emptySlots + 1
                            end
                        else
                            emptySlots = emptySlots + 1
                        end
                    else
                        emptySlots = emptySlots + 1
                    end
                else
                    emptySlots = emptySlots + 1
                end
                table.insert(pods, podData)
            end
        end

        plotData.summary = {
            floor = getFloorFromSlotCount(totalSlots),
            total_slots = totalSlots,
            occupied_slots = occupiedSlots,
            empty_slots = emptySlots
        }
        plotData.pods = pods
        plotData.purchase_data = getPurchaseData(plot)
        
        local remainingTimeText = plotData.purchase_data and plotData.purchase_data.RemainingTime
        local isLocked = remainingTimeText and remainingTimeText ~= "0s"

        if remainingTimeText == "1s" then
            local firstSeenTime = plotLockdownState[guid]
            if not firstSeenTime then
                plotLockdownState[guid] = time()
            elseif time() - firstSeenTime > 1.1 then
                isLocked = false
            end
        else
            plotLockdownState[guid] = nil
        end
        plotData.is_locked = isLocked

        totalOccupiedSlots = totalOccupiedSlots + occupiedSlots
        totalEmptySlots = totalEmptySlots + emptySlots
        table.insert(allPlots, plotData)
    end
	
	for guidInState in pairs(plotLockdownState) do
		if not processedGuids[guidInState] then
			plotLockdownState[guidInState] = nil
		end
	end

    local finalData = {
        plots = allPlots,
        server_summary = {
            total_plots = totalPlotsCount,
            occupied_plots = occupiedPlotsCount,
            empty_plots = emptyPlotsCount,
            occupied_slots = totalOccupiedSlots,
            empty_slots = totalEmptySlots
        }
    }
    updateReplicatedStorageData(finalData, bestPet)
end

local function generatePetData()
    if updatePending then return end
    updatePending = true
    task.defer(function()
        runDataGeneration()
        updatePending = false
    end)
end

local function setupListenersForGui(animalOverhead)
    if not animalOverhead then return end
    local function connectSignal(obj, prop)
        table.insert(connections, obj:GetPropertyChangedSignal(prop):Connect(generatePetData))
    end
    local generationLabel = animalOverhead:FindFirstChild("Generation")
    if generationLabel then connectSignal(generationLabel, "Text") end
    local stolenLabel = animalOverhead:FindFirstChild("Stolen")
    if stolenLabel then
        connectSignal(stolenLabel, "Text")
        connectSignal(stolenLabel, "Visible")
    end
    animalOverhead.ChildAdded:Connect(function(child)
        if child.Name == "Generation" or child.Name == "Stolen" then
            generatePetData()
        end
    end)
end

local function setupListenersForPodium(numberedPodium)
    local baseModel = numberedPodium:FindFirstChild("Base")
    if not baseModel then return end
    local spawnPart = baseModel:FindFirstChild("Spawn")
    if not spawnPart then return end
    
    local function setupForAttachment(attachment)
        if not attachment then return end
        attachment.ChildAdded:Connect(function(child)
            if child.Name == "AnimalOverhead" then
                setupListenersForGui(child)
                generatePetData()
            end
        end)
        local animalOverhead = attachment:FindFirstChild("AnimalOverhead")
        if animalOverhead then
            setupListenersForGui(animalOverhead)
        end
    end
    
    spawnPart.ChildRemoved:Connect(function(child)
        if child.Name == "Attachment" then generatePetData() end
    end)
    spawnPart.ChildAdded:Connect(function(child)
        if child.Name == "Attachment" then
            setupForAttachment(child)
            generatePetData()
        end
    end)
    
    local attachment = spawnPart:FindFirstChild("Attachment")
    if attachment then setupForAttachment(attachment) end
end

local function setupListenersForPlotBlock(plotBlock)
    local mainPart = plotBlock:FindFirstChild("Main")
    if not mainPart then return end
    local billboardGui = mainPart:FindFirstChild("BillboardGui")
    if not billboardGui then return end
    local remainingTimeLabel = billboardGui:FindFirstChild("RemainingTime")
    if remainingTimeLabel and remainingTimeLabel:IsA("TextLabel") then
        table.insert(connections, remainingTimeLabel:GetPropertyChangedSignal("Text"):Connect(generatePetData))
    end
end

local function setupListenersForPlot(plot)
    local animalPodiums = plot:FindFirstChild("AnimalPodiums")
    if animalPodiums then
        for _, numberedPodium in ipairs(animalPodiums:GetChildren()) do
            setupListenersForPodium(numberedPodium)
        end
        animalPodiums.ChildAdded:Connect(setupListenersForPodium)
        animalPodiums.ChildRemoved:Connect(generatePetData)
    end
    
    local purchasesFolder = plot:FindFirstChild("Purchases")
    if purchasesFolder then
        for _, plotBlock in ipairs(purchasesFolder:GetChildren()) do
            setupListenersForPlotBlock(plotBlock)
        end
        purchasesFolder.ChildAdded:Connect(setupListenersForPlotBlock)
    end
end

local function start()
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    connections = {}
    
    if Plots then
        for _, plot in ipairs(Plots:GetChildren()) do
            setupListenersForPlot(plot)
        end
        Plots.ChildAdded:Connect(function(plot)
            setupListenersForPlot(plot)
            generatePetData()
        end)
        Plots.ChildRemoved:Connect(generatePetData)
    end
    
    RunService.Heartbeat:Connect(function()
        if time() - lastPollTime > 1 then
            lastPollTime = time()
            generatePetData()
        end
    end)
    
    generatePetData()
end

start()
