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

                MOVE    STR_TITLE, R8           ; welcome message
                RSUB    PRINTSTR, 1

                ; Mount SD card and load original ROMs, if available.
                RSUB    CHKORMNT, 1             ; mount SD card partition #1 
                CMP     0, R9
                RBRA    MOUNT_OK, Z
                HALT                            ; TODO: replace by retry
MOUNT_OK        MOVE    FN_GBC_ROM, R8          ; full path to ROM
                MOVE    MEM_BIOS, R9            ; MMIO location of "ROM RAM"
                RSUB    LOAD_ROM, 1

                MOVE    GBC$CSR, R0             ; R0 = control & status reg.

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR1, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                ; on reset, is on continous reset

                AND     GBC$CSR_UN_RESET, @R0   ; un-reset => system runs now

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR2, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                ; pause
                OR      GBC$CSR_PAUSE, @R0      ; pause

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR3, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                ; un-pause
                AND     GBC$CSR_UN_PAUSE, @R0   ; un-pause

                MOVE    @R0, R8
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1

                MOVE    TEST_STR4, R8
                RSUB    PRINTSTR, 1
                SYSCALL(getc, 1)

                SYSCALL(exit, 1)


DEBUG_WAIT      INCRB
                MOVE    1000, R0
_WAITLOOP2      MOVE    0xFFFF, R1
_WAITLOOP1      SUB     1, R1
                RBRA    _WAITLOOP1, !Z
                SUB     1, R0
                RBRA    _WAITLOOP2, !Z
                DECRB
                RET

DEBUG_HALT      HALT                

TEST_STR1       .ASCII_W "GBC is reset and paused\n"
TEST_STR2       .ASCII_W "GBC is running\n"
TEST_STR3       .ASCII_W "GBC is paused\n"
TEST_STR4       .ASCII_W "GBC is running\n"

STR_TITLE       .ASCII_W "Game Boy Color for MEGA65 - MiSTer port done by sy2002 in 2021\n\n"

STR_ROM_FF      .ASCII_W " found. Using given ROM.\n"
STR_ROM_FNF     .ASCII_W " not found. Will use built-in open source ROM instead.\n"

FN_DMG_ROM      .ASCII_W "/gbc/dmg_boot.bin"
FN_GBC_ROM      .ASCII_W "/gbc/cgb_bios.bin"
FN_START_DIR    .ASCII_W "/gbc"

ERR_MNT         .ASCII_W "Error mounting device: SD Card. Error code: "
ERR_LOAD_ROM    .ASCII_W "Error loading ROM: Illegal file: File too long."

; ----------------------------------------------------------------------------
; SD Card / file system functions
; ----------------------------------------------------------------------------

; Check, if we have a valid device handle and if not, mount the SD Card
; as the device. For now, we are using partition 1 hardcoded. This can be
; easily changed in the following code, but then we need an explicit
; mount/unmount mechanism, which is currently done automatically.
; Returns the device handle in R8, R9 = 0 if everything is OK,
; otherwise errorcode in R9 and R8 = 0
CHKORMNT        XOR     R9, R9
                MOVE    SD_DEVHANDLE, R8
                CMP     0, @R8                  ; valid handle?
                RBRA    _CHKORMNT_RET, !Z       ; yes: leave
                MOVE    1, R9                   ; partition #1
                SYSCALL(f32_mnt_sd, 1)
                CMP     0, R9                   ; mounting worked?
                RBRA    _CHKORMNT_RET, Z        ; yes: leave
                MOVE    ERR_MNT, R8             ; print error message
                RSUB    PRINTSTR, 1
                MOVE    R9, R8                  ; print error code
                RSUB    PRINTHEX, 1
                RSUB    PRINTCRLF, 1
                MOVE    SD_DEVHANDLE, R8        ; invalidate device handle
                XOR     @R8, @R8 
                XOR     R8, R8                  ; return 0 as device handle                   
_CHKORMNT_RET   RET

; Check, if original ROM is available and load it.
;  R8: full path to file to be loaded
;  R9: MMIO address of "ROM RAM"
; R10: 0 = file found, using ROM from file
;      1 = file not found, using Open Source ROM
;      2 = load error, corrupt state, system should halt
LOAD_ROM        INCRB
                MOVE    R9, R7                  ; R7: MMIO addr. of "ROM RAM"
                RSUB    PRINTSTR, 1             ; print full file path
                MOVE    R8, R10                 ; R10: full path to file
                MOVE    SD_DEVHANDLE, R8        ; R8: device handle
                MOVE    FILEHANDLE, R9          ; R9: file handle
                XOR     R11, R11                ; 0 = "/" is path separator
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; file open worked?
                RBRA    _LR_FOPEN_OK, Z         ; yes: process
                MOVE    STR_ROM_FNF, R8         ; no: print msg and use ..
                RSUB    PRINTSTR, 1             ; .. Open Source ROM instead
                MOVE    1, R10                  ; return with code 1
                RBRA    _LOAD_ROM_RET, 1

_LR_FOPEN_OK    MOVE    STR_ROM_FF, R8
                RSUB    PRINTSTR, 1
                MOVE    R9, R8                  ; R8: valid file handle
                MOVE    R7, R0                  ; R0: MMIO BIOS "ROM RAM"
                MOVE    R0, R1                  ; R1: maximum length
                ADD     MEM_BIOS_MAXLEN, R1                

_LR_LOAD_LOOP   SYSCALL(f32_fread, 1)           ; read one byte
                CMP     FAT32$EOF, R10          ; EOF?
                RBRA    _LR_LOAD_OK, Z          ; yes: close file and end
                MOVE    R9, @R0++               ; no: store byte in "ROM RAM"
                CMP     R0, R1                  ; maximum length reached?
                RBRA    _LR_LOAD_LOOP, !Z       ; no: continue
                MOVE    2, R10                  ; yes: illegal/corrupt file
                RBRA    _LR_FCLOSE, 1           ; end with code 2

_LR_LOAD_OK     XOR     R10, R10                ; R10 = 0: file load OK                
_LR_FCLOSE      MOVE    FILEHANDLE, R8          ; close file
                MOVE    0, @R8
_LOAD_ROM_RET   DECRB
                RET

; ----------------------------------------------------------------------------
; Screen and Serial IO functions
; ----------------------------------------------------------------------------

; Print the string in R8 on the current cursor position on the screen
; and in parallel to the UART
PRINTSTR        INCRB
                SYSCALL(puts, 1)
                DECRB
                RET

; Print the number in R8 in hexadecimal
PRINTHEX        INCRB
                SYSCALL(puthex, 1)
                DECRB
                RET

; Move the cursor to the next line
PRINTCRLF       INCRB
                SYSCALL(crlf, 1)
                DECRB
                RET

; ----------------------------------------------------------------------------
; Variables (need to be located in RAM)
; ----------------------------------------------------------------------------

SD_DEVHANDLE   .BLOCK  FAT32$DEV_STRUCT_SIZE   ; SD card device handle
FILEHANDLE     .BLOCK  FAT32$FDH_STRUCT_SIZE   ; File handle

