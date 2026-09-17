-- =================================================================
-- KissoHub — Anime Monster Collector (Part 1: setup + helpers)
-- =================================================================
return function(KissoCore)
    if type(KissoCore) ~= "table" then
        warn("[AMC] KissoCore not passed in.")
        return
    end
    if not KissoCore.Rayfield then
        warn("[AMC] Rayfield missing.")
        return
    end

    local Rayfield   = KissoCore.Rayfield
    local ASSET_ICON = KissoCore.ASSET_ICON or "rbxassetid://89387722763691"

    local Players     = game:GetService("Players")
    local Workspace   = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    local function TryUI(label, fn)
        local ok, result = pcall(fn)
        if not ok then
            warn("[AMC] Failed: " .. label .. " -> " .. tostring(result))
            return nil
        end
        return result
    end

    local Window = TryUI("BuildWindow", function()
        return KissoCore.BuildWindow("Anime Monster Collector", "AMCPrefs")
    end)
    if not Window then
        warn("[AMC] Window creation failed.")
        return
    end

    local StatusTag, StateTag, SetActivity = TryUI("BuildTags", function()
        return KissoCore.BuildTags(Window)
    end)

    local SafeNotify = function(t, c, d) pcall(function() KissoCore.SafeNotify(Window, t, c, d) end) end
    local QuickToast = function(t, s) pcall(function() KissoCore.QuickToast(Window, t, s) end) end

    local SpiritMapping = {}
    local SelectedSpiritInstance = nil
    local SelectedSortMethod = "Level (High to Low)"
    local AutoLockSpiritEnabled = false
    local ChestMapping = {}
    local SelectedChestInstance = nil
    local AutoOpenChestsEnabled = false
    local WalkSpeedValue = 16
    local InfZoomEnabled = false
    local AntiVoidEnabled = false

    local function getSpiritName(spirit)
        local obj = spirit:FindFirstChild("SpiritName", true)
        if obj then
            if obj:IsA("TextLabel") or obj:IsA("TextBox") then
                if obj.Text ~= "" then return obj.Text end
            elseif obj:IsA("ValueBase") then
                if tostring(obj.Value) ~= "" then return tostring(obj.Value) end
            end
        end
        return spirit.Name
    end

    local function getSpiritLevel(spirit)
        local obj = spirit:FindFirstChild("SpiritLevel", true)
        if obj then
            if obj:IsA("TextLabel") or obj:IsA("TextBox") then
                local n = tonumber(string.match(obj.Text, "%d+"))
                if n then return n end
                if obj.Text ~= "" then return obj.Text end
            elseif obj:IsA("ValueBase") then
                return tonumber(obj.Value) or obj.Value
            end
        end
        local attr = spirit:GetAttribute("Level") or spirit:GetAttribute("Lvl")
        if attr then return tonumber(attr) or attr end
        return 0
    end

    local function getSpiritMaxHP(spirit)
        local maxHp = spirit:GetAttribute("MaxHP") or spirit:GetAttribute("MaxHealth") or 0
        if maxHp == 0 then
            local hum = spirit:FindFirstChildOfClass("Humanoid") or spirit:FindFirstChildWhichIsA("Humanoid", true)
            if hum then maxHp = hum.MaxHealth end
        end
        if maxHp == 0 then
            local hpObj = spirit:FindFirstChild("MaxHP", true)
                or spirit:FindFirstChild("MaxHealth", true)
                or spirit:FindFirstChild("Health", true)
            if hpObj and hpObj:IsA("ValueBase") then maxHp = hpObj.Value end
        end
        return tonumber(maxHp) or 0
    end

    local function isChestOnCooldown(chest)
        local statusUI = chest:FindFirstChild("ClientComponent_ChestRewardStatus", true)
        if statusUI then
            local cd = statusUI:FindFirstChild("CooldownGui", true) or statusUI:FindFirstChild("Cooldown", true)
            if cd then
                if cd:IsA("GuiObject") then return cd.Visible end
                if cd:IsA("LayerCollector") then return cd.Enabled end
                return true
            end
        end
        local cdDirect = chest:FindFirstChild("CooldownGui", true)
        if cdDirect then
            if cdDirect:IsA("GuiObject") then return cdDirect.Visible end
            if cdDirect:IsA("LayerCollector") then return cdDirect.Enabled end
            return true
        end
        return false
    end

    local function refreshChestList(ChestDropdown)
        local activeLevels = Workspace:FindFirstChild("ActiveLevels")
        local chestData = {}
        ChestMapping = {}

        if activeLevels then
            local excludedKeywords = {"button","frame","ui","gui","icon","prompt","label","text","template","holder","close","open"}
            local addedInstances = {}

            for _, desc in ipairs(activeLevels:GetDescendants()) do
                if desc:IsA("Model") or desc:IsA("BasePart") then
                    local lower = string.lower(desc.Name)
                    if string.find(lower, "chest") then
                        local excluded = false
                        for _, kw in ipairs(excludedKeywords) do
                            if string.find(lower, kw) then excluded = true; break end
                        end

                        local parent = desc.Parent
                        while parent and parent ~= activeLevels do
                            if addedInstances[parent] then excluded = true; break end
                            parent = parent.Parent
                        end

                        if not excluded and isChestOnCooldown(desc) then excluded = true end

                        if not excluded then
                            local area = "Unknown Area"
                            local p = desc.Parent
                            while p and p ~= activeLevels do
                                if string.find(p.Name, "Level") or string.find(p.Name, "Area") then
                                    area = p.Name
                                    break
                                end
                                p = p.Parent
                            end

                            addedInstances[desc] = true
                            table.insert(chestData, { instance = desc, name = desc.Name, area = area })
                        end
                    end
                end
            end
        end

        local opts = {}
        for i, data in ipairs(chestData) do
            local s = string.format("[%s] %s (#%d)", data.area, data.name, i)
            table.insert(opts, s)
            ChestMapping[s] = data.instance
        end
        if #opts == 0 then
            table.insert(opts, "No Ready Chests Found")
            SelectedChestInstance = nil
        end
        if ChestDropdown then pcall(function() ChestDropdown:Refresh(opts) end) end
        return chestData
    end

    -- =============================================================
    -- PART 1 ENDS HERE — comment below says where Part 2 goes
    -- =============================================================
    warn("[AMC] Part 1 loaded OK — helpers + window built.")
end