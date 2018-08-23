-- Setup namespaces ---------------------------

local addOnName, Core = ...;

MayronUI = {};
MayronUI.RegisteredModules = {};
MayronUI.ModulesInitialized = false;

Core.Database = LibStub:GetLibrary("LibMayronDB"):CreateDatabase("MUIdb", addOnName);
Core.EventManager = LibStub:GetLibrary("LibMayronEvents");
Core.GUIBuilder = LibStub:GetLibrary("LibMayronGUI");
Core.Objects = LibStub:GetLibrary("LibMayronObjects");
Core.Locale = LibStub("AceLocale-3.0"):GetLocale("MayronUI");

local db = Core.Database;
local em = Core.EventManager;
local tk = Core.Toolkit;
local gui = Core.GUIBuilder;
local L = Core.Locale;

local Engine = Core.Objects:CreatePackage("Engine", "MayronUI");
local Module = Engine:CreateClass("Module");
local ModuleHiddenData = {}; -- we pass real module data to module functions

-- Add Default Database Values ----------------

db:AddToDefaults("global.Core", {
    uiScale = 0.7,
    change_game_font = true,
    font = "MUI_Font",
	use_localization = true,
    addons = {
        {"Aura Frames", true, "AuraFrames"},
        {"Bartender4", true, "Bartender4"},
        {"Grid", true, "Grid"},
        {"Masque", true, "Masque"},
        {"Mik Scrolling Battle Text", false, "MikScrollingBattleText"},
        {"Recount", true, "Recount"},
        {"Shadowed Unit Frames", true, "ShadowedUnitFrames"},
        {"TipTac", true, "TipTac"},
    }
});

local _, class = UnitClass("player");
db:AddToDefaults("profile.theme", {
    color = {
        r = tk.Constants.CLASS_RGB_COLORS[class].r,
        g = tk.Constants.CLASS_RGB_COLORS[class].g,
        b = tk.Constants.CLASS_RGB_COLORS[class].b,
        hex = tk.Constants.CLASS_RGB_COLORS[class].hex
    },
});

-- Slash Commands ------------------

Core.commands = {
	["config"] = function()
        if (not tk.IsAddOnLoaded("MUI_Config")) then
            EnableAddOn("MUI_Config");

            if (not tk.LoadAddOn("MUI_Config")) then
                tk:Print(L["Failed to load MUI_Config. Possibly missing?"]);
                return;
            end

            MayronUI:ImportModule("Config"):init();
        end

        MayronUI:ImportModule("Config"):Show();
	end,
	["install"] = function()
        if (not tk.IsAddOnLoaded("MUI_Setup")) then
            local success = tk.LoadAddOn("MUI_Setup");

            if (not success) then 
                return; 
            end
        end

        MayronUI:ImportModule("MUI_Setup"):Show();
	end,
	["help"] = function()
		tk.print(" ");
		tk:Print(L["List of slash commands:"])
		tk:Print("|cff00cc66/mui config|r - "..L["shows config menu"]);
		tk:Print("|cff00cc66/mui install|r - "..L["shows setup menu"]);
        tk.print(" ");
	end
};

-- Module Object -------------------

Engine:DefineReturns("string", "?boolean");
function Module:__Construct(data, moduleName, initializeOnDemand, injectedNamespace)
    local hiddenData = {};
    ModuleHiddenData[tostring(self)] = hiddenData;    
    hiddenData.moduleName = moduleName;
    hiddenData.initializeOnDemand = initializeOnDemand;
    hiddenData.initialized = false;
    hiddenData.enabled = false;

    if (injectedNamespace) then
        Core.Objects:CopyTableValues(injectedNamespace, data, 1);

        for key, value in pairs(injectedNamespace) do
            data[key] = value;
        end
    end
end

Engine:DefineReturns("string");
function Module:GetModuleName(data)
    return ModuleHiddenData[tostring(self)].moduleName;
end

Engine:DefineParams("function");
function Module:OnInitialize(data, initializedCallback)
    ModuleHiddenData[tostring(self)].initializedCallback = initializedCallback;
end

function Module:Initialize(data, ...)
    local hiddenData = ModuleHiddenData[tostring(self)];   

    Core.Objects:Assert(hiddenData.initializedCallback, 
        "No initialized callback registered with module '%s'", hiddenData.moduleName);

    hiddenData.initializedCallback(self, data, ...);  
    hiddenData.initialized = true;
end

