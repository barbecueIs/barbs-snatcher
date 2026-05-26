!macro customFinishPage
  !define MUI_FINISHPAGE_RUN "$INSTDIR\${APP_EXECUTABLE_FILENAME}"
  !define MUI_FINISHPAGE_RUN_TEXT "Launch Barb's Snatcher"
  !insertmacro MUI_PAGE_FINISH
!macroend
