--!strict
-- FOV + дистанция + бюджет: какие блоки получают наросты (shell / crystal).

export type VisConfig = {
	range: number,
	fovAttach: number,
	fovKeep: number,
	fovWeight: number,
}

export type Visibility = {
	dist: number,
	fovDot: number,
	inRange: boolean,
	inFovAttach: boolean,
	inFovKeep: boolean,
	priority: number,
}

export type Entry = {
	key: string,
	hasDecor: boolean,
	vis: Visibility,
}

export type PickResult = {
	keep: { [string]: boolean },
	attach: { [string]: boolean },
	remove: { [string]: boolean },
}

local HOVER_PRIORITY_BONUS = 1e6

local MiningBlockDecor = {}

function MiningBlockDecor.computeVisibility(
	blockPos: Vector3,
	camPos: Vector3,
	camLook: Vector3,
	cfg: VisConfig
): Visibility
	local offset = blockPos - camPos
	local dist = offset.Magnitude
	local fovDot = if dist > 0.05 then offset.Unit:Dot(camLook) else 1
	local inRange = dist <= cfg.range
	return {
		dist = dist,
		fovDot = fovDot,
		inRange = inRange,
		inFovAttach = fovDot >= cfg.fovAttach,
		inFovKeep = fovDot >= cfg.fovKeep,
		priority = dist - fovDot * cfg.fovWeight,
	}
end

function MiningBlockDecor.pick(entries: { Entry }, maxCount: number, priorityKey: string?): PickResult
	local keep: { [string]: boolean } = {}
	local attach: { [string]: boolean } = {}
	local remove: { [string]: boolean } = {}

	local eligible: { Entry } = {}
	for _, e in ipairs(entries) do
		if not e.vis.inRange then
			if e.hasDecor then
				remove[e.key] = true
			end
			continue
		end
		local inCone = if e.hasDecor then e.vis.inFovKeep else e.vis.inFovAttach
		if inCone or e.key == priorityKey then
			table.insert(eligible, e)
		elseif e.hasDecor then
			remove[e.key] = true
		end
	end

	table.sort(eligible, function(a, b)
		local pa = a.vis.priority - (if a.key == priorityKey then HOVER_PRIORITY_BONUS else 0)
		local pb = b.vis.priority - (if b.key == priorityKey then HOVER_PRIORITY_BONUS else 0)
		return pa < pb
	end)

	local count = 0
	for _, e in ipairs(eligible) do
		if count >= maxCount then
			if e.hasDecor then
				remove[e.key] = true
			end
			continue
		end
		keep[e.key] = true
		if not e.hasDecor then
			attach[e.key] = true
		end
		count += 1
	end

	for _, e in ipairs(entries) do
		if e.hasDecor and not keep[e.key] and not remove[e.key] then
			remove[e.key] = true
		end
	end

	return { keep = keep, attach = attach, remove = remove }
end

return MiningBlockDecor