Engine:DefineReturns("boolean");
function Module:IsInitialized(data)
    return ModuleHiddenData[tostring(self)].initialized;
end

Engine:DefineReturns("boolean");
function Module:IsInitializedOnDemand(data)
    return ModuleHiddenData[tostring(self)].initializeOnDemand == true;
end

Engine:DefineParams("function");
function Module:OnEnable(data, enabledCallback)
    ModuleHiddenData[tostring(self)].enabledCallback = enabledCallback;
end

Engine:DefineParams("function");
function Module:OnDisable(data, disabledCallback)
    ModuleHiddenData[tostring(self)].disabledCallback = disabledCallback;
end

Engine:DefineParams("boolean");
function Module:SetEnabled(data, enabled, ...)   
    local hiddenData = ModuleHiddenData[tostring(self)];
    hiddenData.enabled = enabled;
    
    if (enabled) then
        Core.Objects:Assert(hiddenData.enabledCallback, "No enabled callback registered with module '%s'", moduleName);
        hiddenData.enabledCallback(self, data, ...);
    else
        Core.Objects:Assert(hiddenData.disabledCallback, "No disabled callback registered with module '%s'", moduleName);
        hiddenData.disabledCallback(self, data, ...);
    end
end

Engine:DefineReturns("boolean");
function Module:IsEnabled(data)
    return ModuleHiddenData[tostring(self)].enabled;
end

Engine:DefineParams("function");
function Module:OnConfigUpdate(data, configUpdateCallback)
    ModuleHiddenData[tostring(self)].configUpdateCallback = configUpdateCallback;
end

Engine:DefineParams("LinkedList", "any");
function Module:ConfigUpdate(data, linkedList, newValue)
    ModuleHiddenData[tostring(self)].configUpdateCallback(self, data, linkedList, newValue);
end

-- MayronUI Functions ---------------------

function MayronUI:ImportModule(moduleName)
    return self.RegisteredModules[moduleName];
end

-- @param (optional) initializeOnDemand - if true, must be initialized manually instead of 
--   MayronUI automatically initializing module during PLAYER_ENTERING_WORLD event
function MayronUI:RegisterModule(moduleName, initializeOnDemand, injectedNamespace)
    local SubModuleClass = Engine:CreateClass(moduleName, Module);
    local subModuleInstance = SubModuleClass();

    subModuleInstance:Super(moduleName, initializeOnDemand, injectedNamespace); -- call parent constructor
    
    -- Make it easy to search for
    self.RegisteredModules[moduleName] = subModuleInstance;
    table.insert(self.RegisteredModules, subModuleInstance);

    return subModuleInstance, SubModuleClass;
end

