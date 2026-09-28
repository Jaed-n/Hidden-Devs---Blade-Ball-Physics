--Connected Discord-Github   @JaydenDhsm / rblx -- IllllIIIlIIIIIIIllll
--!strict

local objectsEffectsId: {[Instance]: {[string]: number}} = setmetatable({}, {
	__mode = "k"
})

local globalEffectCounter = 0

local module = {}

function module.addEffect(object: Instance, effect: string): number
	local objectEffectsId = objectsEffectsId[object]

	if not objectEffectsId then
		objectEffectsId = {}
		objectsEffectsId[object] = objectEffectsId
	end

	globalEffectCounter += 1
	objectEffectsId[effect] = globalEffectCounter

	return globalEffectCounter
end

function module.removeEffect(object: Instance, effect: string, id: number): boolean?
	local objectEffectsId = objectsEffectsId[object]
	if not objectEffectsId then
		return nil
	end

	if objectEffectsId[effect] ~= id then
		return nil
	end

	objectEffectsId[effect] = nil
	return true
end

function module.hasEffect(object: Instance, effect: string): boolean
	local objectEffectsId = objectsEffectsId[object]
	if not objectEffectsId then
		return false
	end

	return objectEffectsId[effect] ~= nil
end

function module.hasSameEffect(object: Instance, effect: string, id: number): boolean
	local objectEffectsId = objectsEffectsId[object]
	if not objectEffectsId then
		return false
	end

	return objectEffectsId[effect] == id
end

function module.forceRemoveEffect(object: Instance, effect: string): boolean?
	local objectEffectsId = objectsEffectsId[object]
	if not objectEffectsId then
		return nil
	end

	objectEffectsId[effect] = nil
	return true
end

return module