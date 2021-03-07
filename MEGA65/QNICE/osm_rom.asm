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

                ; initialize system
                MOVE    SD_DEVHANDLE, R8        ; invalidate device handle
                MOVE    0, @R8
                MOVE    FILEHANDLE, R8          ; ditto file handle
                MOVE    0, @R8
                MOVE    CUR_X, R8               ; cursor X = 0
                MOVE    0, @R8
                MOVE    CUR_Y, R8               ; ditto cursor Y
                MOVE    0, @R8
                RSUB    KEYB_INIT, 1            ; initialize keyboard ctrl.
                MOVE    GAME_RUNNING, R8        ; game is not runnnig
                MOVE    0, @R8
                MOVE    FB_HEAD, R8             ; no active head of file brws.
                MOVE    0, @R8
                MOVE    FB_ITEMS_COUNT, R8      ; no directory browsed so far
                MOVE    0, @R8
                MOVE    FB_ITEMS_SHOWN, R8      ; no dir. items shown so far
                MOVE    0, @R8

                ; reset gameboy, set visibility parameters and
                ; print the frame and the welcome message
                MOVE    1, R8                   ; show welcome message
                MOVE    GBC$CSR_RESET, R9       ; put machine in reset state 
                RSUB    RESETGB_WELCOME, 1

                ; Mount SD card and load original ROMs, if available.
                RSUB    CHKORMNT, 1             ; mount SD card partition #1 
                CMP     0, R9
                RBRA    MOUNT_OK, Z
                HALT                            ; TODO: replace by retry
MOUNT_OK        MOVE    FN_GBC_ROM, R8          ; full path to ROM
                MOVE    MEM_BIOS, R9            ; MMIO location of "ROM RAM"
                RSUB    LOAD_ROM, 1

                ; Print help screen
                RSUB    HELP_SCREEN, 1

                ; The file browser remembers the cursor position of all
                ; nested directories so that when we climb up the directory
                ; tree, the cursor selects the correct item on the screen.
                ; We assume to be two levels deep at the beginning. This is
                ; why we push two 0 on the stack and remove one of them, in
                ; case we revert back to the root folder.
                MOVE    0, @--SP
                MOVE    0, @--SP

                ; load sorted directory list into memory
                MOVE    SD_DEVHANDLE, R8
                MOVE    FN_START_DIR, R9        ; start path
CD_AND_READ     MOVE    HEAP, R10               ; start address of heap   
                MOVE    HEAP_SIZE, R11          ; maximum memory available
                                                ; for storing the linked list
                MOVE    FILTERROMNAMES, R12     ; do not show ROM file names
                RSUB    DIRBROWSE_READ, 1       ; read directory content
                CMP     0, R11                  ; errors?
                RBRA    BROWSE_START, Z         ; no
                CMP     1, R11                  ; error: path not found
                RBRA    ERR_PNF, Z
                CMP     2, R11                  ; max files? (only warn)
                RBRA    WRN_MAX, Z
                RBRA    ERR_UNKNOWN, 1

                ; /gbc path not found, try root instead
ERR_PNF         ADD     1, SP                   ; see comment above at @--SP
                MOVE    FN_ROOT_DIR, R9         ; try root
                MOVE    HEAP, R10
                MOVE    HEAP_SIZE, R11
                RSUB    DIRBROWSE_READ, 1
                CMP     0, R11                  
                RBRA    BROWSE_START, Z
                CMP     2, R11
                RBRA    WRN_MAX, Z
                RBRA    ERR_UNKNOWN, 1

                ; unknown error: end (TODO: we might want to retry in future)
ERR_UNKNOWN     MOVE    ERR_BROWSE_UNKN, R8 
                XOR     R9, R9               
                RBRA    FATALERROR, 1

                ; warn, that we are not showing all files
WRN_MAX         MOVE    WRN_MAXFILES, R8        ; print warning message
                RSUB    PRINTSTR, 1
_WRNMAXSPACE    RSUB    KEYB_SCAN, 1
                RSUB    KEYB_GETKEY, 1
                CMP     KEY_SPACE, R8           ; SPACE pressed?
                RBRA    _WRNMAXSPACE, !Z        ; no: wait
                RSUB    CLRINNER, 1             ; clear inner part of window

                ; ------------------------------------------------------------
                ; DIRECTORY BROWSER
                ; ------------------------------------------------------------

BROWSE_START    MOVE    R10, R0                 ; R0: dir. linked list head

                MOVE    FB_HEAD, R8             
                MOVE    @R8, R8                 ; persistent existing head?
                RBRA    BROWSE_SETUP, Z         ; no: continue
                MOVE    R8, R0                  ; yes: use it

                ; how much items are there in the current directory?
BROWSE_SETUP    MOVE    R0, R8
                RSUB    SLL$LASTNCOUNT, 1
                MOVE    R10, R1                 ; R1: amount of items in dir.
                MOVE    GBC$OSM_ROWS, R2        ; R2: max rows on screen
                SUB     2, R2                   ; (frame is 2 rows high)
                MOVE    R0, R3                  ; R3: currently visible head
                MOVE    @SP++, R4               ; R4: currently selected ..
                                                ; .. line inside window
                XOR     R5, R5                  ; R5: counts the amount of ..
                                                ; ..files that have been shown

                MOVE    FB_ITEMS_COUNT, R8      ; existing persistent # items?
                CMP     0, @R8
                RBRA    BROWSE_SETUP2, Z        ; no
                MOVE    @R8, R1                 ; yes: store ..
                MOVE    0, @R8                  ; .. and clear value / flag
