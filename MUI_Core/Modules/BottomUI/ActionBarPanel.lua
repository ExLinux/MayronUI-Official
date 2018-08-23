-- Setup Namespaces ----------------------

local addOnName, Core = ...;
local em = Core.EventManager;
local tk = Core.Toolkit;
local db = Core.Database;
local gui = Core.GUIBuilder;
local L = Core.Locale;
local obj = Core.Objects;

-- Register and Import Modules -----------

local ActionBarPanelModule, ActionBarPanel = MayronUI:RegisterModule("BottomUI_ActionBarPanel", true);
local SlideController = gui.WidgetsPackage:Get("SlideController");

-- Load Database Defaults ----------------

db:AddToDefaults("profile.actionBarPanel", {
    enabled = true,
    expanded = false,
    modKey = "C",
    retractHeight = 44,
    expandHeight = 80,
    animateSpeed = 6,
    alpha = 1,
    texture = tk.Constants.MEDIA.."bottom_ui\\actionbar_panel",

    -- second row (both bar 9 and 10 are used to make the 2nd row (20 buttons)
    bartender = {
        control = true,
        [1] = "Bar 1",
        [2] = "Bar 7",
        [3] = "Bar 9",
        [4] = "Bar 10",
    }
});

-- Local Functions -----------------------

local function LoadTutorial(panel)
    local frame = tk:PopFrame("Frame", panel);

    frame:SetFrameStrata("TOOLTIP");
    frame:SetSize(250, 130);
    frame:SetPoint("BOTTOM", panel, "TOP", 0, 100);

    gui:CreateDialogBox(tk.Constants.AddOnStyle, nil, nil, frame);
    gui:AddCloseButton(tk.Constants.AddOnStyle, frame);
    gui:AddArrow(tk.Constants.AddOnStyle, frame, "DOWN");

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight");
    frame.text:SetWordWrap(true);
    frame.text:SetPoint("TOPLEFT", 10, -20);
    frame.text:SetPoint("BOTTOMRIGHT", -10, 10);
    frame.text:SetText(
        "Press and hold the "..tk:GetThemeColoredText("Control").." key while out of "..
                "combat to show the "..tk:GetThemeColoredText("Expand").." button.\n\n"..
                "Click the Expand button to show a second row of action buttons!"
    );
   
    em:CreateEventHandler("MODIFIER_STATE_CHANGED", function(self)
        if (tk:IsModComboActive("C")) then
            frame.text:SetText(
                "Once expanded, you can press and hold the same key while out of "..
                        "combat to show the "..tk:GetThemeColoredText("Retract").." button.\n\n"..
                        "Pressing this will hide the second row of action buttons."
            );

            if (not frame:IsShown()) then
                tk.UIFrameFadeIn(frame, 0.5, 0, 1);
                frame:Show();
            end

            db.global.tutorial = nil;
            self:Destroy();
        end
    end);
end

local function ToggleBartenderBar(btBar, show, bartenderControl)
    if (tk.IsAddOnLoaded("Bartender4") and bartenderControl) then
        btBar:SetConfigAlpha((show and 1) or 0);
        btBar:SetVisibilityOption("always", not show);
    end
end

local FadeBarsIn_Counter = 0;

local function FadeBarsIn(bartenderControl)
    if (not (tk.IsAddOnLoaded("Bartender4") and bartenderControl)) then 
        return;
     end

     FadeBarsIn_Counter = FadeBarsIn_Counter + 1;

    if (FadeBarsIn_Counter > 6) then
        ToggleBartenderBar(ActionBarBTBar3, true, bartenderControl);
        ToggleBartenderBar(ActionBarBTBar4, true, bartenderControl);
        tk.UIFrameFadeIn(ActionBarBTBar3, 0.3, 0, 1);
        tk.UIFrameFadeIn(ActionBarBTBar4, 0.3, 0, 1);
    else
        tk.C_Timer.After(0.02, FadeBarsIn);
    end
end

-- ActionBarPanel Module ----------------- 

ActionBarPanelModule:OnInitialize(function(self, data, buiContainer, subModules)
    data.sv = db.profile.actionBarPanel;
    data.bartenderControl = data.sv.bartender.control;
    data.buiContainer = buiContainer;
    data.ResourceBars = subModules.ResourceBars;
    data.DataText = subModules.DataText;

    if (data.sv.enabled) then
        self:SetEnabled(true);
    end    
end);

ActionBarPanelModule:OnEnable(function(self, data)
    if (data.panel) then 
        return; 
    end

    local barsContainer = data.ResourceBars:GetBarContainer();
    data.panel = tk.CreateFrame("Frame", "MUI_ActionBarPanel", data.buiContainer);    
    data.panel:SetPoint("BOTTOMLEFT", barsContainer, "TOPLEFT", 0, -1);
    data.panel:SetPoint("BOTTOMRIGHT", barsContainer, "TOPRIGHT", 0, -1);
    data.panel:SetFrameLevel(10);

    self:SetBartenderBars();

    if (data.sv.expanded) then
        data.panel:SetHeight(data.sv.expandHeight);
        ToggleBartenderBar(data.BTBar3, true, data.bartenderControl);
        ToggleBartenderBar(data.BTBar4, true, data.bartenderControl);
    else
        data.panel:SetHeight(data.sv.retractHeight);
        ToggleBartenderBar(data.BTBar3, false, data.bartenderControl);
        ToggleBartenderBar(data.BTBar4, false, data.bartenderControl);
    end

    data.slideController = SlideController(data.panel);
    data.slideController:SetMinHeight(data.sv.retractHeight);
    data.slideController:SetMaxHeight(data.sv.expandHeight);
    data.slideController:SetStepValue(data.sv.animateSpeed);

    data.slideController:OnEndRetract(function()
        ToggleBartenderBar(data.BTBar3, false, data.bartenderControl);
        ToggleBartenderBar(data.BTBar4, false, data.bartenderControl);
    end);

    gui:CreateGridTexture(data.panel, data.sv.texture, 20, nil, 749, 45);

    -- expand button:
    local expandBtn = gui:CreateButton(tk.Constants.AddOnStyle, data.panel, " ");
    expandBtn:SetFrameStrata("HIGH");
    expandBtn:SetFrameLevel(20);
    expandBtn:SetSize(140, 20);
    expandBtn:SetBackdrop(tk.Constants.backdrop);
    expandBtn:SetBackdropBorderColor(0, 0, 0);
    expandBtn:SetPoint("BOTTOM", data.panel, "TOP", 0, -1);
    expandBtn:Hide();

    local normalTexture = expandBtn:GetNormalTexture();
    normalTexture:ClearAllPoints();
    normalTexture:SetPoint("TOPLEFT", 1, -1);
    normalTexture:SetPoint("BOTTOMRIGHT", -1, 1);

    local highlightTexture = expandBtn:GetHighlightTexture();
    highlightTexture:ClearAllPoints();
    highlightTexture:SetPoint("TOPLEFT", 1, -1);
    highlightTexture:SetPoint("BOTTOMRIGHT", -1, 1);

    expandBtn.glow = expandBtn:CreateTexture(nil, "BACKGROUND");
    tk:SetThemeColor(expandBtn.glow);

    expandBtn.glow:SetTexture(tk.Constants.MEDIA.."bottom_ui\\glow");
    expandBtn.glow:SetSize(db.profile.bottomui.width, 60);
    expandBtn.glow:SetBlendMode("ADD");
    expandBtn.glow:SetPoint("BOTTOM", 0, 1);

    local group = expandBtn.glow:CreateAnimationGroup();
    group.a = group:CreateAnimation("Alpha");
    group.a:SetSmoothing("OUT");
    group.a:SetDuration(0.4);
    group.a:SetFromAlpha(0);
    group.a:SetToAlpha(1);
    group.a:SetStartDelay(0.1);
    group.a2 = group:CreateAnimation("Scale");
    group.a2:SetOrigin("BOTTOM", 0, 0);
    group.a2:SetDuration(0.4);
    group.a2:SetFromScale(0, 0);
    group.a2:SetToScale(1, 1);

    local group2 = expandBtn:CreateAnimationGroup();
    group2.a = group2:CreateAnimation("Alpha");
    group2.a:SetSmoothing("OUT");
    group2.a:SetDuration(0.4);
    group2.a:SetFromAlpha(0);
    group2.a:SetToAlpha(1);

    group:SetScript("OnFinished", function()
        expandBtn.glow:SetAlpha(1);
    end);

    expandBtn:SetScript("OnClick", function(self)
        self:Hide();

        if (tk.InCombatLockdown()) then 
            return; 
        end

        tk.PlaySound(tk.Constants.CLICK);

        if (data.sv.expanded) then
            data.slideController:Start(data.slideController.FORCE_RETRACT);

            if (tk.IsAddOnLoaded("Bartender4") and data.bartenderControl) then
                ToggleBartenderBar(data.BTBar3, true, data.bartenderControl);
                ToggleBartenderBar(data.BTBar4, true, data.bartenderControl);

                tk.UIFrameFadeOut(data.BTBar3, 0.1, 1, 0);
                tk.UIFrameFadeOut(data.BTBar4, 0.1, 1, 0);
            end
        else
            FadeBarsIn_Counter = 0;
            FadeBarsIn();
            data.slideController:Start(data.slideController.FORCE_EXPAND);
        end

        data.sv.expanded = not data.sv.expanded;
    end);

    group:SetScript("OnPlay", function()
        expandBtn.glow:SetAlpha(0);
        group2:Play();
    end);

    group2:SetScript("OnFinished", function()
        expandBtn:SetAlpha(1);
    end);

    group2:SetScript("OnPlay", function()
        expandBtn:Show();
        expandBtn:SetAlpha(0);
    end);

    em:CreateEventHandler("MODIFIER_STATE_CHANGED", function()
        if (not tk:IsModComboActive(data.sv.modKey) or tk.InCombatLockdown()) then
            expandBtn:Hide();
            return;
        end

        if (data.sv.expanded) then
            expandBtn:SetText("Retract");
        else
            expandBtn:SetText("Expand");
        end

        group:Stop();
        group2:Stop();
        group:Play();        
    end);

    em:CreateEventHandler("PLAYER_REGEN_DISABLED", function() 
        expandBtn:Hide(); 
    end);

    if (db.global.tutorial) then
        LoadTutorial(data.panel);        
    end
end);

-- ActionBarPanel Object ----------------------

function ActionBarPanel:GetPanel(data)
    return data.panel;
end

function ActionBarPanel:PositionBartenderBars(data)
    if (not (data.BTBar1 or data.BTBar2 or data.BTBar3 or data.BTBar4)) then 
        return; 
    end

    if (tk.IsAddOnLoaded("Bartender4") and data.bartenderControl) then
        local height = data.ResourceBars:GetHeight() +
                ((data.DataText:IsShown() and data.DataText:GetHeight()) or 0) - 3;

        data.BTBar1.config.position.y = 39 + height;
        data.BTBar2.config.position.y = 39 + height;
        data.BTBar3.config.position.y = 74 + height;
        data.BTBar4.config.position.y = 74 + height;
        data.BTBar1:LoadPosition();
        data.BTBar2:LoadPosition();
        data.BTBar3:LoadPosition();
        data.BTBar4:LoadPosition();
    end
end

function ActionBarPanel:SetBartenderBars(data)
    if (tk.IsAddOnLoaded("Bartender4") and data.bartenderControl) then

        local bar1 = data.sv.bartender[1]:match("%d+");
        local bar2 = data.sv.bartender[2]:match("%d+");
        local bar3 = data.sv.bartender[3]:match("%d+");
        local bar4 = data.sv.bartender[4]:match("%d+");

        Bartender4:GetModule("ActionBars"):EnableBar(bar1);
        Bartender4:GetModule("ActionBars"):EnableBar(bar2);
        Bartender4:GetModule("ActionBars"):EnableBar(bar3);
        Bartender4:GetModule("ActionBars"):EnableBar(bar4);

        data.BTBar1 = tk._G["BT4Bar"..tk.tostring(bar1)];
        data.BTBar2 = tk._G["BT4Bar"..tk.tostring(bar2)];
        data.BTBar3 = tk._G["BT4Bar"..tk.tostring(bar3)];
        data.BTBar4 = tk._G["BT4Bar"..tk.tostring(bar4)];

        ToggleBartenderBar(data.BTBar1, true, data.bartenderControl);
        ToggleBartenderBar(data.BTBar2, true, data.bartenderControl);

        self:PositionBartenderBars();
    end
end