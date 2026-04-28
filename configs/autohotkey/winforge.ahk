; =============================================================================
; WinForge AutoHotkey v2 hotkeys.
; Drop into %USERPROFILE%\Documents\AutoHotkey\winforge.ahk
; AutoHotkey v2 syntax. Install AutoHotkey first (winget: AutoHotkey.AutoHotkey).
; =============================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode 2

; ---- App launchers ----------------------------------------------------------
; Win+Alt+T -> Windows Terminal
#!t::Run("wt.exe")
; Win+Alt+E -> File Explorer
#!e::Run("explorer.exe")
; Win+Alt+C -> VS Code in current dir
#!c::Run('code "' A_WorkingDir '"')
; Win+Alt+B -> default browser homepage
#!b::Run("https://www.google.com")

; ---- Window helpers ---------------------------------------------------------
; Win+Up -> maximize, Win+Down -> minimize (already mostly default; reinforce)
#Up::WinMaximize("A")
#Down::WinMinimize("A")

; Center active window
#!Space::CenterActiveWindow()

CenterActiveWindow() {
    hwnd := WinGetID("A")
    if !hwnd
        return
    WinGetPos(&x, &y, &w, &h, "ahk_id " hwnd)
    mon := MonitorGetWorkArea(MonitorGetPrimary(), &left, &top, &right, &bottom)
    nx := left + ((right - left) - w) // 2
    ny := top  + ((bottom - top) - h) // 2
    WinMove(nx, ny, , , "ahk_id " hwnd)
}

; ---- Clipboard / text helpers ----------------------------------------------
; Ctrl+Shift+V -> paste as plain text (PowerToys handles this too; fallback)
^+v::
{
    saved := A_Clipboard
    A_Clipboard := A_Clipboard  ; round-trip strips formatting
    Send("^v")
    Sleep 200
    A_Clipboard := saved
}

; ---- Caps Lock as Esc (toggle by holding shift) -----------------------------
CapsLock::Esc
+CapsLock::CapsLock

; ---- Quick reload -----------------------------------------------------------
#!r::Reload
