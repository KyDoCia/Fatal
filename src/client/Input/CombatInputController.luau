local ContextActionService = game:GetService("ContextActionService")

local CombatInputController = {}
CombatInputController.__index = CombatInputController

function CombatInputController.new(parryIntent)
	return setmetatable({ Remote = parryIntent, Bound = false }, CombatInputController)
end

function CombatInputController:Bind()
	assert(not self.Bound, "combat input already bound")
	self.Bound = true
	ContextActionService:BindAction("CombatParry", function(_, state)
		if state == Enum.UserInputState.Begin then
			local camera = workspace.CurrentCamera
			local viewport = camera and camera.ViewportSize or Vector2.zero
			local ray = camera and camera:ViewportPointToRay(viewport.X * 0.5, viewport.Y * 0.5)
			self.Remote:FireServer(ray and ray.Direction or nil)
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.F)
end

function CombatInputController:Destroy()
	if self.Bound then ContextActionService:UnbindAction("CombatParry"); self.Bound = false end
end

return CombatInputController
