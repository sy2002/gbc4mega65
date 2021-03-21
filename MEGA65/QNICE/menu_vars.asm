; ****************************************************************************
; Game Boy Color for MEGA65 (gbc4mega65)
;
; Variables for Options Menu (menu.asm): Need to be located in RAM
;
; gbc4mega65 machine is based on Gameboy_MiSTer
; MEGA65 port done by sy2002 in February 2021 and licensed under GPL v3
; ****************************************************************************

; Function that clears the VRAM
OPTM_CLEAR      .BLOCK 1

; Function that draws the frame
; x|y = R8|R9, dx|dy = R10|R11
OPTM_FRAME      .BLOCK 1

; Print function that handles everything incl. cursor pos and \n by itself
; R8 contains the string that shall be printed
OPTM_PRINT      .BLOCK 1

; Like print but contains target x|y coords in R9|R10
OPTM_PRINTXY    .BLOCK 1

; Draws a horizontal line/menu separator at the y-pos given in R8
OPTM_LINE       .BLOCK 1

; screen coordinates
OPTM_X          .BLOCK 1
OPTM_Y          .BLOCK 1
OPTM_DX         .BLOCK 1
OPTM_DY         .BLOCK 1

; selection character + zero terminator
OPTM_SEL        .BLOCK 2
