--[[
    ATLAXX · STINGER
    Vicious Bee killer, переписанный на технологиях AtlasX:
      · свой UI (без Kavo / внешних либ) с фоном с GitHub и мобильным тумблером
      · AtlasX-полёт: платформа под игроком + tween / instant teleport
      · сохранение настроек, мульти-инжекторный слой совместимости
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local TweenService   = game:GetService("TweenService")
local TeleportService= game:GetService("TeleportService")
local StarterGui     = game:GetService("StarterGui")
local HttpService    = game:GetService("HttpService")
local GuiService     = game:GetService("GuiService")
local VIM            = game:GetService("VirtualInputManager")

local localPlayer = Players.LocalPlayer

--[[ COMPAT ]]
local function firstFn(...)
    for i = 1, select("#", ...) do
        local fn = select(i, ...)
        if type(fn) == "function" then return fn end
    end
end

local EX = { FileAPI = true, Http = true }
EX.Request = firstFn(request, http_request, httprequest, syn and syn.request, http and http.request)
EX.Queue   = firstFn(queue_on_teleport, syn and syn.queue_on_teleport, fluxus and fluxus.queue_on_teleport)
EX.GetConn = firstFn(getconnections)
EX.Asset   = firstFn(getcustomasset, getasset, getsynasset, syn and syn.getcustomasset)

local memFiles = {}
if type(readfile) ~= "function" or type(writefile) ~= "function" or type(isfile) ~= "function" then
    EX.FileAPI = false
    readfile = function(p) return memFiles[p] end
    writefile = function(p, d) memFiles[p] = d end
    isfile = function(p) return memFiles[p] ~= nil end
    delfile = function(p) memFiles[p] = nil end
end
isfolder = isfolder or function() return true end
makefolder = makefolder or function() end

local function exGuiParent()
    local ok, h = pcall(gethui)
    if ok and h then return h end
    local cg = game:GetService("CoreGui")
    local probe = Instance.new("Folder")
    probe.Parent = cg
    if probe.Parent == cg then probe:Destroy() return cg end
    probe:Destroy()
    return localPlayer:WaitForChild("PlayerGui")
end

local function httpGet(url)
    if EX.Request then
        local ok, res = pcall(EX.Request, { Url = url, Method = "GET" })
        if ok and type(res) == "table" then
            local body = res.Body or res.body
            if type(body) == "string" and #body > 0 then return body end
        end
    end
    if setfflag then pcall(setfflag, "HttpEnabled", "True") end
    local ok, body = pcall(function() return game:HttpGet(url, true) end)
    if ok and type(body) == "string" then return body end
    return nil
end

local ASSETS = "https://raw.githubusercontent.com/happy-g0ose/AtlasX-Obsidian/main/"

local function assetFromUrl(url, baseName)
    local path = baseName .. ".png"
    local okRead, data = pcall(readfile, path)
    if not (okRead and data) then
        local body = httpGet(url)
        if body then pcall(writefile, path, body) end
    end
    if EX.Asset then
        local ok, tex = pcall(EX.Asset, path)
        if ok then return tex end
    end
    return nil
end

local function notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = tostring(text), Duration = duration or 4
        })
    end)
    print("[" .. tostring(title) .. "] " .. tostring(text))
end

--[[ CONFIG ]]
local CONFIG_FILE = "atlasx_stinger.json"
local settings = {
    TweenSpeed = 50,
    HopMode = "Wait Spawn",
    AutoClaimHives = true,
    HiveSlot = "Auto",
    AutoKill = true,
    RushThorn = true,
    FieldFilter = true,
    ShowNotifs = true
}

local function loadConfig()
    local ok, data = pcall(readfile, CONFIG_FILE)
    if not ok or not data then return end
    local ok2, parsed = pcall(function() return HttpService:JSONDecode(data) end)
    if ok2 and type(parsed) == "table" then
        for k, v in pairs(parsed) do
            if type(settings[k]) == type(v) then settings[k] = v end
        end
    end
end
local function saveConfig()
    local ok, data = pcall(function() return HttpService:JSONEncode(settings) end)
    if ok then pcall(writefile, CONFIG_FILE, data) end
end
loadConfig()

