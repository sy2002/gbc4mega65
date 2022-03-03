; ****************************************************************************
; MiSTer2MEGA65 (M2M) QNICE ROM
;
; Variables for shell.asm
;
; done by sy2002 in 2021 and licensed under GPL v3
; ****************************************************************************


#include "dirbrowse_vars.asm"
#include "keyboard_vars.asm"
#include "screen_vars.asm"

#include "menu_vars.asm"

OPTM_ICOUNT		.BLOCK 1						; amount of menu items
OPTM_START 		.BLOCK 1						; initially selected menu item
OPTM_SELECTED   .BLOCK 1                        ; last options menu selection