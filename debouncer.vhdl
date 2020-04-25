library ieee;
use ieee.std_logic_1164.all;

entity debouncer is
	generic(
		log_factor  : natural := 16;
		length      : natural := 8;
		fifo_length : natural := 8
	);
	port(
		clk        : in  std_logic;
		input      : in  std_logic_vector(length-1 downto 0);
		output     : out std_logic_vector(length-1 downto 0)
	);
end debouncer;

architecture rtl of debouncer is
	type debouncer_fifo_t is array(length-1 downto 0) of std_logic_vector(fifo_length-1 downto 0);
	signal debouncer_fifo : debouncer_fifo_t;
	signal count          : natural range 0 to 2**log_factor-1;
	constant ALL_0        : std_logic_vector(fifo_length-1 downto 0) := (others => '0');
	constant ALL_1        : std_logic_vector(fifo_length-1 downto 0) := (others => '1');
begin
	debouncer_filter: for i in 0 to length-1 generate
	begin
		process(clk)
		begin
			if rising_edge(clk) then
				if count = 0 then
					debouncer_fifo(i) <= debouncer_fifo(i)(fifo_length-2 downto 0) & input(i);
					if debouncer_fifo(i) = ALL_0 then
						output(i) <= '0';
					elsif debouncer_fifo(i) = ALL_1 then
						output(i) <= '1';
					end if;
				end if;
			end if;
		end process;
	end generate;

	process(clk)
	begin
		if rising_edge(clk) then
			count <= count+1;
			if count >= 2**log_factor-1 then
				count <= 0;
			end if;
		end if;
	end process;
end rtl;