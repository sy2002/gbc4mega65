; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Options Menu
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; show menu: draw frame and fill it
; R8: String that uses \n to separate lines
; R9: Array of digits that define and group menu items, 0xEEEE ends the menu
;     and 0xFFFF terminates the array
; R10: Default activated elements, 0xFFFF terminates the array
; R11: Positions of horizontal lines, 0xFFFF terminates the aarray
; R12: Default cursor position/selection
OPTM_SHOW       INCRB
                MOVE    R8, R0                  ; R0: string to be printed
                MOVE    R9, R1                  ; R1: menu item groups
                MOVE    R10, R2                 ; R2: default activated elms.
                MOVE    R11, R3                 ; R3: pos of horiz. lines
                MOVE    R12, R4                 ; R4: default cursor selection

                MOVE    OPTM_CLEAR, R7          ; clear VRAM
                ASUB    @R7, 1

                MOVE    OPTM_X, R8
                MOVE    @R8, R8
                MOVE    OPTM_Y, R9
                MOVE    @R9, R9
                MOVE    OPTM_DX, R10
                MOVE    @R10, R10
                MOVE    OPTM_DY, R11
                MOVE    @R11, R11
                MOVE    OPTM_FRAME, R7          ; draw frame
                ASUB    @R7, 1
                MOVE    R0, R8
                MOVE    OPTM_PRINT, R7          ; print menu
                ASUB    @R7, 1

                MOVE    R2, R11                 ; R11 walks through R2
                MOVE    R3, R12                 ; R12 walks through R3
                MOVE    OPTM_X, R5              ; R5: current x-pos
                MOVE    @R5, R5
                ADD     1, R5
                MOVE    1, R6                   ; R6: current y-pos

_OPTM_SHOW_1    CMP     0xFFFF, @R11            ; iterate through menu
                RBRA    _OPTM_SHOW_4, Z         ; end reached
                CMP     0, @R11                 ; show select. at this point?
                RBRA    _OPTM_SHOW_2, Z         ; no
                MOVE    OPTM_SEL, R8            ; yes: print selection here
                MOVE    R5, R9
                MOVE    R6, R10
                MOVE    OPTM_PRINTXY, R7
                ASUB    @R7, 1

_OPTM_SHOW_2    ADD     1, R11
                CMP     0, @R12++               ; horiz. line here?
                RBRA    _OPTM_SHOW_3, Z         ; no
                MOVE    R6, R8
                MOVE    OPTM_DX, R9
                MOVE    @R9, R9
                MOVE    OPTM_LINE, R7
                ASUB    @R7, 1

_OPTM_SHOW_3    ADD     1, R6                   ; next y-pos
                RBRA    _OPTM_SHOW_1, 1

_OPTM_SHOW_4    
                

                DECRB
                RET
