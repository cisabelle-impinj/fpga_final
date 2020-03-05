onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+FPGA_CLK -L xil_defaultlib -L xpm -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.FPGA_CLK xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {FPGA_CLK.udo}

run -all

endsim

quit -force
