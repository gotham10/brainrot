print("version 0.3")
local rs = game:GetService("ReplicatedStorage")
local ws = game:GetService("Workspace")
local ctrls = rs:WaitForChild("Controllers")
local AnimalClient = require(rs:WaitForChild("Classes"):WaitForChild("AnimalClient"))
local PlotController = require(ctrls:WaitForChild("PlotController"))
local CharacterController = require(ctrls:WaitForChild("CharacterController"))

local function formatNumber(value)
	local suffixes = {"", "K", "M", "B", "T"}
	local suffixNum = 1
	while value >= 1000 and suffixNum < #suffixes do
		value = value / 1000
		suffixNum = suffixNum + 1
	end
	if suffixNum > 1 then
		return string.format("%.2f%s", value, suffixes[suffixNum])
	else
		return tostring(math.floor(value))
	end
end

local function setModelTransparency(model, transparency)
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			descendant.Transparency = transparency
		end
	end
end

PlotController:Start()
local myPlot
repeat
	myPlot = PlotController:GetMyPlot()
	task.wait()
until myPlot

local plotModel = typeof(myPlot) == "table" and myPlot.PlotModel or myPlot
if not plotModel or not plotModel:IsDescendantOf(ws.Plots) then return end
local podiums = plotModel:FindFirstChild("AnimalPodiums")
if not podiums then return end

local function getFreePodium()
	for i, podium in ipairs(podiums:GetChildren()) do
		if not podium:IsA("Model") then continue end
		local base = podium:FindFirstChild("Base")
		if not base then continue end
		local spawnPart = base:FindFirstChild("Spawn")
		if not spawnPart then continue end
		local podiumAttachment = spawnPart:FindFirstChild("Attachment")
		if podiumAttachment and podiumAttachment:IsA("Attachment") then
			if podiumAttachment:FindFirstChild("AnimalOverhead") then
				continue
			end
		end
		local claim = podium:FindFirstChild("Claim")
		if not claim then continue end
		local main = claim:FindFirstChild("Main") or claim:FindFirstChild("Hitbox")
		local deco = base:FindFirstChild("Decorations")
		if not main or not deco then continue end
		local p = deco:FindFirstChild("Part")
		if not p then continue end
		return podium, main, p, spawnPart
	end
end

local heldAnimal = nil

