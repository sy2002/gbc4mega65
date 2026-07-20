; ****************************************************************************
; Game Boy and Game Boy Color for MEGA65 (gbc4mega65) QNICE ROM
;
; Main program that is used to build m2m-rom.rom by make_rom.sh.
; The ROM is loaded by QNICE (see M2M/vhdl/QNICE/qnice.vhd).
;
; The execution starts at the label START_FIRMWARE.
;
; done by sy2002 in 2021 - 2026 and licensed under GPL v3
; ****************************************************************************

; If the define RELEASE is defined, then the ROM will be a self-contained and
; self-starting ROM that includes the Monitor (QNICE "operating system") and
; jumps to START_FIRMWARE. In this case it is assumed, that the firmware is
; located in ROM and the variables are located in RAM.
;
; If RELEASE is not defined, then it is assumed that we are in the develop and
; debug mode so that the firmware runs in RAM and can be changed/loaded using
; the standard QNICE Monitor mechanisms such as "M/L" or QTransfer.

#define RELEASE

; ----------------------------------------------------------------------------
; Firmware: M2M system
; ----------------------------------------------------------------------------

; main.asm is the mandatory, so always include it
; It jumps to START_FIRMWARE (see below) after the QNICE "operating system"
; called "Monitor" has been included and initialized
#include "../../M2M/rom/main.asm"

; Only include the Shell, if you want to use the pre-build core automation
; and user experience. If you build your own, then remove this include and
; also remove the include "shell_vars.asm" in the variables section below.
#include "../../M2M/rom/shell.asm"

; ----------------------------------------------------------------------------
; Firmware: Main Code
; ----------------------------------------------------------------------------

                ; Run the Shell: This is where you could put your own system
                ; instead of the shell
START_FIRMWARE  MOVE    LOADED_CART_KIND, R0
                MOVE    CART_KIND_NONE, @R0
                RBRA    START_SHELL, 1

; ----------------------------------------------------------------------------
; Core specific callback functions: Submenus
; ----------------------------------------------------------------------------

; SUBMENU_SUMMARY callback function:
;
; Called when displaying the main menu for every %s that is found in the
; "headline" / starting point of any submenu in config.vhd: You are able to
; change the standard semantics when it comes to summarizing the status of the
; very submenu that is meant by the "headline" / starting point.
;
; The Game Boy core uses the standard semantics for all submenus: the framework
; shows the label of the currently selected radio item of each submenu.
;
; Input:
;   R8: pointer to the string that includes the "%s"
;   R9: pointer to the menu item within the M2M$CFG_OPTM_GROUPS structure
;  R10: end-of-menu-marker: if R9 == R10: we reached end of the menu structure
; Output:
;   R8: 0, if no custom SUBMENU_SUMMARY, else:
;       string pointer to completely new headline (do not modify/re-use R8)
;   R9, R10: unchanged

SUBMENU_SUMMARY XOR     R8, R8                  ; R8 = 0 = no custom string
                RET

; ----------------------------------------------------------------------------
; Core specific callback functions: File browsing and cartridge loading
; ----------------------------------------------------------------------------

; FILTER_FILES callback function:
;
; Called by the file- and directory browser. Used to make sure that the
; browser is only showing valid files and directories.
;
; The Game Boy core shows *.gb files in both machine modes. *.gbc files are
; shown only in Color mode. Directories are always shown.
;
; Input:
;   R8: Name of the file in capital letters
;   R9: 0=file, 1=directory
;  R10: Context (CTX_* constants in sysdef.asm)
;  R11: Menu group id (see config.vhd)
; Output:
;   R8: 0=do not filter file, i.e. show file
FILTER_FILES    INCRB
                MOVE    R9, R0
                MOVE    R8, R1                  ; preserve filename pointer

                CMP     1, R9                   ; do not filter directories
                RBRA    _FFILES_RET_0, Z

                CMP     CTX_LOAD_ROM, R10       ; only filter in the
                RBRA    _FFILES_RET_0, !Z       ; cartridge load context

                MOVE    GB_FILE_EXT, R9         ; show *.gb files
                RSUB    M2M$CHK_EXT, 1          ; preserves R8/R9/R10
                RBRA    _FFILES_RET_0, C        ; extension matched: show it

                MOVE    GBC_OSM_GB_CLASSIC, R8  ; hide *.gbc in Classic mode
                RSUB    M2M$GET_SETTING, 1
                CMP     1, R9
                RBRA    _FFILES_FILTER, Z

                MOVE    R1, R8                  ; restore filename pointer
                MOVE    GBC_FILE_EXT, R9        ; show *.gbc files
                RSUB    M2M$CHK_EXT, 1
                RBRA    _FFILES_RET_0, C        ; extension matched: show it

