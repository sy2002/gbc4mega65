----------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- Configuration data for the Shell
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity config is
port (
   clk_i       : in std_logic;

   -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
   -- bits 11 downto 0: address the up to 4k the configuration data
   address_i   : in std_logic_vector(27 downto 0);

   -- config data
   data_o      : out std_logic_vector(15 downto 0)
);
end entity config;

architecture beh of config is

--------------------------------------------------------------------------------------------------------------------
-- Version of the core
--
-- Single source of truth: The welcome screen, the help system, CORENAME and CFG_FILE derive from this constant
-- and make_release.py checks the release version against it.
--------------------------------------------------------------------------------------------------------------------

constant CORE_VERSION : string := "WIP-V2-A1";

--------------------------------------------------------------------------------------------------------------------
-- String and character constants (specific for the Anikki-16x16 font)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant CHR_LINE_1  : character := character'val(196);
constant CHR_LINE_5  : string := CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1;
constant CHR_LINE_10 : string := CHR_LINE_5 & CHR_LINE_5;
constant CHR_LINE_50 : string := CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10;

--------------------------------------------------------------------------------------------------------------------
-- Welcome and Help Screens (Selectors 0x1000 .. 0x1FFF)
--------------------------------------------------------------------------------------------------------------------

-- define the amount of WHS array elements: between 1 and 16
constant WHS_RECORDS   : natural := 2;

-- define the maximum amount of pages per WHS array element: between 1 and 256
-- (this is necessary because Vivado does not support unconstrained arrays in a record)
constant WHS_MAX_PAGES : natural := 3;

 -- !!! DO NOT TOUCH !!!
constant SEL_WHS           : std_logic_vector(15 downto 0) := x"1000";
type WHS_INDEX_TYPE is array (0 to WHS_MAX_PAGES - 1) of natural;
type WHS_RECORD_TYPE is record
   page_count  : natural;
   page_start  : WHS_INDEX_TYPE;
   page_length : WHS_INDEX_TYPE;
end record;
type WHS_RECORD_ARRAY_TYPE is array (0 to WHS_RECORDS - 1) of WHS_RECORD_TYPE;

-- START YOUR CONFIGURATION BELOW THIS LINE

-- The screen size of the Game Boy core is 32x28 characters (512x448 pixels, 16x16 font),
-- so the usable text area inside the frame is 30 columns wide and 26 rows tall:
-- keep all lines of all screens at a maximum of 30 characters.

constant SCR_WELCOME : string :=

   "\n Game Boy & Game Boy Color\n" &
   " for MEGA65 Version " & CORE_VERSION & "\n\n" &
   " MiSTer port by sy2002\n" &
   " and MJoergen in 2021-2026\n\n" &

   " MEGA65         Game Boy\n" &
   " " & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_5 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & "\n" &
   " Cursor keys    Joypad\n" &
   " Joystick       Joypad, A, B\n" &
   " Space          Start\n" &
   " Return         Select\n" &
   " Left Shift     A\n" &
   " MEGA65 key     B\n" &
   " Help           Options menu\n\n" &

   " Load a cartridge (*.gb or\n" &
   " *.gbc file) via the options\n" &
   " menu item Cartridge.\n\n" &

   " Learn more in About & Help.\n\n" &

   " Press Space to continue.\n";

constant HELP_1 : string :=

   "\n Game Boy for MEGA65 " & CORE_VERSION & "\n\n" &

   " MiSTer port by sy2002\n" &
   " and MJoergen in 2021-2026\n" &
   " Powered by MiSTer2MEGA65\n\n" &

   " MEGA65         Game Boy\n" &
   " " & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_5 & "\n" &
   " Cursor keys    Joypad\n" &
   " Space          Start\n" &
   " Return         Select\n" &
   " Left Shift     A\n" &
   " MEGA65 key     B\n\n" &

   " Joysticks work in both\n" &
   " ports. Use the Joystick\n" &
   " Mode menu for games that\n" &
   " jump with A or B.\n\n\n" &

   " Crsr right: more     (1 of 3)\n" &
   " Space: close the help screen.\n";

constant HELP_2 : string :=

   "\n Cartridges and BIOS\n\n" &

   " Put ROMs on a FAT32 SD card.\n" &
   " The browser starts in /gbc.\n" &
   " Color shows *.gb and *.gbc;\n" &
   " Classic only shows *.gb.\n\n" &

   " Maximum size: 1 MB. Color-\n" &
   " only carts need Color mode.\n\n" &

   " The core includes an Open\n" &
   " Source Game Boy Color BIOS.\n" &
   " For more authenticity, copy\n" &
   " the original cgb_boot.bin\n" &
   " (or cgb_bios.bin) into the\n" &
   " /gbc folder.\n\n" &

   " Settings are saved if the\n" &
   " settings file from the\n" &
   " release ZIP is in /gbc.\n\n" &

   " Crsr left/right     (2 of 3)\n" &
   " Space: close the help screen.\n";

