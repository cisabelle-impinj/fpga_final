-makelib ies_lib/xil_defaultlib -sv \
  "C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
-endlib
-makelib ies_lib/xpm \
  "C:/Xilinx/Vivado/2018.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib ies_lib/xil_defaultlib \
  "../../../ip/FPGA_CLK/FPGA_CLK_clk_wiz.v" \
  "../../../ip/FPGA_CLK/FPGA_CLK.v" \
-endlib
-makelib ies_lib/xil_defaultlib \
  glbl.v
-endlib