return function(animalsToSpawn, chosenIndex)
	for i,info in ipairs(animalsToSpawn) do
		local podium, targetMain, targetDeco, targetSpawn
		if chosenIndex and podiums:FindFirstChild(chosenIndex) then
			local chosen = podiums:FindFirstChild(chosenIndex)
			local base = chosen:FindFirstChild("Base")
			local spawnPart = base and base:FindFirstChild("Spawn")
			local claim = chosen:FindFirstChild("Claim")
			local main = claim and (claim:FindFirstChild("Main") or claim:FindFirstChild("Hitbox"))
			local deco = base and base:FindFirstChild("Decorations")
			local p = deco and deco:FindFirstChild("Part")
			if base and spawnPart and claim and main and p then
				podium, targetMain, targetDeco, targetSpawn = chosen, main, p, spawnPart
			end
		end
		if not podium then
			podium, targetMain, targetDeco, targetSpawn = getFreePodium()
		end
		if not podium then break end
		local model = Instance.new("Model")
		model.Name = info.name
		local part = Instance.new("Part")
		part.Name = "PrimaryPart"
		part.Size = Vector3.new(0, 0, 0)
		part.Anchored = true
		part.CanCollide = false
		part.Transparency = 1
		local position = Vector3.new(targetDeco.Position.X, targetDeco.Position.Y + (targetDeco.Size.Y / 2) + (part.Size.Y / 2), targetDeco.Position.Z)
		local lookAtPosition = targetMain.Position
		local correctedLookAt = Vector3.new(lookAtPosition.X, position.Y, lookAtPosition.Z)
		part.CFrame = CFrame.new(position, correctedLookAt)
		part.Parent = model
		model.PrimaryPart = part
		model.Parent = plotModel
		model:SetAttribute("Index", info.name)
		model:SetAttribute("ForceIdle", true)
		if info.mutations and #info.mutations > 0 then
			model:SetAttribute("Mutation", info.mutations[1])
		end
		local podiumAttachment = targetSpawn:FindFirstChild("Attachment")
		if not podiumAttachment or not podiumAttachment:IsA("Attachment") then
			podiumAttachment = Instance.new("Attachment")
			podiumAttachment.Name = "Attachment"
			podiumAttachment.Parent = targetSpawn
		end
		local animalOverhead = Instance.new("Folder")
		animalOverhead.Name = "AnimalOverhead"
		animalOverhead.Parent = podiumAttachment

		local promptAttachment = targetSpawn:FindFirstChild("PromptAttachment")
		if promptAttachment and promptAttachment:IsA("Attachment") then
			local sellPrompt, grabPrompt
			for _, p in ipairs(promptAttachment:GetChildren()) do
				if p:IsA("ProximityPrompt") then
					if p.KeyboardKeyCode == Enum.KeyCode.F then sellPrompt = p end
					if p.KeyboardKeyCode == Enum.KeyCode.E then grabPrompt = p end
				end
			end

			if sellPrompt and grabPrompt then
				local promptConnections = {}

				local sellValue = math.ceil((info.price or 0) * 0.5)
				sellPrompt.Enabled = true
				sellPrompt:SetAttribute("State", "Sell")
				sellPrompt.ActionText = "Sell: $" .. formatNumber(sellValue)
				sellPrompt.ObjectText = ""

				grabPrompt.Enabled = true
				grabPrompt:SetAttribute("State", "Grab")
				grabPrompt.ActionText = "Grab"
				grabPrompt.ObjectText = info.name
				grabPrompt.HoldDuration = 0

				local sellTrigger
				sellTrigger = sellPrompt.Triggered:Connect(function()
					if heldAnimal then return end
					model:Destroy()
				end)

				local grabTrigger
				grabTrigger = grabPrompt.Triggered:Connect(function()
					if grabPrompt:GetAttribute("State") == "Grab" then
						if heldAnimal then return end
						
						local heldModel = model:Clone()
						heldModel:SetAttribute("IsHeldVisual", true)
						heldModel.Parent = ws:FindFirstChild("RenderedMovingAnimals")

						heldAnimal = { originalModel = model, heldModel = heldModel }
						setModelTransparency(model, 0.5)
						CharacterController:PlayEmote("HandsUp")
						
						sellPrompt.Enabled = false
						grabPrompt:SetAttribute("State", "Place")
						grabPrompt.ActionText = "Place"
						grabPrompt.HoldDuration = 1.5
					elseif grabPrompt:GetAttribute("State") == "Place" then
						if not heldAnimal or heldAnimal.originalModel ~= model then return end
						
						heldAnimal.heldModel:Destroy()
						CharacterController:PlayAnimation("idle")

						heldAnimal = nil
						setModelTransparency(model, 0)
						sellPrompt.Enabled = true
						grabPrompt:SetAttribute("State", "Grab")
						grabPrompt.ActionText = "Grab"
						grabPrompt.HoldDuration = 0
					end
				end)

				table.insert(promptConnections, sellTrigger)
				table.insert(promptConnections, grabTrigger)

				model.Destroying:Connect(function()
					for _, connection in ipairs(promptConnections) do
						connection:Disconnect()
					end
					if heldAnimal and heldAnimal.originalModel == model then
						heldAnimal.heldModel:Destroy()
						heldAnimal = nil
						CharacterController:PlayAnimation("idle")
					end
					sellPrompt.Enabled = false
					grabPrompt.Enabled = false
					sellPrompt.ActionText = ""
					grabPrompt.ActionText = ""
					sellPrompt.ObjectText = ""
					grabPrompt.ObjectText = ""
					if animalOverhead and animalOverhead.Parent then
						animalOverhead:Destroy()
					end
				end)
			end
		end

		local client = AnimalClient.new(model)
		local renderedMovingAnimals = ws:FindFirstChild("RenderedMovingAnimals")
		if renderedMovingAnimals then
			model.AncestryChanged:Connect(function(_, newParent)
				if newParent == renderedMovingAnimals and not model:GetAttribute("IsHeldVisual") then
					task.wait()
					model.Parent = plotModel
				end
			end)
		end
	end
end
