local WidgetContainer = require("ui/widget/container/widgetcontainer")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")

local Multisync = WidgetContainer:extend({
	name = "multisync-progress",
	is_doc_only = true,
})

function Multisync:init()
	self.ui.menu:registerToMainMenu(self)
end

function Multisync:addToMainMenu(menu_items)
	menu_items.multisync_progress = {
		sorting_hint = "progress_sync",
		text = _("Manage sync servers"),
		callback = function()
			UIManager:show(InfoMessage:new({
				text = _("Feature not implemented yet."),
			}))
		end,
	}
end

return Multisync