BROWSE_SETUP2   MOVE    FB_ITEMS_SHOWN, R8      ; exist. pers. # shown items?
                CMP     0, @R8
                RBRA    DRAW_DIRLIST, Z         ; no
                MOVE    @R8, R5                 ; yes: store

                ; list (maximum one screen of) directory entries
DRAW_DIRLIST    RSUB    CLRINNER, 1
                MOVE    R3, R8                  ; R8: pos in LL to show list
                MOVE    R2, R9                  ; R9: amount if lines to show
                RSUB    SHOW_DIR, 1             ; print directory listing

                MOVE    FB_ITEMS_SHOWN, R8      ; do not add SHOW_DIR result..
                CMP     0, @R8                  ; ..if R5 was restored using..
                RBRA    ADD_SHOWN_ITMS, Z       ; FB_ITEMS_SHOWN and..
                MOVE    0, @R8                  ; ..clear FB_ITEMS_SHOWN
                RBRA    SELECT_LOOP, 1

ADD_SHOWN_ITMS  ADD     R10, R5                 ; R5: overall # of files shown

SELECT_LOOP     MOVE    R4, R8                  ; invert currently sel. line
                MOVE    SA_COL_STD_INV, R9
                RSUB    SELECT_LINE, 1

                ; non-blocking mechanism to read keys from the Game Boy
                ; keyboard (MEGA65 keyboard) as well as from the UART
INPUT_LOOP      RSUB    KEYB_SCAN, 1
                RSUB    KEYB_GETKEY, 1
                CMP     0, R8                   ; no key?
                RBRA    INPUT_LOOP, Z           ; then back to non-block. rd.

                CMP     KEY_CUR_UP, R8          ; cursor up: prev file
                RBRA    IL_CUR_UP, Z
                CMP     KEY_CUR_DOWN, R8        ; cursor down: next file
                RBRA    IL_CUR_DOWN, Z
                CMP     KEY_CUR_LEFT, R8        ; cursor left: previous page
                RBRA    IL_CUR_LEFT, Z                
                CMP     KEY_CUR_RIGHT, R8       ; cursor right: next page
                RBRA    IL_CUR_RIGHT, Z
                CMP     KEY_RETURN, R8          ; return key
                RBRA    IL_KEY_RETURN, Z
                CMP     KEY_RUNSTOP, R8         ; Run/Stop key
                RBRA    IL_KEY_RUNSTOP, Z
                RBRA    INPUT_LOOP, 1           ; unknown key

                ; RUN/STOP has been pressed
                ; Exit file browser, if game is running
IL_KEY_RUNSTOP  MOVE    GAME_RUNNING, R8
                MOVE    @R8, R8
                RBRA    INPUT_LOOP, Z           ; ignore if no game running
                MOVE    R4, @--SP               ; remember cursor position
                MOVE    FB_HEAD, R8             ; remember currently vis. head
                MOVE    R3, @R8
                MOVE    FB_ITEMS_COUNT, R8      ; remember # of items in dir.
                MOVE    R1, @R8
                MOVE    FB_ITEMS_SHOWN, R8      ; remember # of items shown
                MOVE    R5, @R8                
                MOVE    GBC$CSR, R8             ; continue game
                AND     GBC$CSR_UN_OSM, @R8
                AND     GBC$CSR_UN_PAUSE, @R8
                RBRA    GAME_RUNS, 1

                ; CURSOR UP has been pressed
IL_CUR_UP       CMP     R4, 0                   ; > 0?
                RBRA    IL_CUR_UP_CHK, !N       ; no: check if need to scroll
                MOVE    R4, R8                  ; yes: deselect current line
                MOVE    SA_COL_STD, R9          
                RSUB    SELECT_LINE, 1
                SUB     1, R4                   ; one line up
                RBRA    SELECT_LOOP, 1          ; select new line and continue
IL_CUR_UP_CHK   CMP     R5, R2                  ; # shown > max rows on scr.?
                RBRA    INPUT_LOOP, !N          ; no: do not scroll; ign. key
                MOVE    -1, R9                  ; R9: iterate backward
                MOVE    1, R10                  ; R10: scroll by one element
                RBRA    SCROLL, 1               ; scroll, then input loop

                ; CURSOR DOWN has been pressed: next file
IL_CUR_DOWN     MOVE    R1, R8                  ; R1: amount of items in dir..
                SUB     1, R8                   ; ..-1 as we count from zero
                CMP     R4, R8                  ; R4 = R1 (bottom reached?)
                RBRA    INPUT_LOOP, Z           ; yes: ignore key press
                MOVE    R2, R8                  ; R2: max rows on screen..
                SUB     1, R8                   ; ..-1 as we count from zero
                CMP     R4, R8                  ; R4 = R1: scrolling needed?
                RBRA    IL_SCRL_DN, Z           ; yes: scroll down
                MOVE    R4, R8                  ; no: deselect current line
                MOVE    SA_COL_STD, R9          
                RSUB    SELECT_LINE, 1
                ADD     1, R4                   ; one line down
                RBRA    SELECT_LOOP, 1          ; select new line and continue

                ; scroll down by iterating the currently visible head of the
                ; SLL by 1 step; if this is not possible: do not scroll,
                ; because we reached the end of the list
IL_SCRL_DN      CMP     R5, R1                  ; all items already shown?
                RBRA    INPUT_LOOP, Z           ; yes: ignore key press
                MOVE    1, R9                   ; R9: iterate forward
                MOVE    1, R10                  ; R10: scroll by one element
                RBRA    SCROLL, 1               ; scroll, then input loop

                ; CURSOR LEFT has been pressed: previous page
                ; check if amount of entries shown minus the amount
                ; of entries on the screen is larger than zero; if yes, then
                ; go back one page; if no then go back to the very first entry
