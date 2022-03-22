; ================================================================
; XM2GB replay routine
; ================================================================

; NOTE: For best results, place player code in ROM0.

; ===========
; Player code
; ===========

section "GBMod",rom0
GBMod:

GBM_LoadModule:     jp  GBMod_LoadModule
GBM_Update:         jp  GBMod_Update
GBM_Stop:           jp  GBMod_Stop

; ================================

GBMod_LoadModule:
    push    af
    push    bc
    push    hl
    di
    ld  [GBM_SongID],a
    xor a
    ld  hl,GBM_RAM_Start+1
    ld  b,(GBM_RAM_End-GBM_RAM_Start+1)-2
.clearloop
    ld  [hl+],a
    dec b
    jr  nz,.clearloop   
    inc a
    ld  [GBM_ModuleTimer],a
    ld  [GBM_TickTimer],a
    
    ldh [rNR52],a   ; disable sound (clears all sound registers)
    or  $80
    ldh [rNR52],a   ; enable sound
    or  $7f
    ldh [rNR51],a   ; all channels to SO1+SO2
    xor %10001000
    ldh [rNR50],a   ; master volume 7

    ld  a,[GBM_SongID]
    inc a
;    ld  b,a
;    ld  a,[GBM_CurrentBank]
;    add b
    ld  [rROMB0],a
    ld  hl,$4000
    
    ld  a,[hl+]
    ld  [GBM_PatternCount],a
    ld  a,[hl+]
    ld  [GBM_PatTableSize],a
    ld  a,[hl+]
    ld  [GBM_ModuleSpeed],a
    ld  a,[hl+]
    ld  [GBM_TickSpeed],a
    ld  a,[hl+]
    ld  [GBM_SongDataOffset],a
    ld  a,[hl+]
    ld  [GBM_SongDataOffset+1],a
    ld  a,[hl+]
    and a
    jr  z,.vblank
.timer
    ld  b,a
    ldh a,[rKEY1]
    cp  $ff
    jr  z,.normalspeed
    bit 7,a
    jr  z,.normalspeed
.doublespeed
    srl b
.normalspeed
    ld  a,b
    ldh [rTMA],a
    ldh [rTIMA],a
    ld  a,[hl]
    ldh [rTAC],a
    ld  a,1
    ld  [GBM_EnableTimer],a
    jr  :+
.vblank
    xor a
    ldh [rTMA],a
    ldh [rTIMA],a
    ldh [rTAC],a
:   ld  a,$ff
    ld  [GBM_LastWave],a
    ld  a,1
    ld  [GBM_DoPlay],a
    ld  [GBM_CmdTick1],a
    ld  [GBM_CmdTick2],a
    ld  [GBM_CmdTick3],a
    ld  [GBM_CmdTick4],a
    sub 2
    ld  [GBM_PanFlags],a
    
    ld  a,[$40f0]
    ld  [GBM_CurrentPattern],a
    pop hl
    pop bc
    pop af
    reti

; ================================

GBMod_Stop:
    xor a
    ld  hl,GBM_RAM_Start
    ld  b,GBM_RAM_End-GBM_RAM_Start
.clearloop
    ld  [hl+],a
    dec b
    jr  nz,.clearloop
    
    ldh [rNR52],a   ; disable sound (clears all sound registers)
    or  $80
    ldh [rNR52],a   ; enable sound
    or  $7f
    ldh [rNR51],a   ; all channels to SO1+SO2
    xor %10001000
    ldh [rNR50],a   ; master volume 7
    ret
    
; ================================

GBMod_Update:
    ld  a,[GBM_DoPlay]
    and a
    ret z
    
    ; anything that needs to be updated on a per-frame basis should be put here
;    ld  e,0
;    call    GBMod_DoVib ; pulse 1 vibrato
;    inc e
;    call    GBMod_DoVib ; pulse 2 vibrato
;    inc e
;    call    GBMod_DoVib ; pulse 3 vibrato
    ; sample playback
    ld  a,[GBM_SamplePlaying]
    and a
    call    nz,GBMod_UpdateSample
    
    ld  a,[GBM_TickTimer]
    dec a
    ld  [GBM_TickTimer],a
    ret nz
    ld  a,[GBM_TickSpeed]
    ld  [GBM_TickTimer],a
    ld  a,[GBM_ModuleTimer]
    dec a
    ld  [GBM_ModuleTimer],a
    jp  nz,GBMod_UpdateCommands
    xor a
    ld  [GBM_SpeedChanged],a
    ld  a,[GBM_ModuleSpeed]
    ld  [GBM_ModuleTimer],a
    ld  a,[GBM_SongID]
    inc a
;    ld  b,a
;    ld  a,[GBM_CurrentBank]
;    add b
    ld  [rROMB0],a
    ld  hl,GBM_SongDataOffset
    ld  a,[hl+]
    ld  b,a
    ld  a,[hl]
    add $40
    ld  h,a
    ld  l,b
    
    ; get pattern offset
    ld  a,[GBM_CurrentPattern]
    and a
    jr  z,.getRow
    
    add a
    add a
    add h
    bit 7,a
    jr  z,:+
    sub $40
    push    af
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    pop af
:   ld  h,a
.getRow
    ld  a,[GBM_CurrentRow]
    and a
    jr  z,.readPatternData
    
    ld  b,a
    swap    a
    and $f0
    ld  e,a
    ld  a,b
    swap    a
    and $0f
    ld  d,a
    add hl,de
    bit 7,h
    jr  z,.readPatternData
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    ld  a,h
    xor %11000000
    ld  h,a
    
.readPatternData
    ; ch1 note
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    push    af
    cp  $ff
    jp  z,.skip1
    cp  $fe
    jr  nz,.nocut1
    xor a
    ld  [GBM_Vol1],a
    ldh [rNR12],a
    ld  a,%10000000
    ldh [rNR14],a
    jp  .skip1
.nocut1
    inc hl
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    ld  a,[hl]
    dec hl
    bit 6,h
    call    z,GBM_HandlePageBoundaryBackwards
    cp  1
    jr  z,.noreset1
    cp  2
    jr  z,.noreset1
    call    GBM_ResetFreqOffset1
    xor     a
    ld      [GBM_ArpTick1],a
.noreset1
    pop af
.freq1
    ld  [GBM_Note1],a
    ld  e,0
    call    GBMod_GetFreq2
    ; ch1 volume
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.skipvol1
    ld  a,[GBM_Command1]
    cp  $a
    jr  z,.skipvol1
    ld  a,[hl]
    swap    a
    and $f
    jr  z,.skipvol1
    ld  b,a
    rla
    rla
    rla
    ld  [GBM_Vol1],a
    ld  a,b
    swap    a
    ldh [rNR12],a
    set 7,e
.skipvol1
    ; ch1 pulse
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    ld  b,a
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.skippulse1
    ld  a,b
    and $f
    jr  z,.skippulse1
    dec a
    ld  [GBM_Pulse1],a
    swap    a
    rla
    rla
    ldh [rNR11],a
.skippulse1
    ; ch1 command
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    ld  [GBM_Command1],a
    ; ch1 param
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    ld  [GBM_Param1],a
    ; update freq
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.ch2
    ld  a,d
    ldh [rNR13],a
    ld  a,e
    ldh [rNR14],a
    jr  .ch2
.skip1
    pop af
    ld  a,[GBM_Note1]
    jr  .freq1

.ch2
    ; ch2 note
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    push    af
    cp  $ff
    jp  z,.skip2
    cp  $fe
    jr  nz,.nocut2
    xor a
    ld  [GBM_Vol2],a
    ldh [rNR22],a
    ld  a,%10000000
    ldh [rNR24],a
    jp  .skip2
.nocut2
    inc hl
    ld  a,[hl]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    dec hl
    bit 6,h
    call    z,GBM_HandlePageBoundaryBackwards
    cp  1
    jr  z,.noreset2
    cp  2
    jr  z,.noreset2
    call    GBM_ResetFreqOffset2
    xor     a
    ld      [GBM_ArpTick2],a
.noreset2
    pop af
.freq2
    ld  [GBM_Note2],a
    ld  e,1
    call    GBMod_GetFreq2
    ; ch2 volume
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.skipvol2
    ld  a,[GBM_Command2]
    cp  $a
    jr  z,.skipvol2
    ld  a,[hl]
    swap    a
    and $f
    jr  z,.skipvol2
    ld  b,a
    rla
    rla
    rla
    ld  [GBM_Vol2],a
    ld  a,b
    swap    a
    ldh [rNR22],a
    set 7,e
.skipvol2
    ; ch2 pulse
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    ld  b,a
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.skippulse2
    ld  a,b
    and $f
    jr  z,.skippulse2
    dec a
    ld  [GBM_Pulse2],a
    swap    a
    rla
    rla
    ldh [rNR21],a
.skippulse2
    ; ch2 command
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    ld  [GBM_Command2],a
    ; ch2 param
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    ld  [GBM_Param2],a
    ; update freq
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.ch3
    ld  a,d
    ldh [rNR23],a
    ld  a,e
    ldh [rNR24],a
    jr  .ch3
.skip2
    pop af
    ld  a,[GBM_Note2]
    jr  .freq2
    
.ch3
    ; ch3 note
    ld  a,[GBM_SamplePlaying]
    and a
    jp  nz,.sample3
.note3
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    push    af
    cp  $ff
    jp  z,.skip3
    cp  $fe
    jr  nz,.nocut3
    xor a
    ld  [GBM_Vol3],a
    ldh [rNR32],a
    jp  .skip3
.nocut3
    inc hl
    bit 7,h
    call    nz,GBM_HandlePageBoundary 
    ld  a,[hl]
    dec hl
    bit 6,h
    call    z,GBM_HandlePageBoundaryBackwards
    cp  1
    jr  z,.noreset3
    cp  2
    jr  z,.noreset3
    call    GBM_ResetFreqOffset3
    xor     a
    ld      [GBM_ArpTick3],a
.noreset3
    pop af
    cp  $80
    jp  z,.playsample3
.freq3
    ld  [GBM_Note3],a
    ld  e,2
    call    GBMod_GetFreq2
    ; ch3 volume
    ld  a,[hl]
    swap    a
    and $f
    jr  z,.skipvol3
    ld  [GBM_Vol3],a
    call    GBMod_GetVol3
    ld  b,a
    ld  a,[GBM_OldVol3]
    cp  b
    jr  z,.skipvol3
    ld  a,[GBM_SkipCH3]
    and a
    jr  nz,.skipvol3
    ld  a,b
    ldh [rNR32],a
    set 7,e
.skipvol3
    ld  [GBM_OldVol3],a
    ; ch3 wave
    ld  a,[hl+]
    bit 7,h
    call   nz,GBM_HandlePageBoundary 
    dec a
    and $f
    cp  15
    jr  z,.continue3
    ld  b,a
    ld  a,[GBM_LastWave]
    cp  b
    jr  z,.continue3
    ld  a,b
    ld  [GBM_Wave3],a
    ld  [GBM_LastWave],a
    push    hl
    call    GBM_LoadWave
    set 7,e
    pop hl
.continue3
    ; ch3 command
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    ld  [GBM_Command3],a
    ; ch3 param
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    ld  [GBM_Param3],a
    ; update freq   
    ld  a,[GBM_SkipCH3]
    and a
    jr  nz,.ch4
    ld  a,d
    ldh [rNR33],a
    ld  a,e
    ldh [rNR34],a
    jr  .ch4
.skip3
    pop af
    ld  a,[GBM_Note3]
    jp  .freq3
.playsample3
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    call    GBMod_PlaySample
    jr  .continue3
.sample3
    ld  a,[hl]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    cp  $ff
    jr  z,.nostopsample3
    xor a
    ld  [GBM_SamplePlaying],a
    jp  .note3
.nostopsample3
    ld  a,l
    add 4
    ld  l,a
    jr  nc,.ch4
    inc h
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    
.ch4
    ; ch4 note
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    cp  $ff
    jr  z,.skip4
    cp  $fe
    jr  nz,.freq4
    xor a
    ld  [GBM_Vol4],a
    ldh [rNR42],a
    ld  a,%10000000
    ldh [rNR44],a
    jr  .skip4
    
.freq4
    ld  [GBM_Note4],a
    push    hl
    ld  hl,NoiseTable
    add l
    ld  l,a
    jr  nc,.nocarry
    inc h
.nocarry
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    ld  d,a
    pop hl
    ; ch4 volume
    ld  a,[GBM_SkipCH4]
    and a
    jr  nz,.skipvol4
    inc hl
    ld  a,[hl]
    dec hl
    cp  $a
    jr  nz,.disablecmd4
.dovol4
    ld  a,[hl]
    swap    a
    and $f
    ld  b,a
    rla
    rla
    rla
    ld  [GBM_Vol4],a
    ld  a,b
    swap    a
    ldh [rNR42],a
    jr  .skipvol4
.disablecmd4
    xor a
    ld  [GBM_Command4],a
    jr  .dovol4
.skipvol4
    ; ch4 mode
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    and a
    jr  z,.nomode
    dec a
    and 1
    ld  [GBM_Mode4],a
    and a
    jr  z,.nomode
    set 3,d
.nomode
    ; ch4 command
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    ld  [GBM_Command4],a
    ; ch4 param
    ld  a,[hl+]
    bit 7,h
    call    nz,GBM_HandlePageBoundary
    ld  [GBM_Param4],a
    ; set freq
    ld  a,[GBM_SkipCH4]
    and a
    jr  nz,.updateRow
    ld  a,d
    ldh [rNR43],a
    ld  a,$80
    ldh [rNR44],a
    jr  .updateRow
.skip4
    ld  a,[GBM_Note4]
    jr  .freq4
    
.updateRow
    call    GBM_ResetCommandTick
    ld  a,[GBM_CurrentRow]
    inc a
    cp  64
    jr  z,.nextPattern
    ld  [GBM_CurrentRow],a
    jr  .done
.nextPattern
    xor a
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_PatTablePos]
    inc a
    ld  b,a
    ld  a,[GBM_PatTableSize]
    cp  b
    jr  z,.loopSong
    ld  a,b
    ld  [GBM_PatTablePos],a
    jr  .setPattern
.loopSong
    xor a
    ld  [GBM_PatTablePos],a
.setPattern
    push    af
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    pop af
    ld  hl,$40f0
    add l
    ld  l,a
    jr  nc,:+
    inc h
:   ld  a,[hl+]
    ld  [GBM_CurrentPattern],a
