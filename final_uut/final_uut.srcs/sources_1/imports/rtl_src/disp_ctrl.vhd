------------------------------------------------------------------------
-- This module implements final course project for
-- UCSD Extension 138569_SP19_OL
--
-- Engineer: Chris Isabelle
--
--  Inputs:
--      mclk     - system clock (100Mhz Oscillator)
--      btn      - buttons on the Nexys4 board
--      swt      - switches 
--
--  Outputs:
--      led      - discrete LEDs on the Nexys4 board 
--      an       - anode lines for the 7-seg displays
--      ssg      - cathodes (segment lines)
--
------------------------------------------------------------------------
-- Revision History:
--  06/08/2019 : ported from lab6
--  06/08/2019 : FPGA_CLK ported from lab3
------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity disp_ctrl is
    port (
        MCLK        : in std_logic;                         -- 100 Mhz clock input
        CPU_RESETN  : in std_logic;                         -- Button RESETN
        BTNC        : in std_logic;                         -- Button BTNC
        BTND        : in std_logic;                         -- Button BTND
        SWT         : in std_logic_vector(1 downto 0);      -- SW1-SW0
        LED         : out std_logic_vector(15 downto 0);    -- LED15-LED0
        AN          : out std_logic_vector(7 downto 0);     -- AN7-AN0
        SSG         : out std_logic_vector(7 downto 0));    -- 7-seg display mapped as .gfedcba
end disp_ctrl;

architecture rtl of disp_ctrl is

component clocks is
    port (   CLK         : in std_logic;
             RSTN        : in std_logic;
             CKE_50M     : out std_logic;
             CLK_100M    : out std_logic;
             CLK_FS_DIV2 : out std_logic
             );
end component;

constant C_REFRESH_PERIOD               : natural := 500000;
signal clkdiv                           : natural;
signal clkdiv2                          : std_logic_vector(31 downto 0);
signal cntr                             : std_logic_vector(3 downto 0);
signal dig                              : std_logic_vector(7 downto 0);
signal cke_50m                          : std_logic;
signal clk_en                           : std_logic;
signal rstn                             : std_logic;
signal btncn                            : std_logic;
signal btndn                            : std_logic;
signal btncn_t_minus_one                : std_logic;
signal btndn_t_minus_one                : std_logic;
signal btncn_edge                       : std_logic;
signal btndn_edge                       : std_logic;
signal btncn_latch                      : std_logic;
signal btndn_latch                      : std_logic;
signal clk100                           : std_logic;
signal clk_fs_div2                      : std_logic;
signal led_cfg_reg                      : std_logic_vector(15 downto 0);
signal led_reg_shift_left               : std_logic;        
signal led_reg_on                       : std_logic;        
signal led_reg_flash                    : std_logic;
signal led_reg_flash_on                 : std_logic;
signal led_strobe                       : std_logic;
-- SSG Config Registers are numbered left to right
signal ssg_cfg_reg1                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg2                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg3                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg4                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg5                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg6                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg7                     : std_logic_vector(4 downto 0);
signal ssg_cfg_reg8                     : std_logic_vector(4 downto 0);
signal dig_data_tmp                     : std_logic_vector(4 downto 0);

begin

-- Using CPU RESET as rstn
rstn <= CPU_RESETN;
btncn <= BTNC;
btndn <= BTND;

-- Port map to the clocks block
u_clocks : clocks
   port map( CLK         => MCLK,
             RSTN        => rstn,
             CKE_50M     => cke_50m, 
             CLK_100M    => clk100,
             CLK_FS_DIV2 => clk_fs_div2  
             );

