; ================================================================
; GBMod replay routine
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
    ld      [GBM_SongID],a
    xor     a
    ld      hl,GBM_RAM_Start+1
    ld      b,(GBM_RAM_End-GBM_RAM_Start+1)-2
.clearloop
    ld      [hl+],a
    dec     b
    jr      nz,.clearloop   
    inc     a
    ld      [GBM_ModuleTimer],a
    ld      [GBM_TickTimer],a
    
    ldh     [rNR52],a   ; disable sound (clears all sound registers)
    or      $80
    ldh     [rNR52],a   ; enable sound
    or      $7f
    ldh     [rNR51],a   ; all channels to SO1+SO2
    xor     %10001000
    ldh     [rNR50],a   ; master volume 7

    ld      a,[GBM_SongID]
    inc     a
;   ld      b,a
;   ld      a,[GBM_CurrentBank]
;   add     b
    ld      [rROMB0],a
    ld      hl,$4000
    
    ld      a,[hl+]
    ld      [GBM_PatternCount],a
    ld      a,[hl+]
    ld      [GBM_PatTableSize],a
    ld      a,[hl+]
    ld      [GBM_ModuleSpeed],a
    ld      a,[hl+]
    ld      [GBM_TickSpeed],a
    ld      a,[hl+]
    ld      [GBM_SongDataOffset],a
    ld      a,[hl+]
    ld      [GBM_SongDataOffset+1],a
    ld      a,[hl+]
    and     a
    jr      z,.vblank
.timer
    ldh     [rTMA],a
    ldh     [rTIMA],a
    ld      a,[hl]
    ldh     [rTAC],a
    ld      a,1
    ld      [GBM_EnableTimer],a
    jr      :+
.vblank
    xor     a
    ldh     [rTMA],a
    ldh     [rTIMA],a
    ldh     [rTAC],a
:   ld      a,$ff
    ld      [GBM_LastWave],a
    ld      a,1
    ld      [GBM_DoPlay],a
    ld      [GBM_CmdTick1],a
    ld      [GBM_CmdTick2],a
    ld      [GBM_CmdTick3],a
    ld      [GBM_CmdTick4],a
    ld      a,$ff
    ld      [GBM_PanFlags],a
    
    ld      a,[$40f0]
    ld      [GBM_CurrentPattern],a
    pop     hl
    pop     bc
    pop     af
    reti

; ================================

GBMod_Stop:
    xor     a
    ld      hl,GBM_RAM_Start
    ld      b,GBM_RAM_End-GBM_RAM_Start
.clearloop
    ld      [hl+],a
    dec     b
    jr      nz,.clearloop
    
    ldh     [rNR52],a   ; disable sound (clears all sound registers)
    or      $80
    ldh     [rNR52],a   ; enable sound
    or      $7f
    ldh     [rNR51],a   ; all channels to SO1+SO2
    xor     %10001000
    ldh     [rNR50],a   ; master volume 7
    ret
    
; ================================

GBMod_Update:
    ld      a,[GBM_DoPlay]
    and     a
    ret     z
    
    ; adjust timing for GBC double speed
    ld      a,[GBM_EnableTimer]
    and     a
    jr      z,:+    ; skip ahead if timer is disabled
    ldh     a,[rKEY1]
    cp      $ff
    jr      z,:+
    bit     7,a
    jr      z,:+
    ld      hl,GBM_OddTick
    inc     [hl]
    bit     0,[hl]
    ret     z
:
    
    ; anything that needs to be updated on a per-frame basis should be put here
;    ld      e,0
;    call    GBMod_DoVib ; pulse 1 vibrato
;    inc     e
;    call    GBMod_DoVib ; pulse 2 vibrato
;    inc     e
;    call    GBMod_DoVib ; pulse 3 vibrato

    ld      a,[GBM_TickTimer]
    dec     a
    ld      [GBM_TickTimer],a
    ret     nz
    ld      a,[GBM_TickSpeed]
    ld      [GBM_TickTimer],a
    ld      a,[GBM_ModuleTimer]
    dec     a
    ld      [GBM_ModuleTimer],a
    jp      nz,GBMod_UpdateCommands
    ld      [GBM_SpeedChanged],a
    ld      a,[GBM_ModuleSpeed]
    ld      [GBM_ModuleTimer],a
    ld      a,[GBM_SongID]
    inc     a
;    ld      b,a
;    ld      a,[GBM_CurrentBank]
;    add     b
    ld      [rROMB0],a
    ld      hl,GBM_SongDataOffset
    ld      a,[hl+]
    ld      b,a
    ld      a,[hl]
    add     $40
    ld      h,a
    ld      l,b
    
    ; get pattern offset
    ld      a,[GBM_CurrentPattern]
    and     a
    jr      z,.getRow
    
    add     a
    add     a
    add     h
    bit     7,a
    jr      z,:+
    sub     $40
    push        af
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    pop     af
:   ld      h,a
.getRow
    ld      a,[GBM_CurrentRow]
    and     a
    jr      z,.readPatternData
    
    ld      b,a
    swap    a
    and     $f0
    ld      e,a
    ld      a,b
    swap    a
    and     $0f
    ld      d,a
    add     hl,de
    bit     7,h
    jr      z,.readPatternData
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    ld      a,h
    xor     %11000000
    ld      h,a
    
.readPatternData
    xor     a
    ld      [GBM_NewNote1],a
    ld      [GBM_NewNote2],a
    ld      [GBM_NewNote3],a
    ld      [GBM_NewNote4],a

    ; ch1 note
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    push    af
    cp      $ff
    jp      z,.skip1
    cp      $fe
    jr      nz,.nocut1
    xor     a
    ld      [GBM_Vol1],a
    ldh     [rNR12],a
    ld      a,%10000000
    ldh     [rNR14],a
    jp      .skip1
.nocut1
    inc     hl
    bit     7,h
    call        nz,GBM_HandlePageBoundary
    ld      a,[hl]
    dec     hl
    bit     6,h
    call    z,GBM_HandlePageBoundaryBackwards
;   cp  1
;   jr  z,.noreset1
;   cp  2
;   jr  z,.noreset1
    call    GBM_ResetFreqOffset1
    xor     a
    ld      [GBM_ArpTick1],a
    ld      a,1
    ld      [GBM_NewNote1],a
.noreset1
    pop af
.freq1
    ld      [GBM_Note1],a
    ld      e,0
    call    GBMod_GetFreq2
    ; ch1 volume
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.skipvol1
    ld      a,[hl]
    swap    a
    and     $f
    jr      z,.skipvol1
    ld      b,a
    rla
    rla
    rla
    ld      [GBM_Vol1],a
    ld      a,b
    swap    a
    ldh     [rNR12],a
    set     7,e
.skipvol1
    ; ch1 pulse
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    ld      b,a
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.skippulse1
    ld      a,b
    and     $f
    jr      z,.skippulse1
    dec     a
    ld      [GBM_Pulse1],a
    swap    a
    rla
    rla
    ldh     [rNR11],a
.skippulse1
    push    de
    ; ch1 command
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    ld      [GBM_Command1],a
    ld      e,a
    ; ch1 parameter
    ld      a,[hl+]
    ld      d,a
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    and     a               ; is parameter 00?
    jr      nz,:+           ; if not, write parameter
    ld      a,e
    and     a               ; is command 0xy?
    jr      z,:+
    cp      $1              ; is command 1xy?
    jr      z,.skipparam1
    cp      $2              ; is command 2xy?
    jr      z,.skipparam1
    cp      $8              ; is command 8xy?
    jr      z,:+
    cp      $a              ; is command Axx?
    jr      z,.skipparam1
    cp      $b              ; is command Bxx?
    jr      z,:+
    cp      $c              ; is command Cxx?
    jr      z,:+
;    cp      $d              ; is command Dxx?
;    jr      z,:+
:   ld      a,d
    ld      [GBM_Param1],a
.skipparam1
    pop     de
    ; update freq
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.ch2
    ld      a,d
    ldh     [rNR13],a
    ld      a,e
    ldh     [rNR14],a
    jr      .ch2
.skip1
    pop     af
    ld      a,[GBM_Note1]
    jp      .freq1

