library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity clk_div_n is
	generic(
		factor_length : natural := 16
	);
	port(
		clk_in        : in  std_logic;
		edge_in       : in  std_logic;
		half_factor   : in  std_logic_vector(factor_length-1 downto 0);
		clk_out       : out std_logic;
		edge_out      : out std_logic
	);
end clk_div_n;

architecture rtl of clk_div_n is
	signal count : natural range 0 to 2**factor_length-1;
	signal clk   : std_logic := '0';
	signal clk_p : std_logic;
begin
	clk_out <= clk;
	edge_out <= clk and not clk_p;
	process(clk_in)
	begin
		if rising_edge(clk_in) then
			if edge_in = '1' then
				count <= count+1;
				if count >= half_factor then
					clk <= not clk;
					count <= 0;
				end if;
				clk_p <= clk;
			end if;
		end if;
	end process;
end rtl;