IL_CUR_LEFT     MOVE    R5, R8                  ; R8: entries shown
                SUB     R2, R8                  ; R2: max entries on screen
                RBRA    INPUT_LOOP, N           ; if < 0 then no scroll
                CMP     R8, R2                  ; R8 > max entries on screen?
                RBRA    IL_PAGE_DEFUP, N        ; yes: scroll one page up
                MOVE    R8, R10                 ; no: move the residual up..
                RBRA    IL_PAGE_UP, !Z          ; .. if it is > 0
                RBRA    INPUT_LOOP, 1
IL_PAGE_DEFUP   MOVE    R2, R10                 ; R10: one page up
IL_PAGE_UP      MOVE    -1, R9                  ; R9: iterate backward
                RBRA    SCROLL, 1               ; scroll, then input loop

                ; CURSOR RIGHT has been pressed: next page
                ; first: check if amount of entries in the directory minus
                ; the amount of files already shown is larger than zero;
                ; if not, then we are already showing all files
                ; second: check if this difference is larger than the maximum
                ; amount of files that we can show on one screen; if yes
                ; then scroll by one screen, if no then scroll by exactly this
                ; difference
IL_CUR_RIGHT    MOVE    R1, R8                  ; R8: entries in current dir.
                SUB     R5, R8                  ; R5: # of files already shown
                RBRA    INPUT_LOOP, Z           ; no more files: ignore key
                CMP     R8, R2                  ; R8 > max rows on screen?
                RBRA    IL_PAGE_DEFDN, N        ; yes: scroll one page down
                MOVE    R8, R10                 ; R10: remaining elm. down
                RBRA    IL_PAGE_DN, 1
IL_PAGE_DEFDN   MOVE    R2, R10                 ; R10: one page down    
IL_PAGE_DN      MOVE    1, R9                   ; R9: iterate forward
                RBRA    SCROLL, 1               ; scroll, then input loop

                ; this code segment is used by all four scrolling modes:
                ; up/down and page up/page down; it is meant to called via
                ; RBRA and not via RSUB because it will return to DRAW_DIRLIST
                ; 
                ; iterates forward or backward depending on R9 being +1 or -1
                ; the iteration amount if given in R10
                ; if the element is not found, then a fatal error is raised
                ; destroys the value of R10
SCROLL          MOVE    R3, R8                  ; R8: currently visible head
                                                ; R9: iteration direction
                                                ; R10: iteration amount
                RSUB    SLL$ITERATE, 1          ; find element
                CMP     0, R11                  ; found element?
                RBRA    SCROLL_DO, !Z           ; yes: continue
                MOVE    ERR_FATAL_ITER, R8      ; no: fatal error and halt
                XOR     R9, R9
                RBRA    FATALERROR, 1                
SCROLL_DO       CMP     -1, R9                  ; negative iteration dir.?
                RBRA    SCROLL_DO2, !Z          ; no: continue
                XOR     R3, R3                  ; yes: inverse sign of R10
                SUB     R10, R3
                MOVE    R3, R10
SCROLL_DO2      MOVE    R11, R3                 ; new visible head
                ADD     R10, R5                 ; R10 more/less visible files
                SUB     R2, R5                  ; compensate for SHOW_DIR
                RBRA    DRAW_DIRLIST, 1         ; redraw directory list

                ; ENTER has been pressed: change directory or load file
                ; iterate the linked list: find the currently seleted element
IL_KEY_RETURN   MOVE    R3, R8                  ; R8: currently visible head
                MOVE    1, R9                   ; R9: iterate forward
                MOVE    R4, R10                 ; R10: iterate by R4 elements
                RSUB    SLL$ITERATE, 1          ; find element
                CMP     0, R11                  ; found element?
                RBRA    ELEMENT_FOUND, !Z       ; yes: continue
                MOVE    ERR_FATAL_ITER, R8      ; no: fatal error and halt
                XOR     R9, R9
                RBRA    FATALERROR, 1

                ; depending on if a directory of a file was selected:
                ; change directory or load cartridge; we therefore need to
                ; find the flag that contains the info "directory" or "file"
ELEMENT_FOUND   MOVE    R11, R8                 ; R11: selected SLL element
                ADD     SLL$DATA_SIZE, R8
                MOVE    @R8, R9
                MOVE    R11, R8
                ADD     SLL$OVRHD_SIZE, R8
                ADD     R9, R8
                CMP     0, @--R8                ; 0=file, 1=directory
                RBRA    LOAD, Z

                ; change directory
                MOVE    R4, R8                  ; deselect current line
                MOVE    SA_COL_STD, R9          
                RSUB    SELECT_LINE, 1                
                MOVE    STR_CD, R8              ; log directory change to UART
                SYSCALL(puts, 1)
                RSUB    CLRINNER, 1             ; clear inner part of frame
                ADD     SLL$DATA, R11
                ADD     1, R11                  ; remove < from name
                MOVE    R11, R8                 ; remove > from name
                SYSCALL(strlen, 1)
                ADD     R9, R8
                SUB     1, R8
                MOVE    0, @R8
                MOVE    R11, R8                 ; R8: clean directory name
                SYSCALL(puts, 1)                ; log it to UART
                SYSCALL(crlf, 1)
                SYSCALL(crlf, 1)
    
                MOVE    FB_HEAD, R9             ; reset head for browsing
                MOVE    0, @R9

                MOVE    FN_UPDIR, R9            ; are we going one dir. up?
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    CHANGEDIR, Z            ; yes: get crsr pos from stack            
                MOVE    R4, @--SP               ; no: remember cursor pos..
                MOVE    0, @--SP                ; ..and new dir. starts at 0

