--[[

 Youtube playlist importer for VLC media player 1.x 2.x 3.x

  Modified: TRC4 <trc4@usa.com>

--]]

-- Helper function to get a parameter's value in a URL
function get_url_param( url, name )
     local _, _, res = string.find( url, "[&?]"..name.."=([^&]*)" )
     return res
end
 
-- Probe function.
function probe()
     if vlc.access ~= "http" and vlc.access ~= "https" then
	     return false
     end
	     
     return string.match(vlc.path:match("([^/]+)"),"%w+.youtube.com") and (string.match(vlc.path, "list=")) and string.match(vlc.path, "action_get_list") == nil
end
 
-- Parse function.
function parse()
	if string.match( vlc.path, "list=" ) then
		local playlist_parsed, playlistData, line, s, item
		local p = {}
		local id_ref = {}
		local index = 1
		local playlistID = get_url_param( vlc.path, "list" )
		local videoID = get_url_param( vlc.path, "v" )
		local playlistURL = "http://www.youtube.com/list_ajax?action_get_list=1&style=xml&list="..playlistID

		while true do
			playlistData = ""
			line = ""
			s = nil
			s = vlc.stream(playlistURL.."&index="..index)
			while line do
				playlistData = playlistData..line
				line = s:readline()
			end

			playlist_parsed = nil
			playlist_parsed = parse_xml(playlistData).root.video
			
			for i, video in ipairs(playlist_parsed) do
				vlc.msg.err(i.." "..video.encrypted_id.CDATA)
				if id_ref[video.encrypted_id.CDATA] 
				and id_ref[video.encrypted_id.CDATA] == i
				then
					return p
				else
					id_ref[video.encrypted_id.CDATA] = i
				end
				
				item = nil
				item = {}
				
				if video.encrypted_id 
				and video.encrypted_id.CDATA then
					item.path = "http://www.youtube.com/watch?v="..video.encrypted_id.CDATA
				end
				
				if video.title 
				and video.title.CDATA then
					item.title = video.title.CDATA
				end
				
				if video.artist 
				and video.artist.CDATA then
					item.artist = video.artist.CDATA
				end
				
				if video.thumbnail 
				and video.thumbnail.CDATA then
					item.arturl = video.thumbnail.CDATA
				end
				
				if video.description 
				and video.description.CDATA then
					item.description = video.description.CDATA
				end
				
				--~ item.rating = video.rating
				table.insert (p, item)
			end
			if #playlist_parsed == 100 then
				index = index +100
			else
				return p
			end
		end
	end
end
 
 
function parse_xml(data)
	local tree = {}
	local stack = {}
	local tmp = {}
	local tmpTag = ""
	local level = 0

	table.insert(stack, tree)

	for op, tag, attr, empty, val in string.gmatch(
		data, 
		"<(%p?)([^%s>/]+)([^>]-)(%/?)>[%s\r\n\t]*([^<]*)[%s\r\n\t]*") do
		if op=="?" then
			--~ DOCTYPE
		elseif op=="/" then
			if level>0 then
			level = level - 1
			table.remove(stack)
			end
		else
		level = level + 1

		if op=="!" then
			stack[level]['CDATA'] = vlc.strings.resolve_xml_special_chars(
			string.gsub(tag..attr, "%[CDATA%[(.+)%]%]", "%1"))
			attr = ""
			level = level - 1
		elseif type(stack[level][tag]) == "nil" then
			stack[level][tag] = {}
			table.insert(stack, stack[level][tag])
		else
			if type(stack[level][tag][1]) == "nil" then
			 tmp = nil
			 tmp = stack[level][tag]
			 stack[level][tag] = nil
			 stack[level][tag] = {}
			 table.insert(stack[level][tag], tmp)
			end
			tmp = nil
			tmp = {}
			table.insert(stack[level][tag], tmp)
			table.insert(stack, tmp)
			end

			if val~="" then
			stack[level][tag]['CDATA'] = {}
			stack[level][tag]['CDATA'] = vlc.strings.resolve_xml_special_chars(val)
			end

			if attr ~= "" then
			stack[level][tag]['ATTR'] = {}
				string.gsub(attr, 
				"(%w+)=([\"'])(.-)%2", 
				function (name, _, value)
				 stack[level][tag]['ATTR'][name] = value
				end)
			end

			if empty ~= "" then
				level = level - 1
				table.remove(stack)
			end
		end
	end
	return tree
end