.done
    
GBMod_UpdateCommands:
    ld  a,$ff
    ld  [GBM_PanFlags],a
    ; ch1
    ld  a,[GBM_Command1]
    ld  hl,.commandTable1
    add a
    add l
    ld  l,a
    jr  nc,.nocarry1
    inc h
.nocarry1
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    jp  hl
    
.commandTable1
    dw  .arp1           ; 0xy - arp
    dw  .slideup1       ; 1xy - note slide up
    dw  .slidedown1     ; 2xy - note slide down
    dw  .ch2            ; 3xy - portamento (NYI)
    dw  .ch2            ; 4xy - vibrato (handled elsewhere)
    dw  .ch2            ; 5xy - portamento + volume slide (NYI)
    dw  .ch2            ; 6xy - vibrato + volume slide (NYI)
    dw  .ch2            ; 7xy - tremolo (NYI)
    dw  .pan1           ; 8xy - panning
    dw  .ch2            ; 9xy - sample offset (won't be implemented)
    dw  .volslide1      ; Axy - volume slide
    dw  .patjump1       ; Bxy - pattern jump
    dw  .ch2            ; Cxy - set volume (won't be implemented)
    dw  .patbreak1      ; Dxy - pattern break
    dw  .ch2            ; Exy - extended commands (NYI)
    dw  .speed1         ; Fxy - set module speed
.arp1
    ld  a,[GBM_Param1]
    and a
    jp  z,.ch2
    ld  a,[GBM_ArpTick1]
    inc a
    cp  4
    jr  nz,.noresetarp1
    ld  a,1
.noresetarp1
    ld  [GBM_ArpTick1],a
    ld  a,[GBM_Param1]
    ld  b,a
    ld  a,[GBM_Note1]
    ld  c,a
    ld  a,[GBM_ArpTick1]
    dec a
    call    GBMod_DoArp
    ld  a,[GBM_SkipCH1]
    and a
    jp  nz,.ch2
    ld  a,d
    ldh [rNR13],a
    ld  a,e
    ldh [rNR14],a
    jp  .ch2
.slideup1
    ld  a,[GBM_Param1]
    ld  b,a
    ld  e,0
    call    GBMod_DoPitchSlide
    ld  a,[GBM_Note1]
    call    GBMod_GetFreq2
    jp  .dosetfreq1
.slidedown1
    ; read tick speed
    ld  a,[GBM_Param1]
    ld  b,a
    ld  e,0
    call    GBMod_DoPitchSlide
    ld  a,[GBM_Note1]
    call    GBMod_GetFreq2
    jp  .dosetfreq1
.pan1
    ld  a,[GBM_Param1]
    cpl
    and $11
    ld  b,a
    ld  a,[GBM_PanFlags]
    xor b
    ld  [GBM_PanFlags],a
    jp  .ch2
.patbreak1
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    ld  a,[GBM_Param1]
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_PatTablePos]
    inc a
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    jr  nc,:+
    inc h
:   ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command1],a
    ld  [GBM_Param1],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.patjump1
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    xor a
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_Param1]
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command1],a
    ld  [GBM_Param1],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.volslide1
    ld  a,[GBM_ModuleSpeed]
    ld  b,a
    ld  a,[GBM_ModuleTimer]
    cp  b
    jr  z,.ch2  ; skip first tick
    
    ld  a,[GBM_Param1]
    cp  $10
    jr  c,.volslide1_dec
.volslide1_inc
    swap    a
    and $f
    ld  b,a
    ld  a,[GBM_Vol1]
    add b
    jr  .volslide1_nocarry
.volslide1_dec
    ld  b,a
    ld  a,[GBM_Vol1]
    sub b
    jr  nc,.volslide1_nocarry
    xor a
.volslide1_nocarry
    ld  [GBM_Vol1],a
    rra
    rra
    rra
    and $f
    ld  b,a
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.ch2
    ld  a,b
    swap    a
    ld  [rNR12],a
    ld  a,[GBM_Note1]
    call    GBMod_GetFreq
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.ch2
    ld  a,d
    ldh [rNR13],a
    ld  a,e
    or  $80
    ldh [rNR14],a
    jr  .ch2
.dosetfreq1
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.ch2
    ld  a,d
    ldh [rNR13],a
    ld  a,e
    ldh [rNR14],a
    jr  .ch2
.speed1
    ld  a,[GBM_SpeedChanged]
    and a
    jr  nz,.ch2
    ld  a,[GBM_Param1]
    ld  [GBM_ModuleSpeed],a
    ld  [GBM_ModuleTimer],a
    ld  a,1
    ld  [GBM_SpeedChanged],a
    
.ch2
    ld  a,[GBM_Command1]
    cp  4
    jr  nz,.novib1
    ld  a,[GBM_Note1]
    call    GBMod_GetFreq
    ld  h,d
    ld  l,e
    ld  a,[GBM_FreqOffset1]
    add h
    ld  h,a
    jr  nc,.continue1
    inc l
.continue1
    ld  a,[GBM_SkipCH1]
    and a
    jr  nz,.novib1
    ld  a,h
    ldh [rNR13],a
    ld  a,l
    ldh [rNR14],a
.novib1
    
    ld  a,[GBM_Command2]
    ld  hl,.commandTable2
    add a
    add l
    ld  l,a
    jr  nc,.nocarry2
    inc h
.nocarry2
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    jp  hl
    
.commandTable2
    dw  .arp2           ; 0xy - arp
    dw  .slideup2       ; 1xy - note slide up
    dw  .slidedown2     ; 2xy - note slide down
    dw  .ch3            ; 3xy - portamento (NYI)
    dw  .ch3            ; 4xy - vibrato (handled elsewhere)
    dw  .ch3            ; 5xy - portamento + volume slide (NYI)
    dw  .ch3            ; 6xy - vibrato + volume slide (NYI)
    dw  .ch3            ; 7xy - tremolo (NYI)
    dw  .pan2           ; 8xy - panning
    dw  .ch3            ; 9xy - sample offset (won't be implemented)
    dw  .volslide2      ; Axy - volume slide
    dw  .patjump2       ; Bxy - pattern jump
    dw  .ch3            ; Cxy - set volume (won't be implemented)
    dw  .patbreak2      ; Dxy - pattern break
    dw  .ch3            ; Exy - extended commands (NYI)
    dw  .speed2         ; Fxy - set module speed
.arp2
    ld  a,[GBM_Param2]
    and a
    jp  z,.ch3
    ld  a,[GBM_ArpTick2]
    inc a
    cp  4
    jr  nz,.noresetarp2
    ld  a,1
.noresetarp2
    ld  [GBM_ArpTick2],a
    ld  a,[GBM_Param2]
    ld  b,a
    ld  a,[GBM_Note2]
    ld  c,a
    ld  a,[GBM_ArpTick2]
    dec a
    call    GBMod_DoArp
    ld  a,[GBM_SkipCH2]
    and a
    jp  nz,.ch3
    ld  a,d
    ldh [rNR23],a
    ld  a,e
    ldh [rNR24],a
    jp  .ch3
.slideup2
    ld  a,[GBM_Param2]
    ld  b,a
    ld  e,1
    call    GBMod_DoPitchSlide
    ld  a,[GBM_Note2]
    call    GBMod_GetFreq2
    jp  .dosetfreq2
.slidedown2
    ; read tick speed
    ld  a,[GBM_Param2]
    ld  b,a
    ld  e,1
    call    GBMod_DoPitchSlide
    ld  a,[GBM_Note2]
    call    GBMod_GetFreq2
    jp  .dosetfreq2
.pan2
    ld  a,[GBM_Param2]
    cpl
    and $11
    rla
    ld  b,a
    ld  a,[GBM_PanFlags]
    xor b
    ld  [GBM_PanFlags],a
    jp  .ch3
.patbreak2
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    ld  a,[GBM_Param2]
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_PatTablePos]
    inc a
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    jr  nc,:+
    inc h
:   ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command2],a
    ld  [GBM_Param2],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.patjump2
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    xor a
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_Param2]
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command2],a
    ld  [GBM_Param2],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.volslide2
    ld  a,[GBM_ModuleSpeed]
    ld  b,a
    ld  a,[GBM_ModuleTimer]
    cp  b
    jr  z,.ch3  ; skip first tick

    ld  a,[GBM_Param2]
    cp  $10
    jr  c,.volslide2_dec
.volslide2_inc
    swap    a
    and $f
    ld  b,a
    ld  a,[GBM_Vol2]
    add b
    jr  .volslide2_nocarry
.volslide2_dec
    ld  b,a
    ld  a,[GBM_Vol2]
    sub b
    jr  nc,.volslide2_nocarry
    xor a
.volslide2_nocarry
    ld  [GBM_Vol2],a
    rra
    rra
    rra
    and $f
    ld  b,a
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.ch3
    ld  a,b
    swap    a
    ld  [rNR22],a
    ld  a,[GBM_Note2]
    call    GBMod_GetFreq
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.ch3
    ld  a,d
    ldh [rNR23],a
    ld  a,e
    or  $80
    ldh [rNR24],a
    jr  .ch3
.dosetfreq2
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.ch3
    ld  a,d
    ldh [rNR23],a
    ld  a,e
    ldh [rNR24],a
    jr  .ch3
.speed2
    ld  a,[GBM_SpeedChanged]
    and a
    jr  nz,.ch3
    ld  a,[GBM_Param2]
    ld  [GBM_ModuleSpeed],a
    ld  [GBM_ModuleTimer],a
    ld  a,1
    ld  [GBM_SpeedChanged],a
    
.ch3
    ld  a,[GBM_Command2]
    cp  4
    jr  nz,.novib2
    ld  a,[GBM_Note2]
    call    GBMod_GetFreq
    ld  h,d
    ld  l,e
    ld  a,[GBM_FreqOffset2]
    add h
    ld  h,a
    jr  nc,.continue2
    inc l
.continue2
    ld  a,[GBM_SkipCH2]
    and a
    jr  nz,.novib2
    ld  a,h
    ldh [rNR23],a
    ld  a,l
    ldh [rNR24],a
.novib2

    ld  a,[GBM_Command3]
    ld  hl,.commandTable3
    add a
    add l
    ld  l,a
    jr  nc,.nocarry3
    inc h
.nocarry3
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    jp  hl
    
.commandTable3
    dw  .arp3           ; 0xy - arp
    dw  .slideup3       ; 1xy - note slide up
    dw  .slidedown3     ; 2xy - note slide down
    dw  .ch4            ; 3xy - portamento (NYI)
    dw  .ch4            ; 4xy - vibrato (handled elsewhere)
    dw  .ch4            ; 5xy - portamento + volume slide (NYI)
    dw  .ch4            ; 6xy - vibrato + volume slide (NYI)
    dw  .ch4            ; 7xy - tremolo (doesn't apply for CH3)
    dw  .pan3           ; 8xy - panning
    dw  .ch4            ; 9xy - sample offset (won't be implemented)
    dw  .ch4            ; Axy - volume slide (doesn't apply for CH3)
    dw  .patjump3       ; Bxy - pattern jump
    dw  .ch4            ; Cxy - set volume (won't be implemented)
    dw  .patbreak3      ; Dxy - pattern break
    dw  .ch4            ; Exy - extended commands (NYI)
    dw  .speed3         ; Fxy - set module speed
    
.arp3
    ld  a,[GBM_Param3]
    and a
    jp  z,.ch4
    ld  a,[GBM_ArpTick3]
    inc a
    cp  4
    jr  nz,.noresetarp3
    ld  a,1
.noresetarp3
    ld  [GBM_ArpTick3],a
    ld  a,[GBM_Param3]
    ld  b,a
    ld  a,[GBM_Note3]
    ld  c,a
    ld  a,[GBM_ArpTick3]
    dec a
    call    GBMod_DoArp
    ld  a,[GBM_SkipCH3]
    and a
    jp  nz,.ch4
    ld  a,d
    ldh [rNR33],a
    ld  a,e
    ldh [rNR34],a
    jp  .ch4
.slideup3
    ld  a,[GBM_Param3]
    ld  b,a
    ld  e,2
    call    GBMod_DoPitchSlide
    ld  a,[GBM_Note3]
    call    GBMod_GetFreq2
    jp  .dosetfreq3
.slidedown3
    ; read tick speed
    ld  a,[GBM_Param3]
    ld  b,a
    ld  e,2
    call    GBMod_DoPitchSlide
    ld  a,[GBM_Note3]
    call    GBMod_GetFreq2
    jp  .dosetfreq3
.pan3
    ld  a,[GBM_Param3]
    cpl
    and $11
    rla
    ld  b,a
    ld  a,[GBM_PanFlags]
    xor b
    ld  [GBM_PanFlags],a
    jp  .ch4
.patbreak3
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    ld  a,[GBM_Param3]
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_PatTablePos]
    inc a
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    jr  nc,:+
    inc h
:   ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command3],a
    ld  [GBM_Param3],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.patjump3
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    xor a
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_Param3]
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command3],a
    ld  [GBM_Param3],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.dosetfreq3
    ld  a,[GBM_SkipCH3]
    and a
    jr  nz,.ch4
    ld  a,d
    ldh [rNR33],a
    ld  a,e
    ldh [rNR34],a
    jr  .ch4
.speed3
    ld  a,[GBM_SpeedChanged]
    and a
    jr  nz,.ch4
    ld  a,[GBM_Param3]
    ld  [GBM_ModuleSpeed],a
    ld  [GBM_ModuleTimer],a
    ld  a,1
    ld  [GBM_SpeedChanged],a

.ch4
    ld  a,[GBM_Command3]
    cp  4
    jr  nz,.novib3
    ld  a,[GBM_SkipCH3]
    and a
    jp  nz,.novib3
    ld  a,[GBM_Note3]
    call    GBMod_GetFreq
    ld  h,d
    ld  l,e
    ld  a,[GBM_FreqOffset3]
    add h
    ld  h,a
    jr  nc,.continue3
    inc l
.continue3
    ld  a,h
    ldh [rNR33],a
    ld  a,l
    ldh [rNR34],a
.novib3


    ld  a,[GBM_Command4]
    ld  hl,.commandTable4
    add a
    add l
    ld  l,a
    jr  nc,.nocarry4
    inc h
.nocarry4
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    jp  hl
    
