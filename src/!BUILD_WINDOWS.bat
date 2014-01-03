cmd
raco exe --gui gui.rkt
move gui.exe Kirisurf.exe
raco distribute ..\bin\Windows\ Kirisurf.exe 
xcopy windows ..\bin\Windows\windows /E
xcopy icons ..\bin\Windows\icons /E
copy kiri.png ..\bin\Windows\kiri.png
copy lang.txt ..\bin\Windows\lang.txt
echo.&pause