_FFILES_FILTER  MOVE    1, R8                   ; no match: filter it
                RBRA    _FFILES_RET, 1

_FFILES_RET_0   XOR     R8, R8                  ; R8 = 0 = do not filter file

_FFILES_RET     MOVE    R0, R9
                DECRB
                RET

; PREP_LOAD_IMAGE callback function:
;
; Some images need to be parsed, for example to extract configuration data or
; to move the file read pointer to the start position of the actual data.
; Sanity checks ("is this a valid file") can also be implemented here.
;
; The Game Boy core checks the cartridge BEFORE it is loaded (the cartridge
; RAM is only 1 MB and the old firmware of gbc4mega65 V0.8 performed the
; equivalent checks while loading):
;
;   1. The file size must be at least 0x150 bytes (i.e. the file contains
;      a complete cartridge header), otherwise it is not a valid cartridge.
;   2. The file size must not exceed 1 MB (0x00100000 bytes).
;   3. A Color-only cartridge (CGB flag 0xC0 at header byte 0x0143) may
;      only be loaded while the machine is in Color mode.
;   4. The Memory Bank Controller (MBC) type (header byte 0x0147) must be
;      supported by mbc.sv: everything but MMM01 (0x0B..0x0D), MBC6 (0x20),
;      MBC7 (0x22), Pocket Camera (0xFC), Bandai TAMA5 (0xFD), HuC3 (0xFE)
;      and HuC1 (0xFF) is accepted (i.e. ROM only, MBC1, MBC2, MBC3, MBC5
;      incl. their battery/RTC variants).
;   5. The ROM size code (header byte 0x0148) must be 5 or less (max 1 MB).
;   6. The RAM size code (header byte 0x0149) must be 5 or less (max 128 KB).
;
; The header bytes are read via the file handle and afterwards the read
; pointer is moved back to the start of the file, so that the Shell streams
; the complete file into the cartridge RAM. (FAT32$FILE_SEEK of the QNICE
; version used by M2M V2.0.1 seeks relative to the start of the file.)
;
; Input:
;   R8: File handle: You are allowed to modify the read pointer of the handle
;   R9: Context (CTX_* constants in sysdef.asm)
;  R10: Context data: menu group id
; Output:
;   R8: 0=OK, error code otherwise
;   R9: image type if R8=0, otherwise 0 or optional ptr to error msg string
PREP_LOAD_IMAGE INCRB

                MOVE    R8, R0                  ; R0: file handle

                CMP     CTX_LOAD_ROM, R9        ; loading a cartridge?
                RBRA    _PLI_OK, !Z             ; no: nothing to check

                ; ------------------------------------------------------------
                ; Check 1 and 2: file size between 0x150 bytes and 1 MB
                ; ------------------------------------------------------------

                MOVE    R0, R1
                ADD     FAT32$FDH_SIZE_LO, R1
                MOVE    @R1, R1                 ; R1: file size, low word
                MOVE    R0, R2
                ADD     FAT32$FDH_SIZE_HI, R2
                MOVE    @R2, R2                 ; R2: file size, high word

                CMP     0x0010, R2              ; compare high word with 0x10
                RBRA    _PLI_MAX1MB, Z          ; equal: low word must be 0
                RBRA    _PLI_CHKMIN, N          ; 0x10 > hi: less than 1 MB
                RBRA    _PLI_TOOLARGE, 1        ; hi > 0x10: more than 1 MB

_PLI_MAX1MB     CMP     0, R1                   ; exactly 1 MB is still OK
                RBRA    _PLI_HEADER, Z
                RBRA    _PLI_TOOLARGE, 1

_PLI_CHKMIN     CMP     0, R2                   ; high word zero?
                RBRA    _PLI_HEADER, !Z         ; no: large enough
                CMP     0x0150, R1              ; 0x150 > size?
                RBRA    _PLI_NOTVALID, N        ; yes: no cartridge header

                ; ------------------------------------------------------------
                ; Check 3 through 6: cartridge header. Read the CGB flag at
                ; 0x0143 followed by the MBC type and size codes at
                ; 0x0147 through 0x0149.
                ; ------------------------------------------------------------

