; ================================================================
; GBMod demo ROM
; ================================================================

; Debug flag
; If set to 1, enable debugging features.

DebugFlag   set 1

; If set to 1, display numbers in decimal instead of hexadecimal.

UseDecimal  set 0

; ================================================================
; Project includes
; ================================================================

include "Variables.asm"
include "Constants.asm"
include "Macros.asm"
include "hardware.inc"

; ================================================================
; Reset vectors (actual ROM starts here)
; ================================================================

SECTION "Reset $00",ROM0[$00]
Reset00:    ret

SECTION "Reset $08",ROM0[$08]
Reset08:    ret

SECTION "Reset $10",ROM0[$10]
Reset10:    ret

SECTION "Reset $18",ROM0[$18]
Reset18:    ret

SECTION "Reset $20",ROM0[$20]
Reset20:    ret

SECTION "Reset $28",ROM0[$28]
Reset28:    ret

SECTION "Reset $30",ROM0[$30]
Reset30:    ret

SECTION "Reset $38",ROM0[$38]
Reset38:    jr  @

; ================================================================
; Interrupt vectors
; ================================================================

SECTION "VBlank interrupt",ROM0[$40]
IRQ_VBlank:
    jp      DoVBlank

SECTION "LCD STAT interrupt",ROM0[$48]
IRQ_STAT:
    reti

SECTION "Timer interrupt",ROM0[$50]
IRQ_Timer:
    jp      DoTimer

SECTION "Serial interrupt",ROM0[$58]
IRQ_Serial:
    reti

SECTION "Joypad interrupt",ROM0[$60]
IRQ_Joypad:
    reti

; ================================================================
; System routines
; ================================================================

include "SystemRoutines.asm"

; ================================================================
; ROM header
; ================================================================

SECTION "ROM header",ROM0[$100]

EntryPoint:
    nop
    jp  ProgramStart

NintendoLogo:   ; DO NOT MODIFY OR ROM WILL NOT BOOT!!!
    db  $ce,$ed,$66,$66,$cc,$0d,$00,$0b,$03,$73,$00,$83,$00,$0c,$00,$0d
    db  $00,$08,$11,$1f,$88,$89,$00,$0e,$dc,$cc,$6e,$e6,$dd,$dd,$d9,$99
    db  $bb,$bb,$67,$63,$6e,$0e,$ec,$cc,$dd,$dc,$99,$9f,$bb,$b9,$33,$3e

ROMTitle:       db  "GBMOD",0,0,0,0,0,0 ; ROM title (11 bytes)
ProductCode:    db  0,0,0,0             ; product code (4 bytes)
GBCSupport:     db  $80                 ; GBC support (0 = DMG only, $80 = DMG/GBC, $C0 = GBC only)
NewLicenseCode: db  "DS"                ; new license code (2 bytes)
SGBSupport:     db  0                   ; SGB support
CartType:       db  $1b                 ; Cart type, see hardware.inc for a list of values
ROMSize:        ds  1                   ; ROM size (handled by post-linking tool)
RAMSize:        db  3                   ; RAM size
DestCode:       db  1                   ; Destination code (0 = Japan, 1 = All others)
OldLicenseCode: db  $33                 ; Old license code (if $33, check new license code)
ROMVersion:     db  0                   ; ROM version
HeaderChecksum: ds  1                   ; Header checksum (handled by post-linking tool)
ROMChecksum:    ds  2                   ; ROM checksum (2 bytes) (handled by post-linking tool)

; ================================================================
; Start of program code
; ================================================================

ProgramStart:
    ld  sp,$fffe
    push    af
    di                      ; disable interrupts
    
.wait                       ; wait for VBlank before disabling the LCD
    ldh a,[rLY]
    cp  $90
    jr  nz,.wait
    xor a
    ld  [rLCDC],a           ; disable LCD
    
    call    ClearWRAM

    ; clear HRAM
    xor a
    ld  bc,$7c80
._loop
    ld  [c],a
    inc c
    dec b
    jr  nz,._loop

    call    ClearVRAM
    
    CopyTileset1BPP Font,0,(Font_End-Font)/8
    
    pop af
    cp  $11
    jr  nz,:+
    ld  hl,Pal_Grayscale
    xor a
    call    LoadBGPalLine