CHANGEDIR       MOVE    R8, R9                  ; use this directory
                MOVE    SD_DEVHANDLE, R8  
                RBRA    CD_AND_READ, 1          ; create new linked-list

LOAD            MOVE    GBC$CSR, R8             ; R8: GBC control & status reg
                AND     GBC$CSR_UN_PAUSE, @R8   ; it does matter, that we..
                                                ; ..unpause before unreset..
                                                ; ..otherwise the palette is..
                                                ; ..for some reason not ..
                                                ; ..correctly changed
                OR      GBC$CSR_RESET, @R8      ; put Game Boy in reset state                                                                                                

                MOVE    R4, @--SP               ; remember cursor position
                MOVE    FB_HEAD, R8             ; remember currently vis. head
                MOVE    R3, @R8
                MOVE    FB_ITEMS_COUNT, R8      ; remember # of items in dir.
                MOVE    R1, @R8
                MOVE    FB_ITEMS_SHOWN, R8      ; remember # of items shown
                MOVE    R5, @R8

                MOVE    STR_LOAD_CART, R8       ; log cartridge name to UART
                SYSCALL(puts, 1)
                ADD     SLL$DATA, R11
                MOVE    R11, R8                 ; R8: cartridge name
                SYSCALL(puts, 1)

                MOVE    MEM_CARTRIDGE_WIN, R9
                MOVE    GBC$CART_SEL, R10  
                RSUB    LOAD_CART, 1
                CMP     0, R11
                RBRA    CART_OK, Z
                HALT                            ; TODO: more graceful handling

CART_OK         MOVE    STR_LOAD_DONE, R8       ; log success to UART only
                SYSCALL(puts, 1)

                ; start Game Boy by "un-resetting"  and hide the OSM
                MOVE    GBC$CSR, R0
                AND     GBC$CSR_UN_RESET, @R0
                AND     GBC$CSR_UN_OSM, @R0
                MOVE    STR_GB_STARTED, R8      ; log gameboy start to UART
                SYSCALL(puts, 1)

                ; ------------------------------------------------------------
                ; MENUS WHILE GAME IS RUNNING
                ; ------------------------------------------------------------

GAME_RUNS       MOVE    GAME_RUNNING, R8        ; set game running flag
                MOVE    1, @R8
                RSUB    KEYB_SCAN, 1
                RSUB    KEYB_GETKEY, 1
                CMP     0, R8                   ; no key?
                RBRA    GAME_RUNS, Z            ; then back to non-block. rd.

                CMP     KEY_RUNSTOP, R8         ; Run/Stop: File browser
                RBRA    GR_RUNSTOP, Z
                CMP     KEY_HELP, R8            ; Help: Options menu
                RBRA    GR_HELP, Z
                RBRA    GAME_RUNS, 1

GR_RUNSTOP      XOR     R8, R8                  ; reset Game Boy and show OSD
                MOVE    GBC$CSR_PAUSE, R9       ; pause Game Boy
                RSUB    RESETGB_WELCOME, 1
                RBRA    BROWSE_START, 1         ; file browser

GR_HELP         SYSCALL(exit, 1)

; ----------------------------------------------------------------------------
; Strings
; ----------------------------------------------------------------------------

STR_TITLE       .ASCII_W "Game Boy Color for MEGA65\nMiSTer port done by sy2002 in 2021\n\n"

STR_ROM_FF      .ASCII_W " found. Using this ROM.\n\n"
STR_ROM_FNF     .ASCII_W " NOT FOUND!\n\nWill use built-in open source ROM instead.\n\n"

STR_CD          .ASCII_W "\nChanging directory to: "
STR_LOAD_CART   .ASCII_W "\nLoading cartridge: "
STR_FLAG_CGB    .ASCII_W "\n  CGB flag     : "
STR_FLAG_SGB    .ASCII_W "\n  SGB flag     : "
STR_FLAG_MBC    .ASCII_W "\n  MBC type     : "
STR_FLAG_ROM    .ASCII_W "\n  ROM size     : "
STR_FLAG_RAM    .ASCII_W "\n  RAM size     : "
STR_FLAG_OLDLIC .ASCII_W "\n  Old licensee : "
STR_LOAD_DONE   .ASCII_W "\nDone.\n"
STR_GB_STARTED  .ASCII_W "Game Boy started.\n"

STR_HELP        .ASCII_P "\n"
                .ASCII_P " MEGA65               Game Boy\n"
                ; 196 = horizontal line in Anikki font
                ; 32 = space, (13, 10) = \n
                .DW 32, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 13, 10                 
                .ASCII_P " Cursor keys          Joypad\n"
                .ASCII_P " Space                Start\n"
                .ASCII_P " Enter                Select\n"
                .ASCII_P " Left Shift           A\n"
                .ASCII_P " MEGA65 key           B\n"
                .ASCII_P " Help                 Options menu\n\n\n"

                .ASCII_P " File Browser\n"
                .DW 32, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 196, 196, 196, 196, 196, 196, 196,
                .DW 196, 196, 196, 196, 13, 10                 
                .ASCII_P " Run/Stop             Enter/leave file browser\n"
                .ASCII_P " Up/Down cursor key   Navigate one file up/down\n"
                .ASCII_P " Left/Right cursor    One page forward/backward\n"
                .ASCII_P " Enter                Start game/change folder\n"
                .ASCII_W "\n\n Press any of these keys to continue."

