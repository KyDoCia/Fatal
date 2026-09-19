local UserInputService = game:GetService("UserInputService")

local InventoryController = {}

function InventoryController.Start(player, request, state)
	local gui = player.PlayerGui:FindFirstChild("InventoryGui")
	while not gui do
		local child = player.PlayerGui.ChildAdded:Wait()
		gui = if child.Name == "InventoryGui" then child else player.PlayerGui:FindFirstChild("InventoryGui")
	end
	local panel = gui.Panel
	local equip = panel.Equip
	gui.Enabled = false
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.I then gui.Enabled = not gui.Enabled end
	end)
	equip.Activated:Connect(function() request:FireServer("EquipWeapon", "TrainingBlade") end)
	state.OnClientEvent:Connect(function(payload)
		local owned = type(payload) == "table" and payload.Weapons and payload.Weapons.TrainingBlade == true
		panel.Item.Text = owned and "TRAINING BLADE" or "LOCKED"
		equip.Text = payload.EquippedWeapon == "TrainingBlade" and "EQUIPPED" or "EQUIP"
		equip.Active = owned and payload.EquippedWeapon ~= "TrainingBlade"
	end)
	request:FireServer("GetState")
end

return InventoryController
