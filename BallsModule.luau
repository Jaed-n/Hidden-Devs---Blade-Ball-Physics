--Connected Discord-Github   @JaydenDhsm / rblx -- IllllIIIlIIIIIIIllll
--!strict
local ServerStorage = game:GetService("ServerStorage")
local Modules = script.Parent
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local inputsModule = require(Modules:WaitForChild("InputsModule"))
local abilitiesModule = require(Modules:WaitForChild("AbilitiesModule"))
local playersModule = require(Modules:WaitForChild("PlayersModule"))
local effectsModule = require(Modules:WaitForChild("EffectsModule"))
local soundsModule = require(Modules:WaitForChild("SoundsModule"))

local highlightEvent = ReplicatedStorage:WaitForChild("HighlightEvent")
local ballTemplate = ServerStorage:WaitForChild("Ball")
local explosions = ReplicatedStorage.Assets.Explosions

local botsFolder = workspace:WaitForChild("Bots")
local bots = {
	botsFolder:WaitForChild("Bot1"),
	botsFolder:WaitForChild("Bot2")
}

local activeBalls = {}

local module = {}
module.__index = module

type BallStats = {
	velocity: Vector3,
	acceleration: number,
	jerk: number,
	maxDist: number,
	decayPower: number,
	dragCoef: number,
	dragPower: number,
	deflectStrength: number,
	range: number
}

type TemporaryStats = {
	velocity: Vector3?,
	acceleration: number?,
	jerk: number?,
	maxDist: number?,
	decayPower: number?,
	dragCoef: number?,
	dragPower: number?,
	deflectStrength: number?,
	range: number?
}

type WeldState = {
	Token: number,
	Connection: RBXScriptConnection?
}

local weldStates: {[Model]: WeldState} = {}

local function removeHighlight(target: BasePart)
	local character = target.Parent
	if not character then return end

	local highlight = character:FindFirstChild("BallTargetHighlight")
	if highlight and highlight:IsA("Highlight") then
		highlight:Destroy()
	end
end

local function addHighlight(target: BasePart)
	local character = target.Parent
	if not character then return end

	removeHighlight(target)

	local highlight = Instance.new("Highlight")
	highlight.Name = "BallTargetHighlight"
	highlight.FillColor = Color3.new(1, 0, 0)
	highlight.Parent = character
end

local function setWeld(character: Model, state: boolean)
	local sword = character:FindFirstChild("Sword")
	if not sword then
		return
	end

	local manualWeld = sword:FindFirstChild("ManualWeld")
	local weld = sword:FindFirstChild("Weld")

	if not manualWeld or not weld then
		return
	end

	if not manualWeld:IsA("WeldConstraint") or not weld:IsA("WeldConstraint") then
		return
	end

	manualWeld.Enabled = not state
	weld.Enabled = state
end
local function placeEffect(effect: Instance, cframe: CFrame)
	if effect:IsA("BasePart") then
		effect.CFrame = cframe
	elseif effect:IsA("Model") then
		effect:PivotTo(cframe)
	end
end

local function DeathVFX(name: string, character: Model)
	local explosionTemplate = explosions:FindFirstChild(name)
	local rootPart = character:FindFirstChild("HumanoidRootPart")

	if not explosionTemplate or not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local explosion = explosionTemplate:Clone()
	explosion.Parent = workspace

	if explosion:IsA("BasePart") then
		explosion.Position = rootPart.Position
	elseif explosion:IsA("Model") then
		explosion:PivotTo(rootPart.CFrame)
	end

	local attachment = explosion:FindFirstChild("att", true)

	if attachment then
		for _, particle in attachment:GetChildren() do
			if particle:IsA("ParticleEmitter") then
				particle.Enabled = true
				particle:Emit(1)
			end
		end

		local sound = explosion:FindFirstChild("sfx", true)
		if sound and sound:IsA("Sound") then
			sound:Play()
		end
	end

	Debris:AddItem(explosion, 3)
end

