--Connected Discord-Github   @JaydenDhsm / rblx -- IllllIIIlIIIIIIIllll
--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Modules = script.Modules

local AbilitiesModule = require(Modules:WaitForChild("AbilitiesModule"))
local BallsModule = require(Modules:WaitForChild("BallsModule"))
local InputsModule = require(Modules:WaitForChild("InputsModule"))
local PlayersModule = require(Modules:WaitForChild("PlayersModule"))

local AbilityEvent = ReplicatedStorage:WaitForChild("AbilityEvent")
local InputEvent = ReplicatedStorage:WaitForChild("InputEvent")
local NotificationEvent = ReplicatedStorage:WaitForChild("NotificationEvent")

local EquippedAbilities: {[number]: string} = {}

local ValidAbilities: {[string]: string} = {
	["op"] = "OP",
	["rapture"] = "Rapture",
	["titanblade"] = "TitanBlade",
	["dribble"] = "Dribble",
	["singularity"] = "Singularity",
	["deathslash"] = "DeathSlash",
	["slashesoffury"] = "SlashesOfFury",
	["infinity"] = "Infinity",
	["slashofduality"] = "SlashOfDuality",
}

local function SetupPlayer(Player: Player)
	InputsModule.addPlayer(Player)
	PlayersModule.addPlayer(Player)
	AbilitiesModule.addPlayer(Player)
	PlayersModule.CreateFolders(Player)

	EquippedAbilities[Player.UserId] = "DeathSlash"

	Player.Chatted:Connect(function(Message)
		if string.sub(Message, 1, 1) ~= "/" then
			return
		end

		local Command = string.lower(string.sub(Message, 2))
		local AbilityName = ValidAbilities[Command]

		if not AbilityName then
			return
		end

		EquippedAbilities[Player.UserId] = AbilityName
		NotificationEvent:FireClient(Player, "Equipped: " .. AbilityName)
		AbilitiesModule.resetCooldown(Player, AbilityName)
	end)
end

local function RemovePlayer(Player: Player)
	InputsModule.removePlayer(Player)
	PlayersModule.removePlayer(Player)
	AbilitiesModule.removePlayer(Player)
	EquippedAbilities[Player.UserId] = nil
end

Players.PlayerAdded:Connect(SetupPlayer)
Players.PlayerRemoving:Connect(RemovePlayer)

for _, Player in Players:GetPlayers() do
	task.spawn(SetupPlayer, Player)
end

AbilityEvent.OnServerEvent:Connect(function(Player: Player, AbilityType: string)
	local Character = Player.Character
	if not Character then
		return
	end

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid or Humanoid.Health <= 0 then
		return
	end

	if AbilityType == "Deflect" then
		local Animator = Humanoid:FindFirstChildOfClass("Animator")

		if Animator then
			local Animation = ReplicatedStorage.Assets.Animations.Sword.Default.GrabParry
			local Track = Animator:LoadAnimation(Animation)

			Track.Priority = Enum.AnimationPriority.Action
			Track:Play(0.05)
		end

		AbilitiesModule.ability(Player, "Deflect")
	elseif AbilityType == "Ability" then
		local EquippedAbility = EquippedAbilities[Player.UserId]

		if EquippedAbility then
			AbilitiesModule.ability(Player, EquippedAbility)
		end
	end
end)

InputEvent.OnServerEvent:Connect(function(Player: Player, MousePos: Vector3, CameraCFrame: CFrame)
	InputsModule.setInput(Player, MousePos, CameraCFrame)
end)

task.spawn(function()
	while true do
		local Ball = BallsModule.new()
		Ball.ball.Position = Vector3.new(0, 3, 0)

		task.wait(0.5)

		Ball:act()
		Ball.ball.Destroying:Wait()

		task.wait(1.5)
	end
end)