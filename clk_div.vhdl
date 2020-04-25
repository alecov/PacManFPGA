library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity clk_div is
	generic(
		log_factor : natural := 24
	);
	port(
		clk_in     : in  std_logic;
		edge_in    : in  std_logic;
		clk_out    : out std_logic;
		edge_out   : out std_logic
	);
end clk_div;

architecture rtl of clk_div is
	signal count : std_logic_vector(log_factor-1 downto 0);
	signal clk   : std_logic;
	signal clk_p : std_logic;
begin
	clk <= count(log_factor-1);
	clk_out <= clk;
	edge_out <= clk and not clk_p;
	process(clk_in)
	begin
		if rising_edge(clk_in) then
			if edge_in = '1' then
				count <= conv_std_logic_vector(conv_integer(count)+1, log_factor);
				clk_p <= count(log_factor-1);
			end if;
		end if;
	end process;
end rtl;