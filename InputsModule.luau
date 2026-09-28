--Connected Discord-Github   @JaydenDhsm / rblx -- IllllIIIlIIIIIIIllll
--!strict

local activePlayers: {[number]: PlayerInput} = {}

local module = {}

type PlayerInput = {
	mousePos: Vector3?,
	cameraCFrame: CFrame?
}

function module.addPlayer(player: Player)
	local userId = player.UserId

	activePlayers[userId] = {
		mousePos = nil,
		cameraCFrame = nil
	}
end

function module.removePlayer(player: Player)
	local userId = player.UserId
	activePlayers[userId] = nil
end

function module.setInput(player: Player, mousePos: Vector3, cameraCFrame: CFrame)
	local userId = player.UserId
	local playerData = activePlayers[userId]

	if not playerData then
		return
	end

	if typeof(mousePos) ~= "Vector3" then
		return
	end

	if typeof(cameraCFrame) ~= "CFrame" then
		return
	end

	if mousePos.Magnitude > 100000 then
		return
	end

	if cameraCFrame.Position.Magnitude > 100000 then
		return
	end

	playerData.mousePos = mousePos
	playerData.cameraCFrame = cameraCFrame
end

function module.getMousePos(player: Player): Vector3?
	local playerData = activePlayers[player.UserId]

	if not playerData then
		return nil
	end

	return playerData.mousePos
end

function module.getCameraCFrame(player: Player): CFrame?
	local playerData = activePlayers[player.UserId]

	if not playerData then
		return nil
	end

	return playerData.cameraCFrame
end

return module