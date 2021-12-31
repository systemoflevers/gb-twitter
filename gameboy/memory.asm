INCLUDE "hardware.inc"
        
SECTION "Memory", ROM0

clearOAM::
        ;; Modifies:
        ;;  hl
        ;;  a
        ld hl, $FE00

.write_loop:
        ld [hl], 0              ; Can't use hli since that needs a?
        inc hl
        ;; Only check the low address byte (l).
        ;; OAM is $FE00 - $FE9F so the high byte (h) is always $FE.
        ld a, l
        cp $A0                  ; 1 past $9F.
        jr nz, .write_loop
        ret

memcpy::
        ;; Args:
        ;;   b: number of bytes
        ;;   hl: destination
        ;;   de: source
        ;; Modifies:
        ;;   a
        xor a ; set a to 0
        cp b
        ret z

.loop
        ld a, [de]
        inc de
        ld [hli], a
        dec b
        jr nz, .loop
        ret