local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local UIManager = require("ui/uimanager")
local md5 = require("ffi/sha2").md5
local _ = require("gettext")
local T = require("ffi/util").template
local Sync = require("sync")

local Multisync = {}

function Multisync:init(container)
	self.container = container
	self.settings = container.settings
	self.sync = Sync:new(container)
end

function Multisync:addToMainMenu(menu_items)
	menu_items.multisync_progress = {
		sorting_hint = "progress_sync",
		text = _("Manage sync servers"),
		sub_item_table = self:getSubMenuItems(),
		-- callback = function()
		-- 	UIManager:show(InfoMessage:new({
		-- 		text = _("Feature not implemented yet."),
		-- 	}))
		-- end,
	}
end

function Multisync:getSubMenuItems()
	return {
		{
			text = _("Push progress to server"),
			callback = function()
				self:pushProgress()
			end,
		},
		{
			text = _("Pull progress from server"),
			callback = function()
				self:pullProgress()
			end,
		},
		{
			text = _("Manage sync servers"),
			callback = function()
				self:manageServers()
			end,
			separator = true,
		},
	}
end

function Multisync:saveSettings()
	G_reader_settings:saveSetting("multisync_progress", self.settings)
end

function Multisync:showServerPicker(direction)
	if #self.settings.servers == 0 then
		UIManager:show(InfoMessage:new{
			text = _("No sync servers configured yet."),
		})
		return
	end

	local buttons = {}
	for _, server in ipairs(self.settings.servers) do
		table.insert(buttons, {{
				text = server.name,
				callback = function()
						UIManager:close(self.picker_dialog)
						self.sync:syncWithServer(server, direction)
					end,
			}})
	end

	self.picker_dialog = ButtonDialog:new{
		title = direction == "push" and _("Push progress to:") or _("Pull progress from:"),
		buttons = buttons,
	}
	UIManager:show(self.picker_dialog)
end

function Multisync:pushProgress()
	self:showServerPicker("push")
end

function Multisync:pullProgress()
	self:showServerPicker("pull")
end

function Multisync:manageServers()
	local item_table = {}
	for index, server in ipairs(self.settings.servers) do
		table.insert(item_table, {
			text = server.name,
			server_index = index,
		})
	end
	table.insert(item_table, {
		text = _("Add new server"),
		add_server = true,
	})

	self.server_menu = Menu:new{
		title = _("Sync servers"),
		item_table = item_table,
		paths = { "servers" },
		covers_fullscreen = true,
		is_borderless = true,
		is_popout = false,
		title_bar_fm_style = true,
		title_bar_left_icon = "plus",
		onLeftButtonTap = function() self:editServer() end,
		onMenuSelect = function(menu, item)
			if item.server_index then
					self:editServer(item.server_index)
				elseif item.add_server then
						self:editServer()
				end
			end,
		onMenuHold = function(menu, item)
			if item.server_index then
					self:confirmDeleteServer(item.server_index)
			end
			return true
		end,
		onReturn = function()
			self.server_menu:onCloseAllMenus()
		end,
		close_callback = function()
			self.server_menu = nil
		end,
	}
	UIManager:show(self.server_menu)
end

function Multisync:editServer(index)
	local existing = index and self.settings.servers[index] or {}
	local dialog
	dialog = MultiInputDialog:new{
		title = index and _("Edit server") or _("Add server"),
		fields = {
			{ text = existing.name or "", hint = _("Name") },
			{ text = existing.host or "https://", hint = _("Host URL") },
			{ text = existing.username or "", hint = _("Username") },
			{ text = "", hint = _("Password"), text_type = "password" },
		},
		buttons = {{
			{ text = _("Cancel"), callback = function() UIManager:close(dialog) end },
			{
				text = _("Save"),
				callback = function()
					local name, host, username, password = unpack(dialog:getFields())
					if name == "" or host == "" or username == "" or password == "" then
						UIManager:show(InfoMessage:new{
							text = _("All fields are required."),
						})
						return
					end

						local server = {
							name = name,
							host = host,
							username = username,
							userkey = existing.userkey,
						}
						if password ~= "" then
							server.userkey = md5(password)
						end

						if not server.userkey then
								UIManager:show(InfoMessage:new{
									text = _("Enter the password to save this server."),
								})
								return
							end
					if index then
						self.settings.servers[index] = server
					else
						table.insert(self.settings.servers, server)
					end
					self:saveSettings()
					UIManager:close(dialog)
					self:refreshServerMenu()
				end,
			},
		}},
	}
	UIManager:show(dialog)
	dialog:onShowKeyboard()
end

function Multisync:refreshServerMenu()
	if self.server_menu then
		self.server_menu:onCloseAllMenus()
	end
	self:manageServers()
end

function Multisync:confirmDeleteServer(index)
	local server = self.settings.servers[index]
	if not server then
		return
	end

	UIManager:show(ConfirmBox:new{
		text = T(_("Delete server %1?"), server.name),
		ok_text = _("Delete"),
		ok_callback = function()
			table.remove(self.settings.servers, index)
			self:saveSettings()
			self:refreshServerMenu()
		end,
	})
end

return Multisync
