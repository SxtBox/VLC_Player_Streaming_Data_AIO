--[[
 $Id$
 Copyright © 2007-2022 the VideoLAN team
 Twitch Playlist importer for VLC media player 1.x 2.x 3.x
 Tested on VLC Player 3.0.16
 To play videos need to paste twitch_multi.lua in C:\Program Files (x86)\VideoLAN\VLC\lua\playlist
 Modified: TRC4 <trc4@usa.com>

 STABLE Version Multi Streams
 Example URL: https://www.twitch.tv/pulsradiocom
--]]

function json_dump(t)
  local json = require("dkjson")
  return json.encode(t, { indent=true })
end

function parse_json(str)
  vlc.msg.dbg("Parsing JSON: " .. str)
  local json = require("dkjson")
  return json.decode(str)
end

function get_json(url)
  vlc.msg.dbg("Getting JSON from " .. url)

  local stream = vlc.stream(url)
  local data = ""
  local line = ""

  if not stream then return false end

  while true do
    line = stream:readline()
    if not line then break end
    data = data .. line
  end

  return parse_json(data)
end

function get_streams(url, title, channel, status, game, date)
  vlc.msg.dbg("Getting items from " .. url)
  -- #EXTM3U
  -- #EXT-X-TWITCH-INFO:NODE="video-edge-c9010c.lax03",MANIFEST-NODE-TYPE="legacy",MANIFEST-NODE="video-edge-c9010c.lax03",SUPPRESS="false",SERVER-TIME="1483827093.91",USER-IP="76.94.205.190",SERVING-ID="4529b3c0570a46c8b3ed902f68b8368f",CLUSTER="lax03",ABS="false",BROADCAST-ID="24170411392",STREAM-TIME="5819.9121151",MANIFEST-CLUSTER="lax03"
  -- #EXT-X-MEDIA:TYPE=VIDEO,GROUP-ID="chunked",NAME="Source",AUTOSELECT=YES,DEFAULT=YES
  -- #EXT-X-STREAM-INF:PROGRAM-ID=1,BANDWIDTH=2838000,RESOLUTION=1280x720,VIDEO="chunked"

  local stream = vlc.stream(url)
  if not stream then return false end

  local items = {}
  local name = "error"
  -- local resolution = "error"

  while true do
    local line = stream:readline()
    if not line then break end
    if string.find(line, "^#.*NAME=") then
      name = string.match(line, "NAME=\"?([a-zA-Z0-9_ \(\)]+)\"?")
      if name == "1080p (source)" then
        name = "1080p"
      elseif name == "audio_only" then
        name = "Audio Only"
      end
    -- elseif string.find(line, "^#.*RESOLUTION=") then
    --   resolution = string.match(line, "RESOLUTION=\"?([0-9x]+)\"?")
    elseif string.find(line, "^http") then
      table.insert(items, { path=line, name=title.." ["..name.."] "..status, artist=channel, genre=game, date=date })
      -- Uncomment the line below to only have the best quality stream appear
      -- break
    end
  end

  return items
end

function url_encode(str)
  str = string.gsub(str, "\n", "\r\n")
  str = string.gsub(str, "([^%w %-%_%.%~])", function(c) return string.format("%%%02X", string.byte(c)) end)
  str = string.gsub(str, " ", "+")
  return str
end

function unescape(str)
  str = string.gsub( str, '&lt;', '<' )
  str = string.gsub( str, '&gt;', '>' )
  str = string.gsub( str, '&quot;', '"' )
  str = string.gsub( str, '&apos;', "'" )
  str = string.gsub( str, '&#(%d+);', function(n) return string.char(n) end )
  str = string.gsub( str, '&#x(%d+);', function(n) return string.char(tonumber(n,16)) end )
  str = string.gsub( str, '&amp;', '&' ) -- Be sure to do this after all others
  return str
end

function string.starts(haystack, needle)
  return string.sub(haystack, 1, string.len(needle)) == needle
end

function duration(seconds)
  local s = math.fmod(seconds, 60)
  local m = math.fmod(seconds / 60, 60)
  local h = math.floor(seconds / 3600)
  if h > 0 then
    return string.format("%d:%02d:%02d", h, m, s)
  else
    return string.format("%d:%02d", m, s)
  end
end

