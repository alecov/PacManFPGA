library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity display7 is
	port(
		data     : in  std_logic_vector(3 downto 0);
		segments : out std_logic_vector(6 downto 0)
	);
end display7;

architecture rtl of display7 is
begin
	process(data)
	begin
		case conv_integer(data) is
			when 0 => segments <= "0000001";
			when 1 => segments <= "1001111";
			when 2 => segments <= "0010010";
			when 3 => segments <= "0000110";
			when 4 => segments <= "1001100";
			when 5 => segments <= "0100100";
			when 6 => segments <= "0100000";
			when 7 => segments <= "0001111";
			when 8 => segments <= "0000000";
			when 9 => segments <= "0000100";
			when 10 => segments <= "0001000";
			when 11 => segments <= "1100000";
			when 12 => segments <= "0110001";
			when 13 => segments <= "1000010";
			when 14 => segments <= "0110000";
			when 15 => segments <= "0111000";
			when others => segments <= "0110000";
		end case;
	end process;
end rtl;