WRN_MAXFILES    .ASCII_P "Warning: This directory contains more files than\n"
                .ASCII_P "this core is able to load into memory.\n\n"
                .ASCII_P "Please split the files into multiple folders.\n\n"
                .ASCII_P "If you choose to continue by pressing SPACE,\n"
                .ASCII_P "be aware that random files will be missing.\n\n"
                .ASCII_W "Press SPACE to continue."

ERR_MNT         .ASCII_W "Error mounting device: SD Card. Error code: "
ERR_LOAD_ROM    .ASCII_W "Error loading ROM: Illegal file: File too long.\n"
ERR_LOAD_CART   .ASCII_W "  ERROR!\n"
ERR_BROWSE_UNKN .ASCII_W "SD Card: Unknown error while trying to browse.\n"
ERR_FATAL       .ASCII_W "FATAL ERROR:\n"
ERR_FATAL_STOP  .ASCII_W "Core stopped. Please reset the machine."
ERR_FATAL_ITER  .ASCII_W "Corrupt memory structure: Linked-list boundary.\n"

; ROM/BIOS file names and standard path 
; (the file names need to be in upper case)
FN_ROM_OFS      .EQU 5 ; offset to add to rom filen. to get the name w/o path
FN_DMG_ROM      .ASCII_W "/GBC/DMG_BOOT.BIN"
FN_GBC_ROM      .ASCII_W "/GBC/CGB_BIOS.BIN"
FN_START_DIR    .ASCII_W "/GBC"
FN_ROOT_DIR     .ASCII_W "/"
FN_UPDIR        .ASCII_W ".."

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
                RBRA    _LR_LOAD_LOOP, !Z       ; no: continue with next byte
                MOVE    2, R10                  ; yes: illegal/corrupt file
                MOVE    ERR_LOAD_ROM, R8
                RBRA    PRINTSTR, 1
                RBRA    _LR_FCLOSE, 1           ; end with code 2

_LR_LOAD_OK     XOR     R10, R10                ; R10 = 0: file load OK                
_LR_FCLOSE      MOVE    FILEHANDLE, R8          ; close file
                MOVE    0, @R8
_LOAD_ROM_RET   DECRB
                RET

; Check, if original ROM is available and load it.
;  R8: full path to file to be loaded
;  R9: MMIO address of "ROM RAM"
; R10: MMIO address of window selector
; R11: 0 = OK
;      1 = file not found
LOAD_CART       INCRB
                MOVE    R9, R0                  ; R0: MMIO addr. of 4k win.
                MOVE    R10, R1                 ; R1: MMIO of win. selector
                MOVE    R8, R10                 ; R9: full path to cart. file
                XOR     R11, R11                ; 0 = "/" is path separator
                MOVE    SD_DEVHANDLE, R8        ; R8: device handle
                MOVE    FILEHANDLE, R9          ; R9: file handle
                SYSCALL(f32_fopen, 1)
                CMP     0, R10                  ; file open worked?
                RBRA    _LC_FOPEN_OK, Z         ; yes: process
                MOVE    1, R11                  ; end with code 1
                RBRA    _LC_FCLOSE, 1

_LC_FOPEN_OK    MOVE    R9, R8                  ; R8: valid file handle
                MOVE    0, @R1                  ; start with 0 as win. sel.
                MOVE    R0, R3                  ; window boundary + 1
                ADD     MEM_CARTWIN_MAXLEN, R3
_LC_LOAD_LOOP1  MOVE    R0, R2                  ; R2: write pointer to 4k win.
_LC_LOAD_LOOP2  SYSCALL(f32_fread, 1)
                CMP     FAT32$EOF, R10          ; EOF?
                RBRA    _LC_LOAD_OK, Z          ; yes: close file and end  

                ; extract cartridge flags
                CMP     0, @R1
                RBRA    _LC_LOAD_STORE, !Z      ; no: skip cart. flag checks

                MOVE    GBC$CF_CGB_CHA, R5      ; CGB flag
                MOVE    STR_FLAG_CGB, R6        
                MOVE    GBC$CF_CGB, R7
                RSUB    _LC_HANDLE_CF, 1

                MOVE    GBC$CF_SGB_CHA, R5      ; SGB flag
                MOVE    STR_FLAG_SGB, R6        
                MOVE    GBC$CF_SGB, R7
                RSUB    _LC_HANDLE_CF, 1

                MOVE    GBC$CF_MBC_CHA, R5      ; MBC type
                MOVE    STR_FLAG_MBC, R6        
                MOVE    GBC$CF_MBC, R7
                RSUB    _LC_HANDLE_CF, 1

                MOVE    GBC$CF_ROM_SIZE_CHA, R5 ; ROM size
                MOVE    STR_FLAG_ROM, R6
                MOVE    GBC$CF_ROM_SIZE, R7
                RSUB    _LC_HANDLE_CF, 1

                MOVE    GBC$CF_RAM_SIZE_CHA, R5 ; ROM size
                MOVE    STR_FLAG_RAM, R6
                MOVE    GBC$CF_RAM_SIZE, R7
                RSUB    _LC_HANDLE_CF, 1

                MOVE    GBC$CF_OLDLIC_CHA, R5   ; Old licensee flag
                MOVE    STR_FLAG_OLDLIC, R6
                MOVE    GBC$CF_OLDLICENSEE, R7
                RSUB    _LC_HANDLE_CF, 1

                RBRA    _LC_LOAD_STORE, 1       ; skip the sub-routine code

                ; internal sub routine code, meant to be called via RSUB
                ; flag address is given in R5
                ; stores cartridge flag value in R9 to where R7 points to
                ; and prints the value using the string in R6
