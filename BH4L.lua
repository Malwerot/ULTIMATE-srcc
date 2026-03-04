local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

----------------------------------------------------------------
-- [ CARREGAMENTO DE BIBLIOTECAS ]
----------------------------------------------------------------
getgenv().le = getgenv().le or loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/scripts/refs/heads/main/LimbExtender.lua'))()
local LimbExtender = getgenv().le

local le = LimbExtender({
    LISTEN_FOR_INPUT = false,
    USE_HIGHLIGHT = false,
})

getgenv().uilibray = getgenv().uilibray or loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
local Rayfield = getgenv().uilibray

----------------------------------------------------------------
-- [ LÓGICA DO AUTOFARM ]
----------------------------------------------------------------
local farmConnection
local currentIndex = 1
local farmTimer = 0
local equipPending = false
local equipTimer = 0
local EQUIP_DELAY = 0.3

local farmItems = {
    {name = "Water", cooldown = 0.5},
    {name = "Sugar Block Bag", cooldown = 22},
    {name = "Gelatin", cooldown = 2.8},
    {name = "Empty Bag", cooldown = 47},
}

local function countItems(itemName)
    local count = 0
    local backpack = LocalPlayer.Backpack
    local character = LocalPlayer.Character
    local items = {}
    if backpack then for _, v in ipairs(backpack:GetChildren()) do table.insert(items, v) end end
    if character then for _, v in ipairs(character:GetChildren()) do table.insert(items, v) end end
    
    for _, item in ipairs(items) do
        if item:IsA("Tool") and item.Name == itemName then
            count = count + 1
        end
    end
    return count
end

local function equipItem(itemName)
    local character = LocalPlayer.Character
    if not character then return false end
    local tool = LocalPlayer.Backpack:FindFirstChild(itemName)
    if tool then
        character.Humanoid:EquipTool(tool)
        return true
    end
    return false
end

local function pressE()
    pcall(function()
        local locations = {
            Workspace.Map.Houses.WH1:FindFirstChild("Interior"),
            Workspace.Map.Locations.Apartments:FindFirstChild("Home 1"),
            Workspace.Map.Locations.Apartments:FindFirstChild("Home 2"),
            Workspace.Map.Locations.Apartments:FindFirstChild("Home 3"),
            Workspace.Map.Locations.Apartments:FindFirstChild("Home 4")
        }
        -- Usando pairs para evitar que pare se encontrar um nil no meio do caminho
        for _, loc in pairs(locations) do
            if type(loc) == "userdata" then
                for _, child in ipairs(loc:GetChildren()) do
                    if child.Name == "Cooking Pot" then
                        local att = child:FindFirstChild("Attachment")
                        local pp = att and att:FindFirstChild("ProximityPrompt")
                        if pp then fireproximityprompt(pp) end
                    end
                end
            end
        end
    end)
end

local function startAutoFarm()
    if farmConnection then farmConnection:Disconnect() end
    farmTimer = 0
    currentIndex = 1
    farmConnection = RunService.Heartbeat:Connect(function(dt)
        farmTimer = farmTimer + dt
        if equipPending then
            equipTimer = equipTimer + dt
            if equipTimer >= EQUIP_DELAY then
                pressE()
                equipPending = false
                equipTimer = 0
                farmTimer = 0
            end
        elseif farmTimer >= farmItems[currentIndex].cooldown then
            if equipItem(farmItems[currentIndex].name) then
                equipPending = true
                equipTimer = 0
            end
            currentIndex = currentIndex % #farmItems + 1
            farmTimer = 0
        end
    end)
end

local function stopAutoFarm()
    if farmConnection then farmConnection:Disconnect() farmConnection = nil end
    equipPending = false
end

