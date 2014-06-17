--[[

--]]
local addon, nspace = ...

local Chat = LibStub("AceAddon-3.0"):NewAddon(addon, "AceEvent-3.0", "AceTimer-3.0", "AceHook-3.0")
local LSM = LibStub("LibSharedMedia-3.0")

--[[

--]]
local len, gsub, find, sub, gmatch, format, random = string.len, string.gsub, string.find, string.sub, string.gmatch, string.format, math.random
local tinsert, tremove, tsort, twipe, tconcat = table.insert, table.remove, table.sort, table.wipe, table.concat

--[[

--]]
local CreatedFrames = 0
local msgList, msgCount, msgTime = {}, {}, {}
local filter, login = {}, false
local chatFilters = {}
local throttleInterval = 5

local chatFont = LSM:Fetch("font", "Liberation Sans") or NAMEPLATE_FONT

local DEFAULT_STRINGS = {
	GUILD = "G",
	PARTY = "P",
	RAID = "R",
	OFFICER = "O",
	PARTY_LEADER = "PL",
	RAID_LEADER = "RL",
	INSTANCE_CHAT = "I",
	INSTANCE_CHAT_LEADER = "IL",
	PET_BATTLE_COMBAT_LOG = PET_BATTLE_COMBAT_LOG,
}

local hyperlinkTypes = {
	["item"] = true,
	["spell"] = true,
	["unit"] = true,
	["quest"] = true,
	["enchant"] = true,
	["achievement"] = true,
	["instancelock"] = true,
	["talent"] = true,
	["glyph"] = true,
}

--[[
	The Meat and potatoes
--]]
local PrepareMessage = function(author, message)
	return author:upper() .. message
end

Chat.ChatFrame_AddMessageEventFilter = function(self, event, filter)
	assert(event and filter)

	if (chatFilters[event]) then
		-- Only allow a filter to be added once
		for index, filterFunc in next, chatFilters[event] do
			if (filterFunc == filter) then
				return
			end
		end
	else
		chatFilters[event] = {}
	end

	tinsert(chatFilters[event], filter)
end

