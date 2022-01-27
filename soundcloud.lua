--[[
 $Id$
 Copyright © 2007-2022 the VideoLAN team
 Soundcloud Playlist importer for VLC media player 1.x 2.x 3.x
 Tested on VLC Player 3.0.16
 To play videos need to paste soundcloud.lua in C:\Program Files (x86)\VideoLAN\VLC\lua\playlist
 Modified: TRC4 <trc4@usa.com>
 Example URL: https://soundcloud.com/sxtbox/trc4-deejay-dance-with-the
--]]

-- Probe function
function probe()
  local path = vlc.path
  path = path:gsub("^www%.", "")
  return (vlc.access == "http" or vlc.access == "https") and string.match(path, "^soundcloud%.com/.+/.+")
end

function fix_quotes(value)
  if string.match(value, "^\"") then
    return ""
  end
  return string.gsub(value, "\\\"", "\"")
end

function extract_magic(url)
  local s = vlc.stream(url)
  if not s then
    return nil
  end
  local line = s:read(4194304)
  if not line then
    return nil
  end
  local client_id = string.match(line, "[{,]client_id:\"(%w+)\"[},]")
  if client_id then
    vlc.msg.dbg("Soundcloud Found API Magic")
    return client_id
  end
  return nil
end

-- Parse function
function parse()
  while true do
    local line = vlc.readline()
    if not line then
      break
    end
    if not stream then
      stream = string.match(line, "\"url\":\"([^\"]-/stream/progressive[^\"]-)\"")
    end
    if not client_id then
      local script = string.match(line, "<script( .-)>")
      if script then
        local src = string.match(script, " src=\"(.-)\"")
        if src then
          client_id = extract_magic(src)
        end
      end
    end
    if not name then
      name = string.match(line, "[\"']title[\"'] *: *\"(.-[^\\])\"")
      if name then
        name = fix_quotes(name)
      end
    end
    if not description then
      description = string.match(line, "[\"']artwork_url[\"'] *:.-[\"']description[\"'] *: *\"(.-[^\\])\"")
      if description then
        description = fix_quotes(description)
      end
    end
    if not artist then
      artist = string.match(line, "[\"']username[\"'] *: *\"(.-[^\\])\"")
      if artist then
        artist = fix_quotes(artist)
      end
    end
    if not arturl then
      arturl = string.match(line, "[\"']artwork_url[\"'] *: *[\"'](.-)[\"']")
    end
  end
  if stream then
    if client_id then
      stream = stream .. (string.match(stream, "?") and "&" or "?") .. "client_id=" .. client_id
    end
    local api = vlc.stream(stream)
    if api then
      local streams = api:readline()
      path = string.match(streams, "\"url\":\"(.-)\"")
    end
  end
  if not path then
    vlc.msg.err("Couldn't extract soundcloud audio URL, please check for updates to this script")
    return {}
  end
  return {
    {
      path = path,
      name = name,
      description = description,
      artist = artist,
      arturl = arturl
    }
  }
end