local _G_KEYS = {
    TweenSpeed = "TweenSpeed", Thorns = "ThornsCollected", StartTime = "StartTime",
    HopMode = "ServerHopMode", Visited = "VisitedServers", InitialStingers = "InitialStingers",
    HiveSlot = "StingerHiveSlot"
}
if not _G.VisitedServers then _G.VisitedServers = {} end
if game.JobId and game.JobId ~= "" then _G.VisitedServers[game.JobId] = tick() end
local transfer = _G.StingerTransferData
if type(transfer) == "table" then
    for k, g in pairs(_G_KEYS) do
        if transfer[k] ~= nil then _G[g] = transfer[k] end
    end
end
_G.TweenSpeed = settings.TweenSpeed
_G.ServerHopMode = settings.HopMode
_G.ThornsCollected = _G.ThornsCollected or 0
_G.StartTime = _G.StartTime or tick()
_G.StingerHiveSlot = _G.StingerHiveSlot or settings.HiveSlot
settings.HiveSlot = _G.StingerHiveSlot

local stats = { Kills = _G.ThornsCollected, Status = "Idle", Server = "—" }

--[[ UI (AtlasX style, built with Instance.new) ]]
local ui = {}
ui.controls = {}

local gui = Instance.new("ScreenGui")
gui.Name = "AtlasXStinger"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = exGuiParent()

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = parent
end

local window = Instance.new("ImageLabel")
window.Name = "Window"
window.Size = UDim2.new(0, 620, 0, 430)
window.Position = UDim2.new(0.5, -310, 0.5, -215)
window.BackgroundColor3 = Color3.fromRGB(16, 16, 24)
window.BackgroundTransparency = 0.25
window.BorderSizePixel = 0
window.ScaleType = Enum.ScaleType.Crop
window.Parent = gui
corner(window, 12)

local bgTex = assetFromUrl(ASSETS .. "background.png", "stinger_bg")
if bgTex then window.Image = bgTex else window.ImageTransparency = 1 end

local shade = Instance.new("Frame")
shade.Size = UDim2.new(1, 0, 1, 0)
shade.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
shade.BackgroundTransparency = 0.45
shade.BorderSizePixel = 0
shade.Parent = window
corner(shade, 12)

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, -46, 0, 42)
titleBar.Position = UDim2.new(0, 12, 0, 0)
titleBar.BackgroundTransparency = 1
titleBar.Text = "ATLAXX · STINGER"
titleBar.TextColor3 = Color3.fromRGB(235, 235, 245)
titleBar.TextSize = 17
titleBar.Font = Enum.Font.GothamBold
titleBar.TextXAlignment = Enum.TextXAlignment.Left
titleBar.Parent = shade

local minimize = Instance.new("TextButton")
minimize.Size = UDim2.new(0, 30, 0, 30)
minimize.Position = UDim2.new(1, -38, 0, 6)
minimize.Text = "–"
minimize.TextColor3 = Color3.fromRGB(255, 100, 120)
minimize.BackgroundTransparency = 1
minimize.Font = Enum.Font.GothamBold
minimize.TextSize = 20
minimize.Parent = shade
minimize.MouseButton1Click:Connect(function() window.Visible = false end)

local tabsFrame = Instance.new("Frame")
tabsFrame.Size = UDim2.new(1, -24, 0, 34)
tabsFrame.Position = UDim2.new(0, 12, 0, 44)
tabsFrame.BackgroundTransparency = 1
tabsFrame.Parent = shade

local contentFrame = Instance.new("Frame")
contentFrame.Size = UDim2.new(1, -24, 1, -92)
contentFrame.Position = UDim2.new(0, 12, 0, 84)
contentFrame.BackgroundTransparency = 1
contentFrame.Parent = shade

ui.tabs = {}
ui.currentTab = nil

function ui:Tab(name)
    local tab = { name = name, sections = {} }
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 110, 0, 30)
    btn.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    btn.TextColor3 = Color3.fromRGB(200, 200, 215)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.Text = name
    corner(btn, 6)
    btn.Parent = tabsFrame
    local n = #ui.tabs + 1
    btn.Position = UDim2.new(0, (n - 1) * 116, 0, 0)

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.BorderSizePixel = 0
    page.ScrollBarThickness = 4
    page.Visible = false
    page.Parent = contentFrame
    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 6)
    layout.Parent = page
    tab.page = page
    tab.button = btn

    btn.MouseButton1Click:Connect(function() ui:Select(name) end)
    ui.tabs[name] = tab
    if not ui.currentTab then ui:Select(name) end
    return tab
end

