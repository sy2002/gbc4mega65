; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; List of supported Game Boy Memory Bank Controllers (MBCs)
;
; This list needs to be consistent with vhdl/mbc.vhd
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************

; R8: MBC ID as described in https://gbdev.io/pandocs/#_0147-cartridge-type
; Returns set C flag for supported MBCs
CHECK_MBC       AND     0xFFFB, SR              ; clear carry flag

                ; list of supported
                CMP     0x0000, R8              ; MBC $00
                RBRA    _CHECK_MBC_SC, Z
                CMP     0x0001, R8              ; MBC $01
                RBRA    _CHECK_MBC_SC, Z

                RBRA    _CHECK_MBC_RET, 1       ; no supported MBC found

_CHECK_MBC_SC   OR      4, SR                   ; set carry flag
_CHECK_MBC_RET  RET

