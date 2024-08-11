local payphone_hits_tab = gui.get_tab("Payphone Hits")

local payphone_flow  = 2709088
local fmmc_variation = 2738934

local GSFV = 0x2AC4EC
local GPBL = 0x679D39
local GABS = 0x1DF7D3

local PAYPHONE_STATE_WAIT       = 0
local PAYPHONE_STATE_AVAILABLE  = 1
local PAYPHONE_STATE_ACTIVE     = 2
local PAYPHONE_STATE_LAUNCHING  = 3
local PAYPHONE_STATE_ON_MISSION = 4

local variation_names = {
    "The Tech Entrepreneur",
    "The Judge",
    "The Cofounder",
    "The CEO",
    "The Trolls",
    "The Popstar",
    "The Dealers",
    "The Hitmen"
}

local subvariation_names = {
    [0] = {
        "Ocean",
        "Car Crusher",
        "Gas Station"
    },
    [1] = {
        "Golf Club",
        "Golf Cart",
        "Remote Bomb"
    },
    [2] = {
        "Car on Fire",
        "Install Explosives",
        "Scoped Rifle"
    },
    [3] = {
        "Headshot",
        "7 minutes",
        "Run Over"
    },
    [4] = {
        "Throwable Explosives",
        "Drive-By",
        "After They Arrive"
    },
    [5] = {
        "Bulldozer",
        "Cargo Container",
        "Gas Tank Explosion"
    },
    [6] = {
        "Vagos Lowrider",
        "Police Cruiser",
        "Truck"
    },
    [7] = {
        "Scoped Rifle",
        "Suppressed Pistol",
        "Explosives"
    }
}

local selected_variation    = 0
local selected_subvariation = 0
local complete_bonus        = false

local payphone_state          = 0
local assassination_bonus_str = ""

local function get_subvariation_for_variation()
    local subvariation_start = scr_function.call_script_function("freemode", GSFV, "int", {
        { "int", 262 }, -- FMMC_TYPE_PAYPHONE
        { "int", selected_variation }
    })
    return subvariation_start + selected_subvariation
end

-- TO-DO: This sometimes returns a different bonus than the subvariation we choose. Figure out why.
local function get_assassination_bonus_str()
    if not script.is_active("fm_content_payphone_hit") then
        return "N/A"
    end
    
    local gxt = scr_function.call_script_function("fm_content_payphone_hit", GABS, "string", {}) -- TO-DO: Do not call this every frame (or do?)
    return HUD.GET_FILENAME_FOR_AUDIO_CONVERSATION(gxt) -- TO-DO: Figure out how the script gets the value for ~1~
end

script.register_looped("Payphone Hits", function()
    payphone_state          = globals.get_int(payphone_flow)
    assassination_bonus_str = get_assassination_bonus_str()
    
    if complete_bonus then
        local value = locals.get_int("fm_content_payphone_hit", 5675 + 740 + 1) | (1 << 1)
        locals.set_int("fm_content_payphone_hit", 5675 + 740 + 1, value)
    end
end)

payphone_hits_tab:add_imgui(function()
    selected_variation, used = ImGui.Combo("Select Variation", selected_variation, variation_names, #variation_names)
    if used then
        selected_subvariation = 0
    end
    
    selected_subvariation = ImGui.Combo("Select Subvariation", selected_subvariation, subvariation_names[selected_variation], #subvariation_names[selected_variation])
    
    if ImGui.Button("Request Payphone Hit") then
        script.run_in_fiber(function()
            if payphone_state == PAYPHONE_STATE_WAIT then
                globals.set_int(fmmc_variation + 5249 + 347, selected_variation)
                globals.set_int(fmmc_variation + 5249 + 348, get_subvariation_for_variation())
                local value = globals.get_int(payphone_flow + 1 + 1) | (1 << 0)
                globals.set_int(payphone_flow + 1 + 1, value)
            else
                gui.show_error("Payphone Hits", "A payphone hit mission is already active.")
            end
        end)
    end
    
    ImGui.SameLine()
    
    -- TO-DO: This mostly teleports us to a buggy location, consider adding some offset
    if ImGui.Button("Teleport to Payphone") then
        script.run_in_fiber(function()
            if payphone_state == PAYPHONE_STATE_ACTIVE then
                local coords = scr_function.call_script_function("freemode", GPBL, "vector3", {})
                PED.SET_PED_COORDS_KEEP_VEHICLE(self.get_ped(), coords.x, coords.y, coords.z)
            else
                gui.show_error("Payphone Hits", "No active payphone hit.")
            end
        end)
    end
    
    if ImGui.Button("Skip Cooldown") then
        script.run_in_fiber(function()
            local cooldown = stats.get_int("MPX_PAYPHONE_HIT_CDTIMER")
            local epoch    = NETWORK.GET_CLOUD_TIME_AS_INT()
            if epoch < cooldown then
                stats.set_int("MPX_PAYPHONE_HIT_CDTIMER", epoch - 1000)
            end
        end)
    end
    
    ImGui.Text("Assassination Bonus: " .. assassination_bonus_str)
    
    complete_bonus = ImGui.Checkbox("Always Complete Bonus", complete_bonus)
end)