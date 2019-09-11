--- Choose player to spectate GUI
-- SpectatorMode
--
-- @author TyKonKet
-- @date 23/12/2016
SpectateGui = {}
local SpectateGui_mt = Class(SpectateGui, ScreenElement)

SpectateGui.CONTROLS = {
    DIALOG_ELEMENT = "dialogElement",

    DIALOG_TITLE_ELEMENT = "dialogTitleElement",
    DIALOG_TEXT_ELEMENT = "dialogTextElement",
    SPECTABLE_USERS_ELEMENT = "spectableUsersElement",
    USERNAME = "userName",
    MESSAGE_BACKGROUND = "messageBackground",
    BUTTONS_PC = "buttonsPC",

	NO_BUTTON = "noButton",
	SPECTATE_BUTTON = "spectateButton"
}

function SpectateGui:new(isServer, isClient)
	local self = ScreenElement:new(target, SpectateGui_mt)

	self:registerControls(SpectateGui.CONTROLS)

    self.isServer = isServer
    self.isClient = isClient
	self.returnScreenName = ""
	self.selectedState = 1
	self.areButtonsDisabled = false

	return self
end

--TODO: Register inputbindings here?

function SpectateGui:onOpen()
	SpectateGui:superClass().onOpen(self)
	if self.areButtonsDisabled then
		FocusManager:setFocus(self.noButton)
	else
		FocusManager:setFocus(self.spectateButton)
	end
end

function SpectateGui:onClose()
	SpectateGui:superClass().onClose(self)
end

function SpectateGui:onClickActivate()
	SpectateGui:superClass().onClickActivate(self)
	if self.areButtonsDisabled then
		return
	end
	g_spectatorMode:startSpectate(self.selectedState)
	self.onClickBack(self)
end

function SpectateGui:onClickSpectableUsers(state)
	self.selectedState = state
end

function SpectateGui:setSpectableUsers(users) 
	if #users == 0 then
		self:setDisabled(true)
		self.messageBackground:setVisible(true)
		self.spectableUsersElement:setTexts({})
		self.spectableUsersElement:setState(0)
	else
		self:setDisabled(false)
		self.messageBackground:setVisible(false)
		self.users = users
		self.spectableUsersElement:setTexts(users)
		self.spectableUsersElement:setState(self.selectedState)
		self:onClickSpectableUsers(self.selectedState)
	end
end

function SpectateGui:setDisabled(disabled)
	self.areButtonsDisabled = disabled
	self.spectateButton:setDisabled(disabled)
	self.spectableUsersElement:setDisabled(disabled)
end
