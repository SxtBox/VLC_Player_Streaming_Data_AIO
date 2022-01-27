@echo off
color a
cls
title AIO Streaming For VLC Player 
echo.
echo  ------------------------------------------------------------
echo    For More Modules Or Updates Stay Connected to Kodi dot AL 
echo  ------------------------------------------------------------
echo  *------------------------------------------------------*
echo  ' AIO Streaming For VLC Player 1.x and 2.x 3.x         '
echo  *------------------------------------------------------*
echo  ' Author   : Olsion Bakiaj                             '
echo  ' Email    : TRC4@USA.COM                              '
echo  ' Website  : KODI.AL                                   '
echo  ' Version  : 1.0                                       '
echo  ' Created  : Wednesday, March 4, 2020                  '
echo  ' Modified : 00:00:0000                                '
echo  *------------------------------------------------------*
echo.
goto menu
:menu
echo  Select Your Operating System:
echo.
echo  [1] For Windows 32 BIT
echo  [2] For Windows 64 BIT
:choice
echo.
set /P C=Insert your number:

if "%C%"=="1" goto install32
if "%C%"=="2" goto install64

goto choice

:install32
copy "playlist_youtube.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "youtube_live.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "youtube.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "vimeo.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "dailymotion.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "twitch.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "twitch-extension.lua" "%ProgramFiles%\VideoLAN\VLC\lua\extensions\"
copy "soundcloud.lua" "%ProgramFiles%\VideoLAN\VLC\lua\playlist\"
copy "browse_window.lua" "%ProgramFiles%\VideoLAN\VLC\lua\http\dialogs\"
goto end

:install64
copy "playlist_youtube.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "youtube_live.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "youtube.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "vimeo.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "dailymotion.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "twitch.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "twitch-extension.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\extensions\"
copy "soundcloud.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\playlist\"
copy "browse_window.lua" "%ProgramFiles(x86)%\VideoLAN\VLC\lua\http\dialogs\"
goto end

:end
cls
echo. AIO Streaming For VLC Player Was Installed Successfully, Happy Playing!
echo. Press any key to close this window.
echo. 
pause
