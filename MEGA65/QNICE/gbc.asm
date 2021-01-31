; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Definitions for MMIO access to the Game Boy Color core
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

GBC$CSR             .EQU 0xFFE0 ; Control and status register
    ; Bit      0: Reset
    ; Bit      1: Pause
GBC$CART_SEL        .EQU 0xFFE1 ; 

GBC$CSR_RESET       .EQU 0x0001
GBC$CSR_UN_RESET    .EQU 0xFFFE
GBC$CSR_PAUSE       .EQU 0x0002
GBC$CSR_UN_PAUSE    .EQU 0xFFFD

CARTRIDGE_WIN       .EQU 0xB000 ; 4kb window defined by GBC$CART_SEL
BIOS                .EQU 0xC000 ; GBC or GB BIOS
VRAM                .EQU 0xD000 ; Video RAM: "ASCII" characters
