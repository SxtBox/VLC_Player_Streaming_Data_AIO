--[[
 $Id$
 Copyright © 2007-2022 the VideoLAN team
 Youtube Video Player for VLC media player 1.x 2.x 3.x
 Tested on VLC Player 3.0.16
 Support links: Video, Live Streams, and Playlists
 To play videos need to paste youtube.lua in C:\Program Files (x86)\VideoLAN\VLC\lua\playlist
 Modified: TRC4 <trc4@usa.com>
--]]

-- Helper function to get a parameter's value in a URL
function get_url_param(url, name)
  local _, _, res = string.find(url, "[&?]" .. name .. "=([^&]*)")
  return res
end
function copy_url_param(url, name)
  local value = get_url_param(url, name)
  return value and "&" .. name .. "=" .. value or ""
end
function get_arturl()
  local iurl = get_url_param(vlc.path, "iurl")
  if iurl then
    return iurl
  end
  local video_id = get_url_param(vlc.path, "v")
  if not video_id then
    return nil
  end
  return vlc.access .. "://img.youtube.com/vi/" .. video_id .. "/default.jpg"
end
function get_fmt(fmt_list)
  local prefres = vlc.var.inherit(nil, "preferred-resolution")
  if prefres < 0 then
    return nil
  end
  local fmt
  for itag, height in string.gmatch(fmt_list, "(%d+)/%d+x(%d+)[^,]*") do
    fmt = itag
    if prefres >= tonumber(height) then
      break
    end
  end
  return fmt
end
function read_long_line()
  local eol
  local pos = 0
  local len = 32768
  repeat
    len = len * 2
    local line = vlc.peek(len)
    if not line then
      return nil
    end
    eol = string.find(line, "\n", pos + 1)
    pos = len
  until eol or len >= 1048576
  return vlc.read(eol or len)
end
function buf_iter(s)
  s.i = s.i + 1
  local line = s.lines[s.i]
  if not line then
    repeat
      local l = s.stream:readline()
      if not l then
        break
      end
      line = line and line .. l or l
    until string.match(line, "};$")
    if line then
      s.lines[s.i] = line
    end
  end
  return line
end
function js_extract(js, pattern)
  js.i = 0
  for line in buf_iter, js, nil do
    local ex = string.match(line, pattern)
    if ex then
      return ex
    end
  end
  vlc.msg.err("Couldn't process youtube video URL, please check for updates to this script")
  return nil
end
function js_descramble(sig, js_url)
  local js = {
    stream = vlc.stream(js_url),
    lines = {},
    i = 0
  }
  if not js.stream then
    vlc.msg.err("Couldn't process youtube video URL, please check for updates to this script")
    return sig
  end
  local descrambler = js_extract(js, "[=%(,&|](..)%(decodeURIComponent%(.%.s%)%)")
  if not descrambler then
    vlc.msg.dbg("Couldn't extract youtube video URL signature descrambling function name")
    return sig
  end
  local rules = js_extract(js, "^" .. descrambler .. "=function%([^)]*%){(.-)};")
  if not rules then
    vlc.msg.dbg("Couldn't extract youtube video URL signature descrambling rules")
    return sig
  end
  local helper = string.match(rules, ";(..)%...%(")
  if not helper then
    vlc.msg.dbg("Couldn't extract youtube video URL signature transformation helper name")
    vlc.msg.err("Couldn't process youtube video URL, please check for updates to this script")
    return sig
  end
  local transformations = js_extract(js, "[ ,]" .. helper .. "={(.-)};")
  if not transformations then
    vlc.msg.dbg("Couldn't extract youtube video URL signature transformation code")
    return sig
  end
  local trans = {}
  for meth, code in string.gmatch(transformations, "(..):function%([^)]*%){([^}]*)}") do
    if string.match(code, "%.reverse%(") then
      trans[meth] = "reverse"
    elseif string.match(code, "%.splice%(") then
      trans[meth] = "slice"
    elseif string.match(code, "var c=") then
      trans[meth] = "swap"
    else
      vlc.msg.warn("Couldn't parse unknown youtube video URL signature transformation")
    end
  end
  local missing = false
  for meth, idx in string.gmatch(rules, "..%.(..)%([^,]+,(%d+)%)") do
    idx = tonumber(idx)
    if trans[meth] == "reverse" then
      sig = string.reverse(sig)
    elseif trans[meth] == "slice" then
      sig = string.sub(sig, idx + 1)
    elseif trans[meth] == "swap" then
      if idx > 1 then
        sig = string.gsub(sig, "^(.)(" .. string.rep(".", idx - 1) .. ")(.)(.*)$", "%3%2%1%4")
      elseif idx == 1 then
        sig = string.gsub(sig, "^(.)(.)", "%2%1")
      end
    else
      vlc.msg.dbg("Couldn't apply unknown youtube video URL signature transformation")
      missing = true
    end
  end
  if missing then
    vlc.msg.err("Couldn't process youtube video URL, please check for updates to this script")
  end
  return sig
