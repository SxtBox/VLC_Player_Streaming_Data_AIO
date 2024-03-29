--[[
 $Id$
 Copyright © 2007-2022 the VideoLAN team
 Dailymotion Playlist importer for VLC media player 1.x 2.x 3.x
 Tested on VLC Player 3.0.16
 Support links: Video, Live Streams, and Playlists
 To play videos need to paste dailymotion.lua in C:\Program Files (x86)\VideoLAN\VLC\lua\playlist
 Modified: TRC4 <trc4@usa.com>
--]]

function probe()
  return (vlc.access == "http" or vlc.access == "https") and string.match(vlc.path, "^www%.dailymotion%.com/video/")
end
function parse()
  while true do
    line = vlc.readline()
    if not line then
      break
    end
    if string.match(line, "<meta property=\"og:title\"") then
      _, _, name = string.find(line, "content=\"(.-)\"")
      name = vlc.strings.resolve_xml_special_chars(name)
      name = string.gsub(name, " %- [^ ]+ [Dd]ailymotion$", "")
    end
    if string.match(line, "<meta name=\"description\"") then
      _, _, description = string.find(line, "content=\"(.-)\"")
      if description ~= nil then
        description = vlc.strings.resolve_xml_special_chars(description)
      end
    end
    if string.match(line, "<meta property=\"og:image\"") then
      arturl = string.match(line, "content=\"(.-)\"")
    end
  end
  local video_id = string.match(vlc.path, "^www%.dailymotion%.com/video/([^/?#]+)")
  if video_id then
    local metadata = vlc.stream(vlc.access .. "://www.dailymotion.com/player/metadata/video/" .. video_id)
    if metadata then
      local line = metadata:readline()
      artist = string.match(line, "\"username\":\"([^\"]+)\"")
      local poster = string.match(line, "\"poster_url\":\"([^\"]+)\"")
      if poster then
        arturl = string.gsub(poster, "\\/", "/")
      end
      local streams = string.match(line, "\"qualities\":{(.-%])}")
      if streams then
        local prefres = vlc.var.inherit(nil, "preferred-resolution")
        local file, live
        for height, stream in string.gmatch(streams, "\"(%w+)\":%[(.-)%]") do
          if string.match(height, "^(%d+)$") and (not file or prefres < 0 or prefres >= tonumber(height)) then
            local f = string.match(stream, "\"type\":\"video\\/[^\"]+\",\"url\":\"([^\"]+)\"")
            if f then
              file = f
            end
          end
          live = live or string.match(stream, "\"type\":\"application\\/x%-mpegURL\",\"url\":\"([^\"]+)\"")
        end
        path = file or live
        if path then
          path = string.gsub(path, "\\/", "/")
        end
      end
    end
  end
  if not path then
    vlc.msg.err("Couldn't extract dailymotion video URL, please check for updates to this script")
    return {}
  end
  return {
    {
      path = path,
      name = name,
      description = description,
      arturl = arturl,
      artist = artist
    }
  }
end
