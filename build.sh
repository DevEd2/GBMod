#!/bin/sh
PROJECTNAME="GBMod"
set -e

# Build ROM
python3 xmconv.py Modules/LostInTranslation.xm Modules/LostInTranslation.bin -a "Pigu"
python3 xmconv.py Modules/Spring.xm Modules/Spring.bin -t 4 -m 168 -a "Faried Verheul"
python3 xmconv.py Modules/SlimeCave.xm Modules/SlimeCave.bin -a "Chris Hampton"

echo Assembling...
rgbasm -o $PROJECTNAME.obj -p 255 Main.asm

echo Linking...
rgblink -p 255 -o $PROJECTNAME.gb -n $PROJECTNAME.sym $PROJECTNAME.obj

echo Fixing...
rgbfix -v -p 255 $PROJECTNAME.gb

echo Cleaning up...
rm $PROJECTNAME.obj
echo Build complete.