.commandTable4
    dw  .arp4           ; 0xy - arp
    dw  .done           ; 1xy - note slide up (doesn't apply for CH4)
    dw  .done           ; 2xy - note slide down (doesn't apply for CH4)
    dw  .done           ; 3xy - portamento (doesn't apply for CH4)
    dw  .done           ; 4xy - vibrato (doesn't apply for CH4)
    dw  .done           ; 5xy - portamento + volume slide (doesn't apply for CH4)
    dw  .done           ; 6xy - vibrato + volume slide (doesn't apply for CH4)
    dw  .done           ; 7xy - tremolo (NYI)
    dw  .pan4           ; 8xy - panning
    dw  .done           ; 9xy - sample offset (won't be implemented)
    dw  .volslide4      ; Axy - volume slide
    dw  .patjump4       ; Bxy - pattern jump
    dw  .done           ; Cxy - set volume (won't be implemented)
    dw  .patbreak4      ; Dxy - pattern break
    dw  .done           ; Exy - extended commands (NYI)
    dw  .speed4         ; Fxy - set module speed
.arp4
    ld  a,[GBM_Param4]
    and a
    jp  z,.done
    ld  a,[GBM_ArpTick4]
    inc a
    cp  4
    jr  nz,.noresetarp4
    ld  a,1
.noresetarp4
    ld  [GBM_ArpTick4],a
    ld  a,[GBM_Param4]
    ld  b,a
    ld  a,[GBM_Note4]
    ld  c,a
    ld  a,[GBM_ArpTick4]
    dec a
    call    GBMod_DoArp4
    ld  hl,NoiseTable
    add l
    ld  l,a
    jr  nc,.nocarry5
    inc h
.nocarry5
    ld  a,[hl]
    ldh [rNR43],a
    jp  .done
.pan4
    ld  a,[GBM_Param4]
    cpl
    and $11
    ld  b,a
    ld  a,[GBM_PanFlags]
    xor b
    ld  [GBM_PanFlags],a
    jp  .done
.patbreak4
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    ld  a,[GBM_Param4]
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_PatTablePos]
    inc a
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    jr  nc,:+
    inc h
:   ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command4],a
    ld  [GBM_Param4],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.patjump4
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    xor a
    ld  [GBM_CurrentRow],a
    ld  a,[GBM_Param4]
    ld  [GBM_PatTablePos],a
    ld  hl,$40f0
    add l
    ld  l,a
    ld  a,[hl]
    ld  [GBM_CurrentPattern],a
    xor a
    ld  [GBM_Command4],a
    ld  [GBM_Param4],a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    jp  .done
.volslide4
    ld  a,[GBM_ModuleSpeed]
    ld  b,a
    ld  a,[GBM_ModuleTimer]
    cp  b
    jr  z,.done ; skip first tick

    ld  a,[GBM_Param4]
    cp  $10
    jr  c,.volslide4_dec
.volslide4_inc
    swap    a
    and $f
    ld  b,a
    ld  a,[GBM_Vol4]
    add b
    jr  .volslide4_nocarry
.volslide4_dec
    ld  b,a
    ld  a,[GBM_Vol4]
    sub b
    jr  nc,.volslide4_nocarry
    xor a
.volslide4_nocarry
    ld  [GBM_Vol4],a
    rra
    rra
    rra
    and $f
    ld  b,a
    ld  a,[GBM_SkipCH4]
    and a
    jr  nz,.done
    ld  a,b
    swap    a
    ld  [rNR42],a
    ld  a,[GBM_Note4]
    call    GBMod_GetFreq
    ld  a,[GBM_SkipCH4]
    and a
    jr  nz,.done
    or  $80
    ldh [rNR44],a
    jr  .done   
.speed4
    ld  a,[GBM_SpeedChanged]
    and a
    jr  nz,.done
    ld  a,[GBM_Param4]
    ld  [GBM_ModuleSpeed],a
    ld  [GBM_ModuleTimer],a
    ld  a,1
    ld  [GBM_SpeedChanged],a
    
.done
    ld  a,[GBM_PanFlags]
    ldh [rNR51],a

    ld  a,1
    ld  [rROMB0],a
    ret
    
GBMod_DoArp:
    call    GBMod_DoArp4
    jp  GBMod_GetFreq
    ret

GBMod_DoArp4:
    and a
    jr  z,.arp0
    dec a
    jr  z,.arp1
    dec a
    jr  z,.arp2
    ret ; default case
.arp0
    xor a
    ld  b,a
    jr  .getNote
.arp1
    ld  a,b
    swap    a
    and $f
    ld  b,a
    jr  .getNote
.arp2
    ld  a,b
    and $f
    ld  b,a
.getNote
    ld  a,c
    add b
    ret
    
; Input: e = current channel
GBMod_DoVib:
    ld  hl,GBM_Command1
    call    GBM_AddChannelID
    ld  a,[hl]
    cp  4
    ret nz  ; return if vibrato is disabled
    ; get vibrato tick
    ld  hl,GBM_Param1
    call    GBM_AddChannelID
    ld  a,[hl]
    push    af
    swap    a
    cpl
    and $f
    ld  b,a
    ld  hl,GBM_CmdTick1
    call    GBM_AddChannelID
    ld  a,[hl]
    and a
    jr  z,.noexit
    pop af
    dec [hl]
    ret
.noexit
    ld  [hl],b
    ; get vibrato depth
    pop af
    and $f
    ld  d,a
    ld  hl,GBM_ArpTick1
    call    GBM_AddChannelID
    ld  a,[hl]
    xor 1
    ld  [hl],a
    and a
    jr  nz,.noreset2
    ld  hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld  [hl],0
    ret
.noreset2
    ld  hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld  a,d
    rr  d
    add d
    ld  [hl],a
    ret

; INPUT: e=channel ID
GBMod_DoPitchSlide:
    push    bc
    push    de
    ld  hl,GBM_Command1
    call    GBM_AddChannelID
    ld  a,[hl]
    cp  1
    jr  z,.slideup
    cp  2
    jr  nz,.done
.slidedown
    call    .getparam
    xor a
    sub c
    ld  c,a
    ld  a,0
    sbc b
    ld  b,a
    jr  .setoffset
.slideup
    call    .getparam
.setoffset
    add hl,bc
    add hl,bc
    add hl,bc
    add hl,bc
    ld  b,h
    ld  c,l
    ld  hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld  a,c
    ld  [hl+],a
    ld  a,b
    ld  [hl],a
    call    .getparam
    jr  .done
.getparam
    ld  hl,GBM_Param1
    call    GBM_AddChannelID
    ld  a,[hl]
    ld  c,a
    ld  b,0
    ld  hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    ret
.done
    pop de
    pop bc
    ret
    
GBM_AddChannelID:
    ld  a,e
GBM_AddChannelID_skip:
    add l
    ld  l,a
    ret nc
    inc h
    ret
    
GBM_AddChannelID16:
    ld  a,e
    add a
    jr  GBM_AddChannelID_skip
    
GBM_ResetCommandTick:
.ch1
    ld  a,[GBM_Command1]
    cp  4
    jr  z,.ch2
    xor a
    ld  [GBM_CmdTick1],a
.ch2
    ld  a,[GBM_Command2]
    cp  4
    jr  z,.ch3
    xor a
    ld  [GBM_CmdTick2],a
.ch3
    ld  a,[GBM_Command3]
    cp  4
    jr  z,.ch4
    xor a
    ld  [GBM_CmdTick3],a
.ch4
    xor a
    ld  [GBM_CmdTick4],a
    ret
    
    
; input:  a = note id
;         b = channel ID
; output: de = frequency
GBMod_GetFreq:
    push    af
    push    bc
    push    hl
    ld  de,0
    ld  l,a
    ld  h,0
    jr  GBMod_DoGetFreq
GBMod_GetFreq2:
    push    af
    push    bc
    push    hl
    ld  c,a
    ld  hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld  a,[hl+]
    ld  d,[hl]
    ld  e,a
    ld  l,c
    ld  h,0
GBMod_DoGetFreq:
    add hl,hl   ; x1
    add hl,hl   ; x2
    add hl,hl   ; x4
    add hl,hl   ; x8
    add hl,hl   ; x16
    add hl,hl   ; x32
    add hl,hl   ; x64
    ld  b,h
    ld  c,l
    ld  a,bank(FreqTable)
    ld  [rROMB0],a
    ld  hl,FreqTable
    add hl,bc
    add hl,de
    ld  a,[hl+]
    ld  d,a
    ld  a,[hl]
    ld  e,a
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    pop hl
    pop bc
    pop af
    ret
    
GBM_ResetFreqOffset1:
    push    af
    push    hl
    xor a
    ld  [GBM_Command1],a
    ld  [GBM_Param1],a
    ld  hl,GBM_FreqOffset1
    jr  GBM_DoResetFreqOffset
GBM_ResetFreqOffset2:
    push    af
    push    hl
    xor a
    ld  [GBM_Command2],a
    ld  [GBM_Param2],a
    ld  hl,GBM_FreqOffset2
    jr  GBM_DoResetFreqOffset
GBM_ResetFreqOffset3:
    push    af
    push    hl
    xor a
    ld  [GBM_Command3],a
    ld  [GBM_Param3],a
    ld  hl,GBM_FreqOffset3
GBM_DoResetFreqOffset:
    ld  [hl+],a
    ld  [hl],a
    pop hl
    pop af
    ret
    
GBMod_GetVol3:
    push    hl
    ld  hl,WaveVolTable
    add l
    ld  l,a
    jr  nc,.nocarry
    inc h
.nocarry
    ld  a,[hl]
    pop hl
    ret

; INPUT: a = wave ID
GBM_LoadWave:
    and $f
    add a
    push    af
    ld  a,[GBM_SongID]
    inc a
    ld  [rROMB0],a
    pop af
    ld  hl,GBM_PulseWaves
    add l
    ld  l,a
    jr  nc,.nocarry2
    inc h
.nocarry2
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    call    GBM_CopyWave
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    ret
GBM_CopyWave:
    ldh a,[rNR51]
    push    af
    and %10111011
    ldh [rNR51],a   ; prevent spike on GBA
    xor a
    ldh [rNR30],a
    ld  bc,$1030
.loop
    ld  a,[hl+]
    ld  [c],a
    inc c
    dec b
    jr  nz,.loop
    ld  a,%10000000
    ldh [rNR30],a
    pop af
    ldh [rNR51],a
    ret

; INPUT: a = sample ID
GBMod_PlaySample:
    ld  [GBM_SampleID],a
    push    hl
    ld  c,a
    ld  b,0
    ld  hl,GBM_SampleTable
    add hl,bc
    add hl,bc
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    ; bank
    ld  a,[hl+]
    ld  [GBM_SampleBank],a
    ; pointer
    ld  a,[hl+]
    ld  [GBM_SamplePointer],a
    ld  a,[hl+]
    ld  [GBM_SamplePointer+1],a
    ; counter
    ld  a,[hl+]
    ld  [GBM_SampleCounter],a
    ld  a,[hl]
    ld  [GBM_SampleCounter+1],a
    ld  a,1
    ld  [GBM_SamplePlaying],a
    jr  GBMod_UpdateSample2
    
GBMod_UpdateSample:
    push    hl
GBMod_UpdateSample2:
    ld  a,[GBM_SamplePlaying]
    and a
    ret z   ; return if sample not playing
    ld  a,[GBM_SampleBank]
    ld  [rROMB0],a
    ld  hl,GBM_SamplePointer
    ld  a,[hl+]
    ld  h,[hl]
    ld  l,a
    call    GBM_CopyWave
    ld  a,%00100000
    ldh [rNR32],a
    ld  a,$d4
    ldh [rNR33],a
    ld  a,$83
    ldh [rNR34],a
    ld  a,[GBM_SampleCounter]
    sub 16
    ld  [GBM_SampleCounter],a
    jr  nc,.skiphigh
    ld  a,[GBM_SampleCounter+1]
    dec a
    ld  [GBM_SampleCounter+1],a
.skiphigh
    ld  b,a
    ld  a,l
    ld  [GBM_SamplePointer],a
    ld  a,h
    ld  [GBM_SamplePointer+1],a
    ld  a,[GBM_SampleCounter+1]
    ld  b,a
    ld  a,[GBM_SampleCounter]
    or  b
    jr  nz,.done
    xor a
    ld  [GBM_SamplePlaying],a
    ld  a,[GBM_Wave3]
    call    GBM_LoadWave

    pop hl
    ret
.done
    ld  a,[GBM_SongID]
    inc a
    ld  b,a
    ld  a,[GBM_CurrentBank]
    add b
    ld  [rROMB0],a
    pop hl
    ret

GBM_HandlePageBoundary:
    push    af
    push    bc
    ld  a,[GBM_CurrentBank]
    inc a
    ld  [GBM_CurrentBank],a
    ld  b,a
    ld  a,[GBM_SongID]
    inc a
    add b
    ld  [rROMB0],a
    ld  h,$40
    pop bc
    pop af
    ret
    
GBM_HandlePageBoundaryBackwards:
    push    af
    push    bc
    ld  a,[GBM_CurrentBank]
    dec a
    ld  [GBM_CurrentBank],a
    ld  b,a
    ld  a,[GBM_SongID]
    inc a
    add b
    ld  [rROMB0],a
    ld  a,h
    sub $40
    ld  h,a
    pop bc
    pop af
    ret

GBM_PulseWaves:
    dw  wave_Pulse125,wave_Pulse25,wave_Pulse50,wave_Pulse75
    dw  $4030,$4040,$4050,$4060
    dw  $4070,$4080,$4090,$40a0
    dw  $40b0,$40c0,$40d0,$40e0
    
; evil optimization hax for pulse wave data
; should result in the following:
; wave_Pulse75:  $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00
; wave_Pulse50:  $ff,$ff,$ff,$ff,$ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00
; wave_Pulse25:  $ff,$ff,$ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
; wave_Pulse125: $ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
wave_Pulse75:   db  $ff,$ff,$ff,$ff
wave_Pulse50:   db  $ff,$ff,$ff,$ff
wave_Pulse25:   db  $ff,$ff
wave_Pulse125:  db  $ff,$ff,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; last four bytes read from WaveVolumeTable
    
WaveVolTable:   
    db  $00,$00,$00,$00,$60,$60,$60,$60,$40,$40,$40,$40,$20,$20,$20,$20

; ================================

NoiseTable: ; taken from deflemask
    db  $a4 ; 15 steps
    db  $97,$96,$95,$94,$87,$86,$85,$84,$77,$76,$75,$74,$67,$66,$65,$64
    db  $57,$56,$55,$54,$47,$46,$45,$44,$37,$36,$35,$34,$27,$26,$25,$24
    db  $17,$16,$15,$14,$07,$06,$05,$04,$03,$02,$01,$00

include "GBMod_SampleData.asm"
   

; shamelessly ripped from Fatass's player
section "GBMod - Frequency table",romx
FreqTable:
    dw $0022,$0024,$0026,$0028,$002a,$002b,$002d,$002f ; c-3 + 0-7
    dw $0031,$0033,$0034,$0036,$0038,$003a,$003c,$003d ; c-3 + 8-15
    dw $003f,$0041,$0043,$0045,$0046,$0048,$004a,$004c ; c-3 + 16-23
    dw $004e,$004f,$0051,$0053,$0055,$0056,$0058,$005a ; c-3 + 24-31
    dw $005c,$005d,$005f,$0061,$0063,$0065,$0066,$0068 ; c-3 + 32-39
    dw $006a,$006c,$006d,$006f,$0071,$0073,$0074,$0076 ; c-3 + 40-47
    dw $0078,$007a,$007b,$007d,$007f,$0080,$0082,$0084 ; c-3 + 48-55
    dw $0086,$0087,$0089,$008b,$008d,$008e,$0090,$0092 ; c-3 + 56-63
    dw $0093,$0095,$0097,$0099,$009a,$009c,$009e,$009f ; c#3 + 0-7
    dw $00a1,$00a3,$00a4,$00a6,$00a8,$00aa,$00ab,$00ad ; c#3 + 8-15
    dw $00af,$00b0,$00b2,$00b4,$00b5,$00b7,$00b9,$00ba ; c#3 + 16-23
    dw $00bc,$00be,$00bf,$00c1,$00c3,$00c5,$00c6,$00c8 ; c#3 + 24-31
    dw $00ca,$00cb,$00cd,$00cf,$00d0,$00d2,$00d3,$00d5 ; c#3 + 32-39
    dw $00d7,$00d8,$00da,$00dc,$00dd,$00df,$00e1,$00e2 ; c#3 + 40-47
    dw $00e4,$00e6,$00e7,$00e9,$00eb,$00ec,$00ee,$00ef ; c#3 + 48-55
    dw $00f1,$00f3,$00f4,$00f6,$00f8,$00f9,$00fb,$00fc ; c#3 + 56-63
    dw $00fe,$0100,$0101,$0103,$0105,$0106,$0108,$0109 ; d-3 + 0-7
    dw $010b,$010d,$010e,$0110,$0111,$0113,$0115,$0116 ; d-3 + 8-15
    dw $0118,$0119,$011b,$011d,$011e,$0120,$0121,$0123 ; d-3 + 16-23
    dw $0125,$0126,$0128,$0129,$012b,$012c,$012e,$0130 ; d-3 + 24-31
    dw $0131,$0133,$0134,$0136,$0137,$0139,$013b,$013c ; d-3 + 32-39
    dw $013e,$013f,$0141,$0142,$0144,$0145,$0147,$0149 ; d-3 + 40-47
    dw $014a,$014c,$014d,$014f,$0150,$0152,$0153,$0155 ; d-3 + 48-55
    dw $0157,$0158,$015a,$015b,$015d,$015e,$0160,$0161 ; d-3 + 56-63
    dw $0163,$0164,$0166,$0167,$0169,$016a,$016c,$016d ; d#3 + 0-7
    dw $016f,$0170,$0172,$0174,$0175,$0177,$0178,$017a ; d#3 + 8-15
    dw $017b,$017d,$017e,$0180,$0181,$0183,$0184,$0186 ; d#3 + 16-23
    dw $0187,$0189,$018a,$018c,$018d,$018f,$0190,$0191 ; d#3 + 24-31
    dw $0193,$0194,$0196,$0197,$0199,$019a,$019c,$019d ; d#3 + 32-39
    dw $019f,$01a0,$01a2,$01a3,$01a5,$01a6,$01a8,$01a9 ; d#3 + 40-47
    dw $01ab,$01ac,$01ad,$01af,$01b0,$01b2,$01b3,$01b5 ; d#3 + 48-55
    dw $01b6,$01b8,$01b9,$01bb,$01bc,$01bd,$01bf,$01c0 ; d#3 + 56-63
    dw $01c2,$01c3,$01c5,$01c6,$01c8,$01c9,$01ca,$01cc ; e-3 + 0-7
    dw $01cd,$01cf,$01d0,$01d2,$01d3,$01d4,$01d6,$01d7 ; e-3 + 8-15
    dw $01d9,$01da,$01dc,$01dd,$01de,$01e0,$01e1,$01e3 ; e-3 + 16-23
    dw $01e4,$01e5,$01e7,$01e8,$01ea,$01eb,$01ed,$01ee ; e-3 + 24-31
    dw $01ef,$01f1,$01f2,$01f4,$01f5,$01f6,$01f8,$01f9 ; e-3 + 32-39
    dw $01fa,$01fc,$01fd,$01ff,$0200,$0201,$0203,$0204 ; e-3 + 40-47
    dw $0206,$0207,$0208,$020a,$020b,$020c,$020e,$020f ; e-3 + 48-55
    dw $0211,$0212,$0213,$0215,$0216,$0217,$0219,$021a ; e-3 + 56-63
    dw $021c,$021d,$021e,$0220,$0221,$0222,$0224,$0225 ; f-3 + 0-7
    dw $0226,$0228,$0229,$022a,$022c,$022d,$022e,$0230 ; f-3 + 8-15
    dw $0231,$0232,$0234,$0235,$0236,$0238,$0239,$023a ; f-3 + 16-23
    dw $023c,$023d,$023e,$0240,$0241,$0242,$0244,$0245 ; f-3 + 24-31
    dw $0246,$0248,$0249,$024a,$024c,$024d,$024e,$0250 ; f-3 + 32-39
    dw $0251,$0252,$0254,$0255,$0256,$0258,$0259,$025a ; f-3 + 40-47
    dw $025b,$025d,$025e,$025f,$0261,$0262,$0263,$0265 ; f-3 + 48-55
    dw $0266,$0267,$0268,$026a,$026b,$026c,$026e,$026f ; f-3 + 56-63
    dw $0270,$0271,$0273,$0274,$0275,$0277,$0278,$0279 ; f#3 + 0-7
    dw $027a,$027c,$027d,$027e,$0280,$0281,$0282,$0283 ; f#3 + 8-15
    dw $0285,$0286,$0287,$0288,$028a,$028b,$028c,$028d ; f#3 + 16-23
    dw $028f,$0290,$0291,$0292,$0294,$0295,$0296,$0297 ; f#3 + 24-31
    dw $0299,$029a,$029b,$029c,$029e,$029f,$02a0,$02a1 ; f#3 + 32-39
    dw $02a3,$02a4,$02a5,$02a6,$02a8,$02a9,$02aa,$02ab ; f#3 + 40-47
    dw $02ad,$02ae,$02af,$02b0,$02b1,$02b3,$02b4,$02b5 ; f#3 + 48-55
    dw $02b6,$02b8,$02b9,$02ba,$02bb,$02bc,$02be,$02bf ; f#3 + 56-63
    dw $02c0,$02c1,$02c3,$02c4,$02c5,$02c6,$02c7,$02c9 ; g-3 + 0-7
    dw $02ca,$02cb,$02cc,$02cd,$02cf,$02d0,$02d1,$02d2 ; g-3 + 8-15
    dw $02d3,$02d5,$02d6,$02d7,$02d8,$02d9,$02db,$02dc ; g-3 + 16-23
    dw $02dd,$02de,$02df,$02e0,$02e2,$02e3,$02e4,$02e5 ; g-3 + 24-31
    dw $02e6,$02e8,$02e9,$02ea,$02eb,$02ec,$02ed,$02ef ; g-3 + 32-39
    dw $02f0,$02f1,$02f2,$02f3,$02f4,$02f6,$02f7,$02f8 ; g-3 + 40-47
    dw $02f9,$02fa,$02fb,$02fd,$02fe,$02ff,$0300,$0301 ; g-3 + 48-55
    dw $0302,$0303,$0305,$0306,$0307,$0308,$0309,$030a ; g-3 + 56-63
    dw $030c,$030d,$030e,$030f,$0310,$0311,$0312,$0314 ; g#3 + 0-7
    dw $0315,$0316,$0317,$0318,$0319,$031a,$031b,$031d ; g#3 + 8-15
    dw $031e,$031f,$0320,$0321,$0322,$0323,$0324,$0326 ; g#3 + 16-23
    dw $0327,$0328,$0329,$032a,$032b,$032c,$032d,$032f ; g#3 + 24-31
    dw $0330,$0331,$0332,$0333,$0334,$0335,$0336,$0337 ; g#3 + 32-39
    dw $0338,$033a,$033b,$033c,$033d,$033e,$033f,$0340 ; g#3 + 40-47
    dw $0341,$0342,$0343,$0345,$0346,$0347,$0348,$0349 ; g#3 + 48-55
    dw $034a,$034b,$034c,$034d,$034e,$034f,$0351,$0352 ; g#3 + 56-63
    dw $0353,$0354,$0355,$0356,$0357,$0358,$0359,$035a ; a-3 + 0-7
    dw $035b,$035c,$035d,$035f,$0360,$0361,$0362,$0363 ; a-3 + 8-15
    dw $0364,$0365,$0366,$0367,$0368,$0369,$036a,$036b ; a-3 + 16-23
    dw $036c,$036d,$036e,$0370,$0371,$0372,$0373,$0374 ; a-3 + 24-31
    dw $0375,$0376,$0377,$0378,$0379,$037a,$037b,$037c ; a-3 + 32-39
    dw $037d,$037e,$037f,$0380,$0381,$0382,$0383,$0384 ; a-3 + 40-47
    dw $0385,$0387,$0388,$0389,$038a,$038b,$038c,$038d ; a-3 + 48-55
    dw $038e,$038f,$0390,$0391,$0392,$0393,$0394,$0395 ; a-3 + 56-63
    dw $0396,$0397,$0398,$0399,$039a,$039b,$039c,$039d ; a#3 + 0-7
    dw $039e,$039f,$03a0,$03a1,$03a2,$03a3,$03a4,$03a5 ; a#3 + 8-15
    dw $03a6,$03a7,$03a8,$03a9,$03aa,$03ab,$03ac,$03ad ; a#3 + 16-23
    dw $03ae,$03af,$03b0,$03b1,$03b2,$03b3,$03b4,$03b5 ; a#3 + 24-31
    dw $03b6,$03b7,$03b8,$03b9,$03ba,$03bb,$03bc,$03bd ; a#3 + 32-39
    dw $03be,$03bf,$03c0,$03c1,$03c2,$03c3,$03c4,$03c5 ; a#3 + 40-47
    dw $03c6,$03c7,$03c8,$03c9,$03ca,$03cb,$03cc,$03cd ; a#3 + 48-55
    dw $03ce,$03cf,$03d0,$03d1,$03d1,$03d2,$03d3,$03d4 ; a#3 + 56-63
    dw $03d5,$03d6,$03d7,$03d8,$03d9,$03da,$03db,$03dc ; b-3 + 0-7
    dw $03dd,$03de,$03df,$03e0,$03e1,$03e2,$03e3,$03e4 ; b-3 + 8-15
    dw $03e5,$03e6,$03e7,$03e7,$03e8,$03e9,$03ea,$03eb ; b-3 + 16-23
    dw $03ec,$03ed,$03ee,$03ef,$03f0,$03f1,$03f2,$03f3 ; b-3 + 24-31
    dw $03f4,$03f5,$03f6,$03f7,$03f7,$03f8,$03f9,$03fa ; b-3 + 32-39
    dw $03fb,$03fc,$03fd,$03fe,$03ff,$0400,$0401,$0402 ; b-3 + 40-47
    dw $0403,$0403,$0404,$0405,$0406,$0407,$0408,$0409 ; b-3 + 48-55
    dw $040a,$040b,$040c,$040d,$040e,$040e,$040f,$0410 ; b-3 + 56-63
    dw $0411,$0412,$0413,$0414,$0415,$0416,$0417,$0418 ; c-4 + 0-7
    dw $0418,$0419,$041a,$041b,$041c,$041d,$041e,$041f ; c-4 + 8-15
    dw $0420,$0421,$0421,$0422,$0423,$0424,$0425,$0426 ; c-4 + 16-23
    dw $0427,$0428,$0429,$0429,$042a,$042b,$042c,$042d ; c-4 + 24-31
    dw $042e,$042f,$0430,$0431,$0431,$0432,$0433,$0434 ; c-4 + 32-39
    dw $0435,$0436,$0437,$0438,$0438,$0439,$043a,$043b ; c-4 + 40-47
    dw $043c,$043d,$043e,$043e,$043f,$0440,$0441,$0442 ; c-4 + 48-55
    dw $0443,$0444,$0445,$0445,$0446,$0447,$0448,$0449 ; c-4 + 56-63
    dw $044a,$044b,$044b,$044c,$044d,$044e,$044f,$0450 ; c#4 + 0-7
    dw $0451,$0451,$0452,$0453,$0454,$0455,$0456,$0456 ; c#4 + 8-15
    dw $0457,$0458,$0459,$045a,$045b,$045c,$045c,$045d ; c#4 + 16-23
    dw $045e,$045f,$0460,$0461,$0461,$0462,$0463,$0464 ; c#4 + 24-31
    dw $0465,$0466,$0466,$0467,$0468,$0469,$046a,$046b ; c#4 + 32-39
    dw $046b,$046c,$046d,$046e,$046f,$0470,$0470,$0471 ; c#4 + 40-47
    dw $0472,$0473,$0474,$0474,$0475,$0476,$0477,$0478 ; c#4 + 48-55
    dw $0479,$0479,$047a,$047b,$047c,$047d,$047d,$047e ; c#4 + 56-63
    dw $047f,$0480,$0481,$0481,$0482,$0483,$0484,$0485 ; d-4 + 0-7
    dw $0485,$0486,$0487,$0488,$0489,$048a,$048a,$048b ; d-4 + 8-15
    dw $048c,$048d,$048d,$048e,$048f,$0490,$0491,$0491 ; d-4 + 16-23
    dw $0492,$0493,$0494,$0495,$0495,$0496,$0497,$0498 ; d-4 + 24-31
    dw $0499,$0499,$049a,$049b,$049c,$049d,$049d,$049e ; d-4 + 32-39
    dw $049f,$04a0,$04a0,$04a1,$04a2,$04a3,$04a4,$04a4 ; d-4 + 40-47
    dw $04a5,$04a6,$04a7,$04a7,$04a8,$04a9,$04aa,$04aa ; d-4 + 48-55
    dw $04ab,$04ac,$04ad,$04ae,$04ae,$04af,$04b0,$04b1 ; d-4 + 56-63
    dw $04b1,$04b2,$04b3,$04b4,$04b4,$04b5,$04b6,$04b7 ; d#4 + 0-7
    dw $04b7,$04b8,$04b9,$04ba,$04bb,$04bb,$04bc,$04bd ; d#4 + 8-15
    dw $04be,$04be,$04bf,$04c0,$04c1,$04c1,$04c2,$04c3 ; d#4 + 16-23
    dw $04c4,$04c4,$04c5,$04c6,$04c7,$04c7,$04c8,$04c9 ; d#4 + 24-31
    dw $04c9,$04ca,$04cb,$04cc,$04cc,$04cd,$04ce,$04cf ; d#4 + 32-39
    dw $04cf,$04d0,$04d1,$04d2,$04d2,$04d3,$04d4,$04d5 ; d#4 + 40-47
    dw $04d5,$04d6,$04d7,$04d7,$04d8,$04d9,$04da,$04da ; d#4 + 48-55
    dw $04db,$04dc,$04dd,$04dd,$04de,$04df,$04df,$04e0 ; d#4 + 56-63
    dw $04e1,$04e2,$04e2,$04e3,$04e4,$04e5,$04e5,$04e6 ; e-4 + 0-7
    dw $04e7,$04e7,$04e8,$04e9,$04ea,$04ea,$04eb,$04ec ; e-4 + 8-15
    dw $04ec,$04ed,$04ee,$04ee,$04ef,$04f0,$04f1,$04f1 ; e-4 + 16-23
    dw $04f2,$04f3,$04f3,$04f4,$04f5,$04f6,$04f6,$04f7 ; e-4 + 24-31
    dw $04f8,$04f8,$04f9,$04fa,$04fa,$04fb,$04fc,$04fd ; e-4 + 32-39
    dw $04fd,$04fe,$04ff,$04ff,$0500,$0501,$0501,$0502 ; e-4 + 40-47
    dw $0503,$0503,$0504,$0505,$0506,$0506,$0507,$0508 ; e-4 + 48-55
    dw $0508,$0509,$050a,$050a,$050b,$050c,$050c,$050d ; e-4 + 56-63
    dw $050e,$050e,$050f,$0510,$0510,$0511,$0512,$0513 ; f-4 + 0-7
    dw $0513,$0514,$0515,$0515,$0516,$0517,$0517,$0518 ; f-4 + 8-15
    dw $0519,$0519,$051a,$051b,$051b,$051c,$051d,$051d ; f-4 + 16-23
    dw $051e,$051f,$051f,$0520,$0521,$0521,$0522,$0523 ; f-4 + 24-31
    dw $0523,$0524,$0525,$0525,$0526,$0527,$0527,$0528 ; f-4 + 32-39
    dw $0528,$0529,$052a,$052a,$052b,$052c,$052c,$052d ; f-4 + 40-47
    dw $052e,$052e,$052f,$0530,$0530,$0531,$0532,$0532 ; f-4 + 48-55
    dw $0533,$0534,$0534,$0535,$0536,$0536,$0537,$0537 ; f-4 + 56-63
    dw $0538,$0539,$0539,$053a,$053b,$053b,$053c,$053d ; f#4 + 0-7
    dw $053d,$053e,$053e,$053f,$0540,$0540,$0541,$0542 ; f#4 + 8-15
    dw $0542,$0543,$0544,$0544,$0545,$0545,$0546,$0547 ; f#4 + 16-23
    dw $0547,$0548,$0549,$0549,$054a,$054a,$054b,$054c ; f#4 + 24-31
    dw $054c,$054d,$054e,$054e,$054f,$054f,$0550,$0551 ; f#4 + 32-39
    dw $0551,$0552,$0553,$0553,$0554,$0554,$0555,$0556 ; f#4 + 40-47
    dw $0556,$0557,$0557,$0558,$0559,$0559,$055a,$055b ; f#4 + 48-55
    dw $055b,$055c,$055c,$055d,$055e,$055e,$055f,$055f ; f#4 + 56-63
    dw $0560,$0561,$0561,$0562,$0562,$0563,$0564,$0564 ; g-4 + 0-7
    dw $0565,$0565,$0566,$0567,$0567,$0568,$0568,$0569 ; g-4 + 8-15
    dw $056a,$056a,$056b,$056b,$056c,$056d,$056d,$056e ; g-4 + 16-23
    dw $056e,$056f,$0570,$0570,$0571,$0571,$0572,$0573 ; g-4 + 24-31
    dw $0573,$0574,$0574,$0575,$0576,$0576,$0577,$0577 ; g-4 + 32-39
    dw $0578,$0578,$0579,$057a,$057a,$057b,$057b,$057c ; g-4 + 40-47
    dw $057d,$057d,$057e,$057e,$057f,$057f,$0580,$0581 ; g-4 + 48-55
    dw $0581,$0582,$0582,$0583,$0583,$0584,$0585,$0585 ; g-4 + 56-63
    dw $0586,$0586,$0587,$0587,$0588,$0589,$0589,$058a ; g#4 + 0-7
    dw $058a,$058b,$058b,$058c,$058d,$058d,$058e,$058e ; g#4 + 8-15
    dw $058f,$058f,$0590,$0591,$0591,$0592,$0592,$0593 ; g#4 + 16-23
    dw $0593,$0594,$0594,$0595,$0596,$0596,$0597,$0597 ; g#4 + 24-31
    dw $0598,$0598,$0599,$0599,$059a,$059b,$059b,$059c ; g#4 + 32-39
    dw $059c,$059d,$059d,$059e,$059e,$059f,$05a0,$05a0 ; g#4 + 40-47
    dw $05a1,$05a1,$05a2,$05a2,$05a3,$05a3,$05a4,$05a4 ; g#4 + 48-55
    dw $05a5,$05a6,$05a6,$05a7,$05a7,$05a8,$05a8,$05a9 ; g#4 + 56-63
    dw $05a9,$05aa,$05aa,$05ab,$05ac,$05ac,$05ad,$05ad ; a-4 + 0-7
    dw $05ae,$05ae,$05af,$05af,$05b0,$05b0,$05b1,$05b1 ; a-4 + 8-15
    dw $05b2,$05b2,$05b3,$05b4,$05b4,$05b5,$05b5,$05b6 ; a-4 + 16-23
    dw $05b6,$05b7,$05b7,$05b8,$05b8,$05b9,$05b9,$05ba ; a-4 + 24-31
    dw $05ba,$05bb,$05bb,$05bc,$05bc,$05bd,$05be,$05be ; a-4 + 32-39
    dw $05bf,$05bf,$05c0,$05c0,$05c1,$05c1,$05c2,$05c2 ; a-4 + 40-47
    dw $05c3,$05c3,$05c4,$05c4,$05c5,$05c5,$05c6,$05c6 ; a-4 + 48-55
    dw $05c7,$05c7,$05c8,$05c8,$05c9,$05c9,$05ca,$05ca ; a-4 + 56-63
    dw $05cb,$05cb,$05cc,$05cc,$05cd,$05cd,$05ce,$05cf ; a#4 + 0-7
    dw $05cf,$05d0,$05d0,$05d1,$05d1,$05d2,$05d2,$05d3 ; a#4 + 8-15
    dw $05d3,$05d4,$05d4,$05d5,$05d5,$05d6,$05d6,$05d7 ; a#4 + 16-23
    dw $05d7,$05d8,$05d8,$05d9,$05d9,$05da,$05da,$05db ; a#4 + 24-31
    dw $05db,$05dc,$05dc,$05dd,$05dd,$05de,$05de,$05de ; a#4 + 32-39
    dw $05df,$05df,$05e0,$05e0,$05e1,$05e1,$05e2,$05e2 ; a#4 + 40-47
    dw $05e3,$05e3,$05e4,$05e4,$05e5,$05e5,$05e6,$05e6 ; a#4 + 48-55
    dw $05e7,$05e7,$05e8,$05e8,$05e9,$05e9,$05ea,$05ea ; a#4 + 56-63
    dw $05eb,$05eb,$05ec,$05ec,$05ed,$05ed,$05ee,$05ee ; b-4 + 0-7
    dw $05ef,$05ef,$05ef,$05f0,$05f0,$05f1,$05f1,$05f2 ; b-4 + 8-15
    dw $05f2,$05f3,$05f3,$05f4,$05f4,$05f5,$05f5,$05f6 ; b-4 + 16-23
    dw $05f6,$05f7,$05f7,$05f8,$05f8,$05f8,$05f9,$05f9 ; b-4 + 24-31
    dw $05fa,$05fa,$05fb,$05fb,$05fc,$05fc,$05fd,$05fd ; b-4 + 32-39
    dw $05fe,$05fe,$05ff,$05ff,$05ff,$0600,$0600,$0601 ; b-4 + 40-47
    dw $0601,$0602,$0602,$0603,$0603,$0604,$0604,$0604 ; b-4 + 48-55
    dw $0605,$0605,$0606,$0606,$0607,$0607,$0608,$0608 ; b-4 + 56-63
    dw $0609,$0609,$060a,$060a,$060a,$060b,$060b,$060c ; c-5 + 0-7
    dw $060c,$060d,$060d,$060e,$060e,$060e,$060f,$060f ; c-5 + 8-15
    dw $0610,$0610,$0611,$0611,$0612,$0612,$0612,$0613 ; c-5 + 16-23
    dw $0613,$0614,$0614,$0615,$0615,$0616,$0616,$0616 ; c-5 + 24-31
    dw $0617,$0617,$0618,$0618,$0619,$0619,$061a,$061a ; c-5 + 32-39
    dw $061a,$061b,$061b,$061c,$061c,$061d,$061d,$061e ; c-5 + 40-47
    dw $061e,$061e,$061f,$061f,$0620,$0620,$0621,$0621 ; c-5 + 48-55
    dw $0621,$0622,$0622,$0623,$0623,$0624,$0624,$0624 ; c-5 + 56-63
    dw $0625,$0625,$0626,$0626,$0627,$0627,$0627,$0628 ; c#5 + 0-7
    dw $0628,$0629,$0629,$062a,$062a,$062a,$062b,$062b ; c#5 + 8-15
    dw $062c,$062c,$062d,$062d,$062d,$062e,$062e,$062f ; c#5 + 16-23
    dw $062f,$062f,$0630,$0630,$0631,$0631,$0632,$0632 ; c#5 + 24-31
    dw $0632,$0633,$0633,$0634,$0634,$0634,$0635,$0635 ; c#5 + 32-39
    dw $0636,$0636,$0637,$0637,$0637,$0638,$0638,$0639 ; c#5 + 40-47
    dw $0639,$0639,$063a,$063a,$063b,$063b,$063b,$063c ; c#5 + 48-55
    dw $063c,$063d,$063d,$063d,$063e,$063e,$063f,$063f ; c#5 + 56-63
    dw $0640,$0640,$0640,$0641,$0641,$0642,$0642,$0642 ; d-5 + 0-7
    dw $0643,$0643,$0644,$0644,$0644,$0645,$0645,$0646 ; d-5 + 8-15
    dw $0646,$0646,$0647,$0647,$0648,$0648,$0648,$0649 ; d-5 + 16-23
    dw $0649,$064a,$064a,$064a,$064b,$064b,$064c,$064c ; d-5 + 24-31
    dw $064c,$064d,$064d,$064d,$064e,$064e,$064f,$064f ; d-5 + 32-39
    dw $064f,$0650,$0650,$0651,$0651,$0651,$0652,$0652 ; d-5 + 40-47
    dw $0653,$0653,$0653,$0654,$0654,$0654,$0655,$0655 ; d-5 + 48-55
    dw $0656,$0656,$0656,$0657,$0657,$0658,$0658,$0658 ; d-5 + 56-63
    dw $0659,$0659,$0659,$065a,$065a,$065b,$065b,$065b ; d#5 + 0-7
    dw $065c,$065c,$065c,$065d,$065d,$065e,$065e,$065e ; d#5 + 8-15
    dw $065f,$065f,$0660,$0660,$0660,$0661,$0661,$0661 ; d#5 + 16-23
    dw $0662,$0662,$0663,$0663,$0663,$0664,$0664,$0664 ; d#5 + 24-31
    dw $0665,$0665,$0665,$0666,$0666,$0667,$0667,$0667 ; d#5 + 32-39
    dw $0668,$0668,$0668,$0669,$0669,$066a,$066a,$066a ; d#5 + 40-47
    dw $066b,$066b,$066b,$066c,$066c,$066c,$066d,$066d ; d#5 + 48-55
    dw $066e,$066e,$066e,$066f,$066f,$066f,$0670,$0670 ; d#5 + 56-63
    dw $0670,$0671,$0671,$0672,$0672,$0672,$0673,$0673 ; e-5 + 0-7
    dw $0673,$0674,$0674,$0674,$0675,$0675,$0675,$0676 ; e-5 + 8-15
    dw $0676,$0677,$0677,$0677,$0678,$0678,$0678,$0679 ; e-5 + 16-23
    dw $0679,$0679,$067a,$067a,$067a,$067b,$067b,$067b ; e-5 + 24-31
    dw $067c,$067c,$067d,$067d,$067d,$067e,$067e,$067e ; e-5 + 32-39
    dw $067f,$067f,$067f,$0680,$0680,$0680,$0681,$0681 ; e-5 + 40-47
    dw $0681,$0682,$0682,$0682,$0683,$0683,$0683,$0684 ; e-5 + 48-55
    dw $0684,$0684,$0685,$0685,$0686,$0686,$0686,$0687 ; e-5 + 56-63
    dw $0687,$0687,$0688,$0688,$0688,$0689,$0689,$0689 ; f-5 + 0-7
    dw $068a,$068a,$068a,$068b,$068b,$068b,$068c,$068c ; f-5 + 8-15
    dw $068c,$068d,$068d,$068d,$068e,$068e,$068e,$068f ; f-5 + 16-23
    dw $068f,$068f,$0690,$0690,$0690,$0691,$0691,$0691 ; f-5 + 24-31
    dw $0692,$0692,$0692,$0693,$0693,$0693,$0694,$0694 ; f-5 + 32-39
    dw $0694,$0695,$0695,$0695,$0696,$0696,$0696,$0697 ; f-5 + 40-47
    dw $0697,$0697,$0698,$0698,$0698,$0698,$0699,$0699 ; f-5 + 48-55
    dw $0699,$069a,$069a,$069a,$069b,$069b,$069b,$069c ; f-5 + 56-63
    dw $069c,$069c,$069d,$069d,$069d,$069e,$069e,$069e ; f#5 + 0-7
    dw $069f,$069f,$069f,$06a0,$06a0,$06a0,$06a1,$06a1 ; f#5 + 8-15
    dw $06a1,$06a1,$06a2,$06a2,$06a2,$06a3,$06a3,$06a3 ; f#5 + 16-23
    dw $06a4,$06a4,$06a4,$06a5,$06a5,$06a5,$06a6,$06a6 ; f#5 + 24-31
    dw $06a6,$06a6,$06a7,$06a7,$06a7,$06a8,$06a8,$06a8 ; f#5 + 32-39
    dw $06a9,$06a9,$06a9,$06aa,$06aa,$06aa,$06ab,$06ab ; f#5 + 40-47
    dw $06ab,$06ab,$06ac,$06ac,$06ac,$06ad,$06ad,$06ad ; f#5 + 48-55
    dw $06ae,$06ae,$06ae,$06af,$06af,$06af,$06af,$06b0 ; f#5 + 56-63
    dw $06b0,$06b0,$06b1,$06b1,$06b1,$06b2,$06b2,$06b2 ; g-5 + 0-7
    dw $06b2,$06b3,$06b3,$06b3,$06b4,$06b4,$06b4,$06b5 ; g-5 + 8-15
    dw $06b5,$06b5,$06b5,$06b6,$06b6,$06b6,$06b7,$06b7 ; g-5 + 16-23
    dw $06b7,$06b8,$06b8,$06b8,$06b8,$06b9,$06b9,$06b9 ; g-5 + 24-31
    dw $06ba,$06ba,$06ba,$06ba,$06bb,$06bb,$06bb,$06bc ; g-5 + 32-39
    dw $06bc,$06bc,$06bd,$06bd,$06bd,$06bd,$06be,$06be ; g-5 + 40-47
    dw $06be,$06bf,$06bf,$06bf,$06bf,$06c0,$06c0,$06c0 ; g-5 + 48-55
    dw $06c1,$06c1,$06c1,$06c1,$06c2,$06c2,$06c2,$06c3 ; g-5 + 56-63
    dw $06c3,$06c3,$06c3,$06c4,$06c4,$06c4,$06c5,$06c5 ; g#5 + 0-7
    dw $06c5,$06c5,$06c6,$06c6,$06c6,$06c7,$06c7,$06c7 ; g#5 + 8-15
    dw $06c7,$06c8,$06c8,$06c8,$06c9,$06c9,$06c9,$06c9 ; g#5 + 16-23
    dw $06ca,$06ca,$06ca,$06cb,$06cb,$06cb,$06cb,$06cc ; g#5 + 24-31
    dw $06cc,$06cc,$06cc,$06cd,$06cd,$06cd,$06ce,$06ce ; g#5 + 32-39
    dw $06ce,$06ce,$06cf,$06cf,$06cf,$06d0,$06d0,$06d0 ; g#5 + 40-47
    dw $06d0,$06d1,$06d1,$06d1,$06d1,$06d2,$06d2,$06d2 ; g#5 + 48-55
    dw $06d3,$06d3,$06d3,$06d3,$06d4,$06d4,$06d4,$06d4 ; g#5 + 56-63
    dw $06d5,$06d5,$06d5,$06d5,$06d6,$06d6,$06d6,$06d7 ; a-5 + 0-7
    dw $06d7,$06d7,$06d7,$06d8,$06d8,$06d8,$06d8,$06d9 ; a-5 + 8-15
    dw $06d9,$06d9,$06da,$06da,$06da,$06da,$06db,$06db ; a-5 + 16-23
    dw $06db,$06db,$06dc,$06dc,$06dc,$06dc,$06dd,$06dd ; a-5 + 24-31
    dw $06dd,$06dd,$06de,$06de,$06de,$06df,$06df,$06df ; a-5 + 32-39
    dw $06df,$06e0,$06e0,$06e0,$06e0,$06e1,$06e1,$06e1 ; a-5 + 40-47
    dw $06e1,$06e2,$06e2,$06e2,$06e2,$06e3,$06e3,$06e3 ; a-5 + 48-55
    dw $06e3,$06e4,$06e4,$06e4,$06e4,$06e5,$06e5,$06e5 ; a-5 + 56-63
    dw $06e5,$06e6,$06e6,$06e6,$06e6,$06e7,$06e7,$06e7 ; a#5 + 0-7
    dw $06e8,$06e8,$06e8,$06e8,$06e9,$06e9,$06e9,$06e9 ; a#5 + 8-15
    dw $06ea,$06ea,$06ea,$06ea,$06eb,$06eb,$06eb,$06eb ; a#5 + 16-23
    dw $06ec,$06ec,$06ec,$06ec,$06ed,$06ed,$06ed,$06ed ; a#5 + 24-31
    dw $06ee,$06ee,$06ee,$06ee,$06ef,$06ef,$06ef,$06ef ; a#5 + 32-39
    dw $06ef,$06f0,$06f0,$06f0,$06f0,$06f1,$06f1,$06f1 ; a#5 + 40-47
    dw $06f1,$06f2,$06f2,$06f2,$06f2,$06f3,$06f3,$06f3 ; a#5 + 48-55
    dw $06f3,$06f4,$06f4,$06f4,$06f4,$06f5,$06f5,$06f5 ; a#5 + 56-63
    dw $06f5,$06f6,$06f6,$06f6,$06f6,$06f7,$06f7,$06f7 ; b-5 + 0-7
    dw $06f7,$06f7,$06f8,$06f8,$06f8,$06f8,$06f9,$06f9 ; b-5 + 8-15
    dw $06f9,$06f9,$06fa,$06fa,$06fa,$06fa,$06fb,$06fb ; b-5 + 16-23
    dw $06fb,$06fb,$06fc,$06fc,$06fc,$06fc,$06fc,$06fd ; b-5 + 24-31
    dw $06fd,$06fd,$06fd,$06fe,$06fe,$06fe,$06fe,$06ff ; b-5 + 32-39
    dw $06ff,$06ff,$06ff,$06ff,$0700,$0700,$0700,$0700 ; b-5 + 40-47
    dw $0701,$0701,$0701,$0701,$0702,$0702,$0702,$0702 ; b-5 + 48-55
    dw $0702,$0703,$0703,$0703,$0703,$0704,$0704,$0704 ; b-5 + 56-63
    dw $0704,$0705,$0705,$0705,$0705,$0705,$0706,$0706 ; c-6 + 0-7
    dw $0706,$0706,$0707,$0707,$0707,$0707,$0707,$0708 ; c-6 + 8-15
    dw $0708,$0708,$0708,$0709,$0709,$0709,$0709,$0709 ; c-6 + 16-23
    dw $070a,$070a,$070a,$070a,$070b,$070b,$070b,$070b ; c-6 + 24-31
    dw $070b,$070c,$070c,$070c,$070c,$070d,$070d,$070d ; c-6 + 32-39
    dw $070d,$070d,$070e,$070e,$070e,$070e,$070f,$070f ; c-6 + 40-47
    dw $070f,$070f,$070f,$0710,$0710,$0710,$0710,$0710 ; c-6 + 48-55
    dw $0711,$0711,$0711,$0711,$0712,$0712,$0712,$0712 ; c-6 + 56-63
    dw $0712,$0713,$0713,$0713,$0713,$0713,$0714,$0714 ; c#6 + 0-7
    dw $0714,$0714,$0715,$0715,$0715,$0715,$0715,$0716 ; c#6 + 8-15
    dw $0716,$0716,$0716,$0716,$0717,$0717,$0717,$0717 ; c#6 + 16-23
    dw $0718,$0718,$0718,$0718,$0718,$0719,$0719,$0719 ; c#6 + 24-31
    dw $0719,$0719,$071a,$071a,$071a,$071a,$071a,$071b ; c#6 + 32-39
    dw $071b,$071b,$071b,$071b,$071c,$071c,$071c,$071c ; c#6 + 40-47
    dw $071c,$071d,$071d,$071d,$071d,$071e,$071e,$071e ; c#6 + 48-55
    dw $071e,$071e,$071f,$071f,$071f,$071f,$071f,$0720 ; c#6 + 56-63
    dw $0720,$0720,$0720,$0720,$0721,$0721,$0721,$0721 ; d-6 + 0-7
    dw $0721,$0722,$0722,$0722,$0722,$0722,$0723,$0723 ; d-6 + 8-15
    dw $0723,$0723,$0723,$0724,$0724,$0724,$0724,$0724 ; d-6 + 16-23
    dw $0725,$0725,$0725,$0725,$0725,$0726,$0726,$0726 ; d-6 + 24-31
    dw $0726,$0726,$0727,$0727,$0727,$0727,$0727,$0728 ; d-6 + 32-39
    dw $0728,$0728,$0728,$0728,$0728,$0729,$0729,$0729 ; d-6 + 40-47
    dw $0729,$0729,$072a,$072a,$072a,$072a,$072a,$072b ; d-6 + 48-55
    dw $072b,$072b,$072b,$072b,$072c,$072c,$072c,$072c ; d-6 + 56-63
    dw $072c,$072d,$072d,$072d,$072d,$072d,$072d,$072e ; d#6 + 0-7
    dw $072e,$072e,$072e,$072e,$072f,$072f,$072f,$072f ; d#6 + 8-15
    dw $072f,$0730,$0730,$0730,$0730,$0730,$0731,$0731 ; d#6 + 16-23
    dw $0731,$0731,$0731,$0731,$0732,$0732,$0732,$0732 ; d#6 + 24-31
    dw $0732,$0733,$0733,$0733,$0733,$0733,$0733,$0734 ; d#6 + 32-39
    dw $0734,$0734,$0734,$0734,$0735,$0735,$0735,$0735 ; d#6 + 40-47
    dw $0735,$0736,$0736,$0736,$0736,$0736,$0736,$0737 ; d#6 + 48-55
    dw $0737,$0737,$0737,$0737,$0738,$0738,$0738,$0738 ; d#6 + 56-63
    dw $0738,$0738,$0739,$0739,$0739,$0739,$0739,$0739 ; e-6 + 0-7
    dw $073a,$073a,$073a,$073a,$073a,$073b,$073b,$073b ; e-6 + 8-15
    dw $073b,$073b,$073b,$073c,$073c,$073c,$073c,$073c ; e-6 + 16-23
    dw $073d,$073d,$073d,$073d,$073d,$073d,$073e,$073e ; e-6 + 24-31
    dw $073e,$073e,$073e,$073e,$073f,$073f,$073f,$073f ; e-6 + 32-39
    dw $073f,$073f,$0740,$0740,$0740,$0740,$0740,$0741 ; e-6 + 40-47
    dw $0741,$0741,$0741,$0741,$0741,$0742,$0742,$0742 ; e-6 + 48-55
    dw $0742,$0742,$0742,$0743,$0743,$0743,$0743,$0743 ; e-6 + 56-63
    dw $0743,$0744,$0744,$0744,$0744,$0744,$0744,$0745 ; f-6 + 0-7
    dw $0745,$0745,$0745,$0745,$0745,$0746,$0746,$0746 ; f-6 + 8-15
    dw $0746,$0746,$0746,$0747,$0747,$0747,$0747,$0747 ; f-6 + 16-23
    dw $0747,$0748,$0748,$0748,$0748,$0748,$0748,$0749 ; f-6 + 24-31
    dw $0749,$0749,$0749,$0749,$0749,$074a,$074a,$074a ; f-6 + 32-39
    dw $074a,$074a,$074a,$074b,$074b,$074b,$074b,$074b ; f-6 + 40-47
    dw $074b,$074c,$074c,$074c,$074c,$074c,$074c,$074d ; f-6 + 48-55
    dw $074d,$074d,$074d,$074d,$074d,$074e,$074e,$074e ; f-6 + 56-63
    dw $074e,$074e,$074e,$074f,$074f,$074f,$074f,$074f ; f#6 + 0-7
    dw $074f,$074f,$0750,$0750,$0750,$0750,$0750,$0750 ; f#6 + 8-15
    dw $0751,$0751,$0751,$0751,$0751,$0751,$0752,$0752 ; f#6 + 16-23
    dw $0752,$0752,$0752,$0752,$0752,$0753,$0753,$0753 ; f#6 + 24-31
    dw $0753,$0753,$0753,$0754,$0754,$0754,$0754,$0754 ; f#6 + 32-39
    dw $0754,$0754,$0755,$0755,$0755,$0755,$0755,$0755 ; f#6 + 40-47
    dw $0756,$0756,$0756,$0756,$0756,$0756,$0756,$0757 ; f#6 + 48-55
    dw $0757,$0757,$0757,$0757,$0757,$0758,$0758,$0758 ; f#6 + 56-63
    dw $0758,$0758,$0758,$0758,$0759,$0759,$0759,$0759 ; g-6 + 0-7
    dw $0759,$0759,$075a,$075a,$075a,$075a,$075a,$075a ; g-6 + 8-15
    dw $075a,$075b,$075b,$075b,$075b,$075b,$075b,$075b ; g-6 + 16-23
    dw $075c,$075c,$075c,$075c,$075c,$075c,$075c,$075d ; g-6 + 24-31
    dw $075d,$075d,$075d,$075d,$075d,$075e,$075e,$075e ; g-6 + 32-39
    dw $075e,$075e,$075e,$075e,$075f,$075f,$075f,$075f ; g-6 + 40-47
    dw $075f,$075f,$075f,$0760,$0760,$0760,$0760,$0760 ; g-6 + 48-55
    dw $0760,$0760,$0761,$0761,$0761,$0761,$0761,$0761 ; g-6 + 56-63
    dw $0761,$0762,$0762,$0762,$0762,$0762,$0762,$0762 ; g#6 + 0-7
    dw $0763,$0763,$0763,$0763,$0763,$0763,$0763,$0764 ; g#6 + 8-15
    dw $0764,$0764,$0764,$0764,$0764,$0764,$0765,$0765 ; g#6 + 16-23
    dw $0765,$0765,$0765,$0765,$0765,$0766,$0766,$0766 ; g#6 + 24-31
    dw $0766,$0766,$0766,$0766,$0767,$0767,$0767,$0767 ; g#6 + 32-39
    dw $0767,$0767,$0767,$0767,$0768,$0768,$0768,$0768 ; g#6 + 40-47
    dw $0768,$0768,$0768,$0769,$0769,$0769,$0769,$0769 ; g#6 + 48-55
    dw $0769,$0769,$076a,$076a,$076a,$076a,$076a,$076a ; g#6 + 56-63
    dw $076a,$076a,$076b,$076b,$076b,$076b,$076b,$076b ; a-6 + 0-7
    dw $076b,$076c,$076c,$076c,$076c,$076c,$076c,$076c ; a-6 + 8-15
    dw $076c,$076d,$076d,$076d,$076d,$076d,$076d,$076d ; a-6 + 16-23
    dw $076e,$076e,$076e,$076e,$076e,$076e,$076e,$076e ; a-6 + 24-31
    dw $076f,$076f,$076f,$076f,$076f,$076f,$076f,$0770 ; a-6 + 32-39
    dw $0770,$0770,$0770,$0770,$0770,$0770,$0770,$0771 ; a-6 + 40-47
    dw $0771,$0771,$0771,$0771,$0771,$0771,$0771,$0772 ; a-6 + 48-55
    dw $0772,$0772,$0772,$0772,$0772,$0772,$0772,$0773 ; a-6 + 56-63
    dw $0773,$0773,$0773,$0773,$0773,$0773,$0774,$0774 ; a#6 + 0-7
    dw $0774,$0774,$0774,$0774,$0774,$0774,$0775,$0775 ; a#6 + 8-15
    dw $0775,$0775,$0775,$0775,$0775,$0775,$0776,$0776 ; a#6 + 16-23
    dw $0776,$0776,$0776,$0776,$0776,$0776,$0777,$0777 ; a#6 + 24-31
    dw $0777,$0777,$0777,$0777,$0777,$0777,$0778,$0778 ; a#6 + 32-39
    dw $0778,$0778,$0778,$0778,$0778,$0778,$0778,$0779 ; a#6 + 40-47
    dw $0779,$0779,$0779,$0779,$0779,$0779,$0779,$077a ; a#6 + 48-55
    dw $077a,$077a,$077a,$077a,$077a,$077a,$077a,$077b ; a#6 + 56-63
    dw $077b,$077b,$077b,$077b,$077b,$077b,$077b,$077c ; b-6 + 0-7
    dw $077c,$077c,$077c,$077c,$077c,$077c,$077c,$077c ; b-6 + 8-15
    dw $077d,$077d,$077d,$077d,$077d,$077d,$077d,$077d ; b-6 + 16-23
    dw $077e,$077e,$077e,$077e,$077e,$077e,$077e,$077e ; b-6 + 24-31
    dw $077e,$077f,$077f,$077f,$077f,$077f,$077f,$077f ; b-6 + 32-39
    dw $077f,$0780,$0780,$0780,$0780,$0780,$0780,$0780 ; b-6 + 40-47
    dw $0780,$0780,$0781,$0781,$0781,$0781,$0781,$0781 ; b-6 + 48-55
    dw $0781,$0781,$0781,$0782,$0782,$0782,$0782,$0782 ; b-6 + 56-63
    dw $0782,$0782,$0782,$0782,$0783,$0783,$0783,$0783 ; c-7 + 0-7
    dw $0783,$0783,$0783,$0783,$0784,$0784,$0784,$0784 ; c-7 + 8-15
    dw $0784,$0784,$0784,$0784,$0784,$0785,$0785,$0785 ; c-7 + 16-23
    dw $0785,$0785,$0785,$0785,$0785,$0785,$0786,$0786 ; c-7 + 24-31
    dw $0786,$0786,$0786,$0786,$0786,$0786,$0786,$0787 ; c-7 + 32-39
    dw $0787,$0787,$0787,$0787,$0787,$0787,$0787,$0787 ; c-7 + 40-47
    dw $0787,$0788,$0788,$0788,$0788,$0788,$0788,$0788 ; c-7 + 48-55
    dw $0788,$0788,$0789,$0789,$0789,$0789,$0789,$0789 ; c-7 + 56-63
    dw $0789,$0789,$0789,$078a,$078a,$078a,$078a,$078a ; c#7 + 0-7
    dw $078a,$078a,$078a,$078a,$078a,$078b,$078b,$078b ; c#7 + 8-15
    dw $078b,$078b,$078b,$078b,$078b,$078b,$078c,$078c ; c#7 + 16-23
    dw $078c,$078c,$078c,$078c,$078c,$078c,$078c,$078c ; c#7 + 24-31
    dw $078d,$078d,$078d,$078d,$078d,$078d,$078d,$078d ; c#7 + 32-39
    dw $078d,$078e,$078e,$078e,$078e,$078e,$078e,$078e ; c#7 + 40-47
    dw $078e,$078e,$078e,$078f,$078f,$078f,$078f,$078f ; c#7 + 48-55
    dw $078f,$078f,$078f,$078f,$078f,$0790,$0790,$0790 ; c#7 + 56-63
    dw $0790,$0790,$0790,$0790,$0790,$0790,$0790,$0791 ; d-7 + 0-7
    dw $0791,$0791,$0791,$0791,$0791,$0791,$0791,$0791 ; d-7 + 8-15
    dw $0791,$0792,$0792,$0792,$0792,$0792,$0792,$0792 ; d-7 + 16-23
    dw $0792,$0792,$0792,$0793,$0793,$0793,$0793,$0793 ; d-7 + 24-31
    dw $0793,$0793,$0793,$0793,$0793,$0794,$0794,$0794 ; d-7 + 32-39
    dw $0794,$0794,$0794,$0794,$0794,$0794,$0794,$0795 ; d-7 + 40-47
    dw $0795,$0795,$0795,$0795,$0795,$0795,$0795,$0795 ; d-7 + 48-55
    dw $0795,$0796,$0796,$0796,$0796,$0796,$0796,$0796 ; d-7 + 56-63
    dw $0796,$0796,$0796,$0796,$0797,$0797,$0797,$0797 ; d#7 + 0-7
    dw $0797,$0797,$0797,$0797,$0797,$0797,$0798,$0798 ; d#7 + 8-15
    dw $0798,$0798,$0798,$0798,$0798,$0798,$0798,$0798 ; d#7 + 16-23
    dw $0798,$0799,$0799,$0799,$0799,$0799,$0799,$0799 ; d#7 + 24-31
    dw $0799,$0799,$0799,$0799,$079a,$079a,$079a,$079a ; d#7 + 32-39
    dw $079a,$079a,$079a,$079a,$079a,$079a,$079a,$079b ; d#7 + 40-47
    dw $079b,$079b,$079b,$079b,$079b,$079b,$079b,$079b ; d#7 + 48-55
    dw $079b,$079b,$079c,$079c,$079c,$079c,$079c,$079c ; d#7 + 56-63
    dw $079c,$079c,$079c,$079c,$079c,$079d,$079d,$079d ; e-7 + 0-7
    dw $079d,$079d,$079d,$079d,$079d,$079d,$079d,$079d ; e-7 + 8-15
    dw $079e,$079e,$079e,$079e,$079e,$079e,$079e,$079e ; e-7 + 16-23
    dw $079e,$079e,$079e,$079f,$079f,$079f,$079f,$079f ; e-7 + 24-31
    dw $079f,$079f,$079f,$079f,$079f,$079f,$079f,$07a0 ; e-7 + 32-39
    dw $07a0,$07a0,$07a0,$07a0,$07a0,$07a0,$07a0,$07a0 ; e-7 + 40-47
    dw $07a0,$07a0,$07a1,$07a1,$07a1,$07a1,$07a1,$07a1 ; e-7 + 48-55
    dw $07a1,$07a1,$07a1,$07a1,$07a1,$07a1,$07a2,$07a2 ; e-7 + 56-63
    dw $07a2,$07a2,$07a2,$07a2,$07a2,$07a2,$07a2,$07a2 ; f-7 + 0-7
    dw $07a2,$07a2,$07a3,$07a3,$07a3,$07a3,$07a3,$07a3 ; f-7 + 8-15
    dw $07a3,$07a3,$07a3,$07a3,$07a3,$07a3,$07a4,$07a4 ; f-7 + 16-23
    dw $07a4,$07a4,$07a4,$07a4,$07a4,$07a4,$07a4,$07a4 ; f-7 + 24-31
    dw $07a4,$07a4,$07a5,$07a5,$07a5,$07a5,$07a5,$07a5 ; f-7 + 32-39
    dw $07a5,$07a5,$07a5,$07a5,$07a5,$07a5,$07a6,$07a6 ; f-7 + 40-47
    dw $07a6,$07a6,$07a6,$07a6,$07a6,$07a6,$07a6,$07a6 ; f-7 + 48-55
    dw $07a6,$07a6,$07a7,$07a7,$07a7,$07a7,$07a7,$07a7 ; f-7 + 56-63
    dw $07a7,$07a7,$07a7,$07a7,$07a7,$07a7,$07a7,$07a8 ; f#7 + 0-7
    dw $07a8,$07a8,$07a8,$07a8,$07a8,$07a8,$07a8,$07a8 ; f#7 + 8-15
    dw $07a8,$07a8,$07a8,$07a9,$07a9,$07a9,$07a9,$07a9 ; f#7 + 16-23
    dw $07a9,$07a9,$07a9,$07a9,$07a9,$07a9,$07a9,$07a9 ; f#7 + 24-31
    dw $07aa,$07aa,$07aa,$07aa,$07aa,$07aa,$07aa,$07aa ; f#7 + 32-39
    dw $07aa,$07aa,$07aa,$07aa,$07aa,$07ab,$07ab,$07ab ; f#7 + 40-47
    dw $07ab,$07ab,$07ab,$07ab,$07ab,$07ab,$07ab,$07ab ; f#7 + 48-55
    dw $07ab,$07ab,$07ac,$07ac,$07ac,$07ac,$07ac,$07ac ; f#7 + 56-63
    dw $07ac,$07ac,$07ac,$07ac,$07ac,$07ac,$07ac,$07ad ; g-7 + 0-7
    dw $07ad,$07ad,$07ad,$07ad,$07ad,$07ad,$07ad,$07ad ; g-7 + 8-15
    dw $07ad,$07ad,$07ad,$07ad,$07ae,$07ae,$07ae,$07ae ; g-7 + 16-23
    dw $07ae,$07ae,$07ae,$07ae,$07ae,$07ae,$07ae,$07ae ; g-7 + 24-31
    dw $07ae,$07ae,$07af,$07af,$07af,$07af,$07af,$07af ; g-7 + 32-39
    dw $07af,$07af,$07af,$07af,$07af,$07af,$07af,$07af ; g-7 + 40-47
    dw $07b0,$07b0,$07b0,$07b0,$07b0,$07b0,$07b0,$07b0 ; g-7 + 48-55
    dw $07b0,$07b0,$07b0,$07b0,$07b0,$07b1,$07b1,$07b1 ; g-7 + 56-63
    dw $07b1,$07b1,$07b1,$07b1,$07b1,$07b1,$07b1,$07b1 ; g#7 + 0-7
    dw $07b1,$07b1,$07b1,$07b2,$07b2,$07b2,$07b2,$07b2 ; g#7 + 8-15
    dw $07b2,$07b2,$07b2,$07b2,$07b2,$07b2,$07b2,$07b2 ; g#7 + 16-23
    dw $07b2,$07b2,$07b3,$07b3,$07b3,$07b3,$07b3,$07b3 ; g#7 + 24-31
    dw $07b3,$07b3,$07b3,$07b3,$07b3,$07b3,$07b3,$07b3 ; g#7 + 32-39
    dw $07b4,$07b4,$07b4,$07b4,$07b4,$07b4,$07b4,$07b4 ; g#7 + 40-47
    dw $07b4,$07b4,$07b4,$07b4,$07b4,$07b4,$07b4,$07b5 ; g#7 + 48-55
    dw $07b5,$07b5,$07b5,$07b5,$07b5,$07b5,$07b5,$07b5 ; g#7 + 56-63
    dw $07b5,$07b5,$07b5,$07b5,$07b5,$07b6,$07b6,$07b6 ; a-7 + 0-7
    dw $07b6,$07b6,$07b6,$07b6,$07b6,$07b6,$07b6,$07b6 ; a-7 + 8-15
    dw $07b6,$07b6,$07b6,$07b6,$07b7,$07b7,$07b7,$07b7 ; a-7 + 16-23
    dw $07b7,$07b7,$07b7,$07b7,$07b7,$07b7,$07b7,$07b7 ; a-7 + 24-31
    dw $07b7,$07b7,$07b7,$07b7,$07b8,$07b8,$07b8,$07b8 ; a-7 + 32-39
    dw $07b8,$07b8,$07b8,$07b8,$07b8,$07b8,$07b8,$07b8 ; a-7 + 40-47
    dw $07b8,$07b8,$07b8,$07b9,$07b9,$07b9,$07b9,$07b9 ; a-7 + 48-55
    dw $07b9,$07b9,$07b9,$07b9,$07b9,$07b9,$07b9,$07b9 ; a-7 + 56-63
    dw $07b9,$07b9,$07b9,$07ba,$07ba,$07ba,$07ba,$07ba ; a#7 + 0-7
    dw $07ba,$07ba,$07ba,$07ba,$07ba,$07ba,$07ba,$07ba ; a#7 + 8-15
    dw $07ba,$07ba,$07bb,$07bb,$07bb,$07bb,$07bb,$07bb ; a#7 + 16-23
    dw $07bb,$07bb,$07bb,$07bb,$07bb,$07bb,$07bb,$07bb ; a#7 + 24-31
    dw $07bb,$07bb,$07bc,$07bc,$07bc,$07bc,$07bc,$07bc ; a#7 + 32-39
    dw $07bc,$07bc,$07bc,$07bc,$07bc,$07bc,$07bc,$07bc ; a#7 + 40-47
    dw $07bc,$07bc,$07bc,$07bd,$07bd,$07bd,$07bd,$07bd ; a#7 + 48-55
    dw $07bd,$07bd,$07bd,$07bd,$07bd,$07bd,$07bd,$07bd ; a#7 + 56-63
    dw $07bd,$07bd,$07bd,$07be,$07be,$07be,$07be,$07be ; b-7 + 0-7
    dw $07be,$07be,$07be,$07be,$07be,$07be,$07be,$07be ; b-7 + 8-15
    dw $07be,$07be,$07be,$07be,$07bf,$07bf,$07bf,$07bf ; b-7 + 16-23
    dw $07bf,$07bf,$07bf,$07bf,$07bf,$07bf,$07bf,$07bf ; b-7 + 24-31
    dw $07bf,$07bf,$07bf,$07bf,$07bf,$07c0,$07c0,$07c0 ; b-7 + 32-39
    dw $07c0,$07c0,$07c0,$07c0,$07c0,$07c0,$07c0,$07c0 ; b-7 + 40-47
    dw $07c0,$07c0,$07c0,$07c0,$07c0,$07c0,$07c1,$07c1 ; b-7 + 48-55
    dw $07c1,$07c1,$07c1,$07c1,$07c1,$07c1,$07c1,$07c1 ; b-7 + 56-63
    dw $07c1,$07c1,$07c1,$07c1,$07c1,$07c1,$07c1,$07c1 ; c-8 + 0-7
    dw $07c2,$07c2,$07c2,$07c2,$07c2,$07c2,$07c2,$07c2 ; c-8 + 8-15
    dw $07c2,$07c2,$07c2,$07c2,$07c2,$07c2,$07c2,$07c2 ; c-8 + 16-23
    dw $07c2,$07c2,$07c3,$07c3,$07c3,$07c3,$07c3,$07c3 ; c-8 + 24-31
    dw $07c3,$07c3,$07c3,$07c3,$07c3,$07c3,$07c3,$07c3 ; c-8 + 32-39
    dw $07c3,$07c3,$07c3,$07c3,$07c4,$07c4,$07c4,$07c4 ; c-8 + 40-47
    dw $07c4,$07c4,$07c4,$07c4,$07c4,$07c4,$07c4,$07c4 ; c-8 + 48-55
    dw $07c4,$07c4,$07c4,$07c4,$07c4,$07c4,$07c4,$07c5 ; c-8 + 56-63
    dw $07c5,$07c5,$07c5,$07c5,$07c5,$07c5,$07c5,$07c5 ; c#8 + 0-7
    dw $07c5,$07c5,$07c5,$07c5,$07c5,$07c5,$07c5,$07c5 ; c#8 + 8-15
    dw $07c5,$07c6,$07c6,$07c6,$07c6,$07c6,$07c6,$07c6 ; c#8 + 16-23
    dw $07c6,$07c6,$07c6,$07c6,$07c6,$07c6,$07c6,$07c6 ; c#8 + 24-31
    dw $07c6,$07c6,$07c6,$07c6,$07c7,$07c7,$07c7,$07c7 ; c#8 + 32-39
    dw $07c7,$07c7,$07c7,$07c7,$07c7,$07c7,$07c7,$07c7 ; c#8 + 40-47
    dw $07c7,$07c7,$07c7,$07c7,$07c7,$07c7,$07c7,$07c7 ; c#8 + 48-55
    dw $07c8,$07c8,$07c8,$07c8,$07c8,$07c8,$07c8,$07c8 ; c#8 + 56-63
    dw $07c8,$07c8,$07c8,$07c8,$07c8,$07c8,$07c8,$07c8 ; d-8 + 0-7
    dw $07c8,$07c8,$07c8,$07c8,$07c9,$07c9,$07c9,$07c9 ; d-8 + 8-15
    dw $07c9,$07c9,$07c9,$07c9,$07c9,$07c9,$07c9,$07c9 ; d-8 + 16-23
    dw $07c9,$07c9,$07c9,$07c9,$07c9,$07c9,$07c9,$07c9 ; d-8 + 24-31
    dw $07ca,$07ca,$07ca,$07ca,$07ca,$07ca,$07ca,$07ca ; d-8 + 32-39
    dw $07ca,$07ca,$07ca,$07ca,$07ca,$07ca,$07ca,$07ca ; d-8 + 40-47
    dw $07ca,$07ca,$07ca,$07ca,$07cb,$07cb,$07cb,$07cb ; d-8 + 48-55
    dw $07cb,$07cb,$07cb,$07cb,$07cb,$07cb,$07cb,$07cb ; d-8 + 56-63
    dw $07cb,$07cb,$07cb,$07cb,$07cb,$07cb,$07cb,$07cb ; d#8 + 0-7
    dw $07cb,$07cc,$07cc,$07cc,$07cc,$07cc,$07cc,$07cc ; d#8 + 8-15
    dw $07cc,$07cc,$07cc,$07cc,$07cc,$07cc,$07cc,$07cc ; d#8 + 16-23
    dw $07cc,$07cc,$07cc,$07cc,$07cc,$07cc,$07cd,$07cd ; d#8 + 24-31
    dw $07cd,$07cd,$07cd,$07cd,$07cd,$07cd,$07cd,$07cd ; d#8 + 32-39
    dw $07cd,$07cd,$07cd,$07cd,$07cd,$07cd,$07cd,$07cd ; d#8 + 40-47
    dw $07cd,$07cd,$07cd,$07cd,$07ce,$07ce,$07ce,$07ce ; d#8 + 48-55
    dw $07ce,$07ce,$07ce,$07ce,$07ce,$07ce,$07ce,$07ce ; d#8 + 56-63
    dw $07ce,$07ce,$07ce,$07ce,$07ce,$07ce,$07ce,$07ce ; e-8 + 0-7
    dw $07ce,$07ce,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf ; e-8 + 8-15
    dw $07cf,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf ; e-8 + 16-23
    dw $07cf,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf,$07cf ; e-8 + 24-31
    dw $07cf,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0 ; e-8 + 32-39
    dw $07d0,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0 ; e-8 + 40-47
    dw $07d0,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0,$07d0 ; e-8 + 48-55
    dw $07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1 ; e-8 + 56-63
    dw $07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1 ; f-8 + 0-7
    dw $07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1,$07d1 ; f-8 + 8-15
    dw $07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2 ; f-8 + 16-23
    dw $07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2 ; f-8 + 24-31
    dw $07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2,$07d2 ; f-8 + 32-39
    dw $07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3 ; f-8 + 40-47
    dw $07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3 ; f-8 + 48-55
    dw $07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3,$07d3 ; f-8 + 56-63
    dw $07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4 ; f#8 + 0-7
    dw $07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4 ; f#8 + 8-15
    dw $07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4,$07d4 ; f#8 + 16-23
    dw $07d4,$07d4,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5 ; f#8 + 24-31
    dw $07d5,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5 ; f#8 + 32-39
    dw $07d5,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5,$07d5 ; f#8 + 40-47
    dw $07d5,$07d5,$07d5,$07d6,$07d6,$07d6,$07d6,$07d6 ; f#8 + 48-55
    dw $07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d6 ; f#8 + 56-63
    dw $07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d6 ; g-8 + 0-7
    dw $07d6,$07d6,$07d6,$07d6,$07d6,$07d6,$07d7,$07d7 ; g-8 + 8-15
    dw $07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7 ; g-8 + 16-23
    dw $07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7 ; g-8 + 24-31
    dw $07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7,$07d7 ; g-8 + 32-39
    dw $07d7,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8 ; g-8 + 40-47
    dw $07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8 ; g-8 + 48-55
    dw $07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8,$07d8 ; g-8 + 56-63
    dw $07d8,$07d8,$07d8,$07d8,$07d9,$07d9,$07d9,$07d9 ; g#8 + 0-7
    dw $07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9 ; g#8 + 8-15
    dw $07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9 ; g#8 + 16-23
    dw $07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9,$07d9 ; g#8 + 24-31
    dw $07d9,$07da,$07da,$07da,$07da,$07da,$07da,$07da ; g#8 + 32-39
    dw $07da,$07da,$07da,$07da,$07da,$07da,$07da,$07da ; g#8 + 40-47
    dw $07da,$07da,$07da,$07da,$07da,$07da,$07da,$07da ; g#8 + 48-55
    dw $07da,$07da,$07da,$07da,$07da,$07da,$07db,$07db ; g#8 + 56-63
    dw $07db,$07db,$07db,$07db,$07db,$07db,$07db,$07db ; a-8 + 0-7
    dw $07db,$07db,$07db,$07db,$07db,$07db,$07db,$07db ; a-8 + 8-15
    dw $07db,$07db,$07db,$07db,$07db,$07db,$07db,$07db ; a-8 + 16-23
    dw $07db,$07db,$07db,$07db,$07dc,$07dc,$07dc,$07dc ; a-8 + 24-31
    dw $07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc ; a-8 + 32-39
    dw $07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc ; a-8 + 40-47
    dw $07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc,$07dc ; a-8 + 48-55
    dw $07dc,$07dc,$07dc,$07dd,$07dd,$07dd,$07dd,$07dd ; a-8 + 56-63
    dw $07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd ; a#8 + 0-7
    dw $07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd ; a#8 + 8-15
    dw $07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd,$07dd ; a#8 + 16-23
    dw $07dd,$07dd,$07de,$07de,$07de,$07de,$07de,$07de ; a#8 + 24-31
    dw $07de,$07de,$07de,$07de,$07de,$07de,$07de,$07de ; a#8 + 32-39
    dw $07de,$07de,$07de,$07de,$07de,$07de,$07de,$07de ; a#8 + 40-47
    dw $07de,$07de,$07de,$07de,$07de,$07de,$07de,$07de ; a#8 + 48-55
    dw $07de,$07de,$07de,$07df,$07df,$07df,$07df,$07df ; a#8 + 56-63
    dw $07df,$07df,$07df,$07df,$07df,$07df,$07df,$07df ; b-8 + 0-7
    dw $07df,$07df,$07df,$07df,$07df,$07df,$07df,$07df ; b-8 + 8-15
    dw $07df,$07df,$07df,$07df,$07df,$07df,$07df,$07df ; b-8 + 16-23
    dw $07df,$07df,$07df,$07df,$07df,$07e0,$07e0,$07e0 ; b-8 + 24-31
    dw $07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0 ; b-8 + 32-39
    dw $07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0 ; b-8 + 40-47
    dw $07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0 ; b-8 + 48-55
    dw $07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e0,$07e1 ; b-8 + 56-63 
        
; ================
; Player variables
; ================

section "GBMod vars",wram0
GBM_RAM_Start:

GBM_SongID:         ds  1
GBM_CurrentBank:    ds  1
GBM_DoPlay:         ds  1
GBM_CurrentRow:     ds  1
GBM_CurrentPattern: ds  1
GBM_ModuleSpeed:    ds  1
GBM_SpeedChanged:   ds  1
GBM_ModuleTimer:    ds  1
GBM_TickSpeed:      ds  1
GBM_TickTimer:      ds  1
GBM_PatternCount:   ds  1
GBM_PatTableSize:   ds  1
GBM_PatTablePos:    ds  1
GBM_SongDataOffset: ds  2

GBM_PanFlags:       ds  1

GBM_ArpTick1:       ds  1
GBM_ArpTick2:       ds  1
GBM_ArpTick3:       ds  1
GBM_ArpTick4:       ds  1

GBM_CmdTick1:       ds  1
GBM_CmdTick2:       ds  1
GBM_CmdTick3:       ds  1
GBM_CmdTick4:       ds  1

GBM_Command1:       ds  1
GBM_Command2:       ds  1
GBM_Command3:       ds  1
GBM_Command4:       ds  1
GBM_Param1:         ds  1
GBM_Param2:         ds  1
GBM_Param3:         ds  1
GBM_Param4:         ds  1

GBM_Note1:          ds  1
GBM_Note2:          ds  1
GBM_Note3:          ds  1
GBM_Note4:          ds  1

GBM_FreqOffset1:    ds  2
GBM_FreqOffset2:    ds  2
GBM_FreqOffset3:    ds  2

GBM_Vol1:           ds  1
GBM_Vol2:           ds  1
GBM_Vol3:           ds  1
GBM_Vol4:           ds  1
GBM_OldVol1:        ds  1
GBM_OldVol2:        ds  1
GBM_OldVol3:        ds  1
GBM_OldVol4:        ds  1
GBM_Pulse1:         ds  1
GBM_Pulse2:         ds  1
GBM_Wave3:          ds  1
GBM_Mode4:          ds  1

GBM_SkipCH1:        ds  1
GBM_SkipCH2:        ds  1
GBM_SkipCH3:        ds  1
GBM_SkipCH4:        ds  1

GBM_LastWave:       ds  1
GBM_WaveBuffer:     ds  16

GBM_SamplePlaying:  ds  1
GBM_SampleID:       ds  1
GBM_SampleBank:     ds  1
GBM_SamplePointer:  ds  2
GBM_SampleCounter:  ds  2

GBM_EnableTimer:    ds  1
GBM_TMA:            ds  1
GBM_TAC:            ds  1
GBM_RAM_End:

; Note values
C_2     equ $00
C#2     equ $01
D_2     equ $02
D#2     equ $03
E_2     equ $04
F_2     equ $05
F#2     equ $06
G_2     equ $07
G#2     equ $08
A_2     equ $09
A#2     equ $0a
B_2     equ $0b
C_3     equ $0c
C#3     equ $0d
D_3     equ $0e
D#3     equ $0f
E_3     equ $10
F_3     equ $11
F#3     equ $12
G_3     equ $13
G#3     equ $14
A_3     equ $15
A#3     equ $16
B_3     equ $17
C_4     equ $18
C#4     equ $19
D_4     equ $1a
D#4     equ $1b
E_4     equ $1c
F_4     equ $1d
F#4     equ $1e
G_4     equ $1f
G#4     equ $20
A_4     equ $21
A#4     equ $22
B_4     equ $23
C_5     equ $24
C#5     equ $25
D_5     equ $26
D#5     equ $27
E_5     equ $28
F_5     equ $29
F#5     equ $2a
G_5     equ $2b
G#5     equ $2c
A_5     equ $2d
A#5     equ $2e
B_5     equ $2f
C_6     equ $30
C#6     equ $31
D_6     equ $32
D#6     equ $33
E_6     equ $34
F_6     equ $35
F#6     equ $36
G_6     equ $37
G#6     equ $38
A_6     equ $39
A#6     equ $3a
B_6     equ $3b
C_7     equ $3c
C#7     equ $3d
D_7     equ $3e
D#7     equ $3f
E_7     equ $40
F_7     equ $41
F#7     equ $42
G_7     equ $43
G#7     equ $44
A_7     equ $45
A#7     equ $46
B_7     equ $47