function ui:Select(name)
    for _, tab in pairs(ui.tabs) do
        local active = tab.name == name
        tab.page.Visible = active
        tab.button.BackgroundColor3 = active and Color3.fromRGB(70, 40, 90) or Color3.fromRGB(28, 28, 40)
        tab.button.TextColor3 = active and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(200, 200, 215)
    end
    ui.currentTab = name
end

function ui:Section(tab, name)
    local section = { name = name }
    local header = Instance.new("TextLabel")
    header.Size = UDim2.new(1, -4, 0, 24)
    header.BackgroundTransparency = 1
    header.Text = "▸ " .. name
    header.TextColor3 = Color3.fromRGB(180, 150, 255)
    header.Font = Enum.Font.GothamBold
    header.TextSize = 13
    header.TextXAlignment = Enum.TextXAlignment.Left
    header.Parent = tab.page

    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(1, -4, 0, 10)
    holder.BackgroundTransparency = 1
    holder.Parent = tab.page
    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, 5)
    lay.Parent = holder
    lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        holder.Size = UDim2.new(1, -4, 0, lay.AbsoluteContentSize.Y)
    end)
    section.holder = holder
    return section
end

local function makeRow(section, height)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, 0, 0, height or 32)
    row.BackgroundColor3 = Color3.fromRGB(30, 30, 44)
    row.BackgroundTransparency = 0.35
    corner(row, 6)
    row.Parent = section.holder
    return row
end

