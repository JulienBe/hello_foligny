INCLUDE "hardware.inc"


SECTION "Header", ROM0[$100]
	jp EntryPoint
	ds $150 - @, 0 ; Make room for the header

EntryPoint:

WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank
    
    ; Turn LCD off
    ld a, 0
    ld [rLCDC], a

    ; Copy tile data
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
    call Memcopy
    
    ; Copy the tilemap
    ld de, Tilemap
    ld hl, $9800
    ld bc, TilemapEnd - Tilemap
    call Memcopy

	; Clean OAM
	ld a, 0
	ld b, 160
	ld hl, _OAMRAM
ClearOam:
	ld [hli], a
	dec b
	jp nz, ClearOam

	; Copy paddle
	ld de, Paddle
    ld hl, $8000
    ld bc, PaddleEnd - Paddle
	call Memcopy

	; Copy the ball
	ld de, Ball
	ld hl, $8010
	ld bc, BallEnd - Ball
	call Memcopy

	; Init paddle sprite in oam
	ld hl, _OAMRAM
	ld a, 128 + 16
	ld [hli], a
	ld a, 16 + 8
	ld [hli], a
	ld a, 0
	ld [hli], a
	ld [hli], a	
	; Init ball ball sprite
	ld a, 100 + 16
	ld [hli], a
	ld a, 100 + 8
	ld [hli], a
	ld a, 1
	ld [hli], a
	ld a, 0
	ld [hli], a	

    ; Turn LCD on
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a

	; Init palette
    ld a, %11100100
    ld [rBGP], a
    ld a, %11100100
	ld [rOBP0], a

	; Init variables
	ld a, 0
    ld [wFrameCounter], a
	ld a, 1
	ld [wBallSpeedX], a
	ld a, -1
	ld [wBallSpeedY], a

Main:
	ld a, [rLY]  		; wait until NOT vblank ???? Why do I need this ?
	cp 144				; wait until NOT vblank ????
    jp nc, Main			; wait until NOT vblank ????
WaitVBlank2:
	ld a, [rLY]
	cp 144
	jp c, WaitVBlank2

	; Move the ball
	ld a, [wBallSpeedX]
	ld b, a
	ld a, [_OAMRAM + 5]
	add a, b
	ld [_OAMRAM + 5], a

	ld a, [wBallSpeedY]
	ld b, a
	ld a, [_OAMRAM + 4]
	add a, b
	ld [_OAMRAM + 4], a
BounceOnTop:
    ; Remember to offset the OAM position!
    ; (8, 16) in OAM coordinates is (0, 0) on the screen.
    ld a, [_OAMRAM + 4]
    sub a, 16 + 1
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel ; Returns tile address in hl
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnRight
    ld a, 1
    ld [wBallSpeedY], a
BounceOnRight:
    ld a, [_OAMRAM + 4]
    sub a, 16
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8 - 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnLeft
    ld a, -1
    ld [wBallSpeedX], a
BounceOnLeft:
    ld a, [_OAMRAM + 4]
    sub a, 16
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8 + 1
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceOnBottom
    ld a, 1
    ld [wBallSpeedX], a
BounceOnBottom:
    ld a, [_OAMRAM + 4]
    sub a, 16 - 1
    ld c, a
    ld a, [_OAMRAM + 5]
    sub a, 8
    ld b, a
    call GetTileByPixel
    ld a, [hl]
    call IsWallTile
    jp nz, BounceDone
    ld a, -1
    ld [wBallSpeedY], a
BounceDone:

	; Check if the ball is a proper Y to bounce on the paddle
	ld a, [_OAMRAM]
	ld b, a
	ld a, [_OAMRAM + 4]
	cp a, b
	jp nz, PaddleBounceDone ; can only bounce at same Y
	ld a, [_OAMRAM + 5]
	ld b, a
	ld a, [_OAMRAM + 1]
	sub a, 8
	cp a, b
	jp nc, PaddleBounceDone
	add a, 8 + 16
	cp a, b
	jp c, PaddleBounceDone
	ld a, -1
	ld [wBallSpeedY], a
PaddleBounceDone:	

	ld a, [wFrameCounter]
	inc a
	ld [wFrameCounter], a

	call UpdateKeys

CheckLeft:
	ld a, [wCurKeys]
	and a, PADF_LEFT
	jp z, CheckRight
Left:				
	; Move the paddle
	ld a, [_OAMRAM + 1]
	dec a
	; if we are full left don't move
	cp a, 15
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main

CheckRight:
	ld a, [wCurKeys]
	and a, PADF_RIGHT
	jp z, Main
Right:
	ld a, [_OAMRAM + 1]
	inc a
	; if we are full right don't move
	cp a, 105
	jp z, Main
	ld [_OAMRAM + 1], a
	jp Main

; Convert a pixel position to a tilemap address
; hl = $9800 + X + Y * 32
; @param b: X
; @param c: Y
; @return hl: tile address
GetTileByPixel:
	; First, we need to divide by 8 to convert a pixel position to a tile position.
	; After this we want to multiply the Y position by 32.
	; These operations effectively cancel out so we only need to mask the Y value.
	ld a, c
	and a, %11111000
	ld l, a
	ld h, 0
	; Now we have the position * 8 in hl
	add hl, hl ; position * 16
	add hl, hl ; position * 32
	; Convert the X position to an offset.
	ld a, b
	srl a ; a / 2
	srl a ; a / 4
	srl a ; a / 8
	; Add the two offsets together.
	add a, l
	ld l, a
	adc a, h
	sub a, l
	ld h, a
	; Add the offset to the tilemap's base address, and we are done!
	ld bc, $9800
	add hl, bc
	ret

