local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

-- Variáveis de configuração técnica
local DEFAULTS = {
	TARGET_LIMB = "HumanoidRootPart",
	LIMB_SIZE = 15,
	LIMB_TRANSPARENCY = 0.9,
	LIMB_CAN_COLLIDE = false,
	TEAM_CHECK = true,
	FORCEFIELD_CHECK = true,
	RESET_LIMB_ON_DEATH2 = false,
	USE_HIGHLIGHT = true,
	DEPTH_MODE = "AlwaysOnTop",
	HIGHLIGHT_FILL_COLOR = Color3.fromRGB(255, 117, 24),
	HIGHLIGHT_FILL_TRANSPARENCY = 0.7,
	HIGHLIGHT_OUTLINE_COLOR = Color3.fromRGB(0,0,0),
	HIGHLIGHT_OUTLINE_TRANSPARENCY = 1,
}

local limbExtenderData = getgenv().limbExtenderData or {}
getgenv().limbExtenderData = limbExtenderData

-- Finaliza processos antigos se existirem
if limbExtenderData.terminateOldProcess and type(limbExtenderData.terminateOldProcess) == "function" then
	limbExtenderData.terminateOldProcess("FullKill")
	limbExtenderData.terminateOldProcess = nil
end

-- Carregamento de módulos lógicos (Sem UI)
if not limbExtenderData.ConnectionManager then
	limbExtenderData.ConnectionManager = loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/modules/refs/heads/main/ConnectionManager.lua'))()
end
local ConnectionManager = limbExtenderData.ConnectionManager

-- Bypass de Anti-Cheat interno
if not limbExtenderData._indexBypassDone then
	limbExtenderData._indexBypassDone = true
    pcall(function()
        for _, obj in ipairs(getgc(true)) do
            local idx = rawget(obj, "indexInstance")
            if typeof(idx) == "table" and idx[1] == "kick" then
                for _, pair in pairs(obj) do
                    pair[2] = function() return false end
                end
                break
            end
        end
    end)
end

-- FUNÇÕES DE SUPORTE
local function mergeSettings(user)
	local s = {}
	for k,v in pairs(DEFAULTS) do s[k] = v end
	if user then for k,v in pairs(user) do s[k] = v end end
	return s
end

local function watchProperty(instance, prop, callback)
	if not instance or type(prop) ~= "string" or type(callback) ~= "function" then return nil end
	local signal = instance:GetPropertyChangedSignal(prop)
	if signal and type(signal.Connect) == "function" then
		return signal:Connect(function() callback(instance) end)
	end
	return nil
end

local function makeHighlight(settings)
	local hiFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Limb Extender Highlights Folder")
	if not hiFolder then
		hiFolder = Instance.new("Folder")
		hiFolder.Name = "Limb Extender Highlights Folder"
		hiFolder.Parent = game:GetService("ReplicatedStorage")
	end
	local hi = Instance.new("Highlight")
	hi.Name = "LimbHighlight"
	if settings and settings.DEPTH_MODE then hi.DepthMode = Enum.HighlightDepthMode[settings.DEPTH_MODE] end
	hi.FillColor = settings.HIGHLIGHT_FILL_COLOR
	hi.FillTransparency = settings.HIGHLIGHT_FILL_TRANSPARENCY
	hi.OutlineColor = settings.HIGHLIGHT_OUTLINE_COLOR
	hi.OutlineTransparency = settings.HIGHLIGHT_OUTLINE_TRANSPARENCY
	hi.Enabled = true
	hi.Parent = hiFolder
	return hi
end

-- CLASSE PLAYERDATA (Gerencia cada jogador individualmente)
local PlayerData = {}
PlayerData.__index = PlayerData

function PlayerData.new(parent, player)
	local self = setmetatable({
		_parent = parent,
		player = player,
		conns = ConnectionManager.new(),
		highlight = nil,
		PartStreamable = nil,
		_charDelay = nil,
		_destroyed = false,
	}, PlayerData)

	if player and player.CharacterAdded then
		self.conns:Connect(player.CharacterAdded, function(c) self:onCharacter(c) end, ("Player_%s_CharacterAdded"):format(player.Name))
	end
	self:onCharacter(player.Character or workspace:FindFirstChild(player.Name))
	return self
end

function PlayerData:saveLimbProperties(limb)
	local parent = self._parent
	parent._limbStore[limb] = {
		OriginalSize = limb.Size,
		OriginalTransparency = limb.Transparency,
		OriginalCanCollide = limb.CanCollide,
		OriginalMassless = limb.Massless,
	}
end

function PlayerData:restoreLimbProperties(limb)
	local parent = self._parent
	local p = parent._limbStore[limb]
	if not p then return end
	
	if limb and limb.Parent then
		limb.Size = p.OriginalSize
		limb.Transparency = p.OriginalTransparency
		limb.CanCollide = p.OriginalCanCollide
		limb.Massless = p.OriginalMassless
	end
	parent._limbStore[limb] = nil
	if limbExtenderData.limbs then limbExtenderData.limbs[limb] = nil end
end

