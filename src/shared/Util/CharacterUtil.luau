local CharacterUtil = {}

function CharacterUtil.Resolve(character)
	if not character or not character:IsA("Model") then return nil end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso")
	local hand = character:FindFirstChild("RightHand")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then return nil end
	if not root or not root:IsA("BasePart") or not torso or not torso:IsA("BasePart") or not hand or not hand:IsA("BasePart") then return nil end
	return { Character = character, Humanoid = humanoid, RootPart = root, UpperTorso = torso, RightHand = hand }
end

function CharacterUtil.WaitForR15(character, timeout)
	local deadline = os.clock() + timeout
	repeat
		local resolved = CharacterUtil.Resolve(character)
		if resolved then return resolved end
		task.wait()
	until os.clock() >= deadline
	return nil
end

return CharacterUtil