Chat.ChatFrame_RemoveMessageEventFilter = function(self, event, filter)
	assert(event and filter)

	if (chatFilters[event]) then
		for index, filterFunc in next, chatFilters[event] do
			if (filterFunc == filter) then
				tremove(chatFilters[event], index)
			end
		end

		if (#chatFilters[event] == 0) then
			chatFilters[event] = nil
		end
	end
end

do
	local GetBNFriendColor = function(name, id)
		local _, _, game, _, _, _, _, class = BNGetToonInfo(id)
		if game ~= BNET_CLIENT_WOW or not class then
			return name
		else
			for k,v in pairs(LOCALIZED_CLASS_NAMES_MALE) do if class == v then class = k end end
			for k,v in pairs(LOCALIZED_CLASS_NAMES_FEMALE) do if class == v then class = k end end

			return "|c"..RAID_CLASS_COLORS[class].colorStr..name.."|r"
		end
	end

	local ConcatenateTimeStamp = function(msg)
		local timeStamp = BetterDate("%H:%M ", Chat.timeOverride or time())
		timeStamp = timeStamp:gsub(" ", "")
		timeStamp = timeStamp:gsub("AM", " AM")
		timeStamp = timeStamp:gsub("PM", " PM")
		msg = "|cffB3B3B3["..timeStamp.."] |r"..msg
		Chat.timeOverride = nil

		return msg
	end

	local ShortChannel = function(self)
		return format("|Hchannel:%s|h[%s]|h", self, DEFAULT_STRINGS[self] or self:gsub("channel:", ""))
	end

	Chat.ChatFrame_MessageEventHandler = function(self, event, ...)
		if (strsub(event, 1, 8) == "CHAT_MSG") then
			local arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 = ...
			local type = strsub(event, 10)
			local info = ChatTypeInfo[type]

			local filter = false

			if ( chatFilters[event] ) then
				local newarg1, newarg2, newarg3, newarg4, newarg5, newarg6, newarg7, newarg8, newarg9, newarg10, newarg11, newarg12, newarg13, newarg14

				for _, filterFunc in next, chatFilters[event] do
					filter, newarg1, newarg2, newarg3, newarg4, newarg5, newarg6, newarg7, newarg8, newarg9, newarg10, newarg11, newarg12, newarg13, newarg14 = filterFunc(self, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)

					if ( filter ) then
						return true
					elseif ( newarg1 ) then
						arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14 = newarg1, newarg2, newarg3, newarg4, newarg5, newarg6, newarg7, newarg8, newarg9, newarg10, newarg11, newarg12, newarg13, newarg14
					end
				end
			end

			local coloredName = GetColoredName(event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9, arg10, arg11, arg12, arg13, arg14)

			local channelLength = strlen(arg4)
			local infoType = type

			if ( (strsub(type, 1, 7) == "CHANNEL") and (type ~= "CHANNEL_LIST") and ((arg1 ~= "INVITE") or (type ~= "CHANNEL_NOTICE_USER")) ) then
				if ( arg1 == "WRONG_PASSWORD" ) then
					local staticPopup = _G[StaticPopup_Visible("CHAT_CHANNEL_PASSWORD") or ""]
					if ( staticPopup and strupper(staticPopup.data) == strupper(arg9) ) then
						-- Don"t display invalid password messages if we"re going to prompt for a password (bug 102312)
						return
					end
				end

				local found = 0
				for index, value in pairs(self.channelList) do
					if ( channelLength > strlen(value) ) then
						-- arg9 is the channel name without the number in front...
						if ( ((arg7 > 0) and (self.zoneChannelList[index] == arg7)) or (strupper(value) == strupper(arg9)) ) then
							found = 1
							infoType = "CHANNEL"..arg8
							info = ChatTypeInfo[infoType]
							if ( (type == "CHANNEL_NOTICE") and (arg1 == "YOU_LEFT") ) then
								self.channelList[index] = nil
								self.zoneChannelList[index] = nil
							end
							break
						end
					end
				end
				if ( (found == 0) or not info ) then
					return true
				end
			end

			local chatGroup = Chat_GetChatCategory(type)
			local chatTarget
			if ( chatGroup == "CHANNEL" or chatGroup == "BN_CONVERSATION" ) then
				chatTarget = tostring(arg8)
			elseif ( chatGroup == "WHISPER" or chatGroup == "BN_WHISPER" ) then
				if(not(strsub(arg2, 1, 2) == "|K")) then
					chatTarget = strupper(arg2)
				else
					chatTarget = arg2
				end
			end

			if ( FCFManager_ShouldSuppressMessage(self, chatGroup, chatTarget) ) then
				return true
			end

			if ( chatGroup == "WHISPER" or chatGroup == "BN_WHISPER" ) then
				if ( self.privateMessageList and not self.privateMessageList[strlower(arg2)] ) then
					return true
				elseif ( self.excludePrivateMessageList and self.excludePrivateMessageList[strlower(arg2)]
					and ( (chatGroup == "WHISPER" and GetCVar("whisperMode") ~= "popout_and_inline") or (chatGroup == "BN_WHISPER" and GetCVar("bnWhisperMode") ~= "popout_and_inline") ) ) then
					return true
				end
			elseif ( chatGroup == "BN_CONVERSATION" ) then
				if ( self.bnConversationList and not self.bnConversationList[arg8] ) then
					return true
				elseif ( self.excludeBNConversationList and self.excludeBNConversationList[arg8] and GetCVar("conversationMode") ~= "popout_and_inline") then
					return true
				end
			end

			if (self.privateMessageList) then
				-- Dedicated BN whisper windows need online/offline messages for only that player
				if ( (chatGroup == "BN_INLINE_TOAST_ALERT" or chatGroup == "BN_WHISPER_PLAYER_OFFLINE") and not self.privateMessageList[strlower(arg2)] ) then
					return true
				end

				-- HACK to put certain system messages into dedicated whisper windows
				if ( chatGroup == "SYSTEM") then
					local matchFound = false
					local message = strlower(arg1)
					for playerName, _ in pairs(self.privateMessageList) do
						local playerNotFoundMsg = strlower(format(ERR_CHAT_PLAYER_NOT_FOUND_S, playerName))
						local charOnlineMsg = strlower(format(ERR_FRIEND_ONLINE_SS, playerName, playerName))
						local charOfflineMsg = strlower(format(ERR_FRIEND_OFFLINE_S, playerName))
						if ( message == playerNotFoundMsg or message == charOnlineMsg or message == charOfflineMsg) then
							matchFound = true
							break
						end
					end

					if (not matchFound) then
						return true
					end
				end
			end

			if ( type == "SYSTEM" or type == "SKILL" or type == "LOOT" or type == "CURRENCY" or type == "MONEY" or
				 type == "OPENING" or type == "TRADESKILLS" or type == "PET_INFO" or type == "TARGETICONS" or type == "BN_WHISPER_PLAYER_OFFLINE") then
				self:AddMessage(ConcatenateTimeStamp(arg1), info.r, info.g, info.b, info.id)
			elseif ( strsub(type,1,7) == "COMBAT_" ) then
				self:AddMessage(ConcatenateTimeStamp(arg1), info.r, info.g, info.b, info.id)
			elseif ( strsub(type,1,6) == "SPELL_" ) then
				self:AddMessage(ConcatenateTimeStamp(arg1), info.r, info.g, info.b, info.id)
			elseif ( strsub(type,1,10) == "BG_SYSTEM_" ) then
				self:AddMessage(ConcatenateTimeStamp(arg1), info.r, info.g, info.b, info.id)
			elseif ( strsub(type,1,11) == "ACHIEVEMENT" ) then
				self:AddMessage(format(ConcatenateTimeStamp(arg1), "|Hplayer:"..arg2.."|h".."["..coloredName.."]".."|h"), info.r, info.g, info.b, info.id)
			elseif ( strsub(type,1,18) == "GUILD_ACHIEVEMENT" ) then
				self:AddMessage(format(ConcatenateTimeStamp(arg1), "|Hplayer:"..arg2.."|h".."["..coloredName.."]".."|h"), info.r, info.g, info.b, info.id)
			elseif ( type == "IGNORED" ) then
				self:AddMessage(format(ConcatenateTimeStamp(CHAT_IGNORED), arg2), info.r, info.g, info.b, info.id)
			elseif ( type == "FILTERED" ) then
				self:AddMessage(format(ConcatenateTimeStamp(CHAT_FILTERED), arg2), info.r, info.g, info.b, info.id)
			elseif ( type == "RESTRICTED" ) then
				self:AddMessage(ConcatenateTimeStamp(CHAT_RESTRICTED), info.r, info.g, info.b, info.id)
			elseif ( type == "CHANNEL_LIST") then
				if(channelLength > 0) then
					self:AddMessage(format(ConcatenateTimeStamp(_G["CHAT_"..type.."_GET"]..arg1), tonumber(arg8), arg4), info.r, info.g, info.b, info.id)
				else
					self:AddMessage(ConcatenateTimeStamp(arg1), info.r, info.g, info.b, info.id)
				end
			elseif (type == "CHANNEL_NOTICE_USER") then
				local globalstring = _G["CHAT_"..arg1.."_NOTICE_BN"]
				if ( not globalstring ) then
					globalstring = _G["CHAT_"..arg1.."_NOTICE"]
				end

				globalString = ConcatenateTimeStamp(globalstring)

				if(strlen(arg5) > 0) then
					-- TWO users in this notice (E.G. x kicked y)
					self:AddMessage(format(globalstring, arg8, arg4, arg2, arg5), info.r, info.g, info.b, info.id)
				elseif ( arg1 == "INVITE" ) then
					self:AddMessage(format(globalstring, arg4, arg2), info.r, info.g, info.b, info.id)
				else
					self:AddMessage(format(globalstring, arg8, arg4, arg2), info.r, info.g, info.b, info.id)
				end
			elseif (type == "CHANNEL_NOTICE") then
				local globalstring = _G["CHAT_"..arg1.."_NOTICE_BN"]
				if ( not globalstring ) then
					globalstring = _G["CHAT_"..arg1.."_NOTICE"]
				end
				if ( arg10 > 0 ) then
					arg4 = arg4.." "..arg10
				end

				globalString = ConcatenateTimeStamp(globalstring)

				local accessID = ChatHistory_GetAccessID(Chat_GetChatCategory(type), arg8)
				local typeID = ChatHistory_GetAccessID(infoType, arg8, arg12)
				self:AddMessage(format(globalstring, arg8, arg4), info.r, info.g, info.b, info.id, false, accessID, typeID)
			elseif ( type == "BN_CONVERSATION_NOTICE" ) then
				local channelLink = format(CHAT_BN_CONVERSATION_GET_LINK, arg8, MAX_WOW_CHAT_CHANNELS + arg8)
				local playerLink = format("|HBNplayer:%s:%s:%s:%s:%s|h[%s]|h", arg2, arg13, arg11, Chat_GetChatCategory(type), arg8, arg2)
				local message = format(_G["CHAT_CONVERSATION_"..arg1.."_NOTICE"], channelLink, playerLink)

				local accessID = ChatHistory_GetAccessID(Chat_GetChatCategory(type), arg8)
				local typeID = ChatHistory_GetAccessID(infoType, arg8, arg12)
				self:AddMessage(ConcatenateTimeStamp(message), info.r, info.g, info.b, info.id, false, accessID, typeID)
			elseif ( type == "BN_CONVERSATION_LIST" ) then
				local channelLink = format(CHAT_BN_CONVERSATION_GET_LINK, arg8, MAX_WOW_CHAT_CHANNELS + arg8)
				local message = format(CHAT_BN_CONVERSATION_LIST, channelLink, arg1)
				self:AddMessage(ConcatenateTimeStamp(message), info.r, info.g, info.b, info.id, false, accessID, typeID)
			elseif ( type == "BN_INLINE_TOAST_ALERT" ) then
				if ( arg1 == "FRIEND_OFFLINE" and not BNet_ShouldProcessOfflineEvents() ) then
					return true
				end
				local globalstring = _G["BN_INLINE_TOAST_"..arg1]
				local message
				if ( arg1 == "FRIEND_REQUEST" ) then
					message = globalstring
				elseif ( arg1 == "FRIEND_PENDING" ) then
					message = format(BN_INLINE_TOAST_FRIEND_PENDING, BNGetNumFriendInvites())
				elseif ( arg1 == "FRIEND_REMOVED" or arg1 == "BATTLETAG_FRIEND_REMOVED" ) then
					message = format(globalstring, arg2)
				elseif ( arg1 == "FRIEND_ONLINE" or arg1 == "FRIEND_OFFLINE") then
					local hasFocus, toonName, client, realmName, realmID, faction, race, class, guild, zoneName, level, gameText = BNGetToonInfo(arg13)
					if (toonName and toonName ~= "" and client and client ~= "") then
						local toonNameText = BNet_GetClientEmbeddedTexture(client, 14)..toonName
						local playerLink = format("|HBNplayer:%s:%s:%s:%s:%s|h[%s] (%s)|h", arg2, arg13, arg11, Chat_GetChatCategory(type), 0, arg2, toonNameText)
						message = format(globalstring, playerLink)
					else
						local playerLink = format("|HBNplayer:%s:%s:%s:%s:%s|h[%s]|h", arg2, arg13, arg11, Chat_GetChatCategory(type), 0, arg2)
						message = format(globalstring, playerLink)
					end
				else
					local playerLink = format("|HBNplayer:%s:%s:%s:%s:%s|h[%s]|h", arg2, arg13, arg11, Chat_GetChatCategory(type), 0, arg2)
					message = format(globalstring, playerLink)
				end
				self:AddMessage(ConcatenateTimeStamp(message), info.r, info.g, info.b, info.id)
			elseif ( type == "BN_INLINE_TOAST_BROADCAST" ) then
				if ( arg1 ~= "" ) then
					arg1 = RemoveExtraSpaces(arg1)
					local playerLink = format("|HBNplayer:%s:%s:%s:%s:%s|h[%s]|h", arg2, arg13, arg11, Chat_GetChatCategory(type), 0, arg2)
					self:AddMessage(format(ConcatenateTimeStamp(BN_INLINE_TOAST_BROADCAST), playerLink, arg1), info.r, info.g, info.b, info.id)
				end
			elseif ( type == "BN_INLINE_TOAST_BROADCAST_INFORM" ) then
				if ( arg1 ~= "" ) then
					arg1 = RemoveExtraSpaces(arg1)
					self:AddMessage(ConcatenateTimeStamp(BN_INLINE_TOAST_BROADCAST_INFORM), info.r, info.g, info.b, info.id)
				end
			elseif ( type == "BN_INLINE_TOAST_CONVERSATION" ) then
				self:AddMessage(format(ConcatenateTimeStamp(BN_INLINE_TOAST_CONVERSATION), arg1), info.r, info.g, info.b, info.id)
			else
				local body

				local _, fontHeight = FCF_GetChatWindowInfo(self:GetID())

				if ( fontHeight == 0 ) then
					--fontHeight will be 0 if it"s still at the default (14)
					fontHeight = 13
				end

				-- Add AFK/DND flags
				local pflag
				if(strlen(arg6) > 0) then
					if ( arg6 == "GM" ) then
						--If it was a whisper, dispatch it to the GMChat addon.
						if ( type == "WHISPER" ) then
							return
						end
						--Add Blizzard Icon, this was sent by a GM
						pflag = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:12:20:0:0:32:16:4:28:0:16|t "
					elseif ( arg6 == "DEV" ) then
						--Add Blizzard Icon, this was sent by a Dev
						pflag = "|TInterface\\ChatFrame\\UI-ChatIcon-Blizz:12:20:0:0:32:16:4:28:0:16|t "
					else
						pflag = _G["CHAT_FLAG_"..arg6]
					end
				else
					if not pflag then
						pflag = ""
					end
				end

				if ( type == "WHISPER_INFORM" and GMChatFrame_IsGM and GMChatFrame_IsGM(arg2) ) then
					return
				end

				local showLink = 1
				if ( strsub(type, 1, 7) == "MONSTER" or strsub(type, 1, 9) == "RAID_BOSS") then
					showLink = nil
				else
					arg1 = gsub(arg1, "%%", "%%%%")
				end

				-- Search for icon links and replace them with texture links.
				for tag in gmatch(arg1, "%b{}") do
					local term = strlower(gsub(tag, "[{}]", ""))
					if ( ICON_TAG_LIST[term] and ICON_LIST[ICON_TAG_LIST[term]] ) then
						arg1 = gsub(arg1, tag, ICON_LIST[ICON_TAG_LIST[term]] .. "0|t")
					elseif ( GROUP_TAG_LIST[term] ) then
						local groupIndex = GROUP_TAG_LIST[term]
						local groupList = "["
						for i=1, GetNumGroupMembers() do
							local name, rank, subgroup, level, class, classFileName = GetRaidRosterInfo(i)
							if ( name and subgroup == groupIndex ) then
								local classColorTable = RAID_CLASS_COLORS[classFileName]
								if ( classColorTable ) then
									name = format("\124cff%.2x%.2x%.2x%s\124r", classColorTable.r*255, classColorTable.g*255, classColorTable.b*255, name)
								end
								groupList = groupList..(groupList == "[" and "" or PLAYER_LIST_DELIMITER)..name
							end
						end
						groupList = groupList.."]"
						arg1 = gsub(arg1, tag, groupList)
					end
				end

				--Remove groups of many spaces
				arg1 = RemoveExtraSpaces(arg1)

				local playerLink

				if ( type ~= "BN_WHISPER" and type ~= "BN_WHISPER_INFORM" and type ~= "BN_CONVERSATION" ) then
					playerLink = "|Hplayer:"..arg2..":"..arg11..":"..chatGroup..(chatTarget and ":"..chatTarget or "").."|h"
				else
					coloredName = GetBNFriendColor(arg2, arg13)
					playerLink = "|HBNplayer:"..arg2..":"..arg13..":"..arg11..":"..chatGroup..(chatTarget and ":"..chatTarget or "").."|h"
				end

				local message = arg1
				if ( arg14 ) then	--isMobile
					message = ChatFrame_GetMobileEmbeddedTexture(info.r, info.g, info.b)..message
				end

				if ( (strlen(arg3) > 0) and (arg3 ~= self.defaultLanguage) ) then
					local languageHeader = "["..arg3.."] "
					if ( showLink and (strlen(arg2) > 0) ) then
						body = format(_G["CHAT_"..type.."_GET"]..languageHeader..message, pflag..playerLink.."["..coloredName.."]".."|h")
					else
						body = format(_G["CHAT_"..type.."_GET"]..languageHeader..message, pflag..arg2)
					end
				else
					if ( not showLink or strlen(arg2) == 0 ) then
						if ( type == "TEXT_EMOTE" ) then
							body = message
						else
							body = format(_G["CHAT_"..type.."_GET"]..message, pflag..arg2, arg2)
						end
					else
						if ( type == "EMOTE" ) then
							body = format(_G["CHAT_"..type.."_GET"]..message, pflag..playerLink..coloredName.."|h")
						elseif ( type == "TEXT_EMOTE") then
							body = gsub(message, arg2, pflag..playerLink..coloredName.."|h", 1)
						else
							body = format(_G["CHAT_"..type.."_GET"]..message, pflag..playerLink.."["..coloredName.."]".."|h")
						end
					end
				end

				-- Add Channel
				arg4 = gsub(arg4, "%s%-%s.*", "")
				if( chatGroup  == "BN_CONVERSATION" ) then
					body = format(CHAT_BN_CONVERSATION_GET_LINK, MAX_WOW_CHAT_CHANNELS + arg8, MAX_WOW_CHAT_CHANNELS + arg8)..body
				elseif(channelLength > 0) then
					body = "|Hchannel:channel:"..arg8.."|h["..arg4.."]|h "..body
				end

				local accessID = ChatHistory_GetAccessID(chatGroup, chatTarget)
				local typeID = ChatHistory_GetAccessID(infoType, chatTarget, arg12 == "" and arg13 or arg12)

				body = body:gsub("|Hchannel:(.-)|h%[(.-)%]|h", ShortChannel)
				body = body:gsub("CHANNEL:", "")
				body = body:gsub("^(.-|h) ".."whispers", "%1")
				body = body:gsub("^(.-|h) ".."says", "%1")
				body = body:gsub("^(.-|h) ".."yells", "%1")
				body = body:gsub("<"..AFK..">", "[|cffFF0000".."AFK".."|r] ")
				body = body:gsub("<"..DND..">", "[|cffE7E716".."DND".."|r] ")
				body = body:gsub("%[BN_CONVERSATION:", "%[".."")
				body = body:gsub("^%["..RAID_WARNING.."%]", "[".."RW".."]")

				self:AddMessage(ConcatenateTimeStamp(body), info.r, info.g, info.b, info.id, false, accessID, typeID)
			end

			if ( type == "WHISPER" or type == "BN_WHISPER" ) then
				--BN_WHISPER FIXME
				ChatEdit_SetLastTellTarget(arg2, type)
				if ( self.tellTimer and (GetTime() > self.tellTimer) ) then
					PlaySound("TellMessage")
				end
				self.tellTimer = GetTime() + CHAT_TELL_ALERT_TIME
			end

			return true
		end
	end
end

function Chat:ChatFrame_OnEvent(event, ...)
	if ( ChatFrame_ConfigEventHandler(self, event, ...) ) then
		return
	end
	if ( ChatFrame_SystemEventHandler(self, event, ...) ) then
		return
	end
	if ( Chat.ChatFrame_MessageEventHandler(self, event, ...) ) then
		return
	end
end

function Chat:FloatingChatFrame_OnEvent(event, ...)
	Chat.ChatFrame_OnEvent(self, event, ...)
	FloatingChatFrame_OnEvent(self, event, ...)
end

function Chat:CHAT_MSG_CHANNEL(event, message, author, ...)
	local blockFlag = false
	local msg = PrepareMessage(author, message)

	-- ignore player messages
	if author == UnitName("player") then return Chat.FindURL(self, event, message, author, ...) end
	if msgList[msg] and throttleInterval ~= 0 then
		if difftime(time(), msgTime[msg]) <= throttleInterval then
			blockFlag = true
		end
	end

	if blockFlag then
		return true
	else
		if throttleInterval ~= 0 then
			msgTime[msg] = time()
		end

		return Chat.FindURL(self, event, message, author, ...)
	end
end

Chat.CHAT_MSG_YELL = function(self, event, message, author, ...)
	local blockFlag = false
	local msg = PrepareMessage(author, message)

	if (msg == nil) then
		return Chat.FindURL(self, event, message, author, ...)
	end

	-- ignore player messages
	if (author == UnitName("player")) then
		return Chat.FindURL(self, event, message, author, ...)
	end

	if (msgList[msg] and msgCount[msg] > 1 and throttleInterval ~= 0) then
		if (difftime(time(), msgTime[msg]) <= throttleInterval) then
			blockFlag = true
		end
	end

	if (blockFlag) then
		return true
	else
		if (throttleInterval ~= 0) then
			msgTime[msg] = time()
		end

		return Chat.FindURL(self, event, message, author, ...)
	end
end

Chat.CHAT_MSG_SAY = function(self, event, message, author, ...)
	return Chat.FindURL(self, event, message, author, ...)
end

-- Misc hooked/other functions
do
	local stopScript = false

	hooksecurefunc(DEFAULT_CHAT_FRAME, "RegisterEvent", function(self, event)
		if (event == "GUILD_MOTD" and not stopScript) then
			self:UnregisterEvent("GUILD_MOTD")
		end
	end)

	local cachedMsg = GetGuildRosterMOTD()
	if (cachedMsg == "") then cachedMsg = nil end

	Chat.DelayGMOTD = function(self)
		stopScript = true
		DEFAULT_CHAT_FRAME:RegisterEvent("GUILD_MOTD")
		local msg = cachedMsg or GetGuildRosterMOTD()

		if (msg == "") then msg = nil end

		if (msg) then
			ChatFrame_SystemEventHandler(DEFAULT_CHAT_FRAME, "GUILD_MOTD", msg)
		end

		self:UnregisterEvent("PLAYER_ENTERING_WORLD")
	end
end

Chat.FCF_SetWindowAlpha = function(self, frame, alpha, doNotSave)
	frame.oldAlpha = alpha or 1
end

function Chat:ChatEdit_OnEnterPressed(editBox)
	local type = editBox:GetAttribute("chatType")
	local chatFrame = editBox:GetParent()
	if (not chatFrame.isTemporary and ChatTypeInfo[type].sticky == 1) then
		editBox:SetAttribute("chatType", type)
	end
end

function Chat:SetChatFont(dropDown, chatFrame, fontSize)
	if (not chatFrame) then
		chatFrame = FCF_GetCurrentChatFrame()
	end

	chatFrame:SetFont(chatFont, 13, "THINOUTLINE")
end

function Chat:PET_BATTLE_CLOSE()
	for _, frameName in pairs(CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame and _G[frameName.."Tab"]:GetText():match(PET_BATTLE_COMBAT_LOG)) then
			FCF_Close(frame)
		end
	end
end

function Chat:UpdateFading()
	for _, frameName in pairs(CHAT_FRAMES) do
		local frame = _G[frameName]
		if (frame) then
			frame:SetFading(0)
		end
	end
end

-- Scrolling
local function ChatFrame_OnMouseScroll(frame, delta)
	if (delta < 0) then
		if (IsShiftKeyDown()) then
			frame:ScrollToBottom()
		else
			for i = 1, 3 do
				frame:ScrollDown()
			end
		end
	elseif (delta > 0) then
		if (IsShiftKeyDown()) then
			frame:ScrollToTop()
		else
			for i = 1, 3 do
				frame:ScrollUp()
			end
		end

		if (frame.ScrollTimer) then
			Chat:CancelTimer(frame.ScrollTimer, true)
		end

		frame.ScrollTimer = Chat:ScheduleTimer("ScrollToBottom", 20, frame) -- Scroll the chat frame down after 20 seconds
	end
end

function Chat:ScrollToBottom(frame)
	frame:ScrollToBottom()

	self:CancelTimer(frame.ScrollTimer, true)
end

-- Chat and editbox histories
Chat.DisplayChatHistory = function(self)
	local temp, data = {}
	for id, _ in pairs(self.db.ChatLog) do
		tinsert(temp, tonumber(id))
	end

	tsort(temp, function(a, b)
		return a < b
	end)

	for i = 1, #temp do
		data = self.db.ChatLog[tostring(temp[i])]

		if (type(data) == "table" and data[20] ~= nil) then
			Chat.timeOverride = temp[i]
			Chat.ChatFrame_MessageEventHandler(DEFAULT_CHAT_FRAME, data[20], unpack(data))
		end
	end
end

Chat.ChatEdit_AddHistory = function(self, editBox, line)
	if (line:find("/rl")) then return end

	if (strlen(line) > 0) then
		for i, text in pairs(self.db.ChatEditHistory) do
			if (text == line) then
				return
			end
		end

		tinsert(self.db.ChatEditHistory, #self.db.ChatEditHistory + 1, line)

		if (#self.db.ChatEditHistory > 5) then
			tremove(self.db.ChatEditHistory, 1)
		end
	end
end

do
	local GetTimeForSavedMessage = function()
		local randomTime = select(2, ("."):split(GetTime() or "0."..random(1, 999), 2)) or 0
		return time().."."..randomTime
	end

	local ChatThrottleHandler = function(event, ...)
		local arg1, arg2 = ...

		if (arg2 ~= "") then
			local message = PrepareMessage(arg2, arg1)
			if msgList[message] == nil then
				msgList[message] = true
				msgCount[message] = 1
				msgTime[message] = time()
			else
				msgCount[message] = msgCount[message] + 1
			end
		end
	end

	Chat.SaveChatHistory = function(self, event, ...)
		if (event == "CHAT_MESSAGE_SAY" or event == "CHAT_MESSAGE_YELL" or event == "CHAT_MSG_CHANNEL") then
			ChatThrottleHandler(event, ...)

			local message, author = ...
			local msg = PrepareMessage(author, message)

			if (author ~= UnitName("player") and msgList[msg]) then
				if (difftime(time(), msgTime[msg]) <= throttleInterval) then
					return
				end
			end
		end

		local temp = {}
		for i = 1, select("#", ...) do
			temp[i] = select(i, ...) or false
		end

		if (#temp > 0) then
			temp[20] = event
			local timeForMessage = GetTimeForSavedMessage()

			self.db.ChatLog[timeForMessage] = temp

			local c, k = 0
			for id, data in pairs(self.db.ChatLog) do
				c = c + 1
				if (not k or k > id) then
					k = id
				end
			end

			if (c > 50) then
				self.db.ChatLog[k] = nil
			end
		end
	end
end

-- Copy the chat
Chat.CopyChat = function(self, frame)
	if not CopyChatFrame:IsShown() then
		local chatFrame = _G["ChatFrame" .. frame:GetID()]
		local numMessages = chatFrame:GetNumMessages()

		if (numMessages >= 1) then
			local GetMessageInfo = chatFrame.GetMessageInfo
			local text = GetMessageInfo(chatFrame, 1)

			for index = 2, numMessages do
				text = text .. "\n" .. GetMessageInfo(chatFrame, index)
			end

			CopyChatFrame:Show()
			CopyChatFrameEditBox:SetText(text)
		end
	else
		CopyChatFrame:Hide()
	end
end

-- Hyperlinking routines
do
	local URL_MATCH = {
		"(%a+)://(%S+)%s?",
		"www%.([_A-Za-z0-9-]+)%.(%S+)%s?",
		"([_A-Za-z0-9-%.]+)@([_A-Za-z0-9-]+)(%.+)([_A-Za-z0-9-%.]+)%s?",
	}

	local URL_REPLACE = {
		"%1://%2",
		"www.%1.%2",
		"%1@%2%3%4",
	}

	Chat.ThrottleSound = function(self)
		self.SoundPlayed = nil
	end

	Chat.PrintURL = function(self, url)
		return "|cFFFFFFFF[|Hurl:"..url.."|h"..url.."|h]|r "
	end

	Chat.FindURL = function(self, event, msg, ...)
		if (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") and not Chat.SoundPlayed then
			PlaySoundFile(LSM:Fetch("sound", "Whisper Alert"), "Master")
			Chat.SoundPlayed = true
			Chat.SoundTimer = Chat:ScheduleTimer("ThrottleSound", 1)
		end

		for i, pattern in ipairs(URL_MATCH) do
			local new = msg:gsub(pattern, Chat:PrintURL(URL_REPLACE[i]))
			if msg ~= new then
				msg = new
				break
			end
		end

		return false, msg, ...
	end
end

local WIM_URLLink = function(link)
	if link:sub(1, 4) == "url:" then -- ignore Blizzard urlIndex links
		currentURL = link:sub(5)
		StaticPopup_Show("URL_COPY_DIALOG")
		return
	end
end

local URLChatFrame_OnHyperlinkShow = function(self, link, ...)
	Chat.clickedframe = self

	if link:sub(1, 4) == "url:" then -- ignore Blizzard urlIndex links
		currentURL = link:sub(5)
		StaticPopup_Show("URL_COPY_DIALOG")
		return
	end

	ChatFrame_OnHyperlinkShow(self, link, ...)
end

Chat.OnMessageScrollChanged = function(self, frame)
	if (hyperLinkEntered == frame) then
		HideUIPanel(GameTooltip)
		hyperLinkEntered = false
	end
end

Chat.EnableHyperlink = function(self)
	for _, frameName in pairs(CHAT_FRAMES) do
		local frame = _G[frameName]
		if (not self.hooks or not self.hooks[frame] or not self.hooks[frame].OnHyperlinkEnter) then
			self:HookScript(frame, "OnHyperlinkEnter")
			self:HookScript(frame, "OnHyperlinkLeave")
			self:HookScript(frame, "OnMessageScrollChanged")
		end
	end
end

Chat.DisableHyperlink = function(self)
	for _, frameName in pairs(CHAT_FRAMES) do
		local frame = _G[frameName]
		if self.hooks and self.hooks[frame] and self.hooks[frame].OnHyperlinkEnter then
			self:Unhook(frame, "OnHyperlinkEnter")
			self:Unhook(frame, "OnHyperlinkLeave")
			self:Unhook(frame, "OnMessageScrollChanged")
		end
	end
end

do
	local hyperLinkEntered = nil

	Chat.OnHyperlinkEnter = function(self, frame, refString)
		if (InCombatLockdown()) then return end

		local linkToken = refString:match("^([^:]+)")

		if (hyperlinkTypes[linkToken]) then
			ShowUIPanel(GameTooltip)
			GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
			GameTooltip:SetHyperlink(refString)
			hyperLinkEntered = frame
			GameTooltip:Show()
		end
	end

	Chat.OnHyperlinkLeave = function(self, frame, refString)
		local linkToken = refString:match("^([^:]+)")

		if (hyperlinkTypes[linkToken]) then
			HideUIPanel(GameTooltip)
			hyperLinkEntered = nil
		end
	end
end

-- Styling and initial setup of chat frames
Chat.SetupChat = function(self, event, ...)
	for _, frameName in pairs(CHAT_FRAMES) do
		local frame = _G[frameName]
		local id = frame:GetID()

		self:StyleChat(frame)

		FCFTab_UpdateAlpha(frame)

		frame:SetFont(chatFont, 13, "THINOUTLINE")

		frame:SetTimeVisible(100)
		frame:SetFading(false)

		frame:SetScript("OnHyperlinkClick", URLChatFrame_OnHyperlinkShow)
		frame:SetScript("OnMouseWheel", ChatFrame_OnMouseScroll)

		if (id > NUM_CHAT_WINDOWS) then
			frame:SetScript("OnEvent", Chat.FloatingChatFrame_OnEvent)
		elseif (id ~= 2) then
			frame:SetScript("OnEvent", Chat.ChatFrame_OnEvent)
		end

		hooksecurefunc(frame, "SetScript", function(f, script, func)
			if (script == "OnMouseWheel" and func ~= ChatFrame_OnMouseScroll) then
				f:SetScript(script, ChatFrame_OnMouseScroll)
			end
		end)
	end

	self:EnableHyperlink()

	if (not self.HookSecured) then
		self:SecureHook("FCF_OpenTemporaryWindow", "SetupChat")
		self.HookSecured = true
	end
end

do
	local tabTexs = {
		"",
		"Selected",
		"Highlight"
	}

	local GetGroupDistribution = function()
		local inInstance, kind = IsInInstance()

		if (inInstance and kind == "pvp") then
			return "/bg "
		end

		if (IsInRaid()) then
			return "/ra "
		end
		if (IsInGroup()) then
			return "/p "
		end

		return "/s "
	end


	Chat.StyleChat = function(self, frame)
		local name = frame:GetName()

		if (frame.styled) then return end

		frame:SetFrameLevel(4)

		local id = frame:GetID()

		local tab = _G[name.."Tab"]
		local editbox = _G[name.."EditBox"]

		for _, texName in pairs(tabTexs) do
			_G[tab:GetName()..texName.."Left"]:SetTexture(nil)
			_G[tab:GetName()..texName.."Middle"]:SetTexture(nil)
			_G[tab:GetName()..texName.."Right"]:SetTexture(nil)
		end

		hooksecurefunc(tab, "SetAlpha", function(t, alpha)
			if (alpha ~= 1 and (not t.isDocked or GeneralDockManager.selected:GetID() == t:GetID())) then
				t:SetAlpha(1.0)
			elseif (alpha < 0.6) then
				t:SetAlpha(0.6)
			end
		end)

		tab.text = _G[name.."TabText"]
		tab.text:SetFont(chatFont, 12, "OUTLINE")
		tab.text:SetJustifyH("CENTER")
		tab.text.GetWidth = tab.text.GetStringWidth

		if tab.conversationIcon then
			tab.conversationIcon:ClearAllPoints()
			tab.conversationIcon:Point("RIGHT", tab.text, "LEFT", -1, 0)
		end

		frame:SetClampRectInsets(0, 0, 0, 0)
		frame:SetClampedToScreen(false)
--		frame:StripTextures(true)
		_G[name.."ButtonFrame"]:UnregisterAllEvents()
		_G[name.."ButtonFrame"]:Hide()

		editbox:SetAltArrowKeyMode(false)

		editbox:ClearAllPoints()
		editbox:Point("BOTTOMLEFT",  frame, "TOPLEFT",  -5, 22)
		editbox:Point("BOTTOMRIGHT", frame, "TOPRIGHT", 10, 22)

		self:SecureHook(editbox, "AddHistoryLine", "ChatEdit_AddHistory")

		editbox:SetAlpha(0)
		hooksecurefunc("ChatEdit_DeactivateChat", function(self)
			editbox:SetAlpha(0)
		end)
		hooksecurefunc("ChatEdit_OnHide", function(self)
			editbox:SetAlpha(0)
		end)

		editbox:HookScript("OnTextChanged", function(self)
			local text = self:GetText()

			if InCombatLockdown() then
				local MIN_REPEAT_CHARACTERS = 5
				if (len(text) > MIN_REPEAT_CHARACTERS) then
				local repeatChar = true
				for i=1, MIN_REPEAT_CHARACTERS, 1 do
					if ( sub(text,(0-i), (0-i)) ~= sub(text,(-1-i),(-1-i)) ) then
						repeatChar = false
						break
					end
				end
					if ( repeatChar ) then
						self:Hide()
						return
					end
				end
			end

			if text:len() < 5 then
				if text:sub(1, 4) == "/tt " then
					local unitname, realm
					unitname, realm = UnitName("target")
					if unitname then unitname = gsub(unitname, " ", "") end
					if unitname and not UnitIsSameServer("player", "target") then
						unitname = unitname .. "-" .. gsub(realm, " ", "")
					end
					ChatFrame_SendTell((unitname or "Invalid Target"), ChatFrame1)
				end

				if text:sub(1, 4) == "/gr " then
					self:SetText(GetGroupDistribution() .. text:sub(5))
					ChatEdit_ParseText(self, 0)
				end
			end

			local new, found = gsub(text, "|Kf(%S+)|k(%S+)%s(%S+)|k", "%2 %3")

			if (found > 0) then
				new = new:gsub("|", "")
				self:SetText(new)
			end
		end)

		for i, text in pairs(self.db.ChatEditHistory) do
			editbox:AddHistoryLine(text)
		end

		hooksecurefunc("ChatEdit_UpdateHeader", function()
			local type = editbox:GetAttribute("chatType")
			if ( type == "CHANNEL" ) then
				local id = GetChannelName(editbox:GetAttribute("channelTarget"))
				if id == 0 then
					editbox:SetBackdropBorderColor(0, 0, 0)
				else
					editbox:SetBackdropBorderColor(ChatTypeInfo[type..id].r,ChatTypeInfo[type..id].g,ChatTypeInfo[type..id].b)
				end
			elseif type then
				editbox:SetBackdropBorderColor(ChatTypeInfo[type].r,ChatTypeInfo[type].g,ChatTypeInfo[type].b)
			end
		end)

		hooksecurefunc("FCF_Tab_OnClick", function(self)
			local info = UIDropDownMenu_CreateInfo()
			info.text = "Copy Chat Contents"
			info.notCheckable = true
			info.func = Chat.CopyChat
			info.arg1 = self
			UIDropDownMenu_AddButton(info)
		end)

		CreatedFrames = id
		frame.styled = true
	end
end

Chat.PositionChat = function(self, override)
	if ((InCombatLockdown() and not override and self.initialMove) or (IsMouseButtonDown("LeftButton") and not override)) then return end

	for i = 1, CreatedFrames do
		local BASE_OFFSET = 60
		chat = _G[format("ChatFrame%d", i)]
		chatbg = format("ChatFrame%dBackground", i)
		button = _G[format("ButtonCF%d", i)]
		id = chat:GetID()
		tab = _G[format("ChatFrame%sTab", i)]
		point = GetChatWindowSavedPosition(id)
		isDocked = chat.isDocked
		tab.isDocked = chat.isDocked

		if id > NUM_CHAT_WINDOWS then
			point = point or select(1, chat:GetPoint())
			if select(2, tab:GetPoint()):GetName() ~= bg then
				isDocked = true
			else
				isDocked = false
			end
		end

		if (id ~= 2 and not (id > NUM_CHAT_WINDOWS)) then
			chat:ClearAllPoints()
			chat:Point("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 5, 10)
			chat:Size(450, 175)
			FCF_SavePositionAndDimensions(chat)
		end
	end

	self.initialMove = true
end

--[[

--]]
Chat.OnInitialize = function(self)
	self.charSettings = LibStub("AceDB-3.0"):New("draeChatCharDB")	-- Pull the profile specifically

	self.db = self.charSettings.profile
	self.db.ChatEditHistory = self.db.ChatEditHistory or {}
	self.db.ChatLog = self.db.ChatLog or {}
end

Chat.OnEnable = function(self)
	-- Get rid of some stuff we're not interested in
	FriendsMicroButton:UnregisterAllEvents()
	FriendsMicroButton:Hide()
	ChatFrameMenuButton:UnregisterAllEvents()
	ChatFrameMenuButton:Hide()

	self:UpdateFading()
	self:SecureHook("ChatEdit_OnEnterPressed")

	self:SecureHook("FCF_SetChatWindowFontSize", "SetChatFont")
	self:RegisterEvent("PLAYER_ENTERING_WORLD", "DelayGMOTD")
	self:RegisterEvent("UPDATE_CHAT_WINDOWS", "SetupChat")
	self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "SetupChat")
	self:RegisterEvent("PET_BATTLE_CLOSE")

	self:SetupChat()
	self:PositionChat(true)

	self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_INSTANCE_CHAT_LEADER", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_CHANNEL", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_EMOTE", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_GUILD", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_GUILD_ACHIEVEMENT", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_OFFICER", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_PARTY", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_PARTY_LEADER", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_RAID", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_RAID_LEADER", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_RAID_WARNING", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_SAY", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_WHISPER", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "SaveChatHistory")
	self:RegisterEvent("CHAT_MSG_YELL", "SaveChatHistory")

	--First get all pre-existing filters and copy them to our version of chatFilters using ChatFrame_GetMessageEventFilters
	for name, _ in pairs(ChatTypeGroup) do
		for i = 1, #ChatTypeGroup[name] do
			local filterFuncTable = ChatFrame_GetMessageEventFilters(ChatTypeGroup[name][i])
			if filterFuncTable then
				chatFilters[ChatTypeGroup[name][i]] = {}

				for j = 1, #filterFuncTable do
					local filterFunc = filterFuncTable[j]
					tinsert(chatFilters[ChatTypeGroup[name][i]], filterFunc)
				end
			end
		end
	end

	-- CHAT_MSG_CHANNEL isn"t located inside ChatTypeGroup
	local filterFuncTable = ChatFrame_GetMessageEventFilters("CHAT_MSG_CHANNEL")
	if filterFuncTable then
		chatFilters["CHAT_MSG_CHANNEL"] = {}

		for j = 1, #filterFuncTable do
			local filterFunc = filterFuncTable[j]
			tinsert(chatFilters["CHAT_MSG_CHANNEL"], filterFunc)
		end
	end

	--Now hook onto Blizzards functions for other addons
	self:SecureHook("ChatFrame_AddMessageEventFilter")
	self:SecureHook("ChatFrame_RemoveMessageEventFilter")
	self:SecureHook("FCF_SetWindowAlpha")

	ChatFrame_AddMessageEventFilter("CHAT_MSG_CHANNEL", Chat.CHAT_MSG_CHANNEL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_YELL", Chat.CHAT_MSG_YELL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", Chat.CHAT_MSG_SAY)

	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER_INFORM", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_WHISPER", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_GUILD", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_OFFICER", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_PARTY_LEADER", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_RAID_LEADER", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_INSTANCE_CHAT_LEADER", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_CONVERSATION", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_WHISPER_INFORM", Chat.FindURL)
	ChatFrame_AddMessageEventFilter("CHAT_MSG_BN_INLINE_TOAST_BROADCAST", Chat.FindURL)

	self.SoundPlayed = true
	self.SoundPlayed = nil

	local frame = CreateFrame("Frame", "CopyChatFrame", UIParent)
	frame:SetBackdrop({
		bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
		edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
		edgeSize = 16, tileSize = 16, tile = true,
		insets = { left = 3, right = 3, top = 5, bottom = 3 }
	})
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:SetFrameStrata("DIALOG")
	frame:EnableMouse(true)
	frame:Point("LEFT", 5, 10)
	frame:Height(400)
	frame:Width(500)
	frame:Hide()

	tinsert(UISpecialFrames, "CopyChatFrame")

	local scrollArea = CreateFrame("ScrollFrame", "CopyChatScrollFrame", frame, "UIPanelScrollFrameTemplate")
	scrollArea:Point("TOPLEFT", 13, -30)
	scrollArea:Point("BOTTOMRIGHT", -30, 13)

	local editBox = CreateFrame("EditBox", "CopyChatFrameEditBox", frame)
	editBox:SetMultiLine(true)
	editBox:SetMaxLetters(20000)
	editBox:EnableMouse(true)
	editBox:SetAutoFocus(true)
	editBox:SetFontObject(ChatFontNormal)
	editBox:Width(450)
	editBox:Height(270)
	editBox:SetScript("OnEscapePressed", function() frame:Hide() end)

	scrollArea:SetScrollChild(editBox)

	local close = CreateFrame("Button", "CopyChatFrameCloseButton", frame, "UIPanelCloseButton")
	close:Point("TOPRIGHT", 0, -1)

	StaticPopupDialogs.URL_COPY_DIALOG = {
		text = "URL",
		button2 = CLOSE,
		hasEditBox = 1,
		maxLetters = 1024,
		editBoxWidth = 350,
		hideOnEscape = 1,
		showAlert = 1,
		timeout = 0,
		whileDead = 1,
		preferredIndex = 3, -- helps prevent taint; see http://forums.wowace.com/showthread.php?t=19960
		OnShow = function(self)
			(self.icon or _G[self:GetName().."AlertIcon"]):Hide()

			local editBox = self.editBox or _G[self:GetName().."EditBox"]
			editBox:SetText(currentURL)
			editBox:SetFocus()
			editBox:HighlightText(0)

			local button2 = self.button2 or _G[self:GetName().."Button2"]
			button2:ClearAllPoints()
			button2:Point("TOP", editBox, "BOTTOM", 0, -6)
			button2:Width(150)

			currentURL = nil
		end,
		EditBoxOnEscapePressed = function(self)
			self:GetParent():Hide()
		end,
	}

	--Disable Blizzard
	InterfaceOptionsSocialPanelTimestampsButton:SetAlpha(0)
	InterfaceOptionsSocialPanelTimestampsButton:SetScale(0.000001)
	InterfaceOptionsSocialPanelTimestamps:SetAlpha(0)
	InterfaceOptionsSocialPanelTimestamps:SetScale(0.000001)
	InterfaceOptionsSocialPanelChatStyle:EnableMouse(false)
	InterfaceOptionsSocialPanelChatStyleButton:Hide()
	InterfaceOptionsSocialPanelChatStyle:SetAlpha(0)

	if (self.db.ChatLog) then
		self:DisplayChatHistory()
	end
end
