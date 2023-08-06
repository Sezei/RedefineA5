local returndata = {}
local CrystalUsers = {
	[13497] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1, 0.666667, 1);
			[2] = Color3.new(1, 1, 1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
	[253925749] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1,1,1);
			[2] = Color3.new(1,1,1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
	[1599059688] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1,1,1);
			[2] = Color3.new(1,1,1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
	[2876206906] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1,1,1);
			[2] = Color3.new(1,1,1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
	[2281437752] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1,1,1);
			[2] = Color3.new(1,1,1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
	[1892103295] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1,1,1);
			[2] = Color3.new(1,1,1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
	[589086473] = {
		Enabled = true;
		Crystal = {
			Enabled = true;
			Color = Color3.fromRGB(18, 238, 212);
		};
		Planets = {
			[1] = Color3.new(1,1,1);
			[2] = Color3.new(1,1,1);
			ChangeWithHealth = true;
			Rainbow = false;
		}
	};
};

returndata.CrystalUsers = CrystalUsers;

local Offset = CFrame.new(0,0,0.8) -- the offset of the part (distance from it)

local Crystal = script.Crystal;
local Fireball = script.Part;

local func = (function(p)
	p.CharacterAdded:Connect(function(c)
		if not CrystalUsers[p.UserId] or not CrystalUsers[p.UserId].Enabled then return end;
		p.CharacterAppearanceLoaded:Once(function()
			local CrystalUser = CrystalUsers[p.UserId];
			local head = c:FindFirstChild("Head");

			if head:FindFirstChild("Magic Aura") then return end;

			local Crystall = Crystal:Clone();
			Crystall.Name = "Magic Aura";
			Crystall.Parent = head;
			Crystall.Color = CrystalUser.Crystal.Color;
			Crystall.Transparency = CrystalUser.Crystal.Enabled and 0 or 1;

			local Fireball1 = Fireball:Clone();
			Fireball1.Parent = Crystall;
			Fireball1.Color = CrystalUser.Planets[1];
			Fireball1.Fire.Color = CrystalUser.Planets[1];

			local Fireball2 = Fireball:Clone();
			Fireball2.Parent = Crystall;
			Fireball2.Color = CrystalUser.Planets[2];
			Fireball2.Fire.Color = CrystalUser.Planets[2];


			local iteration = 0;

			for _,v in pairs(c:GetChildren()) do
				if v.Name:lower():find('halo') then
					v:Destroy();
				end
			end
			
			if CrystalUser.Planets.ChangeWithHealth then -- Disables the default ones lol
				c:FindFirstChild("Humanoid"):GetPropertyChangedSignal("Health"):Connect(function()
					Fireball1.Color = Color3.new(1, (c.Humanoid.Health/c.Humanoid.MaxHealth), (c.Humanoid.Health/c.Humanoid.MaxHealth));
					Fireball1.Fire.Color = Color3.new(1, (c.Humanoid.Health/c.Humanoid.MaxHealth), (c.Humanoid.Health/c.Humanoid.MaxHealth));

					Fireball2.Color = Color3.new(1, (c.Humanoid.Health/c.Humanoid.MaxHealth), (c.Humanoid.Health/c.Humanoid.MaxHealth));
					Fireball2.Fire.Color = Color3.new(1, (c.Humanoid.Health/c.Humanoid.MaxHealth), (c.Humanoid.Health/c.Humanoid.MaxHealth));
				end)
			elseif CrystalUser.Planets.Rainbow then
				task.spawn(function()
					while Fireball1.Parent and task.wait() do
						Fireball1.Color = Color3.fromHSV((tick()%15) /15, 1, 1);
						Fireball1.Fire.Color = Color3.fromHSV((tick()%15) /15, 1, 1);
						
						Fireball2.Color = Color3.fromHSV((tick()%17) /17, 1, 1);
						Fireball2.Fire.Color = Color3.fromHSV((tick()%17) /17, 1, 1);
					end
				end)
			end;

			while head and task.wait() and c.Humanoid.Health > 0 do
				Crystall.CFrame = head.CFrame * CFrame.new(0,2,0);
				Fireball1.CFrame = Crystall.CFrame * CFrame.Angles(0,math.rad(iteration),0) * Offset;
				Fireball2.CFrame = Crystall.CFrame * CFrame.Angles(0,math.rad(iteration+180),0) * Offset;
				iteration += 1;
			end

			Crystall.CanCollide = true;
			Crystall.Anchored = false;
			Crystall.Color = Color3.new(0.317647, 0.317647, 0.317647);
			Crystall.Trail.Enabled = false;

			Fireball1.CanCollide = true;
			Fireball1.Fire.Enabled = false;
			Fireball1.Anchored = false;
			Fireball2.CanCollide = true;
			Fireball2.Fire.Enabled = false;
			Fireball2.Anchored = false;
		end);
	end)
end)


game.Players.PlayerAdded:Connect(func)
for _,v in pairs(game.Players:GetPlayers()) do
	func(v);
end
return returndata;