; WinForge AutoHotKey Scripts v1.0
; Requires AutoHotKey v2  |  Place at: Documents\AutoHotkey\winforge.ahk
#Requires AutoHotkey v2.0
#SingleInstance Force

; Window Snapping (Win + Numpad)
#Numpad7:: WinMove(0, 0, A_ScreenWidth/2, A_ScreenHeight/2, "A")
#Numpad9:: WinMove(A_ScreenWidth/2, 0, A_ScreenWidth/2, A_ScreenHeight/2, "A")
#Numpad1:: WinMove(0, A_ScreenHeight/2, A_ScreenWidth/2, A_ScreenHeight/2, "A")
#Numpad3:: WinMove(A_ScreenWidth/2, A_ScreenHeight/2, A_ScreenWidth/2, A_ScreenHeight/2, "A")
#Numpad4:: WinMove(0, 0, A_ScreenWidth/2, A_ScreenHeight, "A")
#Numpad6:: WinMove(A_ScreenWidth/2, 0, A_ScreenWidth/2, A_ScreenHeight, "A")
#Numpad5:: {
    w := A_ScreenWidth * 0.75
    h := A_ScreenHeight * 0.75
    WinMove((A_ScreenWidth-w)/2, (A_ScreenHeight-h)/2, w, h, "A")
}

; Quick Launch
#e:: {
    if FileExist("C:\Program Files\Files\Files.exe")
        Run("C:\Program Files\Files\Files.exe")
    else
        Run("explorer.exe")
}
#t:: Run("wt.exe")

; Window Utilities
^Space:: WinSetAlwaysOnTop(-1, "A")
!+t::    WinSetTransparent(150, "A")
!+o::    WinSetTransparent("Off", "A")

; Text Expansion
:*:;shrug::¯\_(ツ)_/¯
:*:;arrow::→
:*:;check::✓
:*:;cross::✗
:*:;date:: { SendInput(FormatTime(, "yyyy-MM-dd")) }
:*:;time:: { SendInput(FormatTime(, "HH:mm")) }

; Reload
^!r:: Reload()
