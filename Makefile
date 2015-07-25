test-afu2host: afu2host mkSyn_AFUToHost.v libBDPIPipe32_VPI.so

verilogsim: mkSyn_StreamManager.v host2afu libBDPIPipe32_VPI.so

libBDPIPipe32_VPI.so:
	echo "// Automatically generated by Makefile" > register.c
	for i in `ls vpi_wrapper_*.h`; do echo "#include \"$$i\"" >> register.c ; done;
	echo "void (*vlog_startup_routines[])() = { " >> register.c
	echo "`ls vpi_wrapper_*.h`" | sed -ne "s/vpi_wrapper_\(.*\)\.h/\1_vpi_register, /p" >> register.c
	echo "0u }; " >> register.c
	gcc -shared -fPIC -m32 -O3 -I/usr/local/Bluespec/lib/VPI -L/usr/local/Bluespec/lib/VPI/g++4 -L../BDPIPipe -g -o $@ vpi_wrapper_*.c register.c -lbdpi -lBDPIPipe32 -lgmp

default: mkSyn_StreamManager.v

check-OStream: mkTB_OStream.v
	vsim -c -do "source testbuf.tcl; vlog $<; simostream"

check-CAPIStream: mkTB_StreamManager.v
	vsim -c -do "source testbuf.tcl; vlog $<; simstream "	

BSC_OPTS=-check-assert -opt-undetermined-vals -unspecified-to X -p +:MMIO:DedicatedAFU:Core:../BlueLogic/Convenience:../BlueLogic/Pipeline:../BDPIPipe

mkSyn_AFUToHost.v: AFUToHostStream.bsv ReadBuf.bsv 
	bsc $(BSC_OPTS) -verilog -u $<
	bsc $(BSC_OPTS) -verilog -g mkSyn_AFUToHost -o $@ $<
	
mkSyn_HostToAFU.v: Test_HostToAFUStream.bsv ReadBuf.bsv 
	bsc $(BSC_OPTS) -verilog -u $<
	bsc $(BSC_OPTS) -verilog -g mkSyn_HostToAFU -o $@ $<
	
host2afu: host2afu.cpp *.hpp
	g++ -g -std=c++11 -fPIC -I/home/jcassidy/src/CAPI/pslse/pslse -L/home/jcassidy/src/CAPI/pslse/pslse -I/home/jcassidy/src -o $@ $< -lcxl -lpthread

afu2host: afu2host.cpp *.hpp
	g++ -g -std=c++11 -fPIC -I/home/jcassidy/src/CAPI/pslse/pslse -L/home/jcassidy/src/CAPI/pslse/pslse -I/home/jcassidy/src -o $@ $< -lcxl -lpthread
