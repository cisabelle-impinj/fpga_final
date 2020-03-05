onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib FPGA_CLK_opt

do {wave.do}

view wave
view structure
view signals

do {FPGA_CLK.udo}

run -all

quit -force
