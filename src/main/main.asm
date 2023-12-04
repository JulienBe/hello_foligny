INCLUDE "src/main/utils/hardware.inc"

SECTION "GameVariables", WRAM0

wLastKeys:: db
wCurKeys:: db
wNewKeys:: db
wGameState:: db

SECTION "Header", ROM0[$100]
    jp Entry
    ds $150 - @, 0 ; Make room for the header
; 
; set our default game state
; init gb-sprobj-lib 
; setup display registers
; load tile data for the font into vram    
;
Entry:
    ; shutdown audio circuit
    ld a, 0
    ld [rNR52], a
    ; set game state
    ld [wGameState], a
    
    call WaitForVBlank
    ; init gb-sprobj-lib
    call InitSpriteLib

    ; turn off display 
    ld a, 0
    ld [rLCDC], a

    ; load the text font into VRAM
    call LoadFontIntoVRAM

    ; turn on display
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON | LCDCF_OBJ16 | LCDCF_WINON | LCDCF_WIN9C00
    ld [rLCDC], a

    ; setup display registers
    ld a, %11100100
    ld [rBGP], a
    ld [rOBP0], a