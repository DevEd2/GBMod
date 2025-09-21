# Moved
This project has migrated to [Codeberg](https://codeberg.org/DevEd/GBMod).

# GBMod
XM converter + player for Game Boy

## Using GBMod
Requirements: [Python 3](https://www.python.org/) and a tracker of your choice ([OpenMPT](https://openmpt.org/), [MilkyTracker](https://milkytracker.org/), [FT2 Clone](https://16-bits.org/ft2.php), etc.)

1. Download the easypack [here](http://devnet.sonicgamesdimension.net/GBMod-Easypack.zip)

2. Unzip it

3. Use the provided template module to write a tune
  - Volume column is allowed, but you should use the note off command (in the note column) instead of setting the volume to zero
  - Tempo must be 150, speed can be whatever
  - Allowed effects: 0xy (CH1-CH3 only), 1xy/2xy (CH1-CH3 only), Axx, Bxx, Dxx, Fxx
    - Using Cxx to set note volume is not supported, use the volume column instead
  - Instruments 1-4 can be used on CH1, CH2, and CH3
  - Instruments 5-16 may only be used on CH3
  - Instruments 17 and 18 may only be used on CH4
  - The samples for instruments 5-16 may be redrawn as you see fit, but don't change the sample size
  - Each pattern must be 64 rows long (if you need to cut a pattern early use D00)
  - Do not use C00 in order to do note cuts, instead you should use the note off command (in the note column)
  - You must save your module in .XM format

4. Run xmconv.py
`python xmconv.py yourmodule.xm music.bin`

5. Build the ROM
  - If on Windows, run "type player.bin music.bin > rom.gb"
  - If on Linux or Mac OS X, run "cat player.bin music.bin > rom.gb"
  - Change the ROM name to your song's name
  - Optional: Use RGBFIX to fix the checksum of the resulting ROM

## Building GBMod
Requirements: [RGBDS](https://github.com/gbdev/rgbds), Python 3

1. Clone the repository.
2. If on Windows, run `build.bat`.
3. If on macOS or Linux, run `build.sh`. If you get a "permission denied" error, run `chmod +x build.sh` and try again.
