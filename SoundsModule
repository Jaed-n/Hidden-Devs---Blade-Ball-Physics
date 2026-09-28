--Connected Discord-Github   @JaydenDhsm / rblx -- IllllIIIlIIIIIIIllll
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local soundEvent = ReplicatedStorage:WaitForChild("SoundEvent")

local module = {}

function module.playSoundAtPlayer(player: Player, soundName: string)
	local character = player.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	soundEvent:FireAllClients(player, hrp, soundName)
end

function module.playSoundAtPart(targetPart: BasePart?, soundName: string)
	if not targetPart then return end

	soundEvent:FireAllClients(nil, targetPart, soundName)
end

return module