.ch2
    ; ch2 note
    ld      a,[hl+]
    bit     7,h
    call   nz,GBM_HandlePageBoundary 
    push    af
    cp      $ff
    jp      z,.skip2
    cp      $fe
    jr      nz,.nocut2
    xor     a
    ld      [GBM_Vol2],a
    ldh     [rNR22],a
    ld      a,%10000000
    ldh     [rNR24],a
    jp      .skip2
.nocut2
    inc     hl
    ld      a,[hl]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    dec     hl
    bit     6,h
    call    z,GBM_HandlePageBoundaryBackwards
;   cp      1
;   jr      z,.noreset2
;   cp      2
;   jr      z,.noreset2
    call    GBM_ResetFreqOffset2
    xor     a
    ld      [GBM_ArpTick2],a
    ld      a,1
    ld      [GBM_NewNote2],a
.noreset2
    pop     af
.freq2
    ld      [GBM_Note2],a
    ld      e,1
    call    GBMod_GetFreq2
    ; ch2 volume
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.skipvol2
    ld      a,[hl]
    swap    a
    and     $f
    jr      z,.skipvol2
    ld      b,a
    rla
    rla
    rla
    ld      [GBM_Vol2],a
    ld      a,b
    swap    a
    ldh     [rNR22],a
    set     7,e
.skipvol2
    ; ch2 pulse
    ld      a,[hl+]
    bit     7,h
    call   nz,GBM_HandlePageBoundary 
    ld      b,a
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.skippulse2
    ld      a,b
    and     $f
    jr      z,.skippulse2
    dec     a
    ld      [GBM_Pulse2],a
    swap    a
    rla
    rla
    ldh     [rNR21],a
.skippulse2
    push    de
    ; ch2 command
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    ld      [GBM_Command2],a
    ld      e,a
    ; ch2 parameter
    ld      a,[hl+]
    ld      d,a
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    and     a               ; is parameter 00?
    jr      nz,:+           ; if not, write parameter
    ld      a,e
    and     a               ; is command 0xy?
    jr      z,:+
    cp      $1              ; is command 1xy?
    jr      z,.skipparam2
    cp      $2              ; is command 2xy?
    jr      z,.skipparam2
    cp      $8              ; is command 8xy?
    jr      z,:+
    cp      $a              ; is command Axx?
    jr      z,.skipparam2
    cp      $b              ; is command Bxx?
    jr      z,:+
    cp      $c              ; is command Cxx?
    jr      z,:+
;    cp      $d              ; is command Dxx?
;    jr      z,:+
:   ld      a,d
    ld      [GBM_Param2],a
.skipparam2
    pop     de
    ; update freq
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.ch3
    ld      a,d
    ldh     [rNR23],a
    ld      a,e
    ldh     [rNR24],a
    jr      .ch3
.skip2
    pop     af
    ld      a,[GBM_Note2]
    jp      .freq2
    
.ch3
    ; ch3 note
.note3
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    push    af
    cp      $ff
    jp      z,.skip3
    cp      $fe
    jr      nz,.nocut3
    xor     a
    ld      [GBM_Vol3],a
    ldh     [rNR32],a
.nocut3
    inc     hl
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    ld      a,[hl]
    dec     hl
    bit     6,h
    call    z,GBM_HandlePageBoundaryBackwards
;   cp      1
;   jr      z,.noreset3
;   cp      2
;   jr      z,.noreset3
    call    GBM_ResetFreqOffset3
    xor     a
    ld      [GBM_ArpTick3],a
    ld      a,1
    ld      [GBM_NewNote3],a
.noreset3
    pop     af
.freq3
    ld      [GBM_Note3],a
    ld      e,2
    call    GBMod_GetFreq2
    ; ch3 volume
    ld      a,[hl]
    swap    a
    and     $f
    jr      z,.skipvol3
    ld      b,a
    rla
    rla
    rla
    ld      [GBM_Vol3],a
    ld      a,b
    call    GBMod_GetVol3
    ld      b,a
    ld      a,[GBM_OldVol3]
    cp      b
    jr      z,.skipvol3
    ld      a,[GBM_SkipCH3]
    and     a
    jr      nz,.skipvol3
    ld      a,b
    ldh     [rNR32],a
    set     7,e
.skipvol3
    ld      [GBM_OldVol3],a
    ; ch3 wave
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    dec     a
    and     $f
    cp      15
    jr      z,.continue3
    ld      b,a
    ld      a,[GBM_LastWave]
    cp      b
    jr      z,.continue3
    ld      a,b
    ld      [GBM_Wave3],a
    ld      [GBM_LastWave],a
    push    hl
    call    GBM_LoadWave
    set     7,e
    pop     hl
.continue3
    push    de
    ; ch3 command
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    ld      [GBM_Command3],a
    ld      e,a
    ; ch3 parameter
    ld      a,[hl+]
    ld      d,a
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    and     a               ; is parameter 00?
    jr      nz,:+           ; if not, write parameter
    ld      a,e
    and     a               ; is command 0xy?
    jr      z,:+
    cp      $1              ; is command 1xy?
    jr      z,.skipparam3
    cp      $2              ; is command 2xy?
    jr      z,.skipparam3
    cp      $8              ; is command 8xy?
    jr      z,:+
    cp      $a              ; is command Axx?
    jr      z,.skipparam3
    cp      $b              ; is command Bxx?
    jr      z,:+
    cp      $c              ; is command Cxx?
    jr      z,:+
;    cp      $d              ; is command Dxx?
;    jr      z,:+
:   ld      a,d
    ld      [GBM_Param3],a
.skipparam3
    pop     de
    ; update freq   
    ld      a,[GBM_SkipCH3]
    and     a
    jr      nz,.ch4
    ld      a,d
    ldh     [rNR33],a
    ld      a,e
    ldh     [rNR34],a
    jr      .ch4
.skip3
    pop     af
    ld      a,[GBM_Note3]
    jp      .freq3
.nostopsample3
    ld      a,l
    add     4
    ld      l,a
    jr      nc,.ch4
    inc     h
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    
.ch4
    ; ch4 note
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    cp      $ff
    jp      z,.skip4
    cp      $fe
    jr      nz,.freq4
    xor     a
    ld      [GBM_Vol4],a
    ldh     [rNR42],a
    ld      a,%10000000
    ldh     [rNR44],a
    ld      a,1
    ld      [GBM_NewNote4],a
    jp      .skip4
    
.freq4
    ld      [GBM_Note4],a
    push    hl
    ld      hl,NoiseTable
    add     l
    ld      l,a
    jr      nc,.nocarry
    inc     h
.nocarry
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    ld      d,a
    pop     hl
    ; ch4 volume
    ld      a,[GBM_SkipCH4]
    and     a
    jr      nz,.skipvol4
    ld      a,[hl]
    swap    a
    and     $f
    jr      z,.skipvol4
    ld      b,a
    rla
    rla
    rla
    ld      [GBM_Vol4],a
    ld      a,b
    swap    a
    ldh     [rNR42],a
    set     7,e
.skipvol4
    ; ch4 mode
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    and     a
    jr      z,.nomode
    dec     a
    and     1
    ld      [GBM_Mode4],a
    and     a
    jr      z,.nomode
    set     3,d
.nomode
    ; ch4 command
    push    de
    ld      a,[hl+]
    bit     7,h
    call    nz,GBM_HandlePageBoundary 
    ld      [GBM_Command4],a
    ld      e,a
    ; ch1 parameter
    ld      a,[hl+]
    ld      d,a
    bit     7,h
    call    nz,GBM_HandlePageBoundary
    and     a               ; is parameter 00?
    jr      nz,:+           ; if not, write parameter
    ld      a,e
    and     a               ; is command 0xy?
    jr      z,:+
    cp      $1              ; is command 1xy?
    jr      z,.skipparam4
    cp      $2              ; is command 2xy?
    jr      z,.skipparam4
    cp      $8              ; is command 8xy?
    jr      z,:+
    cp      $a              ; is command Axx?
    jr      z,.skipparam4
    cp      $b              ; is command Bxx?
    jr      z,:+
    cp      $c              ; is command Cxx?
    jr      z,:+
;    cp      $d              ; is command Dxx?
;    jr      z,:+
:   ld      a,d
    ld      [GBM_Param4],a
