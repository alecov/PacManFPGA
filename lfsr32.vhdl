library ieee;
use ieee.std_logic_1164.all;

entity LFSR32 is
	generic(
		output_length : natural := 32
	);
	port(
		clk           : in  std_logic;
		seed_enable_n : in  std_logic;
		seed_input    : in  std_logic_vector(31 downto 0);
		output        : out std_logic_vector(output_length-1 downto 0)
	);
end LFSR32;

architecture rtl of LFSR32 is
	signal fifo        : std_logic_vector(31 downto 0);
	signal fifo_output : std_logic_vector(output_length-1 downto 0);
begin
	output <= fifo_output;
	process(clk, seed_enable_n, seed_input)
	begin
		if seed_enable_n = '0' then
			fifo <= seed_input;
		elsif rising_edge(clk) then
			fifo <= fifo(30 downto 0) & not (fifo(31) xor fifo(21) xor fifo(1) xor fifo(0));
			fifo_output <= fifo_output(output_length-2 downto 0) & fifo(31);
		end if;
	end process;
end rtl;