function module.new(params)
	params = params or {}

	local self = setmetatable({}, module)
	local ball = ballTemplate:Clone()

	ball.Parent = workspace

	self.ball = ball
	self.target = nil
	self.connection = nil
	self.Hit = explosions:WaitForChild("Hit")

	self.currentValues = {
		velocity = params.velocity or Vector3.zero,
		acceleration = params.acceleration or 0.002,
		jerk = params.jerk or 0.00005,
		maxDist = params.maxDist or 100,
		decayPower = params.decayPower or 0.16,
		dragCoef = params.dragCoef or 0.02,
		dragPower = params.dragPower or 1.6,
		deflectStrength = params.deflectStrength or 0.005,
		range = params.range or 5
	} :: BallStats

	self.tempValues = {
		velocity = nil,
		acceleration = nil,
		jerk = nil,
		maxDist = nil,
		decayPower = nil,
		dragCoef = nil,
		dragPower = nil,
		deflectStrength = nil,
		range = nil
	} :: TemporaryStats

	self.onDeflect = Instance.new("BindableEvent")

	table.insert(activeBalls, self)
	return self
end

function module:setStat(stat: string, value: any)
	-- temporary effects use unique IDs so older effects cannot remove newer ones
	local id = effectsModule.addEffect(self, stat)
	self.tempValues[stat] = value
	return id
end

function module:changeStat(stat: string, value: any)
	self.currentValues[stat] = value
end

function module:resetStat(stat: string, id: any)
	if not effectsModule.removeEffect(self, stat, id) then
		return
	end

	self.tempValues[stat] = nil
end

function module:forceResetStat(stat: string)
	effectsModule.forceRemoveEffect(self, stat)
	self.tempValues[stat] = nil
end

function module:getStat(stat: string)
	return self.currentValues[stat]
end

