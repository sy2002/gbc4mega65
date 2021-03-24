; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Options Menu
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; ----------------------------------------------------------------------------
; Option Menu key codes (to be returned by the function in OPTM_FP_GETKEY)
; ----------------------------------------------------------------------------

OPTM_KEY_UP     .EQU 1
OPTM_KEY_DOWN   .EQU 2
OPTM_KEY_SELECT .EQU 3
OPTM_KEY_CLOSE  .EQU 4

; ----------------------------------------------------------------------------
; Initialization record that is filled using OPTM_INIT
; ----------------------------------------------------------------------------

; Function that clears the VRAM
OPTM_FP_CLEAR   .EQU 0  

; Function that draws the frame
; x|y = R8|R9, dx|dy = R10|R11
OPTM_FP_FRAME   .EQU 1

; Print function that handles everything incl. cursor pos and \n by itself
; R8 contains the string that shall be printed
OPTM_FP_PRINT   .EQU 2

; Like print but contains target x|y coords in R9|R10
OPTM_FP_PRINTXY .EQU 3

; Draws a horizontal line/menu separator at the y-pos given in R8
OPTM_FP_LINE    .EQU 4

; Selects/unselects menu item in R8 (counting from 0 and counting also
; non-selectable menu entries such as lines)
; R9=0: unselect   R9=1: select
OPTM_FP_SELECT  .EQU 5

; Waits until one of the four Option Menu keys is pressed
; and returns the OPTM_KEY_* code in R8
OPTM_FP_GETKEY  .EQU 6

; selection character + zero terminator: 2 words in length!
OPTM_IR_SEL     .EQU 7

; amount of menu items: the length of the arrays to which OPTM_IR_GROUPS,
; OPTM_IR_DEFAULT and OPTM_IR_LINES point needs to be equal to this amount
OPTM_IR_SIZE    .EQU 9

; pointer to string containing the menu items and separating them with \n
OPTM_IR_ITEMS   .EQU 10

; array of digits that define and group menu items,
; 0xEEEE automatically closes the menu when selected by the user
; 0x8xxx denotes single-select menu items
OPTM_IR_GROUPS  .EQU 11

; CAUTION: This array needs to be located in RAM
;
; Input: array of 0s and 1s to define menu items that are activated by default
; Output: selected items after menu has been closed
OPTM_IR_INOUT   .EQU 12

; array of 0s and 1s to define horizontal separator lines
OPTM_IR_LINES   .EQU 13

; ----------------------------------------------------------------------------
; Options Menu functions
; ----------------------------------------------------------------------------

; Initialize data structures needed for the menu
; R8: pointer to initialization record
; R9:  x-coord
; R10: y-coord
; R11: width
; R12: height
OPTM_INIT       INCRB
                MOVE    OPTM_DATA, R0
                MOVE    R8, @R0
                MOVE    OPTM_X, R0
                MOVE    R9, @R0
                MOVE    OPTM_Y, R0
                MOVE    R10, @R0
                MOVE    OPTM_DX, R0
                MOVE    R11, @R0
                MOVE    OPTM_DY, R0
                MOVE    R12, @R0
                DECRB
                RET

