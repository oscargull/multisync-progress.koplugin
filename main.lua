local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Device = require("device")
local Event = require("ui/event")
local Math = require("optmath")
local NetworkMgr = require("ui/network/manager")
local MultisyncSetup = require("ui")
local _ = require("gettext")

local Container = WidgetContainer:extend({
	name = "multisync-progress",
	is_doc_only = true,
})

function Container:init()
	self.settings = G_reader_settings:readSetting("multisync_progress", {})
	self.settings.servers = self.settings.servers or {}
	self.device_id = G_reader_settings:readSetting("device_id")
	MultisyncSetup:init(self)
	self.ui.menu:registerToMainMenu(self)
end

function Container:addToMainMenu(menu_items)
	MultisyncSetup:addToMainMenu(menu_items)
end

function Container:getLastPercent()
	if self.ui.document.info.has_pages then
		return Math.roundPercent(self.ui.paging:getLastPercent())
	end
	return Math.roundPercent(self.ui.rolling:getLastPercent())
end

function Container:getLastProgress()
	if self.ui.document.info.has_pages then
		return self.ui.paging:getLastProgress()
	end
	return self.ui.rolling:getLastProgress()
end

function Container:getDocumentDigest()
	return self.ui.doc_settings:readSetting("partial_md5_checksum")
end

function Container:getMetadata()
	local file_name = self:getFileName()
	local props = self.ui.doc_props
	return {
		filename = file_name,
		title = props.display_title,
		authors = props.authors,
	}
end

function Container:getFileName()
	local util = require("util")
	local file_path, file_name = util.splitFilePathName(self.ui.document.file)
	return file_name
end

function Container:syncToProgress(progress)
	if self.ui.document.info.has_pages then
		self.ui:handleEvent(Event:new("GotoPage", tonumber(progress)))
	else
		self.ui:handleEvent(Event:new("GotoXPointer", progress))
	end
end

function Container:canSync()
	return self.ui and self.ui.document and self.ui.document.file
end

function Container:ensureNetwork(callback)
	return not NetworkMgr:willRerunWhenOnline(callback)
end

return Container