.skipparam4
    pop de
    ; set freq
    ld      a,[GBM_SkipCH4]
    and     a
    jr      nz,.updateRow
    ld      a,d
    ldh     [rNR43],a
    ld      a,$80
    ldh     [rNR44],a
    jr      .updateRow
.skip4
    ld      a,[GBM_Note4]
    jp      .freq4
        
.updateRow
    call    GBM_ResetCommandTick
    ld      a,[GBM_CurrentRow]
    inc     a
    cp      64
    jr      z,.nextPattern
    ld      [GBM_CurrentRow],a
    jr      .done
.nextPattern
    xor     a
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_PatTablePos]
    inc     a
    ld      b,a
    ld      a,[GBM_PatTableSize]
    cp      b
    jr      z,.loopSong
    ld      a,b
    ld      [GBM_PatTablePos],a
    jr      .setPattern
.loopSong
    xor a
    ld  [GBM_PatTablePos],a
.setPattern
    push    af
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    pop     af
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl+]
    ld      [GBM_CurrentPattern],a
.done
    
GBMod_UpdateCommands:
    ld      a,$ff
    ld      [GBM_PanFlags],a
    ; ch1
    ld      a,[GBM_Command1]
    ld      hl,.commandTable1
    add     a
    add     l
    ld      l,a
    jr      nc,.nocarry1
    inc     h
.nocarry1
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      hl
    
.commandTable1
    dw      .arp1           ; 0xy - arp
    dw      .slideup1       ; 1xy - note slide up
    dw      .slidedown1     ; 2xy - note slide down
    dw      .ch2            ; 3xy - portamento (NYI)
    dw      .ch2            ; 4xy - vibrato (handled elsewhere)
    dw      .ch2            ; 5xy - portamento + volume slide (NYI)
    dw      .ch2            ; 6xy - vibrato + volume slide (NYI)
    dw      .ch2            ; 7xy - tremolo (NYI)
    dw      .pan1           ; 8xy - panning
    dw      .ch2            ; 9xy - sample offset (won't be implemented)
    dw      .volslide1      ; Axy - volume slide
    dw      .patjump1       ; Bxy - pattern jump
    dw      .ch2            ; Cxy - set volume (won't be implemented)
    dw      .patbreak1      ; Dxy - pattern break
    dw      .ch2            ; Exy - extended commands (NYI)
    dw      .speed1         ; Fxy - set module speed
.arp1
    ld      a,[GBM_Param1]
    and     a
    jp      z,.ch2
    ld      a,[GBM_ArpTick1]
    inc     a
    cp      4
    jr      nz,.noresetarp1
    ld      a,1
.noresetarp1
    ld      [GBM_ArpTick1],a
    ld      a,[GBM_Param1]
    ld      b,a
    ld      a,[GBM_Note1]
    ld      c,a
    ld      a,[GBM_ArpTick1]
    dec     a
    call        GBMod_DoArp
    ld      a,[GBM_SkipCH1]
    and     a
    jp      nz,.ch2
    ld      a,d
    ldh     [rNR13],a
    ld      a,e
    ldh     [rNR14],a
    jp      .ch2
.slideup1
    ld      a,[GBM_Param1]
    ld      b,a
    ld      e,0
    call    GBMod_DoPitchSlide
    ld      a,[GBM_Note1]
    call    GBMod_GetFreq2
    jp      .dosetfreq1
.slidedown1
    ; read tick speed
    ld      a,[GBM_Param1]
    ld      b,a
    ld      e,0
    call    GBMod_DoPitchSlide
    ld      a,[GBM_Note1]
    call    GBMod_GetFreq2
    jp      .dosetfreq1
.pan1
    ld      a,[GBM_Param1]
    cp      $55
    jr      c,.panleft1
    cp      $aa
    jr      c,.pancenter1
.panright1
    ld      a,$10
    jr      :+
.pancenter1
    xor     a
    jr      :+
.panleft1
    ld      a,$01    
:   ld      b,a
    ld      a,[GBM_PanFlags]
    xor     b
    ld      [GBM_PanFlags],a
    jp      .ch2
.patbreak1
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    ld      a,[GBM_Param1]
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_PatTablePos]
    inc     a
    ld      b,a
    ld      a,[GBM_PatTableSize]
    cp      b
    ld      a,b
    jr      nz,:+
    ; TODO: loop position
    xor     a
:   ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command1],a
    ld      [GBM_Param1],a
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    jp      .done
.patjump1
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_Param1]
    ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command1],a
    ld      [GBM_Param1],a
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentBank],a
    jp      .done
.volslide1
    ld      a,[GBM_ModuleSpeed]
    ld      b,a
    ld      a,[GBM_ModuleTimer]
    cp      b
    jr      z,.ch2  ; skip first tick
    
    ld      a,[GBM_Param1]
    cp      $10
    jr      c,.volslide1_dec
.volslide1_inc
    swap    a
    and     $f
    ld      b,a
    ld      a,[GBM_Vol1]
    add     b
    jr      c,:+
    add     b
    jr      nc,.volslide1_nocarry
:   ld      a,$f
    jr      .volslide1_nocarry
.volslide1_dec
    ld      b,a
    ld      a,[GBM_Vol1]
    sub     b
    jr      c,:+
    sub     b
    jr      nc,.volslide1_nocarry
:   xor     a
.volslide1_nocarry
    ld      [GBM_Vol1],a
    rra
    rra
    rra
    and     $f
    ld      b,a
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.ch2
    ld      a,b
    swap    a
    ldh     [rNR12],a
    ld      a,[GBM_Note1]
    call    GBMod_GetFreq
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.ch2
    ld      a,d
    ldh     [rNR13],a
    ld      a,e
    or      $80
    ldh     [rNR14],a
    jr      .ch2
.dosetfreq1
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.ch2
    ld      a,d
    ldh     [rNR13],a
    ld      a,e
    ldh     [rNR14],a
    jr      .ch2
.speed1
    ld      a,[GBM_SpeedChanged]
    and     a
    jr      nz,.ch2
    ld      a,[GBM_Param1]
    ld      [GBM_ModuleSpeed],a
    ld      [GBM_ModuleTimer],a
    ld      a,1
    ld      [GBM_SpeedChanged],a
    
.ch2
    ld      a,[GBM_Command1]
    cp      4
    jr      nz,.novib1
    ld      a,[GBM_Note1]
    call    GBMod_GetFreq
    ld      h,d
    ld      l,e
    ld      a,[GBM_FreqOffset1]
    add     h
    ld      h,a
    jr      nc,.continue1
    inc     l
.continue1
    ld      a,[GBM_SkipCH1]
    and     a
    jr      nz,.novib1
    ld      a,h
    ldh     [rNR13],a
    ld      a,l
    ldh     [rNR14],a
.novib1
    
    ld      a,[GBM_Command2]
    ld      hl,.commandTable2
    add     a
    add     l
    ld      l,a
    jr      nc,.nocarry2
    inc     h
.nocarry2
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      hl
    