_PLI_HEADER     MOVE    R0, R8
                MOVE    0x0143, R9              ; seek to the CGB flag byte
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9
                RBRA    _PLI_NOTVALID, !Z

                MOVE    R0, R8                  ; read CGB compatibility flag
                SYSCALL(f32_fread, 1)
                CMP     0, R10
                RBRA    _PLI_NOTVALID, !Z
                MOVE    R9, R6                  ; R6: CGB flag

                MOVE    R0, R8
                MOVE    0x0147, R9              ; seek to the MBC type byte
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9
                RBRA    _PLI_NOTVALID, !Z

                MOVE    R0, R8                  ; read MBC type
                SYSCALL(f32_fread, 1)
                CMP     0, R10
                RBRA    _PLI_NOTVALID, !Z
                MOVE    R9, R3                  ; R3: MBC type
                MOVE    R0, R8                  ; read ROM size code
                SYSCALL(f32_fread, 1)
                CMP     0, R10
                RBRA    _PLI_NOTVALID, !Z
                MOVE    R9, R4                  ; R4: ROM size code
                MOVE    R0, R8                  ; read RAM size code
                SYSCALL(f32_fread, 1)
                CMP     0, R10
                RBRA    _PLI_NOTVALID, !Z
                MOVE    R9, R5                  ; R5: RAM size code

                ; move the read pointer back to the start of the file, so
                ; that the Shell streams the complete file afterwards
                MOVE    R0, R8
                XOR     R9, R9
                XOR     R10, R10
                SYSCALL(f32_fseek, 1)
                CMP     0, R9
                RBRA    _PLI_NOTVALID, !Z

                ; unsupported MBC types, see also mbc.sv and the identical
                ; list in the original gbc4mega65 firmware (constraints.asm)
                CMP     0x000B, R3              ; MMM01
                RBRA    _PLI_BADMBC, Z
                CMP     0x000C, R3              ; MMM01+RAM
                RBRA    _PLI_BADMBC, Z
                CMP     0x000D, R3              ; MMM01+RAM+BATTERY
                RBRA    _PLI_BADMBC, Z
                CMP     0x0020, R3              ; MBC6
                RBRA    _PLI_BADMBC, Z
                CMP     0x0022, R3              ; MBC7
                RBRA    _PLI_BADMBC, Z
                CMP     0x00FC, R3              ; Pocket Camera
                RBRA    _PLI_BADMBC, Z
                CMP     0x00FD, R3              ; Bandai TAMA5
                RBRA    _PLI_BADMBC, Z
                CMP     0x00FE, R3              ; HuC3
                RBRA    _PLI_BADMBC, Z
                CMP     0x00FF, R3              ; HuC1+RAM+BATTERY
                RBRA    _PLI_BADMBC, Z

                ; ROM size code must be 5 (= 1 MB) or less
                CMP     0x0005, R4
                RBRA    _PLI_CHKRAM, Z
                RBRA    _PLI_TOOLARGE, !N       ; code > 5: ROM too large

                ; RAM size code must be 5 (= max 128 KB in mbc.sv) or less
_PLI_CHKRAM     CMP     0x0005, R5
                RBRA    _PLI_CLASSIFY, Z
                RBRA    _PLI_BADRAM, !N         ; code > 5: RAM too large

                ; Remember the successfully validated cartridge by its
                ; authoritative header compatibility, not by its filename.
                ; A 0xC0 CGB flag means Color-only. 0x80 is dual-compatible
                ; and therefore remains valid in either machine mode.
_PLI_CLASSIFY   MOVE    R6, R1
                AND     0x00C0, R1
                CMP     0x00C0, R1
                RBRA    _PLI_CGB_ONLY, Z

                MOVE    CART_KIND_DMG_COMPAT, R1
                RBRA    _PLI_REMEMBER, 1

_PLI_CGB_ONLY   MOVE    GBC_OSM_GB_CLASSIC, R8
                RSUB    M2M$GET_SETTING, 1
                CMP     1, R9                   ; Classic mode active?
                RBRA    _PLI_WRONG_MODE, Z      ; yes: reject Color-only cart
                MOVE    CART_KIND_CGB_ONLY, R1

_PLI_REMEMBER   MOVE    LOADED_CART_KIND, R2
                MOVE    R1, @R2                 ; failed loads never overwrite it

_PLI_OK         XOR     R8, R8                  ; no errors
                XOR     R9, R9                  ; image type hardcoded to 0
                DECRB
                RET