_LC_HANDLE_CF   ADD     MEM_CARTRIDGE_WIN, R5   ; adjust for MMIO
                CMP     R5, R2                  ; address = flag address?
                RBRA    _LC_HCF_RET, !Z         ; no: continue
                MOVE    R9, @R7                 ; store flag in register                
                MOVE    R8, @--SP 
                MOVE    R6, R8                  ; UART: print name of flag
                SYSCALL(puts, 1)
                MOVE    @R7, R8                 ; UART: print value of flag
                SYSCALL(puthex, 1)
                MOVE    @SP++, R8
_LC_HCF_RET     RET

                ; store byte in cartridge memory and handle the "paging"
                ; via the memory windows
_LC_LOAD_STORE  MOVE    R9, @R2++               ; store byte in cart. mem.
                CMP     R3, R2                  ; window boundary reached?
                RBRA    _LC_LOAD_LOOP2, !Z      ; no: continue with next byte
                ADD     1, @R1                  ; next cart. mem. window
                RBRA    _LC_LOAD_LOOP1, 1

_LC_LOAD_OK     XOR     R11, R11                ; end with code 0
_LC_FCLOSE      MOVE    FILEHANDLE, R8          ; close file
                MOVE    0, @R8            
                DECRB
                RET  

; While browsing directories, make sure that the users are not seeing the
; BIOS/ROM files of the Game Boy. Expects string pointer in R8 and returns 0,
; if nothing is to be filtered otherwise returns 1.
; The string in R8 is always upper case. Make sure that the ROM file names
; are always upper case.
FILTERROMNAMES  INCRB
                MOVE    R9, R0
                MOVE    R10, R1

                MOVE    FN_DMG_ROM, R9
                ADD     FN_ROM_OFS, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _FILTRN_RET1, Z

                MOVE    FN_GBC_ROM, R9
                ADD     FN_ROM_OFS, R9
                SYSCALL(strcmp, 1)
                CMP     0, R10
                RBRA    _FILTRN_RET1, Z

_FILTRN_RET0    XOR     R8, R8
                RBRA    _FILTRN_RET, 1
_FILTRN_RET1    MOVE    1, R8

_FILTRN_RET     MOVE    R0, R9
                MOVE    R1, R10
                DECRB
                RET

; ----------------------------------------------------------------------------
; Screen and Serial IO functions
; ----------------------------------------------------------------------------

; reset Game Boy, set visibility parameters, print frame and pnt welcome msg
; R8: 0=without welcome message, 1=with welcome message
; R9: target state of Game Boy
RESETGB_WELCOME INCRB
                MOVE    R8, R7

                MOVE    GBC$CSR, R0             ; R0: GBC control & status reg
                MOVE    R9, @R0                 ; set target state
                OR      GBC$CSR_OSM, @R0        ; show on-screen-menu
                RSUB    CLRSCR, 1               ; clear VRAM
                XOR     R8, R8                  ; x|y for frame = (0, 0)
                XOR     R9, R9                  
                MOVE    GBC$OSM_COLS, R10       ; full screen size
                MOVE    GBC$OSM_ROWS, R11
                RSUB    PRINTFRAME, 1           ; show frame

                CMP     1, R7                   ; R7=1: show message
                RBRA    _RESETGB_RET, !Z
                MOVE    STR_TITLE, R8           ; welcome message
                RSUB    PRINTSTR, 1

_RESETGB_RET    DECRB
                RET

; Show directory listing
; Input:
;   R8: position inside the directory linked-list from which to show it
;   R9: maximum amount of entries to show
; Output:
;  R10: amount of entries shown
SHOW_DIR        INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                INCRB

                SUB     1, R9                   ; we start counting from 0
                XOR     R0, R0                  ; R0: amount of entries shown

_SHOWDIR_L      MOVE    R8, R1                  ; R1: ptr to next LL element
                ADD     SLL$NEXT, R1
                ADD     SLL$DATA, R8            ; R8: entry name

                ; for performance reasons: do not output to UART
                ; if you need to debug: delete "SCR" in the following
                ; two function calls to use the dual-output routines
                RSUB    PRINTSTRSCR, 1          ; print dirname/filename
                RSUB    PRINTCRLFSCR, 1

                ADD     1, R0
                CMP     R0, R9                  ; shown <= maximum?
                RBRA    _SHOWDIR_RET, N         ; no: leave
_SHOWDIR_NEXT   MOVE    @R1, R8                 ; more entries available?
                RBRA    _SHOWDIR_L, !Z          ; yes: loop

_SHOWDIR_RET    MOVE    R0, R10                 ; return # of entries shown
                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                DECRB
                RET

; Print the string in R8 on the current cursor position on the screen
; and in parallel to the UART
PRINTSTR        SYSCALL(puts, 1)                ; output on serial console
                RSUB    PRINTSTRSCR, 1          ; output on screen
                RET

; Print the string in R8 on the screen only
PRINTSTRSCR     RSUB    ENTER, 1

                MOVE    R8, R0                  ; R0: string to be printed
                MOVE    CUR_X, R1               ; R1: running x-cursor
                MOVE    CUR_Y, R2               ; R2: running y-cursor
                MOVE    INNER_X, R3             ; R3: inner-left x-coord for..
                MOVE    @R3, R3                 ; ..not printing outside frame                                                

                RSUB    CALC_VRAM, 1            ; R8: VRAM addr of curs. pos.

