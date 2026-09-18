local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")

local InputController = {}

function InputController.Start(button, callback)
	local actionName = "FatalParry"
	ContextActionService:BindAction(actionName, function(_, inputState)
		if inputState == Enum.UserInputState.Begin and not UserInputService:GetFocusedTextBox() then callback() end
		return Enum.ContextActionResult.Sink
	end, false, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	button.Visible = UserInputService.TouchEnabled
	local click = button.Activated:Connect(callback)
	return function()
		click:Disconnect()
		ContextActionService:UnbindAction(actionName)
	end
end

return InputController