constant HELP_3 : string :=

   "\n Display\n\n" &

   " HDMI: use the HDMI submenus\n" &
   " to choose 60 Hz modes and\n" &
   " image filters. Flicker-free\n" &
   " syncs the core to HDMI;\n" &
   " switch it off when using\n" &
   " the VGA output.\n" &
   " Aspect Ratio selects three\n" &
   " borderless Handheld LCD sizes\n" &
   " in the original 10:9 shape,\n" &
   " or the TV-style 4:3 canvas.\n\n" &

   " VGA: Standard is 31 kHz.\n" &
   " The retro 15 kHz modes are\n" &
   " for CRT monitors, also with\n" &
   " CSYNC for RGB/SCART.\n\n" &

   " github.com/sy2002/gbc4mega65\n\n\n" &

   " Crsr left: back      (3 of 3)\n" &
   " Space: close the help screen.\n";

-- Concatenate all your Welcome and Help screens into one large string, so that during synthesis one large string ROM can be build.
constant WHS_DATA : string := SCR_WELCOME & HELP_1 & HELP_2 & HELP_3;

-- The WHS array needs the start address of each page. As a best practice: Just define some constants, that you can name for example
-- just like you named the string constants and then add _START. Use the 'length attribute of VHDL to add up all previous strings
-- so that the Synthesis tool can calculate the start addresses: Your first string starts at zero, your next one at the address which
-- is equal to the length of the first one, your next one at the address which is equal to the sum of the previous ones, and so on.
constant SCR_WELCOME_START : natural := 0;
constant HELP_1_START      : natural := SCR_WELCOME'length;
constant HELP_2_START      : natural := HELP_1_START + HELP_1'length;
constant HELP_3_START      : natural := HELP_2_START + HELP_2'length;

