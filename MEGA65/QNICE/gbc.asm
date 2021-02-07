; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Definitions for MMIO access to the Game Boy Color core
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; Control and status register
GBC$CSR             .EQU 0xFFE0
    ; Bit      0: Reset
    ; Bit      1: Pause
    ; Bit      2: Show On-Screen-Menu (OSM)

GBC$CSR_RESET       .EQU 0x0001
GBC$CSR_UN_RESET    .EQU 0xFFFE
GBC$CSR_PAUSE       .EQU 0x0002
GBC$CSR_UN_PAUSE    .EQU 0xFFFD
GBC$CSR_OSM         .EQU 0x0004
GBC$CSR_UN_OSM      .EQU 0xFFFB

; window selector for MEM_CARTRIDGE_WIN
; actual cartridge RAM address = GBC$CART_SEL x 4096 + MEM_CARTRIDGE_WIN 
GBC$CART_SEL        .EQU 0xFFE1 

; On-Screen-Menu (OSM)
; When bit 2 of the CSR = 1, then the OSM is shown at the coordinates
; and in the size given by these two registers. The coordinates and the
; size are specified in characters.
GBC$OSM_XY          .EQU 0xFFE2 ; hi-byte = x-start coord, lo-byte = ditto y
GBC$OSM_DXDY        .EQU 0xFFE3 ; hi-byte = dx, lo-byte = dy

GBC$OSM_COLS        .EQU 50     ; columns (max chars per line)
GBC$OSM_ROWS        .EQU 37     ; rows (max lines per screen)


; MMIO locations and sizes
MEM_CARTRIDGE_WIN   .EQU 0xB000 ; 4kb window defined by GBC$CART_SEL
MEM_BIOS            .EQU 0xC000 ; GBC or GB BIOS
MEM_VRAM            .EQU 0xD000 ; Video RAM: "ASCII" characters

MEM_BIOS_MAXLEN     .EQU 0x1000 ; maximum length of BIOS
MEM_CARTWIN_MAXLEN  .EQU 0x1000 ; length of cartridge window

; Special characters in font Anikki-16x16
CHR_FC_TL           .EQU 201    ; fat top/left corner
CHR_FC_SH           .EQU 205    ; fat straight horizontal
CHR_FC_TR           .EQU 187    ; fat top/right corner
CHR_FC_SV           .EQU 186    ; fat straight vertical
CHR_FC_BL           .EQU 200    ; fat bottom/left corner
CHR_FC_BR           .EQU 188    ; fat bottom/right corner