function probe()
  return (vlc.access == "http" or vlc.access == "https") and (string.starts(vlc.path, "www.twitch.tv/") or string.starts(vlc.path, "go.twitch.tv/") or string.starts(vlc.path, "player.twitch.tv/") or (string.starts(vlc.path, "clips.twitch.tv/") and not string.starts(vlc.path, "clips.twitch.tv/api/")))
end

function parse()
  -- If Twitch decides to block this client_id, you can replace it here:
  local client_id = "jzkbprff40iqj646a697cyrvl0zt2m6"
  local limit = 25 -- max is 100
  local language = "" -- empty means all languages, set to "en" for only english streams
  local items = {}

  if string.find(vlc.path, "clips.twitch.tv/([^/?#]+)") or string.find(vlc.path, "/clip/([^/?#]+)") then
    -- https://clips.twitch.tv/AmazonianKnottyLapwingSwiftRage
    -- https://www.twitch.tv/gamesdonequick/clip/ExuberantMiniatureSandpiperDogFace
    local slug = string.match(vlc.path, "clips.twitch.tv/([^/?#]+)") or string.match(vlc.path, "/clip/([^/?#]+)")
    local clip = get_json("https://clips.twitch.tv/api/v2/clips/"..slug.."/status")
    -- vlc.msg.info(json_dump(clip))

    if clip then
      for _, stream in ipairs(clip["quality_options"]) do
        if stream["quality"] ~= "source" then
          stream["quality"] = stream["quality"].."p"
        end
        table.insert(items, { path=stream["source"], name="[clip] "..slug.." ("..stream["quality"].." @ "..stream["frame_rate"].." fps)" })
        if string.match(vlc.path, "quality=best") then break end
      end
    end
  elseif vlc.path == "www.twitch.tv/" then
    -- https://www.twitch.tv/
    local data = get_json("https://api.twitch.tv/kraken/streams/featured?limit=6&geo=US&lang=en&on_site=1&client_id="..client_id)
    -- vlc.msg.info(json_dump(data))
    local featured = data["featured"]
    for _, featured in ipairs(data["featured"]) do
      local channel = featured["stream"]["channel"]["name"]
      local game = featured["stream"]["channel"]["game"]
      local title = "[featured] "..channel
      if game ~= nil then
        title = title.." playing "..game
      end
      title = title.." - "..featured["stream"]["channel"]["status"]
      table.insert(items, { path="https://www.twitch.tv/"..channel, name=title })
    end
  elseif string.find(vlc.path,"twitch.tv/directory/game/([^/?#]+)/clips") then
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/clips?range=7d
    local game = string.match(vlc.path, "/directory/game/([^/?#]+)")
    local cursor = string.match(vlc.path, "cursor=(.+)") or ""
    local data = get_json("https://api.twitch.tv/kraken/clips/top?game="..game.."&client_id="..client_id.."&api_version=5&limit="..limit.."&cursor="..cursor)
    if data then
      -- vlc.msg.info(json_dump(data))
      for _, clip in ipairs(data["clips"]) do
        local channel = clip["broadcaster"]["name"]
        local title = "[clip] ["..duration(clip["duration"]).."] "..clip["title"]
        table.insert(items, { path="https://clips.twitch.tv/"..clip["slug"].."?quality=best", name=title, artist=channel, genre=clip["game"] })
      end
      if data["_cursor"] ~= "" then
        table.insert(items, { path="https://www.twitch.tv/directory/game/"..game.."/clips?cursor="..data["_cursor"], name="Load more" })
      end
    else
      vlc.msg.info("Game "..game.." does not exists.")
      table.insert(items, { path="", name="Game "..game.." does not exists." })
    end
  elseif string.find(vlc.path,"twitch.tv/directory/game/([^/?#]+)/videos/") then
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/all (same as sort=views)
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/all?sort=time
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/all?sort=views
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/past_premiere
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/archive
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/highlight
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past/videos/upload
    local game, type = string.match(vlc.path, "/directory/game/([^/?#]+)/videos/([^/?#]+)")
    local sort = string.match(vlc.path, "sort=([^&]+)") or "views"
    local offset = string.match(vlc.path, "offset=(.+)") or "0"
    local data = get_json("https://api.twitch.tv/kraken/videos/top?game="..game.."&sort="..sort.."&broadcast_type="..type.."&client_id="..client_id.."&api_version=5&limit="..limit.."&offset="..offset)
    for _, video in ipairs(data["vods"]) do
      local video_id = string.match(video["_id"], "v(%d+)") or video["_id"]
      local channel = video["channel"]["name"]
      local date = string.match(video["created_at"], "([%d-]+)T")
      local full_date = string.gsub(video["created_at"], "[TZ]", " ")
      local title = "[vod "..video_id.."] ["..date.."] ["..duration(video["length"]).."] "..video["title"]
      table.insert(items, { path="https://www.twitch.tv/"..channel.."/video/"..video_id, name=title, artist=channel, genre=video["game"], date=full_date })
    end
    table.insert(items, { path="https://www.twitch.tv/directory/game/"..game.."/videos/all?sort="..sort.."&offset="..(offset+limit), name="Load more" })
  elseif string.find(vlc.path,"twitch.tv/directory/game/([^/?#]+)") then
    -- https://www.twitch.tv/directory/game/The%20Legend%20of%20Zelda%3A%20A%20Link%20to%20the%20Past
    local game = string.match(vlc.path, "/directory/game/([^/?#]+)")
    local offset = string.match(vlc.path, "offset=(.+)") or "0"
    local data = get_json("https://api.twitch.tv/kraken/streams?game="..game.."&client_id="..client_id.."&api_version=5&limit="..limit.."&language="..language.."&offset="..offset)
    -- vlc.msg.info(json_dump(data))
    for _, stream in ipairs(data["streams"]) do
      local channel = stream["channel"]["name"]
      local title = "[live] "..stream["channel"]["name"].." - "..stream["channel"]["status"]
      table.insert(items, { path="https://www.twitch.tv/"..channel, name=title, artist=channel, genre=stream["game"] })
    end
    table.insert(items, { path="https://www.twitch.tv/directory/game/"..game.."?offset="..(offset+limit), name="Load more" })
  elseif string.find(vlc.path,"twitch.tv/communities/") then
    -- https://www.twitch.tv/communities/speedrunning
    local name = string.match(vlc.path, "/communities/([a-zA-Z0-9_.-]+)"):lower()
    local offset = string.match(vlc.path, "offset=(.+)") or "0"
    local cdata = get_json("https://api.twitch.tv/kraken/communities?name="..name.."&client_id="..client_id.."&api_version=5")
    if cdata then
      -- vlc.msg.info(json_dump(cdata))
      local data = get_json("https://api.twitch.tv/kraken/streams?community_id="..cdata["_id"].."&client_id="..client_id.."&api_version=5&limit="..limit.."&language="..language.."&offset="..offset)
      -- vlc.msg.info(json_dump(data))
      for _, stream in ipairs(data["streams"]) do
        local channel = stream["channel"]["name"]
        local title = "[live] "..stream["channel"]["name"].." playing "..stream["game"].." - "..stream["channel"]["status"]
        table.insert(items, { path="https://www.twitch.tv/"..channel, name=title, artist=channel, genre=stream["game"] })
      end
      table.insert(items, { path="https://www.twitch.tv/communities/"..name.."?offset="..(offset+limit), name="Load more" })
    else
      vlc.msg.info("Community "..name.." does not exists.")
      table.insert(items, { path="", name="Community "..name.." does not exists." })
    end
  elseif string.find(vlc.path,"twitch.tv/([^/?#]+)/videos%?filter=clips") or string.find(vlc.path,"twitch.tv/([^/?#]+)/clips") then
    -- https://www.twitch.tv/speedgaming/videos?filter=clips&range=7d
    -- https://www.twitch.tv/speedgaming/clips (legacy url)
    local channel = string.match(vlc.path, "twitch.tv/([^/?#]+)/")
    local cursor = string.match(vlc.path, "cursor=(.+)") or ""
    local data = get_json("https://api.twitch.tv/kraken/clips/top?channel="..channel.."&client_id="..client_id.."&api_version=5&limit="..limit.."&cursor="..cursor)
    if data then
      -- vlc.msg.info(json_dump(data))
      for _, clip in ipairs(data["clips"]) do
        local title = "[clip] ["..duration(clip["duration"]).."] "..clip["title"]
        table.insert(items, { path="https://clips.twitch.tv/"..clip["slug"].."?quality=best", name=title, artist=channel, genre=clip["game"] })
      end
      if data["_cursor"] ~= "" then
        table.insert(items, { path="https://www.twitch.tv/"..channel.."/videos?filter=clips&cursor="..data["_cursor"], name="Load more" })
      end
    else
      vlc.msg.info("Channel "..channel.." does not exists.")
      table.insert(items, { path="", name="Channel "..channel.." does not exists." })
    end
  elseif string.find(vlc.path,"twitch.tv/([^/?#]+)/videos%?filter=collections") then
    -- https://www.twitch.tv/speedgaming/videos?filter=collections&sort=time
    local channel = string.match(vlc.path, "twitch.tv/([^/?#]+)/")
    local cursor = string.match(vlc.path, "cursor=(.+)") or ""
    local cdata = get_json("https://api.twitch.tv/kraken/users?login="..channel.."&client_id="..client_id.."&api_version=5")
    if cdata["_total"] ~= 0 then
      local channel_id = cdata["users"][1]["_id"]
      local data = get_json("https://api.twitch.tv/kraken/channels/"..channel_id.."/collections?client_id="..client_id.."&api_version=5&limit="..limit.."&cursor="..cursor)
      -- vlc.msg.info(json_dump(data))
      for _, collection in ipairs(data["collections"]) do
        local title = "[collection] ["..duration(collection["total_duration"]).."] "..collection["title"]
        table.insert(items, { path="https://www.twitch.tv/collections/"..collection["_id"], name=title, artist=channel })
      end
      if data["_cursor"] ~= nil then
        table.insert(items, { path="https://www.twitch.tv/"..channel.."/videos?filter=collections&cursor="..data["_cursor"], name="Load more" })
      end
    else
      vlc.msg.info("Channel "..channel.." does not exists.")
      table.insert(items, { path="", name="Channel "..channel.." does not exists." })
    end
  elseif string.find(vlc.path,"twitch.tv/([^/?#]+)/videos%?filter=([^&#]+)") or string.find(vlc.path,"twitch.tv/([^/?#]+)/videos/([^/?#]+)") or string.find(vlc.path,"twitch.tv/([^/?#]+)/videos") then
    -- https://www.twitch.tv/speedgaming/videos?filter=all&sort=time
    -- https://www.twitch.tv/speedgaming/videos?filter=archives&sort=time
    -- https://www.twitch.tv/speedgaming/videos?filter=highlights&sort=time
    -- https://www.twitch.tv/speedgaming/videos (same as /videos/all)
    -- https://www.twitch.tv/speedgaming/videos/all (legacy url)
    -- https://www.twitch.tv/speedgaming/videos/upload (legacy url)
    -- https://www.twitch.tv/speedgaming/videos/archive (legacy url)
    -- https://www.twitch.tv/speedgaming/videos/highlight (legacy url)
    local channel, type = string.match(vlc.path, "/([^/?#]+)/videos%?filter=([^&#]+)")
    if type == nil then
      channel, type = string.match(vlc.path, "/([^/?#]+)/videos/([^/?#]+)")
      if type == nil then
        channel = string.match(vlc.path, "/([^/?#]+)/videos")
        type = "all"
      end
    end
    if type == "archives" then
      type = "archive"
    end
    if type == "highlights" then
      type = "highlight"
    end
    local offset = string.match(vlc.path, "offset=(.+)") or "0"
    local data = get_json("https://api.twitch.tv/kraken/channels/"..channel.."/videos?client_id="..client_id.."&api_version=3&broadcast_type="..type.."&limit="..limit.."&offset="..offset)
    -- vlc.msg.info(json_dump(data))
    for _, video in ipairs(data["videos"]) do
      -- skip if the video is being recorded (i.e. stream is live) since there are usually issues playing them
      -- you can still use a direct link to the video if you want to try anyway
      if video["status"] ~= "recording" then
        local video_id = string.match(video["_id"], "v(%d+)") or video["_id"]
        local channel = video["channel"]["name"]
        local date = string.match(video["created_at"], "([%d-]+)T")
        local full_date = string.gsub(video["created_at"], "[TZ]", " ")
        local title = "[vod "..video_id.."] ["..date.."] ["..duration(video["length"]).."] "..video["title"]
        table.insert(items, { path="https://www.twitch.tv/"..channel.."/video/"..video_id, name=title, artist=channel, genre=video["game"], date=full_date })
      end
    end
    table.insert(items, { path="https://www.twitch.tv/"..channel.."/videos/"..type.."?offset="..(offset+limit), name="Load more" })
  elseif string.find(vlc.path,"/video/") or string.find(vlc.path,"twitch.tv/videos/") or string.find(vlc.path,"video=") or string.find(vlc.path,"twitch.tv/collections/") then
    -- https://www.twitch.tv/gamesdonequick/video/113837699
    -- https://www.twitch.tv/videos/113837699 (legacy url)
    -- https://www.twitch.tv/gamesdonequick/v/113837699 (legacy url, will redirect to /videos/ so we don't need to check for it)
    -- https://player.twitch.tv/?video=v113837699 ("v" is optional)
    -- https://www.twitch.tv/collections/k2Ou9QRbAhUMPw
    -- https://www.twitch.tv/videos/112628247?collection=k2Ou9QRbAhUMPw

    local collection_id = string.match(vlc.path, "[?&]collection=([^&#]+)") or string.match(vlc.path, "/collections/([^/?#]+)")
    if collection_id ~= nil then
      local data = get_json("https://api.twitch.tv/kraken/collections/"..collection_id.."/items?client_id="..client_id.."&api_version=5")
      for _, video in ipairs(data["items"]) do
        local video_id = video["item_id"]
        local channel = video["owner"]["name"]
        local date = string.match(video["published_at"], "([%d-]+)T")
        local full_date = string.gsub(video["published_at"], "[TZ]", " ")
        local title = "[vod "..video_id.."] ["..date.."] ["..duration(video["duration"]).."] "..video["owner"]["name"].." - "..video["title"]
        table.insert(items, { path="https://www.twitch.tv/"..channel.."/video/"..video_id, name=title, artist=channel, genre=video["game"], date=full_date })
      end
    else
      local video_id = string.match(vlc.path, "/video/(%d+)") or string.match(vlc.path, "/videos/(%d+)") or string.match(vlc.path, "video=v?(%d+)")
      local video = get_json("https://api.twitch.tv/kraken/videos/"..video_id.."?client_id="..client_id.."&api_version=5")

      if video then
        -- vlc.msg.info(json_dump(video))
        local access_token_data = get_json("https://api.twitch.tv/api/vods/"..video_id.."/access_token?client_id="..client_id)
        -- vlc.msg.info(json_dump(access_token_data))
        local date = string.match(video["created_at"], "([%d-]+)T")
        local full_date = string.gsub(video["created_at"], "[TZ]", " ")
        local title = "[vod "..video_id.."] ["..date.."] ["..duration(video["length"]).."]"
        local url = "http://usher.twitch.tv/vod/"..video_id.."?player=twitchweb&nauthsig="..access_token_data["sig"].."&nauth="..url_encode(access_token_data["token"]).."&allow_audio_only=true&allow_source=true"
        items = get_streams(url, title, video["channel"]["name"], video["title"], video["game"], full_date)
      else
        vlc.msg.info("Video "..video_id.." does not exists.")
        table.insert(items, { path="", name="Twitch video "..video_id.." does not exists." })
      end
    end
  else
    -- https://www.twitch.tv/speedgaming
    local channel = string.match(vlc.path, "twitch.tv/([^/?#]+)")
    vlc.msg.info(string.format("channel: %s", channel))

    local data = get_json("https://api.twitch.tv/api/channels/"..channel.."?client_id="..client_id)
    local access_token_data = get_json("https://api.twitch.tv/api/channels/"..channel.."/access_token?client_id="..client_id)
    local token_data = parse_json(access_token_data["token"])
    -- vlc.msg.info(json_dump(data))
    -- vlc.msg.info(json_dump(access_token_data))
    -- vlc.msg.info(json_dump(token_data))

    local url = "http://usher.ttvnw.net/api/channel/hls/"..token_data["channel"]..".m3u8?player=twitchweb&token="..url_encode(access_token_data["token"]).."&sig="..access_token_data["sig"].."&allow_audio_only=true&allow_source=true&allow_spectre=true"
    items = get_streams(url, "[live]", token_data["channel"], data["status"], data["game"], "")
  end

  return items
end
