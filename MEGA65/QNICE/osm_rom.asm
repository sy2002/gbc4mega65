; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; QNICE ROM: GBC Boot-ROM loader and On-Screen-Menu
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

#include "../../QNICE/dist_kit/sysdef.asm"
#include "../../QNICE/dist_kit/monitor.def"
#include "gbc.asm"

                .ORG    0x8000                  ; start at 0x8000

                MOVE    TEST_STR1, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                ; on reset, the GBC is paused and on continous reset
                ; we need to un-pause first and then un-reset
                MOVE    GBC$CSR, R0             ; R0 = control & status reg.
                AND     GBC$CSR_UN_PAUSE, @R0   ; un-pause & reset still actv.
                AND     GBC$CSR_UN_RESET, @R0   ; un-reset => system runs now
                
                MOVE    TEST_STR2, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                ; pause
                OR      GBC$CSR_PAUSE, @R0      ; pause

                MOVE    TEST_STR3, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                ; un-pause
                AND     GBC$CSR_UN_PAUSE, @R0   ; un-pause


                MOVE    TEST_STR4, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                SYSCALL(exit, 1)

ANOTHER_LABEL   HALT                            ; execution never reaches this

TEST_STR1       .ASCII_W "GBC is reset and paused\n"
TEST_STR2       .ASCII_W "GBC is running\n"
TEST_STR3       .ASCII_W "GBC is paused\n"
TEST_STR4       .ASCII_W "GBC is running\n"

; ----------------------------------------------------------------------------
; Sample Sub-Routine
; Returns: Always the value 3 in R8
; ----------------------------------------------------------------------------

SAMPLE_SUB      INCRB                           ; switch register bank

                MOVE    1, R0                   ; messing around with R0 and
                MOVE    2, R1                   ; R1 does not matter due to
                                                ; the DECRB that comes at the
                                                ; end of this sub routine

                MOVE    3, R8                   ; return value

                DECRB                           ; restore register bank
                RET                             ; end sub routine
