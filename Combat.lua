-- // CONFIGURAÇÃO GLOBAL // --
_G.Seriality = true -- Altere para false para desligar o Fast Attack

-- // VARIÁVEIS PRINCIPAIS // --
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local plr = Players.LocalPlayer

-- // FUNÇÃO PARA CONFERIR INIMIGOS E ALVOS VIVOS // --
local function IsEntityAlive(entity)
    if not entity then return false end
    local humanoid = entity:FindFirstChildOfClass("Humanoid")
    return humanoid and humanoid.Health > 0
end

-- // ENCONTRAR INIMIGOS PRÓXIMOS // --
local function GetEnemiesInRange(character, range)
    local targets = {}
    local playerPos = character:GetPivot().Position
    
    -- Checar inimigos do mapa
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, enemy in ipairs(enemies:GetChildren()) do
            local rootPart = enemy:FindFirstChild("HumanoidRootPart")
            if rootPart and IsEntityAlive(enemy) then
                if (rootPart.Position - playerPos).Magnitude <= range then
                    table.insert(targets, enemy)
                end
            end
        end
    end
    
    -- Checar outros jogadores (PVP)
    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= plr and otherPlayer.Character then
            local rootPart = otherPlayer.Character:FindFirstChild("HumanoidRootPart")
            if rootPart and IsEntityAlive(otherPlayer.Character) then
                if (rootPart.Position - playerPos).Magnitude <= range then
                    table.insert(targets, otherPlayer.Character)
                end
            end
        end
    end
    return targets
end

-- // SISTEMA CORRIGIDO DE REGISTRO DE DANO (FAST ATTACK) // --
local function AttackNoCoolDown()
    local character = plr.Character
    if not character then return end
    
    local equippedWeapon = nil
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then
            equippedWeapon = item
            break
        end
    end
    if not equippedWeapon then return end
    
    local enemiesInRange = GetEnemiesInRange(character, 60)
    if #enemiesInRange == 0 then return end
    
    local netFolder = ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Net")
    local attackEvent = netFolder:WaitForChild("RE/RegisterAttack")
    local hitEvent = netFolder:WaitForChild("RE/RegisterHit")
    
    if not attackEvent or not hitEvent then return end
    
    local targets = {}
    local mainTarget = nil
    local HitboxLimbs = {"RightLowerArm", "RightUpperArm", "LeftLowerArm", "LeftUpperArm", "RightHand", "LeftHand", "Head"}
    
    for _, enemy in ipairs(enemiesInRange) do
        if not enemy:GetAttribute("IsBoat") then
            local partName = HitboxLimbs[math.random(#HitboxLimbs)]
            local targetPart = enemy:FindFirstChild(partName) or enemy.PrimaryPart
            if targetPart then
                table.insert(targets, { enemy, targetPart })
                mainTarget = targetPart
            end
        end
    end
    
    if not mainTarget then return end
    
    -- Dispara o ataque sem animação/cooldown
    attackEvent:FireServer(0)
    
    -- Envia o registro de acerto diretamente ao servidor
    pcall(function()
        local flags = require(ReplicatedStorage.Modules.Flags)
        if flags and flags.COMBAT_REMOTE_THREAD then
            local playerScripts = plr:FindFirstChild("PlayerScripts")
            local localScript = playerScripts and playerScripts:FindFirstChildOfClass("LocalScript")
            if localScript and getsenv then
                local env = getsenv(localScript)
                if env and env._G and env._G.SendHitsToServer then
                    env._G.SendHitsToServer(mainTarget, targets)
                    return
                end
            end
        end
        -- Fallback seguro caso o thread esteja desativado ou modificado
        hitEvent:FireServer(mainTarget, targets)
    end)
end

-- // REMOÇÃO DO BALANÇO DE CÂMERA (ANTI-SHAKE) // --
pcall(function()
    local CameraShaker = require(ReplicatedStorage:WaitForChild("Util"):WaitForChild("CameraShaker"))
    if CameraShaker then
        CameraShaker:Stop()
    end
end)

-- // VERIFICAÇÃO DE ALVOS MÁGICOS OU BLOX FRUITS M1 // --
local function get_Monster()
    local character = plr.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return false end
    
    local enemies = workspace:FindFirstChild("Enemies")
    if enemies then
        for _, b in pairs(enemies:GetChildren()) do
            local c = b:FindFirstChild("UpperTorso") or b:FindFirstChild("Head")
            if b:FindFirstChild("HumanoidRootPart") and c then
                if (c.Position - character.HumanoidRootPart.Position).Magnitude <= 50 then
                    return true, c.Position
                end
            end
        end
    end
    return false
end

-- // LOOP PRINCIPAL DE EXECUÇÃO CONSTANTE // --
RunService.Heartbeat:Connect(function()
    if not _G.Seriality then return end
    
    pcall(function()
        -- Executa o Fast Attack baseado em ferramentas físicas (Espada, Estilo de Luta, Arma)
        AttackNoCoolDown()
        
        -- Executa cliques automáticos para habilidades M1 de Frutas (ex: Buddha, Light, etc.)
        local character = plr.Character
        local tool = character and character:FindFirstChildOfClass("Tool")
        if tool and tool.ToolTip == "Blox Fruit" then
            local hasMob = get_Monster()
            if hasMob then
                local LeftClickRemote = tool:FindFirstChild("LeftClickRemote")
                if LeftClickRemote then
                    LeftClickRemote:FireServer(Vector3.new(0.01, -500, 0.01), 1, true)
                    LeftClickRemote:FireServer(false)
                end
            end
        end
    end)
end)
