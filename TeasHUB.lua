local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local success, errorMessage = pcall(function()
	task.wait(5)

	local player = Players.LocalPlayer
	if not player then
		warn("LocalPlayer henüz yüklenmedi, bekliyorum...")
		Players.PlayerAdded:Wait()
		player = Players.LocalPlayer
		if not player then
			error("LocalPlayer hala yüklenemedi. Script durduruluyor.")
		end
	end

	local playerGui = player:WaitForChild("PlayerGui", 10)
	if not playerGui then
		error("PlayerGui yüklenemedi. Script durduruluyor.")
	end

	local flySpeed = 50
	local speedValue = 16
	local jumpBoost = 50
	local spinValue = 25

	local featureStates = {
		Fly = false,
		Speed = false,
		["Jump Boost"] = false,
		NoClip = false,
		Invisible = false,
		Bang = false,
		Jetpack = false,
		Lightning = false,
		ESP = false,
		Spin = false,
	}

	local selectedPlayerName = nil
	local selectedPlayerButton = nil

	local currentBangLoop, currentBangAnimation, currentBangAnimationTrack, currentBangDiedConnection = nil, nil, nil, nil
	local flyBodyGyro, flyBodyVelocity, flyConnection, flyDiedConnection = nil, nil, nil, nil
	local jetpackConnection = nil
	local noclipConnection = nil
	local originalCharacter, invisibleCharacter, lastInvisCFrame, invisConnection = nil, nil, nil, nil
	local lightningLoop = nil
	local lightningMode = 1
	local espConnection = nil
	local espContainer = nil
	local spinInstance = nil

	local function getRoot(char)
		if not char then return nil end
		return char:FindFirstChild('HumanoidRootPart') or char:FindFirstChild('Torso') or char:FindFirstChild('UpperTorso')
	end

	local function espYarat(targetPlayer)
		if not targetPlayer.Character then return end
		local espFolder = Instance.new("Folder", espContainer)
		espFolder.Name = targetPlayer.Name .. "_ESP"
		local character = targetPlayer.Character
		local head = character:WaitForChild("Head")
		local billboardGui = Instance.new("BillboardGui", espFolder)
		billboardGui.Adornee = head
		billboardGui.Size = UDim2.new(0, 200, 0, 80)
		billboardGui.StudsOffset = Vector3.new(0, 2.5, 0)
		billboardGui.AlwaysOnTop = true
		local textLabel = Instance.new("TextLabel", billboardGui)
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Font = Enum.Font.SourceSans
		textLabel.TextSize = 16
		textLabel.TextColor3 = targetPlayer.TeamColor.Color
		textLabel.TextStrokeTransparency = 0.5
		for _, part in ipairs(character:GetChildren()) do
			if part:IsA("BasePart") then
				local box = Instance.new("BoxHandleAdornment", espFolder)
				box.Adornee = part
				box.Size = part.Size
				box.Color3 = targetPlayer.TeamColor.Color
				box.Transparency = 0.6
				box.AlwaysOnTop = true
			end
		end
	end

	local function stopEsp()
		if espConnection then espConnection:Disconnect(); espConnection = nil end
		if espContainer then pcall(function() espContainer:Destroy() end); espContainer = nil end
		print("ESP modu kapatıldı.")
	end

	local function startEsp()
		stopEsp()
		espContainer = Instance.new("Folder")
		espContainer.Name = "TeasHUB_ESP_Container"
		espContainer.Parent = CoreGui
		print("ESP modu açıldı.")
		espConnection = RunService.RenderStepped:Connect(function()
			if not featureStates.ESP then return end
			for _, targetPlayer in ipairs(Players:GetPlayers()) do
				if targetPlayer ~= player then
					local espFolder = espContainer:FindFirstChild(targetPlayer.Name .. "_ESP")
					if not espFolder or not targetPlayer.Character or not espFolder:FindFirstChild("BillboardGui") or (espFolder:FindFirstChild("BillboardGui") and espFolder.BillboardGui.Adornee.Parent ~= targetPlayer.Character) then
						if espFolder then espFolder:Destroy() end
						espYarat(targetPlayer)
					else
						local billboardGui = espFolder:FindFirstChild("BillboardGui")
						if billboardGui then
							local textLabel = billboardGui:FindFirstChild("TextLabel")
							local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
							if textLabel and humanoid and player.Character and getRoot(player.Character) and getRoot(targetPlayer.Character) then
								local distance = (getRoot(targetPlayer.Character).Position - getRoot(player.Character).Position).Magnitude
								textLabel.Text = string.format("%s\nCan: %.0f\nUzaklık: %.0fm", targetPlayer.Name, humanoid.Health, distance)
							end
						end
					end
				end
			end
		end)
	end

	local function applyLightningMode(mode)
		if lightningLoop then lightningLoop:Disconnect(); lightningLoop = nil end
		if mode == 1 then
			local function applyDarkMode()
				Lighting.ClockTime = 0
				Lighting.Brightness = 0.5
				Lighting.Ambient = Color3.fromRGB(15, 15, 15)
				Lighting.OutdoorAmbient = Color3.fromRGB(15, 15, 15)
				Lighting.GlobalShadows = false
				Lighting.FogEnd = 600
				pcall(function() local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") if atmosphere then atmosphere.Enabled = false end end)
			end
			lightningLoop = RunService.RenderStepped:Connect(applyDarkMode)
			print("Lightning Modu: Karanlık Aktif.")
		elseif mode == 2 then
			Lighting.Brightness = 1
			Lighting.ClockTime = 12
			Lighting.FogEnd = 20000
			Lighting.GlobalShadows = true
			Lighting.Ambient = Color3.fromRGB(128, 128, 128)
			Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
			pcall(function() local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") if atmosphere then atmosphere.Enabled = true end end)
			print("Lightning Modu: Sıfırlandı (Normal).")
		elseif mode == 3 then
			local function applyFullbright()
				Lighting.Brightness = 2
				Lighting.ClockTime = 14
				Lighting.FogEnd = 100000
				Lighting.GlobalShadows = false
				Lighting.Ambient = Color3.fromRGB(192, 192, 192)
				Lighting.OutdoorAmbient = Color3.fromRGB(192, 192, 192)
				pcall(function() local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") if atmosphere then atmosphere.Enabled = false end end)
			end
			lightningLoop = RunService.RenderStepped:Connect(applyFullbright)
			print("Lightning Modu: Fullbright Aktif.")
		end
	end

	local function startLightning() applyLightningMode(lightningMode) end
	local function stopLightning() applyLightningMode(2) end

	local function applyJumpBoost(character, powerValue)
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if humanoid.UseJumpPower then humanoid.JumpPower = powerValue else local gravity = workspace.Gravity humanoid.JumpHeight = (powerValue * powerValue) / (2 * gravity) end
			print("Zıplama gücü/yüksekliği ayarlandı. Güç Değeri: " .. powerValue)
		end
	end

	local function resetJumpBoost(character)
		if not character then return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.JumpPower = 50; humanoid.JumpHeight = 7.2; print("Zıplama gücü sıfırlandı.") end
	end

	local function stopFly()
		if flyConnection then flyConnection:Disconnect(); flyConnection = nil end
		if flyDiedConnection then flyDiedConnection:Disconnect(); flyDiedConnection = nil end
		if flyBodyGyro then flyBodyGyro:Destroy(); flyBodyGyro = nil end
		if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
		if player and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.PlatformStand = false end
		print("Fly modu kapatıldı.")
	end

	local function startFly()
		stopFly()
		local character = player.Character
		if not character then print("Fly için karakter bulunamadı."); return end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		local rootPart = getRoot(character)
		if not humanoid or not rootPart then print("Fly için Humanoid veya RootPart bulunamadı."); return end
		flyBodyGyro = Instance.new("BodyGyro")
		flyBodyGyro.P = 50000; flyBodyGyro.Parent = rootPart; flyBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9); flyBodyGyro.CFrame = rootPart.CFrame
		flyBodyVelocity = Instance.new("BodyVelocity")
		flyBodyVelocity.Parent = rootPart; flyBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9); flyBodyVelocity.Velocity = Vector3.new(0, 0, 0)
		humanoid.PlatformStand = true
		print("Fly modu başlatıldı. Hız: " .. flySpeed)
		flyDiedConnection = humanoid.Died:Connect(function() featureStates.Fly = false; stopFly() end)
		flyConnection = RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			if not camera then return end
			local direction = Vector3.new()
			if UserInputService:IsKeyDown(Enum.KeyCode.W) then direction += camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) then direction -= camera.CFrame.LookVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) then direction += camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) then direction -= camera.CFrame.RightVector end
			if UserInputService:IsKeyDown(Enum.KeyCode.E) then direction += Vector3.new(0, 1, 0) end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) then direction -= Vector3.new(0, 1, 0) end
			if direction.Magnitude > 0 then flyBodyVelocity.Velocity = direction.Unit * flySpeed else flyBodyVelocity.Velocity = Vector3.new(0, 0, 0) end
			flyBodyGyro.CFrame = camera.CFrame
		end)
	end

	local function stopJetpack()
		if jetpackConnection then jetpackConnection:Disconnect(); jetpackConnection = nil end
		print("Jetpack modu kapatıldı.")
	end

	local function startJetpack()
		stopJetpack()
		jetpackConnection = UserInputService.JumpRequest:Connect(function()
			if featureStates.Jetpack and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then
				player.Character.Humanoid:ChangeState("Jumping")
			end
		end)
		print("Jetpack modu açıldı. Zıplama tuşuna basılı tutarak yüksel.")
	end

	local function stopNoclip()
		if noclipConnection then noclipConnection:Disconnect(); noclipConnection = nil end
		if player and player.Character then
			for _, part in ipairs(player.Character:GetDescendants()) do if part:IsA("BasePart") then part.CanCollide = true end end
		end
		print("Noclip modu kapatıldı ve çarpışmalar normale döndürüldü.")
	end

	local function startNoclip()
		stopNoclip()
		noclipConnection = RunService.Stepped:Connect(function()
			if not featureStates.NoClip or not player.Character then return end
			for _, part in ipairs(player.Character:GetDescendants()) do if part:IsA("BasePart") and part.CanCollide == true then part.CanCollide = false end end
		end)
		print("Noclip modu açıldı.")
	end

	local function stopInvisible()
		if invisConnection then invisConnection:Disconnect(); invisConnection = nil end
		if originalCharacter and invisibleCharacter then
			if invisibleCharacter:FindFirstChild("HumanoidRootPart") then lastInvisCFrame = invisibleCharacter.HumanoidRootPart.CFrame end
			player.Character = originalCharacter
			originalCharacter.Parent = workspace
			if originalCharacter:FindFirstChild("HumanoidRootPart") and lastInvisCFrame then originalCharacter:SetPrimaryPartCFrame(lastInvisCFrame) end
			invisibleCharacter:Destroy()
		end
		originalCharacter, invisibleCharacter, lastInvisCFrame, invisConnection = nil, nil, nil, nil
		print("Görünmezlik modu kapatıldı.")
	end

	local function startInvisible()
		stopInvisible()
		local character = player.Character
		if not character or not getRoot(character) then print("Karakter bulunamadı, görünmezlik başlatılamadı."); featureStates.Invisible = false; return end
		character.Archivable = true
		originalCharacter = character
		lastInvisCFrame = getRoot(character).CFrame
		invisibleCharacter = character:Clone()
		invisibleCharacter.Name = "InvisibleClone"
		for _, part in ipairs(invisibleCharacter:GetDescendants()) do if part:IsA("BasePart") then part.Transparency = 0.7; part.Color = Color3.fromRGB(150, 150, 255) end end
		originalCharacter.Parent = game:GetService("Lighting")
		invisibleCharacter.Parent = workspace
		player.Character = invisibleCharacter
		invisibleCharacter:SetPrimaryPartCFrame(lastInvisCFrame)
		local cloneHumanoid = invisibleCharacter:FindFirstChildOfClass("Humanoid")
		if cloneHumanoid then
			cloneHumanoid.Died:Connect(function()
				print("Görünmezken ölüldü, mod sıfırlanıyor.")
				if originalCharacter then originalCharacter:Destroy() end
				stopInvisible()
				featureStates.Invisible = false
			end)
		end
		invisConnection = RunService.Heartbeat:Connect(function()
			if featureStates.Invisible and originalCharacter and invisibleCharacter and getRoot(invisibleCharacter) then
				originalCharacter:SetPrimaryPartCFrame(getRoot(invisibleCharacter).CFrame)
			else
				stopInvisible()
				featureStates.Invisible = false
			end
		end)
		print("Görünmezlik modu açıldı.")
	end

	local function isR15(plr)
		if plr and plr.Character and plr.Character:FindFirstChildOfClass('Humanoid') then return plr.Character:FindFirstChildOfClass('Humanoid').RigType == Enum.HumanoidRigType.R15 end
		return false
	end

	local function stopBang()
		if currentBangLoop then currentBangLoop:Disconnect(); currentBangLoop = nil end
		if currentBangAnimationTrack then currentBangAnimationTrack:Stop(); currentBangAnimationTrack:Destroy(); currentBangAnimationTrack = nil end
		if currentBangAnimation then currentBangAnimation:Destroy(); currentBangAnimation = nil end
		if currentBangDiedConnection then currentBangDiedConnection:Disconnect(); currentBangDiedConnection = nil end
		print("Bang işlemi durduruldu.")
	end

	local function startBang(targetPlayerName, bangSpeed)
		stopBang()
		task.wait(0.1)
		local localPlayer = Players.LocalPlayer
		local targetPlayer = Players:FindFirstChild(targetPlayerName)
		if not localPlayer or not localPlayer.Character or not getRoot(localPlayer.Character) then print("Hata: Kendi karakteriniz bulunamadı."); featureStates.Bang = false; return end
		if not targetPlayer or not targetPlayer.Character or not getRoot(targetPlayer.Character) then print("Hata: Hedef kullanıcı bulunamadı: " .. targetPlayerName); featureStates.Bang = false; return end
		print("Bang işlemi başlatılıyor: " .. targetPlayerName)
		local myCharacter = localPlayer.Character
		local myHumanoid = myCharacter:FindFirstChildOfClass('Humanoid')
		local myRootPart = getRoot(myCharacter)
		if not myHumanoid or not myRootPart then print("Gerekli parçalar bulunamadı."); featureStates.Bang = false; return end
		currentBangAnimation = Instance.new("Animation")
		currentBangAnimation.AnimationId = (not isR15(localPlayer) and "rbxassetid://148840371") or "rbxassetid://5918726674"
		local successAnim, loadedAnimation = pcall(function() return myHumanoid:LoadAnimation(currentBangAnimation) end)
		if successAnim and loadedAnimation then
			currentBangAnimationTrack = loadedAnimation
			currentBangAnimationTrack:Play(0.1, 1, 1)
			currentBangAnimationTrack:AdjustSpeed(bangSpeed or 3)
			currentBangDiedConnection = myHumanoid.Died:Connect(function()
				print("Kendi karakteriniz öldü, bang durduruluyor.")
				stopBang()
				local bangButton = mainFrame:FindFirstChild("contentFrame"):FindFirstChild("BangButton")
				if bangButton then featureStates.Bang = false; updateFeatureButtonVisual(bangButton, false); bangButton.Text = "Bang (" .. (selectedPlayerName or "Hedef Yok") .. ")" end
			end)
		else
			warn("UYARI: Animasyon yüklenemedi! " .. tostring(loadedAnimation))
		end
		local bangOffset = CFrame.new(0, 0, 1.1)
		currentBangLoop = RunService.Stepped:Connect(function()
			pcall(function()
				if targetPlayer and targetPlayer.Character and getRoot(targetPlayer.Character) then
					myRootPart.CFrame = getRoot(targetPlayer.Character).CFrame * bangOffset
				else
					print("Hedef oyuncu kayboldu, bang durduruluyor.")
					stopBang(); featureStates.Bang = false
					local bangButton = mainFrame:FindFirstChild("contentFrame"):FindFirstChild("BangButton")
					if bangButton then updateFeatureButtonVisual(bangButton, false); bangButton.Text = "Bang (Hedef Yok)"; bangButton.BackgroundTransparency = 0.5; bangButton.Active = false end
				end
			end)
		end)
		print("Bang döngüsü başladı.")
	end

	local function stopSpin()
		if spinInstance then pcall(function() spinInstance:Destroy() end); spinInstance = nil end
		print("Spin modu kapatıldı.")
	end

	local function startSpin()
		stopSpin()
		local char = player.Character
		local root = getRoot(char)
		if not root then warn("Spin başlatılamadı: Karakterin root part'ı bulunamadı."); featureStates.Spin = false; return end
		spinInstance = Instance.new("BodyAngularVelocity")
		spinInstance.Name = "TeasHUB_SpinInstance"
		spinInstance.MaxTorque = Vector3.new(0, math.huge, 0)
		spinInstance.AngularVelocity = Vector3.new(0, spinValue, 0)
		spinInstance.Parent = root
		print("Spin modu açıldı. Hız: " .. spinValue)
	end

	if playerGui:FindFirstChild("TeasHUB") then playerGui.TeasHUB:Destroy() end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TeasHUB"; gui.ResetOnSpawn = false; gui.Parent = playerGui

	local function applyUICorner(frame, radius) local corner = Instance.new("UICorner", frame); corner.CornerRadius = UDim.new(0, radius or 8) end

	local mainFrame = Instance.new("Frame", gui)
	mainFrame.Size = UDim2.new(0, 800, 0, 460); mainFrame.Position = UDim2.new(0.5, -400, 0.5, -230); mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30); mainFrame.BorderSizePixel = 0; applyUICorner(mainFrame, 16); mainFrame.Active = true; mainFrame.Draggable = true; mainFrame.ClipsDescendants = true

	local sidePanel = Instance.new("Frame", mainFrame)
	sidePanel.Size = UDim2.new(0, 180, 1, 0); sidePanel.Position = UDim2.new(0, 0, 0, 0); sidePanel.BackgroundColor3 = Color3.fromRGB(22, 22, 22); sidePanel.BorderSizePixel = 0; applyUICorner(sidePanel, 16)

	local profileFrame = Instance.new("Frame", sidePanel)
	profileFrame.Size = UDim2.new(0, 120, 0, 120); profileFrame.Position = UDim2.new(0.5, -60, 0, 20); profileFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45); applyUICorner(profileFrame, 60)

	local profileImage = Instance.new("ImageLabel", profileFrame)
	profileImage.Size = UDim2.new(1, 0, 1, 0); profileImage.Position = UDim2.new(0, 0, 0, 0); profileImage.BackgroundTransparency = 1
	local pcallSuccess, pcallThumbnail = pcall(function() return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420) end)
	if pcallSuccess and pcallThumbnail and pcallThumbnail ~= "" then profileImage.Image = pcallThumbnail else warn("Profil resmi alınamadı."); profileImage.Image = "rbxassetid://214620021" end
	applyUICorner(profileImage, 60)

	local usernameLabel = Instance.new("TextLabel", sidePanel)
	usernameLabel.Size = UDim2.new(1, -20, 0, 30); usernameLabel.Position = UDim2.new(0, 10, 0, 150); usernameLabel.BackgroundTransparency = 1; usernameLabel.TextColor3 = Color3.fromRGB(255, 255, 255); usernameLabel.Font = Enum.Font.GothamBold; usernameLabel.TextSize = 22; usernameLabel.Text = player.Name; usernameLabel.TextXAlignment = Enum.TextXAlignment.Center

	local categoryFrame = Instance.new("Frame", sidePanel)
	categoryFrame.Size = UDim2.new(1, -20, 0, 210); categoryFrame.Position = UDim2.new(0, 10, 0, 190); categoryFrame.BackgroundTransparency = 1

	local contentFrame = Instance.new("Frame", mainFrame)
	contentFrame.Size = UDim2.new(1, -180, 1, 0); contentFrame.Position = UDim2.new(0, 180, 0, 0); contentFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35); contentFrame.BorderSizePixel = 0; applyUICorner(contentFrame, 16)

	-- *** KATEGORİ DEĞİŞİKLİĞİ *** --
	local categories = {
		{Name = "Main", Items = {"Fly", "Speed", "Jump Boost", "NoClip", "Invisible", "Jetpack"}},
		{Name = "Misc", Items = {"Lightning", "ESP", "Spin"}},
		{Name = "Troll", Items = {"Bang", "Teleport", "Fling"}},
		{Name = "Settings", Items = {"Theme Switcher"}}
	}

	local currentCategory = nil
	local actionButtons = {}

	local playerListFrame = Instance.new("Frame", contentFrame)
	playerListFrame.Size = UDim2.new(0, 250, 1, -40); playerListFrame.Position = UDim2.new(0, 20 + 220 + 50, 0, 20); playerListFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40); playerListFrame.BorderSizePixel = 0; applyUICorner(playerListFrame, 10); playerListFrame.Visible = false

	local playerListTitle = Instance.new("TextLabel", playerListFrame)
	playerListTitle.Size = UDim2.new(1, 0, 0, 30); playerListTitle.Position = UDim2.new(0, 0, 0, 0); playerListTitle.BackgroundColor3 = Color3.fromRGB(30, 30, 30); playerListTitle.TextColor3 = Color3.fromRGB(255, 255, 255); playerListTitle.Font = Enum.Font.GothamBold; playerListTitle.TextSize = 18; playerListTitle.Text = "Sunucudaki Oyuncular"; playerListTitle.TextXAlignment = Enum.TextXAlignment.Center; applyUICorner(playerListTitle, 8)

	local playerListScrollingFrame = Instance.new("ScrollingFrame", playerListFrame)
	playerListScrollingFrame.Size = UDim2.new(1, -10, 1, -40); playerListScrollingFrame.Position = UDim2.new(0, 5, 0, 35); playerListScrollingFrame.BackgroundTransparency = 1; playerListScrollingFrame.BorderSizePixel = 0; playerListScrollingFrame.CanvasSize = UDim2.new(0,0,0,0); playerListScrollingFrame.VerticalScrollBarInset = Enum.ScrollBarInset.Always; playerListScrollingFrame.ScrollBarImageColor3 = Color3.fromRGB(80, 130, 80); playerListScrollingFrame.ClipsDescendants = true

	local function updatePlayerList()
		for _, child in pairs(playerListScrollingFrame:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		local yOffset = 0
		local playersInGame = Players:GetPlayers()
		table.sort(playersInGame, function(p1, p2) return p1.Name:lower() < p2.Name:lower() end)
		for _, p in ipairs(playersInGame) do
			if p.Name ~= player.Name then
				local playerButton = Instance.new("TextButton", playerListScrollingFrame)
				playerButton.Size = UDim2.new(1, 0, 0, 30); playerButton.Position = UDim2.new(0, 0, 0, yOffset); playerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60); playerButton.TextColor3 = Color3.fromRGB(255, 255, 255); playerButton.Font = Enum.Font.GothamBold; playerButton.TextSize = 16; playerButton.Text = p.Name; applyUICorner(playerButton, 6); playerButton.BorderSizePixel = 0
				if selectedPlayerName == p.Name then playerButton.BackgroundColor3 = Color3.fromRGB(80, 130, 80); selectedPlayerButton = playerButton end
				playerButton.MouseEnter:Connect(function() TweenService:Create(playerButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(90, 90, 90)}):Play() end)
				playerButton.MouseLeave:Connect(function() if selectedPlayerButton ~= playerButton then TweenService:Create(playerButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(60, 60, 60)}):Play() end end)
				playerButton.MouseButton1Click:Connect(function()
					if selectedPlayerButton and selectedPlayerButton ~= playerButton then selectedPlayerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60) end
					selectedPlayerButton = playerButton; selectedPlayerName = p.Name; selectedPlayerButton.BackgroundColor3 = Color3.fromRGB(80, 130, 80)
					print("Seçilen oyuncu: " .. selectedPlayerName)
					
					-- *** OYUNCU SEÇİLDİĞİNDE TROLL BUTONLARINI GÜNCELLE *** --
					if currentCategory == "Troll" then
						local bangButton = contentFrame:FindFirstChild("BangButton")
						if bangButton then
							bangButton.Text = "Bang (" .. selectedPlayerName .. ")"
							bangButton.Active = true
							bangButton.BackgroundTransparency = 0
							if featureStates.Bang then startBang(selectedPlayerName, 3) end
						end
						
						local teleportButton = contentFrame:FindFirstChild("TeleportButton")
						if teleportButton then
							teleportButton.Text = "Teleport (" .. selectedPlayerName .. ")"
							teleportButton.Active = true
							teleportButton.BackgroundTransparency = 0
						end
					end
				end)
				yOffset = yOffset + 35
			end
		end
		playerListScrollingFrame.CanvasSize = UDim2.new(0, 0, 0, yOffset)
	end

	Players.PlayerAdded:Connect(updatePlayerList)
	Players.PlayerRemoving:Connect(updatePlayerList)

	local function clearContent()
		for _, btn in pairs(actionButtons) do btn:Destroy() end
		actionButtons = {}
		if playerListFrame then
			playerListFrame.Visible = false
			selectedPlayerName = nil
			if selectedPlayerButton then selectedPlayerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60); selectedPlayerButton = nil end
		end
		featureStates.Bang = false; stopBang()
		featureStates.Lightning = false; stopLightning()
		featureStates.ESP = false; stopEsp()
		featureStates.Spin = false; stopSpin()
	end

	local function createSliderUI(parent, initialValue, resetValue, minVal, maxVal)
		local min, max = minVal or 0, maxVal or 100
		local range = max - min
		local controlFrame = Instance.new("Frame", parent)
		controlFrame.Size = UDim2.new(0, 200, 0, 65); controlFrame.BackgroundTransparency = 1
		local valueBox = Instance.new("TextBox", controlFrame)
		valueBox.Size = UDim2.new(0, 40, 0, 30); valueBox.Position = UDim2.new(1, -15, 0, 0); valueBox.BackgroundColor3 = Color3.fromRGB(50, 50, 50); valueBox.TextColor3 = Color3.fromRGB(230, 230, 230); valueBox.Font = Enum.Font.GothamBold; valueBox.TextSize = 20; valueBox.Text = tostring(initialValue); valueBox.ClearTextOnFocus = false; valueBox.TextXAlignment = Enum.TextXAlignment.Center; applyUICorner(valueBox, 15)
		local sliderFrame = Instance.new("Frame", controlFrame)
		sliderFrame.Size = UDim2.new(0, 110, 0, 20); sliderFrame.Position = UDim2.new(0, 30, 0, 10); sliderFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 70); applyUICorner(sliderFrame, 10)
		local sliderFill = Instance.new("Frame", sliderFrame)
		if range > 0 then local scale = (initialValue - min) / range; sliderFill.Size = UDim2.new(math.clamp(scale, 0, 1), 0, 1, 0) end
		sliderFill.BackgroundColor3 = Color3.fromRGB(80, 130, 80); applyUICorner(sliderFill, 10)
		local dragging = false
		sliderFrame.InputBegan:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; mainFrame.Draggable = false end end)
		sliderFrame.InputEnded:Connect(function(input) if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false; mainFrame.Draggable = true end end)
		local function updateSliderFromValue(value)
			local numValue = tonumber(value)
			if numValue and range > 0 then local scale = (numValue - min) / range; sliderFill.Size = UDim2.new(math.clamp(scale, 0, 1), 0, 1, 0) end
		end
		sliderFrame.InputChanged:Connect(function(input)
			if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
				local relativePos = math.clamp(input.Position.X - sliderFrame.AbsolutePosition.X, 0, sliderFrame.AbsoluteSize.X)
				local currentScale = relativePos / sliderFrame.AbsoluteSize.X
				sliderFill.Size = UDim2.new(currentScale, 0, 1, 0)
				local val = min + (currentScale * range)
				valueBox.Text = tostring(math.floor(val))
			end
		end)
		local minusBtn = Instance.new("TextButton", controlFrame); minusBtn.Size = UDim2.new(0, 25, 0, 25); minusBtn.Position = UDim2.new(0, 0, 0, 7); minusBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); minusBtn.TextColor3 = Color3.fromRGB(230, 230, 230); minusBtn.Text = "-"; minusBtn.Font = Enum.Font.GothamBold; minusBtn.TextSize = 24; applyUICorner(minusBtn, 6); minusBtn.BorderSizePixel = 0
		local plusBtn = Instance.new("TextButton", controlFrame); plusBtn.Size = UDim2.new(0, 25, 0, 25); plusBtn.Position = UDim2.new(0, 145, 0, 7); plusBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); plusBtn.TextColor3 = Color3.fromRGB(230, 230, 230); plusBtn.Text = "+"; plusBtn.Font = Enum.Font.GothamBold; plusBtn.TextSize = 24; applyUICorner(plusBtn, 6); plusBtn.BorderSizePixel = 0
		local resetBtn = Instance.new("TextButton", controlFrame); resetBtn.Size = UDim2.new(0, 80, 0, 25); resetBtn.Position = UDim2.new(0, 235, 0, 2); resetBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 70); resetBtn.TextColor3 = Color3.fromRGB(230, 230, 230); resetBtn.Text = "Sıfırla"; resetBtn.Font = Enum.Font.GothamBold; resetBtn.TextSize = 16; applyUICorner(resetBtn, 6); resetBtn.BorderSizePixel = 0
		minusBtn.MouseButton1Click:Connect(function() local curVal = tonumber(valueBox.Text) or initialValue; curVal = math.clamp(curVal - 5, min, max); valueBox.Text = tostring(curVal); updateSliderFromValue(curVal) end)
		plusBtn.MouseButton1Click:Connect(function() local curVal = tonumber(valueBox.Text) or initialValue; curVal = math.clamp(curVal + 5, min, max); valueBox.Text = tostring(curVal); updateSliderFromValue(curVal) end)
		resetBtn.MouseButton1Click:Connect(function() valueBox.Text = tostring(resetValue); updateSliderFromValue(resetValue) end)
		valueBox.FocusLost:Connect(function() local num = tonumber(valueBox.Text) or initialValue; num = math.clamp(math.floor(num), min, max); valueBox.Text = tostring(num); updateSliderFromValue(num) end)
		return controlFrame, valueBox
	end

	local function updateFeatureButtonVisual(btn, enabled)
		if enabled then btn.BackgroundColor3 = Color3.fromRGB(80, 130, 80) else btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50) end
	end

	local function showCategory(catName)
		clearContent()
		currentCategory = catName
		local list
		for _, cat in ipairs(categories) do
			if cat.Name == catName then list = cat.Items; break end
		end
		if not list then return end

		if catName == "Troll" then playerListFrame.Visible = true; updatePlayerList()
		else playerListFrame.Visible = false; selectedPlayerName = nil; if selectedPlayerButton then selectedPlayerButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60); selectedPlayerButton = nil end; featureStates.Bang = false; stopBang()
		end

		for i, actionName in ipairs(list) do
			if catName == "Main" then
				local btn = Instance.new("TextButton", contentFrame); btn.Size = UDim2.new(0, 220, 0, 40); btn.Position = UDim2.new(0, 20, 0, 20 + (i - 1) * 70); btn.Text = actionName; btn.TextColor3 = Color3.fromRGB(230, 230, 230); btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; applyUICorner(btn, 16); btn.BorderSizePixel = 0
				updateFeatureButtonVisual(btn, featureStates[actionName])
				btn.MouseEnter:Connect(function() if not featureStates[actionName] then TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 130, 80)}):Play() end end)
				btn.MouseLeave:Connect(function() if not featureStates[actionName] then TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play() end end)
				btn.MouseButton1Click:Connect(function()
					featureStates[actionName] = not featureStates[actionName]
					local state = featureStates[actionName]
					if actionName == "Fly" then if state then startFly() else stopFly() end
					elseif actionName == "Speed" then if state then if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.WalkSpeed = speedValue end else if player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.WalkSpeed = 16 end end
					elseif actionName == "Jump Boost" then if state then applyJumpBoost(player.Character, jumpBoost) else resetJumpBoost(player.Character) end
					elseif actionName == "Jetpack" then if state then startJetpack() else stopJetpack() end
					elseif actionName == "NoClip" then if state then startNoclip() else stopNoclip() end
					elseif actionName == "Invisible" then if state then startInvisible() else stopInvisible() end
					end
					updateFeatureButtonVisual(btn, state)
					print(actionName .. (state and " açıldı" or " kapandı"))
				end)
				table.insert(actionButtons, btn)
				local sliderYPos = 20 + (i - 1) * 70
				if actionName == "Fly" then
					local cf, vb = createSliderUI(contentFrame, flySpeed, 50, 1, 500); cf.Position = UDim2.new(0, 250, 0, sliderYPos); table.insert(actionButtons, cf); vb.Changed:Connect(function() local val = tonumber(vb.Text) if val then flySpeed = val; if featureStates.Fly and flyBodyVelocity then flyBodyVelocity.Velocity = flyBodyVelocity.Velocity.Unit * flySpeed end end end)
				elseif actionName == "Speed" then
					local cf, vb = createSliderUI(contentFrame, speedValue, 16, 0, 200); cf.Position = UDim2.new(0, 250, 0, sliderYPos); table.insert(actionButtons, cf); vb.Changed:Connect(function() local val = tonumber(vb.Text) if val then speedValue = val; if featureStates.Speed and player.Character and player.Character:FindFirstChildOfClass("Humanoid") then player.Character.Humanoid.WalkSpeed = speedValue end end end)
				elseif actionName == "Jump Boost" then
					local cf, vb = createSliderUI(contentFrame, jumpBoost, 50, 0, 300); cf.Position = UDim2.new(0, 250, 0, sliderYPos); table.insert(actionButtons, cf); vb.Changed:Connect(function() local val = tonumber(vb.Text) if val then jumpBoost = val; if featureStates["Jump Boost"] then applyJumpBoost(player.Character, jumpBoost) end end end)
				end
			elseif catName == "Misc" then
				local btn = Instance.new("TextButton", contentFrame); btn.Size = UDim2.new(0, 220, 0, 40); btn.Position = UDim2.new(0, 20, 0, 20 + (i - 1) * 70); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); btn.TextColor3 = Color3.fromRGB(230, 230, 230); btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.Text = actionName; applyUICorner(btn, 16); btn.BorderSizePixel = 0
				table.insert(actionButtons, btn)
				if actionName == "Lightning" then
					updateFeatureButtonVisual(btn, featureStates.Lightning)
					local modeFrame = Instance.new("Frame", contentFrame); modeFrame.Size = UDim2.new(0, 200, 0, 40); modeFrame.Position = UDim2.new(0, 250, 0, 20 + (i - 1) * 70); modeFrame.BackgroundTransparency = 1; table.insert(actionButtons, modeFrame)
					local darkBtn = Instance.new("TextButton", modeFrame); darkBtn.Size = UDim2.new(0, 95, 1, 0); darkBtn.Position = UDim2.new(0, 0, 0, 0); darkBtn.BackgroundColor3 = lightningMode == 1 and Color3.fromRGB(80, 130, 80) or Color3.fromRGB(50, 50, 50); darkBtn.TextColor3 = Color3.fromRGB(230, 230, 230); darkBtn.Font = Enum.Font.GothamBold; darkBtn.Text = "Karanlık"; darkBtn.TextSize = 18; applyUICorner(darkBtn, 10)
					local fullBtn = Instance.new("TextButton", modeFrame); fullBtn.Size = UDim2.new(0, 95, 1, 0); fullBtn.Position = UDim2.new(0, 105, 0, 0); fullBtn.BackgroundColor3 = lightningMode == 3 and Color3.fromRGB(80, 130, 80) or Color3.fromRGB(50, 50, 50); fullBtn.TextColor3 = Color3.fromRGB(230, 230, 230); fullBtn.Font = Enum.Font.GothamBold; fullBtn.Text = "Fullbright"; fullBtn.TextSize = 18; applyUICorner(fullBtn, 10)
					darkBtn.MouseButton1Click:Connect(function() lightningMode = 1; darkBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80); fullBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); if featureStates.Lightning then startLightning() end end)
					fullBtn.MouseButton1Click:Connect(function() lightningMode = 3; fullBtn.BackgroundColor3 = Color3.fromRGB(80, 130, 80); darkBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); if featureStates.Lightning then startLightning() end end)
					btn.MouseButton1Click:Connect(function() featureStates.Lightning = not featureStates.Lightning; updateFeatureButtonVisual(btn, featureStates.Lightning); if featureStates.Lightning then startLightning() else stopLightning() end end)
				elseif actionName == "ESP" then
					updateFeatureButtonVisual(btn, featureStates.ESP)
					btn.MouseButton1Click:Connect(function() featureStates.ESP = not featureStates.ESP; if featureStates.ESP then startEsp() else stopEsp() end; updateFeatureButtonVisual(btn, featureStates.ESP) end)
				-- *** SPIN BURAYA TAŞINDI VE DÜZELTİLDİ ***
				elseif actionName == "Spin" then
					updateFeatureButtonVisual(btn, featureStates.Spin)
					local sliderYPos = 20 + (i - 1) * 70
					-- Slider artık 0'dan başlıyor
					local cf, vb = createSliderUI(contentFrame, spinValue, 25, 0, 150)
					cf.Position = UDim2.new(0, 250, 0, sliderYPos)
					table.insert(actionButtons, cf)
					vb.Changed:Connect(function()
						local val = tonumber(vb.Text)
						if val then spinValue = val; if featureStates.Spin and spinInstance then spinInstance.AngularVelocity = Vector3.new(0, spinValue, 0) end end
					end)
					btn.MouseButton1Click:Connect(function()
						featureStates.Spin = not featureStates.Spin
						updateFeatureButtonVisual(btn, featureStates.Spin)
						if featureStates.Spin then startSpin() else stopSpin() end
					end)
				end
			elseif catName == "Troll" then
				local btn = Instance.new("TextButton", contentFrame); btn.Size = UDim2.new(0, 220, 0, 40); btn.Position = UDim2.new(0, 20, 0, 20 + (i - 1) * 70); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); btn.TextColor3 = Color3.fromRGB(230, 230, 230); btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.Text = actionName; applyUICorner(btn, 16); btn.BorderSizePixel = 0
				if actionName == "Bang" then
					btn.Name = "BangButton"; updateFeatureButtonVisual(btn, featureStates.Bang)
					if not selectedPlayerName then btn.BackgroundTransparency = 0.5; btn.Active = false; btn.Text = "Bang (Hedef Yok)" else btn.Text = "Bang (" .. selectedPlayerName .. ")"; btn.BackgroundTransparency = 0; btn.Active = true end
				-- *** TELEPORT BURAYA TAŞINDI ***
				elseif actionName == "Teleport" then
					btn.Name = "TeleportButton"
					if not selectedPlayerName then btn.BackgroundTransparency = 0.5; btn.Active = false; btn.Text = "Teleport (Hedef Yok)" else btn.Text = "Teleport (" .. selectedPlayerName .. ")"; btn.BackgroundTransparency = 0; btn.Active = true end
				end
				btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 130, 80)}):Play() end)
				btn.MouseLeave:Connect(function()
					local targetColor = Color3.fromRGB(50, 50, 50)
					if actionName == "Bang" and featureStates.Bang and selectedPlayerName then targetColor = Color3.fromRGB(80, 130, 80) end
					TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = targetColor}):Play()
				end)
				if actionName == "Bang" then
					btn.MouseButton1Click:Connect(function()
						if selectedPlayerName then
							featureStates.Bang = not featureStates.Bang; updateFeatureButtonVisual(btn, featureStates.Bang)
							if featureStates.Bang then print("Bang aktif! Hedef: " .. selectedPlayerName); local targetPlayer = Players:FindFirstChild(selectedPlayerName); if targetPlayer and targetPlayer.Character and getRoot(targetPlayer.Character) then startBang(selectedPlayerName, 3) else warn("Bang hedefi bulunamadı"); featureStates.Bang = false; updateFeatureButtonVisual(btn, false); stopBang() end
							else print("Bang kapatıldı."); stopBang() end
						else warn("Bang için hedef oyuncu seçilmedi!"); featureStates.Bang = false; updateFeatureButtonVisual(btn, false) end
					end)
				-- *** TELEPORT TIKLAMA OLAYI ***
				elseif actionName == "Teleport" then
					btn.MouseButton1Click:Connect(function()
						if not selectedPlayerName then warn("Teleport için hedef oyuncu seçilmedi!"); return end
						local yerelOyuncu = Players.LocalPlayer
						local hedefOyuncu = Players:FindFirstChild(selectedPlayerName)
						if not hedefOyuncu then print("Hata: Hedef oyuncu '" .. selectedPlayerName .. "' sunucuda bulunamadı."); return end
						if not yerelOyuncu.Character or not getRoot(yerelOyuncu.Character) then print("Hata: Senin karakterin yüklenmemiş."); return end
						if not hedefOyuncu.Character or not getRoot(hedefOyuncu.Character) then print("Hata: Hedef oyuncunun karakteri yüklenmemiş."); return end
						print("'" .. selectedPlayerName .. "' adlı oyuncunun yanına ışınlanılıyor...")
						local benimRootPartim = getRoot(yerelOyuncu.Character)
						local hedefRootPart = getRoot(hedefOyuncu.Character)
						benimRootPartim.CFrame = hedefRootPart.CFrame * CFrame.new(3, 1, 0)
					end)
				end
				table.insert(actionButtons, btn)
			elseif catName == "Settings" then
				if actionName == "Theme Switcher" then
					local themeBtn = Instance.new("TextButton", contentFrame); themeBtn.Size = UDim2.new(0, 220, 0, 40); themeBtn.Position = UDim2.new(0, 20, 0, 20 + (i - 1) * 70); themeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); themeBtn.TextColor3 = Color3.fromRGB(230, 230, 230); themeBtn.Font = Enum.Font.GothamBold; themeBtn.TextSize = 20; themeBtn.Text = "Koyu / Açık Tema"; applyUICorner(themeBtn, 16); themeBtn.BorderSizePixel = 0
					themeBtn.MouseEnter:Connect(function() TweenService:Create(themeBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 130, 80)}):Play() end)
					themeBtn.MouseLeave:Connect(function() TweenService:Create(themeBtn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play() end)
					themeBtn.MouseButton1Click:Connect(function() print("Tema değiştirici tıklandı") end)
					table.insert(actionButtons, themeBtn)
				end
			end
		end
	end

	local catButtons = {}
	local function createCategoryButtons()
		local yOffset = 0
		for _, cat in ipairs(categories) do
			local catName = cat.Name
			local btn = Instance.new("TextButton", categoryFrame); btn.Size = UDim2.new(1, 0, 0, 40); btn.Position = UDim2.new(0, 0, 0, yOffset); btn.BackgroundColor3 = Color3.fromRGB(50, 50, 50); btn.TextColor3 = Color3.fromRGB(230, 230, 230); btn.Font = Enum.Font.GothamBold; btn.TextSize = 20; btn.Text = catName; applyUICorner(btn, 10); btn.BorderSizePixel = 0
			btn.MouseEnter:Connect(function() TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(80, 130, 80)}):Play() end)
			btn.MouseLeave:Connect(function() if currentCategory ~= catName then TweenService:Create(btn, TweenInfo.new(0.3), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play() end end)
			btn.MouseButton1Click:Connect(function() for _, b in pairs(catButtons) do b.BackgroundColor3 = Color3.fromRGB(50, 50, 50) end; btn.BackgroundColor3 = Color3.fromRGB(80, 130, 80); showCategory(catName) end)
			table.insert(catButtons, btn); yOffset = yOffset + 45
		end
	end

	createCategoryButtons()
	catButtons[1].BackgroundColor3 = Color3.fromRGB(80, 130, 80)
	showCategory("Main")

	local closeButton = Instance.new("TextButton", mainFrame); closeButton.Size = UDim2.new(0, 30, 0, 30); closeButton.Position = UDim2.new(1, -40, 0, 15); closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50); closeButton.TextColor3 = Color3.fromRGB(255, 255, 255); closeButton.Font = Enum.Font.GothamBold; closeButton.TextSize = 20; closeButton.Text = "X"; applyUICorner(closeButton, 6); closeButton.BorderSizePixel = 0
	closeButton.MouseEnter:Connect(function() TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(255, 0, 0)}):Play() end)
	closeButton.MouseLeave:Connect(function() TweenService:Create(closeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(200, 50, 50)}):Play() end)
	closeButton.MouseButton1Click:Connect(function() gui:Destroy(); print("GUI kapatıldı (Destroy)"); stopBang(); stopFly(); stopJetpack(); stopNoclip(); stopInvisible(); stopLightning(); stopEsp(); stopSpin() end)

	local minimizeButton = Instance.new("TextButton", mainFrame); minimizeButton.Size = UDim2.new(0, 30, 0, 30); minimizeButton.Position = UDim2.new(1, -40, 0, 50); minimizeButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50); minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255); minimizeButton.Font = Enum.Font.GothamBold; minimizeButton.TextSize = 20; minimizeButton.Text = "/"; applyUICorner(minimizeButton, 6); minimizeButton.BorderSizePixel = 0
	minimizeButton.MouseEnter:Connect(function() TweenService:Create(minimizeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(80, 80, 80)}):Play() end)
	minimizeButton.MouseLeave:Connect(function() TweenService:Create(minimizeButton, TweenInfo.new(0.2), {BackgroundColor3 = Color3.fromRGB(50, 50, 50)}):Play() end)

	local minimizedIndicator = Instance.new("TextButton", gui); minimizedIndicator.Size = UDim2.new(0, 100, 0, 40); minimizedIndicator.Position = UDim2.new(0, 10, 1, -50); minimizedIndicator.BackgroundColor3 = Color3.fromRGB(30, 30, 30); minimizedIndicator.BorderSizePixel = 0; minimizedIndicator.Visible = false; applyUICorner(minimizedIndicator, 8); minimizedIndicator.TextColor3 = Color3.fromRGB(255, 255, 255); minimizedIndicator.Font = Enum.Font.GothamBold; minimizedIndicator.TextSize = 20; minimizedIndicator.Text = "TeasHUB"; minimizedIndicator.TextXAlignment = Enum.TextXAlignment.Center; minimizedIndicator.TextYAlignment = Enum.TextYAlignment.Center
	minimizedIndicator.MouseButton1Click:Connect(function() mainFrame.Visible = true; minimizedIndicator.Visible = false; print("GUI tekrar gösterildi.") end)
	minimizeButton.MouseButton1Click:Connect(function() if mainFrame.Visible then mainFrame.Visible = false; minimizedIndicator.Visible = true; print("GUI gizlendi.") end end)
	UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
		if input.KeyCode == Enum.KeyCode.RightControl and not gameProcessedEvent then
			if mainFrame.Visible then mainFrame.Visible = false; minimizedIndicator.Visible = true; print("GUI gizlendi (Kısayol).") else mainFrame.Visible = true; minimizedIndicator.Visible = false; print("GUI gösterildi (Kısayol).") end
		end
	end)
