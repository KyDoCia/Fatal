local Controller = {}
Controller.__index = Controller

local function variant(direction, character)
	if not direction then return "Default" end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local relative = if root and root:IsA("BasePart") then root.CFrame:VectorToObjectSpace(direction) else direction
	if relative.Y > 0.45 then return "Up" end
	return if relative.X < -0.2 then "Left" elseif relative.X > 0.2 then "Right" else "Default"
end

function Controller.new(presentation, animationSet)
	local self = setmetatable({ Presentation = presentation, Set = animationSet, Attempt = 0, Confirmed = 0, Tracks = {}, PendingMiss = nil }, Controller)
	self.Connection = presentation.Player.CharacterAdded:Connect(function(character) self:Load(character) end)
	self.RemovingConnection = presentation.Player.CharacterRemoving:Connect(function(character)
		if character == self.Character then self:Clear() end
	end)
	if presentation.Player.Character then self:Load(presentation.Player.Character) end
	return self
end

function Controller:Clear()
	if self.PendingMiss then task.cancel(self.PendingMiss); self.PendingMiss = nil end
	for _, track in self.Tracks do track:Stop(0); track:Destroy() end
	table.clear(self.Tracks)
	self.Character = nil
end

function Controller:Load(character)
	self:Clear()
	self.Character = character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and (humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 3))
	if not animator then return end
	local function load(name, id)
		if id == "" then return end
		local animation = Instance.new("Animation"); animation.AnimationId = id
		local track = animator:LoadAnimation(animation); animation:Destroy()
		track.Priority = Enum.AnimationPriority.Action; self.Tracks[name] = track
	end
	load("Equip", self.Set.Equip)
	load("Attempt", self.Set.ParryAttempt)
	for name, id in self.Set.ParryHit do load("Hit" .. name, id) end
	if type(self.Set.ParryMiss) == "table" then
		for name, id in self.Set.ParryMiss do load("Miss" .. name, id) end
	else
		load("MissDefault", self.Set.ParryMiss)
	end
	if self.Tracks.Equip then self.Tracks.Equip:Play(0.05) end
end

function Controller:PlayAttempt(direction)
	self.Attempt += 1
	local attempt = self.Attempt
	local directionVariant = variant(direction, self.Character)
	self.Presentation:PresentIntent(direction)
	if self.PendingMiss then task.cancel(self.PendingMiss) end
	if self.Tracks.Attempt then self.Tracks.Attempt:Play(0.03) end
	self.PendingMiss = task.delay(0.18, function()
		self.PendingMiss = nil
		if self.Attempt ~= attempt or self.Confirmed >= attempt then return end
		if self.Tracks.Attempt and self.Tracks.Attempt.IsPlaying then self.Tracks.Attempt:Stop(0.03) end
		local track = self.Tracks["Miss" .. directionVariant] or self.Tracks.MissDefault
		if track then track:Play(0.03) end
		self.Presentation:PresentMiss(directionVariant)
	end)
end

function Controller:Confirm(direction)
	self.Confirmed = self.Attempt
	if self.PendingMiss then task.cancel(self.PendingMiss); self.PendingMiss = nil end
	if self.Tracks.Attempt and self.Tracks.Attempt.IsPlaying then self.Tracks.Attempt:Stop(0.03) end
	for name, missTrack in self.Tracks do if string.sub(name, 1, 4) == "Miss" and missTrack.IsPlaying then missTrack:Stop(0.03) end end
	local directionVariant = variant(direction, self.Character)
	local track = self.Tracks["Hit" .. directionVariant] or self.Tracks.HitDefault
	if track then track:Play(0.02) end
	self.Presentation:PresentParry(directionVariant)
end

function Controller:Destroy()
	self.Attempt += 1
	if self.Connection then self.Connection:Disconnect() end
	if self.RemovingConnection then self.RemovingConnection:Disconnect() end
	self:Clear()
end

return Controller
