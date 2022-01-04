INCLUDE "hardware.inc"
INCLUDE "esp.inc"

xCOORD EQU $C003
yCOORD EQU $C004

SECTION "Interupt VBLANK", ROM0[$40]
jp VBlankHandler

SECTION "Header", ROM0[$100]

EntryPoint:
        di
        jp Start

REPT $150 - $104
    db 0
ENDR

SECTION "Sprite Data", ROM0
Sprites:
.Sprite1
        ;; Remember that this number format hides the weirdness of tile data.
        ;; `31333332 is the same as %11111110 10111111. This is not obvious.
        dw `31333332
        dw `30303030
        dw `03030303
        dw `03030303
        dw `03030303
        dw `03030303
        dw `03030303
        dw `33333333
        
.AtSymbol
        dw `00000000
        dw `00333000
        dw `03000300
        dw `30033030
        dw `30303030
        dw `30030300
        dw `03000000
        dw `00333000
.Heart
        ;; Colour 2 is used to toggle filled/empty heart.
        dw `33333333
        dw `30030033
        dw `02202203
        dw `02222203
        dw `02222203
        dw `30222033
        dw `33020333
        dw `33303333

.ArrowR
        dw `33333333
        dw `00113333
        dw `00111333
        dw `00111133
        dw `00111113
        dw `00111133
        dw `00111333
        dw `00113333

SECTION "Game code", ROM0

Start:
.waitVBlank
        ld a, [rLY]
        cp 144 ; Check if the LCD is past VBlank
        jr c, .waitVBlank
        xor a ; ld a, 0 
        ld [rLCDC], a
        
        ld hl, $8000
        ld de, Sprites.ArrowR
        ld b, 16
        call memcpy

        call clearOAM

        ;; Load OAM data for sprite.
        ld hl, $FE00            ; OBJ space
        ld a, 151               ; y position
        ld [hli], a
        ld a, 110               ; x position
        ld [hli], a
        ld a, 0
        ld [hli], a
        ld a, 0
        ld [hli], a

        ;; Set sprite palette 0.
        ld hl, rOBP0
        ld [hl], %11100000

        ;; copy the font
        ld hl, $9000
        ld de, FontTiles
        ld bc, FontTilesEnd - FontTiles
.copyFont
        ld a, [de] ; Grab 1 byte from the source
        ld [hli], a ; Place it at the destination, incrementing hl
        inc de ; Move to next byte
        dec bc ; Decrement count
        ld a, b ; Check if count is 0, since `dec bc` doesn't update flags
        or c
        jr nz, .copyFont

        ld hl, $9400
        ld de, Sprites.AtSymbol
        ld b, 16
        call memcpy

        ;; copy connecting string
        ld hl, $98E4 ; This will print the string roughly in the center
        ld de, ConnectingString
.copyString
        ld a, [de]
        ld [hli], a
        inc de
        and a ; Check if the byte we just copied is zero
        jr nz, .copyString ; Continue if it's not

        ; place window
        ld hl, $ff4b
        ld [hl], 7
        ld hl, $ff4a
        ld [hl], 135

        ;; Add an all black tile.
        ;; This is used to fill the window with black. It's tile index 128.
        ld hl, $8800
        ld a, $FF
        ld d, 16
:
        ld [hli], a
        dec d
        jr nz, :-

        ld de, Sprites.Heart
        ld b, 16
        call memcpy

        ;; fill top two lines of window with black
        ld d, 20 ; d is the column counter
        ld e, 2  ; e is the line counter
        ld hl, $9C00
:
        ld a, 128
        ld [hli], a
        dec d
        jr nz, :-
        ld d, 20
        ;; add 12 to hl to get to the next line. The tilemap is 32 tiles wide.
        ;; HL is pointing to the 21st, adding 12 brings it to the first tile on
        ;; the next line. 
        ld bc, 12
        add hl, bc
        dec e
        jr nz, :-

        ;; Place the heart.
        ld hl, $9C0E
        ld a, 129
        ld [hli], a

        ; Set some display registers

        ; Set background and window pallet
        ld a, %11110100
        ld [rBGP], a
        
        ; Scroll to 0,0
        xor a ; ld a, 0
        ld [rSCY], a
        ld [rSCX], a

        ;; Turn on LCD with sprites off and background on.
        ld a, %11000001
        ld [rLCDC], a

        ;; Turn on interupts for vblank.
        ;; My vblank interupt handler is just RETI.
        ;; This lets me use HALT to wait for vblank.
        ld hl, rIE
        ld [hl], IEF_VBLANK
        ei

        ld hl, $98EF
        ld d, 20
        
.waitConnect
        ;; Check if the ESP is ready once a frame.
        ;; Blink the last period in the "Connecting.." string every 20 frames.
        EspReadyToA
        and 1
        jr z, .connected
        halt ; wait for vblank
        dec d
        jr nz, .waitConnect
        ld d, 20
        ld a, [hl]
        ;; $2E is the "." character in the tilemap. Doing an xor will change the
        ;; value to either 0 or $2E. The 0 tile is a blank tile. 
        xor $2E
        ld [hl], a

        jr .waitConnect

.connected
        ld hl, $98E4
        ld de, ConnectedString
.copyConnectedString
        ld a, [de]
        ld [hli], a
        inc de
        and a ; Check if the byte we just copied is zero
        jr nz, .copyConnectedString
        ;; ready is 0

        FromEspToA ; ignore the value
 :      ; loop until ready is 1
        EspReadyToA
        and 1
        jr z, :-

        ;; wait 60 frames.
        ;; This is to keep "Conected!!" on the screen long enough to be read.
        ld d, 60
:
        halt
        dec d
        jr nz, :-

        ;; Display "Loading.." and blink the last "." while waiting for ready.
        ld hl, $98E4
        ld de, LoadingString
        call HaltAndCopyString

        ld d, 20
        ld hl, $98EE
:
        EspReadyToA
        and 1
        jr z, :+  ; 0 here is ready
        halt 
        dec d
        jr nz, :-
        ld d, 20
        ld a, [hl]
        xor $2E
        ld [hl], a
        jr :-
:       ;; done waiting

        ld hl, $98E4
        ld de, Strings.Clear
        call HaltAndCopyString
        halt 

        ;; Turn off the display so that I can draw the tweet's text without
        ;; worrying about vblank.
        xor a
        ld [rLCDC], a
        ld d, 20 ; columns
        ld e, 18 ; rows
        ld hl, $9800
:
        FromEspToA

        ;; The text is 0 terminated.
        cp 0
        jp z, doneLoading
        ld [hli], a

:       ;; Wait for ready.
        EspReadyToA
        and 1
        jr nz, :- ; not ready yet
        dec d
        jr nz, :-- ; line isn't full
        ;; line is full, go to next line.
        ld bc, 12
        add hl, bc
        ld d, 20
        dec e
        jr nz, :-- ; more lines left

doneLoading:
        ;halt 
        ld a, %11100001
        ld [rLCDC], a

;9813 9820


gameloop:       
.gameloop

        ;; Read d-pad.
        ld HL, rP1
        ld a, %00100000
        ld [hl], a
        ld c, [hl]
        ld [hl], $FF
        ;; check left
        ld a, c
        and %00000010
        jr nz, .checkRight

.checkRight

        ld a, c
        and %00000001
        jr nz, .checkA

        ;; Turn the Object/sprite layer on.
        ;; This displays the arrow sprite.
        ;; Once it's visible there's no way to turn it off right now. This is a
        ;; lazy way to get very minimal UI.
        ld a, %11100011
        ld [rLCDC], a

.checkA

        ;; Read action buttons
        ld HL, rP1
        ld a, %00010000
        ld a, %11011111
        ld [hl], a
        ld c, [hl]
        ld [hl], $FF

        ;; check A
        ld a, c
        and %00000001
        jr nz, .AisNotPressed
        ;; A is pressed.
        ;; Check if already pressed
        ld hl, $C000
        ld a, [hl]
        cp 0
        jp nz, gameloop

        ;; wasn't already pressed
        ;; mark as pressed
        ld [hl], 1

        ;; do stuff

        ld a, "L"
        ToEspFromA  ; The ESP ignores this.
:
        halt 
        EspReadyToA
        and 1
        jp nz, :-

        FromEspToA
        halt 
        ld a, %11000100
        ld [rBGP], a
        jp gameloop

.AisNotPressed

        ;; mark A as not pressed first
        ld hl, $C000
        ld [hl], 0
        jp gameloop


VBlankHandler:
        reti

SECTION "Font", ROM0

        FontTiles:
        INCBIN "font.chr"
        FontTilesEnd:


SECTION "copy string function", ROM0
HaltAndCopyString:
        halt
CopyString:
        ;; copy a 0 terminated string
        ;; from de to hl
        ;; doesn't check screen size
        ld a, [de]
        ld [hli], a
        inc de
        and a
        jr nz, CopyString
        ret

SECTION "Connecting string", ROM0

ConnectingString:
        db "Connecting..", 0

SECTION "Connected string", rom0

ConnectedString:
        db "Connected!!!", 0

SECTION "strings", ROM0

LoadingString:
Strings:
        db "  Loading.. ", 0
.Twitter
        db "  Twitter!  ", 0
.Clear
        db "            ", 0