.commandTable2
    dw      .arp2           ; 0xy - arp
    dw      .slideup2       ; 1xy - note slide up
    dw      .slidedown2     ; 2xy - note slide down
    dw      .ch3            ; 3xy - portamento (NYI)
    dw      .ch3            ; 4xy - vibrato (handled elsewhere)
    dw      .ch3            ; 5xy - portamento + volume slide (NYI)
    dw      .ch3            ; 6xy - vibrato + volume slide (NYI)
    dw      .ch3            ; 7xy - tremolo (NYI)
    dw      .pan2           ; 8xy - panning
    dw      .ch3            ; 9xy - sample offset (won't be implemented)
    dw      .volslide2      ; Axy - volume slide
    dw      .patjump2       ; Bxy - pattern jump
    dw      .ch3            ; Cxy - set volume (won't be implemented)
    dw      .patbreak2      ; Dxy - pattern break
    dw      .ch3            ; Exy - extended commands (NYI)
    dw      .speed2         ; Fxy - set module speed
.arp2
    ld      a,[GBM_Param2]
    and     a
    jp      z,.ch3
    ld      a,[GBM_ArpTick2]
    inc     a
    cp      4
    jr      nz,.noresetarp2
    ld      a,1
.noresetarp2
    ld      [GBM_ArpTick2],a
    ld      a,[GBM_Param2]
    ld      b,a
    ld      a,[GBM_Note2]
    ld      c,a
    ld      a,[GBM_ArpTick2]
    dec     a
    call    GBMod_DoArp
    ld      a,[GBM_SkipCH2]
    and     a
    jp      nz,.ch3
    ld      a,d
    ldh     [rNR23],a
    ld      a,e
    ldh     [rNR24],a
    jp      .ch3
.slideup2
    ld      a,[GBM_Param2]
    ld      b,a
    ld      e,1
    call    GBMod_DoPitchSlide
    ld      a,[GBM_Note2]
    call    GBMod_GetFreq2
    jp      .dosetfreq2
.slidedown2
    ; read tick speed
    ld      a,[GBM_Param2]
    ld      b,a
    ld      e,1
    call    GBMod_DoPitchSlide
    ld      a,[GBM_Note2]
    call    GBMod_GetFreq2
    jp      .dosetfreq2
.pan2
    ld      a,[GBM_Param2]
    cp      $55
    jr      c,.panleft2
    cp      $aa
    jr      c,.pancenter2
.panright2
    ld      a,$10
    jr      :+
.pancenter2
    xor     a
    jr      :+
.panleft2
    ld      a,$01
:   rla 
    ld      b,a
    ld      a,[GBM_PanFlags]
    xor     b
    ld      [GBM_PanFlags],a
    jp      .ch3
.patbreak2
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    ld      a,[GBM_Param2]
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_PatTablePos]
    inc     a
    ld      b,a
    ld      a,[GBM_PatTableSize]
    cp      b
    ld      a,b
    jr      nz,:+
    ; TODO: loop position
    xor     a
:   ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command2],a
    ld      [GBM_Param2],a
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    jp      .done
.patjump2
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_Param2]
    ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command2],a
    ld      [GBM_Param2],a
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentBank],a
    jp      .done
.volslide2
    ld      a,[GBM_ModuleSpeed]
    ld      b,a
    ld      a,[GBM_ModuleTimer]
    cp      b
    jr      z,.ch3  ; skip first tick

    ld      a,[GBM_Param2]
    cp      $10
    jr      c,.volslide2_dec
.volslide2_inc
    swap    a
    and     $f
    ld      b,a
    ld      a,[GBM_Vol2]
    add     b
    jr      c,:+
    add     b
    jr      nc,.volslide2_nocarry
:   ld      a,$f
    jr      .volslide2_nocarry
.volslide2_dec
    ld      b,a
    ld      a,[GBM_Vol2]
    sub     b
    jr      c,:+
    sub     b
    jr      nc,.volslide2_nocarry
:   xor     a
.volslide2_nocarry
    ld      [GBM_Vol2],a
    rra
    rra
    rra
    and     $f
    ld      b,a
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.ch3
    ld      a,b
    swap    a
    ldh     [rNR22],a
    ld      a,[GBM_Note2]
    call    GBMod_GetFreq
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.ch3
    ld      a,d
    ldh     [rNR23],a
    ld      a,e
    or      $80
    ldh     [rNR24],a
    jr      .ch3
.dosetfreq2
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.ch3
    ld      a,d
    ldh     [rNR23],a
    ld      a,e
    ldh     [rNR24],a
    jr      .ch3
.speed2
    ld      a,[GBM_SpeedChanged]
    and     a
    jr      nz,.ch3
    ld      a,[GBM_Param2]
    ld      [GBM_ModuleSpeed],a
    ld      [GBM_ModuleTimer],a
    ld      a,1
    ld      [GBM_SpeedChanged],a
    
.ch3
    ld      a,[GBM_Command2]
    cp      4
    jr      nz,.novib2
    ld      a,[GBM_Note2]
    call    GBMod_GetFreq
    ld      h,d
    ld      l,e
    ld      a,[GBM_FreqOffset2]
    add     h
    ld      h,a
    jr      nc,.continue2
    inc     l
.continue2
    ld      a,[GBM_SkipCH2]
    and     a
    jr      nz,.novib2
    ld      a,h
    ldh     [rNR23],a
    ld      a,l
    ldh     [rNR24],a
.novib2
    ld      a,[GBM_Command3]
    ld      hl,.commandTable3
    add     a
    add     l
    ld      l,a
    jr      nc,.nocarry3
    inc     h
.nocarry3
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      hl
    
.commandTable3
    dw      .arp3           ; 0xy - arp
    dw      .slideup3       ; 1xy - note slide up
    dw      .slidedown3     ; 2xy - note slide down
    dw      .ch4            ; 3xy - portamento (NYI)
    dw      .ch4            ; 4xy - vibrato (handled elsewhere)
    dw      .ch4            ; 5xy - portamento + volume slide (NYI)
    dw      .ch4            ; 6xy - vibrato + volume slide (NYI)
    dw      .ch4            ; 7xy - tremolo (doesn't apply for CH3)
    dw      .pan3           ; 8xy - panning
    dw      .ch4            ; 9xy - sample offset (won't be implemented)
    dw      .volslide3      ; Axy - volume slide
    dw      .patjump3       ; Bxy - pattern jump
    dw      .ch4            ; Cxy - set volume (won't be implemented)
    dw      .patbreak3      ; Dxy - pattern break
    dw      .ch4            ; Exy - extended commands (NYI)
    dw      .speed3         ; Fxy - set module speed
    
.arp3
    ld      a,[GBM_Param3]
    and     a
    jp      z,.ch4
    ld      a,[GBM_ArpTick3]
    inc     a
    cp      4
    jr      nz,.noresetarp3
    ld      a,1
.noresetarp3
    ld      [GBM_ArpTick3],a
    ld      a,[GBM_Param3]
    ld      b,a
    ld      a,[GBM_Note3]
    ld      c,a
    ld      a,[GBM_ArpTick3]
    dec     a
    call    GBMod_DoArp
    ld      a,[GBM_SkipCH3]
    and     a
    jp      nz,.ch4
    ld      a,d
    ldh     [rNR33],a
    ld      a,e
    ldh     [rNR34],a
    jp      .ch4
.slideup3
    ld      a,[GBM_Param3]
    ld      b,a
    ld      e,2
    call        GBMod_DoPitchSlide
    ld      a,[GBM_Note3]
    call    GBMod_GetFreq2
    jp      .dosetfreq3
.slidedown3
    ; read tick speed
    ld      a,[GBM_Param3]
    ld      b,a
    ld      e,2
    call    GBMod_DoPitchSlide
    ld      a,[GBM_Note3]
    call    GBMod_GetFreq2
    jp      .dosetfreq3
.pan3
    ld      a,[GBM_Param3]
    cp      $55
    jr      c,.panleft3
    cp      $aa
    jr      c,.pancenter3
.panright3
    ld      a,$10
    jr      :+
.pancenter3
    xor     a
    jr      :+
.panleft3
    ld      a,$01
:   rla
    rla
    ld      b,a
    ld      a,[GBM_PanFlags]
    xor     b
    ld      [GBM_PanFlags],a
    jp      .ch4
.patbreak3
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    ld      a,[GBM_Param3]
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_PatTablePos]
    inc     a
    ld      b,a
    ld      a,[GBM_PatTableSize]
    cp      b
    ld      a,b
    jr      nz,:+
    ; TODO: loop position
    xor     a
:   ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command3],a
    ld      [GBM_Param3],a
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    jp      .done
.patjump3
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_Param3]
    ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command3],a
    ld      [GBM_Param3],a
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentBank],a
    jp      .done
.volslide3
    ld      a,[GBM_ModuleSpeed]
    ld      b,a
    ld      a,[GBM_ModuleTimer]
    cp      b
    jr      z,.ch4  ; skip first tick
    ld      a,[GBM_Param3]
    cp      $10
    jr      c,.volslide3_dec
.volslide3_inc
    swap    a
    and     $f
    ld      b,a
    ld      a,[GBM_Vol3]
    add     b
    jr      nc,.volslide3_nocarry
    ld      a,$f
    jr      .volslide3_nocarry
.volslide3_dec
    ld      b,a
    ld      a,[GBM_Vol3]
    sub     b
    jr      nc,.volslide3_nocarry
    xor     a
