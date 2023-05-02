local mouse = game:GetService("Players").LocalPlayer:GetMouse();
local UserInputService = game:GetService("UserInputService");
local defaultmouseicon = "rbxasset://textures/Cursors/KeyboardMouse/ArrowFarCursor.png";
local draggingbutton = "http://www.roblox.com/asset/?id=10965462721";

return function(inst,dragpart)
	local dragging
	local dragInput
	local dragStart
	local startPos

	if not dragpart then dragpart = inst end;

	local function update(input)
		local delta = input.Position - dragStart
		--inst.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		inst:TweenPosition(UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y), "Out", "Quad", 0.1, true);
	end

	dragpart.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = inst.Position
			mouse.Icon = draggingbutton;

			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
					mouse.Icon = defaultmouseicon;
				end
			end)
		end
	end)

	dragpart.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
end