----------------------------------------------------------------
-- [ CONFIGURAÇÃO DA JANELA RAYFIELD ]
----------------------------------------------------------------
local Messages = {
    "Don't Blink Or Stare 🩸",
    "BloodHound On Top 🩸",
    "Vô do Silver Gosta de Anão ⛔",
    "DRACKOZADA DO INGUIÇA XOTA 💲",
    "     /̵͇̿̿/’̿’̿ ̿ ̿̿ ̿̿ ̿̿💥  ",
    "A",
    "SILVER BALUDÃO 🥵",
    "XOSOOOOOOOOO 💋",
    "M4 ☯︎",
    "SALUTATIONS TO BWD ⚜︎",
    "STACKS OF MONEY 💵",
    "follow axiogenesis on roblox 🦴👁",
}
local ChosenMessage = Messages[math.random(1, #Messages)]

local Window = Rayfield:CreateWindow({
    Name = "AXIOS",
    Icon = 107904589783906,
    LoadingTitle = "AXIOS",
    LoadingSubtitle = ChosenMessage,
    Theme = "Default",
    DisableRayfieldPrompts = false,
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "LimbExtenderConfigs",
        FileName = "Configuration",
    },
})

-- Criando as abas
local AutoTab = Window:CreateTab("AutoFarm", "badge-dollar-sign")
local Settings = Window:CreateTab("Limbs", "scale-3d")
local Tab = Window:CreateTab("Sense", "eye")
local Target = Window:CreateTab("Target", "crosshair")
local Themes = Window:CreateTab("Themes", "palette")

----------------------------------------------------------------
-- [ ABA: AUTOFARM - ATUALIZADA ]
----------------------------------------------------------------
AutoTab:CreateSection("Marshmallow AutoFarm")

AutoTab:CreateToggle({
    Name = "Iniciar AutoFarm (Cooking Pots)",
    CurrentValue = false,
    Flag = "AutoFarmMainToggle",
    Callback = function(Value)
        if Value then startAutoFarm() else stopAutoFarm() end
    end,
})

AutoTab:CreateButton({
    Name = "Vender para Lamont Bell (Instant)",
    Callback = function()
        pcall(function()
            local npc = Workspace.Folders.NPCs:FindFirstChild("Lamont Bell")
            if npc and npc:FindFirstChild("UpperTorso") then
                local pp = npc.UpperTorso:FindFirstChild("ProximityPrompt")
                if pp then
                    pp.HoldDuration = 0
                    fireproximityprompt(pp)
                end
            end
        end)
    end,
})

AutoTab:CreateDivider()

-- Label que será atualizada
local MarshLabel = AutoTab:CreateLabel("🍡 Marshmallows possíveis: 0")

-- Variável para controlar o loop do contador
local countingActive = false

AutoTab:CreateToggle({
    Name = "Atualizar Contador em Tempo Real",
    CurrentValue = false,
    Flag = "RealTimeCounter",
    Callback = function(Value)
        countingActive = Value
        
        task.spawn(function()
            while countingActive do
                -- Pcall evita que o erro pare o script e suje o log
                pcall(function()
                    local s = countItems("Sugar Block Bag")
                    local w = countItems("Water")
                    local g = countItems("Gelatin")
                    
                    -- Proteção básica: se os itens forem nil, o total é 0
                    local total = math.min(s or 0, w or 0, g or 0)
                    
                    -- Verifica se o MarshLabel ainda existe antes de setar
                    if MarshLabel and MarshLabel.Set then
                        MarshLabel:Set("🍡 Marshmallows possíveis: " .. tostring(total))
                    end
                end)
                
                task.wait(2) -- Aumentei para 2 segundos para dar fôlego ao CoreGui
            end
        end)
    end,
})

----------------------------------------------------------------
-- [ ABA: LIMBS (LimbExtender) ]
----------------------------------------------------------------
local function safeCreate(tab, methodName, opts)
    local method = tab[methodName]
    if type(method) == "function" then
        return method(tab, opts)
    else
        warn("Method " .. tostring(methodName) .. " not found on tab")
    end
end

local function createOption(params)
    local methodName = "Create" .. params.method
    local opts = {
        Name = params.name,
        SectionParent = params.section,
        CurrentValue = params.value,
        Flag = params.flag,
        Options = params.options,
        CurrentOption = params.currentOption,
        MultipleOptions = params.multipleOptions,
        Range = params.range,
        Color = params.color,
        Increment = params.increment,
        Callback = function(Value)
            if params.multipleOptions == false and type(Value) == "table" then
                Value = Value[1] or Value
            end
            le:Set(params.flag, Value)
        end,
    }
    return safeCreate(params.tab, methodName, opts)
end

local ModifyLimbs = Settings:CreateToggle({
    Name = "Modify Limbs",
    SectionParent = nil,
    CurrentValue = false,
    Flag = "ModifyLimbs",
    Callback = function(Value)
        le:Toggle(Value)
    end,
})
Settings:CreateDivider()

local toggleSettings = {
    { method = "Toggle", name = "Team Check", flag = "TEAM_CHECK", tab = Settings, value = le:Get("TEAM_CHECK") },
    { method = "Toggle", name = "ForceField Check", flag = "FORCEFIELD_CHECK", tab = Settings, value = le:Get("FORCEFIELD_CHECK") },
    { method = "Toggle", name = "Limb Collisions", flag = "LIMB_CAN_COLLIDE", tab = Settings, value = le:Get("LIMB_CAN_COLLIDE"), createDivider = true },
    { method = "Slider", name = "Limb Transparency", flag = "LIMB_TRANSPARENCY", tab = Settings, range = {0,1}, increment = 0.1, value = le:Get("LIMB_TRANSPARENCY") },
    { method = "Slider", name = "Limb Size", flag = "LIMB_SIZE", tab = Settings, range = {5,50}, increment = 0.5, value = le:Get("LIMB_SIZE"), createDivider = true },
}

for _, setting in pairs(toggleSettings) do
    createOption(setting)
    if setting.createDivider then
        setting.tab:CreateDivider()
    end
end

Settings:CreateKeybind({
    Name = "Toggle Keybind",
    CurrentKeybind = le:Get("TOGGLE"),
    HoldToInteract = false,
    SectionParent = nil,
    Flag = "ToggleKeybind",
    Callback = function()
        ModifyLimbs:Set(not le._running)
    end,
})

----------------------------------------------------------------
-- [ ABA: TARGET ]
----------------------------------------------------------------
local TargetLimb = Target:CreateDropdown({
    Name = "Target Limb",
    Options = {},
    CurrentOption = { le:Get("TARGET_LIMB") or "Head" },
    MultipleOptions = false,
    Flag = "TARGET_LIMB",
    Callback = function(Options)
        le:Set("TARGET_LIMB", type(Options) == "table" and Options[1] or Options)
    end,
})

----------------------------------------------------------------
-- [ ABA: THEMES ]
----------------------------------------------------------------
Themes:CreateDropdown({
    Name = "Current Theme",
    Options = {"Default", "AmberGlow", "Amethyst", "Bloom", "DarkBlue", "Green", "Light", "Ocean", "Serenity"},
    CurrentOption = {"Default"},
    MultipleOptions = false,
    Flag = "CurrentTheme",
    Callback = function(Options)
        Window:ModifyTheme(type(Options) == "table" and Options[1] or Options)
    end,
})

----------------------------------------------------------------
-- [ ABA: SENSE (ESP) ]
----------------------------------------------------------------
local Sense = loadstring(game:HttpGet('https://sirius.menu/sense'))()
Sense.teamSettings.enemy.enabled = true
Sense.teamSettings.friendly.enabled = true

local function setBoth(settingName, value)
    if Sense and Sense.teamSettings then
        Sense.teamSettings.enemy[settingName] = value
        Sense.teamSettings.friendly[settingName] = value
    end
end

local function createControl(def)
    if not def or not def.type then return end

    local function applyPropsToTeams(value)
        if not def.props then return end
        local function wrapColor(c)
            if def.alpha ~= nil then return {c, def.alpha} end
            return c
        end

        if def.props.friendly then
            local target = Sense.teamSettings.friendly
            for _, propName in ipairs(def.props.friendly) do
                target[propName] = (def.type == "color") and wrapColor(value) or value
            end
        end
        if def.props.enemy then
            local target = Sense.teamSettings.enemy
            for _, propName in ipairs(def.props.enemy) do
                target[propName] = (def.type == "color") and wrapColor(value) or value
            end
        end
    end

    local function controlCallback(v)
        if def.setting then setBoth(def.setting, v) end
        applyPropsToTeams(v)
        if def.onChange then def.onChange(v) end
    end

    if def.type == "section" then
        Tab:CreateSection(def.name or "")
        return
    elseif def.type == "label" then
        Tab:CreateLabel(def.name or "")
        return
    elseif def.type == "toggle" then
        return Tab:CreateToggle({ Name = def.name, CurrentValue = def.default or false, Flag = def.flag or "", Callback = controlCallback })
    elseif def.type == "color" then
        return Tab:CreateColorPicker({ Name = def.name, Color = def.color or Color3.fromRGB(255,255,255), Flag = def.flag or "", Callback = controlCallback })
    elseif def.type == "dropdown" then
        return Tab:CreateDropdown({ 
            Name = def.name, 
            Options = def.options or {}, 
            CurrentOption = {def.current}, 
            Flag = def.flag or "", 
            Callback = function(v)
                local val = type(v) == "table" and v[1] or v
                controlCallback(val)
            end 
        })
    elseif def.type == "slider" then
        return Tab:CreateSlider({ 
            Name = def.name, 
            Range = def.range or {0,100}, 
            CurrentValue = def.default or (def.range and def.range[1]) or 0, 
            Increment = def.increment or 1, 
            Suffix = def.suffix or "", 
            Flag = def.flag or "", 
            Callback = controlCallback 
        })
    end
end

local function colorBoth(name, flag, propertiesList, defaultColor, alpha)
    return { type = "color", name = name, flag = flag, color = defaultColor, alpha = alpha or 1, props = { friendly = propertiesList, enemy = propertiesList } }
end
local function colorFriendly(name, flag, friendlyProps, defaultColor, alpha)
    return { type = "color", name = name, flag = flag, color = defaultColor, alpha = alpha or 1, props = { friendly = friendlyProps } }
end
local function colorEnemy(name, flag, enemyProps, defaultColor, alpha)
    return { type = "color", name = name, flag = flag, color = defaultColor, alpha = alpha or 1, props = { enemy = enemyProps } }
end
local function toggle(name, flag, setting, default)
    return { type = "toggle", name = name, flag = flag, setting = setting, default = default }
end
local function slider(name, flag, range, default, inc, setting)
    return { type = "slider", name = name, flag = flag, range = range, default = default, increment = inc, setting = setting }
end

local ui = {
    { type = "section", name = "Team Settings" },
    { type = "toggle", name = "Hide Team", flag = "HideTeam", default = false, onChange = function(v) Sense.teamSettings.friendly.enabled = not v end },

    colorBoth("Team Color",  "TeamColor", {"boxColor","box3dColor","offScreenArrowColor","tracerColor"}, Color3.fromRGB(0,255,0), 1),
    colorBoth("Enemy Color", "EnemyColor", {"boxColor","box3dColor","offScreenArrowColor","tracerColor"}, Color3.fromRGB(255,0,0), 1),

    { type = "section", name = "Box" },
    toggle("Enabled", "Boxes", "box", false),
    toggle("Outline", "BoxesOutlined", "boxOutline", true),
    toggle("Fill", "BoxesFilled", "boxFill", false),
    colorFriendly("Team Fill Color", "TeamFillColor", {"boxFillColor"}, Color3.fromRGB(0,255,0), 0.5),
    colorEnemy("Enemy Fill Color", "EnemyFillColor", {"boxFillColor"}, Color3.fromRGB(255,0,0), 0.5),
    toggle("3D Boxes", "3DBoxes", "box3d", false),

    { type = "section", name = "Health" },
    toggle("Enabled", "HealthBar", "healthBar", false),
    { type = "color", name = "Health Color", flag = "HealthColor", color = Color3.fromRGB(0,255,0), onChange = function(c) setBoth("healthyColor", c) end },
    { type = "color", name = "Dying Color", flag = "DyingColor", color = Color3.fromRGB(255,0,0), onChange = function(c) setBoth("dyingColor", c) end },
    toggle("Outline", "HBsOutlined", "healthBarOutline", true),

    { type = "section", name = "Tracer" },
    toggle("Enabled", "Tracers", "tracer", false),
    toggle("Outline", "TracersOutlined", "tracerOutline", true),
    { type = "dropdown", name = "Origin", flag = "TracerOrigin", options = {"Bottom","Top","Mouse"}, current = "Bottom", onChange = function(v) setBoth("tracerOrigin", type(v) == "table" and v[1] or v) end },

    { type = "section", name = "Tag" },
    toggle("Name", "Names", "name", false),
    toggle("Name Outlined", "NamesOutlined", "nameOutline", true),
    toggle("Distance", "Distances", "distance", false),
    toggle("Distance Outlined", "DistancesOutlined", "distanceOutline", true),
    toggle("Health", "Health", "healthText", false),
    toggle("Health Outlined", "HealthsOutlined", "healthTextOutline", true), -- Nome corrigido aqui

    { type = "section", name = "Chams" },
    toggle("Enabled", "Chams", "chams", false),
    toggle("Visible Only", "ChamsVisOnly", "chamsVisibleOnly", false),
    colorFriendly("Team Fill Color", "TeamFillColorChams", {"chamsFillColor"}, Color3.new(0.2,0.2,0.2), 0.5),
    colorFriendly("Team Outline Color", "TeamOutlineColorChams", {"chamsOutlineColor"}, Color3.new(0,1,0), 0),
    colorEnemy("Enemy Fill Color", "EnemyFillColorChams", {"chamsFillColor"}, Color3.new(0.2,0.2,0.2), 0.5),
    colorEnemy("Enemy Outline Color", "EnemyOutlineColorChams", {"chamsOutlineColor"}, Color3.new(1,0,0), 0),

    { type = "section", name = "Off Screen Arrow" },
    toggle("Enabled", "OSA", "offScreenArrow", false),
    slider("Size", "OSASize", {15,50}, 15, 1, "offScreenArrowSize"),
    slider("Radius", "OSARadius", {150,360}, 150, 1, "offScreenArrowRadius"),
    toggle("Outline", "OSAOutlined", "offScreenArrowOutline", true),

    { type = "section", name = "Weapon" },
    toggle("Enabled", "Weapons", "weapon", false),
    toggle("Outline", "WeaponOutlined", "weaponOutline", true),
}

for _, entry in ipairs(ui) do
    createControl(entry)
end

----------------------------------------------------------------
-- [ CARREGAMENTO FINAL E CONEXÕES ]
----------------------------------------------------------------
Rayfield:LoadConfiguration()

local limbs = {}
local function addLimbIfNew(name)
    if not name then return end
    if not table.find(limbs, name) then
        table.insert(limbs, name)
        table.sort(limbs)
        TargetLimb:Refresh(limbs)
    end
end

local function characterAdded(Character)
    if not Character then return end
    local function onChildChanged(child)
        if not child or not child:IsA("BasePart") then return end
        addLimbIfNew(child.Name)
    end

    Character.ChildAdded:Connect(onChildChanged)

    for _, child in ipairs(Character:GetChildren()) do
        onChildChanged(child)
    end
end

LocalPlayer.CharacterAdded:Connect(characterAdded)
if LocalPlayer.Character then
    characterAdded(LocalPlayer.Character)
end

Rayfield:Notify({
    Title = "Script Carregado!",
    Content = "AutoFarm e ESP prontos.",
    Duration = 4,
    Image = 4483345998,
})