_PLI_NOTVALID   MOVE    1, R8
                MOVE    WRN_NO_CART, R9
                DECRB
                RET

_PLI_BADMBC     MOVE    2, R8
                MOVE    WRN_UNSUPP_MBC, R9
                DECRB
                RET

_PLI_TOOLARGE   MOVE    3, R8
                MOVE    WRN_TOO_LARGE, R9
                DECRB
                RET

_PLI_BADRAM     MOVE    4, R8
                MOVE    WRN_RAM_SIZE, R9
                DECRB
                RET

_PLI_WRONG_MODE MOVE    5, R8
                MOVE    WRN_COLOR_ONLY, R9
                DECRB
                RET

; ----------------------------------------------------------------------------
; Core specific callback functions: Custom tasks
; ----------------------------------------------------------------------------

; PREP_START callback function:
;
; Called right before the core is being started. At this point, the core
; is ready to run, settings are loaded (if the core uses settings) and the
; core is still held in reset (if RESET_KEEP is on). So at this point in time,
; you can execute tasks that change the run-state of the core.
;
; The Game Boy core applies the saved HDMI Filter selection here, so that the
; user-selected filter replaces the framework boot-time default before the
; first frame reaches HDMI.
;
; Input: None
; Output:
;   R8: 0=OK, else pointer to string with error message
;   R9: 0=OK, else error code
PREP_START      INCRB
                RSUB    LOAD_HDMI_FILTER, 1
                XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; RESET_CORE helper:
;
; Pulse M2M$CSR bit 0 long enough to pass cleanly through the framework CDC
; and reset the Game Boy machine. This is the proven C64MEGA65 firmware
; pattern: the delay avoids the too-short pulse produced by a bare OR/AND
; pair. It resets only the core; the loaded cartridge remains available and
; the selected Classic/Color machine starts it again.
;
; Input:  none
; Output: none (callers clear R8/R9 themselves)
RESET_CORE      INCRB
                MOVE    M2M$CSR, R0
                OR      M2M$CSR_RESET, @R0      ; assert soft reset
                MOVE    64, R1                  ; widen pulse across the CDC
_RC_DELAY       SUB     1, R1
                RBRA    _RC_DELAY, !Z
                AND     M2M$CSR_UN_RESET, @R0   ; release soft reset
                DECRB
                RET

; OSM_SEL_POST callback function:
;
; Called each time the user selects something in the on-screen-menu (OSM),
; and while the OSM is still visible. This means, that this callback function
; is called on each press of one of the valid selection keys with the
; exception that pressing a selection key while hovering over a submenu entry
; or exit point does not call this function. All the functionality and
; semantics associated with a certain menu item is already handled by the
; framework when OSM_SELECTED is called, so you are not able to change the
; basic semantics but you are able to add core specific additional
; "intelligent" semantics and behaviors.
;
; The Game Boy core applies a newly selected HDMI Filter live. An allowed
; Classic/Color change invalidates the file-browser cache and soft-resets the
; core so the new mode starts from a clean boot while the cartridge remains
; in memory. OSM_SEL_PRE reverts an unsafe switch to Classic, in which case
; this callback deliberately skips both actions.
;
; Input:
;   R8: selected menu group (as defined in config.vhd)
;   R9: selected item within menu group
;       in case of single selected items: 0=not selected, 1=selected
;   R10: OPTM_KEY_SELECT (by default means "Return") or
;        OPTM_KEY_SELALT (by default means "Space")
; Output:
;   R8: 0=OK, else pointer to string with error message
;   R9: 0=OK, else error code
OSM_SEL_POST    INCRB

                CMP     GBC_OPTM_G_GBMODE, R8   ; Classic/Color changed?
                RBRA    _OSMSP_GBMODE, Z

                CMP     GBC_OPTM_G_HDMI_FLT, R8 ; HDMI Filter changed?
                RBRA    _OSMSP_RET, !Z
                RSUB    LOAD_HDMI_FILTER, 1      ; yes: apply it live
                RBRA    _OSMSP_RET, 1

_OSMSP_GBMODE   CMP     0, R9                   ; requested Classic?
                RBRA    _OSMSP_MODE_OK, !Z      ; no: Color is always safe
                MOVE    LOADED_CART_KIND, R0
                CMP     CART_KIND_CGB_ONLY, @R0 ; PRE reverted this request?
                RBRA    _OSMSP_RET, Z            ; yes: do not reset