_PS_L1          MOVE    @R0++, R4               ; read char
                CMP     0x000D, R4              ; is it a CR?
                RBRA    _PS_L2, Z               ; yes: process
                CMP     '<', R4                 ; replace < by special
                RBRA    _PS_L4, !Z
                MOVE    CHR_DIR_L, R4
                RBRA    _PS_L6, 1
_PS_L4          CMP     '>', R4                 ; replace > by special                
                RBRA    _PS_L5, !Z
                MOVE    CHR_DIR_R, R4
                RBRA    _PS_L6, 1
_PS_L5          CMP     0, R4                   ; no: end-of-string?
                RBRA    _PS_RET, Z              ; yes: leave
_PS_L6          MOVE    R4, @R8++               ; no: print char
                ADD     1, @R1                  ; x-cursor + 1
                RBRA    _PS_L1, 1               ; next char

_PS_L2          MOVE    @R0++, R5               ; next char
                CMP     0x000A, R5              ; is it a LF?
                RBRA    _PS_L3, Z               ; yes: process
                MOVE    0x000D, @R8++           ; no: print original chard
                MOVE    R5, @R8++
                RBRA    _PS_L1, 1

_PS_L3          MOVE    R3, @R1                 ; inner-left start x-coord
                ADD     1, @R2                  ; new line
                RSUB    CALC_VRAM, 1
                RBRA    _PS_L1, 1

_PS_RET         RSUB    LEAVE, 1
                RET

; Print the number in R8 in hexadecimal
; TODO: also print on MEGA65 screen for better error messages & debugging
PRINTHEX        INCRB
                SYSCALL(puthex, 1)
                DECRB
                RET

; Move the cursor to the next line: screen only
PRINTCRLFSCR    INCRB
                MOVE    R8, R0
                MOVE    _PRINTCRLF_S, R8
                RSUB    PRINTSTRSCR, 1
                MOVE    R0, R8
                DECRB
                RET

; Move the cursor to the next line: screen and UART
PRINTCRLF       INCRB
                MOVE    R8, R0
                MOVE    _PRINTCRLF_S, R8
                RSUB    PRINTSTR, 1
                MOVE    R0, R8
                DECRB
                RET

_PRINTCRLF_S    .ASCII_W "\n"                

; Calculates the VRAM address for the current cursor pos in CUR_X & CUR_Y
; R8: VRAM address
CALC_VRAM       RSUB    ENTER, 1

                MOVE    MEM_VRAM, R0            ; video ram address equals ..    
                MOVE    CUR_Y, R8               ; .. CUR_Y x GBC$OSM_COLS ..
                MOVE    @R8, R8
                MOVE    GBC$OSM_COLS, R9
                SYSCALL(mulu, 1)                ; R10 = R8 x R9
                MOVE    CUR_X, R8
                MOVE    @R8, R8
                ADD     R8, R10                 ; .. + CUR_X
                ADD     R10, R0                 ; R0 = video RAM addr

                MOVE    R0, @--SP
                RSUB    LEAVE, 1
                MOVE    @SP++, R8
                RET

; clear screen (VRAM) by filling it with 0 which is an empty char in our font
CLRSCR          INCRB
                MOVE    MEM_VRAM, R0
                MOVE    MEM_VRAM_ATTR, R1
                MOVE    2048, R2
_CLRSCR_L       MOVE    0, @R0++                ; 0 = CLR = space character
                MOVE    SA_COL_STD, @R1++       ; foreground/backgr. color
                SUB     1, R2
                RBRA    _CLRSCR_L, !Z                 
                DECRB
                RET

; clear inner part of the screen (leave the frame)
CLRINNER        INCRB
                MOVE    MEM_VRAM, R0            ; R0: VRAM
                MOVE    GBC$OSM_COLS, R1        ; R1: amount of cols to fill
                SUB     2, R1
                MOVE    GBC$OSM_ROWS, R2        ; R2: amount of lines to fill
                SUB     2, R2                
                ADD     GBC$OSM_COLS, R0        ; skip first row
                ADD     1, R0                   ; skip first col
                MOVE    R2, R5
_CLRINNER_L1    MOVE    R1, R4
_CLRINNER_L2    MOVE    0, @R0++
                SUB     1, R4
                RBRA    _CLRINNER_L2, !Z
                ADD     2, R0
                SUB     1, R5
                RBRA    _CLRINNER_L1, !Z
                MOVE    CUR_X, R0
                MOVE    1, @R0
                MOVE    CUR_Y, R0
                MOVE    1, @R0
                DECRB
                RET

; Sets the visibility registers and draws a frame
; R8/R9:   start x/y coordinates
; R10/R11: dx/dy sizes, both need to be larger than 3
PRINTFRAME      RSUB    ENTER, 1

                ; set x/y coordinates
                MOVE    GBC$OSM_XY, R0
                MOVE    R8, @R0
                AND     0xFFFD, SR              ; clear X-flag (shift in '0')
                SHL     8, @R0
                ADD     R9, @R0

                ; set dx/dy sizes
                MOVE    GBC$OSM_DXDY, R0
                MOVE    R10, @R0
                AND     0xFFFD, SR
                SHL     8, @R0
                ADD     R11, @R0

                ; calculate VRAM start position and set the cursor to the
                ; first free inner position (the cursor is not needed for
                ; the rest of this routine but afterwards)
                MOVE    CUR_X, R0
                MOVE    R8, @R0
                MOVE    CUR_Y, R1
                MOVE    R9, @R1
                RSUB    CALC_VRAM, 1
                ADD     1, @R0                  ; first free inner pos for x
                ADD     1, @R1                  ; ditto y
                MOVE    INNER_X, R2
                MOVE    @R0, @R2

                ; calculate delta to next line in VRAM
                MOVE    R10, R0                 ; R10: dx
                SUB     1, R0              
                MOVE    GBC$OSM_COLS, R1
                SUB     R0, R1                  ; R1: delta = cols - (dx - 1)

                ; draw loop for top line
                MOVE    CHR_FC_TL, @R8++        ; draw top/left corner
                MOVE    R10, R0
                SUB     2, R0                   ; net dx
                MOVE    R0, R2
