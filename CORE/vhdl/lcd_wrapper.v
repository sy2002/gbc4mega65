/*
   Game Boy and Game Boy Color for MEGA65 (gbc4mega65)

   Verilog wrapper around MiSTer's lcd.v (CORE/GameBoy/lcd.v)

   Two reasons why this wrapper exists:

   1. lcd.v has an input port named "on" which is a reserved word in VHDL, so the module
      cannot be instantiated from main.vhd directly. The wrapper renames it to lcd_on_i.

   2. It hardcodes the gbc4mega65 configuration so that lcd.v itself stays byte-identical
      to the proven MiSTer original:
        * sgb_en = 1 with a black backdrop (sgb_border_pix = 0): this turns lcd.v's
          Super Game Boy border compositing into a plain black frame around the
          160x144 Game Boy picture, resulting in a 256x224 active area - the classic
          SGB screen geometry. This larger canvas is what makes the M2M on-screen-menu
          usable on the analog output (raster 512x448 post-scandoubler = 32x28 chars).
        * double_buffer = 1: tear-free double buffering (like the original gbc4mega65).
        * tint/inv = 0: Game Boy Classic renders in the authentic grayscale.
        * frame_blend = 0: no frame blending (kept off like in the original core).

   The color grading feature of the original gbc4mega65 core maps to lcd.v's
   "originalcolors" input: originalcolors = 1 shows the raw, fully saturated GBC colors,
   originalcolors = 0 applies MiSTer's GBC LCD color correction.

   This machine is based on Gameboy_MiSTer
   Powered by MiSTer2MEGA65
   MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
*/

module lcd_wrapper
(
   // Game Boy core side (clk_sys = 33.554432 MHz domain)
   input         clk_sys,
   input         ce,               // 4.19 MHz clock enable from speedcontrol
   input         lcd_clkena,       // pixel strobe from gb.v
   input         lcd_vsync,        // frame sync from gb.v
   input  [14:0] lcd_data,         // pixel data from gb.v
   input   [1:0] lcd_mode,         // PPU mode from gb.v
   input         lcd_on,           // LCDC bit 7 from gb.v

   // configuration
   input         isGBC,            // Game Boy Color mode
   input         originalcolors,   // 1 = fully saturated raw colors, 0 = LCD emulation

   // video output side (clk_vid = 67.108864 MHz domain = 2x clk_sys)
   input         clk_vid,
   output        ce_pix,           // ~6.71 MHz pixel clock enable
   output        hs,
   output        vs,
   output        hbl,
   output        vbl,
   output  [7:0] r,
   output  [7:0] g,
   output  [7:0] b
);

lcd lcd_inst
(
   .clk_sys        ( clk_sys        ),
   .ce             ( ce             ),
   .lcd_clkena     ( lcd_clkena     ),
   .lcd_vs         ( lcd_vsync      ),
   .data           ( lcd_data       ),
   .mode           ( lcd_mode       ),
   .isGBC          ( isGBC          ),
   .double_buffer  ( 1'b1           ),

   .pal1           ( 24'd0          ),   // unused: tint = 0 selects the grayscale palette
   .pal2           ( 24'd0          ),
   .pal3           ( 24'd0          ),
   .pal4           ( 24'd0          ),

   .sgb_border_pix ( 16'h0000       ),   // bit 15 = 0: backdrop mode, color = black
   .sgb_pal_en     ( 1'b0           ),
   .sgb_en         ( 1'b1           ),   // 256x224 active area with black border

   .tint           ( 1'b0           ),
   .inv            ( 1'b0           ),
   .frame_blend    ( 1'b0           ),
   .originalcolors ( originalcolors ),

   .on             ( lcd_on         ),

   .clk_vid        ( clk_vid        ),
   .ce_pix         ( ce_pix         ),
   .hs             ( hs             ),
   .vs             ( vs             ),
   .hbl            ( hbl            ),
   .vbl            ( vbl            ),
   .h_cnt          (                ),
   .v_cnt          (                ),
   .r              ( r              ),
   .g              ( g              ),
   .b              ( b              )
);

endmodule
