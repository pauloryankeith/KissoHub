-- =================================================================
-- KissoHub — Anime Monster Collector
-- =================================================================
return function(KissoCore)
    local Rayfield          = KissoCore.Rayfield
    local ASSET_ICON        = KissoCore.ASSET_ICON
    local SessionStartTime  = KissoCore.SessionStartTime

    local Players     = game:GetService("Players")
    local Workspace   = game:GetService("Workspace")
    local LocalPlayer = Players.LocalPlayer

    -- =============================================================
    -- WINDOW + TAGS + NOTIFICATION HELPERS
    -- =============================================================
    local Window = KissoCore.BuildWindow("Anime Monster Collector", "AMCPrefs")
    local StatusTag, StateTag, SetActivity = KissoCore.BuildTags(Window)
    local SafeNotify = function(t, c, d) KissoCore.SafeNotify(Window, t, c, d) end
    local QuickToast = function(t, s) KissoCore.QuickToast(Window, t, s) end

    -- =============================================================
    -- STATE VARIABLES
    -- =============================================================
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

    -- =============================================================
    -- HELPERS: SPIRITS
    -- =============================================================
    local function getSpiritName(spirit)
        local spiritNameObj = spirit:FindFirstChild("SpiritName", true)
        if spiritNameObj then
            if spiritNameObj:IsA("TextLabel") or spiritNameObj:IsA("TextBox") then
                if spiritNameObj.Text ~= "" then return spiritNameObj.Text end
            elseif spiritNameObj:IsA("StringValue") or spiritNameObj:IsA("ValueBase") then
                if tostring(spiritNameObj.Value) ~= "" then return tostring(spiritNameObj.Value) end
            end
        end
        return spirit.Name
    end

    local function getSpiritLevel(spirit)
        local spiritLevelObj = spirit:FindFirstChild("SpiritLevel", true)
        if spiritLevelObj then
            if spiritLevelObj:IsA("TextLabel") or spiritLevelObj:IsA("TextBox") then
                local text = spiritLevelObj.Text
                local extractedNumber = tonumber(string.match(text, "%d+"))
                if extractedNumber then return extractedNumber end
                if text ~= "" then return text end
            elseif spiritLevelObj:IsA("ValueBase") then
                return tonumber(spiritLevelObj.Value) or spiritLevelObj.Value
            end
        end

        local attrLevel = spirit:GetAttribute("Level") or spirit:GetAttribute("Lvl")
        if attrLevel then return tonumber(attrLevel) or attrLevel end

        return 0
    end

    local function getSpiritMaxHP(spirit)
        local maxHp = spirit:GetAttribute("MaxHP") or spirit:GetAttribute("MaxHealth") or 0
        if maxHp == 0 then
            local hum = spirit:FindFirstChildOfClass("Humanoid") or spirit:FindFirstChildWhichIsA("Humanoid", true)
            if hum then maxHp = hum.MaxHealth end
        end
        if maxHp == 0 then
            local hpObj = spirit:FindFirstChild("MaxHP", true) or spirit:FindFirstChild("MaxHealth", true) or spirit:FindFirstChild("Health", true)
            if hpObj and hpObj:IsA("ValueBase") then maxHp = hpObj.Value end
        end
        return tonumber(maxHp) or 0
    end

    -- =============================================================
    -- HELPERS: CHESTS
    -- =============================================================
    local function isChestOnCooldown(chest)
        local statusUI = chest:FindFirstChild("ClientComponent_ChestRewardStatus", true)
        if statusUI then
            local cooldownGui = statusUI:FindFirstChild("CooldownGui", true) or statusUI:FindFirstChild("Cooldown", true)
            if cooldownGui then
                if cooldownGui:IsA("BillboardGui") or cooldownGui:IsA("SurfaceGui") or cooldownGui:IsA("ScreenGui") then
                    return cooldownGui.Enabled
                elseif cooldownGui:IsA("GuiObject") then
                    return cooldownGui.Visible
                end
                return true
            end
        end

        local cdDirect = chest:FindFirstChild("CooldownGui", true)
        if cdDirect then
            if cdDirect:IsA("BillboardGui") or cdDirect:IsA("SurfaceGui") or cdDirect:IsA("ScreenGui") then
                return cdDirect.Enabled
            elseif cdDirect:IsA("GuiObject") then
                return cdDirect.Visible
            end
            return true
        end

        return false
    end

    local function refreshChestList(ChestDropdown)
        local activeLevels = workspace:FindFirstChild("ActiveLevels")
        local chestData = {}
        ChestMapping = {}

        if activeLevels then
            local excludedKeywords = {"button", "frame", "ui", "gui", "icon", "prompt", "label", "text", "template", "holder", "close", "open"}
            local addedInstances = {}

            for _, desc in ipairs(activeLevels:GetDescendants()) do
                if desc:IsA("Model") or desc:IsA("BasePart") then
                    local lowerName = string.lower(desc.Name)

                    if string.find(lowerName, "chest") then
                        local isExcluded = false

                        for _, kw in ipairs(excludedKeywords) do
                            if string.find(lowerName, kw) then
                                isExcluded = true
                                break
                            end
                        end

                        local parent = desc.Parent
                        while parent and parent ~= activeLevels do
                            if addedInstances[parent] then
                                isExcluded = true
                                break
                            end
                            parent = parent.Parent
                        end

                        if not isExcluded and isChestOnCooldown(desc) then
                            isExcluded = true
                        end

                        if not isExcluded then
                            local levelName = "Unknown Area"
                            local p = desc.Parent
                            while p and p ~= activeLevels do
                                if string.find(p.Name, "Level") or string.find(p.Name, "Area") then
                                    levelName = p.Name
                                    break
                                end
                                p = p.Parent
                            end

                            addedInstances[desc] = true
                            table.insert(chestData, {
                                instance = desc,
                                name = desc.Name,
                                area = levelName
                            })
                        end
                    end
                end
            end
        end

        local dropdownOptions = {}
        for i, data in ipairs(chestData) do
            local displayString = string.format("[%s] %s (#%d)", data.area, data.name, i)
            table.insert(dropdownOptions, displayString)
            ChestMapping[displayString] = data.instance
        end

        if #dropdownOptions == 0 then
            table.insert(dropdownOptions, "No Ready Chests Found")
            SelectedChestInstance = nil
        end

        if ChestDropdown then
            pcall(function() ChestDropdown:Refresh(dropdownOptions) end)
        end

        return chestData
    end

    -- =============================================================
    -- HOME TAB (from core)
    -- =============================================================
    local HomeTab, HomeStats = KissoCore.BuildHomeTab(Window, "Anime Monster Collector")

    -- =============================================================
    -- SPIRITS TAB
    -- =============================================================
    local SpiritsTab = Window:CreateTab({ name = "👻 Spirits", icon = ASSET_ICON })
    SpiritsTab:CreateSection({ name = "🎯 Target Selection" })

    local SpiritDropdown

    local function refreshSpiritList()
        local folder = workspace:FindFirstChild("ActiveSpirits")
        local spiritData = {}
        SpiritMapping = {}

        if folder then
            for _, spirit in ipairs(folder:GetChildren()) do
                pcall(function()
                    local sName = getSpiritName(spirit)
                    local sLvl = getSpiritLevel(spirit)
                    local sMaxHp = getSpiritMaxHP(spirit)

                    table.insert(spiritData, {
                        instance = spirit,
                        name = sName,
                        level = sLvl,
                        maxHp = sMaxHp,
                        rawId = spirit.Name
                    })
                end)
            end
        end

        if SelectedSortMethod == "Level (High to Low)" then
            table.sort(spiritData, function(a, b) return (tonumber(a.level) or 0) > (tonumber(b.level) or 0) end)
        elseif SelectedSortMethod == "Max HP (High to Low)" then
            table.sort(spiritData, function(a, b) return a.maxHp > b.maxHp end)
        elseif SelectedSortMethod == "Name (A-Z)" then
            table.sort(spiritData, function(a, b) return a.name < b.name end)
        end

        local dropdownOptions = {}
        for _, data in ipairs(spiritData) do
            local displayString = string.format("[%s] Lvl: %s | HP: %d (%s)", data.name, tostring(data.level), data.maxHp, data.rawId)
            table.insert(dropdownOptions, displayString)
            SpiritMapping[displayString] = data.instance
        end

        if #spiritData > 0 then
            if not SelectedSpiritInstance or not SelectedSpiritInstance.Parent then
                SelectedSpiritInstance = spiritData[1].instance
            end
        else
            table.insert(dropdownOptions, "No Spirits Found")
            SelectedSpiritInstance = nil
        end

        if SpiritDropdown then
            pcall(function() SpiritDropdown:Refresh(dropdownOptions) end)
        end

        return spiritData
    end

    SpiritsTab:CreateDropdown({
        name = "Sort Method",
        flag = "SortDropdown",
        options = {"Level (High to Low)", "Max HP (High to Low)", "Name (A-Z)"},
        value = {"Level (High to Low)"},
        multiSelect = false,
        callback = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            SelectedSortMethod = choice
            refreshSpiritList()
        end,
    })

    SpiritDropdown = SpiritsTab:CreateDropdown({
        name = "Select Spirit",
        flag = "SpiritSelectDropdown",
        options = {"Click Refresh Below"},
        value = {"Click Refresh Below"},
        multiSelect = false,
        callback = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            SelectedSpiritInstance = SpiritMapping[choice]
        end,
    })

    SpiritsTab:CreateButton({
        name = "🔄 Refresh Spirit List",
        callback = function()
            local list = refreshSpiritList()
            SafeNotify("Spirits Refreshed", "Found " .. tostring(#list) .. " spirit(s).", 2)
        end,
    })

    SpiritsTab:CreateButton({
        name = "📍 Teleport to Selected Spirit",
        callback = function()
            if not SelectedSpiritInstance or not SelectedSpiritInstance.Parent then
                SafeNotify("Teleport Failed", "Selected spirit no longer exists. Please refresh!", 3)
                return
            end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local targetCFrame
            if SelectedSpiritInstance:IsA("Model") then
                local part = SelectedSpiritInstance.PrimaryPart or SelectedSpiritInstance:FindFirstChildWhichIsA("BasePart", true)
                if part then targetCFrame = part.CFrame end
            elseif SelectedSpiritInstance:IsA("BasePart") then
                targetCFrame = SelectedSpiritInstance.CFrame
            end

            if targetCFrame then
                hrp.CFrame = targetCFrame * CFrame.new(0, 3, 0)
                QuickToast("Teleported", "Moved to selected spirit")
            end
        end,
    })

    SpiritsTab:CreateDivider({ text = "automation" })
    SpiritsTab:CreateSection({ name = "🔄 Auto Tracking" })

    SpiritsTab:CreateToggle({
        name = "Auto Lock & TP to Spirit",
        flag = "AutoLockSpiritToggle",
        value = false,
        callback = function(Value)
            AutoLockSpiritEnabled = Value
            if AutoLockSpiritEnabled then
                SetActivity(true, "TRACKING")
                QuickToast("Auto Lock", "Started tracking")
                task.spawn(function()
                    while AutoLockSpiritEnabled do
                        if not SelectedSpiritInstance or not SelectedSpiritInstance.Parent then
                            refreshSpiritList()
                        end

                        local target = SelectedSpiritInstance
                        if target and target.Parent then
                            local char = LocalPlayer.Character
                            local hrp = char and char:FindFirstChild("HumanoidRootPart")
                            if hrp then
                                local targetCFrame
                                if target:IsA("Model") then
                                    local part = target.PrimaryPart or target:FindFirstChildWhichIsA("BasePart", true)
                                    if part then targetCFrame = part.CFrame end
                                elseif target:IsA("BasePart") then
                                    targetCFrame = target.CFrame
                                end

                                if targetCFrame then
                                    hrp.CFrame = targetCFrame * CFrame.new(0, 3, 0)
                                end
                            end
                        end
                        task.wait(0.05)
                    end
                end)
            end
        end,
    })

    -- =============================================================
    -- CHESTS TAB
    -- =============================================================
    local ChestsTab = Window:CreateTab({ name = "📦 Chests", icon = ASSET_ICON })
    ChestsTab:CreateSection({ name = "🎯 Target Selection" })

    local ChestDropdown

    ChestDropdown = ChestsTab:CreateDropdown({
        name = "Select Chest",
        flag = "ChestSelectDropdown",
        options = {"Click Refresh Below"},
        value = {"Click Refresh Below"},
        multiSelect = false,
        callback = function(Option)
            local choice = typeof(Option) == "table" and Option[1] or Option
            SelectedChestInstance = ChestMapping[choice]
        end,
    })

    ChestsTab:CreateButton({
        name = "🔄 Refresh Chest List",
        callback = function()
            local data = refreshChestList(ChestDropdown)
            SafeNotify("Chests Refreshed", "Found " .. tostring(#data) .. " ready chest(s) (Cooldowns excluded).", 2)
        end,
    })

    ChestsTab:CreateButton({
        name = "📍 Teleport to Selected Chest",
        callback = function()
            if not SelectedChestInstance or not SelectedChestInstance.Parent then
                SafeNotify("Teleport Failed", "Selected chest no longer exists or is on cooldown!", 3)
                return
            end

            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local targetCFrame
            if SelectedChestInstance:IsA("Model") then
                local part = SelectedChestInstance.PrimaryPart or SelectedChestInstance:FindFirstChildWhichIsA("BasePart", true)
                if part then targetCFrame = part.CFrame end
            elseif SelectedChestInstance:IsA("BasePart") then
                targetCFrame = SelectedChestInstance.CFrame
            end

            if targetCFrame then
                hrp.CFrame = targetCFrame * CFrame.new(0, 3, 0)
                QuickToast("Teleported", "Moved to selected chest")
            end
        end,
    })

    ChestsTab:CreateDivider({ text = "automation" })
    ChestsTab:CreateSection({ name = "🔄 Auto Collect" })

    ChestsTab:CreateToggle({
        name = "Auto Open All Chests",
        flag = "AutoOpenChestsToggle",
        value = false,
        callback = function(Value)
            AutoOpenChestsEnabled = Value
            if AutoOpenChestsEnabled then
                SetActivity(true, "FARMING")
                QuickToast("Auto Open", "Started opening chests")
                task.spawn(function()
                    while AutoOpenChestsEnabled do
                        local availableChests = refreshChestList(ChestDropdown)

                        if #availableChests == 0 then
                            task.wait(3)
                        else
                            for _, chestData in ipairs(availableChests) do
                                if not AutoOpenChestsEnabled then break end

                                local chestObj = chestData.instance
                                if chestObj and chestObj.Parent and not isChestOnCooldown(chestObj) then
                                    local char = LocalPlayer.Character
                                    local hrp = char and char:FindFirstChild("HumanoidRootPart")

                                    if hrp then
                                        local targetCFrame
                                        if chestObj:IsA("Model") then
                                            local part = chestObj.PrimaryPart or chestObj:FindFirstChildWhichIsA("BasePart", true)
                                            if part then targetCFrame = part.CFrame end
                                        elseif chestObj:IsA("BasePart") then
                                            targetCFrame = chestObj.CFrame
                                        end

                                        if targetCFrame then
                                            hrp.CFrame = targetCFrame * CFrame.new(0, 3, 0)
                                            task.wait(0.3)

                                            local prompt = chestObj:FindFirstChildWhichIsA("ProximityPrompt", true)
                                            if prompt then
                                                pcall(function()
                                                    fireproximityprompt(prompt)
                                                end)
                                            end
                                            task.wait(0.8)
                                        end
                                    end
                                end
                            end
                        end
                        task.wait(1)
                    end
                end)
            end
        end,
    })

    -- =============================================================
    -- MISC TAB
    -- =============================================================
    local MiscTab = Window:CreateTab({ name = "🛠️ Misc", icon = ASSET_ICON })

    MiscTab:CreateSection({ name = "🚀 Movement" })

    MiscTab:CreateSlider({
        name = "Walk Speed",
        flag = "WalkSpeedSlider",
        range = {16, 300},
        increment = 1,
        value = 16,
        suffix = " Speed",
        callback = function(Value)
            WalkSpeedValue = Value
            local char = LocalPlayer.Character
            if char and char:FindFirstChildOfClass("Humanoid") then
                char:FindFirstChildOfClass("Humanoid").WalkSpeed = Value
            end
        end,
    })

    -- Walk Speed Keeper Loop (bypasses game resets)
    task.spawn(function()
        while true do
            task.wait(0.1)
            if WalkSpeedValue ~= 16 then
                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                if hum and hum.WalkSpeed ~= WalkSpeedValue then
                    hum.WalkSpeed = WalkSpeedValue
                end
            end
        end
    end)

    MiscTab:CreateDivider({ text = "camera" })
    MiscTab:CreateSection({ name = "🎥 Camera" })

    MiscTab:CreateToggle({
        name = "Infinite Zoom Out",
        flag = "InfZoomToggle",
        value = false,
        callback = function(Value)
            InfZoomEnabled = Value
            if InfZoomEnabled then
                LocalPlayer.CameraMaxZoomDistance = 100000
            else
                LocalPlayer.CameraMaxZoomDistance = 128
            end
        end,
    })

    -- Zoom Enforcer Loop
    task.spawn(function()
        while true do
            task.wait(0.5)
            if InfZoomEnabled then
                if LocalPlayer.CameraMaxZoomDistance ~= 100000 then
                    LocalPlayer.CameraMaxZoomDistance = 100000
                end
            end
        end
    end)

    MiscTab:CreateDivider({ text = "safety" })
    MiscTab:CreateSection({ name = "🛡️ Protection" })

    MiscTab:CreateToggle({
        name = "Anti Fall Void",
        flag = "AntiVoidToggle",
        value = false,
        callback = function(Value)
            AntiVoidEnabled = Value
            if AntiVoidEnabled then
                QuickToast("Anti-Void", "Enabled")
                task.spawn(function()
                    while AntiVoidEnabled do
                        local char = LocalPlayer.Character
                        local hrp = char and char:FindFirstChild("HumanoidRootPart")
                        if hrp then
                            local voidHeight = workspace.FallenPartsDestroyHeight + 50
                            if hrp.Position.Y < voidHeight or hrp.Position.Y < -200 then
                                hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                                hrp.CFrame = hrp.CFrame + Vector3.new(0, 300, 0)
                                SafeNotify("Anti-Void Triggered", "Prevented falling into the void!", 2)
                            end
                        end
                        task.wait(0.3)
                    end
                end)
            end
        end,
    })

    -- =============================================================
    -- LIVE REFRESH (updates Home tab + state tag)
    -- =============================================================
    KissoCore.StartLiveRefresh(HomeStats, function()
        local count = 0
        if AutoLockSpiritEnabled then count += 1 end
        if AutoOpenChestsEnabled then count += 1 end
        if InfZoomEnabled then count += 1 end
        if AntiVoidEnabled then count += 1 end
        if WalkSpeedValue ~= 16 then count += 1 end

        if AutoLockSpiritEnabled then
            StateTag:Set({ text = "TRACKING", color = Color3.fromRGB(0, 200, 255) })
        elseif AutoOpenChestsEnabled then
            StateTag:Set({ text = "FARMING", color = Color3.fromRGB(0, 220, 130) })
        elseif count > 0 then
            StateTag:Set({ text = "ACTIVE", color = Color3.fromRGB(0, 220, 130) })
        else
            StateTag:Set({ text = "IDLE", color = Color3.fromRGB(190, 40, 220) })
        end

        return count
    end)
end