.volslide3_nocarry
    ld      [GBM_Vol3],a
    rra
    rra
    rra
    and     $f
    ld      b,a
    ld      a,[GBM_SkipCH3]
    and     a
    jr      nz,.ch4
    ld      a,b
    ld      hl,WaveVolTable
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ldh     [rNR32],a
    ld      a,[GBM_Note3]
    call    GBMod_GetFreq
    ld      a,[GBM_SkipCH3]
    and     a
    jr      nz,.ch4
    ld      a,d
    ldh     [rNR33],a
    ld      a,e
    ldh     [rNR34],a
    jr      .ch4
.dosetfreq3
    ld      a,[GBM_SkipCH3]
    and     a
    jr      nz,.ch4
    ld      a,d
    ldh     [rNR33],a
    ld      a,e
    ldh     [rNR34],a
    jr      .ch4
.speed3 
    ld      a,[GBM_SpeedChanged]
    and     a
    jr      nz,.ch4
    ld      a,[GBM_Param3]
    ld      [GBM_ModuleSpeed],a
    ld      [GBM_ModuleTimer],a
    ld      a,1
    ld      [GBM_SpeedChanged],a

.ch4
    ld      a,[GBM_Command3]
    cp      4
    jr      nz,.novib3
    ld      a,[GBM_SkipCH3]
    and     a
    jp      nz,.novib3
    ld      a,[GBM_Note3]
    call    GBMod_GetFreq
    ld      h,d
    ld      l,e
    ld      a,[GBM_FreqOffset3]
    add     h
    ld      h,a
    jr      nc,.continue3
    inc     l
.continue3
    ld      a,h
    ldh     [rNR33],a
    ld      a,l
    ldh     [rNR34],a
.novib3 


    ld      a,[GBM_Command4]
    ld      hl,.commandTable4
    add     a
    add     l
    ld      l,a
    jr      nc,.nocarry4
    inc     h
.nocarry4
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    jp      hl
    
