all: MEGA65-R3.bit

# Specify install location of the Xilinx Vivado tool
XILINX_DIR = /opt/Xilinx/Vivado/2019.2

PPRDIR=.
VHDL2008=\
	$(PPRDIR)/../QNICE/vhdl/alu.vhd \
	$(PPRDIR)/vhdl/debouncer.vhd \
	$(PPRDIR)/vhdl/lcd_to_pixels.vhd \
	$(PPRDIR)/vhdl/mega65.vhd \
	$(PPRDIR)/vhdl/qnice.vhd \
	$(PPRDIR)/vhdl/top_mega65-r3.vhd

VHDL=\
	$(PPRDIR)/../QNICE/vhdl/alu_shifter.vhd \
	$(PPRDIR)/../QNICE/vhdl/basic_uart.vhd \
	$(PPRDIR)/../QNICE/vhdl/block_ram.vhd \
	$(PPRDIR)/../QNICE/vhdl/bus_uart.vhd \
	$(PPRDIR)/../QNICE/vhdl/byte_bram.vhd \
	$(PPRDIR)/../QNICE/vhdl/cpu_constants.vhd \
	$(PPRDIR)/../QNICE/vhdl/EAE.vhd \
	$(PPRDIR)/../QNICE/vhdl/fifo.vhd \
	$(PPRDIR)/../QNICE/vhdl/kbd_constants.vhd \
	$(PPRDIR)/../QNICE/vhdl/qnice_cpu.vhd \
	$(PPRDIR)/../QNICE/vhdl/register_file.vhd \
	$(PPRDIR)/../QNICE/vhdl/sdcard.vhd \
	$(PPRDIR)/../QNICE/vhdl/sd_spi.vhd \
	$(PPRDIR)/../QNICE/vhdl/tools.vhd \
	$(PPRDIR)/../rtl/boot_rom.vhd \
	$(PPRDIR)/../rtl/bus_savestates.vhd \
	$(PPRDIR)/../rtl/gbc_snd.vhd \
	$(PPRDIR)/../rtl/gb_savestates.vhd \
	$(PPRDIR)/../rtl/gb_statemanager.vhd \
	$(PPRDIR)/../rtl/reg_savestates.vhd \
	$(PPRDIR)/../rtl/speedcontrol.vhd \
	$(PPRDIR)/../rtl/T80/GBse.vhd \
	$(PPRDIR)/../rtl/T80/T80_ALU.vhd \
	$(PPRDIR)/../rtl/T80/T80_MCode.vhd \
	$(PPRDIR)/../rtl/T80/T80_Pack.vhd \
	$(PPRDIR)/../rtl/T80/T80_Reg.vhd \
	$(PPRDIR)/../rtl/T80/T80.vhd \
	$(PPRDIR)/vhdl/2port2clk_ram.vhd \
	$(PPRDIR)/vhdl/block_rom.vhd \
	$(PPRDIR)/vhdl/clk.vhd \
	$(PPRDIR)/vhdl/debounce.vhd \
	$(PPRDIR)/vhdl/drivers/kb_matrix_ram.vhdl \
	$(PPRDIR)/vhdl/drivers/matrix_to_keynum.vhdl \
	$(PPRDIR)/vhdl/drivers/mega65kbd_to_matrix.vhdl \
	$(PPRDIR)/vhdl/drivers/pcm_to_pdm.vhdl \
	$(PPRDIR)/vhdl/keyboard.vhd \
	$(PPRDIR)/vhdl/m65_const.vhd \
	$(PPRDIR)/vhdl/qnice_globals.vhd \
	$(PPRDIR)/vhdl/qnice_mmio.vhd \
	$(PPRDIR)/vhdl/vga_controller.vhd

VERILOG=\
	$(PPRDIR)/../rtl/gb.v \
	$(PPRDIR)/../rtl/hdma.v \
	$(PPRDIR)/../rtl/link.v \
	$(PPRDIR)/../rtl/sprites.v \
	$(PPRDIR)/../rtl/timer.v \
	$(PPRDIR)/../rtl/video.v \
	$(PPRDIR)/Verilog/mbc.sv

SOURCES = $(VHDL) $(VHDL2008) $(VERILOG)

# Generate the build script used by Vivado
MEGA65-R3.tcl: MEGA65-R3.xdc Makefile
	echo "# This is a tcl command script for the Vivado tool chain" > $@
	echo "read_vhdl -vhdl2008 { $(VHDL2008) }" >> $@
	echo "read_vhdl { $(VHDL) }" >> $@
	echo "read_verilog { $(VERILOG) }" >> $@
	echo "read_xdc MEGA65-R3.xdc" >> $@
	echo "synth_design -top MEGA65_R3 -part xc7a200tfbg484-1 -flatten_hierarchy none" >> $@
	echo "write_checkpoint -force post_synth.dcp" >> $@
	echo "opt_design" >> $@
	echo "place_design" >> $@
	echo "phys_opt_design" >> $@
	echo "route_design" >> $@
	echo "write_checkpoint -force MEGA65-R3.dcp" >> $@
	echo "write_bitstream -force MEGA65-R3.bit" >> $@
	echo "exit" >> $@

# Generate the bit-file used to configure the FPGA
MEGA65-R3.bit: MEGA65-R3.tcl $(SOURCES) MEGA65-R3.xdc
	bash -c "source $(XILINX_DIR)/settings64.sh ; vivado -mode tcl -source $<"

clean:
	rm -f vivado*
	rm -f post_synth.dcp
	rm -f MEGA65-R3.tcl
	rm -f MEGA65-R3.dcp
	rm -f MEGA65-R3.bit
	rm -f tight_setup_hold_pins.txt

