library ieee;
use ieee.std_logic_1164.all;

entity pacman is
	port(
		-- Default system signals
		clk_25MHz     : in  std_logic;
		reset_n       : in  std_logic;

		-- Game switches & controls
		game_start_n  : in  std_logic;
		game_speed    : in  std_logic_vector(1 downto 0);

		-- Keyboard Interface
		keyboard_clk  : in  std_logic;
		keyboard_data : in  std_logic;

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
	signal game_start_n_signal  : std_logic;
	signal game_speed_signal    : std_logic_vector(1 downto 0);
	signal game_controls        : std_logic_vector(4 downto 0);
	signal game_data            : std_logic_vector(37 downto 0);

	-- Keyboard signals
	signal scan_code            : std_logic_vector(7 downto 0);
	signal scan_code_filter     : std_logic_vector(7 downto 0);

	-- 7-Segment Display signals
	signal display_data         : std_logic_vector(7 downto 0);

	-- Debouncer signals
	signal reset_n_signal       : std_logic;
	signal reset_signal         : std_logic;
	signal debouncer_input      : std_logic_vector(3 downto 0);
	signal debouncer_output     : std_logic_vector(3 downto 0);

	-- Auxiliary signals
	signal reset                : std_logic;
	signal vcc                  : std_logic := '1';
	signal gnd                  : std_logic := '0';

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
	component keyboard
		port(
			keyboard_clk  : in  std_logic;
			keyboard_data : in  std_logic;
			clock_25Mhz   : in  std_logic;
			reset         : in  std_logic;
			read          : in  std_logic;
			scan_code     : out std_logic_vector(7 downto 0);
			scan_ready    : out std_logic
		);
	end component;
	component display7
		port(
			data     : in  std_logic_vector(3 downto 0);
			segments : out std_logic_vector(6 downto 0)
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
begin
	-- General components section
	core_0:      pacman_core port map(clk_25MHz => clk_25MHz, reset_n => reset_n_signal, game_speed => game_speed_signal, game_controls => game_controls, game_data => game_data, horz_sync => horz_sync, vert_sync => vert_sync, red => red, green => green, blue => blue);
	keyboard_0:  keyboard    port map(keyboard_clk => keyboard_clk, keyboard_data => keyboard_data, clock_25Mhz => clk_25MHz, reset => reset_signal, read => vcc, scan_code => scan_code);
	display7_0:  display7    port map(data => display_data(3 downto 0), segments => display(6 downto 0));
	display7_1:  display7    port map(data => display_data(7 downto 4), segments => display(13 downto 7));
	debouncer_0: debouncer   generic map(log_factor => 10, length => 4, fifo_length => 4) port map(clk => clk_25MHz, input => debouncer_input, output => debouncer_output);

	-- Keyboard section
	game_controls(4) <= not game_start_n_signal; -- Start
	with scan_code_filter select game_controls(3) <= '1' when "01110101", '0' when others; -- Up
	with scan_code_filter select game_controls(2) <= '1' when "01110010", '0' when others; -- Down
	with scan_code_filter select game_controls(1) <= '1' when "01101011", '0' when others; -- Left
	with scan_code_filter select game_controls(0) <= '1' when "01110100", '0' when others; -- Right

	-- 7-Segment Display section
	display_data <= game_data(11 downto 4);

	-- Debouncer section
	debouncer_input(0)          <= reset_n;
	debouncer_input(1)          <= game_start_n;
	debouncer_input(3 downto 2) <= game_speed;
	reset_n_signal       <= debouncer_output(0);
	game_start_n_signal  <= debouncer_output(1);
	game_speed_signal    <= debouncer_output(3 downto 2);
	reset_signal         <= not reset_n_signal;

	-- Auxiliary section
	reset <= not reset_n;
	vcc   <= '1';
	gnd   <= '0';

	keyboard_filter: process(clk_25MHz)
	begin
		if rising_edge(clk_25MHz) then
			if scan_code = "01110101"
			or scan_code = "01110010"
			or scan_code = "01101011"
			or scan_code = "01110100" then
				scan_code_filter <= scan_code;
			end if;
		end if;
	end process;
end rtl;