end)

if not success then
	warn("TeasHUB GUI başlatılamadı! Hata: " .. errorMessage)
	if Players.LocalPlayer and Players.LocalPlayer.PlayerGui then
		local errorGui = Instance.new("ScreenGui"); errorGui.Name = "TeasHUB_Error"; errorGui.Parent = Players.LocalPlayer.PlayerGui
		local errorLabel = Instance.new("TextLabel"); errorLabel.Size = UDim2.new(0, 300, 0, 100); errorLabel.Position = UDim2.new(0.5, -150, 0.5, -50); errorLabel.BackgroundColor3 = Color3.fromRGB(255, 50, 50); errorLabel.TextColor3 = Color3.fromRGB(255, 255, 255); errorLabel.TextSize = 18; errorLabel.Font = Enum.Font.GothamBold; errorLabel.Text = "TeasHUB Yükleme Hatası!\n" .. errorMessage .. "\nExecutor Output'unu Kontrol Edin."; errorLabel.TextWrapped = true; errorLabel.TextXAlignment = Enum.TextXAlignment.Center; errorLabel.TextYAlignment = Enum.TextYAlignment.Center; errorLabel.Parent = errorGui
		local corner = Instance.new("UICorner", errorLabel); corner.CornerRadius = UDim.new(0, 8)
		task.wait(8)
		errorGui:Destroy()
	end
end