; Show menu: Draw frame and fill it with the menu items
OPTM_SHOW       RSUB    ENTER, 1

                MOVE    OPTM_DATA, R0           ; R0: string to be printed
                MOVE    @R0, R0
                ADD     OPTM_IR_ITEMS, R0
                MOVE    @R0, R0
                MOVE    OPTM_DATA, R1           ; R1: size of menu (# items)
                MOVE    @R1, R1
                ADD     OPTM_IR_SIZE, R1
                MOVE    @R1, R1                
                MOVE    OPTM_DATA, R2           ; R2: default activated elms.
                MOVE    @R2, R2
                ADD     OPTM_IR_INOUT, R2
                MOVE    @R2, R2
                MOVE    OPTM_DATA, R3           ; R3: pos of horiz. lines
                MOVE    @R3, R3
                ADD     OPTM_IR_LINES, R3
                MOVE    @R3, R3

                MOVE    OPTM_FP_CLEAR, R7       ; clear VRAM
                RSUB    _OPTM_CALL, 1

                MOVE    OPTM_X, R8
                MOVE    @R8, R8
                MOVE    OPTM_Y, R9
                MOVE    @R9, R9
                MOVE    OPTM_DX, R10
                MOVE    @R10, R10
                MOVE    OPTM_DY, R11
                MOVE    @R11, R11
                MOVE    OPTM_FP_FRAME, R7       ; draw frame
                RSUB    _OPTM_CALL, 1
                MOVE    R0, R8
                MOVE    OPTM_FP_PRINT, R7       ; print menu
                RSUB    _OPTM_CALL, 1

                MOVE    OPTM_X, R5              ; R5: current x-pos
                MOVE    @R5, R5
                ADD     1, R5
                MOVE    1, R6                   ; R6: current y-pos

                XOR     R0, R0                  ; R0: iteration position
_OPTM_SHOW_1    CMP     R0, R1                  ; R0 < R1 (start from 0)
                RBRA    _OPTM_SHOW_RET, Z       ; end reached
                CMP     0, @R2++                ; show select. at this point?
                RBRA    _OPTM_SHOW_2, Z         ; no
                MOVE    OPTM_DATA, R8           ; yes: print selection here
                MOVE    @R8, R8
                ADD     OPTM_IR_SEL, R8
                MOVE    R5, R9
                MOVE    R6, R10
                MOVE    OPTM_FP_PRINTXY, R7
                RSUB    _OPTM_CALL, 1

_OPTM_SHOW_2    CMP     0, @R3++                ; horiz. line here?
                RBRA    _OPTM_SHOW_3, Z         ; no
                MOVE    R6, R8                  ; yes: R8: y-pos of line
                MOVE    OPTM_FP_LINE, R7
                RSUB    _OPTM_CALL, 1

_OPTM_SHOW_3    ADD     1, R6                   ; next y-pos
                ADD     1, R0                   ; next menu item
                RBRA    _OPTM_SHOW_1, 1

_OPTM_SHOW_RET  RSUB    LEAVE, 1
                RET

; Runs menu and returns results
; Input
;   R8: Default cursor position/selection
; Output
;   R8: Selected cursor position
;   R9: 0: no single-select menu point chosen
;       0x8xxx: single-select menu point chosen 
;   plus: the array where OPTM_IR_INOUT points to contains selected items
OPTM_RUN        INCRB

                MOVE    OPTM_DATA, R0           ; R0: size of data structure
                MOVE    @R0, R0
                ADD     OPTM_IR_SIZE, R0
                MOVE    @R0, R0
                MOVE    OPTM_DATA, R1           ; R1: menu item groups
                MOVE    @R1, R1
                ADD     OPTM_IR_GROUPS, R1
                MOVE    @R1, R1
                MOVE    R8, R2                  ; R2: selected item
                MOVE    R2, R3                  ; R3: old selected item

_OPTM_RUN_SEL   MOVE    OPTM_FP_SELECT, R7      ; select line
                MOVE    R2, R8                  ; R8: selected item
                MOVE    1, R9
                RSUB    _OPTM_CALL, 1

                MOVE    OPTM_FP_GETKEY, R7      ; get next keypress
                RSUB    _OPTM_CALL, 1

                CMP     OPTM_KEY_UP, R8         ; key: up?
                RBRA    _OPTM_RUN_3, !Z         ; no: check other key
_OPTM_RUN_1     CMP     0, R2                   ; yes: wrap around at top?
                RBRA    _OPTM_KU_NWA, !Z        ; no: find next menu item
                MOVE    R0, R2                  ; yes: wrap around
_OPTM_KU_NWA    SUB     1, R2                   ; one element up
                MOVE    R1, R6                  ; find next menu item: descnd.
                ADD     R2, R6
                CMP     0, @R6                  ; menu item found?
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on
                RBRA    _OPTM_RUN_1, 1          ; no: continue searching

_OPTM_RUN_2     MOVE    OPTM_FP_SELECT, R7      ; unselect old item
                MOVE    R3, R8
                XOR     R9, R9
                RSUB    _OPTM_CALL, 1
                MOVE    R2, R3                  ; remember current item as old
                RBRA    _OPTM_RUN_SEL, 1

_OPTM_RUN_3     CMP     OPTM_KEY_DOWN, R8       ; key: down?
                RBRA    _OPTM_RUN_5, !Z         ; no: check other key
_OPTM_RUN_4     CMP     R0, R2                  ; yes: wrap around at bottom?
                RBRA    _OPTM_KD_NWA, !Z        ; no: find next menu item
                MOVE    0, R2                   ; yes: wrap around
_OPTM_KD_NWA    ADD     1, R2                   ; one element down
                MOVE    R1, R6                  ; find next menu item: ascend.
                ADD     R2, R6
                CMP     0, @R6                  ; menu item found?
                RBRA    _OPTM_RUN_2, !Z         ; yes: unselect cur. and go on
                RBRA    _OPTM_RUN_4, 1          ; no: continue searching

_OPTM_RUN_5

                DECRB
                RET

; ----------------------------------------------------------------------------
; Internal helper functions
; ----------------------------------------------------------------------------                

; call function stored in initialization record
; R7: Function pointer ID (see above)
; R8..R12 input/output parameters
_OPTM_CALL      MOVE    R7, @--SP               ; save R7 for usage & restore

                ; find function pointer
                MOVE    OPTM_DATA, R7           ; local variable with ptr         
                MOVE    @R7, R7                 ; get info record ptr
                ADD     @SP, R7                 ; find correct record element
                MOVE    @R7, R7                 ; get function address
                ASUB    R7, 1                   ; call function

                MOVE    @SP++, R7               ; restore R7
                RET
