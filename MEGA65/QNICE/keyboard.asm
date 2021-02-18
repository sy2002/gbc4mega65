; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Keyboard controller
;
; The basic idea is: A key first has to be released until it can be counted
; as pressed.
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in February 2021 and licensed under GPL v3
; ****************************************************************************

KEYB_PRESSED   .BLOCK 1
KEYB_NEWKEYS   .BLOCK 1

; call this before working with this library
KEYB_INIT       INCRB
                MOVE    KEYB_PRESSED, R0
                MOVE    0, @R0
                MOVE    KEYB_NEWKEYS, R0
                MOVE    0, @R0
                DECRB
                RET

; perform one scan iteration; meant to be called repeatedly
KEYB_SCAN       INCRB

                MOVE    GBC$KEYMATRIX, R0       ; R0: keyboard matrix
                MOVE    @R0, R0
                MOVE    KEYB_PRESSED, R1        ; R1 points to PRESSED
                MOVE    KEYB_NEWKEYS, R2        ; R2 points to NEWKEYS

                ; new keys are keys that have not been pressed since last scan
                NOT     @R1, R3
                AND     R0, R3
                OR      R3, @R2

                ; store currently pressed keys
                MOVE    R0, @R1

                DECRB
                RET

; returns new key in R8
KEYB_GETKEY     INCRB

                MOVE    1, R0                   ; R0: key scanner
                MOVE    KEYB_NEWKEYS, R1        ; R1: list of new keys

_KEYB_GK_LOOP   MOVE    @R1, R2                 ; scan at current R0 pos.
                AND     R0, R2
                RBRA    _KEYBGK_RET_R2, !Z      ; key found? return it
                AND     0xFFFD, SR              ; no: clear X-flag, shift in 0
                SHL     1, R0                   ; move "scanner"
                RBRA    _KEYB_GK_LOOP, !Z       ; loop if not yet done
                RBRA    _KEYBGK_RET_0, 1        ; return 0, if nothing found

_KEYBGK_RET_R2  MOVE    R2, R8                  ; return new key
                NOT     R2, R2
                AND     R2, @R1                 ; unmark this key as new
                RBRA    _KEYBGK_RET, 1

_KEYBGK_RET_0   MOVE    0, R8
_KEYBGK_RET     DECRB
                RET
