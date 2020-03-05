--------------------------------------------------------------------
-- ECE40170 FPGA Final Project                                             
--                                                                   
-- Author:                                              
-- Date:                                                    
--                                                                  
-- Module Description:                                              
-- ?                                                  
--                                                                  
--                                                                  
-- Module Name: ?.vhd                                 
--                                                                  
-- Revision History                                                 
-- Date      Init    Description                                    
-- xx/xx/    ?     Initial Release                                
--                                                                  
--------------------------------------------------------------------            
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;


entity clocks is
    port (   CLK         : in std_logic;
             RSTN        : in std_logic;
             CKE_50M     : out std_logic;
             CLK_100M    : out std_logic;
             CLK_FS_DIV2 : out std_logic
             );
end clocks;


architecture rtl of clocks is

component fpga_clk is
port
 (-- Clock in ports
  CLK_IN1           : in     std_logic;
  -- Clock out ports
  CLK_OUT1          : out    std_logic;
  CLK_OUT2          : out    std_logic;
  -- Status and control signals
  RESET             : in     std_logic;
  LOCKED            : out    std_logic
 );
end component;

signal cke_50m_i   : std_logic;
signal clk_count   : natural;
signal locked      : std_logic;
signal clk_fs_50m  : std_logic;
signal dcm_rst     : std_logic;
signal clk_buf_100m : std_logic;

begin

-- These two clocks are synchronized
CLK_100M <= clk_buf_100m;
CKE_50M <= cke_50m_i;

cke_gen : process (RSTN, clk_buf_100m)
begin
if (RSTN = '0') then
   cke_50m_i <= '0';
   clk_count <= 0;
elsif (clk_buf_100m'event and clk_buf_100m = '1') then
   if (clk_count = 1) then
       cke_50m_i <= '1';
       clk_count <= 0;
    else
       cke_50m_i <= '0';
       clk_count <= clk_count + 1;
    end if;   
end if;
end process;

dcm_rst <= not RSTN;    

u_fpga_clk : fpga_clk
port map(-- Clock in ports
         CLK_IN1            => CLK,
         -- Clock out ports
         CLK_OUT1           => clk_buf_100m,
         CLK_OUT2           => CLK_FS_DIV2,
         -- Status and control signals
         RESET              => dcm_rst,
         LOCKED             => locked
         );

end rtl;