_OSMSP_MODE_OK  RSUB    FB_RE_INIT, 1           ; rebuild mode-dependent list
                RSUB    RESET_CORE, 1

_OSMSP_RET      XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; OSM_SEL_PRE callback function:
;
; Identical to the OSM_SEL_POST callback function (see above) but it is being
; called before the functionality and semantics associated with a certain
; menu item has been handled by the framework.
OSM_SEL_PRE     INCRB

                CMP     GBC_OPTM_G_GBMODE, R8   ; Classic/Color selection?
                RBRA    _OSMPRE_RET, !Z
                CMP     0, R9                   ; switching to Classic?
                RBRA    _OSMPRE_RET, !Z
                MOVE    LOADED_CART_KIND, R0
                CMP     CART_KIND_CGB_ONLY, @R0 ; Color-only cart loaded?
                RBRA    _OSMPRE_RET, !Z

                ; Repaint and restore the Color item before the framework
                ; copies the menu state to the core-facing control register.
                MOVE    GBC_OSM_GB_COLOR, R8
                MOVE    1, R9
                RSUB    M2M$FORCE_MENU, 1

_OSMPRE_RET     XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; ----------------------------------------------------------------------------
; Core specific callback functions: Custom messages
; ----------------------------------------------------------------------------

; CUSTOM_MSG callback function:
;
; Called in various situations where the Shell needs to output a message
; to the end user. The situations and contexts are described in sysdef.asm
;
; Input:
;   R8: Situation (CMSG_* constants in sysdef.asm)
;   R9: Context   (CTX_* constants in sysdef.asm)
; Output:
;   R8: 0=no custom message available, otherwise pointer to string

CUSTOM_MSG      INCRB

                CMP     CMSG_BROWSENOTHING, R8  ; no valid files in folder?
                RBRA    _CMSG_RET_0, !Z
                CMP     CTX_LOAD_ROM, R9        ; while loading a cartridge?
                RBRA    _CMSG_RET_0, !Z

                MOVE    GBC_OSM_GB_CLASSIC, R8
                RSUB    M2M$GET_SETTING, 1
                CMP     1, R9
                RBRA    _CMSG_CLASSIC, Z
                MOVE    WRN_NO_GB_FILES, R8
                RBRA    _CMSG_RET, 1

_CMSG_CLASSIC   MOVE    WRN_NO_CLASSIC_FILES, R8
                RBRA    _CMSG_RET, 1

_CMSG_RET_0     XOR     R8, R8

_CMSG_RET       DECRB
                RET

; ----------------------------------------------------------------------------
; HDMI Filter dispatch
; (same mechanism as in the C64MEGA65 V6 and AExp cores)
; ----------------------------------------------------------------------------

; LOAD_HDMI_FILTER: Read the saved HDMI Filter selection from M2M$CFM_DATA
; and configure ascal accordingly. Called from PREP_START (boot) and
; OSM_SEL_POST (runtime). Eight options, single-select: exactly one of the
; GBC_OSM_HDMI_FLT_* bits is set at any time -- OPTM_G_STDSEL in config.vhd
; guarantees a default ("Lanczos") if the saved SD config file is missing
; or empty.
;
; Two execution shapes, both encoded in HDMI_FLT_TABLE rows
; (OSM_bit, ASCAL_MODE_word, H_label, V_label):
;
;   * Native modes (No Filter / Sharp Bilinear / Bicubic) -> write the
;                  matching mode word (NEAREST / SBILINEAR / BICUBIC) to
;                  M2M$ASCAL_MODE. The H/V labels are 0 sentinels: we skip
;                  the polyphase RAM write entirely and let ascal run its
;                  built-in scaler datapath.
;   * Polyphase modes (Smooth / Lanczos / Scanlines / CRT (S-Video) /
;                  CRT (Composite)) -> write POLYPHASE then push the
;                  (H_label, V_label) pair into the ascal polyphase RAM
;                  via M2M$LOAD_POLYPHASE.
;
; This routine assumes ASCAL_USAGE=1 (AUSE_CUSTOM) in config.vhd: ASCAL_INIT
; in M2M/rom/gencfg.asm always clears the M2M$CSR ascal-autosync bit first
; and only re-sets it for AUSE_AUTO, so with AUSE_CUSTOM the M2M$ASCAL_MODE
; register stays firmware-writable.
;
; Input:  None
; Output: R8 = 0, R9 = 0 on success
LOAD_HDMI_FILTER INCRB
                MOVE    HDMI_FLT_TABLE, R0
                MOVE    8, R1                   ; option count