function ui:Toggle(section, text, default, callback)
    local row = makeRow(section, 32)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 1, 0)
    btn.Position = UDim2.new(0, 6, 0, 0)
    btn.BackgroundTransparency = 1
    btn.TextColor3 = Color3.fromRGB(225, 225, 235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = row
    local ctrl = { value = default and true or false }
    function ctrl:Set(v, silent)
        self.value = v and true or false
        btn.Text = (self.value and "[✓] " or "[ ] ") .. text
        btn.TextColor3 = self.value and Color3.fromRGB(180, 255, 190) or Color3.fromRGB(225, 225, 235)
        if not silent then saveConfig() if callback then callback(self.value) end end
    end
    btn.MouseButton1Click:Connect(function() ctrl:Set(not ctrl.value) end)
    ctrl:Set(default, true)
    ui.controls[text] = ctrl
    return ctrl
end

function ui:Slider(section, text, min, max, default, step, callback)
    local row = makeRow(section, 34)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(0.62, -6, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(225, 225, 235)
    label.Font = Enum.Font.Gotham
    label.TextSize = 13
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local minus = Instance.new("TextButton")
    minus.Size = UDim2.new(0, 30, 0, 24)
    minus.Position = UDim2.new(0.64, 0, 0.5, -12)
    minus.Text = "–"
    minus.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    minus.TextColor3 = Color3.fromRGB(255, 255, 255)
    minus.Parent = row
    corner(minus, 5)
    local plus = Instance.new("TextButton")
    plus.Size = UDim2.new(0, 30, 0, 24)
    plus.Position = UDim2.new(1, -36, 0.5, -12)
    plus.Text = "+"
    plus.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    plus.TextColor3 = Color3.fromRGB(255, 255, 255)
    plus.Parent = row
    corner(plus, 5)
    local ctrl = { value = default }
    function ctrl:Set(v, silent)
        self.value = math.clamp(math.floor(v), min, max)
        label.Text = text .. ": " .. self.value
        if not silent then saveConfig() if callback then callback(self.value) end end
    end
    minus.MouseButton1Click:Connect(function() ctrl:Set(ctrl.value - step) end)
    plus.MouseButton1Click:Connect(function() ctrl:Set(ctrl.value + step) end)
    ctrl:Set(default, true)
    ui.controls[text] = ctrl
    return ctrl
end

function ui:Dropdown(section, text, options, default, callback)
    local row = makeRow(section, 32)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 1, 0)
    btn.Position = UDim2.new(0, 6, 0, 0)
    btn.BackgroundTransparency = 1
    btn.TextColor3 = Color3.fromRGB(225, 225, 235)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = row
    local ctrl = { value = default, options = options, index = 1 }
    for i, o in ipairs(options) do if o == default then ctrl.index = i end end
    function ctrl:Set(v, silent)
        self.value = v
        for i, o in ipairs(options) do if o == v then self.index = i end end
        btn.Text = text .. ": " .. self.value
        if not silent then saveConfig() if callback then callback(self.value) end end
    end
    btn.MouseButton1Click:Connect(function()
        ctrl:Set(options[(ctrl.index % #options) + 1])
    end)
    ctrl:Set(default, true)
    ui.controls[text] = ctrl
    return ctrl
end

function ui:Label(section, text)
    local row = makeRow(section, 26)
    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, -12, 1, 0)
    label.Position = UDim2.new(0, 6, 0, 0)
    label.BackgroundTransparency = 1
    label.TextColor3 = Color3.fromRGB(200, 200, 215)
    label.Font = Enum.Font.Gotham
    label.TextSize = 12
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Text = text
    label.Parent = row
    return { Set = function(_, v) label.Text = tostring(v) end }
end

function ui:Button(section, text, callback)
    local row = makeRow(section, 30)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -12, 1, 0)
    btn.Position = UDim2.new(0, 6, 0, 0)
    btn.BackgroundColor3 = Color3.fromRGB(60, 35, 80)
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamSemibold
    btn.TextSize = 13
    btn.Text = text
    btn.Parent = row
    corner(btn, 6)
    btn.MouseButton1Click:Connect(function() pcall(callback) end)
    return btn
end

-- mobile toggle icon (AtlasX style)
local toggleBtn = Instance.new("ImageButton")
toggleBtn.Size = UDim2.new(0, 52, 0, 52)
toggleBtn.Position = UDim2.new(0, 14, 0, 90)
toggleBtn.BackgroundTransparency = 1
toggleBtn.Parent = gui
local toggleTex = assetFromUrl(ASSETS .. "toggle.png", "stinger_toggle")
if toggleTex then
    toggleBtn.Image = toggleTex
else
    toggleBtn.BackgroundColor3 = Color3.fromRGB(60, 30, 80)
    toggleBtn.ImageTransparency = 1
end
corner(toggleBtn, 10)
toggleBtn.MouseButton1Click:Connect(function() window.Visible = not window.Visible end)

--[[ UI CONTENT ]]
local mainTab = ui:Tab("Main")
local core = ui:Section(mainTab, "Core Configuration")
local tweenCtrl = ui:Slider(core, "Tween Speed", 1, 150, settings.TweenSpeed, 5,
    function(v) settings.TweenSpeed = v _G.TweenSpeed = v end)
local hopCtrl = ui:Dropdown(core, "Server Hop Mode", { "Wait Spawn", "Instant Hop" }, settings.HopMode,
    function(v) settings.HopMode = v _G.ServerHopMode = v end)
local killCtrl = ui:Toggle(core, "Auto Kill Vicious", settings.AutoKill, function(v) settings.AutoKill = v end)
local thornCtrl = ui:Toggle(core, "Rush Thorn", settings.RushThorn, function(v) settings.RushThorn = v end)
local hiveCtrl = ui:Toggle(core, "Auto Claim Hive", settings.AutoClaimHives, function(v) settings.AutoClaimHives = v end)
local hiveSlotCtrl = ui:Dropdown(core, "Preferred Hive Slot", { "Auto", "1", "2", "3", "4", "5", "6" }, settings.HiveSlot,
    function(v) settings.HiveSlot = v _G.StingerHiveSlot = v end)
local fieldCtrl = ui:Toggle(core, "Field Filter", settings.FieldFilter, function(v) settings.FieldFilter = v end)
local notifCtrl = ui:Toggle(core, "Notifications", settings.ShowNotifs, function(v) settings.ShowNotifs = v end)

local statsTab = ui:Tab("Stats")
local statsSection = ui:Section(statsTab, "Session Statistics")
local labelKills = ui:Label(statsSection, "Vicious Killed: 0")
local labelTime = ui:Label(statsSection, "Time Elapsed: 00:00:00")
local labelStatus = ui:Label(statsSection, "Status: Idle")
local labelServer = ui:Label(statsSection, "Server: —")
local labelExec = ui:Label(statsSection, "Executor: " .. tostring(identifyexecutor and identifyexecutor() or "Unknown"))
ui:Button(statsSection, "Save Settings", function() saveConfig() notify("AtlasX · Stinger", "Settings saved") end)
ui:Button(statsSection, "Reset Session", function()
    _G.ThornsCollected = 0 stats.Kills = 0 _G.StartTime = tick() _G.VisitedServers = {}
    notify("AtlasX · Stinger", "Session reset")
end)

local creditsTab = ui:Tab("Credits")
local creditsSection = ui:Section(creditsTab, "Credits")
ui:Label(creditsSection, "Developer: happy goose")
ui:Label(creditsSection, "AtlasX UI / flight by happy_goose")
ui:Label(creditsSection, "Original Atlas by chris12089")

local function say(title, text)
    if settings.ShowNotifs then notify(title, text) end
end

--[[ GAME HELPERS ]]
local function getHRP() return localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart") end
local function getHumanoid() return localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid") end

local FieldsConfig = {
    ["Clover Field"] = true, ["Spider Field"] = true, ["Cactus Field"] = true,
    ["Rose Field"] = true, ["Mountain Top Field"] = true, ["Pepper Patch"] = true,
    ["Sunflower Field"] = true, ["Mushroom Field"] = true, ["Blue Flower Field"] = true,
    ["Dandelion Field"] = true, ["Strawberry Field"] = true, ["Bamboo Field"] = true,
    ["Pineapple Patch"] = true, ["Stump Field"] = true, ["Pine Tree Forest"] = true,
    ["Coconut Field"] = true
}

local function isFieldAllowed(position)
    if not settings.FieldFilter then return true end
    local fieldsFolder = workspace:FindFirstChild("Fields")
    if not fieldsFolder then return true end
    for _, field in ipairs(fieldsFolder:GetChildren()) do
        if field:IsA("BasePart") then
            local d = (Vector3.new(position.X, 0, position.Z) - Vector3.new(field.Position.X, 0, field.Position.Z)).Magnitude
            if d < 145 then return FieldsConfig[field.Name] == true end
        end
    end
    return true
end

local function findThorn()
    local wts = workspace:FindFirstChild("Particles") and workspace.Particles:FindFirstChild("WTs")
    if not wts then return nil end
    for _, v in ipairs(wts:GetChildren()) do
        if v.Name == "WaitingThorn" and isFieldAllowed(v.Position) then return v end
    end
    return nil
end

local function findVicious()
    local monsters = workspace:FindFirstChild("Monsters")
    if monsters then
        for _, v in ipairs(monsters:GetChildren()) do
            if string.find(v.Name, "Vicious", 1, true) then
                local hum = v:FindFirstChildOfClass("Humanoid")
                if hum and hum.Health > 0 then return v end
            end
        end
    end
    for _, v in ipairs(workspace:GetChildren()) do
        if string.find(v.Name, "Vicious", 1, true) then
            local hum = v:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health > 0 then return v end
        end
    end
    return nil
end

--[[ ATLASX FLIGHT ]]
local flight = { platform = nil, conn = nil, tween = nil }
local function clearFlight()
    if flight.conn then pcall(function() flight.conn:Disconnect() end) flight.conn = nil end
    if flight.tween then pcall(function() flight.tween:Cancel() end) flight.tween = nil end
    if flight.platform then pcall(function() flight.platform:Destroy() end) flight.platform = nil end
end

local function ensurePlatform()
    local hrp = getHRP()
    if not hrp then return nil end
    local p = Instance.new("Part")
    p.Name = "AtlasXFlightPlatform"
    p.Size = Vector3.new(14, 1, 14)
    p.Anchored = true
    p.CanCollide = true
    p.Transparency = 1
    p.Parent = workspace.CurrentCamera or workspace
    p.CFrame = hrp.CFrame - Vector3.new(0, 3.5, 0)
    flight.platform = p
    flight.conn = RunService.Heartbeat:Connect(function()
        if p.Parent and hrp.Parent then p.CFrame = hrp.CFrame - Vector3.new(0, 3.5, 0) end
    end)
    return p
end

local function teleportTo(position, keepY)
    local hrp = getHRP()
    if not hrp then return false end
    clearFlight()
    ensurePlatform()
    local target = keepY and Vector3.new(position.X, hrp.Position.Y, position.Z) or position
    pcall(function() hrp.CFrame = CFrame.new(target + Vector3.new(0, 2.5, 0)) end)
    return true
end

local function flyTo(position)
    local hrp = getHRP()
    if not hrp then return false end
    clearFlight()
    ensurePlatform()
    local target = position + Vector3.new(math.random(-1, 1), math.random(4, 7), math.random(-1, 1))
    local distance = (target - hrp.Position).Magnitude
    local speed = math.max(1, settings.TweenSpeed + math.random(-2, 2))
    local tween = TweenService:Create(hrp,
        TweenInfo.new(distance / speed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { CFrame = CFrame.new(target) })
    flight.tween = tween
    tween:Play()
    tween.Completed:Wait()
    task.wait(0.2)
    return true
end

--[[ SERVER HOP / TELEPORT DATA ]]
local function prepareTeleportData()
    local data = {
        TweenSpeed = settings.TweenSpeed,
        Thorns = _G.ThornsCollected,
        StartTime = _G.StartTime,
        HopMode = settings.HopMode,
        HiveSlot = settings.HiveSlot,
        Visited = _G.VisitedServers,
        InitialStingers = _G.InitialStingers
    }
    if not EX.Queue then return end
    local ok, encoded = pcall(function() return HttpService:JSONEncode(data) end)
    if ok then
        pcall(EX.Queue, [[ _G.StingerTransferData = game:GetService("HttpService"):JSONDecode(']] .. encoded .. [[') ]])
    end
end

pcall(function()
    if not EX.GetConn then return end
    GuiService.ErrorMessageChanged:Connect(function()
        task.wait(0.1)
        local provider = game:GetService("CoreGui"):FindFirstChild("RobloxGuiProvider")
        local prompt = provider and provider:FindFirstChild("ErrorPrompt")
        if not prompt then return end
        local button = prompt:FindFirstChildOfClass("TextButton") or prompt:FindFirstChildOfClass("ImageButton")
        if not button then return end
        for _, ev in ipairs({ "MouseButton1Click", "MouseButton1Down", "Activated" }) do
            local sig = button[ev]
            if sig then
                for _, conn in ipairs(EX.GetConn(sig)) do pcall(function() conn:Fire() end) end
            end
        end
    end)
end)

pcall(function()
    if EX.GetConn then
        for _, c in ipairs(EX.GetConn(localPlayer.Idled)) do pcall(function() c:Disable() end) end
    end
end)

local hopping = false
local function serverHop()
    if hopping then return end
    hopping = true
    stats.Status = "Server hopping"
    say("AtlasX · Stinger", "Searching for a unique server…")
    if game.JobId and game.JobId ~= "" then _G.VisitedServers[game.JobId] = tick() end
    prepareTeleportData()

    local placeId = game.PlaceId
    local list = {}
    local raw = httpGet("https://games.roblox.com/v1/games/" .. placeId .. "/servers/Public?sortOrder=Asc&limit=100")
    if raw then
        local ok, decoded = pcall(function() return HttpService:JSONDecode(raw) end)
        if ok and decoded and decoded.data then
            for _, server in ipairs(decoded.data) do
                if server.id and not _G.VisitedServers[server.id] and server.playing and server.maxPlayers then
                    if server.playing < math.floor(server.maxPlayers * 0.8) and server.playing > 0 then
                        table.insert(list, server)
                    end
                end
            end
        end
    end

    task.wait(0.05)
    if #list > 0 then
        local picked = list[math.random(1, #list)]
        _G.VisitedServers[picked.id] = tick()
        print("[AtlasX · Stinger] Joining " .. picked.playing .. "/" .. picked.maxPlayers)
        pcall(function() TeleportService:TeleportToPlaceInstance(placeId, picked.id, localPlayer) end)
        task.wait(4)
    else
        _G.VisitedServers = {}
        if game.JobId then _G.VisitedServers[game.JobId] = tick() end
        pcall(function() TeleportService:Teleport(placeId, localPlayer) end)
    end
    hopping = false
end

--[[ HIVE CLAIM (Atlas-derived: real HiveN slots, not canvases) ]]
local function getActivatePrompt()
    local pg = localPlayer:FindFirstChild("PlayerGui")
    local button = pg and pg:FindFirstChild("ScreenGui") and pg.ScreenGui:FindFirstChild("ActivateButton")
    local box = button and button:FindFirstChild("TextBox")
    if not box then return nil end
    local deadline = tick() + 2
    while tick() < deadline do
        local ok, offsetY = pcall(function() return button.Position.Y.Offset end)
        if ok and offsetY >= 0 then break end
        task.wait(0.05)
    end
    local ok, text = pcall(function() return box.Text end)
    return ok and text or nil
end

local function pressActivate()
    pcall(function()
        VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
        task.wait(0.15)
        VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end)
end

local function checkOwnHive()
    if localPlayer:FindFirstChild("Honeycomb") then return true end
    local honeycombs = workspace:FindFirstChild("Honeycombs")
    if honeycombs then
        for _, hive in ipairs(honeycombs:GetChildren()) do
            local owner = hive:FindFirstChild("Owner")
            if owner and owner:IsA("ObjectValue") and owner.Value == localPlayer then return true end
        end
    end
    -- fallback for older servers where only canvas tags exist
    local canvases = workspace:FindFirstChild("HiveDeco") and workspace.HiveDeco:FindFirstChild("StickerCanvases")
    if canvases then
        for i = 1, 6 do
            local canvas = canvases:FindFirstChild("StickerCanvas" .. i)
            local tag = canvas and (canvas:FindFirstChild("PlayerName") or canvas:FindFirstChild("OwnerTag"))
            if tag then
                if tag:IsA("StringValue") and tag.Value == localPlayer.Name then return true end
                if tag:IsA("ObjectValue") and tag.Value == localPlayer then return true end
                if tag:IsA("TextLabel") and tag.Text == localPlayer.Name then return true end
            end
        end
    end
    return false
end

local function claimHiveSlot(slotIndex)
    local honeycombs = workspace:FindFirstChild("Honeycombs")
    local hive = honeycombs and honeycombs:FindFirstChild("Hive" .. slotIndex)
    if not hive then return false end
    local owner = hive:FindFirstChild("Owner")
    if owner and owner.Value ~= nil and owner.Value ~= "" then return false end
    local arrow = hive:FindFirstChild("patharrow")
    local base = arrow and arrow:FindFirstChild("Base")
    if not base then return false end
    stats.Status = "Claiming Hive " .. slotIndex
    pcall(flyTo, base.Position + Vector3.new(0, 2, 0))
    task.wait(0.3)
    local prompt = getActivatePrompt()
    if prompt and not prompt:find("Claim Hive", 1, true) then
        -- localized prompt: still try E once rather than skipping the slot
        pressActivate()
    else
        pressActivate()
    end
    local deadline = tick() + 2
    while tick() < deadline and not localPlayer:FindFirstChild("Honeycomb") do task.wait(0.1) end
    if localPlayer:FindFirstChild("Honeycomb") then
        say("AtlasX", "Hive " .. slotIndex .. " claimed")
        return true
    end
    return false
end

local function claimAllHives()
    if not settings.AutoClaimHives or checkOwnHive() then return end
    local slots = {}
    local preferred = tonumber(settings.HiveSlot)
    if preferred and preferred >= 1 and preferred <= 6 then slots[#slots + 1] = preferred end
    for i = 6, 1, -1 do
        local seen = false
        for _, s in ipairs(slots) do if s == i then seen = true break end end
        if not seen then slots[#slots + 1] = i end
    end
    for i = 1, 6 do
        local seen = false
        for _, s in ipairs(slots) do if s == i then seen = true break end end
        if not seen then slots[#slots + 1] = i end
    end
    for _, slot in ipairs(slots) do
        if checkOwnHive() then return end
        if claimHiveSlot(slot) then
            stats.Status = "Idle"
            local spawn = localPlayer:FindFirstChild("SpawnPos")
            local value = spawn and spawn:FindFirstChild("Value")
            if value and value:IsA("Vector3Value") then pcall(flyTo, value.Value + Vector3.new(0, 3, 0)) end
            return
        end
    end
    -- fallback: canvas markers if the real HiveN slots are not present
    local canvases = workspace:FindFirstChild("HiveDeco") and workspace.HiveDeco:FindFirstChild("StickerCanvases")
    if canvases then
        for i = 1, 6 do
            if checkOwnHive() then return end
            local canvas = canvases:FindFirstChild("StickerCanvas" .. i)
            if canvas and canvas:FindFirstChild("OriginPart") then
                local tag = canvas:FindFirstChild("PlayerName") or canvas:FindFirstChild("OwnerTag")
                local occupied = canvas:FindFirstChild("Occupied")
                local free = not tag and (not occupied or occupied.Value == false or occupied.Value == 0)
                if free then
                    pcall(flyTo, canvas.OriginPart.Position + Vector3.new(0, 2, 0))
                    task.wait(0.3)
                    pressActivate()
                    task.wait(0.8)
                end
            end
        end
    end
    if not checkOwnHive() then serverHop() end
end

--[[ COMBAT ]]
local function followAndKillVicious()
    local vic = findVicious()
    if not vic then return end
    local vicRoot = vic:FindFirstChild("HumanoidRootPart") or vic.PrimaryPart or
        vic:FindFirstChild("Torso") or vic:FindFirstChild("Head") or vic:FindFirstChildOfClass("BasePart")
    if not vicRoot then return end

    stats.Status = "Killing Vicious"
    say("AtlasX · Stinger", "Target locked: Vicious Bee")

    local platform = Instance.new("Part")
    platform.Name = "AtlasXCombatPlatform"
    platform.Size = Vector3.new(45, 1, 45)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 1
    platform.Parent = workspace.CurrentCamera or workspace
    platform.CFrame = vicRoot.CFrame + Vector3.new(0, 8, 0)

    flyTo(platform.Position)
    local resetting = false
    local conn = RunService.Heartbeat:Connect(function()
        if not vicRoot or not vicRoot.Parent then return end
        platform.CFrame = CFrame.new(vicRoot.Position + Vector3.new(0, 8, 0))
        local hrp, h = getHRP(), getHumanoid()
        if hrp and h and h.Health > 0 and not resetting then
            if (hrp.Position - platform.Position).Magnitude > 35 or (hrp.Position.Y - platform.Position.Y) < -4 then
                resetting = true
                task.spawn(function()
                    teleportTo(platform.Position + Vector3.new(0, 3, 0))
                    resetting = false
                end)
            elseif settings.AutoKill then
                h:MoveTo(Vector3.new(vicRoot.Position.X, platform.Position.Y + 2, vicRoot.Position.Z))
            end
        end
    end)

    while settings.AutoKill do
        task.wait(0.5)
        if not findVicious() then
            pcall(function() conn:Disconnect() end)
            pcall(function() platform:Destroy() end)
            clearFlight()
            stats.Kills = stats.Kills + 1
            _G.ThornsCollected = stats.Kills
            stats.Status = "Vicious killed — hopping"
            serverHop()
            return
        end
        local h = getHumanoid()
        if not h or h.Health <= 0 then
            local charAdded = localPlayer.CharacterAdded:Wait()
            pcall(function() charAdded:WaitForChild("HumanoidRootPart", 20) end)
            task.wait(0.5)
            if findVicious() then teleportTo(platform.Position) end
        end
    end
    pcall(function() conn:Disconnect() end)
    pcall(function() platform:Destroy() end)
    clearFlight()
end

--[[ MAIN LOOP ]]
if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(1.2)
if not localPlayer.Character then localPlayer.CharacterAdded:Wait() end
pcall(function() localPlayer.Character:WaitForChild("HumanoidRootPart", 20) end)

if settings.HopMode == "Instant Hop" and not findVicious() and not findThorn() then
    serverHop()
end

task.spawn(function()
    while true do
        task.wait(0.3)
        if settings.AutoKill and findVicious() then
            claimAllHives()
            followAndKillVicious()
        elseif settings.RushThorn and findThorn() then
            local thorn = findThorn()
            claimAllHives()
            stats.Status = "Rushing thorn"
            teleportTo(thorn.Position)
            local deadline = tick() + 10
            local spawned = false
            while tick() < deadline do
                task.wait(0.2)
                if findVicious() then spawned = true break end
            end
            if spawned and settings.AutoKill then followAndKillVicious() else serverHop() end
        elseif settings.HopMode == "Instant Hop" then
            serverHop()
        else
            stats.Status = "Waiting for Vicious"
            task.wait(1.5)
            if not findVicious() and not findThorn() then serverHop() end
        end
    end
end)

-- stuck watchdog
task.spawn(function()
    local last, stuck = nil, 0
    while task.wait(1) do
        local hrp = getHRP()
        if hrp then
            local p = hrp.Position
            if last and (p - last).Magnitude < 1 then
                stuck = stuck + 1
                if stuck >= 15 then serverHop() break end
            else
                stuck = 0
            end
            last = p
        end
    end
end)

-- stats + server display
task.spawn(function()
    while task.wait(1) do
        local elapsed = tick() - (_G.StartTime or tick())
        local h = string.format("%02d", math.floor(elapsed / 3600))
        local m = string.format("%02d", math.floor((elapsed / 60) % 60))
        local s = string.format("%02d", math.floor(elapsed % 60))
        labelKills:Set("Vicious Killed: " .. tostring(stats.Kills))
        labelTime:Set("Time Elapsed: " .. h .. ":" .. m .. ":" .. s)
        labelStatus:Set("Status: " .. stats.Status)
        labelServer:Set("Server: " .. tostring(game.JobId ~= "" and game.JobId:sub(1, 8) or "—"))
    end
end)

notify("AtlasX · Stinger", "AtlasX Edition loaded")
