--[[
              /=============================\
              | SIMPLE FLING GUI x MM2 EDIT |
              \=============================/
v4.9 - Optimized, Player ESP, Dev Picker, Hover Fling & Gun Utilities
--]]  

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local Library = loadstring(game:HttpGet("https://raw.githubusercontent.com/geragori11/XClientMenuV2/main/source.lua"))()
loadstring(game:HttpGet("https://raw.githubusercontent.com/geragori11/checkerXClient/main/check.lua"))()
-- ==========================================
-- ЗАГРУЗЧИК ВНЕШНИХ МОДУЛЕЙ
-- ==========================================
local function LoadExternalModule(url, mainWindow)
    local success, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    
    if success then
        if type(result) == "function" then
            -- Передаем главное окно меню внутрь модуля, чтобы он мог создать там свои вкладки
            result(mainWindow) 
        end
        print("[XClientMenu] Модуль успешно загружен: " .. url)
    else
        warn("[XClientMenu] Ошибка загрузки модуля " .. url .. "\n" .. tostring(result))
    end
end

-- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
local SelectedTargets = {}
local IsFlinging = false 
local AutoProtect = true
local HoverFlingEnabled = false 

-- ПЕРЕМЕННЫЕ ДЛЯ ОРУЖИЯ
local AutoPickupEnabled = false
local AutoPickupAttempts = 1
local AutoPickupRunning = false
local GunESPEnabled = false
local GunESPInstances = {Highlight = nil, Billboard = nil}

-- ПЕРЕМЕННЫЕ ДЛЯ РАЗРАБОТЧИКА
local ObjectPickerEnabled = false
local PlayerPickerEnabled = false

-- ПЕРЕМЕННЫЕ ESP ИГРОКОВ
local PlayerESPEnabled = false
local PlayerESPInstances = {}

getgenv().OldPos = nil 
getgenv().FPDH = workspace.FallenPartsDestroyHeight

local function Notify(Title, Content, Duration, CustomImage)
    Library:Notify({
        Title = Title,
        Content = Content,
        Duration = Duration or 5,
        Image = CustomImage or 4483362458
    })
end

-- ==========================================
-- ЛОГИКА ОБНАРУЖЕНИЯ MM2 РОЛЕЙ
-- ==========================================
local function GetPlayerRole(Player)
    if not Player then return "Unknown" end
    local Character = Player.Character
    local Backpack = Player:FindFirstChild("Backpack")

    if (Character and Character:FindFirstChild("Knife")) or (Backpack and Backpack:FindFirstChild("Knife")) then
        return "Murderer"
    elseif (Character and Character:FindFirstChild("Gun")) or (Backpack and Backpack:FindFirstChild("Gun")) then
        return "Sheriff"
    else
        return "Innocent"
    end
end

local function GetAvatar(UserId)
    return "rbxthumb://type=AvatarHeadShot&id=" .. UserId .. "&w=150&h=150"
end

-- ==========================================
-- КОЛЛИЗИИ
-- ==========================================
local function EnableCollision(Character)
    if not Character then return end 
    for _, Part in pairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") then Part.CanCollide = true end
    end
end

local function DisableCollision(Character)
    if not Character then return end 
    for _, Part in pairs(Character:GetDescendants()) do
        if Part:IsA("BasePart") then Part.CanCollide = false end
    end
end

local function SetProtection(IsEnabled)
    local Character = LocalPlayer.Character
    if not Character then return end 
    if IsEnabled and AutoProtect then
        EnableCollision(Character)
    else 
        DisableCollision(Character)
    end
end

