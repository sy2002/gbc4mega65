all:	gbc.bit

VIVADO=	./vivado_wrapper

QNICE/tools:
	git submodule update --init --recursive

QNICE/c/qnice/qniceconv:	QNICE/tools
	( cd QNICE/tools ; yes "" | ./make-toolchain.sh )

MEGA65/QNICE/osm_rom.rom:	QNICE/c/qnice/qniceconv
	( cd MEGA65/QNICE ; ./make_rom.sh )

gbc.bit:	MEGA65/QNICE/osm_rom.rom
	mkdir -p bin
	$(VIVADO) -mode batch -source MEGA65/mega65r3_impl.tcl MEGA65/MEGA65-R3.xpr

clean:
	rm -fr QNICE/tools
	rm QNICE/c/qnice/qniceconv
	rm MEGA65/QNICE/osm_rom.rom
	git submodule deinit --all -f