end
function stream_url(params, js_url)
  local url = string.match(params, "url=([^&]+)")
  if not url then
    return nil
  end
  url = vlc.strings.decode_uri(url)
  local s = string.match(params, "s=([^&]+)")
  if s then
    s = vlc.strings.decode_uri(s)
    vlc.msg.dbg("Found " .. string.len(s) .. "-character scrambled signature for youtube video URL, attempting to descramble... ")
    if js_url then
      s = js_descramble(s, js_url)
    else
      vlc.msg.err("Couldn't process youtube video URL, please check for updates to this script")
    end
    local sp = string.match(params, "sp=([^&]+)")
    if not sp then
      vlc.msg.warn("Couldn't extract signature parameters for youtube video URL, guessing")
      sp = "signature"
    end
    url = url .. "&" .. sp .. "=" .. vlc.strings.encode_uri_component(s)
  end
  return url
end
function pick_url(url_map, fmt, js_url)
  for stream in string.gmatch(url_map, "[^,]+") do
    local itag = string.match(stream, "itag=(%d+)")
    if not (fmt and itag) or tonumber(itag) == tonumber(fmt) then
      return stream_url(stream, js_url)
    end
  end
  return nil
end
function pick_stream(stream_map, js_url)
  local pick
  local fmt = tonumber(get_url_param(vlc.path, "fmt"))
  if fmt then
    for stream in string.gmatch(stream_map, "{(.-)}") do
      local itag = tonumber(string.match(stream, "\"itag\":(%d+)"))
      if fmt == itag then
        pick = stream
        break
      end
    end
  else
    local prefres = vlc.var.inherit(nil, "preferred-resolution")
    local bestres
    for stream in string.gmatch(stream_map, "{(.-)}") do
      local height = tonumber(string.match(stream, "\"height\":(%d+)"))
      if not pick or height and (not bestres or (prefres < 0 or prefres >= height) and bestres < height or prefres > -1 and prefres < bestres and bestres > height) then
        bestres = height
        pick = stream
      end
    end
  end
  if not pick then
    return nil
  end
  local cipher = string.match(pick, "\"signatureCipher\":\"(.-)\"") or string.match(pick, "\"[a-zA-Z]*[Cc]ipher\":\"(.-)\"")
  if cipher then
    local url = stream_url(cipher, js_url)
    if url then
      return url
    end
  end
  return string.match(pick, "\"url\":\"(.-)\"")
end
function probe()
  return (vlc.access == "http" or vlc.access == "https") and ((string.match(vlc.path, "^www%.youtube%.com/") or string.match(vlc.path, "^music%.youtube%.com/") or string.match(vlc.path, "^gaming%.youtube%.com/")) and (string.match(vlc.path, "/watch%?") or string.match(vlc.path, "/live$") or string.match(vlc.path, "/live%?") or string.match(vlc.path, "/get_video_info%?") or string.match(vlc.path, "/v/") or string.match(vlc.path, "/embed/")) or string.match(vlc.path, "^consent%.youtube%.com/"))
