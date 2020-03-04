--[[
Twitch.tv extension v0.0.2 by Stefan Sundin
https://gist.github.com/stefansundin/c200324149bb00001fef5a252a120fc2

The only thing that this extension does is to act as a helper to seek to the
correct time when you open a twitch.tv url that contains a timestamp.
You must have the playlist parser installed as well!

Usage:
1. Install the playlist parser: https://addons.videolan.org/p/1167220/
2. Install this file in the lua/extensions/ directory:
- On Windows: %APPDATA%/vlc/lua/extensions/
- On Mac: $HOME/Library/Application Support/org.videolan.vlc/lua/extensions/
- On Linux: ~/.local/share/vlc/lua/extensions/
- On Linux (snap package): ~/snap/vlc/current/.local/share/vlc/lua/extensions/
To install the addon for all users, put the file here instead:
- On Windows: C:/Program Files (x86)/VideoLAN/VLC/lua/extensions/
- On Mac: /Applications/VLC.app/Contents/MacOS/share/lua/extensions/
- On Linux: /usr/lib/vlc/lua/extensions/
- On Linux (snap package): /snap/vlc/current/usr/lib/vlc/lua/extensions/
3. Open VLC and activate the extension via the menu.
   NOTE: You must do this every time you restart VLC, as far as I know there is
         no way for the extension to activate itself. :(
         There is no feedback indicating that the extension was activated.
4. Open a twitch.tv url with a timestamp using "Open Network Stream..."

Download and install with one command on Mac:
curl -o "$HOME/Library/Application Support/org.videolan.vlc/lua/extensions/twitch-extension.lua" https://gist.githubusercontent.com/stefansundin/c200324149bb00001fef5a252a120fc2/raw/twitch-extension.lua

Download and install with one command on Linux:
curl -o ~/.local/share/vlc/lua/extensions/twitch-extension.lua https://gist.githubusercontent.com/stefansundin/c200324149bb00001fef5a252a120fc2/raw/twitch-extension.lua

Example url:
https://www.twitch.tv/gamesdonequick/video/113837699?t=23m56s
https://www.twitch.tv/videos/113837699?t=23m56s
https://player.twitch.tv/?video=v113837699&time=23m56s

Changelog:
- v0.0.2: Support new go.twitch.tv urls (beta site).
- v0.0.1: First version of extension.
--]]

require 'common'

function descriptor()
  return {
    title        = "Twitch.tv Extension v0.0.2",
    shortdesc    = "Twitch.tv Extension v0.0.2",
    version      = "v0.0.2",
    author       = "Stefan Sundin",
    url          = "https://gist.github.com/stefansundin/c200324149bb00001fef5a252a120fc2",
    description  = "This extension is needed to support jumping to a twitch.tv timestamp indicated by ?t= in the URL. VLC extensions must be activated each time VLC is run. This is unfortunate and I have not found any workaround.",
    capabilities = { "input-listener" }
  }
end

function activate()
  check_meta()
end

function input_changed()
  check_meta()
end

-- The extension does not work if I name this string.starts, so weird..
function stringstarts(haystack, needle)
  return string.sub(haystack, 1, string.len(needle)) == needle
end

function check_meta()
  if vlc.input.is_playing() then
    local item = vlc.item or vlc.input.item()
    if item then
      local meta = item:metas()
      if meta and meta["url"] then
        vlc.msg.info("Trying to parse t from: "..meta["url"])
        if (stringstarts(meta["url"], "https://www.twitch.tv/") or stringstarts(meta["url"], "https://go.twitch.tv/") or stringstarts(meta["url"], "https://player.twitch.tv/")) and (string.find(meta["url"], "[?&]t=") or string.find(meta["url"], "[?&]time=")) then
          local t = string.match(meta["url"], "[?&]t=([^&#]+)") or string.match(meta["url"], "[?&]time=([^&#]+)")
          vlc.msg.info("t="..t)
          local start = 0
          local h = string.match(t, "(%d+)h")
          if h then
            -- vlc.msg.info("h: "..h)
            start = start + tonumber(h)*3600
          end
          local m = string.match(t, "(%d+)m")
          if m then
            -- vlc.msg.info("m: "..m)
            start = start + tonumber(m)*60
          end
          local s = string.match(t, "(%d+)s")
          if s then
            -- vlc.msg.info("s: "..s)
            start = start + tonumber(s)
          end
          vlc.msg.info("Seeking to: "..start)
          common.seek(start)
        end
      end
    end
    return true
  end
end