-- Button edge detect & decode logic
button_detect : process (rstn, clk100) 
begin                  
    if (rstn = '0') then
       btncn_t_minus_one <= '0';
       btndn_t_minus_one <= '0';
       btncn_latch <= '0';
       btndn_latch <= '0';
    elsif ( clk100'event and clk100 = '1') then 
    -- Edge detect logic
        btncn_t_minus_one <= btncn; 
        btndn_t_minus_one <= btndn; 
    -- Decided to make this an elsif to avoid a race condition in the 
    -- event that BTNC & BTND go true during the same clk100 cycle.
    -- In this case the fibonacci numbers win!!!
        if(btncn = '1' and btncn_t_minus_one = '0') then
            btncn_latch <= '1';
            btndn_latch <= '0';
        elsif(btndn = '1' and btndn_t_minus_one = '0') then
            btncn_latch <= '0';
            btndn_latch <= '1';
        end if;    
    end if;    
end process;

-- FSM implements Functional Requirements
switch_detect : process (rstn, clk100) 
begin
    if (rstn = '0') then
        ssg_cfg_reg1 <= "10001";
        ssg_cfg_reg2 <= "01101";
        ssg_cfg_reg3 <= "10010";
        ssg_cfg_reg4 <= "01110";
        ssg_cfg_reg5 <= "11111"; 
        ssg_cfg_reg6 <= "11111";
        ssg_cfg_reg7 <= "11111";
        ssg_cfg_reg8 <= "11111";
        led_reg_on <= '0';        
        led_reg_flash <= '0';
        led_reg_shift_left <= '1';        
    elsif ( clk100'event and clk100 = '1') then 
        if (SWT(0) = '1' and SWT(1) = '1') then
        -- led reg enable shift left
            led_reg_on <= '0';        
            led_reg_flash <= '0';        
            led_reg_shift_left <= '1';        
        -- display "Error"
            ssg_cfg_reg1 <= "01110"; 
            ssg_cfg_reg2 <= "01111";
            ssg_cfg_reg3 <= "01111";
            ssg_cfg_reg4 <= "10011";    
            ssg_cfg_reg5 <= "01111"; 
            ssg_cfg_reg6 <= "11111";
            ssg_cfg_reg7 <= "11111";
            ssg_cfg_reg8 <= "11111";
        else
            if (SWT(0) = '0' and SWT(1) = '0') then
        -- led reg enable off
                led_reg_on <= '0';        
                led_reg_flash <= '0';
                led_reg_shift_left <= '0';        
            elsif (SWT(0) = '1' and SWT(1) = '0') then
        -- led reg enable on
                led_reg_on <= '1';        
                led_reg_flash <= '0';
                led_reg_shift_left <= '0';        
            else
        -- led reg enable flash
                led_reg_on <= '0';        
                led_reg_flash <= '1';
                led_reg_shift_left <= '0';        
            end if;
            if (btncn_latch = '1') then
        -- display "11235813"
                ssg_cfg_reg1 <= "00001"; 
                ssg_cfg_reg2 <= "00001";
                ssg_cfg_reg3 <= "00010";
                ssg_cfg_reg4 <= "00011";    
                ssg_cfg_reg5 <= "00101"; 
                ssg_cfg_reg6 <= "01000";
                ssg_cfg_reg7 <= "00001";
                ssg_cfg_reg8 <= "00011";
            elsif (btndn_latch = '1') then
        -- display "HELLO"
                ssg_cfg_reg1 <= "10000";
                ssg_cfg_reg2 <= "01110";
                ssg_cfg_reg3 <= "10010";
                ssg_cfg_reg4 <= "10010";    
                ssg_cfg_reg5 <= "00000"; 
                ssg_cfg_reg6 <= "11111";
                ssg_cfg_reg7 <= "11111";
                ssg_cfg_reg8 <= "11111";    
            else
        -- display "Idle"
                ssg_cfg_reg1 <= "10001";
                ssg_cfg_reg2 <= "01101";
                ssg_cfg_reg3 <= "10010";
                ssg_cfg_reg4 <= "01110";    
                ssg_cfg_reg5 <= "11111"; 
                ssg_cfg_reg6 <= "11111";
                ssg_cfg_reg7 <= "11111";
                ssg_cfg_reg8 <= "11111";
            end if;
        end if;    
    end if;    
end process;

-- Counter logic counts to 5E7 then creates a 
-- single cycle enable signal to drive led_strobe
-- 5 * 10^7 * 10 ns = 500 msec
clk_en_proc: process ( rstn, clk100) 
begin                  
if (rstn = '0') then
   clkdiv2 <= (others => '0');
   clk_en <= '0';
elsif ( clk100'event and clk100 = '1') then
     if (clkdiv2 = 5E7) then 
        clkdiv2 <= (others => '0');
        led_strobe <= '1';
     else
        clkdiv2 <= clkdiv2 + 1;
        led_strobe <= '0';
     end if;
end if;
end process;

-- LED Driver
led_driver_proc: process ( rstn, clk100) 
begin                  
    if (rstn = '0') then
        led_cfg_reg <= "0000000000000000";
    elsif ( clk100'event and clk100 = '1') then
        if (led_reg_on = '1') then
            led_cfg_reg <= "1111111111111111";
        elsif (led_reg_flash = '1') then
            if (led_strobe = '1') then
                if(led_reg_flash_on = '1') then
                    led_cfg_reg <= "1111111111111111";
                    led_reg_flash_on <= '0';
                else
                    led_cfg_reg <= "0000000000000000";
                    led_reg_flash_on <= '1';
                end if;                    
            end if;                    
        elsif (led_reg_shift_left = '1') then
            if ((led_cfg_reg = "0000000000000000") or (led_cfg_reg = "1111111111111111")) then
                led_cfg_reg <= "0000000000000001";
            end if;
            if (led_strobe = '1') then
                led_cfg_reg <= led_cfg_reg(14 downto 0) & led_cfg_reg(15);
            end if;
        else
            led_cfg_reg <= "0000000000000000";
        end if;
    end if;
end process;

LED <= led_cfg_reg;       

-- Refresh driver for SSG
refresh_proc: process (rstn, clk100) 
begin                  
    if (rstn = '0') then
       clkdiv <= 0;
       AN <= "11111111";
       dig_data_tmp <= (others => '0');
    elsif ( clk100'event and clk100 = '1') then
         clkdiv <= clkdiv + 1;
-- Spend 1/8 of C_REFRESH_PERIOD on driving each of the 8 SSG displays
         if (clkdiv = C_REFRESH_PERIOD) then 
            clkdiv <= 0;
         elsif (clkdiv > 0 and clkdiv <= (C_REFRESH_PERIOD*1/8)) then
            AN <= "01111111";
            dig_data_tmp <= ssg_cfg_reg1;
         elsif (clkdiv > (C_REFRESH_PERIOD*1/8) and clkdiv <= (C_REFRESH_PERIOD*2)/8) then
            AN <= "10111111";
            dig_data_tmp <= ssg_cfg_reg2;
         elsif (clkdiv > (C_REFRESH_PERIOD*2)/8 and clkdiv <= (C_REFRESH_PERIOD*3)/8) then
            AN <= "11011111";
            dig_data_tmp <= ssg_cfg_reg3;
         elsif (clkdiv > (C_REFRESH_PERIOD*3)/8 and clkdiv <= (C_REFRESH_PERIOD*4)/8) then
            AN <= "11101111";	
            dig_data_tmp <= ssg_cfg_reg4;
         elsif (clkdiv > (C_REFRESH_PERIOD*4)/8 and clkdiv <= (C_REFRESH_PERIOD*5)/8) then
            AN <= "11110111";
            dig_data_tmp <= ssg_cfg_reg5;
         elsif (clkdiv > (C_REFRESH_PERIOD*5)/8 and clkdiv <= (C_REFRESH_PERIOD*6)/8) then
            AN <= "11111011";
            dig_data_tmp <= ssg_cfg_reg6;
         elsif (clkdiv > (C_REFRESH_PERIOD*6)/8 and clkdiv <= (C_REFRESH_PERIOD*7)/8) then
            AN <= "11111101";
            dig_data_tmp <= ssg_cfg_reg7;
         elsif (clkdiv > (C_REFRESH_PERIOD*7)/8 and clkdiv <= (C_REFRESH_PERIOD-1)) then
            AN <= "11111110";    
            dig_data_tmp <= ssg_cfg_reg8;
         end if;
    end if;
end process;

SSG(7 downto 0) <= not dig;  

dig <= -- gfedcba
    "00111111" when dig_data_tmp = "00000" else      -- display 0 when dig_data_tmp equals 00000 
    "00000110" when dig_data_tmp = "00001" else      -- display 1 when dig_data_tmp equals 00001 
    "01011011" when dig_data_tmp = "00010" else      -- display 2 when dig_data_tmp equals 00010
    "01001111" when dig_data_tmp = "00011" else      -- display 3 when dig_data_tmp equals 00011
    "01100110" when dig_data_tmp = "00100" else      -- display 4 when dig_data_tmp equals 00100
    "01101101" when dig_data_tmp = "00101" else      -- display 5 when dig_data_tmp equals 00101
    "01111101" when dig_data_tmp = "00110" else      -- display 6 when dig_data_tmp equals 00110
    "00000111" when dig_data_tmp = "00111" else      -- display 7 when dig_data_tmp equals 00111
    "01111111" when dig_data_tmp = "01000" else      -- display 8 when dig_data_tmp equals 01000
    "01101111" when dig_data_tmp = "01001" else      -- display 9 when dig_data_tmp equals 01001
    "01110111" when dig_data_tmp = "01010" else      -- display A when dig_data_tmp equals 01010
    "00111110" when dig_data_tmp = "01011" else      -- display B when dig_data_tmp equals 01011
    "00111001" when dig_data_tmp = "01100" else      -- display C when dig_data_tmp equals 01100
    "01011110" when dig_data_tmp = "01101" else      -- display d when dig_data_tmp equals 01101
    "01111001" when dig_data_tmp = "01110" else      -- display E when dig_data_tmp equals 01110
    "01010000" when dig_data_tmp = "01111" else      -- display r when dig_data_tmp equals 01111
    "01110110" when dig_data_tmp = "10000" else      -- display H when dig_data_tmp equals 10000
    "00110000" when dig_data_tmp = "10001" else      -- display I when dig_data_tmp equals 10001
    "00111000" when dig_data_tmp = "10010" else      -- display L when dig_data_tmp equals 10010
    "01011100" when dig_data_tmp = "10011" else      -- display o when dig_data_tmp equals 10011
    "00000000";                                      -- else blank display, use dig_data_tmp equals 11111        

end rtl;
