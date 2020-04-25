library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

entity vga_sync is
	port(
		clk_25Mhz    : in  std_logic;
		red_in       : in  std_logic;
		green_in     : in  std_logic;
		blue_in      : in  std_logic;
		red_out      : out std_logic;
		green_out    : out std_logic;
		blue_out     : out std_logic;
		horz_sync    : out std_logic;
		vert_sync    : out std_logic;
		video_x      : out std_logic_vector(9 downto 0);
		video_y      : out std_logic_vector(9 downto 0)
	);
end vga_sync;

architecture rtl of vga_sync is
	signal horz_sync_signal : std_logic;
	signal vert_sync_signal : std_logic;
	signal video_on_v       : std_logic;
	signal video_on_h       : std_logic;
	signal video_on         : std_logic;
	signal h_count          : std_logic_vector(9 downto 0);
	signal v_count          : std_logic_vector(9 downto 0);
begin
	video_on <= video_on_h and video_on_v;
	process(clk_25Mhz)
	begin
		if rising_edge(clk_25Mhz) then
			h_count <= h_count+1;
			if h_count >= 799 then
				h_count <= conv_std_logic_vector(0, 10);
			end if;
			if 659 <= h_count and h_count <= 755 then
				horz_sync_signal <= '0';
			else
				horz_sync_signal <= '1';
			end if;
			if h_count >= 699 then
				v_count <= v_count+1;
				if v_count >= 524 then
					v_count <= conv_std_logic_vector(0, 10);
				end if;
			end if;
			if 493 >= v_count and v_count <= 494 then
				vert_sync_signal <= '0';
			else
				vert_sync_signal <= '1';
			end if;
			if h_count <= 639 then
				video_on_h <= '1';
				video_x <= h_count;
			else
				video_on_h <= '0';
			end if;
			if (v_count <= 479) then
				video_on_v <= '1';
				video_y <= v_count;
			else
				video_on_v <= '0';
			end if;

			red_out   <= red_in   and video_on;
			green_out <= green_in and video_on;
			blue_out  <= blue_in  and video_on;
			horz_sync <= horz_sync_signal;
			vert_sync <= vert_sync_signal;
		end if;
	end process;
end rtl;