@echo off
set PROJECTNAME="GBMod"

rem	Build ROM
python xmconv.py Modules/LostInTranslation.xm Modules/LostInTranslation.bin -a "Pigu"
python xmconv.py Modules/EndlessRoad.xm Modules/EndlessRoad.bin -a "DevEd"
python xmconv.py Modules/Spring.xm Modules/Spring.bin -t 4 -m 170 -a "Faried Verheul"
python xmconv.py Modules/SlimeCave.xm Modules/SlimeCave.bin -a "Chris Hampton"
python xmconv.py Modules/GLoopEnd.xm Modules/GLoopEnd.bin -t 4 -m 176 -a "Adriaan Wormgoor"
echo Assembling...
rgbasm -o %PROJECTNAME%.obj -p 255 Main.asm
if errorlevel 1 goto :BuildError
echo Linking...
rgblink -p 255 -o %PROJECTNAME%.gb -n %PROJECTNAME%.sym %PROJECTNAME%.obj
if errorlevel 1 goto :BuildError
echo Fixing...
rgbfix -v -p 255 %PROJECTNAME%.gb
echo Cleaning up...
del %PROJECTNAME%.obj
echo Build complete.
goto :end

:BuildError
set PROJECTNAME=
echo Build failed, aborting...
goto:eof

:end
set PROJECTNAME=