_LHF_LOOP       MOVE    @R0++, R8               ; R8 = OSM bit for this option
                RSUB    M2M$GET_SETTING, 1
                CMP     1, R9                   ; selected?
                RBRA    _LHF_FOUND, Z           ; yes -> apply this row
                ADD     3, R0                   ; no -> skip MODE, H, V
                SUB     1, R1
                RBRA    _LHF_LOOP, !Z

                ; Defensive fallback: no bit set. Force the Lanczos preset
                ; (polyphase mode + Lanczos2_12 on both axes), matching the
                ; config.vhd OPTM_G_STDSEL default.
                MOVE    M2M$ASCAL_MODE, R2
                MOVE    M2M$ASCAL_POLYPHASE, @R2
                MOVE    LANCZOS2_12,    R8
                MOVE    LANCZOS2_12,    R9
                RSUB    M2M$LOAD_POLYPHASE, 1
                RBRA    _LHF_RET, 1

_LHF_FOUND      MOVE    @R0++, R3               ; R3 = ASCAL_MODE word
                MOVE    M2M$ASCAL_MODE, R2
                MOVE    R3, @R2                 ; write mode register
                MOVE    @R0++, R8               ; R8 = H label (0 = sentinel)
                MOVE    @R0,   R9               ; R9 = V label (0 = sentinel)
                CMP     0, R8                   ; native-mode sentinel?
                RBRA    _LHF_RET, Z             ; yes -> done, no RAM write
                RSUB    M2M$LOAD_POLYPHASE, 1

_LHF_RET        XOR     R8, R8
                XOR     R9, R9
                DECRB
                RET

; Filter table: (OSM_bit, ASCAL_MODE_word, H_label, V_label) per option, in
; OPTM_ITEMS display order. The first three rows use ascal native modes
; (NEAREST / SBILINEAR / BICUBIC); their H and V are 0 sentinels so the
; dispatcher skips the polyphase RAM write for them. The remaining five
; rows all select polyphase (mode 100) and provide real coefficient table
; labels.
;
; See CORE/m2m-rom/video_filters/README.md for per-blob notes and
; CORE/vhdl/config.vhd for the OPTM_ITEMS / OPTM_GROUPS structure.
HDMI_FLT_TABLE  .DW GBC_OSM_HDMI_FLT_NO_FILTER,     M2M$ASCAL_NEAREST,   0,                   0
                .DW GBC_OSM_HDMI_FLT_SHARP,         M2M$ASCAL_SBILINEAR, 0,                   0
                .DW GBC_OSM_HDMI_FLT_BICUBIC,       M2M$ASCAL_BICUBIC,   0,                   0
                .DW GBC_OSM_HDMI_FLT_SMOOTH,        M2M$ASCAL_POLYPHASE, GS_SHARPNESS_050,    GS_SHARPNESS_050
                .DW GBC_OSM_HDMI_FLT_LANCZOS,       M2M$ASCAL_POLYPHASE, LANCZOS2_12,         LANCZOS2_12
                .DW GBC_OSM_HDMI_FLT_SCANLINES,     M2M$ASCAL_POLYPHASE, LANCZOS2_12,         SCAN_BR_110_80

                ; Both CRT rows reuse SCAN_BR_110_80 as the V file (same as
                ; Scanlines mode). CRT_Sim_*_V is a deep ~40% mid-phase
                ; plateau designed to be combined with the MiSTer gamma LUT
                ; + shadow mask; M2M supports neither, so standalone the
                ; plateau crushes bright content into a dark band. The
                ; Composite vs S-Video character lives entirely in the H
                ; file (Composite has heavy horizontal blur, S-Video has
                ; mild softening), so swapping only the V file preserves the
                ; perceptual distinction while restoring near-unity mean
                ; brightness.
                .DW GBC_OSM_HDMI_FLT_CRT_SVIDEO,    M2M$ASCAL_POLYPHASE, CRT_SIM_SVIDEO_H,    SCAN_BR_110_80
                .DW GBC_OSM_HDMI_FLT_CRT_COMPOSITE, M2M$ASCAL_POLYPHASE, CRT_SIM_COMPOSITE_H, SCAN_BR_110_80

