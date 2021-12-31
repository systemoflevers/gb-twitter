IF !DEF(ESP_INC)
ESP_INC SET 1

rESP EQU $A000
rESP_READY EQU $B000


MACRO ToEspFromR
    ld  hl, rESP
    ld [hl], \1
ENDM ; ToEspFromR

MACRO ToEspFromA
    ld [rESP], a 
ENDM ; ToEspFromA

MACRO FromEspToR
    ld hl, rESP
    ld \1, [hl]
ENDM ; FromEspToR

MACRO FromEspToA
    ld a, [rESP]
ENDM ; FromEspToA

MACRO EspReadyToA
    ld a, [rESP_READY]
ENDM ; EspReadyToA

ENDC ;ESP_INC