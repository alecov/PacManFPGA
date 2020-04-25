library ieee;
use ieee.std_logic_1164.all;

entity pacman is
	port(
		-- Default system signals
		clk_25MHz     : in  std_logic;
		reset_n       : in  std_logic;

		-- Game switches & controls
		game_speed    : in  std_logic_vector(1 downto 0);
		game_controls : in  std_logic_vector(4 downto 0);

		-- VGA Interface
		horz_sync     : out std_logic;
		vert_sync     : out std_logic;
		red           : out std_logic;
		green         : out std_logic;
		blue          : out std_logic;

		-- 7-Segment Display Interface
		display       : out std_logic_vector(13 downto 0)
	);
end pacman;

architecture rtl of pacman is
	-- Core signals
	signal reset_n_signal       : std_logic;
	signal game_speed_signal    : std_logic_vector(1 downto 0);
	signal game_controls_signal : std_logic_vector(4 downto 0);
	signal game_data_signal     : std_logic_vector(37 downto 0);

	-- Debouncer signals
	signal debouncer_input      : std_logic_vector(7 downto 0);
	signal debouncer_output     : std_logic_vector(7 downto 0);

	-- 7-Segment Display signals
	signal display_data         : std_logic_vector(7 downto 0);

	component pacman_core
		port(
			-- Default system signals
			clk_25MHz     : in  std_logic;
			reset_n       : in  std_logic;

			-- Game switches & controls
			game_speed    : in  std_logic_vector(1 downto 0);
			game_controls : in  std_logic_vector(4 downto 0);
			game_data     : out std_logic_vector(37 downto 0);

			-- VGA Interface
			horz_sync     : out std_logic;
			vert_sync     : out std_logic;
			red           : out std_logic;
			green         : out std_logic;
			blue          : out std_logic
		);
	end component;
	component debouncer
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
	end component;
	component display7
		port(
			data     : in  std_logic_vector(3 downto 0);
			segments : out std_logic_vector(6 downto 0)
		);
	end component;
begin
	-- General components section
	core_0:      pacman_core port map(clk_25MHz => clk_25MHz, reset_n => reset_n_signal, game_speed => game_speed_signal, game_controls => game_controls_signal, game_data => game_data_signal, horz_sync => horz_sync, vert_sync => vert_sync, red => red, green => green, blue => blue);
	display7_0:  display7    port map(data => display_data(3 downto 0), segments => display(6 downto 0));
	display7_1:  display7    port map(data => display_data(7 downto 4), segments => display(13 downto 7));
	debouncer_0: debouncer   generic map(log_factor => 10, length => 8, fifo_length => 4) port map(clk => clk_25MHz, input => debouncer_input, output => debouncer_output);

	-- Debouncer section
	debouncer_input(0)          <= reset_n;
	debouncer_input(2 downto 1) <= game_speed;
	debouncer_input(7 downto 3) <= game_controls;
	reset_n_signal       <= debouncer_output(0);
	game_speed_signal    <= debouncer_output(2 downto 1);
	game_controls_signal <= debouncer_output(7 downto 3);

	-- Output section
	display_data <= game_data_signal(37 downto 30);
end rtl;