; ----------------------------------------------------------------------------
; M2M$LOAD_POLYPHASE  Load a (horizontal, vertical) filter pair into the
;                    ascal polyphase coefficient RAM. ASCAL_FILTER_LEN
;                    (= 0x100, defined in M2M/rom/filters.asm) words are
;                    copied into the H slot at M2M$ASCAL_PP_HORIZ and another
;                    0x100 words into the V slot at M2M$ASCAL_PP_VERT.
;
;                    BACKPORT from M2M V2.1 (M2M/rom/tools.asm): the M2M
;                    V2.0.1 framework does not ship this routine and M2M/rom
;                    firmware stays unmodified in this repo, so it lives here
;                    (see doc/m2m/exceptions.md). When the framework is
;                    upgraded to V2.1+, delete this copy -- the assembler
;                    will flag the duplicate label.
;
; Input:  R8 = pointer to a 256-word horizontal coefficient table
;         R9 = pointer to a 256-word vertical   coefficient table
; Output: -
; ----------------------------------------------------------------------------

M2M$LOAD_POLYPHASE  SYSCALL(enter, 1)

                ; select the ascal Polyphase RAM device
                MOVE    M2M$RAMROM_DEV, R0
                MOVE    M2M$ASCAL_PPHASE, @R0
                MOVE    M2M$RAMROM_4KWIN, R0
                MOVE    0, @R0

                MOVE    ASCAL_FILTER_LEN, R10

                ; copy horizontal filter (R8 already = H label) to PP_HORIZ
                MOVE    R9, R0                  ; stash V pointer
                MOVE    M2M$RAMROM_DATA, R9
                ADD     M2M$ASCAL_PP_HORIZ, R9
                SYSCALL(memcpy, 1)

                ; copy vertical filter (R0 = stashed V label) to PP_VERT.
                MOVE    R0, R8
                MOVE    M2M$RAMROM_DATA, R9
                ADD     M2M$ASCAL_PP_VERT, R9
                SYSCALL(memcpy, 1)

                SYSCALL(leave, 1)
                RET

; Filter coefficient blobs for the polyphase-based options that the M2M
; framework does not already link: LANCZOS2_12 and SCAN_BR_110_80 come in
; via M2M/rom/filters.asm (included from M2M/rom/shell.asm); the three blobs
; below are core-local copies (see video_filters/README.md).
#include "video_filters/GS_Sharpness_050.asm"
#include "video_filters/CRT_Sim_Composite_H.asm"
#include "video_filters/CRT_Sim_SVideo_H.asm"

; ----------------------------------------------------------------------------
; Core specific constants and strings
; ----------------------------------------------------------------------------

; OSM menu constants are autogenerated by make_rom.sh (like in C64MEGA65 and
; AExp): the GBC_OSM_* line numbers are scraped from the C_MENU_* constants in
; ../vhdl/mega65.vhd and the GBC_OPTM_G_* group ids from the OPTM_G_*
; constants in ../vhdl/config.vhd -- no hardcoded menu indexes here.
#include "osm_const.asm"

; cartridge file extensions (need to be upper case)
GB_FILE_EXT     .ASCII_W ".GB"
GBC_FILE_EXT    .ASCII_W ".GBC"

; Type of the cartridge that survived PREP_LOAD_IMAGE validation. The header
; is authoritative: CGB flag 0xC0 means Color-only, while ordinary and 0x80
; dual-compatible cartridges may run in Classic mode.
CART_KIND_NONE       .EQU 0
CART_KIND_DMG_COMPAT .EQU 1
CART_KIND_CGB_ONLY   .EQU 2

; Cartridge check warnings, shown by the Shell together with an error code.
; The screen of the Game Boy core is 32x28 characters, so keep all lines
; at a maximum of 30 characters. The wording is based on the original
; gbc4mega65 V0.8 firmware.
WRN_NO_CART     .ASCII_P "\nCannot run this cartridge!\n\n"
                .ASCII_P "This is not a valid Game Boy\n"
                .ASCII_P "cartridge file.\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_UNSUPP_MBC  .ASCII_P "\nCannot run this cartridge!\n\n"
                .ASCII_P "It uses a not yet supported\n"
                .ASCII_P "Memory Bank Controller (MBC).\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_TOO_LARGE   .ASCII_P "\nCannot run this cartridge!\n\n"
                .ASCII_P "The cartridge ROM is too\n"
                .ASCII_P "large. Maximum supported\n"
                .ASCII_P "ROM size: 1 MB\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_RAM_SIZE    .ASCII_P "\nCannot run this cartridge!\n\n"
                .ASCII_P "The cartridge RAM is too\n"
                .ASCII_P "large. Maximum supported\n"
                .ASCII_P "RAM size: 128 KB\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_COLOR_ONLY  .ASCII_P "\nCannot run this cartridge!\n\n"
                .ASCII_P "This cartridge requires Game\n"
                .ASCII_P "Boy Color mode. Switch to\n"
                .ASCII_P "Color and load it again.\n\n"
                .ASCII_W "Press SPACE to continue.\n"