; @param a: tile ID
; @return z: set if a is a wall
IsWallTile:
	cp a, $00
	ret z
	cp a, $01
	ret z
	cp a, $02
	ret z
	cp a, $04
	ret z
	cp a, $05
	ret z
	cp a, $06
	ret z
	cp a, $07
	ret

; ANCHOR: memcpy
; Copy bytes from one area to another.
; @param de: Source
; @param hl: Destination
; @param bc: Length
Memcopy:
	ld a, [de]
	ld [hli], a
	inc de
	dec bc
	ld a, b
	or a, c
	jp nz, Memcopy
	ret
; ANCHOR_END: memcpy    

UpdateKeys:
	; Poll half the controller
	ld a, P1F_GET_BTN
	call .onenibble
	ld b, a

	; Poll the other half of the controller
	ld a, P1F_GET_DPAD
	call .onenibble
	swap a
	xor a, b 			; A = pressed buttons + direction
	ld b, a

	ld a, [wCurKeys]
	xor a, b 			; A = keys that changed state
	and a, b 			; A = keys that changed to pressed
	ld [wNewKeys], a
	ld a, b 
	ld [wCurKeys], a
	ret

.onenibble
	ldh	[rP1], a		; switch the key matrix
	call .knownret 		; burn 10 cycles
	ldh a, [rP1] 		; wait for the key matrix to settle
	ldh a, [rP1] 		; wait for the key matrix to settle
	ldh a, [rP1] 		; wait for the key matrix to settle
	or a, $F0
.knownret
	ret	

Tiles:
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322222
	dw `33322222
	dw `33322222
	dw `33322211
	dw `33322211
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222222
	dw `22222222
	dw `22222222
	dw `11111111
	dw `11111111
	dw `33333333
	dw `33333333
	dw `33333333
	dw `22222333
	dw `22222333
	dw `22222333
	dw `11222333
	dw `11222333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `33322211
	dw `22222222
	dw `20000000
	dw `20111111
	dw `20111111
	dw `20111111
	dw `20111111
	dw `22222222
	dw `33333333
	dw `22222223
	dw `00000023
	dw `11111123
	dw `11111123
	dw `11111123
	dw `11111123
	dw `22222223
	dw `33333333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `11222333
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `11001100
	dw `11111111
	dw `11111111
	dw `21212121
	dw `22222222
	dw `22322232
	dw `23232323
	dw `33333333
	; Paste your logo here:
    dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33302333
	dw `33333133
	dw `33300313
	dw `33300303
	dw `33013330
	dw `30333333
	dw `03333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `03333333
	dw `30333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333330
	dw `33333320
	dw `33333013
	dw `33330333
	dw `33100333
	dw `31001333
	dw `20001333
	dw `00000333
	dw `00000033
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33330333
	dw `33300333
	dw `33333333
	dw `33033333
	dw `33133333
	dw `33303333
	dw `33303333
	dw `33303333
	dw `33332333
	dw `33332333
	dw `33333330
	dw `33333300
	dw `33333300
	dw `33333100
	dw `33333000
	dw `33333000
	dw `33333100
	dw `33333300
	dw `00000001
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `10000333
	dw `00000033
	dw `00000003
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `33332333
	dw `33302333
	dw `32003333
	dw `00003333
	dw `00003333
	dw `00013333
	dw `00033333
	dw `00033333
	dw `33333300
	dw `33333310
	dw `33333330
	dw `33333332
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000000
	dw `30000000
	dw `33000000
	dw `33333000
	dw `33333333
	dw `00000000
	dw `00000000
	dw `00000000
	dw `00000003
	dw `00000033
	dw `00003333
	dw `02333333
	dw `33333333
	dw `00333333
	dw `03333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
	dw `33333333
TilesEnd:

Tilemap:
	db $00, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $01, $02, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $05, $06, $05, $06, $05, $06, $05, $06, $05, $06, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0A, $0B, $0C, $0D, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $0E, $0F, $10, $11, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $12, $13, $14, $15, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $08, $07, $03, $16, $17, $18, $19, $03, 0,0,0,0,0,0,0,0,0,0,0,0
	db $04, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $09, $07, $03, $03, $03, $03, $03, $03, 0,0,0,0,0,0,0,0,0,0,0,0
TilemapEnd:

Paddle:
    dw `33322110
    dw `30000000
    dw `33221100
    dw `30000000
    dw `33322110
    dw `00000000
    dw `00000000
    dw `00000000
PaddleEnd:

Ball:
    dw `00122000
    dw `01233210
    dw `12333321
    dw `23333332
    dw `23333332
    dw `12333321
    dw `01233210
    dw `00122100
BallEnd:


SECTION "Counter", WRAM0
wFrameCounter: db

SECTION "Input Variables", WRAM0
wCurKeys: db
wNewKeys: db	

SECTION "Ball Data", WRAM0
wBallSpeedX: db
wBallSpeedY: db
