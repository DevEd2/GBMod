; ================================================================
; Macros
; ================================================================

; ================================================================
; Global macros
; ================================================================

; Wait for VRAM accessibility.
macro WaitForVRAM
    ldh     a,[rSTAT]
    and     STATF_BUSY
    jr      nz,@-4
endm

; Copy a tileset to a specified VRAM address.
; USAGE: CopyTileset [tileset],[VRAM address],[number of tiles to copy]
; "tiles" refers to any tileset.
macro CopyTileset
    ld  bc,$10*\3       ; number of tiles to copy
    ld  hl,\1           ; address of tiles to copy
    ld  de,$8000+\2     ; address to copy to
.loop
    ld  a,[hl+]
    ld  [de],a
    inc de
    dec bc
    ld  a,b
    or  c
    jr  nz,.loop
    endm
    
; Copy a 1BPP tileset to a specified VRAM address.
; USAGE: CopyTileset1BPP [tileset],[VRAM address],[number of tiles to copy]
; "tiles" refers to any tileset.
macro CopyTileset1BPP
    ld  bc,$10*\3       ; number of tiles to copy
    ld  hl,\1           ; address of tiles to copy
    ld  de,$8000+\2     ; address to copy to
.loop
    ld  a,[hl+]         ; get tile
    ld  [de],a          ; write tile
    inc de              ; increment destination address
    ld  [de],a          ; write tile again
    inc de              ; increment destination address again
    dec bc
    dec bc              ; since we're copying two tiles, we need to dec bc twice
    ld  a,b
    or  c
    jr  nz,.loop
    endm

; ================================================================
; Project-specific macros
; ================================================================

; Insert project-specific macros here.