WRN_NO_GB_FILES .ASCII_P "This folder does not contain\n"
                .ASCII_P "any Game Boy cartridges\n"
                .ASCII_P "(*.gb or *.gbc files)\n\n"
                .ASCII_W "Press SPACE to continue"

WRN_NO_CLASSIC_FILES
                .ASCII_P "This folder does not contain\n"
                .ASCII_P "any Game Boy cartridges\n"
                .ASCII_P "for Classic mode (*.gb)\n\n"
                .ASCII_W "Press SPACE to continue"

; This needs to be the last thing before the "Variables" sections starts
END_OF_ROM      .DW 0

; ----------------------------------------------------------------------------
; Variables: Need to be located in RAM
; ----------------------------------------------------------------------------

#ifdef RELEASE
                .ORG    0x8000                  ; RAM starts at 0x8000
#endif

;
; Last successfully validated cartridge. A rejected load leaves this value
; unchanged because the previously running cartridge also remains intact.
LOADED_CART_KIND .BLOCK 1

; M2M Shell variables (only include, if you included "shell.asm" above)
#include "../../M2M/rom/shell_vars.asm"

; ----------------------------------------------------------------------------
; Heap and Stack: Need to be located in RAM after the variables
; ----------------------------------------------------------------------------

; The On-Screen-Menu uses the heap for several data structures. This heap
; is located before the main system heap in memory.
; You need to deduct MENU_HEAP_SIZE from the actual heap size below.
; Example: If your HEAP_SIZE would be 29696, then you write 29696-1408=28288
; instead, but when doing the sanity check calculations, you use 29696
;
; Sizing (see the two checks in M2M/rom/options.asm): the OSM needs
; OPTM_STRUCTSIZE (19) plus the OPTM_ITEMS string incl. terminator (814 for
; the 82-line menu) plus four arrays of OPTM_SIZE words (328) plus the
; percent-s scratch area: (OPTM_DX+2) x (submenus + CRT/ROM items + 1),
; which is 29 x 7 = 203 with five submenus. Total 1364; 1408 keeps a small
; reserve without stealing more file browser heap than necessary (every
; word spent here is one word less for sorted directory entries).
MENU_HEAP_SIZE  .EQU 1408

#ifndef RELEASE

; heap for storing the sorted structure of the current directory entries
; this needs to be the last variable before the monitor variables as it is
; only defined as "BLOCK 1" to avoid a large amount of null-values in
; the ROM file
HEAP_SIZE       .EQU 5760                       ; 7168 - 1408 = 5760
HEAP            .BLOCK 1

; in RELEASE mode: 28k of heap which leads to a better user experience when
; it comes to folders with a lot of files
#else

HEAP_SIZE       .EQU 28288                      ; 29696 - 1408 = 28288
HEAP            .BLOCK 1

; The monitor variables use 22 words, round to 32 for being safe and subtract
; it from FF00 because this is at the moment the highest address that we
; can use as RAM: 0xFEE0
; The stack starts at 0xFEE0 (search var VAR$STACK_START in m2m-rom.lis to
; calculate the address). To see, if there is enough room for the stack
; given the HEAP_SIZE do this calculation: Add 29696 words to HEAP which
; is currently 0xXXXX and subtract the result from 0xFEE0. This yields
; currently a stack size of more than 1.5k words, which is sufficient
; for this program.

                .ORG    0xFEE0                  ; TODO: automate calculation
#endif

; STACK_SIZE: Size of the global stack and should be a minimum of 768 words
; after you subtract B_STACK_SIZE.
; B_STACK_SIZE: Size of local stack of the the file- and directory browser. It
; should also have a minimum size of 768 words. If you are not using the
; Shell, then B_STACK_SIZE is not used.
STACK_SIZE      .EQU    1536
B_STACK_SIZE    .EQU    768

#include "../../M2M/rom/main_vars.asm"