function PlayerData:modifyLimbProperties(limb)
	local parent = self._parent
	if not limb or parent._limbStore[limb] then return end
	self:saveLimbProperties(limb)
	
	local sizeVal = parent._settings.LIMB_SIZE or DEFAULTS.LIMB_SIZE
	local newSize = Vector3.new(sizeVal, sizeVal, sizeVal)

	-- Mantém as propriedades travadas
	self.conns:Connect(limb:GetPropertyChangedSignal("Size"), function() limb.Size = newSize end)
	self.conns:Connect(limb:GetPropertyChangedSignal("Transparency"), function() limb.Transparency = parent._settings.LIMB_TRANSPARENCY end)
	self.conns:Connect(limb:GetPropertyChangedSignal("CanCollide"), function() limb.CanCollide = parent._settings.LIMB_CAN_COLLIDE end)

	limb.Size = newSize
	limb.Transparency = parent._settings.LIMB_TRANSPARENCY
	limb.CanCollide = parent._settings.LIMB_CAN_COLLIDE
	if parent._settings.TARGET_LIMB ~= "HumanoidRootPart" then limb.Massless = true end

	if limbExtenderData.limbs then limbExtenderData.limbs[limb] = parent._limbStore[limb] end
end

function PlayerData:spoofSize(part)
	if not part then return end
    local saved = part.Size
    local name = part.Name
	if limbExtenderData._spoofTarget == name then return end
	limbExtenderData._spoofTarget = name

    pcall(function()
		local mt = getrawmetatable(game)
		setreadonly(mt, false)
		local old = mt.__index
		mt.__index = function(Self, Key)
			if tostring(Self) == name and tostring(Key) == "Size" and not checkcaller() then return saved end
			return old(Self, Key)
		end
		setreadonly(mt, true)
	end)
end

function PlayerData:setupCharacter(char)
	local parent = self._parent
	if not char or not parent or parent:_isTeam(self.player) then return end

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end

	if parent._Streamable then
		self.PartStreamable = parent._Streamable.new(char, parent._settings.TARGET_LIMB)
		self.PartStreamable:Observe(function(part)
			if self._destroyed or not part then return end
			self:spoofSize(part)
			self:modifyLimbProperties(part)

			if parent._settings.USE_HIGHLIGHT then
				if not self.highlight then self.highlight = makeHighlight(parent._settings) end
				self.highlight.Adornee = part
			end
		end)
	end
end

function PlayerData:onCharacter(char)
	if not char then return end
	task.delay(0.1, function()
		if self._destroyed then return end
		self:setupCharacter(char)
	end)
end

function PlayerData:Destroy()
	self._destroyed = true
	if self.conns then self.conns:DisconnectAll() end
	if self.highlight then self.highlight:Destroy() end
	if self.PartStreamable then self.PartStreamable:Destroy() end
end

-- CLASSE PRINCIPAL (LimbExtender)
local LimbExtender = {}
LimbExtender.__index = LimbExtender

function LimbExtender.new(userSettings)
	local self = setmetatable({
		_settings = mergeSettings(userSettings),
		_playerTable = limbExtenderData.playerTable or {},
		_limbStore = limbExtenderData.limbs or {},
		_Streamable = nil,
		_connections = ConnectionManager.new(),
		_running = false,
	}, LimbExtender)

	limbExtenderData.playerTable = self._playerTable
	limbExtenderData.limbs = self._limbStore
	
	self._Streamable = loadstring(game:HttpGet('https://raw.githubusercontent.com/AAPVdev/modules/refs/heads/main/Streamable.lua'))()
	limbExtenderData.Streamable = self._Streamable

	limbExtenderData.terminateOldProcess = function() self:Destroy() end
    
    self:Start() -- Inicia automaticamente sem necessidade de botão
	return self
end

function LimbExtender:_isTeam(player)
	return self._settings.TEAM_CHECK and localPlayer.Team ~= nil and player.Team == localPlayer.Team
end

function LimbExtender:Start()
	if self._running then return end
	self._running = true
	
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= localPlayer then self._playerTable[p.Name] = PlayerData.new(self, p) end
	end

	self._connections:Connect(Players.PlayerAdded, function(p)
		self._playerTable[p.Name] = PlayerData.new(self, p)
	end)

	self._connections:Connect(Players.PlayerRemoving, function(p)
		if self._playerTable[p.Name] then self._playerTable[p.Name]:Destroy() end
		self._playerTable[p.Name] = nil
	end)
end

function LimbExtender:Stop()
	self._running = false
	for i, pd in pairs(self._playerTable) do pd:Destroy() end
	self._playerTable = {}
end

function LimbExtender:Destroy()
	self:Stop()
	if self._connections then self._connections:DisconnectAll() end
	limbExtenderData.terminateOldProcess = nil
end

function LimbExtender:Set(key, value)
	if self._settings[key] ~= value then
		self._settings[key] = value
		self:Restart()
	end
end

-- Execução do script
 function LimbExtender:Get(key) return self._settings[key] end

 return setmetatable({}, { __call = function(_, userSettings) return LimbExtender.new(userSettings) end, __index = LimbExtender, })