:
    
    ; Emulator check!
    ; This routine uses echo RAM access to detect lesser
    ; emulators (such as VBA) which are more likely to
    ; break when given situations that real hardware
    ; handles just fine.
    ld  a,"e"               ; this value isn't important
    ld  [VBACheck],a        ; copy value to WRAM
    ld  b,a
    ld  a,[VBACheck+$2000]  ; read value back from echo RAM
    cp  b                   ; (fails in emulators which don't emulate echo RAM)
    jp  z,.noemu            ; if check passes, don't display warning
.emuscreen  
    ld  hl,.emutext
    call    LoadMapText     ; assumes font is already loaded into VRAM
    ld  a,%11100100         ; 3 2 1 0
    ldh [rBGP],a            ; set background palette
    ld  a,%10010001         ; LCD on + BG on + BG $8000
    ldh [rLCDC],a           ; enable LCD
.emuwait
    call    CheckInput
    ld  a,[sys_btnPress]
    bit btnA,a              ; check if A is pressed
    jp  nz,.emubreak        ; if a is pressed, break from loop
    jr  .emuwait
.emutext                    ; 20x18 char tilemap
    db  "Nice emulator you   "
    db  "got there :^)       "
    db  "                    "
    db  "For best results,   "
    db  "please use a better "
    db  "emulator (such as   "
    db  "bgb or gambatte) or "
    db  "run this ROM on real"
    db  "hardware.           "
    db  "                    "
    db  "Press A to continue "
    db  "anyway, but don't   "
    db  "blame me if any part"
    db  "of this ROM doesn't "
    db  "work correctly due  "
    db  "to your terrible    "
    db  "choice of emulator! "
    db  "                    "
    
.emubreak
    ; no need to wait for vblank first because this code only runs in emulators
    xor a
    ldh [rLCDC],a           ; disable lcd
.noemu
    ld  hl,MainText         ; load main text
    call    LoadMapText
    ld  a,%11100100         ; 3 2 1 0
    ldh [rBGP],a            ; set background palette
    
    ld  a,IEF_VBLANK | IEF_TIMER
    ldh [rIE],a             ; set VBlank interrupt flag
        
    ld  a,%10010001         ; LCD on + BG on + BG $8000
    ldh [rLCDC],a           ; enable LCD
    
    ; Sample implementation for loading a song.
    ; Replace the 0 in ld a,0 with the ID of the song you want to load.
    ; Note that invalid values will most likely result in a crash!
    
    ld  a,0
    call    GBM_LoadModule
    call    DrawSongName
    
    ei
    
MainLoop:
    ; draw song id
    ld  a,[CurrentSong]
    ld  hl,$9891
    call    DrawHex
    
    ; playback controls
    ld  a,[sys_btnPress]
    bit btnUp,a
    jr  nz,.add16
    bit btnDown,a
    jr  nz,.sub16
    bit btnLeft,a
    jr  nz,.sub1
    bit btnRight,a
    jr  nz,.add1
    bit btnA,a
    jr  nz,.loadSong
    bit btnB,a
    jr  nz,.stopSong
    bit btnSelect,a
    jr  nz,.toggleSpeed
    jr  .continue

.add1
    ld  a,[CurrentSong]
    inc a
    ld  [CurrentSong],a
    jr  .continue
.sub1
    ld  a,[CurrentSong]
    dec a
    ld  [CurrentSong],a
    jr  .continue
.add16
    ld  a,[CurrentSong]
    add 16
    ld  [CurrentSong],a
    jr  .continue
.sub16
    ld  a,[CurrentSong]
    sub 16
    ld  [CurrentSong],a
    jr  .continue
.loadSong
    ld  a,[CurrentSong]
    call    GBM_LoadModule
    call    DrawSongName
    jr  .continue
.stopSong
    call    GBM_Stop
    ld  hl,str_NoSong
    ld  de,$98a1
    ld  b,16
.stoploop
    ldh a,[rSTAT]
    and 2
    jr  nz,.stoploop
    ld  a,[hl+]
    sub 32
    ld  [de],a
    inc de
    dec b
    jr  nz,.stoploop
    jr  .continue
.toggleSpeed
    call    DoSpeedSwitch
    jr  .loadSong
    
.continue
    
    call    DrawSoundVars
    
    halt                ; wait for VBlank
    
;    ld  a,c
;    ld  hl,MaxRasterTime
;    cp  [hl]
;    jr  c,.skip
;    ld  [hl],c
;.skip
;    ld  hl,$9a31        ; raster time display address in VRAM
;    call    DrawHex     ; draw raster time
    
    call    CheckInput
    
    jp  MainLoop
    
; ================================================================
; Graphics data
; ================================================================
    
MainText:
;        ####################
    db  "                    "
    db  "GBMod v2.0 by DevEd "
    db  "  deved8@gmail.com  "
    db  "                    "
    db  " Current song:  $?? "
    db  " ????????????????   "
    db  " Controls:          "
    db  " A........Load song "
    db  " B........Stop song "
    db  " D-pad..Select song "
    db  " Sel.Toggle CPU spd "
    db  "                    "
    db  " CH1 ??? V? P? ???? "
    db  " CH2 ??? V? P? ???? "
    db  " CH3 ??? V? P? ???? "
    db  " CH4 $?? V? P? ???? "
    db  "                    "
    db  "                    "
;    db  " Raster time:   $?? "
;        ####################

Font:   incbin  "Font.1bpp"  ; 1bpp font data
Font_End:

; ====================
; Draw sound variables
; ====================

DrawSoundVars:
    push    bc
    ; ch1
    ld  a,[GBM_Note1]
    cp  $ff
    jr  z,.nonote1
    call    GetNoteString
    ld  de,$9985
    rept    3
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,[hl+]
    sub 32
    ld  [de],a
    inc de
    endr
    jr  .cont1
.nonote1
    ld  hl,$9985
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,"-"-32
    ld  [hl+],a
    ld  [hl+],a
    ld  [hl+],a
    jr  .cont1
.cont1
    ld  a,[GBM_Vol1]
    rra
    rra
    rra
    ld  hl,$998a
    call    DrawHexDigit
    ld  a,[GBM_Pulse1]
    ld  hl,$998d
    call    DrawHexDigit
    ld  a,[GBM_Command1]
    ld  hl,$998f
    call    DrawHex
    ld  a,[GBM_Param1]
    call    DrawHex
    
    ; ch2
    ld  a,[GBM_Note2]
    cp  $ff
    jr  z,.nonote2
    call    GetNoteString
    ld  de,$99a5
    rept    3
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,[hl+]
    sub 32
    ld  [de],a
    inc de
    endr
    jr  .cont2
.nonote2
    ld  hl,$99a5
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,"-"-32
    ld  [hl+],a
    ld  [hl+],a
    ld  [hl+],a
.cont2
    ld  a,[GBM_Vol2]
    rra
    rra
    rra
    ld  hl,$99aa
    call    DrawHexDigit
    ld  a,[GBM_Pulse2]
    ld  hl,$99ad
    call    DrawHexDigit
    ld  a,[GBM_Command2]
    ld  hl,$99af
    call    DrawHex
    ld  a,[GBM_Param2]
    call    DrawHex
    
    ; ch3
    ld  a,[GBM_Note3]
    cp  $ff
    jr  z,.nonote3
    cp  $80
    jr  z,.sample3
    call    GetNoteString
    ld  de,$99c5
    rept    3
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,[hl+]
    sub 32
    ld  [de],a
    inc de
    endr
    jr  .cont3
.nonote3
    ld  hl,$99c5
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,"-"-32
    ld  [hl+],a
    ld  [hl+],a
    ld  [hl+],a
    jr  .cont3
.sample3
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,"S"-32
    ld  [$99c5],a
    ld  a,[GBM_SampleID]
    ld  hl,$99c6
    call    DrawHex
.cont3
    ld  a,[GBM_Vol3]
    ld  hl,$99ca
    call    DrawHexDigit
    ld  a,[GBM_Wave3]
    inc a
    ld  hl,$99cd
    call    DrawHexDigit
    ld  a,[GBM_Command3]
    ld  hl,$99cf
    call    DrawHex
    ld  a,[GBM_Param3]
    call    DrawHex
    
    ; ch4
    ld  a,[GBM_Note4]
    cp  $ff
    jr  z,.nonote4
    ld  hl,$99e6
    call    DrawHex
    jr  .cont4
.nonote4
    ld  hl,$99e6
    ldh a,[rSTAT]
    and 2
    jr  nz,@-4
    ld  a,"-"-32
    ld  [hl+],a
    ld  [hl+],a
.cont4
    ld  a,[GBM_Vol4]
    rra
    rra
    rra
    ld  hl,$99ea
    call    DrawHexDigit
    ld  a,[GBM_Mode4]
    ld  hl,$99ed
    call    DrawHexDigit
    ld  a,[GBM_Command4]
    ld  hl,$99ef
    call    DrawHex
    ld  a,[GBM_Param4]
    call    DrawHex

    pop bc
    ret

GetNoteString:
    cp  $48
    jr  nc,.unknownNote
    ld  hl,MusicNoteStrTable
    ld  b,a
    add b
    add b
    ld  d,0
    ld  e,a
    add hl,de
    ret
.unknownNote
    ld  hl,UnknownNote
    ret
    
DrawSongName:
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    ld  hl,$4010
    ld  de,$98a1
    ld  b,16
.loop
    ldh a,[rSTAT]
    and 2
    jr  nz,.loop
    ld  a,[hl+]
    sub 32
    ld  [de],a
    inc de
    dec b
    jr  nz,.loop
    ld  a,1
    ld  [rROMB0],a
    ret
    
MusicNoteStrTable:
    db  "C-2","C#2","D-2","D#2","E-2","F-2","F#2","G-2","G#2","A-2","A#2","B-2"
    db  "C-3","C#3","D-3","D#3","E-3","F-3","F#3","G-3","G#3","A-3","A#3","B-3"
    db  "C-4","C#4","D-4","D#4","E-4","F-4","F#4","G-4","G#4","A-4","A#4","B-4"
    db  "C-5","C#5","D-5","D#5","E-5","F-5","F#5","G-5","G#5","A-5","A#5","B-5"
    db  "C-6","C#6","D-6","D#6","E-6","F-6","F#6","G-6","G#6","A-6","A#6","B-6"
    db  "C-7","C#7","D-7","D#7","E-7","F-7","F#7","G-7","G#7","A-7","A#7","B-7"
UnknownNote:    db  "???"
    
str_NoSong:
    db  "NO SONG         "
    
PrintString:
    ld  de,$9800
    and $f
    swap    a
    rla
    jr  nc,.nocarry
    inc d
.nocarry
    ld  e,a
.loop
    ldh a,[rSTAT]
    and 2
    jr  nz,.loop
    
    ld  a,[hl+]
    and a
    ret z
    sub 32
    ld  [de],a
    inc de
    jr  .loop
    
ClearScreen:
    ld  hl,$9800
    ld  bc,$800
.clearLoop
    ldh a,[rSTAT]
    and 2
    jr  nz,.clearLoop
    xor a
    ld  [hl+],a
    dec bc
    ld  a,b
    or  c
    jr  nz,.clearLoop
    ret


; ================================================================
; GBC routines
; ================================================================

; Switches double speed mode off.
; TRASHES: a
NormalSpeed:
    ldh a,[rKEY1]
    bit 7,a         ; already in normal speed?
    ret z           ; if yes, return
    jr  DoSpeedSwitch

; Switches double speed mode on.
; TRASHES: a
DoubleSpeed:
    ldh a,[rKEY1]
    bit 7,a         ; already in double speed?
    ret nz          ; if yes, return
DoSpeedSwitch:
    ld  a,%00110000
    ldh [rP1],a
    xor %00110001   ; a = %00000001
    ldh [rKEY1],a   ; prepare speed switch
    stop
    ret


; Input: hl = palette data	
LoadBGPal:
	ld	a,0
	call	LoadBGPalLine
	ld	a,1
	call	LoadBGPalLine
	ld	a,2
	call	LoadBGPalLine
	ld	a,3
	call	LoadBGPalLine
	ld	a,4
	call	LoadBGPalLine
	ld	a,5
	call	LoadBGPalLine
	ld	a,6
	call	LoadBGPalLine
	ld	a,7
	call	LoadBGPalLine
	ret
	
; Input: hl = palette data	
LoadObjPal:
	ld	a,0
	call	LoadObjPalLine
	ld	a,1
	call	LoadObjPalLine
	ld	a,2
	call	LoadObjPalLine
	ld	a,3
	call	LoadObjPalLine
	ld	a,4
	call	LoadObjPalLine
	ld	a,5
	call	LoadObjPalLine
	ld	a,6
	call	LoadObjPalLine
	ld	a,7
	call	LoadObjPalLine
	ret
	
; Input: hl = palette data
LoadBGPalLine:
	swap	a	; \  multiply
	rrca		; /  palette by 8
	or	$80		; auto increment
	push	af
	WaitForVRAM
	pop	af
	ld	[rBCPS],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ld	a,[hl+]
	ld	[rBCPD],a
	ret
	
; Input: hl = palette data
LoadObjPalLine:
	swap	a	; \  multiply
	rrca		; /  palette by 8
	or	$80		; auto increment
	push	af
	WaitForVRAM
	pop	af
	ld	[rOCPS],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ld	a,[hl+]
	ld	[rOCPD],a
	ret

Pal_Grayscale:
	dw	$7fff,$6e94,$354a,$0000

; ================================================================
; SRAM routines
; ================================================================

;    include "SRAM.asm"
    
; ================================================================
; Misc routines
; ================================================================

DoVBlank:
    push    af
    ld      a,[GBM_EnableTimer]
    and     a
    jr      nz,:+
    push    bc
    push    de
    push    hl
    call    GBM_Update
    pop     hl
    pop     de
    pop     bc
:   pop     af
    reti

DoTimer:
    push    af
    ld      a,[GBM_EnableTimer]
    and     a
    jr      z,:+
    push    bc
    push    de
    push    hl
    call    GBM_Update
    pop     hl
    pop     de
    pop     bc
:   pop     af
    reti

; ================================================================
; Sound driver
; ================================================================

    include "GBMod_Player.asm"
    
; ================================================================
; Song data
; ================================================================

section "Lost In Translation",romx,bank[1]
    incbin  "Modules/LostInTranslation.bin"
section "Spring",romx,bank[2]
    incbin  "Modules/Spring.bin"
section "Slime Cave, bank 1",romx,bank[3]
    incbin  "Modules/SlimeCave.bin",0,$4000
section "Slime Cave, bank 2",romx,bank[4]
    incbin  "Modules/SlimeCave.bin",$4000