function MayronUI:IterateModules()
    local id = 0;
    
	return function()
		id = id + 1;
		if (id <= #self.RegisteredModules) then
			return id, self.RegisteredModules[id];
		end
	end
end

function MayronUI:IsInstalled()
	return db.global.installed and db.global.installed[tk:GetPlayerKey()];
end

-- Register MUICore Module ---------------------

local MUICoreModule, MUICore = MayronUI:RegisterModule("MUI_Core");

MUICoreModule:OnInitialize(function() 
    for i = 1, NUM_CHAT_WINDOWS do
        tk._G["ChatFrame"..i.."EditBox"]:SetAltArrowKeyMode(false);
    end

    tk._G["SLASH_MUI1"] = "/mui";
	SlashCmdList.MUI = function(str)
        local args = {};
        
		if (#str == 0) then
			Core.commands.help();
			return;
        end
        
		for _, arg in tk:IterateArgs(tk.string.split(' ', str)) do
			if (#arg > 0) then
                tk.table.insert(args, arg);
			end
        end
        
        local path = Core.commands;
        
		for id, arg in tk.ipairs(args) do
            arg = tk.string.lower(arg);
            
			if (path[arg]) then
				if (tk.type(path[arg]) == "function") then
					path[arg](tk.select(id + 1, tk.unpack(args)));
                    return;
                    
				elseif (tk.type(path[arg]) == "table") then
                    path = path[arg];
                    
				else
					Core.commands.help();
                    return;
                    
				end
			else
				Core.commands.help();
                return;
                
			end
		end
    end
    
    tk:Print(L["Welcome back"], UnitName("player").."!");
end);

-- MUICore Object -----------------------

function MUICore:GetDatabase()
    return Core.Database;
end

function MUICore:GetToolkit()
    return Core.Toolkit;
end

-- Initialize Modules -------------------

em:CreateEventHandler("PLAYER_ENTERING_WORLD", function()
    FillLocalizedClassList(tk.Constants.LOCALIZED_CLASS_NAMES);    

    if (not MayronUI:IsInstalled()) then
        if ((tk.select(1, tk.LoadAddOn("MUI_Setup")))) then
            MayronUI:ImportModule("MUI_Setup"):Initialize();
        end

		return;
    else
        for id, module in MayronUI:IterateModules() do
            local initializeOnDemand = module:IsInitializedOnDemand();

            if (not initializeOnDemand) then
                module:Initialize();
            end            
        end  
        
        if (tk.IsAddOnLoaded("Recount")) then
            if (db.global.reanchor) then
                Recount_MainWindow:ClearAllPoints();
                Recount_MainWindow:SetPoint("BOTTOMRIGHT", -2, 2);
                Recount_MainWindow:SaveMainWindowPosition();
            end

            gui:CreateDialogBox(tk.Constants.AddOnStyle, nil, "LOW", Recount_MainWindow);
            Recount_MainWindow:SetClampedToScreen(true);
            Recount_MainWindow.tl:SetPoint("TOPLEFT", -6, -5);
            Recount_MainWindow.tr:SetPoint("TOPRIGHT", 6, -5);
        end

        db.global.reanchor = nil;
    end

    Core:SetupOrderHallBar();
    MayronUI.ModulesInitialized = true;
    tk.collectgarbage("collect");

end):SetAutoDestroy(true);

db:OnStart(function(self)
    MayronUI.db = self;
    local r, g, b = tk:GetThemeColor();
    local myFont = tk.CreateFont("MUI_FontNormal");

    myFont:SetFontObject("GameFontNormal");
    myFont:SetTextColor(r, g, b);
    myFont = tk.CreateFont("MUI_FontSmall");
    myFont:SetFontObject("GameFontNormalSmall");
    myFont:SetTextColor(r, g, b);
    myFont = tk.CreateFont("MUI_FontLarge");
    myFont:SetFontObject("GameFontNormalLarge");
    myFont:SetTextColor(r, g, b);

    -- To keep UI widget styles consistent ----------
    -- Can only use once Database is loaded...

    local Style = Core.Objects:Import("MUI_Core.Widgets.Style");

    tk.Constants.AddOnStyle = Style();
    -- tk.Constants.AddOnStyle:EnableColorUpdates();
    tk.Constants.AddOnStyle:SetBackdrop(tk.Constants.backdrop, "DropDownMenu");
    tk.Constants.AddOnStyle:SetBackdrop(tk.Constants.backdrop, "ButtonBackdrop");
    tk.Constants.AddOnStyle:SetTexture(tk.Constants.MEDIA.."mui_bar", "ButtonTexture");
    tk.Constants.AddOnStyle:SetTexture(tk.Constants.MEDIA.."reskin\\arrow_down", "ArrowButtonTexture")
    tk.Constants.AddOnStyle:SetTexture(tk.Constants.MEDIA.."dialog_box\\Texture-", "DialogBoxBackground");
    tk.Constants.AddOnStyle:SetTexture(tk.Constants.MEDIA.."dialog_box\\TitleBar", "TitleBarBackground");
    tk.Constants.AddOnStyle:SetTexture(tk.Constants.MEDIA.."dialog_box\\CloseButton", "CloseButtonBackground");
    tk.Constants.AddOnStyle:SetColor(r, g, b);

    -- Load Media using LibSharedMedia --------------

    local media = tk.Constants.LSM;

    media:Register(media.MediaType.FONT, "MUI_Font", tk.Constants.MEDIA.."font\\mui_font.ttf");
    media:Register(media.MediaType.FONT, "Imagine", tk.Constants.MEDIA.."font\\imagine.ttf");
    media:Register(media.MediaType.FONT, "Prototype", tk.Constants.MEDIA.."font\\prototype.ttf");
    media:Register(media.MediaType.STATUSBAR, "MUI_StatusBar", tk.Constants.MEDIA.."mui_bar.tga");
    media:Register(media.MediaType.BORDER, "Skinner", tk.Constants.MEDIA.."borders\\skinner.tga");
    media:Register(media.MediaType.BORDER, "Glow", tk.Constants.MEDIA.."borders\\glow.tga");

    -- Set Master Game Font Here! -------------------

    if (self.global.Core.change_game_font ~= false) then
        tk:SetGameFont(media:Fetch("font", self.global.Core.font));
    end
end);