-- Fill the WHS array with page start addresses and the length of each page.
-- Make sure that array element 0 is always your Welcome page. If you don't use a welcome page, fill everything with zeros.
constant WHS : WHS_RECORD_ARRAY_TYPE := (
   --- Welcome Screen
   (page_count    => 1,
    page_start    => (SCR_WELCOME_START,  0, 0),
    page_length   => (SCR_WELCOME'length, 0, 0)),

   --- Help pages ("About & Help" menu item)
   (page_count    => 3,
    page_start    => (HELP_1_START,  HELP_2_START,  HELP_3_START),
    page_length   => (HELP_1'length, HELP_2'length, HELP_3'length))
);

--------------------------------------------------------------------------------------------------------------------
-- Set start folder for file browser and specify config file for menu persistence (Selectors 0x0100 and 0x0101)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_DIR_START     : std_logic_vector(15 downto 0) := x"0100";
constant SEL_CFG_FILE      : std_logic_vector(15 downto 0) := x"0101";

-- START YOUR CONFIGURATION BELOW THIS LINE

-- The file browser starts in the /gbc folder (falling back to the root folder if it
-- does not exist), exactly like the original gbc4mega65 releases.
constant DIR_START         : string := "/gbc";

-- The settings file embeds the core version so that different installed versions of the
-- core keep separate settings and stale file formats can never be loaded.
constant CFG_FILE          : string := "/gbc/gbc4mega65-" & CORE_VERSION & ".cfg";

--------------------------------------------------------------------------------------------------------------------
-- General configuration settings: Reset, Pause, OSD behavior, Ascal, etc. (Selector 0x0110)
--------------------------------------------------------------------------------------------------------------------

constant SEL_GENERAL       : std_logic_vector(15 downto 0) := x"0110";  -- !!! DO NOT TOUCH !!!

-- START YOUR CONFIGURATION BELOW THIS LINE

-- at a minimum, keep the reset line active for this amount of "QNICE loops" (see gencfg.asm).
-- "0" means: deactivate this feature
constant RESET_COUNTER     : natural := 100;

-- keep the core running while the OSD is open (the original gbc4mega65 behaved the same:
-- the game continues while the options menu is shown; only the controls are decoupled)
constant OPTM_PAUSE        : boolean := false;

-- show the welcome screen in general
constant WELCOME_ACTIVE    : boolean := true;

-- shall the welcome screen also be shown after the core is reset?
-- (only relevant if WELCOME_ACTIVE is true)
constant WELCOME_AT_RESET  : boolean := false;

-- keyboard and joystick connection during reset and OSD
constant KEYBOARD_AT_RESET : boolean := false;
constant JOY_1_AT_RESET    : boolean := false;
constant JOY_2_AT_RESET    : boolean := false;

constant KEYBOARD_AT_OSD   : boolean := false;
constant JOY_1_AT_OSD      : boolean := true;
constant JOY_2_AT_OSD      : boolean := true;

-- Avalon Scaler settings (see ascal.vhd, used for HDMI output only)
-- 0=set ascal mode (via QNICE's ascal_mode_o) to the value of the config.vhd constant ASCAL_MODE
-- 1=do nothing, leave ascal mode alone, custom QNICE assembly code can still change it via M2M$ASCAL_MODE
--               and QNICE's CSR will be set to not automatically sync ascal_mode_i
-- 2=keep ascal mode in sync with the QNICE input register ascal_mode_i:
--   use this if you want to control the ascal mode for example via the Options menu
--   where you would wire the output of certain options menu bits with ascal_mode_i
--
-- The Game Boy core uses 1 (AUSE_CUSTOM): the firmware in CORE/m2m-rom/m2m-rom.asm implements
-- the "HDMI Filter" menu (LOAD_HDMI_FILTER) and drives M2M$ASCAL_MODE itself
constant ASCAL_USAGE       : natural := 1;
constant ASCAL_MODE        : natural := 0;   -- see ascal.vhd for the meaning of this value

-- Save on-screen-display settings if the file specified by CFG_FILE exists and if it has
-- the length of OPTM_SIZE bytes. If the first byte of the file has the value 0xFF then it
-- is considered as "default", i.e. the menu items specified by OPTM_G_STDSEL are selected.
-- If the file does not exists, then settings are not saved and OPTM_G_STDSEL always denotes the standard settings.
constant SAVE_SETTINGS     : boolean := true;

-- Delay in ms between the last write request to a virtual drive from the core and the start of the
-- cache flushing (i.e. writing to the SD card). The Game Boy core does not use virtual drives,
-- so these two constants are irrelevant; they are kept at the framework defaults.
constant VD_ANTI_THRASHING_DELAY : natural := 2000;

-- Amount of bytes saved in one iteration of the background saving (buffer flushing) process
constant VD_ITERATION_SIZE       : natural := 100;

--------------------------------------------------------------------------------------------------------------------
-- Name and version of the core  (Selector 0x0200)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_CORENAME      : std_logic_vector(15 downto 0) := x"0200";

-- START YOUR CONFIGURATION BELOW THIS LINE

-- Currently this is only used in the debug console. Use the welcome screen and the
-- help system to display the name and version of your core to the end user
constant CORENAME          : string := "Game Boy for MEGA65 " & CORE_VERSION;

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu  (Selectors 0x0300 .. 0x0312): DO NOT TOUCH
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!! Selectors for accessing the menu configuration data
constant SEL_OPTM_ITEMS       : std_logic_vector(15 downto 0) := x"0300";
constant SEL_OPTM_GROUPS      : std_logic_vector(15 downto 0) := x"0301";
constant SEL_OPTM_STDSEL      : std_logic_vector(15 downto 0) := x"0302";
constant SEL_OPTM_LINES       : std_logic_vector(15 downto 0) := x"0303";
constant SEL_OPTM_START       : std_logic_vector(15 downto 0) := x"0304";
constant SEL_OPTM_ICOUNT      : std_logic_vector(15 downto 0) := x"0305";
constant SEL_OPTM_MOUNT_DRV   : std_logic_vector(15 downto 0) := x"0306";
constant SEL_OPTM_SINGLESEL   : std_logic_vector(15 downto 0) := x"0307";
constant SEL_OPTM_MOUNT_STR   : std_logic_vector(15 downto 0) := x"0308";
constant SEL_OPTM_DIMENSIONS  : std_logic_vector(15 downto 0) := x"0309";
constant SEL_OPTM_SAVING_STR  : std_logic_vector(15 downto 0) := x"030A";
constant SEL_OPTM_HELP        : std_logic_vector(15 downto 0) := x"0310";
constant SEL_OPTM_CRTROM      : std_logic_vector(15 downto 0) := x"0311";
constant SEL_OPTM_CRTROM_STR  : std_logic_vector(15 downto 0) := x"0312";
constant SEL_OPTM_DEPS        : std_logic_vector(15 downto 0) := x"0313";

-- !!! DO NOT TOUCH !!! Configuration constants for OPTM_GROUPS (shell.asm and menu.asm expect them to be like this)
constant OPTM_G_TEXT       : integer := 16#00000#;         -- text that cannot be selected
constant OPTM_G_CLOSE      : integer := 16#000FF#;        -- menu items that closes menu
constant OPTM_G_STDSEL     : integer := 16#00100#;        -- item within a group that is selected by default
constant OPTM_G_LINE       : integer := 16#00200#;        -- draw a line at this position
constant OPTM_G_START      : integer := 16#00400#;        -- selector / cursor position after startup (only use once!)
                                                          -- 16#00800# is used in OPTM_G_MOUNT_DRV (OPTM_G_SINGLESEL)
constant OPTM_G_HEADLINE   : integer := 16#01000#;        -- like OPTM_G_TEXT but will be shown in a brigher color
                                                          -- 16#02000# is used in OPTM_G_HELP (plus OPTM_G_SINGLESEL)
                                                          -- 16#04000# is used in OPTM_G_SUBMENU
constant OPTM_G_SINGLESEL  : integer := 16#08000#;        -- single select item
constant OPTM_G_MOUNT_DRV  : integer := 16#08800#;        -- line item means: mount drive; first occurance = drive 0, second = drive 1, ...
constant OPTM_G_HELP       : integer := 16#0A000#;        -- line item means: help screen; first occurance = WHS(1), second = WHS(2), ...
constant OPTM_G_SUBMENU    : integer := 16#0C000#;        -- starts/ends a section that is treated as submenu
constant OPTM_G_LOAD_ROM   : integer := 16#18000#;        -- line item means: load ROM; first occurance = rom 0, second = rom 1, ...
constant OPTM_G_DEPENDENT  : integer := 16#20000000#;      -- dependent line (smart dependencies, see OPTM_DEP below): visible only
                                                           -- while a specific item of a specific mother group is selected (bit 29)

constant OPTM_GTC          : natural := 30;                -- Amount of significant bits in OPTM_G_* constants (max 30: 2**31 overflows
                                                           -- the integer range expression below); was 17 before the smart-dependencies feature

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu: START YOUR CONFIGURATION BELOW THIS LINE
--------------------------------------------------------------------------------------------------------------------

-- Strings with which %s will be replaced in case the menu item is of type OPTM_G_MOUNT_DRV
constant OPTM_S_MOUNT      : string := "<Mount Drive>";     -- no disk image mounted, yet
constant OPTM_S_CRTROM     : string := "<Load>";            -- no ROM loaded, yet
constant OPTM_S_SAVING     : string := "<Saving>";          -- the internal write cache is dirty and not yet written back to the SD card

-- Size of menu and menu items
-- CAUTION: 1. End each line (also the last one) with a \n and make sure empty lines / separator lines are only consisting of a "\n"
--             Do use a lower case \n. If you forget one of them or if you use upper case, you will run into undefined behavior.
--          2. Start each line that contains an actual menu item (multi- or single-select) with a Space character,
--             otherwise you will experience visual glitches.
constant OPTM_SIZE         : natural := 115; -- amount of items including empty lines:
                                             -- needs to be equal to the number of lines in OPTM_ITEMS and amount of items in OPTM_GROUPS
                                             -- IMPORTANT: If SAVE_SETTINGS is true and OPTM_SIZE changes: Make sure to re-generate and
                                             -- and re-distribute the config file. You can make a new one using M2M/tools/make_config.sh

-- Net size of the Options menu on the screen in characters (excluding the frame, which is hardcoded to two characters)
-- Without submenus: Use OPTM_SIZE as height, otherwise count how large the actually visible main menu is:
-- one row per main menu line plus one row per submenu opener line (the submenu content is not counted).
constant OPTM_DX           : natural := 28;
constant OPTM_DY           : natural := 25;

-- The zero-based line indices of the menu items below are mirrored as C_MENU_* constants
-- in mega65.vhd and (auto-generated by CORE/m2m-rom/make_rom.sh) as GBC_OSM_* constants
-- in the QNICE firmware. When adding/removing/reordering lines: keep all three in sync!
constant OPTM_ITEMS        : string :=

   " Game Boy for MEGA65\n"    &    --  0: headline
   "\n"                        &    --  1
   " Cartridge:%s\n"           &    --  2: load a *.gb / *.gbc cartridge (%s = <Load> or filename)
   "\n"                        &    --  3
   " Game Boy Mode\n"          &    --  4: headline
   "\n"                        &    --  5
   " Classic\n"                &    --  6
   " Color\n"                  &    --  7: default
   "\n"                        &    --  8
   " Color Mode\n"             &    --  9: headline
   "\n"                        &    -- 10
   " LCD Emulation\n"          &    -- 11: default
   " Fully Saturated\n"        &    -- 12
   "\n"                        &    -- 13
   " Joystick: %s\n"           &    -- 14: submenu (%s = current mapping)
   " Joystick Mode\n"          &    -- 15: headline
   "\n"                        &    -- 16
   " Standard, Fire=A\n"       &    -- 17: default
   " Standard, Fire=B\n"       &    -- 18
   " Up=A, Fire=B\n"           &    -- 19
   " Up=B, Fire=A\n"           &    -- 20
   "\n"                        &    -- 21
   " Jump & Run Improvements\n" &  -- 22: headline
   " Off\n"                    &    -- 23
   " Soft\n"                   &    -- 24: default
   " Full\n"                   &    -- 25
   "\n"                        &    -- 26
   " Back to main menu\n"      &    -- 27
   " HDMI: %s\n"               &    -- 28: submenu (%s = current display mode)
   " HDMI Display Mode\n"      &    -- 29: headline
   "\n"                        &    -- 30
   " 720p    60 Hz   16:9\n"   &    -- 31: default
   " 640x480 60 Hz    4:3\n"   &    -- 32
   " 720x480 59.94 Hz 3:2\n"   &    -- 33
   " 800x600 60 Hz    4:3\n"   &    -- 34
   "\n"                        &    -- 35
   " HDMI: Flicker-free\n"     &    -- 36: default on
   "\n"                        &    -- 37
   " Aspect Ratio & Size\n"    &    -- 38: headline
   "\n"                        &    -- 39
   " Handheld LCD Small  10:9\n" &  -- 40: default
   " Handheld LCD Medium 10:9\n" &  -- 41
   " Handheld LCD Full   10:9\n" &  -- 42
   " Super Game Boy Style 4:3\n" &  -- 43
   "\n"                        &    -- 44
   " Back to main menu\n"      &    -- 45
   " HDMI: %s\n"               &    -- 46: submenu (%s = current filter)
   " HDMI Filter\n"            &    -- 47: headline
   "\n"                        &    -- 48
   " No Filter\n"              &    -- 49
   " Sharp Bilinear\n"         &    -- 50
   " Bicubic\n"                &    -- 51
   " Smooth\n"                 &    -- 52
   " Lanczos\n"                &    -- 53: default
   " Scanlines\n"              &    -- 54
   " CRT (S-Video)\n"          &    -- 55
   " CRT (Composite)\n"        &    -- 56
   "\n"                        &    -- 57
   " Back to main menu\n"      &    -- 58
   " VGA: %s\n"                &    -- 59: submenu (%s = current VGA mode)
   " VGA Display Mode\n"       &    -- 60: headline
   "\n"                        &    -- 61
   " Standard\n"               &    -- 62: default
   "\n"                        &    -- 63
   " Retro 15 kHz mode\n"      &    -- 64: text
   "\n"                        &    -- 65
   " 15 kHz with HS/VS\n"      &    -- 66
   " 15 kHz with CSYNC\n"      &    -- 67
   "\n"                        &    -- 68
   " Back to main menu\n"      &    -- 69
   " OSM: %s\n"                &    -- 70: submenu (%s = current OSM scaling)
   " OSM Scaling\n"            &    -- 71: headline
   "\n"                        &    -- 72
   " 100%\n"                   &    -- 73: default
   " 94%\n"                    &    -- 74
   " 88%\n"                    &    -- 75
   " 81%\n"                    &    -- 76
   " 75%\n"                    &    -- 77
   " 69%\n"                    &    -- 78
   " 63%\n"                    &    -- 79
   " 56%\n"                    &    -- 80
   " 50%\n"                    &    -- 81
   "\n"                        &    -- 82
   " Back to main menu\n"      &    -- 83: OSM Scaling submenu: END
   " Volume: %s\n"             &    -- 84: submenu (%s = current volume)
   " Volume Control\n"         &    -- 85: headline
   "\n"                        &    -- 86
   " 100%\n"                   &    -- 87: default
   " 95%\n"                    &    -- 88
   " 90%\n"                    &    -- 89
   " 85%\n"                    &    -- 90
   " 80%\n"                    &    -- 91
   " 75%\n"                    &    -- 92
   " 70%\n"                    &    -- 93
   " 65%\n"                    &    -- 94
   " 60%\n"                    &    -- 95
   " 55%\n"                    &    -- 96
   " 50%\n"                    &    -- 97
   " 45%\n"                    &    -- 98
   " 40%\n"                    &    -- 99
   " 35%\n"                    &    -- 100
   " 30%\n"                    &    -- 101
   " 25%\n"                    &    -- 102
   " 20%\n"                    &    -- 103
   " 15%\n"                    &    -- 104
   " 10%\n"                    &    -- 105
   " 5%\n"                     &    -- 106
   " 0%\n"                     &    -- 107
   "\n"                        &    -- 108
   " Back to main menu\n"      &    -- 109: Volume submenu: END
   " Audio Improvements\n"     &    -- 110
   "\n"                        &    -- 111
   " About & Help\n"           &    -- 112
   "\n"                        &    -- 113
   " Close Menu\n";                 -- 114

-- define your own constants here and choose meaningful names
-- make sure that your first group uses the value 1 (0 means "no menu item", such as text and line),
-- and be aware that you can only have a maximum of 254 groups (255 means "Close Menu");
-- also make sure that your group numbers are monotonic increasing (e.g. 1, 2, 3, 4, ...)
-- single-select items and therefore also drive mount items need to have unique identifiers
constant OPTM_G_CART       : integer := 1;      -- cartridge loader
constant OPTM_G_GBMODE     : integer := 2;      -- Game Boy Mode: Classic / Color
constant OPTM_G_COLMODE    : integer := 3;      -- Color Mode: LCD Emulation / Fully Saturated
constant OPTM_G_JOYMODE    : integer := 4;      -- Joystick Mode: the four mappings
constant OPTM_G_JUMPASSIST : integer := 5;      -- Jump & Run Improvements: Off / Soft / Full (decoded in mega65.vhd)
constant OPTM_G_HDMI       : integer := 6;      -- HDMI display modes
constant OPTM_G_HDMI_FF    : integer := 7;      -- HDMI: Flicker-free
constant OPTM_G_HDMI_ASPECT : integer := 8;     -- HDMI Aspect Ratio and handheld size
constant OPTM_G_HDMI_FLT   : integer := 9;      -- HDMI Filter (read by the QNICE firmware)
constant OPTM_G_VGA        : integer := 10;     -- VGA display modes
constant OPTM_G_OSM_MODE   : integer := 11;     -- OSM Scaling radio (read in HDL, mega65.vhd)
constant OPTM_G_AUDIO      : integer := 12;     -- Audio Improvements
constant OPTM_G_ABOUT      : integer := 13;     -- About & Help
constant OPTM_G_VOLUME     : integer := 14;     -- Volume Control (decoded in mega65.vhd, applied in main.vhd via C_VOL_LUT)

-- !!! DO NOT TOUCH !!!
type OPTM_GTYPE is array (0 to OPTM_SIZE - 1) of integer range 0 to 2**OPTM_GTC- 1;

-- !!! DO NOT TOUCH THE FUNCTION DEFINITION IN THE NEXT FOUR LINES
function OPTM_DEP(mother : natural; item : natural) return natural is
begin
   return OPTM_G_DEPENDENT + (item * 16#02000000#) + (mother * 16#00020000#);
end function OPTM_DEP;

-- define your menu groups: which menu items are belonging together to form a group?
-- where are separator lines? which items should be selected by default?
-- make sure that you have exactly the same amount of entries here than in OPTM_ITEMS and defined by OPTM_SIZE
constant OPTM_GROUPS       : OPTM_GTYPE := ( OPTM_G_TEXT + OPTM_G_HEADLINE,            --  0: Game Boy for MEGA65
                                             OPTM_G_LINE,                              --  1
                                             OPTM_G_CART + OPTM_G_LOAD_ROM +
                                                           OPTM_G_START,               --  2: Cartridge:%s, cursor start position
                                             OPTM_G_LINE,                              --  3
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  4: Game Boy Mode
                                             OPTM_G_LINE,                              --  5
                                             OPTM_G_GBMODE,                            --  6: Classic
                                             OPTM_G_GBMODE + OPTM_G_STDSEL,            --  7: Color, default
                                             OPTM_G_LINE,                              --  8
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            --  9: Color Mode
                                             OPTM_G_LINE,                              -- 10
                                             OPTM_G_COLMODE + OPTM_G_STDSEL,           -- 11: LCD Emulation, default
                                             OPTM_G_COLMODE,                           -- 12: Fully Saturated
                                             OPTM_G_LINE,                              -- 13
                                             OPTM_G_SUBMENU,                           -- 14: Joystick Mode submenu: START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 15: Joystick Mode
                                             OPTM_G_LINE,                              -- 16
                                             OPTM_G_JOYMODE + OPTM_G_STDSEL,           -- 17: Standard, Fire=A, default
                                             OPTM_G_JOYMODE,                           -- 18: Standard, Fire=B
                                             OPTM_G_JOYMODE,                           -- 19: Up=A, Fire=B
                                             OPTM_G_JOYMODE,                           -- 20: Up=B, Fire=A
                                             OPTM_G_LINE,                              -- 21
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 22: Jump & Run Improvements
                                             OPTM_G_JUMPASSIST,                        -- 23: Off
                                             OPTM_G_JUMPASSIST + OPTM_G_STDSEL,        -- 24: Soft, default
                                             OPTM_G_JUMPASSIST,                        -- 25: Full
                                             OPTM_G_LINE,                              -- 26
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 27: Joystick Mode submenu: END
                                             OPTM_G_SUBMENU,                           -- 28: HDMI submenu: START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 29: HDMI Display Mode
                                             OPTM_G_LINE,                              -- 30
                                             OPTM_G_HDMI + OPTM_G_STDSEL,              -- 31: 720p 60 Hz, default
                                             OPTM_G_HDMI,                              -- 32: 640x480 60 Hz
                                             OPTM_G_HDMI,                              -- 33: 720x480 59.94 Hz
                                             OPTM_G_HDMI,                              -- 34: 800x600 60 Hz
                                             OPTM_G_LINE,                              -- 35
                                             OPTM_G_HDMI_FF + OPTM_G_SINGLESEL +
                                                              OPTM_G_STDSEL,           -- 36: Flicker-free, default on
                                             OPTM_G_LINE,                              -- 37
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 38: Aspect Ratio
                                             OPTM_G_LINE,                              -- 39
                                             OPTM_G_HDMI_ASPECT + OPTM_G_STDSEL,       -- 40: Handheld LCD Small (10:9), default
                                             OPTM_G_HDMI_ASPECT,                       -- 41: Handheld LCD Medium (10:9)
                                             OPTM_G_HDMI_ASPECT,                       -- 42: Handheld LCD Full (10:9)
                                             OPTM_G_HDMI_ASPECT,                       -- 43: TV-style (4:3)
                                             OPTM_G_LINE,                              -- 44
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 45: HDMI submenu: END
                                             OPTM_G_SUBMENU,                           -- 46: HDMI Filter submenu: START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 47: HDMI Filter
                                             OPTM_G_LINE,                              -- 48
                                             OPTM_G_HDMI_FLT,                          -- 49: No Filter
                                             OPTM_G_HDMI_FLT,                          -- 50: Sharp Bilinear
                                             OPTM_G_HDMI_FLT,                          -- 51: Bicubic
                                             OPTM_G_HDMI_FLT,                          -- 52: Smooth
                                             OPTM_G_HDMI_FLT + OPTM_G_STDSEL,          -- 53: Lanczos, default
                                             OPTM_G_HDMI_FLT,                          -- 54: Scanlines
                                             OPTM_G_HDMI_FLT,                          -- 55: CRT (S-Video)
                                             OPTM_G_HDMI_FLT,                          -- 56: CRT (Composite)
                                             OPTM_G_LINE,                              -- 57
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 58: HDMI Filter submenu: END
                                             OPTM_G_SUBMENU,                           -- 59: VGA submenu: START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 60: VGA Display Mode
                                             OPTM_G_LINE,                              -- 61
                                             OPTM_G_VGA + OPTM_G_STDSEL,               -- 62: Standard, default
                                             OPTM_G_LINE,                              -- 63
                                             OPTM_G_TEXT,                              -- 64: Retro 15 kHz mode
                                             OPTM_G_LINE,                              -- 65
                                             OPTM_G_VGA,                               -- 66: 15 kHz with HS/VS
                                             OPTM_G_VGA,                               -- 67: 15 kHz with CSYNC
                                             OPTM_G_LINE,                              -- 68
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 69: VGA submenu: END
                                             OPTM_G_SUBMENU,                           -- 70: OSM Scaling submenu: START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 71: OSM Scaling
                                             OPTM_G_LINE,                              -- 72
                                             OPTM_G_OSM_MODE + OPTM_G_STDSEL,          -- 73: 100%, default
                                             OPTM_G_OSM_MODE,                          -- 74: 94%
                                             OPTM_G_OSM_MODE,                          -- 75: 88%
                                             OPTM_G_OSM_MODE,                          -- 76: 81%
                                             OPTM_G_OSM_MODE,                          -- 77: 75%
                                             OPTM_G_OSM_MODE,                          -- 78: 69%
                                             OPTM_G_OSM_MODE,                          -- 79: 63%
                                             OPTM_G_OSM_MODE,                          -- 80: 56%
                                             OPTM_G_OSM_MODE,                          -- 81: 50%
                                             OPTM_G_LINE,                              -- 82
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 83: OSM Scaling submenu: END
                                             OPTM_G_SUBMENU,                           -- 84: Volume submenu: START
                                             OPTM_G_TEXT + OPTM_G_HEADLINE,            -- 85: Volume Control
                                             OPTM_G_LINE,                              -- 86
                                             OPTM_G_VOLUME + OPTM_G_STDSEL,            -- 87: 100%, default
                                             OPTM_G_VOLUME,                            -- 88: 95%
                                             OPTM_G_VOLUME,                            -- 89: 90%
                                             OPTM_G_VOLUME,                            -- 90: 85%
                                             OPTM_G_VOLUME,                            -- 91: 80%
                                             OPTM_G_VOLUME,                            -- 92: 75%
                                             OPTM_G_VOLUME,                            -- 93: 70%
                                             OPTM_G_VOLUME,                            -- 94: 65%
                                             OPTM_G_VOLUME,                            -- 95: 60%
                                             OPTM_G_VOLUME,                            -- 96: 55%
                                             OPTM_G_VOLUME,                            -- 97: 50%
                                             OPTM_G_VOLUME,                            -- 98: 45%
                                             OPTM_G_VOLUME,                            -- 99: 40%
                                             OPTM_G_VOLUME,                            -- 100: 35%
                                             OPTM_G_VOLUME,                            -- 101: 30%
                                             OPTM_G_VOLUME,                            -- 102: 25%
                                             OPTM_G_VOLUME,                            -- 103: 20%
                                             OPTM_G_VOLUME,                            -- 104: 15%
                                             OPTM_G_VOLUME,                            -- 105: 10%
                                             OPTM_G_VOLUME,                            -- 106: 5%
                                             OPTM_G_VOLUME,                            -- 107: 0%
                                             OPTM_G_LINE,                              -- 108
                                             OPTM_G_CLOSE + OPTM_G_SUBMENU,            -- 109: Volume submenu: END
                                             OPTM_G_AUDIO + OPTM_G_SINGLESEL,          -- 110: Audio Improvements
                                             OPTM_G_LINE,                              -- 111
                                             OPTM_G_ABOUT + OPTM_G_HELP,               -- 112: About & Help
                                             OPTM_G_LINE,                              -- 113
                                             OPTM_G_CLOSE                              -- 114: Close Menu
                                           );

--------------------------------------------------------------------------------------------------------------------
-- !!! CAUTION: M2M FRAMEWORK CODE !!! DO NOT TOUCH ANYTHING BELOW THIS LINE !!!
--------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------
-- Address Decoding
--------------------------------------------------------------------------------------------------------------------

begin

addr_decode : process(clk_i)
   -- return ASCII value of given string at the position defined by index (zero-based)
   pure function str2data(str : string; index : integer) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := index + 1;
      if strpos <= str'length then
         return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
      else
         return X"0000"; -- zero terminated strings
      end if;
   end function str2data;

   -- return the dimensions of the Options menu
   pure function getDXDY(dx, dy, index: natural) return std_logic_vector is
   begin
      case index is
         when 0 => return std_logic_vector(to_unsigned(dx + 2, 16));
         when 1 => return std_logic_vector(to_unsigned(dy + 2, 16));
         when others => return X"0000";
      end case;
   end function getDXDY;

   -- convert bool to std_logic_vector
   pure function bool2slv(b: boolean) return std_logic_vector is
   begin
      if b then
         return x"0001";
      else
         return x"0000";
      end if;
   end function bool2slv;

   -- return the General Configuration settings
   function getGenConf(index: natural) return std_logic_vector is
   begin
      case index is
         when 1      => return std_logic_vector(to_unsigned(RESET_COUNTER, 16));
         when 2      => return bool2slv(OPTM_PAUSE);
         when 3      => return bool2slv(WELCOME_ACTIVE);
         when 4      => return bool2slv(WELCOME_AT_RESET);
         when 5      => return bool2slv(KEYBOARD_AT_RESET);
         when 6      => return bool2slv(JOY_1_AT_RESET);
         when 7      => return bool2slv(JOY_2_AT_RESET);
         when 8      => return bool2slv(KEYBOARD_AT_OSD);
         when 9      => return bool2slv(JOY_1_AT_OSD);
         when 10     => return bool2slv(JOY_2_AT_OSD);
         when 11     => return std_logic_vector(to_unsigned(ASCAL_USAGE, 16));
         when 12     => return std_logic_vector(to_unsigned(ASCAL_MODE, 16));
         when 13     => return std_logic_vector(to_unsigned(VD_ANTI_THRASHING_DELAY, 16));
         when 14     => return std_logic_vector(to_unsigned(VD_ITERATION_SIZE, 16));
         when 15     => return bool2slv(SAVE_SETTINGS);
         when others => return x"0000";
      end case;
   end function getGenConf;

   variable index           : integer;
   variable whs_page_index  : integer;
   variable whs_array_index : integer;

begin

   if falling_edge(clk_i) then

      index := to_integer(unsigned(address_i(11 downto 0)));
      whs_page_index  := to_integer(unsigned(address_i(19 downto 12)));
      whs_array_index := to_integer(unsigned(address_i(23 downto 20)));

      data_o <= x"EEEE";

      -----------------------------------------------------------------------------------
      -- Welcome & Help System: upper 4 bits of address equal SEL_WHS' upper 4 bits
      -----------------------------------------------------------------------------------

      if address_i(27 downto 24) = SEL_WHS(15 downto 12) then

         if  whs_array_index < WHS_RECORDS then
            if index = 4095 then
               data_o <= std_logic_vector(to_unsigned(WHS(whs_array_index).page_count, 16));
            else
               if index < WHS(whs_array_index).page_length(whs_page_index) then
                  data_o <= str2data(WHS_DATA, WHS(whs_array_index).page_start(whs_page_index) + index);
               else
                  data_o <= (others => '0'); -- zero-terminated strings
               end if;
            end if;
         end if;

      -----------------------------------------------------------------------------------
      -- All other selectors, which are 16-bit values
      -----------------------------------------------------------------------------------

      else

         case address_i(27 downto 12) is
            when SEL_GENERAL           => data_o <= getGenConf(index);
            when SEL_DIR_START         => data_o <= str2data(DIR_START, index);
            when SEL_CFG_FILE          => data_o <= str2data(CFG_FILE, index);
            when SEL_CORENAME          => data_o <= str2data(CORENAME, index);
            when SEL_OPTM_ITEMS        => data_o <= str2data(OPTM_ITEMS, index);
            when SEL_OPTM_MOUNT_STR    => data_o <= str2data(OPTM_S_MOUNT, index);
            when SEL_OPTM_CRTROM_STR   => data_o <= str2data(OPTM_S_CRTROM, index);
            when SEL_OPTM_SAVING_STR   => data_o <= str2data(OPTM_S_SAVING, index);
            when SEL_OPTM_GROUPS       => data_o <= std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15)) &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(14)) & "0" &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(12)) & "0000" &
                                                    std_logic_vector(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(7 downto 0));
            when SEL_OPTM_STDSEL       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(8));
            when SEL_OPTM_LINES        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(9));
            when SEL_OPTM_START        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(10));
            when SEL_OPTM_MOUNT_DRV    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(11));
            when SEL_OPTM_HELP         => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(13));
            when SEL_OPTM_SINGLESEL    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15));
            when SEL_OPTM_CRTROM       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(16));
            when SEL_OPTM_ICOUNT       => data_o <= x"00" & std_logic_vector(to_unsigned(OPTM_SIZE, 8));
            when SEL_OPTM_DIMENSIONS   => data_o <= getDXDY(OPTM_DX, OPTM_DY, index);
            when SEL_OPTM_DEPS         => if index = 4095 then               -- smart dependencies (OPTM_DEP):
                                            data_o <= x"1DEF";               -- magic "DEPendency Format 1" feature probe
                                          else                               -- per line: {000, flag(b29), item(b28..25), mother(b24..17)}
                                            data_o <= "000" &
                                                      std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(29)) &
                                                      std_logic_vector(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(28 downto 25)) &
                                                      std_logic_vector(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(24 downto 17));
                                          end if;

            when others                => null;
         end case;
      end if;
   end if;
end process;

end architecture beh;
