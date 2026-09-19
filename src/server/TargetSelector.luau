local TargetSelector = {}

function TargetSelector.Select(registry, excluded)
	local alive = registry:GetAlive()
	if #alive == 0 then return nil end
	if #alive == 1 then return if alive[1] ~= excluded then alive[1] else nil end
	for index, combatant in alive do
		if combatant == excluded then return alive[index % #alive + 1] end
	end
	return alive[1]
end

return table.freeze(TargetSelector)