end
function parse()
  if string.match(vlc.path, "^consent%.youtube%.com/") then
    local url = get_url_param(vlc.path, "continue")
    if not url then
      vlc.msg.err("Couldn't handle YouTube cookie consent redirection, please check for updates to this script or try disabling HTTP cookie forwarding")
      return {}
    end
    return {
      {
        path = vlc.strings.decode_uri(url),
        options = {
          ":no-http-forward-cookies"
        }
      }
    }
  elseif not string.match(vlc.path, "^www%.youtube%.com/") then
    return {
      {
        path = vlc.access .. "://" .. string.gsub(vlc.path, "^([^/]*)/", "www.youtube.com/")
      }
    }
  elseif string.match(vlc.path, "/watch%?") or string.match(vlc.path, "/live$") or string.match(vlc.path, "/live%?") then
    local js_url
    fmt = get_url_param(vlc.path, "fmt")
    while true do
      local line = new_layout and read_long_line() or vlc.readline()
      if not line then
        break
      end
      if string.match(line, "^ *<div id=\"player%-api\">") then
        line = read_long_line()
        if not line then
          break
        end
      end
      if not title then
        local meta = string.match(line, "<meta property=\"og:title\"( .-)>")
        if meta then
          title = string.match(meta, " content=\"(.-)\"")
          if title then
            title = vlc.strings.resolve_xml_special_chars(title)
          end
        end
      end
      if not description then
        description = string.match(line, "\\\"shortDescription\\\":\\\"(.-[^\\])\\\"")
        if description then
          description = string.gsub(description, "\\([\"\\/])", "%1")
        else
          description = string.match(line, "\"shortDescription\":\"(.-[^\\])\"")
        end
        if description then
          if string.match(description, "^\"") then
            description = ""
          end
          description = string.gsub(description, "\\([\"\\/])", "%1")
          description = string.gsub(description, "\\n", "\n")
          description = string.gsub(description, "\\r", "\r")
          description = string.gsub(description, "\\u0026", "&")
        end
      end
      if not arturl then
        local meta = string.match(line, "<meta property=\"og:image\"( .-)>")
        if meta then
          arturl = string.match(meta, " content=\"(.-)\"")
          if arturl then
            arturl = vlc.strings.resolve_xml_special_chars(arturl)
          end
        end
      end
      if not artist then
        artist = string.match(line, "\\\"author\\\":\\\"(.-)\\\"")
        if artist then
          artist = string.gsub(artist, "\\([\"\\/])", "%1")
        else
          artist = string.match(line, "\"author\":\"(.-)\"")
        end
        if artist then
          artist = string.gsub(artist, "\\u0026", "&")
        end
      end
      if not new_layout and string.match(line, "<script nonce=\"") then
        vlc.msg.dbg("Detected new YouTube HTML code layout")
        new_layout = true
      end
      if not js_url then
        js_url = string.match(line, "\"jsUrl\":\"(.-)\"") or string.match(line, "\"js\": *\"(.-)\"")
        if js_url then
          js_url = string.gsub(js_url, "\\/", "/")
          if string.match(js_url, "^/[^/]") then
            local authority = string.match(vlc.path, "^([^/]*)/")
            js_url = "//" .. authority .. js_url
          end
          js_url = string.gsub(js_url, "^//", vlc.access .. "://")
        end
      end
      if string.match(line, "ytplayer%.config") then
        if not fmt then
          fmt_list = string.match(line, "\"fmt_list\": *\"(.-)\"")
          if fmt_list then
            fmt_list = string.gsub(fmt_list, "\\/", "/")
            fmt = get_fmt(fmt_list)
          end
        end
        url_map = string.match(line, "\"url_encoded_fmt_stream_map\": *\"(.-)\"")
        if url_map then
          vlc.msg.dbg("Found classic parameters for youtube video stream, parsing...")
          url_map = string.gsub(url_map, "\\u0026", "&")
          path = pick_url(url_map, fmt, js_url)
        end
        if not path then
          local stream_map = string.match(line, "\\\"formats\\\":%[(.-)%]")
          if stream_map then
            stream_map = string.gsub(stream_map, "\\([\"\\/])", "%1")
          else
            stream_map = string.match(line, "\"formats\":%[(.-)%]")
          end
          if stream_map then
            vlc.msg.dbg("Found new-style parameters for youtube video stream, parsing...")
            stream_map = string.gsub(stream_map, "\\u0026", "&")
            path = pick_stream(stream_map, js_url)
          end
        end
        if not path then
          local hlsvp = string.match(line, "\\\"hlsManifestUrl\\\": *\\\"(.-)\\\"") or string.match(line, "\"hlsManifestUrl\":\"(.-)\"")
          if hlsvp then
            hlsvp = string.gsub(hlsvp, "\\/", "/")
            path = hlsvp
          end
        end
      end
    end
    if not path then
      local video_id = get_url_param(vlc.path, "v")
      if video_id then
        path = vlc.access .. "://www.youtube.com/get_video_info?video_id=" .. video_id .. copy_url_param(vlc.path, "fmt")
        if js_url then
          path = path .. "&jsurl=" .. vlc.strings.encode_uri_component(js_url)
        end
        vlc.msg.warn("Couldn't extract video URL, falling back to alternate youtube API")
      end
    end
    if not path then
      vlc.msg.err("Couldn't extract youtube video URL, please check for updates to this script")
      return {}
    end
    if not arturl then
      arturl = get_arturl()
    end
    return {
      {
        path = path,
        name = title,
        description = description,
        artist = artist,
        arturl = arturl
      }
    }
  elseif string.match(vlc.path, "/get_video_info%?") then
    local line = vlc.read(1048576)
    if not line then
      vlc.msg.err("YouTube API output missing")
      return {}
    end
    local js_url = get_url_param(vlc.path, "jsurl")
    js_url = js_url and vlc.strings.decode_uri(js_url)
    local fmt = get_url_param(vlc.path, "fmt")
    if not fmt then
      local fmt_list = string.match(line, "&fmt_list=([^&]*)")
      if fmt_list then
        fmt_list = vlc.strings.decode_uri(fmt_list)
        fmt = get_fmt(fmt_list)
      end
    end
    local url_map = string.match(line, "&url_encoded_fmt_stream_map=([^&]*)")
    if url_map then
      vlc.msg.dbg("Found classic parameters for youtube video stream, parsing...")
      url_map = vlc.strings.decode_uri(url_map)
      path = pick_url(url_map, fmt, js_url)
    end
    if not path then
      local stream_map = string.match(line, "%%22formats%%22%%3A%%5B(.-)%%5D")
      if stream_map then
        vlc.msg.dbg("Found new-style parameters for youtube video stream, parsing...")
        stream_map = vlc.strings.decode_uri(stream_map)
        stream_map = string.gsub(stream_map, "\\u0026", "&")
        path = pick_stream(stream_map, js_url)
      end
    end
    if not path then
      local hlsvp = string.match(line, "%%22hlsManifestUrl%%22%%3A%%22(.-)%%22")
      if hlsvp then
        hlsvp = vlc.strings.decode_uri(hlsvp)
        path = hlsvp
      end
    end
    if not path and get_url_param(vlc.path, "el") ~= "detailpage" then
      local video_id = get_url_param(vlc.path, "video_id")
      if video_id then
        path = vlc.access .. "://www.youtube.com/get_video_info?video_id=" .. video_id .. "&el=detailpage" .. copy_url_param(vlc.path, "fmt") .. copy_url_param(vlc.path, "jsurl")
        vlc.msg.warn("Couldn't extract video URL, retrying with alternate YouTube API parameters")
      end
    end
    if not path then
      vlc.msg.err("Couldn't extract youtube video URL, please check for updates to this script")
      return {}
    end
    local title = string.match(line, "%%22title%%22%%3A%%22(.-)%%22")
    if title then
      title = string.gsub(title, "+", " ")
      title = vlc.strings.decode_uri(title)
      title = string.gsub(title, "\\u0026", "&")
    end
    local description = string.match(line, "%%22shortDescription%%22%%3A%%22(.-)%%22")
    if description then
      description = string.gsub(description, "+", " ")
      description = vlc.strings.decode_uri(description)
      description = string.gsub(description, "\\([\"\\/])", "%1")
      description = string.gsub(description, "\\n", "\n")
      description = string.gsub(description, "\\r", "\r")
      description = string.gsub(description, "\\u0026", "&")
    end
    local artist = string.match(line, "%%22author%%22%%3A%%22(.-)%%22")
    if artist then
      artist = string.gsub(artist, "+", " ")
      artist = vlc.strings.decode_uri(artist)
      artist = string.gsub(artist, "\\u0026", "&")
    end
    local arturl = string.match(line, "%%22playerMicroformatRenderer%%22%%3A%%7B%%22thumbnail%%22%%3A%%7B%%22thumbnails%%22%%3A%%5B%%7B%%22url%%22%%3A%%22(.-)%%22")
    arturl = arturl and vlc.strings.decode_uri(arturl)
    return {
      {
        path = path,
        name = title,
        description = description,
        artist = artist,
        arturl = arturl
      }
    }
  else
    local video_id = string.match(vlc.path, "/[^/]+/([^?]*)")
    if not video_id then
      vlc.msg.err("Couldn't extract youtube video URL")
      return {}
    end
    return {
      {
        path = vlc.access .. "://www.youtube.com/watch?v=" .. video_id .. copy_url_param(vlc.path, "fmt")
      }
    }
  end
end
