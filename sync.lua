local Device = require("device")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")
local _ = require("gettext")
local T = require("ffi/util").template
local logger = require("logger")
local KOSyncClient = require("lib/KOSyncClient")

local Sync = {}

function Sync:new(container)
	local instance = setmetatable({}, self)
	self.__index = self
	instance.container = container
	return instance
end

function Sync:syncWithServer(server, direction)
	if not self.container:canSync() then
		UIManager:show(InfoMessage:new{
			text = _("Open a document before syncing progress."),
		})
		return
	end

	if not server.host or not server.username or not server.userkey then
		UIManager:show(InfoMessage:new{
			text = T(_("Server %1 is incomplete."), server.name),
		})
		return
	end

	if not self.container:ensureNetwork(function()
		self:syncWithServer(server, direction)
	end) then
		return
	end

	local client = KOSyncClient:new{
		custom_url = server.host,
		service_spec = self.container.path .. "/lib/api.json",
	}
	local document = self.container:getDocumentDigest()
	if not document then
		UIManager:show(InfoMessage:new{
			text = _("Document checksum is unavailable."),
		})
		return
	end

	local device = Device.model
	local device_id = self.container.device_id
	if direction == "push" then
		self:pushToServer(client, server, document, device, device_id)
	else
		self:pullFromServer(client, server, document)
	end
end

function Sync:pushToServer(client, server, document, device, device_id)
	local ok, err = pcall(client.update_progress,
		client,
		server.username,
		server.userkey,
		document,
		self.container:getMetadata(),
		self.container:getLastProgress(),
		self.container:getLastPercent(),
		device,
		device_id,
		function(ok, status, body)
			logger.dbg("Multisync: push result", server.name, ok, status, body)
			UIManager:show(InfoMessage:new{
				text = ok and T(_("Progress pushed to %1."), server.name)
					or T(_("Could not push progress to %1."), server.name),
				timeout = 3,
			})
		end)
	if not ok then
		logger.warn("Multisync: push failed for", server.name, err)
		UIManager:show(InfoMessage:new{
			text = T(_("Could not push progress to %1."), server.name),
		})
	end
end

function Sync:pullFromServer(client, server, document)
	local ok, err = pcall(client.get_progress,
		client,
		server.username,
		server.userkey,
		document,
		function(ok, body)
			logger.dbg("Multisync: pull result", server.name, ok, body)
			if not ok or not body then
				UIManager:show(InfoMessage:new{
					text = T(_("Could not pull progress from %1."), server.name),
			})
			return
			end

			if not body.percentage then
				UIManager:show(InfoMessage:new{
					text = T(_("No progress found on %1 for this document."), server.name),
					timeout = 3,
			})
			return
			end

			if body.progress == self.container:getLastProgress() then
				UIManager:show(InfoMessage:new{
					text = _("The progress has already been synchronized."),
					timeout = 3,
			})
			return
			end

			self.container:syncToProgress(body.progress)
			UIManager:show(InfoMessage:new{
				text = T(_("Progress pulled from %1."), server.name),
					timeout = 3,
			})
		end)
	if not ok then
		logger.warn("Multisync: pull failed for", server.name, err)
		UIManager:show(InfoMessage:new{
				text = T(_("Could not pull progress from %1."), server.name),
			})
	end
end

return Sync