-- ==========================================
-- ЯДРО FLING (ФИЗИКА)
-- ==========================================
local function FlingPlayer(TargetPlayer)
    local Character = LocalPlayer.Character
    local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
    local RootPart = Humanoid and Humanoid.RootPart
    
    local TargetCharacter = TargetPlayer.Character
    if not TargetCharacter then return end 
    
    local TargetHumanoid, TargetRootPart, TargetHead, TargetAccessory, TargetHandle 
    
    if TargetCharacter:FindFirstChildOfClass("Humanoid") then TargetHumanoid = TargetCharacter:FindFirstChildOfClass("Humanoid") end 
    if TargetHumanoid and TargetHumanoid.RootPart then TargetRootPart = TargetHumanoid.RootPart end 
    if TargetCharacter:FindFirstChild("Head") then TargetHead = TargetCharacter.Head end 
    if TargetCharacter:FindFirstChildOfClass("Accessory") then TargetAccessory = TargetCharacter:FindFirstChildOfClass("Accessory") end 
    if TargetAccessory and TargetAccessory:FindFirstChild("Handle") then TargetHandle = TargetAccessory.Handle end

    if Character and Humanoid and RootPart then
        if AutoProtect then SetProtection(true) end 
        if RootPart.Velocity.Magnitude < 50 then getgenv().OldPos = RootPart.CFrame end 
        
        if TargetHumanoid and TargetHumanoid.Sit then
            if AutoProtect then SetProtection(false) end 
            return
        end 
        
        if TargetHead then workspace.CurrentCamera.CameraSubject = TargetHead 
        elseif TargetHandle then workspace.CurrentCamera.CameraSubject = TargetHandle 
        elseif TargetHumanoid and TargetRootPart then workspace.CurrentCamera.CameraSubject = TargetHumanoid end 
        
        if not TargetCharacter:FindFirstChildWhichIsA("BasePart") then
            if AutoProtect then SetProtection(false) end 
            return
        end

        local function PhysicsFling(TargetPart, PosOffset, AngleOffset)
            RootPart.CFrame = CFrame.new(TargetPart.Position) * PosOffset * AngleOffset 
            Character:SetPrimaryPartCFrame(CFrame.new(TargetPart.Position) * PosOffset * AngleOffset)
            RootPart.Velocity = Vector3.new(9e7, 9e7 * 10, 9e7)
            RootPart.RotVelocity = Vector3.new(9e8, 9e8, 9e8)
        end

        local function ApplyFlingForce(TargetPart)
            local Duration = 2 
            local StartTick = tick()
            local Angle = 0 
            
            repeat 
                if RootPart and TargetHumanoid then
                    if AutoProtect then EnableCollision(Character) end 
                    if TargetPart.Velocity.Magnitude < 50 then
                        Angle = Angle + 100 
                        PhysicsFling(TargetPart, CFrame.new(0, 1.5, 0) + TargetHumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, -1.5, 0) + TargetHumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, 1.5, 0) + TargetHumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, -1.5, 0) + TargetHumanoid.MoveDirection * TargetPart.Velocity.Magnitude / 1.25, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, 1.5, 0) + TargetHumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, -1.5, 0) + TargetHumanoid.MoveDirection, CFrame.Angles(math.rad(Angle), 0, 0))
                        task.wait()
                    else 
                        PhysicsFling(TargetPart, CFrame.new(0, 1.5, TargetHumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, -1.5, -TargetHumanoid.WalkSpeed), CFrame.Angles(0, 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, 1.5, TargetHumanoid.WalkSpeed), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                        PhysicsFling(TargetPart, CFrame.new(0, -1.5, 0), CFrame.Angles(math.rad(90), 0, 0))
                        task.wait()
                    end
                end 
            until tick() > StartTick + Duration or not IsFlinging
        end

        workspace.FallenPartsDestroyHeight = 0/0 
        local BodyVel = Instance.new("BodyVelocity")
        BodyVel.Parent = RootPart 
        BodyVel.Velocity = Vector3.zero
        BodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        
        if TargetRootPart then ApplyFlingForce(TargetRootPart)
        elseif TargetHead then ApplyFlingForce(TargetHead)
        elseif TargetHandle then ApplyFlingForce(TargetHandle)
        else 
            BodyVel:Destroy()
            if AutoProtect then SetProtection(false) end 
            return
        end 
        
        BodyVel:Destroy()
        Humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        workspace.CurrentCamera.CameraSubject = Humanoid 
        
        if getgenv().OldPos then
            repeat 
                RootPart.CFrame = getgenv().OldPos * CFrame.new(0, 0.5, 0)
                Character:SetPrimaryPartCFrame(getgenv().OldPos * CFrame.new(0, 0.5, 0))
                Humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
                for _, Part in pairs(Character:GetChildren()) do
                    if Part:IsA("BasePart") then
                        Part.Velocity = Vector3.zero
                        Part.RotVelocity = Vector3.zero
                    end
                end 
                task.wait()
            until (RootPart.Position - getgenv().OldPos.Position).Magnitude < 25 
            workspace.FallenPartsDestroyHeight = getgenv().FPDH
        end 
        if AutoProtect then SetProtection(false) end 
    end
end

-- ==========================================
-- УПРАВЛЕНИЕ ЗАПУСКОМ FLING 
-- ==========================================
local function StopFlinging()
    if not IsFlinging then return end 
    IsFlinging = false 
    if AutoProtect then SetProtection(false) end 
    Notify("Отключено", "Флинг завершен и отключен.", 2)
end

local function StartFlinging()
    if IsFlinging then return end 
    local Count = 0 for _ in pairs(SelectedTargets) do Count = Count + 1 end 
    if Count == 0 then return Notify("Ошибка", "Сначала выбери цель!", 2) end 
    
    IsFlinging = true 
    if AutoProtect then SetProtection(true) end 
    Notify("Запуск", "Флинг активирован на 5 секунд!", 2)
    
    task.spawn(function()
        task.wait(5)
        if IsFlinging then StopFlinging() end
    end)
    
    task.spawn(function()
        while IsFlinging do
            local ValidTargets = {}
            for Name, Player in pairs(SelectedTargets) do
                if Player and Player.Parent then ValidTargets[Name] = Player 
                else SelectedTargets[Name] = nil end
            end 
            
            for _, Player in pairs(ValidTargets) do
                if IsFlinging then
                    FlingPlayer(Player)
                    task.wait(0.1)
                else break end
            end 
            task.wait(0.5)
        end
    end)
end

-- ==========================================
-- ОПТИМИЗИРОВАННАЯ ЛОГИКА ОРУЖИЯ (БЕЗ LAGS)
-- ==========================================
local function GetGunDrop()
    local PossibleNames = {["GunDrop"] = true, ["Gun_Drop"] = true, ["RevolverDrop"] = true, ["Gun"] = true}
    
    local function CheckObject(Object)
        if PossibleNames[Object.Name] then
            local CurrentParent = Object.Parent
            local IsHeldByPlayer = false
            while CurrentParent and CurrentParent ~= workspace and CurrentParent ~= game do
                if CurrentParent:FindFirstChildOfClass("Humanoid") or CurrentParent:IsA("Backpack") then
                    IsHeldByPlayer = true
                    break
                end
                CurrentParent = CurrentParent.Parent
            end
            if not IsHeldByPlayer then return Object end
        end
        return nil
    end

    for _, Object in ipairs(workspace:GetChildren()) do
        local found = CheckObject(Object)
        if found then return found end
    end
    
    for _, Child in ipairs(workspace:GetChildren()) do
        if Child:IsA("Folder") or Child:IsA("Model") then
            if Child.Name ~= "Players" and Child.Name ~= "Camera" then
                for _, Object in ipairs(Child:GetChildren()) do
                    local found = CheckObject(Object)
                    if found then return found end
                end
            end
        end
    end
    
    return nil
end

local function ClearGunESP()
    if GunESPInstances.Highlight then GunESPInstances.Highlight:Destroy() GunESPInstances.Highlight = nil end
    if GunESPInstances.Billboard then GunESPInstances.Billboard:Destroy() GunESPInstances.Billboard = nil end
end

task.spawn(function()
    while task.wait(0.05) do
        if AutoPickupEnabled and not AutoPickupRunning then
            local GunDrop = GetGunDrop()
            if GunDrop then
                local GunPart = GunDrop:IsA("BasePart") and GunDrop or GunDrop:FindFirstChildWhichIsA("BasePart")
                local Character = LocalPlayer.Character
                local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
                
                if GunPart and RootPart then
                    AutoPickupRunning = true
                    local OriginalPos = RootPart.CFrame
                    
                    for Attempt = 1, AutoPickupAttempts do
                        if not GetGunDrop() then break end 
                        if GetPlayerRole(LocalPlayer) == "Sheriff" then break end 
                        
                        Notify("Автоподбор", "Попытка " .. Attempt .. " из " .. AutoPickupAttempts, 1)
                        
                        RootPart.CFrame = GunPart.CFrame
                        task.wait(0.5)
                        
                        RootPart.CFrame = OriginalPos
                        task.wait(0.2)
                        
                        if GetPlayerRole(LocalPlayer) == "Sheriff" then
                            Notify("Успех!", "Оружие шерифа подобрано!", 3)
                            break
                        end
                        
                        if Attempt < AutoPickupAttempts then task.wait(2) end
                    end
                    
                    if GetPlayerRole(LocalPlayer) ~= "Sheriff" then
                        Notify("Ошибка", "Не удалось подобрать пушку. Лимит попыток исчерпан.", 3)
                    end
                    
                    while GetGunDrop() do task.wait(0.5) end
                    AutoPickupRunning = false
                end
            end
        end
    end
end)

task.spawn(function()
    while task.wait(0.3) do
        local GunDrop = GetGunDrop()
        
        if GunESPEnabled and GunDrop then
            local GunPart = GunDrop:IsA("BasePart") and GunDrop or GunDrop:FindFirstChildWhichIsA("BasePart")
            if GunPart then
                if not GunESPInstances.Highlight or GunESPInstances.Highlight.Parent ~= GunPart then
                    ClearGunESP()
                    
                    local Highlight = Instance.new("Highlight")
                    Highlight.FillColor = Color3.fromRGB(255, 255, 0)
                    Highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
                    Highlight.FillTransparency = 0.5
                    Highlight.Parent = GunPart
                    GunESPInstances.Highlight = Highlight
                    
                    local Billboard = Instance.new("BillboardGui")
                    Billboard.Name = "GunDropESP"
                    Billboard.Size = UDim2.new(0, 100, 0, 50)
                    Billboard.StudsOffset = Vector3.new(0, 2, 0)
                    Billboard.AlwaysOnTop = true
                    Billboard.Parent = GunPart
                    
                    local TextLabel = Instance.new("TextLabel")
                    TextLabel.Size = UDim2.new(1, 0, 1, 0)
                    TextLabel.BackgroundTransparency = 1
                    TextLabel.TextScaled = true
                    TextLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
                    TextLabel.TextStrokeTransparency = 0
                    TextLabel.Font = Enum.Font.SourceSansBold
                    TextLabel.Parent = Billboard
                    
                    GunESPInstances.Billboard = Billboard
                end
                
                if GunESPInstances.Billboard and GunESPInstances.Billboard:FindFirstChildOfClass("TextLabel") then
                    local Character = LocalPlayer.Character
                    local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
                    if RootPart then
                        local Distance = math.floor((RootPart.Position - GunPart.Position).Magnitude)
                        GunESPInstances.Billboard.TextLabel.Text = "🔫 GUN\n[" .. Distance .. "m]"
                    end
                end
            end
        else
            ClearGunESP()
        end
    end
end)

-- ==========================================
-- ЛОГИКА PLAYER ESP
-- ==========================================
local function ClearPlayerESP(Player)
    if PlayerESPInstances[Player] then
        if PlayerESPInstances[Player].Highlight then PlayerESPInstances[Player].Highlight:Destroy() end
        if PlayerESPInstances[Player].Billboard then PlayerESPInstances[Player].Billboard:Destroy() end
        PlayerESPInstances[Player] = nil
    end
end

local function ClearAllPlayerESP()
    for Player, _ in pairs(PlayerESPInstances) do
        ClearPlayerESP(Player)
    end
end

Players.PlayerRemoving:Connect(ClearPlayerESP)

task.spawn(function()
    while task.wait(0.1) do
        if PlayerESPEnabled then
            local LocalChar = LocalPlayer.Character
            local LocalHRP = LocalChar and LocalChar:FindFirstChild("HumanoidRootPart")

            for _, TargetPlayer in ipairs(Players:GetPlayers()) do
                if TargetPlayer ~= LocalPlayer then
                    local Char = TargetPlayer.Character
                    local HRP = Char and Char:FindFirstChild("HumanoidRootPart")

                    if Char and HRP and LocalHRP then
                        local Role = GetPlayerRole(TargetPlayer)
                        local EspColor = Color3.fromRGB(0, 255, 0) -- Зеленый (Innocent)
                        
                        if Role == "Murderer" then
                            EspColor = Color3.fromRGB(255, 0, 0) -- Красный
                        elseif Role == "Sheriff" then
                            EspColor = Color3.fromRGB(0, 0, 255) -- Синий
                        end

                        -- Создаем ESP если его нет или персонаж возродился
                        if not PlayerESPInstances[TargetPlayer] or PlayerESPInstances[TargetPlayer].Highlight.Parent ~= Char then
                            ClearPlayerESP(TargetPlayer)

                            local Highlight = Instance.new("Highlight")
                            Highlight.FillTransparency = 0.6
                            Highlight.OutlineTransparency = 0.1
                            Highlight.Parent = Char

                            local Billboard = Instance.new("BillboardGui")
                            Billboard.Name = "PlayerInfoESP"
                            Billboard.Size = UDim2.new(0, 200, 0, 50)
                            Billboard.StudsOffset = Vector3.new(0, 3.5, 0) -- Чуть выше головы
                            Billboard.AlwaysOnTop = true
                            Billboard.Parent = Char

                            local TextLabel = Instance.new("TextLabel")
                            TextLabel.Size = UDim2.new(1, 0, 1, 0)
                            TextLabel.BackgroundTransparency = 1
                            TextLabel.TextSize = 16
                            TextLabel.TextStrokeTransparency = 0
                            TextLabel.Font = Enum.Font.SourceSansBold
                            TextLabel.Parent = Billboard

                            PlayerESPInstances[TargetPlayer] = {Highlight = Highlight, Billboard = Billboard, TextLabel = TextLabel}
                        end

                        -- Обновляем данные в реальном времени
                        local Dist = math.floor((LocalHRP.Position - HRP.Position).Magnitude)
                        local Inst = PlayerESPInstances[TargetPlayer]
                        
                        Inst.Highlight.FillColor = EspColor
                        Inst.Highlight.OutlineColor = EspColor
                        Inst.TextLabel.TextColor3 = EspColor
                        Inst.TextLabel.Text = TargetPlayer.Name .. "\n[" .. Dist .. "m]"
                    else
                        ClearPlayerESP(TargetPlayer)
                    end
                end
            end
        end
    end
end)

-- ==========================================
-- ИНТЕРФЕЙС (GUI)
-- ==========================================
local Window = Library:CreateWindow({
    Name = "Fling GUI x MM2 Edition",
    LoadingTitle = "Loading Live Tracker...",
    LoadingSubtitle = "V4.9 Optimized + ESP",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false
})

-- ==================== Вкладка MM2 Scanner ====================
local MM2Tab = Window:CreateTab("MM2 Scanner", 4483362458)

MM2Tab:CreateSection("Таблица ролей (Live)")
local RoleTable = MM2Tab:CreateParagraph({
    Title = "Текущие роли на карте",
    Content = "Загрузка..."
})

MM2Tab:CreateToggle({
    Name = "👁️ Player ESP (Подсветка игроков)",
    CurrentValue = false,
    Flag = "PlayerESPToggle",
    Callback = function(Value)
        PlayerESPEnabled = Value
        if not Value then ClearAllPlayerESP() end
    end
})

MM2Tab:CreateSection("Поиск и Флинг")
local TargetDropdown = MM2Tab:CreateDropdown({
    Name = "Выбрать игрока",
    Options = {},
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "MM2TargetDropdown",
    Callback = function(Options)
        SelectedTargets = {}
        for _, SelectedString in ipairs(Options) do
            local CleanName = string.match(SelectedString, "%] (.*)$") or SelectedString
            local P = Players:FindFirstChild(CleanName)
            if P then SelectedTargets[CleanName] = P end
        end
    end
})

-- Оптимизированный цикл обновления списка (обновляет только при изменениях)
local LastDropdownCheckStr = ""
task.spawn(function()
    while task.wait(1.5) do
        local MurdererText = "Не найден"
        local SheriffText = "Не найден"
        local PlayerOptions = {}
        local BuildCheckStr = ""

        for _, P in ipairs(Players:GetPlayers()) do
            if P ~= LocalPlayer then
                local Role = GetPlayerRole(P)
                local DisplayString = "[" .. Role .. "] " .. P.Name
                table.insert(PlayerOptions, DisplayString)
                BuildCheckStr = BuildCheckStr .. DisplayString

                if Role == "Murderer" then MurdererText = P.Name end
                if Role == "Sheriff" then SheriffText = P.Name end
            end
        end

        RoleTable:Set({
            Title = "Текущие роли на карте (Live)",
            Content = "🔪 Мардер: " .. MurdererText .. "\n🔫 Шериф: " .. SheriffText
        })

        -- Триггерим обновление GUI только если изменился состав или роли
        if BuildCheckStr ~= LastDropdownCheckStr then
            LastDropdownCheckStr = BuildCheckStr
            if TargetDropdown then TargetDropdown:Refresh(PlayerOptions, true) end
        end
    end
end)

MM2Tab:CreateButton({
    Name = "🚀 ФЛИНГ ВЫБРАННЫХ (5 сек)",
    Callback = function() StartFlinging() end
})

-- ==================== Секция Утилит ====================
MM2Tab:CreateSection("Утилиты Шерифа (Gun Drops)")

MM2Tab:CreateButton({
    Name = "⚡ Подобрать оружие (Мгновенный ТП)",
    Callback = function()
        local GunDrop = GetGunDrop()
        local Character = LocalPlayer.Character
        local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
        
        if GunDrop and RootPart then
            local GunPart = GunDrop:IsA("BasePart") and GunDrop or GunDrop:FindFirstChildWhichIsA("BasePart")
            if GunPart then
                local OriginalCFrame = RootPart.CFrame
                RootPart.CFrame = GunPart.CFrame
                task.wait(0.2)
                RootPart.CFrame = OriginalCFrame
                Notify("Телепорт", "Прыжок к пушке выполнен!", 2)
            else
                Notify("Ошибка", "Деталь пушки не найдена.", 2)
            end
        else
            Notify("Ошибка", "Пушки сейчас нет на полу!", 2)
        end
    end
})

MM2Tab:CreateToggle({
    Name = "Автоподбор оружия (Auto-Pickup)",
    CurrentValue = false,
    Flag = "AutoPickupToggle",
    Callback = function(Value) AutoPickupEnabled = Value end
})

MM2Tab:CreateSlider({
    Name = "Количество попыток автоподбора",
    Range = {1, 5},
    Increment = 1,
    Suffix = "Попыток",
    CurrentValue = 1,
    Flag = "AutoPickupSlider",
    Callback = function(Value) AutoPickupAttempts = Value end
})

MM2Tab:CreateToggle({
    Name = "Gun ESP (Подсветка пистолета на полу)",
    CurrentValue = false,
    Flag = "GunESPToggle",
    Callback = function(Value) GunESPEnabled = Value end
})

MM2Tab:CreateSection("Быстрый Таргет")

MM2Tab:CreateToggle({
    Name = "Флинг по наведению мыши (Ctrl + R)",
    CurrentValue = false,
    Flag = "HoverFlingToggle",
    Callback = function(Value)
        HoverFlingEnabled = Value
        if Value then Notify("Включено", "Наведи на игрока и нажми Ctrl + R", 2) end
    end
})

MM2Tab:CreateButton({
    Name = "🔥 АВТО-ФЛИНГ МАРДЕРА (5 сек)",
    Callback = function()
        SelectedTargets = {}
        local Found = false
        for _, P in ipairs(Players:GetPlayers()) do
            if GetPlayerRole(P) == "Murderer" then
                SelectedTargets[P.Name] = P
                Found = true
                Notify("Таргет: Мардер", "Начинаю флинг " .. P.Name, 3, GetAvatar(P.UserId))
            end
        end
        if Found then StartFlinging() else Notify("Ошибка", "Мардер еще не получил нож.", 2) end
    end
})

MM2Tab:CreateButton({
    Name = "🔫 АВТО-ФЛИНГ ШЕРИФА (5 сек)",
    Callback = function()
        SelectedTargets = {}
        local Found = false
        for _, P in ipairs(Players:GetPlayers()) do
            if GetPlayerRole(P) == "Sheriff" then
                SelectedTargets[P.Name] = P
                Found = true
                Notify("Таргет: Шериф", "Начинаю флинг " .. P.Name, 3, GetAvatar(P.UserId))
            end
        end
        if Found then StartFlinging() else Notify("Ошибка", "Шерифа пока нет (или пушка на полу).", 2) end
    end
})

-- ==================== Вкладка player ====================
LoadExternalModule("https://raw.githubusercontent.com/geragori11/xclient_player/main/player.lua", Window)
-- ==================== Вкладка teleport ====================
LoadExternalModule("https://raw.githubusercontent.com/geragori11/teleports/main/teleport.lua", Window)
--LoadExternalModule("https://raw.githubusercontent.com/geragori11/Combat/main/combat.lua", Window)
LoadExternalModule("https://raw.githubusercontent.com/geragori11/visual/main/visual.lua", Window)

-- ==================== Вкладка Разработчик ====================
local DevTab = Window:CreateTab("Разработчик", 4483362458)

DevTab:CreateSection("Инструменты инспекции")

DevTab:CreateToggle({
    Name = "Включить Object Picker (Ctrl + Z)",
    CurrentValue = false,
    Flag = "ObjectPickerToggle",
    Callback = function(Value)
        ObjectPickerEnabled = Value
        if Value then
            Notify("Picker Включен", "Наведи курсор на любой объект и нажми Ctrl + Z", 3)
        end
    end
})

local DevConsole = DevTab:CreateParagraph({
    Title = "Консоль объектов",
    Content = "Ожидание сканирования... Наведите мышь на предмет и нажмите Ctrl + Z"
})

DevTab:CreateSection("Инспектор игроков (До получения оружия)")

DevTab:CreateToggle({
    Name = "Включить Player Picker (Ctrl + B)",
    CurrentValue = false,
    Flag = "PlayerPickerToggle",
    Callback = function(Value)
        PlayerPickerEnabled = Value
        if Value then
            Notify("Player Picker Включен", "Наведи курсор на человека и нажми Ctrl + B", 3)
        end
    end
})

local DevPlayerConsole = DevTab:CreateParagraph({
    Title = "Консоль информации об игроках",
    Content = "Наведите мышь на персонажа и нажмите Ctrl + B для полной проверки."
})

-- ==========================================
-- ОБРАБОТКА НАЖАТИЙ (КЛАВИАТУРА)
-- ==========================================
UserInputService.InputBegan:Connect(function(Input, GameProcessed)
    if GameProcessed then return end

    local IsCtrlPressed = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)

    -- Флинг по наведению (Ctrl + R)
    if HoverFlingEnabled and Input.KeyCode == Enum.KeyCode.R and IsCtrlPressed then
        local TargetPart = Mouse.Target
        if TargetPart then
            local Character = TargetPart:FindFirstAncestorOfClass("Model")
            if Character and Character:FindFirstChild("Humanoid") then
                local TargetPlayer = Players:GetPlayerFromCharacter(Character)
                
                if TargetPlayer and TargetPlayer ~= LocalPlayer then
                    SelectedTargets = {} 
                    SelectedTargets[TargetPlayer.Name] = TargetPlayer
                    Notify("Таргет: Мышь", "Начинаю флинг " .. TargetPlayer.Name, 3, GetAvatar(TargetPlayer.UserId))
                    StartFlinging()
                elseif TargetPlayer == LocalPlayer then
                    Notify("Ошибка", "Нельзя флингануть самого себя!", 2)
                end
            end
        end
    end

    -- Object Picker для Разработчика (Ctrl + Z)
    if ObjectPickerEnabled and Input.KeyCode == Enum.KeyCode.Z and IsCtrlPressed then
        local TargetObj = Mouse.Target
        if TargetObj then
            local ObjName = TargetObj.Name
            local ObjClass = TargetObj.ClassName
            local ParentName = TargetObj.Parent and TargetObj.Parent.Name or "Нет (workspace)"
            
            DevConsole:Set({
                Title = "Объект обнаружен: " .. ObjName,
                Content = "Имя: " .. ObjName .. "\n" ..
                          "Родитель (Папка): " .. ParentName .. "\n" ..
                          "Класс: " .. ObjClass
            })
            
            Notify("Успех", "Данные об объекте скопированы в консоль разработчика", 2)
        end
    end

    -- Второй Пикер: Player Picker (Ctrl + B)
    if PlayerPickerEnabled and Input.KeyCode == Enum.KeyCode.B and IsCtrlPressed then
        local TargetPart = Mouse.Target
        if TargetPart then
            local Character = TargetPart:FindFirstAncestorOfClass("Model")
            local TargetPlayer = Character and Players:GetPlayerFromCharacter(Character)
            
            if TargetPlayer then
                local Name = TargetPlayer.Name
                local DisplayName = TargetPlayer.DisplayName
                local UserId = TargetPlayer.UserId
                local Age = TargetPlayer.AccountAge
                
                -- Содержимое рюкзака и рук
                local BackpackItems = {}
                local Backpack = TargetPlayer:FindFirstChild("Backpack")
                if Backpack then
                    for _, Item in ipairs(Backpack:GetChildren()) do
                        table.insert(BackpackItems, Item.Name)
                    end
                end
                
                local CharacterItems = {}
                for _, Item in ipairs(Character:GetChildren()) do
                    if Item:IsA("Tool") then
                        table.insert(CharacterItems, Item.Name)
                    end
                end
                
                local BackpackStr = #BackpackItems > 0 and table.concat(BackpackItems, ", ") or "Пусто"
                local CharacterStr = #CharacterItems > 0 and table.concat(CharacterItems, ", ") or "В руках ничего нет"
                
                local DetectedRole = "Innocent (Не вооружен)"
                if table.find(BackpackItems, "Knife") or Character:FindFirstChild("Knife") then
                    DetectedRole = "🔪 MURDERER (Убийца)"
                elseif table.find(BackpackItems, "Gun") or Character:FindFirstChild("Gun") then
                    DetectedRole = "🔫 SHERIFF (Шериф)"
                end
                
                local FakeRoleValue = TargetPlayer:FindFirstChild("Role") or TargetPlayer:FindFirstChild("tempRole")
                if FakeRoleValue then
                    DetectedRole = tostring(FakeRoleValue.Value) .. " (Изменено внутренним значением)"
                end
                
                DevPlayerConsole:Set({
                    Title = "🕵️ Игрок: " .. DisplayName .. " (@" .. Name .. ")",
                    Content = "User ID: " .. UserId .. "\n" ..
                              "Возраст аккаунта: " .. Age .. " дней\n" ..
                              "В руках: " .. CharacterStr .. "\n" ..
                              "В рюкзаке: " .. BackpackStr .. "\n" ..
                              "Определенная роль: " .. DetectedRole
                })
                
                Notify("Сканирование завершено", "Информация о " .. Name .. " обновлена!", 2, GetAvatar(UserId))
            else
                Notify("Ошибка", "Вы навели мышь не на игрока!", 2)
            end
        end
    end
end)

