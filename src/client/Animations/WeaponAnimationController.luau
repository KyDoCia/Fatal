local Controller = {}
Controller.__index = Controller

local function variant(direction)
	if not direction then return "Default" end
	if direction.Y > 0.45 then return "Up" end
	return if direction.X < -0.2 then "Left" elseif direction.X > 0.2 then "Right" else "Default"
end

function Controller.new(presentation, animationSet)
	local self = setmetatable({ Presentation = presentation, Set = animationSet, Attempt = 0, Confirmed = 0, Tracks = {} }, Controller)
	self.Connection = presentation.Player.CharacterAdded:Connect(function(character) self:Load(character) end)
	if presentation.Player.Character then self:Load(presentation.Player.Character) end
	return self
end

function Controller:Load(character)
	for _, track in self.Tracks do track:Stop(0); track:Destroy() end
	table.clear(self.Tracks)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 3))
	if not animator then return end
	local function load(name, id)
		if id == "" then return end
		local animation = Instance.new("Animation"); animation.AnimationId = id
		local track = animator:LoadAnimation(animation); animation:Destroy()
		track.Priority = Enum.AnimationPriority.Action; self.Tracks[name] = track
	end
	for name, id in self.Set.ParryHit do load("Hit" .. name, id) end
	for name, id in self.Set.ParryMiss do load("Miss" .. name, id) end
end

function Controller:PlayAttempt(direction)
	self.Attempt += 1
	local attempt = self.Attempt
	self.Presentation:PresentIntent(direction)
	local track = self.Tracks["Miss" .. variant(direction)] or self.Tracks.MissDefault
	if track then track:Play(0.03) end
	task.delay(0.18, function()
		if self.Attempt == attempt and self.Confirmed < attempt then self.Presentation:PresentMiss(variant(direction)) end
	end)
end

function Controller:Confirm(direction)
	self.Confirmed = self.Attempt
	for name, missTrack in self.Tracks do if string.sub(name, 1, 4) == "Miss" and missTrack.IsPlaying then missTrack:Stop(0.03) end end
	local track = self.Tracks["Hit" .. variant(direction)] or self.Tracks.HitDefault
	if track then track:Play(0.02) end
	self.Presentation:PresentParry(variant(direction))
end

function Controller:Destroy()
	self.Attempt += 1
	if self.Connection then self.Connection:Disconnect() end
	for _, track in self.Tracks do track:Stop(0); track:Destroy() end
	table.clear(self.Tracks)
end

return Controller