_PF_DL1         MOVE    CHR_FC_SH, @R8++        ; horizontal line
                SUB     1, R2
                RBRA    _PF_DL1, !Z
                MOVE    CHR_FC_TR, @R8          ; draw top/right corner

                ; draw horizontal border
                MOVE    R11, R3
                SUB     2, R3
                MOVE    R3, R2
_PF_DL2         ADD     R1, R8                  ; next line
                MOVE    CHR_FC_SV, @R8++
                ADD     R0, R8                  ; net dx
                MOVE    CHR_FC_SV, @R8
                SUB     1, R2
                RBRA    _PF_DL2, !Z

                ; draw loop for bottom line
                ADD     R1, R8                  ; next line
                MOVE    CHR_FC_BL, @R8++        ; draw bottom/left corner
                MOVE    R0, R2
_PF_DL3         MOVE    CHR_FC_SH, @R8++        ; horizontal line
                SUB     1, R2
                RBRA    _PF_DL3, !Z
                MOVE    CHR_FC_BR, @R8          ; draw bottom/right corner                   

                RSUB    LEAVE, 1
                RET

; Change the attribute of the line in R8 to R9
; R8 is considered as "inside the window", i.e. screenrow = R8 + 1
SELECT_LINE     INCRB   
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2                 ; R10 & R11: changed by mulu
                MOVE    R11, R3
                INCRB

                MOVE    R9, R0
                ADD     1, R8                   ; calculate attrib RAM offset
                MOVE    GBC$OSM_COLS, R9
                SYSCALL(mulu, 1)
                ADD     1, R10
                MOVE    MEM_VRAM_ATTR, R8
                ADD     R10, R8
                MOVE    GBC$OSM_COLS, R9
                SUB     2, R9
_SL_FILL_LOOP   MOVE    R0, @R8++
                SUB     1, R9
                RBRA    _SL_FILL_LOOP, !Z

                DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                DECRB
                RET

; prints the error message given in R8 and the error code given in R9,
; then halts the Game Boy and exits to the QNICE Monitor, which will be
; invisble for most normal users but which might be helpful to debug
FATALERROR      MOVE    R8, R0
                MOVE    R9, R1
                RSUB    RESETGB_WELCOME, 1
                RSUB    PRINTCRLF, 1
                MOVE    ERR_FATAL, R8
                RSUB    PRINTSTR, 1
                MOVE    R0, R8
                RSUB    PRINTSTR, 1
                CMP     0, R1
                RBRA    _FATAL_END, Z
                MOVE    R1, R8
                RSUB    PRINTHEX, 1
_FATAL_END      RSUB    PRINTCRLF, 1
                MOVE    ERR_FATAL_STOP, R8
                RSUB    PRINTSTR, 1
                SYSCALL(exit, 1)

HELP_SCREEN     RSUB    ENTER, 1

                MOVE    STR_HELP, R8
                RSUB    PRINTSTRSCR, 1

_HS_IL          RSUB    KEYB_SCAN, 1
                RSUB    KEYB_GETKEY, 1
                CMP     0, R8                   ; no key?
                RBRA    _HS_IL, Z               ; then back to non-block. rd.

                RSUB    LEAVE, 1
                RET

; ----------------------------------------------------------------------------
; Misc helper functions
; ----------------------------------------------------------------------------

; Alternative to a pure INCRB that also saves R8 .. R12
ENTER           INCRB
                MOVE    R8, R0
                MOVE    R9, R1
                MOVE    R10, R2
                MOVE    R11, R3
                MOVE    R12, R4
                INCRB
                RET

; Alternative to a pure DECRB that also restores R8 .. R12
LEAVE           DECRB
                MOVE    R0, R8
                MOVE    R1, R9
                MOVE    R2, R10
                MOVE    R3, R11
                MOVE    R4, R12
                DECRB
                RET

; ----------------------------------------------------------------------------
; Variables (need to be located in RAM)
; ----------------------------------------------------------------------------

SD_DEVHANDLE   .BLOCK FAT32$DEV_STRUCT_SIZE     ; SD card device handle
FILEHANDLE     .BLOCK FAT32$FDH_STRUCT_SIZE     ; File handle
CUR_X          .BLOCK 1                         ; OSD cursor x coordinate
CUR_Y          .BLOCK 1                         ; ditto y
INNER_X        .BLOCK 1                         ; first x-coord within frame
GAME_RUNNING   .BLOCK 1                         ; 1 = game loaded and running

; file browser persistent status: currently displayed head of linked list
FB_HEAD        .BLOCK 1
FB_ITEMS_COUNT .BLOCK 1
FB_ITEMS_SHOWN .BLOCK 1

; ----------------------------------------------------------------------------
; Keyboard controller
; ----------------------------------------------------------------------------

#include "keyboard.asm"

; ----------------------------------------------------------------------------
; Directory browser including heap for storing the sorted structure
; ----------------------------------------------------------------------------

#include "dirbrowse.asm"

HEAP_SIZE      .EQU 4096        
HEAP           .BLOCK 1