function module:deflect()
	local targetPlayer = self:getTargetPlayer()
	local deflectStrength = self.tempValues.deflectStrength or self.currentValues.deflectStrength

	local hit = self.Hit:Clone()
	local character = targetPlayer and targetPlayer.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")

	if rootPart and rootPart:IsA("BasePart") then
		hit.Parent = rootPart
		placeEffect(hit, rootPart.CFrame + rootPart.CFrame.LookVector * 2)
	else
		hit.Parent = workspace
		placeEffect(hit, self.ball.CFrame)
	end

	local particleBlacklist = {
		Dust = true,
		crescents = true
	}

	local attachment = hit:FindFirstChild("Attatch", true)

	if attachment then
		for _, particle in attachment:GetDescendants() do
			if not particle:IsA("ParticleEmitter") then
				continue
			end

			particle.Enabled = true
			particle:Emit(20)

			if particleBlacklist[particle.Name] then
				continue
			end

			local startTransparency = particle.Transparency

			-- NumberValue is used because NumberSequence cannot be tweened directly.
			task.delay(0.05, function()
				if not particle.Parent then return end

				local value = Instance.new("NumberValue")
				value.Value = 0

				local connection
				connection = value:GetPropertyChangedSignal("Value"):Connect(function()
					if not particle.Parent then
						if connection then
							connection:Disconnect()
						end
						return
					end

					local alpha = value.Value
					local keypoints = table.create(#startTransparency.Keypoints)

					for _, keypoint in ipairs(startTransparency.Keypoints) do
						keypoints[#keypoints + 1] = NumberSequenceKeypoint.new(
							keypoint.Time,
							keypoint.Value + (1 - keypoint.Value) * alpha,
							keypoint.Envelope
						)
					end

					particle.Transparency = NumberSequence.new(keypoints)
				end)

				TweenService:Create(
					value,
					TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{Value = 1}
				):Play()

				Debris:AddItem(value, 0.35)
			end)
		end
	end

	Debris:AddItem(hit, 0.35)

	local deflectDir: Vector3

	if targetPlayer then
		soundsModule.playSoundAtPlayer(targetPlayer, "DeflectSound")

		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

		if animator then
			local animations = ReplicatedStorage.Assets.Animations.Sword.Default
			local grabParry = animations.GrabParry
			local parrySuccess = animations.ParrySuccess

			local grabTrack

			for _, track in animator:GetPlayingAnimationTracks() do
				if track.Animation and track.Animation.AnimationId == grabParry.AnimationId then
					grabTrack = track
					break
				end
			end

			if grabTrack then
				grabTrack:Stop(0.08)
			end

			local successTrack = animator:LoadAnimation(parrySuccess)
			successTrack.Priority = Enum.AnimationPriority.Action

			local previousState = character and weldStates[character]

			if previousState and previousState.Connection then
				previousState.Connection:Disconnect()
			end

			-- each parry gets a token so an older Heartbeat callback cannot override a newer parry
			local token = (previousState and previousState.Token or 0) + 1

			weldStates[character] = {
				Token = token,
				Connection = nil
			}

			setWeld(character, true)
			successTrack:Play(0.08)

			local connection
			connection = RunService.Heartbeat:Connect(function()
				local currentState = weldStates[character]

				if not currentState or currentState.Token ~= token then
					connection:Disconnect()
					return
				end

				if successTrack.TimePosition >= 0.5 then
				--	setWeld(character, false)
					currentState.Connection = nil
					connection:Disconnect()
				end
			end)

			weldStates[character].Connection = connection
		end

		local nextTarget = self:getNextTarget()

		if nextTarget then
			local direction = nextTarget.Position - self.ball.Position
			deflectDir = direction.Magnitude > 0.001 and direction.Unit or rootPart.CFrame.LookVector
		else
			local direction = self.ball.Position - rootPart.Position
			deflectDir = direction.Magnitude > 0.001 and direction.Unit or rootPart.CFrame.LookVector
		end

		deflectStrength += playersModule.getStat(targetPlayer, "strength") or 0
	else
		if self.target then
			soundsModule.playSoundAtPart(self.target, "DeflectSound")
		end

		local nextTarget = self:getNextTarget()

		if nextTarget then
			local direction = nextTarget.Position - self.ball.Position
			deflectDir = direction.Magnitude > 0.001 and direction.Unit or self.ball.CFrame.LookVector
		elseif self.target then
			deflectDir = self.target.CFrame.LookVector
		else
			deflectDir = self.ball.CFrame.LookVector
		end
	end

	-- removing downward velocity keeps the deflected ball from being launched into the floor
	deflectDir = Vector3.new(
		deflectDir.X,
		math.max(0, deflectDir.Y) + 0.0001,
		deflectDir.Z
	).Unit

	local activeVelocity = self.tempValues.velocity or self.currentValues.velocity
	self.currentValues.velocity = deflectDir * (activeVelocity.Magnitude + deflectStrength)

	self.onDeflect:Fire()
end

function module:act()
	local ball = self.ball

	self.connection = RunService.Heartbeat:Connect(function(dt)
		if not self.target then
			local randomTarget = self:getRandomTarget()

			if randomTarget then
				self:setTarget(randomTarget)
			end

			return
		end

		local vectorToTarget = self.target.Position - ball.Position
		local distance = vectorToTarget.Magnitude

		if distance <= 0.001 then
			return
		end

		local currentAcceleration = self.tempValues.acceleration or self.currentValues.acceleration
		local currentJerk = self.tempValues.jerk or self.currentValues.jerk
		local currentMaxDist = self.tempValues.maxDist or self.currentValues.maxDist
		local currentDecayPower = self.tempValues.decayPower or self.currentValues.decayPower
		local currentDragCoef = self.tempValues.dragCoef or self.currentValues.dragCoef
		local currentDragPower = self.tempValues.dragPower or self.currentValues.dragPower
		local baseRange = self.tempValues.range or self.currentValues.range

		local lethalRange = baseRange
		local deflectRange = baseRange
		local targetPlayer = self:getTargetPlayer()

		if targetPlayer then
			deflectRange += playersModule.getStat(targetPlayer, "reach") or 0
		end

		if distance < deflectRange and not effectsModule.hasEffect(self, "controlled") then
			if targetPlayer then
				local deflecting = effectsModule.hasEffect(targetPlayer, "deflecting")
				local invincible = effectsModule.hasEffect(targetPlayer, "invincible")

				if deflecting then
					playersModule.forceResetStat(targetPlayer, "deflecting")
					abilitiesModule.resetCooldown(targetPlayer, "Deflect")
					self:deflect()

					local nextTarget = self:getNextTarget()
					if nextTarget then
						self:setTarget(nextTarget)
					end

					return
				end

				if distance < lethalRange and not invincible then
					local character = targetPlayer.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")

					if not humanoid then
						return
					end

					humanoid.Health = 0
					DeathVFX("Main", character)
					soundsModule.playSoundAtPlayer(targetPlayer, "KillSound")
					self:destroy()
					return
				end
			elseif distance < lethalRange then
				self:deflect()

				local nextTarget = self:getNextTarget()
				if nextTarget then
					self:setTarget(nextTarget)
				end

				return
			end
		end

		local direction = vectorToTarget.Unit
		local dtScale = dt * 60
		local usingTemporaryVelocity = self.tempValues.velocity ~= nil
		local activeVelocity = usingTemporaryVelocity
			and self.tempValues.velocity
			or self.currentValues.velocity

		-- splitting velocity into radial/tangential parts lets the distance curve control how sharply the ball homes in
		activeVelocity += direction * (currentAcceleration * dtScale)

		local radialVelocity = direction * activeVelocity:Dot(direction)
		local tangentialVelocity = activeVelocity - radialVelocity

		local distanceRatio = math.clamp(distance / currentMaxDist, 0, 1)
		local curve = distanceRatio ^ currentDecayPower
		local newTangentialVelocity = tangentialVelocity * curve
		local removedTangentialSpeed = tangentialVelocity.Magnitude - newTangentialVelocity.Magnitude

		-- removed sideways velocity is redirected forward to preserve the ball's momentum
		local forwardVelocity = direction * removedTangentialSpeed

		activeVelocity = radialVelocity + newTangentialVelocity + forwardVelocity

		local speed = activeVelocity.Magnitude

		if speed > 0 then
			-- exponential drag gives smoother, frame-rate independent velocity decay
			local dragForce = currentDragCoef * speed ^ currentDragPower
			local decayRate = (dragForce / speed) * dtScale
			local dragMultiplier = math.exp(-decayRate)

			activeVelocity *= dragMultiplier
		end

		if usingTemporaryVelocity then
			self.tempValues.velocity = activeVelocity
		else
			self.currentValues.velocity = activeVelocity
		end

		ball.Position = Vector3.new(
			ball.Position.X + activeVelocity.X * dtScale,
			math.max(ball.Position.Y + activeVelocity.Y * dtScale, 2),
			ball.Position.Z + activeVelocity.Z * dtScale
		)

		if not self.tempValues.acceleration then
			-- jerk increases acceleration so the ball speeds up over time
			self.currentValues.acceleration += currentJerk * dtScale
		end
	end)
end

function module:destroy()
	if self.onDeflect then
		self.onDeflect:Destroy()
	end

	if self.connection then
		self.connection:Disconnect()
		self.connection = nil
	end

	if self.target then
		local currentPlayer = self:getTargetPlayer()

		removeHighlight(self.target)

		if currentPlayer then
			highlightEvent:FireClient(currentPlayer, self.ball, false)
		end
	end

	local index = table.find(activeBalls, self)
	if index then
		table.remove(activeBalls, index)
	end

	if self.ball then
		self.ball:Destroy()
	end
end

function module.getAllTargets()
	local targets = {}

	for _, bot in ipairs(bots) do
		local rootPart = bot:FindFirstChild("HumanoidRootPart")

		if rootPart and rootPart:IsA("BasePart") then
			table.insert(targets, rootPart)
		end
	end

	for _, player in Players:GetPlayers() do
		local character = player.Character
		if not character then continue end

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		if not rootPart or not rootPart:IsA("BasePart") or not humanoid then
			continue
		end

		if humanoid.Health <= 0 then
			continue
		end

		table.insert(targets, rootPart)
	end

	return targets
end

function module:getTargetPlayer()
	local target = self.target
	if not target then return nil end

	local character = target.Parent
	if not character then return nil end

	return Players:GetPlayerFromCharacter(character)
end

function module:getRandomTarget()
	local currentTarget = self.target
	local targets = module.getAllTargets()

	if currentTarget then
		local index = table.find(targets, currentTarget)

		if index then
			table.remove(targets, index)
		end
	end

	if #targets == 0 then
		return currentTarget
	end

	return targets[math.random(1, #targets)]
end

function module:getNextTarget(mousePos: Vector3?)
	local currentTarget = self.target
	local targets = module.getAllTargets()

	if currentTarget then
		local index = table.find(targets, currentTarget)

		if index then
			--removing the current target prevents the ball from immediately selecting it again.
			table.remove(targets, index)
		end
	end

	if #targets == 0 then
		return currentTarget
	end

	local targetPlayer = self:getTargetPlayer()

	if targetPlayer then
		mousePos = inputsModule.getMousePos(targetPlayer)
	elseif currentTarget then
		mousePos = currentTarget.Position
	end

	if not mousePos then
		return targets[math.random(1, #targets)]
	end

	local closestTarget = nil
	local closestDistance = math.huge

	for _, target in ipairs(targets) do
		local distance = (target.Position - mousePos).Magnitude

		if distance < closestDistance then
			closestDistance = distance
			closestTarget = target
		end
	end

	return closestTarget
end

function module:setTarget(nextTarget: BasePart?)
	if self.target then
		local currentPlayer = self:getTargetPlayer()

		removeHighlight(self.target)

		if currentPlayer then
			highlightEvent:FireClient(currentPlayer, self.ball, false)
		end
	end

	self.target = nextTarget

	if not nextTarget then
		return
	end

	local targetPlayer = self:getTargetPlayer()

	if targetPlayer then
		highlightEvent:FireClient(targetPlayer, self.ball, true)
	end

	addHighlight(nextTarget)
end

function module.getActiveBalls()
	return activeBalls
end

function module.getNearestBall(player: Player)
	local character = player.Character
	if not character then return nil end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart or not rootPart:IsA("BasePart") then
		return nil
	end

	local nearestBall = nil
	local nearestDistance = math.huge

	for _, ball in ipairs(activeBalls) do
		if not ball.ball or not ball.ball.Parent then
			continue
		end

		local distance = (ball.ball.Position - rootPart.Position).Magnitude

		if distance < nearestDistance then
			nearestDistance = distance
			nearestBall = ball
		end
	end

	return nearestBall
end

function module.getBallsInRadius(position: Vector3, range: number, targetedPlayerOnly: Player?)
	local ballsFound = {}

	for _, ball in ipairs(activeBalls) do
		if not ball.ball or not ball.ball.Parent then
			continue
		end

		local distance = (ball.ball.Position - position).Magnitude

		if distance > range then
			continue
		end

		if targetedPlayerOnly and ball:getTargetPlayer() ~= targetedPlayerOnly then
			continue
		end

		table.insert(ballsFound, ball)
	end

	return ballsFound
end

function module.getNearestTargetToPosition(position: Vector3, ignoreTarget: BasePart?)
	local targets = module.getAllTargets()
	local closestTarget = nil
	local closestDistance = math.huge

	for _, target in ipairs(targets) do
		if target == ignoreTarget then
			continue
		end

		local distance = (target.Position - position).Magnitude

		if distance < closestDistance then
			closestDistance = distance
			closestTarget = target
		end
	end

	return closestTarget
end

return module