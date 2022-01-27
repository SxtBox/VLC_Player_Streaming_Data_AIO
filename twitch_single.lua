--[[
 $Id$
 Copyright © 2007-2022 the VideoLAN team
 Twitch Playlist importer for VLC media player 1.x 2.x 3.x
 Tested on VLC Player 3.0.16
 To play videos need to paste twitch_single.lua in C:\Program Files (x86)\VideoLAN\VLC\lua\playlist
 Modified: TRC4 <trc4@usa.com>

 STABLE Version Single Streams
 Example URL: https://www.twitch.tv/pulsradiocom
--]]

function probe()
  return (vlc.access == "http" or vlc.access == "https") and (vlc.path:match("^www%.twitch%.tv/videos/.+") or vlc.path:match("^www%.twitch%.tv/.+") or vlc.path:match("^go%.twitch%.tv/.+") or vlc.path:match("^go%.twitch%.tv/videos/.+"))
end

function parse_json(url)
  local json = require("dkjson")
  local stream = vlc.stream(url)
  local string = ""
  local line = ""
  if not stream then
    return nil, nil, "Failed creating VLC stream"
  end
  while true do
    line = stream:readline()
    if not line then
      break
    end
    string = string .. line
  end
  return json.decode(string)
end

function twitch_api_req(url)
-- If Twitch decides to block this client_id, you can replace it here:
  local obj, pos, err = parse_json(url .. "?client_id=jzkbprff40iqj646a697cyrvl0zt2m6")
-- local obj, pos, err = parse_json(url .. "?client_id=jzkbprff40iqj646a697cyrvl0zt2m6")
  if err then
    return nil, "Error To Getting JSON Object: " .. err
  end
  if obj.error then
    local err = "Twitch API Error: " .. obj.error
    if obj.message then
      err = err .. " (" .. obj.message .. ")"
    end
    return nil, err
  end
  return obj, nil
end

function parse_video()
  local playlist = {}
  local item = {}
  local url, obj, err
  local video_id = vlc.path:match("/videos/(%d+)")
  if video_id == nil then
    vlc.msg.err("Twitch: Failed to parse twitch url for video id")
    return playlist
  end
  vlc.msg.dbg("Twitch: Loading video url for " .. video_id)
  url = "https://api.twitch.tv/api/vods/" .. video_id .. "/access_token"
  obj, err = twitch_api_req(url)
  if err then
    vlc.msg.err("Error getting request token from Twitch: " .. err)
    return playlist
  end
  local stream_url = "http://usher.twitch.tv/vod/" .. video_id
  stream_url = stream_url .. "?player=twitchweb"
  stream_url = stream_url .. "&nauth=" .. vlc.strings.encode_uri_component(obj.token)
  stream_url = stream_url .. "&nauthsig=" .. obj.sig
  stream_url = stream_url .. "&allow_audio_only=true&allow_source=true"
  item.path = stream_url
  item.name = "Twitch: " .. video_id
  url = "https://api.twitch.tv/kraken/videos/v" .. video_id
  obj, err = twitch_api_req(url)
  if err then
    vlc.msg.warn("Error getting video info from Twitch: " .. err)
    table.insert(playlist, item)
    return playlist
  end
  item.name = "Twitch: " .. obj.title
  item.artist = obj.channel.display_name
  item.description = obj.description
  item.url = vlc.path
  table.insert(playlist, item)
  return playlist
end

function parse_stream()
  local playlist = {}
  local item = {}
  local url, obj, err
  local channel = vlc.path:match("/([a-zA-Z0-9_]+)")
  if channel == nil then
    vlc.msg.err("Twitch: Failed to parse twitch url for channel name")
    return playlist
  end
  vlc.msg.dbg("Twitch: Loading stream url for " .. channel)
  url = "https://api.twitch.tv/api/channels/" .. channel .. "/access_token"
  obj, err = twitch_api_req(url)
  if err then
    vlc.msg.err("Error getting request token from Twitch: " .. err)
    return playlist
  end
  local stream_url = "http://usher.twitch.tv/api/channel/hls/" .. channel .. ".m3u8"
  stream_url = stream_url .. "?player=twitchweb"
  stream_url = stream_url .. "&token=" .. vlc.strings.encode_uri_component(obj.token)
  stream_url = stream_url .. "&sig=" .. obj.sig
  stream_url = stream_url .. "&allow_audio_only=true&allow_source=true&type=any"
  item.path = stream_url
  item.name = "Twitch: " .. channel
  item.artist = channel
  url = "https://api.twitch.tv/api/channels/" .. channel
  obj, err = twitch_api_req(url)
  if err then
    vlc.msg.warn("Error getting channel info from Twitch: " .. err)
    table.insert(playlist, item)
    return playlist
  end
  item.name = "Twitch: " .. obj.display_name
  item.nowplaying = obj.display_name .. " playing " .. obj.game
  item.artist = obj.display_name
  item.description = obj.status
  item.url = vlc.path
  table.insert(playlist, item)
  return playlist
end

function parse()
  if vlc.path:match("/videos/.+") then
    return parse_video()
  else
    return parse_stream()
  end
end