.commandTable4
    dw      .arp4           ; 0xy - arp
    dw      .done           ; 1xy - note slide up (doesn't apply for CH4)
    dw      .done           ; 2xy - note slide down (doesn't apply for CH4)
    dw      .done           ; 3xy - portamento (doesn't apply for CH4)
    dw      .done           ; 4xy - vibrato (doesn't apply for CH4)
    dw      .done           ; 5xy - portamento + volume slide (doesn't apply for CH4)
    dw      .done           ; 6xy - vibrato + volume slide (doesn't apply for CH4)
    dw      .done           ; 7xy - tremolo (NYI)
    dw      .pan4           ; 8xy - panning
    dw      .done           ; 9xy - sample offset (won't be implemented)
    dw      .volslide4      ; Axy - volume slide
    dw      .patjump4       ; Bxy - pattern jump
    dw      .done           ; Cxy - set volume (won't be implemented)
    dw      .patbreak4      ; Dxy - pattern break
    dw      .done           ; Exy - extended commands (NYI)
    dw      .speed4         ; Fxy - set module speed
.arp4
    ld      a,[GBM_Param4]
    and     a
    jp      z,.done
    ld      a,[GBM_ArpTick4]
    inc     a
    cp      4
    jr      nz,.noresetarp4
    ld      a,1
.noresetarp4
    ld      [GBM_ArpTick4],a
    ld      a,[GBM_Param4]
    ld      b,a
    ld      a,[GBM_Note4]
    ld      c,a
    ld      a,[GBM_ArpTick4]
    dec     a
    call        GBMod_DoArp4
    ld      hl,NoiseTable
    add     l
    ld      l,a
    jr      nc,.nocarry5
    inc     h
.nocarry5
    ld      a,[hl]
    ldh     [rNR43],a
    jp      .done
.pan4
    ld      a,[GBM_Param4]
    cp      $55
    jr      c,.panleft4
    cp      $aa
    jr      c,.pancenter4
.panright4
    ld      a,$10
    jr      :+
.pancenter4
    xor     a
    jr      :+
.panleft4
    ld      a,$01
:   rla
    rla
    rla
    ld      b,a
    ld      a,[GBM_PanFlags]
    xor     b
    ld      [GBM_PanFlags],a
    jp      .done
.patbreak4
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    ld      a,[GBM_Param4]
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_PatTablePos]
    inc     a
    ld      b,a
    ld      a,[GBM_PatTableSize]
    cp      b
    ld      a,b
    jr      nz,:+
    ; TODO: loop position
    xor     a
:   ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command4],a
    ld      [GBM_Param4],a
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    jp      .done
.patjump4
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentRow],a
    ld      a,[GBM_Param4]
    ld      [GBM_PatTablePos],a
    ld      hl,$40f0
    add     l
    ld      l,a
    jr      nc,:+
    inc     h
:   ld      a,[hl]
    ld      [GBM_CurrentPattern],a
    xor     a
    ld      [GBM_Command4],a
    ld      [GBM_Param4],a
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    xor     a
    ld      [GBM_CurrentBank],a
    jp      .done
.volslide4
    ld      a,[GBM_ModuleSpeed]
    ld      b,a
    ld      a,[GBM_ModuleTimer]
    cp      b
    jr      z,.done ; skip first tick

    ld      a,[GBM_Param4]
    cp      $10
    jr      c,.volslide4_dec
.volslide4_inc
    swap       a
    and     $f
    ld      b,a
    ld      a,[GBM_Vol4]
    add     b
    jr      c,:+
    add     b
    jr      nc,.volslide4_nocarry
:   ld      a,$f
    jr      .volslide4_nocarry
.volslide4_dec
    ld      b,a
    ld      a,[GBM_Vol4]
    sub     b
    jr      c,:+
    sub     b
    jr      nc,.volslide4_nocarry
:   xor     a
.volslide4_nocarry
    ld      [GBM_Vol4],a
    rra
    rra
    rra
    and     $f
    ld      b,a
    ld      a,[GBM_SkipCH4]
    and     a
    jr      nz,.done
    ld      a,b
    swap    a
    ldh     [rNR42],a
    ld      a,[GBM_Note4]
    call    GBMod_GetFreq
    ld      a,[GBM_SkipCH4]
    and     a
    jr      nz,.done
    or      $80
    ldh     [rNR44],a
    jr      .done   
.speed4
    ld      a,[GBM_SpeedChanged]
    and     a
    jr      nz,.done
    ld      a,[GBM_Param4]
    ld      [GBM_ModuleSpeed],a
    ld      [GBM_ModuleTimer],a
    ld      a,1
    ld      [GBM_SpeedChanged],a
    
.done
    ld      a,[GBM_PanFlags]
    ldh     [rNR51],a

    ld      a,1
    ld      [rROMB0],a
    ret
    
GBMod_DoArp:
    call    GBMod_DoArp4
    jp      GBMod_GetFreq
    ret

GBMod_DoArp4:
    and     a
    jr      z,.arp0
    dec     a
    jr      z,.arp1
    dec     a
    jr      z,.arp2
    ret     ; default case
.arp0
    xor     a
    ld      b,a
    jr      .getNote
.arp1
    ld      a,b
    swap    a
    and     $f
    ld      b,a
    jr      .getNote
.arp2
    ld      a,b
    and     $f
    ld      b,a
.getNote
    ld      a,c
    add     b
    ret

; TODO: Rewrite
; Input: e = current channel
GBMod_DoVib:
    ld      hl,GBM_Command1
    call    GBM_AddChannelID
    ld      a,[hl]
    cp      4
    ret     nz  ; return if vibrato is disabled
    ; get vibrato tick
    ld      hl,GBM_Param1
    call    GBM_AddChannelID
    ld      a,[hl]
    push    af
    swap    a
    cpl
    and     $f
    ld      b,a
    ld      hl,GBM_CmdTick1
    call    GBM_AddChannelID
    ld      a,[hl]
    and     a
    jr      z,.noexit
    pop     af
    dec     [hl]
    ret
.noexit
    ld      [hl],b
    ; get vibrato depth
    pop     af
    and     $f
    ld      d,a
    ld      hl,GBM_ArpTick1
    call    GBM_AddChannelID
    ld      a,[hl]
    xor     1
    ld      [hl],a
    and     a
    jr      nz,.noreset2
    ld      hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld      [hl],0
    ret
.noreset2
    ld      hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld      a,d
    rr      d
    add     d
    ld      [hl],a
    ret

; INPUT: e=channel ID
GBMod_DoPitchSlide:

    push    bc
    push    de
    ; don't do pitch bend on the first tick of a note
    ld      a,[GBM_ModuleSpeed]
    ld      b,a
    ld      a,[GBM_ModuleTimer]
    cp      b
    jr      nz,:+
    ld      hl,GBM_NewNote1
    call    GBM_AddChannelID
    ld      a,[hl]
    and     a
    jr      z,.done
    
:   ld      hl,GBM_Command1
    call    GBM_AddChannelID
    ld      a,[hl]
    cp      1
    jr      z,.slideup
    cp      2
    jr      nz,.done
.slidedown
    call    .getparam
    xor     a
    sub     c
    ld      c,a
    ld      a,0
    sbc     b
    ld      b,a
    jr      .setoffset
.slideup
    call    .getparam
.setoffset
    add     hl,bc
    add     hl,bc
    ld      b,h
    ld      c,l
    ld      hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld      a,c
    ld      [hl+],a
    ld      a,b
    ld      [hl],a
    call    .getparam
    jr      .done
.getparam
    ld      hl,GBM_Param1
    call    GBM_AddChannelID
    ld      a,[hl]
    ld      c,a
    ld      b,0
    ld      hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    ret
.done
    pop     de
    pop     bc
    ret
    
GBM_AddChannelID:
    ld      a,e
GBM_AddChannelID_skip:
    add     l
    ld      l,a
    ret     nc
    inc     h
    ret
    
GBM_AddChannelID16:
    ld      a,e
    add     a
    jr      GBM_AddChannelID_skip
    
GBM_ResetCommandTick:
.ch1
    ld      a,[GBM_Command1]
    cp      4
    jr      z,.ch2
    xor     a
    ld      [GBM_CmdTick1],a
.ch2
    ld      a,[GBM_Command2]
    cp      4
    jr      z,.ch3
    xor     a
    ld      [GBM_CmdTick2],a
.ch3    
    ld      a,[GBM_Command3]
    cp      4
    jr      z,.ch4
    xor     a
    ld      [GBM_CmdTick3],a
.ch4    
    xor     a
    ld      [GBM_CmdTick4],a
    ret
    
    
; input:  a = note id
;         b = channel ID
; output: de = frequency
GBMod_GetFreq:
    push    af
    push    bc
    push    hl
    ld      de,0
    ld      l,a
    ld      h,0
    jr      GBMod_DoGetFreq
GBMod_GetFreq2:
    push    af
    push    bc
    push    hl
    ld      c,a
    ld      hl,GBM_FreqOffset1
    call    GBM_AddChannelID16
    ld      a,[hl+]
    ld      d,[hl]
    ld      e,a
    ld      l,c
    ld      h,0
GBMod_DoGetFreq:
    add     hl,hl   ; x1
    add     hl,hl   ; x2
    add     hl,hl   ; x4
    push    de
    ld      d,h
    ld      e,l
    add     hl,hl   ; x8
    add     hl,hl   ; x16
    add     hl,de   ; x20
    pop     de
    ld      b,h
    ld      c,l
    ld      a,bank(FreqTable)
    ld      [rROMB0],a
    ld      hl,FreqTable
    add     hl,bc
    add     hl,de
    ld      a,[hl+]
    ld      d,a
    ld      a,[hl]
    ld      e,a
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    pop     hl
    pop     bc
    pop     af
    ret
    
GBM_ResetFreqOffset1:
    push    af
    push    hl
    xor     a
;    ld      [GBM_Command1],a
;    ld      [GBM_Param1],a
    ld      hl,GBM_FreqOffset1
    jr      GBM_DoResetFreqOffset
GBM_ResetFreqOffset2:
    push    af
    push    hl
    xor     a
;    ld      [GBM_Command2],a
;    ld      [GBM_Param2],a
    ld      hl,GBM_FreqOffset2
    jr      GBM_DoResetFreqOffset
GBM_ResetFreqOffset3:
    push    af
    push    hl
    xor     a
;    ld      [GBM_Command3],a
;    ld      [GBM_Param3],a
    ld      hl,GBM_FreqOffset3
GBM_DoResetFreqOffset:
    ld      [hl+],a
    ld      [hl],a
    pop     hl
    pop     af
    ret
    
GBMod_GetVol3:
    push    hl
    ld      hl,WaveVolTable
    add     l
    ld      l,a
    jr      nc,.nocarry
    inc     h
.nocarry
    ld      a,[hl]
    pop     hl
    ret

; INPUT: a = wave ID
GBM_LoadWave:
    and     $f
    add     a
    push    af
    ld      a,[GBM_SongID]
    inc     a
    ld      [rROMB0],a
    pop     af
    ld      hl,GBM_PulseWaves
    add     l
    ld      l,a
    jr      nc,.nocarry2
    inc     h
.nocarry2
    ld      a,[hl+]
    ld      h,[hl]
    ld      l,a
    call        GBM_CopyWave
    ld      a,[GBM_SongID]
    inc     a
    ld      b,a
    ld      a,[GBM_CurrentBank]
    add     b
    ld      [rROMB0],a
    ret
GBM_CopyWave:
    ldh     a,[rNR51]
    push    af
    and     %10111011
    ldh     [rNR51],a   ; prevent spike on GBA
    xor     a
    ldh     [rNR30],a
    ld      bc,$1030
.loop
    ld      a,[hl+]
    ld      [c],a
    inc     c
    dec     b
    jr      nz,.loop
    ld      a,%10000000
    ldh     [rNR30],a
    pop     af
    ldh     [rNR51],a
    ret

GBM_HandlePageBoundary:
    push    af
    push    bc
    ld      a,[GBM_CurrentBank]
    inc     a
    ld      [GBM_CurrentBank],a
    ld      b,a
    ld      a,[GBM_SongID]
    inc     a
    add     b
    ld      [rROMB0],a
    ld      h,$40
    pop     bc
    pop     af
    ret
    
GBM_HandlePageBoundaryBackwards:
    push    af
    push    bc
    ld      a,[GBM_CurrentBank]
    dec     a
    ld      [GBM_CurrentBank],a
    ld      b,a
    ld      a,[GBM_SongID]
    inc     a
    add     b
    ld      [rROMB0],a
    ld      a,h
    sub     $40
    ld      h,a
    pop     bc
    pop     af
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

section "GBMod - Frequency table",romx
FreqTable:
    dw       $2c, $32, $38, $3d, $43, $49, $4e, $54, $5a, $5f, $65, $6b, $70, $76, $7b, $81, $87, $8c, $92, $97 ; C-2
    dw       $9d, $a2, $a7, $ad, $b2, $b8, $bd, $c2, $c8, $cd, $d2, $d8, $dd, $e2, $e7, $ed, $f2, $f7, $fc,$102 ; C#2
    dw      $107,$10c,$111,$116,$11b,$120,$125,$12a,$12f,$134,$139,$13e,$143,$148,$14d,$152,$157,$15c,$161,$166 ; D-2
    dw      $16b,$170,$175,$179,$17e,$183,$188,$18d,$191,$196,$19b,$1a0,$1a4,$1a9,$1ae,$1b2,$1b7,$1bc,$1c0,$1c5 ; D#2
    dw      $1c9,$1ce,$1d3,$1d7,$1dc,$1e0,$1e5,$1e9,$1ee,$1f2,$1f7,$1fb,$200,$204,$208,$20d,$211,$216,$21a,$21e ; E-2
    dw      $223,$227,$22b,$230,$234,$238,$23d,$241,$245,$249,$24d,$252,$256,$25a,$25e,$262,$267,$26b,$26f,$273 ; F-2
    dw      $277,$27b,$27f,$283,$287,$28b,$28f,$293,$297,$29b,$29f,$2a3,$2a7,$2ab,$2af,$2b3,$2b7,$2bb,$2bf,$2c3 ; F#2
    dw      $2c7,$2ca,$2ce,$2d2,$2d6,$2da,$2dd,$2e1,$2e5,$2e9,$2ed,$2f0,$2f4,$2f8,$2fc,$2ff,$303,$307,$30a,$30e ; G-2
    dw      $312,$315,$319,$31c,$320,$324,$327,$32b,$32e,$332,$336,$339,$33d,$340,$344,$347,$34b,$34e,$352,$355 ; G#2
    dw      $358,$35c,$35f,$363,$366,$36a,$36d,$370,$374,$377,$37a,$37e,$381,$384,$388,$38b,$38e,$392,$395,$398 ; A-2
    dw      $39b,$39f,$3a2,$3a5,$3a8,$3ab,$3af,$3b2,$3b5,$3b8,$3bb,$3be,$3c2,$3c5,$3c8,$3cb,$3ce,$3d1,$3d4,$3d7 ; A#2
    dw      $3da,$3dd,$3e1,$3e4,$3e7,$3ea,$3ed,$3f0,$3f3,$3f6,$3f9,$3fc,$3ff,$402,$405,$407,$40a,$40d,$410,$413 ; B-2
    dw      $416,$419,$41c,$41f,$422,$424,$427,$42a,$42d,$430,$433,$435,$438,$43b,$43e,$440,$443,$446,$449,$44c ; C-3
    dw      $44e,$451,$454,$456,$459,$45c,$45f,$461,$464,$467,$469,$46c,$46e,$471,$474,$476,$479,$47c,$47e,$481 ; C#3
    dw      $483,$486,$488,$48b,$48e,$490,$493,$495,$498,$49a,$49d,$49f,$4a2,$4a4,$4a7,$4a9,$4ac,$4ae,$4b1,$4b3 ; D-3
    dw      $4b5,$4b8,$4ba,$4bd,$4bf,$4c2,$4c4,$4c6,$4c9,$4cb,$4cd,$4d0,$4d2,$4d4,$4d7,$4d9,$4db,$4de,$4e0,$4e2 ; D#3
    dw      $4e5,$4e7,$4e9,$4ec,$4ee,$4f0,$4f2,$4f5,$4f7,$4f9,$4fb,$4fe,$500,$502,$504,$506,$509,$50b,$50d,$50f ; E-3
    dw      $511,$514,$516,$518,$51a,$51c,$51e,$520,$523,$525,$527,$529,$52b,$52d,$52f,$531,$533,$535,$537,$539 ; F-3
    dw      $53b,$53e,$540,$542,$544,$546,$548,$54a,$54c,$54e,$550,$552,$554,$556,$558,$55a,$55b,$55d,$55f,$561 ; F#3
    dw      $563,$565,$567,$569,$56b,$56d,$56f,$571,$573,$574,$576,$578,$57a,$57c,$57e,$580,$581,$583,$585,$587 ; G-3
    dw      $589,$58b,$58c,$58e,$590,$592,$594,$595,$597,$599,$59b,$59d,$59e,$5a0,$5a2,$5a4,$5a5,$5a7,$5a9,$5aa ; G#3
    dw      $5ac,$5ae,$5b0,$5b1,$5b3,$5b5,$5b6,$5b8,$5ba,$5bc,$5bd,$5bf,$5c1,$5c2,$5c4,$5c5,$5c7,$5c9,$5ca,$5cc ; A-3
    dw      $5ce,$5cf,$5d1,$5d3,$5d4,$5d6,$5d7,$5d9,$5db,$5dc,$5de,$5df,$5e1,$5e2,$5e4,$5e5,$5e7,$5e9,$5ea,$5ec ; A#3
    dw      $5ed,$5ef,$5f0,$5f2,$5f3,$5f5,$5f6,$5f8,$5f9,$5fb,$5fc,$5fe,$5ff,$601,$602,$604,$605,$607,$608,$60a ; B-3
    dw      $60b,$60c,$60e,$60f,$611,$612,$614,$615,$616,$618,$619,$61b,$61c,$61d,$61f,$620,$622,$623,$624,$626 ; C-4
    dw      $627,$628,$62a,$62b,$62d,$62e,$62f,$631,$632,$633,$635,$636,$637,$639,$63a,$63b,$63c,$63e,$63f,$640 ; C#4
    dw      $642,$643,$644,$646,$647,$648,$649,$64b,$64c,$64d,$64e,$650,$651,$652,$653,$655,$656,$657,$658,$65a ; D-4
    dw      $65b,$65c,$65d,$65e,$660,$661,$662,$663,$664,$666,$667,$668,$669,$66a,$66b,$66d,$66e,$66f,$670,$671 ; D#4
    dw      $672,$674,$675,$676,$677,$678,$679,$67a,$67b,$67d,$67e,$67f,$680,$681,$682,$683,$684,$685,$687,$688 ; E-4
    dw      $689,$68a,$68b,$68c,$68d,$68e,$68f,$690,$691,$692,$693,$694,$695,$697,$698,$699,$69a,$69b,$69c,$69d ; F-4
    dw      $69e,$69f,$6a0,$6a1,$6a2,$6a3,$6a4,$6a5,$6a6,$6a7,$6a8,$6a9,$6aa,$6ab,$6ac,$6ad,$6ae,$6af,$6b0,$6b1 ; F#4
    dw      $6b2,$6b3,$6b4,$6b5,$6b5,$6b6,$6b7,$6b8,$6b9,$6ba,$6bb,$6bc,$6bd,$6be,$6bf,$6c0,$6c1,$6c2,$6c3,$6c3 ; G-4
    dw      $6c4,$6c5,$6c6,$6c7,$6c8,$6c9,$6ca,$6cb,$6cc,$6cc,$6cd,$6ce,$6cf,$6d0,$6d1,$6d2,$6d3,$6d4,$6d4,$6d5 ; G#4
    dw      $6d6,$6d7,$6d8,$6d9,$6da,$6da,$6db,$6dc,$6dd,$6de,$6df,$6df,$6e0,$6e1,$6e2,$6e3,$6e4,$6e4,$6e5,$6e6 ; A-4
    dw      $6e7,$6e8,$6e8,$6e9,$6ea,$6eb,$6ec,$6ec,$6ed,$6ee,$6ef,$6f0,$6f0,$6f1,$6f2,$6f3,$6f4,$6f4,$6f5,$6f6 ; A#4
    dw      $6f7,$6f7,$6f8,$6f9,$6fa,$6fa,$6fb,$6fc,$6fd,$6fd,$6fe,$6ff,$700,$700,$701,$702,$703,$703,$704,$705 ; B-4
    dw      $706,$706,$707,$708,$708,$709,$70a,$70b,$70b,$70c,$70d,$70d,$70e,$70f,$70f,$710,$711,$712,$712,$713 ; C-5
    dw      $714,$714,$715,$716,$716,$717,$718,$718,$719,$71a,$71a,$71b,$71c,$71c,$71d,$71e,$71e,$71f,$720,$720 ; C#5
    dw      $721,$721,$722,$723,$723,$724,$725,$725,$726,$727,$727,$728,$728,$729,$72a,$72a,$72b,$72c,$72c,$72d ; D-5
    dw      $72d,$72e,$72f,$72f,$730,$730,$731,$732,$732,$733,$733,$734,$735,$735,$736,$736,$737,$737,$738,$739 ; D#5
    dw      $739,$73a,$73a,$73b,$73b,$73c,$73d,$73d,$73e,$73e,$73f,$73f,$740,$741,$741,$742,$742,$743,$743,$744 ; E-5
    dw      $744,$745,$745,$746,$746,$747,$748,$748,$749,$749,$74a,$74a,$74b,$74b,$74c,$74c,$74d,$74d,$74e,$74e ; F-5
    dw      $74f,$74f,$750,$750,$751,$751,$752,$752,$753,$753,$754,$754,$755,$755,$756,$756,$757,$757,$758,$758 ; F#5
    dw      $759,$759,$75a,$75a,$75b,$75b,$75c,$75c,$75d,$75d,$75e,$75e,$75f,$75f,$75f,$760,$760,$761,$761,$762 ; G-5
    dw      $762,$763,$763,$764,$764,$764,$765,$765,$766,$766,$767,$767,$768,$768,$768,$769,$769,$76a,$76a,$76b ; G#5
    dw      $76b,$76b,$76c,$76c,$76d,$76d,$76e,$76e,$76e,$76f,$76f,$770,$770,$771,$771,$771,$772,$772,$773,$773 ; A-5
    dw      $773,$774,$774,$775,$775,$775,$776,$776,$777,$777,$777,$778,$778,$779,$779,$779,$77a,$77a,$77b,$77b ; A#5
    dw      $77b,$77c,$77c,$77c,$77d,$77d,$77e,$77e,$77e,$77f,$77f,$77f,$780,$780,$781,$781,$781,$782,$782,$782 ; B-5
    dw      $783,$783,$783,$784,$784,$785,$785,$785,$786,$786,$786,$787,$787,$787,$788,$788,$788,$789,$789,$789 ; C-6
    dw      $78a,$78a,$78a,$78b,$78b,$78b,$78c,$78c,$78c,$78d,$78d,$78d,$78e,$78e,$78e,$78f,$78f,$78f,$790,$790 ; C#6
    dw      $790,$791,$791,$791,$792,$792,$792,$793,$793,$793,$794,$794,$794,$795,$795,$795,$795,$796,$796,$796 ; D-6
    dw      $797,$797,$797,$798,$798,$798,$798,$799,$799,$799,$79a,$79a,$79a,$79b,$79b,$79b,$79b,$79c,$79c,$79c ; D#6
    dw      $79d,$79d,$79d,$79d,$79e,$79e,$79e,$79f,$79f,$79f,$79f,$7a0,$7a0,$7a0,$7a1,$7a1,$7a1,$7a1,$7a2,$7a2 ; E-6
    dw      $7a2,$7a2,$7a3,$7a3,$7a3,$7a4,$7a4,$7a4,$7a4,$7a5,$7a5,$7a5,$7a5,$7a6,$7a6,$7a6,$7a6,$7a7,$7a7,$7a7 ; F-6
    dw      $7a7,$7a8,$7a8,$7a8,$7a8,$7a9,$7a9,$7a9,$7a9,$7aa,$7aa,$7aa,$7aa,$7ab,$7ab,$7ab,$7ab,$7ac,$7ac,$7ac ; F#6
    dw      $7ac,$7ad,$7ad,$7ad,$7ad,$7ae,$7ae,$7ae,$7ae,$7af,$7af,$7af,$7af,$7af,$7b0,$7b0,$7b0,$7b0,$7b1,$7b1 ; G-6
    dw      $7b1,$7b1,$7b2,$7b2,$7b2,$7b2,$7b2,$7b3,$7b3,$7b3,$7b3,$7b4,$7b4,$7b4,$7b4,$7b4,$7b5,$7b5,$7b5,$7b5 ; G#6
    dw      $7b6,$7b6,$7b6,$7b6,$7b6,$7b7,$7b7,$7b7,$7b7,$7b7,$7b8,$7b8,$7b8,$7b8,$7b8,$7b9,$7b9,$7b9,$7b9,$7ba ; A-6
    dw      $7ba,$7ba,$7ba,$7ba,$7bb,$7bb,$7bb,$7bb,$7bb,$7bc,$7bc,$7bc,$7bc,$7bc,$7bc,$7bd,$7bd,$7bd,$7bd,$7bd ; A#6
    dw      $7be,$7be,$7be,$7be,$7be,$7bf,$7bf,$7bf,$7bf,$7bf,$7c0,$7c0,$7c0,$7c0,$7c0,$7c0,$7c1,$7c1,$7c1,$7c1 ; B-6
    dw      $7c1,$7c2,$7c2,$7c2,$7c2,$7c2,$7c2,$7c3,$7c3,$7c3,$7c3,$7c3,$7c4,$7c4,$7c4,$7c4,$7c4,$7c4,$7c5,$7c5 ; C-7
    dw      $7c5,$7c5,$7c5,$7c5,$7c6,$7c6,$7c6,$7c6,$7c6,$7c6,$7c7,$7c7,$7c7,$7c7,$7c7,$7c7,$7c8,$7c8,$7c8,$7c8 ; C#7
    dw      $7c8,$7c8,$7c9,$7c9,$7c9,$7c9,$7c9,$7c9,$7c9,$7ca,$7ca,$7ca,$7ca,$7ca,$7ca,$7cb,$7cb,$7cb,$7cb,$7cb ; D-7
    dw      $7cb,$7cb,$7cc,$7cc,$7cc,$7cc,$7cc,$7cc,$7cd,$7cd,$7cd,$7cd,$7cd,$7cd,$7cd,$7ce,$7ce,$7ce,$7ce,$7ce ; D#7
    dw      $7ce,$7ce,$7cf,$7cf,$7cf,$7cf,$7cf,$7cf,$7cf,$7d0,$7d0,$7d0,$7d0,$7d0,$7d0,$7d0,$7d1,$7d1,$7d1,$7d1 ; E-7
    dw      $7d1,$7d1,$7d1,$7d1,$7d2,$7d2,$7d2,$7d2,$7d2,$7d2,$7d2,$7d3,$7d3,$7d3,$7d3,$7d3,$7d3,$7d3,$7d3,$7d4 ; F-7
    dw      $7d4,$7d4,$7d4,$7d4,$7d4,$7d4,$7d4,$7d5,$7d5,$7d5,$7d5,$7d5,$7d5,$7d5,$7d5,$7d6,$7d6,$7d6,$7d6,$7d6 ; F#7
    dw      $7d6,$7d6,$7d6,$7d7,$7d7,$7d7,$7d7,$7d7,$7d7,$7d7,$7d7,$7d8,$7d8,$7d8,$7d8,$7d8,$7d8,$7d8,$7d8,$7d8 ; G-7
    dw      $7d9,$7d9,$7d9,$7d9,$7d9,$7d9,$7d9,$7d9,$7d9,$7da,$7da,$7da,$7da,$7da,$7da,$7da,$7da,$7da,$7db,$7db ; G#7
    dw      $7db,$7db,$7db,$7db,$7db,$7db,$7db,$7dc,$7dc,$7dc,$7dc,$7dc,$7dc,$7dc,$7dc,$7dc,$7dc,$7dd,$7dd,$7dd ; A-7
    dw      $7dd,$7dd,$7dd,$7dd,$7dd,$7dd,$7dd,$7de,$7de,$7de,$7de,$7de,$7de,$7de,$7de,$7de,$7de,$7df,$7df,$7df ; A#7
    dw      $7df,$7df,$7df,$7df,$7df,$7df,$7df,$7df,$7e0,$7e0,$7e0,$7e0,$7e0,$7e0,$7e0,$7e0,$7e0,$7e0,$7e1,$7e1 ; B-7
    dw      $7e1,$7e1,$7e1,$7e1,$7e1,$7e1,$7e1,$7e1,$7e1,$7e1,$7e2,$7e2,$7e2,$7e2,$7e2,$7e2,$7e2,$7e2,$7e2,$7e2 ; C-8
    dw      $7e2,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e3,$7e4,$7e4,$7e4,$7e4,$7e4,$7e4,$7e4 ; C#8
    dw      $7e4,$7e4,$7e4,$7e4,$7e4,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e5,$7e6,$7e6 ; D-8
    dw      $7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e6,$7e7,$7e7,$7e7,$7e7,$7e7,$7e7,$7e7,$7e7 ; D#8
    dw      $7e7,$7e7,$7e7,$7e7,$7e7,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8,$7e8 ; E-8
    dw      $7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7e9,$7ea,$7ea,$7ea,$7ea,$7ea ; F-8
    dw      $7ea,$7ea,$7ea,$7ea,$7ea,$7ea,$7ea,$7ea,$7ea,$7ea,$7ea,$7eb,$7eb,$7eb,$7eb,$7eb,$7eb,$7eb,$7eb,$7eb ; F#8
    dw      $7eb,$7eb,$7eb,$7eb,$7eb,$7eb,$7eb,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec,$7ec ; G-8
    dw      $7ec,$7ec,$7ec,$7ec,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed,$7ed ; G#8
    dw      $7ed,$7ed,$7ed,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee,$7ee ; A-8
    dw      $7ee,$7ee,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef,$7ef ; A#8
    dw      $7ef,$7ef,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0,$7f0 ; B-8
        
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
GBM_NewNote1:       ds  1
GBM_NewNote2:       ds  1
GBM_NewNote3:       ds  1
GBM_NewNote4:       ds  1

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

GBM_EnableTimer:    ds  1
GBM_TMA:            ds  1
GBM_TAC:            ds  1
GBM_OddTick:        ds  1
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
