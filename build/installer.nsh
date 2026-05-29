!macro customInit
  ClearErrors
  FileOpen $R0 "$INSTDIR\.installer-version" r
  ${IfNot} ${Errors}
    FileRead $R0 $R1
    FileClose $R0
    ${If} $R1 == "${VERSION}"
      ExecShell "" "$INSTDIR\barbs-snatcher.exe" "--installer"
      Quit
    ${EndIf}
  ${EndIf}
!macroend

!macro customInstall
  CreateShortcut "$DESKTOP\Barb's Launcher.lnk" "$INSTDIR\barbs-snatcher.exe" "--installer"
  ExecShell "" "$INSTDIR\barbs-snatcher.exe" "--installer"
!macroend