-- ==================== Вкладка Настройки ====================
local SettingsTab = Window:CreateTab("Настройки", 4483362458)
SettingsTab:CreateButton({Name = "Очистить список целей", Callback = function() SelectedTargets = {} Notify("Очищено", "Цели сброшены", 2) end})
SettingsTab:CreateButton({
    Name = "Закрыть GUI", 
    Callback = function()
        StopFlinging()
        if AutoProtect then DisableCollision(LocalPlayer.Character) end 
        ClearGunESP()
        ClearAllPlayerESP()
        AutoPickupEnabled = false
        GunESPEnabled = false
        PlayerESPEnabled = false
        ObjectPickerEnabled = false
        PlayerPickerEnabled = false
        Library:Destroy()
    end
})

-- ==========================================
-- МЕСТО ДЛЯ ТВОИХ ВНЕШНИХ МОДУЛЕЙ
-- ==========================================
-- Просто раскомментируй (убери --) или скопируй эту строку и вставь свою ссылку на GitHub
-- LoadExternalModule("https://raw.githubusercontent.com/geragori11/XClientMenuV2/main/твой_скрипт.lua", Window)
-- ==========================================
-- МЕСТО ДЛЯ ТВОИХ ВНЕШНИХ МОДУЛЕЙ
-- ==========================================
--LoadExternalModule("https://raw.githubusercontent.com/geragori11/xclient_player/main/player.lua", Window)
-- ==================== ПодВкладка player |invisible ====================
--LoadExternalModule("https://raw.githubusercontent.com/geragori11/exploits/main/exploits.lua", Window)
Notify("Loaded", "MM2 Fling V4.9 загружен!", 3)
