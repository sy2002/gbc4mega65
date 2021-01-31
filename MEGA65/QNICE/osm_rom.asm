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

                MOVE    SD_DEVHANDLE, R8        ; invalidate device handle
                MOVE    0, @R8

                MOVE    TITLE_STR, R8
                SYSCALL(puts, 1)

                ;RSUB    CHKORMNT, 1
                ;CMP     0, R9
                ;RBRA    MOUNT_OK, Z
                ;HALT                            ; TODO: replace by retry

MOUNT_OK        MOVE    GBC$CSR, R0             ; R0 = control & status reg.

                MOVE    @R0, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    TEST_STR1, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                ; on reset, is on continous reset

                AND     GBC$CSR_UN_RESET, @R0   ; un-reset => system runs now

                MOVE    @R0, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    TEST_STR2, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                ; pause
                OR      GBC$CSR_PAUSE, @R0      ; pause

                MOVE    @R0, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    TEST_STR3, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                ; un-pause
                AND     GBC$CSR_UN_PAUSE, @R0   ; un-pause

                MOVE    @R0, R8
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)

                MOVE    TEST_STR4, R8
                SYSCALL(puts, 1)
                SYSCALL(getc, 1)

                SYSCALL(exit, 1)

TEST_STR1       .ASCII_W "GBC is reset and paused\n"
TEST_STR2       .ASCII_W "GBC is running\n"
TEST_STR3       .ASCII_W "GBC is paused\n"
TEST_STR4       .ASCII_W "GBC is running\n"

TITLE_STR       .ASCII_W "Game Boy Color for MEGA65 - MiSTer port done by sy2002 in 2021\n"



DMG_ROM_FN      .ASCII_W "/gbc/dmg_boot.bin"
GBC_ROM_FN      .ASCII_W "/gbc/cgb_bios.bin"
START_DIR_FN    .ASCII_W "/gbc"

ERR_MNT         .ASCII_W "Error mounting device: SD Card. Error code: "
ERR_FNF_ROM     .ASCII_W " not found. Will use built-in open source ROM instead.\n"

; ----------------------------------------------------------------------------
; SD Card / file system functions
; ----------------------------------------------------------------------------

; Check, if we have a valid device handle and if not, mount the SD Card
; as the device. For now, we are using partition 1 hardcoded. This can be
; easily changed in the following code, but then we need an explicit
; mount/unmount mechanism, which is currently done automatically.
; Returns the device handle in R8, R9 = 0 if everything is OK,
; otherwise errorcode in R9 and R8 = 0
CHKORMNT        MOVE    SD_DEVHANDLE, R8
                CMP     0, @R8                  ; valid handle?
                RBRA    CHKORMNT_RET, !Z        ; yes: leave
                MOVE    1, R9                   ; partition #1
                SYSCALL(f32_mnt, 1)
                CMP     0, R9                   ; mounting worked?
                RBRA    CHKORMNT_RET, Z         ; yes: leave
                MOVE    ERR_MNT, R8             ; print error message
                SYSCALL(puts, 1)
                MOVE    R9, R8                  ; print error code
                SYSCALL(puthex, 1)
                SYSCALL(crlf, 1)
                MOVE    SD_DEVHANDLE, R8        ; invalidate device handle
                XOR     @R8, @R8 
                XOR     R8, R8                  ; return 0 as device handle                   
CHKORMNT_RET    RET

; ----------------------------------------------------------------------------
; Variables (need to be located in RAM)
; Returns: Always the value 3 in R8
; ----------------------------------------------------------------------------

SD_DEVHANDLE   .BLOCK  FAT32$DEV_STRUCT_SIZE   ; SD card device handle
FILEHANDLE     .BLOCK  FAT32$FDH_STRUCT_SIZE   ; File handle

