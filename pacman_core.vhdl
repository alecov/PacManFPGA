library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

library lpm;
use lpm.lpm_components.all;

library work;
use work.pacman_types.all;

entity pacman_core is
	port(
		-- Default system signals
		clk_25Mhz     : in  std_logic;
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
end pacman_core;

architecture rtl of pacman_core is
	-- Game signals
	type game_state_t is (game_reset, game_load_splash, game_start_splash, game_start_splash_wait, game_splash, game_initialize, game_load_map_start, game_load_map_step_1, game_load_map_step_2, game_load_map_step_3, game_load_map_end, game_start, game_start_wait, game_playing, game_eat_pellet_start, game_eat_pellet_step_1, game_eat_pellet_step_2, game_eat_pellet_end, game_pacman_dead, game_win_map);
	signal game_state                     : game_state_t;
	signal game_state_signal              : game_state_t;
	signal game_process_state             : game_process_state_t;
	signal game_process_state_signal      : game_process_state_t;
	signal game_speed_base                : speed_base_t;
	signal game_clk_base                  : std_logic;
	signal game_clk                       : std_logic;

	alias  game_control_start             : std_logic is game_controls(4);
	alias  game_control_up                : std_logic is game_controls(3);
	alias  game_control_down              : std_logic is game_controls(2);
	alias  game_control_left              : std_logic is game_controls(1);
	alias  game_control_right             : std_logic is game_controls(0);

	signal level_speed                    : speed_t;
	signal level_ai                       : ghost_ai_t;

	signal pacman_clk                     : std_logic;
	signal ghost_clk                      : std_logic_vector(MAX_GHOSTS-1 downto 0);
	signal ghost_fast_clk                 : std_logic;
	signal ghost_normal_clk               : std_logic;
	signal ghost_slow_clk                 : std_logic;

	signal pacman_x                       : position_t;
	signal pacman_y                       : position_t;
	signal pacman_sp_x                    : position_t;
	signal pacman_sp_y                    : position_t;
	signal pacman_north                   : pacman_cell;
	signal pacman_south                   : pacman_cell;
	signal pacman_west                    : pacman_cell;
	signal pacman_east                    : pacman_cell;
	signal pacman_current                 : pacman_cell;
	signal pacman_direction               : direction_t;
	signal pacman_change_direction        : direction_t;
	signal pacman_next_direction          : direction_t;
	signal pacman_next_x                  : position_t;
	signal pacman_next_y                  : position_t;
	signal pacman_next                    : pacman_cell;
	signal pacman_state                   : pacman_state_t;
	signal pacman_lives                   : std_logic_vector(3 downto 0);
	signal pacman_pellets                 : std_logic_vector(9 downto 0);
	signal pacman_score                   : std_logic_vector(15 downto 0);
	signal pacman_level                   : std_logic_vector(3 downto 0);
	signal pacman_super_time              : std_logic_vector(7 downto 0);
	signal pacman_start_time              : std_logic_vector(7 downto 0);

	signal ghost_x                        : ghost_position_t;
	signal ghost_y                        : ghost_position_t;
	signal ghost_pen_x                    : position_t;
	signal ghost_pen_y                    : position_t;
	signal ghost_north                    : ghost_adjacency_t;
	signal ghost_south                    : ghost_adjacency_t;
	signal ghost_west                     : ghost_adjacency_t;
	signal ghost_east                     : ghost_adjacency_t;
	signal ghost_current                  : ghost_adjacency_t;
	signal ghost_direction                : ghost_direction_t;
	signal ghost_next_direction           : ghost_direction_t;
	signal ghost_a_direction              : ghost_direction_t;
	signal ghost_b_direction              : ghost_direction_t;
	signal ghost_c_direction              : ghost_direction_t;
	signal ghost_rev_direction            : ghost_direction_t;
	signal ghost_ai_direction             : ghost_direction_t;
	signal ghost_ai_selection             : ghost_ai_t;
	signal ghost_action                   : ghost_action_t;
	signal ghost_target_x                 : ghost_position_t;
	signal ghost_target_y                 : ghost_position_t;
	signal ghost_next_x                   : ghost_position_t;
	signal ghost_next_y                   : ghost_position_t;
	signal ghost_next                     : ghost_adjacency_t;
	signal ghost_next_a                   : ghost_adjacency_t;
	signal ghost_next_b                   : ghost_adjacency_t;
	signal ghost_next_c                   : ghost_adjacency_t;
	signal ghost_ai_state                 : ghost_ai_state_t;
	signal ghost_health                   : ghost_health_t;
	signal ghost_collision                : ghost_collision_t;

	signal gap_a_x                        : position_t;
	signal gap_a_y                        : position_t;
	signal gap_b_x                        : position_t;
	signal gap_b_y                        : position_t;
	signal load_splash_flags              : std_logic_vector(0 downto 0);
	signal load_map_flags                 : std_logic_vector(3 downto 0);
	signal game_start_flags               : std_logic_vector(MAX_GHOSTS downto 0);
	signal game_start_wait_time           : std_logic_vector(7 downto 0);
	constant GAME_START_FLAGS_EMPTY       : std_logic_vector(MAX_GHOSTS downto 0) := (others => '0');
	constant GAME_START_FLAGS_FULL        : std_logic_vector(MAX_GHOSTS downto 0) := (others => '1');

	-- Animation signals & constants
	signal animation_clk                  : std_logic;
	signal animation_0_frame              : std_logic_vector(0 downto 0);
	signal animation_1_frame              : std_logic_vector(3 downto 0);
	signal animation_2_frame              : std_logic_vector(3 downto 0);
	constant ANIMATION_0_END              : std_logic_vector(0 downto 0) := (others => '1');
	constant ANIMATION_1_END              : std_logic_vector(3 downto 0) := (others => '1');
	constant ANIMATION_2_END              : std_logic_vector(3 downto 0) := (others => '1');

	-- RAM signals
	signal ram_address                    : std_logic_vector(ROM_ADDR_LENGTH-1 downto 0);
	signal ram_address_main               : std_logic_vector(ROM_ADDR_LENGTH-1 downto 0);
	signal ram_address_aux                : std_logic_vector(ROM_ADDR_LENGTH-1 downto 0);
	signal ram_address_sel                : std_logic;
	signal ram_x_cell                     : std_logic_vector(5 downto 0);
	signal ram_y_cell                     : std_logic_vector(5 downto 0);
	signal ram_0_data_in                  : std_logic_vector(2 downto 0);
	signal ram_0_data_out                 : std_logic_vector(2 downto 0);
	signal ram_0_write                    : std_logic;

	-- ROM signals
	signal rom_address                    : std_logic_vector(ROM_ADDR_LENGTH-1 downto 0);
	signal rom_0_data                     : pacman_cell;

	-- Font bitmap constants
	constant FONT_ALPHABET_BASE           : natural := 0;
	constant FONT_NUMERIC_BASE            : natural := 26;
	constant FONT_A                       : natural := 0;
	constant FONT_B                       : natural := 1;
	constant FONT_C                       : natural := 2;
	constant FONT_D                       : natural := 3;
	constant FONT_E                       : natural := 4;
	constant FONT_F                       : natural := 5;
	constant FONT_G                       : natural := 6;
	constant FONT_H                       : natural := 7;
	constant FONT_I                       : natural := 8;
	constant FONT_J                       : natural := 9;
	constant FONT_K                       : natural := 10;
	constant FONT_L                       : natural := 11;
	constant FONT_M                       : natural := 12;
	constant FONT_N                       : natural := 13;
	constant FONT_O                       : natural := 14;
	constant FONT_P                       : natural := 15;
	constant FONT_Q                       : natural := 16;
	constant FONT_R                       : natural := 17;
	constant FONT_S                       : natural := 18;
	constant FONT_T                       : natural := 19;
	constant FONT_U                       : natural := 20;
	constant FONT_V                       : natural := 21;
	constant FONT_W                       : natural := 22;
	constant FONT_X                       : natural := 23;
	constant FONT_Y                       : natural := 24;
	constant FONT_Z                       : natural := 25;
	constant FONT_0                       : natural := 26;
	constant FONT_1                       : natural := 27;
	constant FONT_2                       : natural := 28;
	constant FONT_3                       : natural := 29;
	constant FONT_4                       : natural := 30;
	constant FONT_5                       : natural := 31;
	constant FONT_6                       : natural := 32;
	constant FONT_7                       : natural := 33;
	constant FONT_8                       : natural := 34;
	constant FONT_9                       : natural := 35;

	-- Bitmap signals
	signal bitmap_address                 : std_logic_vector(11 downto 0);
	signal bitmap_font_data               : std_logic_vector(2 downto 0);
	signal bitmap_0_data                  : std_logic_vector(2 downto 0);
	signal bitmap_1_data                  : std_logic_vector(2 downto 0);
	signal bitmap_2_data                  : std_logic_vector(2 downto 0);
	signal bitmap_3_data                  : std_logic_vector(2 downto 0);
	signal bitmap_4_data                  : std_logic_vector(2 downto 0);
	signal bitmap_5_data                  : std_logic_vector(2 downto 0);
	signal bitmap_6_data                  : std_logic_vector(2 downto 0);
	signal bitmap_7_data                  : std_logic_vector(2 downto 0);
	signal bitmap_8_data                  : std_logic_vector(2 downto 0);

	-- VGA signals
	signal video_color_in                 : std_logic_vector(2 downto 0);
	signal video_color                    : std_logic_vector(2 downto 0);
	signal video_bitmap                   : std_logic_vector(3 downto 0);
	signal video_x                        : std_logic_vector(9 downto 0);
	signal video_y                        : std_logic_vector(9 downto 0);
	alias  video_x_cell                   : std_logic_vector(5 downto 0) is video_x(9 downto 4);
	alias  video_y_cell                   : std_logic_vector(5 downto 0) is video_y(9 downto 4);

	-- Pseudo-random number generator signals
	signal random_seed_write_n            : std_logic;
	signal random_seed                    : std_logic_vector(31 downto 0);
	signal random_output                  : std_logic_vector(MAX_GHOSTS-1 downto 0);

	-- Registered signals
	signal level_speed_signal             : speed_t;
	signal level_ai_signal                : ghost_ai_t;
	signal pacman_x_signal                : position_t;
	signal pacman_y_signal                : position_t;
	signal pacman_sp_x_signal             : position_t;
	signal pacman_sp_y_signal             : position_t;
	signal pacman_north_signal            : pacman_cell;
	signal pacman_south_signal            : pacman_cell;
	signal pacman_west_signal             : pacman_cell;
	signal pacman_east_signal             : pacman_cell;
	signal pacman_current_signal          : pacman_cell;
	signal pacman_direction_signal        : direction_t;
	signal pacman_change_direction_signal : direction_t;
	signal pacman_next_direction_signal   : direction_t;
	signal pacman_next_x_signal           : position_t;
	signal pacman_next_y_signal           : position_t;
	signal pacman_next_signal             : pacman_cell;
	signal pacman_state_signal            : pacman_state_t;
	signal pacman_lives_signal            : std_logic_vector(3 downto 0);
	signal pacman_pellets_signal          : std_logic_vector(9 downto 0);
	signal pacman_score_signal            : std_logic_vector(15 downto 0);
	signal pacman_level_signal            : std_logic_vector(3 downto 0);
	signal pacman_super_time_signal       : std_logic_vector(7 downto 0);
	signal pacman_start_time_signal       : std_logic_vector(7 downto 0);
	signal ghost_x_signal                 : ghost_position_t;
	signal ghost_y_signal                 : ghost_position_t;
	signal ghost_pen_x_signal             : position_t;
	signal ghost_pen_y_signal             : position_t;
	signal ghost_north_signal             : ghost_adjacency_t;
	signal ghost_south_signal             : ghost_adjacency_t;
	signal ghost_west_signal              : ghost_adjacency_t;
	signal ghost_east_signal              : ghost_adjacency_t;
	signal ghost_current_signal           : ghost_adjacency_t;
	signal ghost_direction_signal         : ghost_direction_t;
	signal ghost_next_direction_signal    : ghost_direction_t;
	signal ghost_a_direction_signal       : ghost_direction_t;
	signal ghost_b_direction_signal       : ghost_direction_t;
	signal ghost_c_direction_signal       : ghost_direction_t;
	signal ghost_rev_direction_signal     : ghost_direction_t;
	signal ghost_ai_direction_signal      : ghost_direction_t;
	signal ghost_ai_selection_signal      : ghost_ai_t;
	signal ghost_action_signal            : ghost_action_t;
	signal ghost_target_x_signal          : ghost_position_t;
	signal ghost_target_y_signal          : ghost_position_t;
	signal ghost_next_x_signal            : ghost_position_t;
	signal ghost_next_y_signal            : ghost_position_t;
	signal ghost_next_signal              : ghost_adjacency_t;
	signal ghost_next_a_signal            : ghost_adjacency_t;
	signal ghost_next_b_signal            : ghost_adjacency_t;
	signal ghost_next_c_signal            : ghost_adjacency_t;
	signal ghost_ai_state_signal          : ghost_ai_state_t;
	signal ghost_health_signal            : ghost_health_t;
	signal ghost_collision_signal         : ghost_collision_t;
	signal gap_a_x_signal                 : position_t;
	signal gap_a_y_signal                 : position_t;
	signal gap_b_x_signal                 : position_t;
	signal gap_b_y_signal                 : position_t;
	signal load_splash_flags_signal       : std_logic_vector(0 downto 0);
	signal load_map_flags_signal          : std_logic_vector(3 downto 0);
	signal game_start_flags_signal        : std_logic_vector(MAX_GHOSTS downto 0);
	signal game_start_wait_time_signal    : std_logic_vector(7 downto 0);
	signal ram_address_main_signal        : std_logic_vector(ROM_ADDR_LENGTH-1 downto 0);
	signal ram_address_sel_signal         : std_logic;
	signal ram_0_data_in_signal           : std_logic_vector(2 downto 0);
	signal ram_0_write_signal             : std_logic;
	signal rom_address_signal             : std_logic_vector(ROM_ADDR_LENGTH-1 downto 0);

	-- Auxiliary signals
	signal vcc                            : std_logic := '1';
	signal gnd                            : std_logic := '0';

	component vga_sync
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
	end component;
	component clk_div
		generic(
			log_factor : natural := 24
		);
		port(
			clk_in     : in  std_logic;
			edge_in    : in  std_logic;
			clk_out    : out std_logic;
			edge_out   : out std_logic
		);
	end component;
	component clk_div_n
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
	end component;
	component LFSR32
		generic(
			output_length : natural := 32
		);
		port(
			clk           : in  std_logic;
			seed_enable_n : in  std_logic;
			seed_input    : in  std_logic_vector(31 downto 0);
			output        : out std_logic_vector(output_length-1 downto 0)
		);
	end component;
begin
	-- General components section
	vga_sync_0:  vga_sync  port map(clk_25Mhz => clk_25Mhz, red_in => video_color_in(2), green_in => video_color_in(1), blue_in => video_color_in(0), red_out => red, green_out => green, blue_out => blue, horz_sync => horz_sync, vert_sync => vert_sync, video_x => video_x, video_y => video_y);
	clk_div_0:   clk_div   generic map(log_factor => 11)            port map(clk_in => clk_25Mhz, edge_in => vcc, clk_out => game_clk_base);
	clk_div_1:   clk_div   generic map(log_factor => 22)            port map(clk_in => clk_25Mhz, edge_in => vcc, clk_out => animation_clk);
	clk_div_n_0: clk_div_n generic map(factor_length => 8)          port map(clk_in => game_clk_base, edge_in => vcc, half_factor => game_speed_base, clk_out => game_clk);
	LFSR32_0:    LFSR32    generic map(output_length => MAX_GHOSTS) port map(clk => clk_25Mhz, seed_enable_n => random_seed_write_n, seed_input => random_seed, output => random_output);

	-- Game switches & controls section
	game_speed_base <= not game_speed & not level_speed & "11";
	game_data(3 downto 0)   <= pacman_lives;
	game_data(13 downto 4)  <= pacman_pellets;
	game_data(29 downto 14) <= pacman_score;
	game_data(33 downto 30) <= pacman_level;
	game_data(37 downto 34) <= level_speed;

	with conv_integer(video_bitmap) select video_color_in <= bitmap_0_data when 0, bitmap_1_data when 1, bitmap_2_data when 2, bitmap_3_data when 3, bitmap_4_data when 4, bitmap_5_data when 5, bitmap_6_data when 6, bitmap_7_data when 7, bitmap_8_data when 8, bitmap_font_data when 14, video_color when others;

	random_seed_write_n <= '1';
	random_seed <= (others => '0');

	-- RAM & ROM section
	ram_0: lpm_ram_dq generic map(lpm_width => 3, lpm_widthad => ROM_ADDR_LENGTH, lpm_numwords => ROM_LENGTH, lpm_file => "UNUSED", lpm_indata => "UNREGISTERED", lpm_address_control => "UNREGISTERED", lpm_outdata => "UNREGISTERED") port map(data => ram_0_data_in, address => ram_address, we => ram_0_write, q => ram_0_data_out);
	rom_0: lpm_rom    generic map(lpm_width => 3, lpm_widthad => ROM_ADDR_LENGTH, lpm_numwords => ROM_LENGTH, lpm_file => "maps\\map_01.hex", lpm_address_control => "UNREGISTERED", lpm_outdata => "UNREGISTERED")                     port map(address => rom_address, memenab => vcc, q => rom_0_data);

	with ram_address_sel select ram_address <= ram_address_main when '0', ram_address_aux when '1', null when others;

	-- Bitmap section
	bitmap_font: lpm_rom generic map(lpm_width => 1, lpm_widthad => 12, lpm_numwords => 2304, lpm_file => "sprites\\font.hex",            lpm_address_control => "UNREGISTERED", lpm_outdata => "UNREGISTERED") port map(address => bitmap_address(11 downto 0), memenab => vcc, q => bitmap_font_data(0 downto 0));
	bitmap_0:    lpm_rom generic map(lpm_width => 2, lpm_widthad => 10, lpm_numwords => 1024, lpm_file => "background\\pacman_cells.hex", lpm_address_control => "UNREGISTERED", lpm_outdata => "UNREGISTERED") port map(address => bitmap_address(9 downto 0),  memenab => vcc, q => bitmap_0_data(1 downto 0));
	bitmap_1:    lpm_rom generic map(lpm_width => 1, lpm_widthad => 10, lpm_numwords => 1024, lpm_file => "sprites\\pacman.hex",          lpm_address_control => "UNREGISTERED", lpm_outdata => "UNREGISTERED") port map(address => bitmap_address(9 downto 0),  memenab => vcc, q => bitmap_1_data(2 downto 2));
	bitmap_2:    lpm_rom generic map(lpm_width => 2, lpm_widthad => 10, lpm_numwords => 1024, lpm_file => "sprites\\blue_ghost.hex",      lpm_address_control => "UNREGISTERED", lpm_outdata => "UNREGISTERED") port map(address => bitmap_address(9 downto 0),  memenab => vcc, q => bitmap_2_data(1 downto 0));
	bitmap_3:    with bitmap_2_data select bitmap_3_data <= "100" when "001", bitmap_2_data when others;
	bitmap_4:    with bitmap_2_data select bitmap_4_data <= "010" when "001", bitmap_2_data when others;
	bitmap_5:    with bitmap_2_data select bitmap_5_data <= "101" when "001", bitmap_2_data when others;
	bitmap_6:    with bitmap_2_data select bitmap_6_data <= "011" when "001", bitmap_2_data when others;
	bitmap_7:    with bitmap_2_data select bitmap_7_data <= "111" when "001", bitmap_2_data when others;
	bitmap_8:    with bitmap_2_data select bitmap_8_data <= "000" when "001", bitmap_2_data when others;

	bitmap_font_data(2) <= bitmap_font_data(0);
	bitmap_font_data(1) <= bitmap_font_data(0);
	bitmap_0_data(2) <= bitmap_0_data(1);
	bitmap_1_data(1) <= bitmap_1_data(2);
	bitmap_1_data(0) <= '0';
	bitmap_2_data(2) <= bitmap_2_data(1);

	-- Auxiliary section
	vcc <= '1';
	gnd <= '0';

	video: process(clk_25Mhz, reset_n, video_x, video_y)
		variable video_test : std_logic_vector(1 downto 0);
	begin
		if reset_n = '0' then
			-- Video test
			video_test := video_y(5 downto 4) xor video_x(5 downto 4);
			video_color(0) <= not video_test(0) and not video_test(1);
			video_color(1) <= not video_test(0) and     video_test(1);
			video_color(2) <=     video_test(0) and not video_test(1);
			video_bitmap <= (others => '1');
			bitmap_address <= (others => '0');
		elsif rising_edge(clk_25Mhz) then
			case game_state is
				when game_splash | game_start | game_start_wait | game_playing | game_eat_pellet_start | game_eat_pellet_step_1 | game_eat_pellet_step_2 | game_eat_pellet_end | game_pacman_dead | game_win_map =>
					video_color <= "000";
					video_bitmap <= (others => '1');
					if video_x_cell < MAP_WIDTH and video_y_cell < MAP_HEIGHT then
						bitmap_address(7 downto 0) <= video_y(3 downto 0) & video_x(3 downto 0);

						-- Draw background
						if ram_0_data_out = PELLET then
							bitmap_address(9 downto 8) <= "00";
							video_bitmap <= conv_std_logic_vector(0, 4);
						elsif ram_0_data_out = P_PELLET and animation_0_frame(0) = '1' then
							bitmap_address(9 downto 8) <= "01";
							video_bitmap <= conv_std_logic_vector(0, 4);
						elsif ram_0_data_out = WALL then
							bitmap_address(9 downto 8) <= "10";
							video_bitmap <= conv_std_logic_vector(0, 4);
						elsif ram_0_data_out = GHOST_WALL then
							bitmap_address(9 downto 8) <= "11";
							video_bitmap <= conv_std_logic_vector(0, 4);
						end if;

						-- Draw ghosts (blue one on top!)
						for i in MAX_GHOSTS-1 downto 0 loop
							if video_x_cell = ghost_x(i) and video_y_cell = ghost_y(i) then
								case ghost_health(i) is
									when alive => video_bitmap <= "0" & conv_std_logic_vector(conv_integer(conv_std_logic_vector(i, 2))+2, 3);
									when weak =>
										video_bitmap <= conv_std_logic_vector(6, 4);
										if pacman_super_time <= SUPER_ALERT then
											video_bitmap <= conv_std_logic_vector(6+conv_integer(pacman_super_time(0 downto 0)), 4);
										end if;
									when dead => video_bitmap <= conv_std_logic_vector(8, 4);
								end case;
								case ghost_direction(i) is
									when up    => bitmap_address(9 downto 8) <= "00";
									when down  => bitmap_address(9 downto 8) <= "01";
									when left  => bitmap_address(9 downto 8) <= "10";
									when right => bitmap_address(9 downto 8) <= "11";
								end case;
							end if;
						end loop;

						-- Draw Pacman & animations
						if game_state /= game_splash then
							if video_x_cell = pacman_x and video_y_cell = pacman_y then
								video_bitmap <= conv_std_logic_vector(1, 4);
								case pacman_direction is
									when up    => bitmap_address(9 downto 8) <= "00";
									when down  => bitmap_address(9 downto 8) <= "01";
									when left  => bitmap_address(9 downto 8) <= "10";
									when right => bitmap_address(9 downto 8) <= "11";
								end case;
								if game_state = game_pacman_dead then
									case conv_integer(animation_1_frame(1 downto 0)) is
										when 0 => bitmap_address(9 downto 8) <= "00";
										when 1 => bitmap_address(9 downto 8) <= "11";
										when 2 => bitmap_address(9 downto 8) <= "01";
										when 3 => bitmap_address(9 downto 8) <= "10";
										when others => null;
									end case;
								elsif game_state = game_win_map then
									if animation_2_frame(0) = '0' then
										video_bitmap <= (others => '1');
									end if;
								end if;
							end if;
						end if;
					elsif MAP_WIDTH+1 <= video_x_cell and video_y_cell = 1 then
						bitmap_address(5 downto 0) <= video_y(3 downto 1) & video_x(3 downto 1);
						video_bitmap <= conv_std_logic_vector(14, 4);
						case conv_integer(video_x_cell) is
							when MAP_WIDTH+1 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_P, 6);
							when MAP_WIDTH+2 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_A, 6);
							when MAP_WIDTH+3 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_C, 6);
							when MAP_WIDTH+4 => video_bitmap <= (others => '1');
							when MAP_WIDTH+5 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_M, 6);
							when MAP_WIDTH+6 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_A, 6);
							when MAP_WIDTH+7 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_N, 6);
							when others => video_bitmap <= (others => '1');
						end case;
					elsif MAP_WIDTH+3 <= video_x_cell and video_y_cell = 2 then
						bitmap_address(5 downto 0) <= video_y(3 downto 1) & video_x(3 downto 1);
						video_bitmap <= conv_std_logic_vector(14, 4);
						case conv_integer(video_x_cell) is
							when MAP_WIDTH+3 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_B, 6);
							when MAP_WIDTH+4 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_Y, 6);
							when others => video_bitmap <= (others => '1');
						end case;
					elsif MAP_WIDTH+1 <= video_x_cell and video_y_cell = 3 then
						bitmap_address(5 downto 0) <= video_y(3 downto 1) & video_x(3 downto 1);
						video_bitmap <= conv_std_logic_vector(14, 4);
						case conv_integer(video_x_cell) is
							when MAP_WIDTH+1 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_N, 6);
							when MAP_WIDTH+2 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_U, 6);
							when MAP_WIDTH+3 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_L, 6);
							when MAP_WIDTH+4 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_L, 6);
							when MAP_WIDTH+5 => video_bitmap <= (others => '1');
							when MAP_WIDTH+6 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_A, 6);
							when MAP_WIDTH+7 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_N, 6);
							when MAP_WIDTH+8 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_D, 6);
							when others => video_bitmap <= (others => '1');
						end case;
					elsif MAP_WIDTH+1 <= video_x_cell and video_y_cell = 4 then
						bitmap_address(5 downto 0) <= video_y(3 downto 1) & video_x(3 downto 1);
						video_bitmap <= conv_std_logic_vector(14, 4);
						case conv_integer(video_x_cell) is
							when MAP_WIDTH+1 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_A, 6);
							when MAP_WIDTH+2 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_K, 6);
							when MAP_WIDTH+3 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_I, 6);
							when MAP_WIDTH+4 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_R, 6);
							when MAP_WIDTH+5 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_A, 6);
							when MAP_WIDTH+6 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_Y, 6);
							when MAP_WIDTH+7 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_B, 6);
							when others => video_bitmap <= (others => '1');
						end case;
					elsif MAP_WIDTH+1 <= video_x_cell and video_y_cell = CANVAS_HEIGHT-6 then
						bitmap_address(5 downto 0) <= video_y(3 downto 1) & video_x(3 downto 1);
						video_bitmap <= conv_std_logic_vector(14, 4);
						case conv_integer(video_x_cell) is
							when MAP_WIDTH+1 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_L, 6);
							when MAP_WIDTH+2 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_I, 6);
							when MAP_WIDTH+3 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_V, 6);
							when MAP_WIDTH+4 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_E, 6);
							when MAP_WIDTH+5 => bitmap_address(11 downto 6) <= conv_std_logic_vector(FONT_S, 6);
							when others => video_bitmap <= (others => '1');
						end case;
					elsif MAP_WIDTH+1 <= video_x_cell and video_x_cell <= CANVAS_WIDTH-2 and video_y_cell = CANVAS_HEIGHT-5 then
						bitmap_address(7 downto 0) <= video_y(3 downto 0) & video_x(3 downto 0);
						if pacman_lives > video_x_cell-(MAP_WIDTH+1) then
							bitmap_address(9 downto 8) <= "11";
							video_bitmap <= conv_std_logic_vector(1, 4);
						end if;
					end if;
				when others => null;
			end case;
		end if;
	end process;

	animation: process(animation_clk, reset_n)
	begin
		if reset_n = '0' then
			animation_0_frame <= (others => '0');
			animation_1_frame <= (others => '0');
			animation_2_frame <= (others => '0');
		elsif rising_edge(animation_clk) then
			case game_state is
				when game_splash | game_start_wait | game_playing =>
					animation_0_frame <= animation_0_frame+1;
					animation_1_frame <= (others => '0');
					animation_2_frame <= (others => '0');
				when game_pacman_dead =>
					animation_0_frame <= (others => '0');
					animation_1_frame <= animation_1_frame+1;
					animation_2_frame <= (others => '0');
				when game_win_map =>
					animation_0_frame <= (others => '0');
					animation_1_frame <= (others => '0');
					animation_2_frame <= animation_2_frame+1;
				when others => null;
			end case;
		end if;
	end process;

	ram_x_cell <= video_x_cell;
	ram_y_cell <= video_y_cell;
	ram_address_aux <= conv_std_logic_vector(MAP_WIDTH*conv_integer(ram_y_cell)+conv_integer(ram_x_cell), ROM_ADDR_LENGTH);
	ram_aux: process(clk_25Mhz, reset_n)
	begin
		if reset_n = '0' then
			pacman_north_signal <= FREE_CELL;
			pacman_south_signal <= FREE_CELL;
			pacman_west_signal <= FREE_CELL;
			pacman_east_signal <= FREE_CELL;
			pacman_current_signal <= FREE_CELL;
			ghost_north_signal <= (others => FREE_CELL);
			ghost_south_signal <= (others => FREE_CELL);
			ghost_west_signal <= (others => FREE_CELL);
			ghost_east_signal <= (others => FREE_CELL);
		elsif rising_edge(clk_25Mhz) then
			-- Update auxiliary pacman data
			if ram_x_cell = pacman_x and ram_y_cell = pacman_y-1 then
				pacman_north_signal <= ram_0_data_out;
			elsif ram_x_cell = pacman_x and ram_y_cell = pacman_y+1 then
				pacman_south_signal <= ram_0_data_out;
			elsif ram_x_cell = pacman_x-1 and ram_y_cell = pacman_y then
				pacman_west_signal <= ram_0_data_out;
			elsif ram_x_cell = pacman_x+1 and ram_y_cell = pacman_y then
				pacman_east_signal <= ram_0_data_out;
			elsif ram_x_cell = pacman_x and ram_y_cell = pacman_y then
				pacman_current_signal <= ram_0_data_out;
			end if;

			-- Update auxiliary ghost data
			for i in 0 to MAX_GHOSTS-1 loop
				if ram_x_cell = ghost_x(i) and ram_y_cell = ghost_y(i)-1 then
					ghost_north_signal(i) <= ram_0_data_out;
				elsif ram_x_cell = ghost_x(i) and ram_y_cell = ghost_y(i)+1 then
					ghost_south_signal(i) <= ram_0_data_out;
				elsif ram_x_cell = ghost_x(i)-1 and ram_y_cell = ghost_y(i) then
					ghost_west_signal(i) <= ram_0_data_out;
				elsif ram_x_cell = ghost_x(i)+1 and ram_y_cell = ghost_y(i) then
					ghost_east_signal(i) <= ram_0_data_out;
				elsif ram_x_cell = ghost_x(i) and ram_y_cell = ghost_y(i) then
					ghost_current_signal(i) <= ram_0_data_out;
				end if;
			end loop;
		end if;
	end process;

	clk_div_pacman: clk_div generic map(log_factor => 3) port map(clk_in => game_clk, edge_in => vcc, clk_out => pacman_clk);
	pacman: process(pacman_clk, reset_n)
		variable pacman_next_dir : direction_t;
	begin
		if reset_n = '0' then
			pacman_x_signal <= (others => '0');
			pacman_y_signal <= (others => '0');
			pacman_direction_signal <= left;
			pacman_super_time_signal <= (others => '0');
			pacman_start_time_signal <= (others => '0');
			pacman_state_signal <= selecting;
			game_start_flags_signal(MAX_GHOSTS) <= '0';
			game_start_wait_time_signal <= (others => '0');
		elsif rising_edge(pacman_clk) then
			case game_state is
				when game_start_splash =>
					game_start_flags_signal(MAX_GHOSTS) <= '1';
				when game_start_splash_wait =>
					game_start_flags_signal(MAX_GHOSTS) <= '0';
				when game_start =>
					pacman_x_signal <= pacman_sp_x;
					pacman_y_signal <= pacman_sp_y;
					pacman_direction_signal <= left;
					pacman_super_time_signal <= (others => '0');
					pacman_start_time_signal <= conv_std_logic_vector(START_TIME, 8);
					pacman_state_signal <= selecting;
					game_start_flags_signal(MAX_GHOSTS) <= '1';
					game_start_wait_time_signal <= conv_std_logic_vector(START_WAIT_TIME, 8);
				when game_start_wait =>
					game_start_flags_signal(MAX_GHOSTS) <= '0';
					if game_start_wait_time > 0 then
						game_start_wait_time_signal <= game_start_wait_time-1;
					end if;
				when game_playing =>
					case pacman_state is
						when selecting =>
							-- Check start/super times
							if pacman_start_time > 0 then
								pacman_start_time_signal <= pacman_start_time-1;
							elsif pacman_super_time > 0 then
								pacman_super_time_signal <= pacman_super_time-1;
							end if;

							-- Check direction changing
							pacman_next_direction_signal <= pacman_change_direction;
							pacman_next_dir := pacman_change_direction;
							if pacman_next = WALL then
								pacman_next_direction_signal <= pacman_direction;
								pacman_next_dir := pacman_direction;
							end if;

							-- Confirming movement
							case pacman_next_dir is
								when up =>
									pacman_next_x_signal <= pacman_x;
									pacman_next_y_signal <= pacman_y-1;
									pacman_next_signal <= pacman_north;
								when down =>
									pacman_next_x_signal <= pacman_x;
									pacman_next_y_signal <= pacman_y+1;
									pacman_next_signal <= pacman_south;
								when left =>
									pacman_next_x_signal <= pacman_x-1;
									pacman_next_y_signal <= pacman_y;
									pacman_next_signal <= pacman_west;
								when right =>
									pacman_next_x_signal <= pacman_x+1;
									pacman_next_y_signal <= pacman_y;
									pacman_next_signal <= pacman_east;
							end case;
							pacman_state_signal <= moving;
						when moving =>
							-- Normal movement
							if pacman_next = GAP then
								if pacman_next_x = gap_a_x and pacman_next_y = gap_a_y then
									pacman_x_signal <= gap_b_x;
									pacman_y_signal <= gap_b_y;
								else
									pacman_x_signal <= gap_a_x;
									pacman_y_signal <= gap_a_y;
								end if;
							elsif pacman_next /= WALL and pacman_next /= GHOST_WALL then
								pacman_x_signal <= pacman_next_x;
								pacman_y_signal <= pacman_next_y;
								pacman_direction_signal <= pacman_next_direction;
								if pacman_next = P_PELLET then
									pacman_super_time_signal <= conv_std_logic_vector(SUPER_TIME, 8);
								end if;
							end if;
							pacman_state_signal <= selecting;
					end case;
				when others => null;
			end case;
		end if;
	end process;

	clk_div_n_ghost_fast:   clk_div_n generic map(factor_length => 8) port map(clk_in => game_clk_base, edge_in => vcc, half_factor => game_speed_base-GHOST_FAST, clk_out => ghost_fast_clk);
	clk_div_n_ghost_normal: clk_div_n generic map(factor_length => 8) port map(clk_in => game_clk_base, edge_in => vcc, half_factor => game_speed_base,            clk_out => ghost_normal_clk);
	clk_div_n_ghost_slow:   clk_div_n generic map(factor_length => 8) port map(clk_in => game_clk_base, edge_in => vcc, half_factor => game_speed_base+GHOST_SLOW, clk_out => ghost_slow_clk);
	ghost: for i in 0 to MAX_GHOSTS-1 generate
	begin
		with ghost_health(i) select ghost_clk(i) <= ghost_normal_clk when alive, ghost_slow_clk when weak, ghost_fast_clk when dead;

		ghost_ai: process(ghost_clk(i), reset_n)
			variable ghost_ai_dir : direction_t;
			variable ghost_p      : ai_t;
		begin
			if reset_n = '0' then
				ghost_x_signal(i) <= conv_std_logic_vector(0, 5);
				ghost_y_signal(i) <= conv_std_logic_vector(0, 5);
				ghost_direction_signal(i) <= left;
				ghost_next_direction_signal(i) <= left;
				ghost_a_direction_signal(i) <= left;
				ghost_b_direction_signal(i) <= left;
				ghost_c_direction_signal(i) <= left;
				ghost_rev_direction_signal(i) <= left;
				ghost_ai_direction_signal(i) <= left;
				ghost_ai_selection_signal(i) <= wander_around;
				ghost_action_signal(i) <= random;
				ghost_target_x_signal(i) <= (others => '0');
				ghost_target_y_signal(i) <= (others => '0');
				ghost_next_x_signal(i) <= (others => '0');
				ghost_next_y_signal(i) <= (others => '0');
				ghost_next_signal(i) <= FREE_CELL;
				ghost_next_a_signal(i) <= FREE_CELL;
				ghost_next_b_signal(i) <= FREE_CELL;
				ghost_next_c_signal(i) <= FREE_CELL;
				ghost_ai_state_signal(i) <= selecting;
				game_start_flags_signal(i) <= '0';
			elsif rising_edge(ghost_clk(i)) then
				case game_state is
					when game_start_splash | game_start =>
						ghost_x_signal(i) <= ghost_pen_x;
						ghost_y_signal(i) <= ghost_pen_y;
						ghost_direction_signal(i) <= left;
						ghost_ai_state_signal(i) <= selecting;
						game_start_flags_signal(i) <= '1';
					when game_start_splash_wait | game_start_wait =>
						game_start_flags_signal(i) <= '0';
					when game_splash | game_playing =>
						case ghost_ai_state(i) is
							when selecting =>
								-- Select AI behaviour
								case ghost_health(i) is
									when alive =>
										ghost_ai_selection_signal(i) <= level_ai(i);
										if game_state = game_splash then
											ghost_ai_selection_signal(i) <= wander_around;
										end if;
									when weak => ghost_ai_selection_signal(i) <= run_pacman;
									when dead => ghost_ai_selection_signal(i) <= follow_pen;
								end case;
								ghost_ai_state_signal(i) <= analysing;
							when analysing =>
								-- AI analysis
								case ghost_ai_selection(i) is
									when wander_around =>
										ghost_action_signal(i) <= random;
									when follow_pacman =>
										ghost_action_signal(i) <= follow;
										ghost_target_x_signal(i) <= pacman_x;
										ghost_target_y_signal(i) <= pacman_y;
									when run_pacman =>
										ghost_action_signal(i) <= run;
										ghost_target_x_signal(i) <= pacman_x;
										ghost_target_y_signal(i) <= pacman_y;
									when follow_pen =>
										ghost_action_signal(i) <= follow;
										ghost_target_x_signal(i) <= ghost_pen_x;
										ghost_target_y_signal(i) <= ghost_pen_y;
								end case;
								ghost_ai_state_signal(i) <= acquiring;
							when acquiring =>
								-- AI data acquisition
								case ghost_direction(i) is
									when up =>
										ghost_a_direction_signal(i) <= up;
										ghost_b_direction_signal(i) <= left;
										ghost_c_direction_signal(i) <= right;
										ghost_rev_direction_signal(i) <= down;
										ghost_next_a_signal(i) <= ghost_north(i);
										ghost_next_b_signal(i) <= ghost_west(i);
										ghost_next_c_signal(i) <= ghost_east(i);
									when down =>
										ghost_a_direction_signal(i) <= down;
										ghost_b_direction_signal(i) <= left;
										ghost_c_direction_signal(i) <= right;
										ghost_rev_direction_signal(i) <= up;
										ghost_next_a_signal(i) <= ghost_south(i);
										ghost_next_b_signal(i) <= ghost_west(i);
										ghost_next_c_signal(i) <= ghost_east(i);
									when left =>
										ghost_a_direction_signal(i) <= up;
										ghost_b_direction_signal(i) <= down;
										ghost_c_direction_signal(i) <= left;
										ghost_rev_direction_signal(i) <= right;
										ghost_next_a_signal(i) <= ghost_north(i);
										ghost_next_b_signal(i) <= ghost_south(i);
										ghost_next_c_signal(i) <= ghost_west(i);
									when right =>
										ghost_a_direction_signal(i) <= up;
										ghost_b_direction_signal(i) <= down;
										ghost_c_direction_signal(i) <= right;
										ghost_rev_direction_signal(i) <= left;
										ghost_next_a_signal(i) <= ghost_north(i);
										ghost_next_b_signal(i) <= ghost_south(i);
										ghost_next_c_signal(i) <= ghost_east(i);
								end case;
								ghost_ai_state_signal(i) <= deciding;
							when deciding =>
								-- AI best decision
								if (ghost_direction(i) = up or ghost_direction(i) = down) and ghost_x(i) < ghost_target_x(i) then
									ghost_ai_dir := right;
								elsif (ghost_direction(i) = up or ghost_direction(i) = down) and ghost_target_x(i) < ghost_x(i) then
									ghost_ai_dir := left;
								elsif (ghost_direction(i) = left or ghost_direction(i) = right) and ghost_y(i) < ghost_target_y(i) then
									ghost_ai_dir := down;
								elsif (ghost_direction(i) = left or ghost_direction(i) = right) and ghost_target_y(i) < ghost_y(i) then
									ghost_ai_dir := up;
								elsif (ghost_direction(i) = up or ghost_direction(i) = down) and ghost_y(i) < ghost_target_y(i) then
									ghost_ai_dir := down;
								elsif (ghost_direction(i) = up or ghost_direction(i) = down) and ghost_target_y(i) < ghost_y(i) then
									ghost_ai_dir := up;
								elsif (ghost_direction(i) = left or ghost_direction(i) = right) and ghost_x(i) < ghost_target_x(i) then
									ghost_ai_dir := right;
								elsif (ghost_direction(i) = left or ghost_direction(i) = right) and ghost_target_x(i) < ghost_x(i) then
									ghost_ai_dir := left;
								end if;

								-- Reverse direction if running away from target
								if ghost_action(i) = run then
									case ghost_ai_dir is
										when up    => ghost_ai_dir := down;
										when down  => ghost_ai_dir := up;
										when left  => ghost_ai_dir := right;
										when right => ghost_ai_dir := left;
									end case;
								end if;
								ghost_ai_direction_signal(i) <= ghost_ai_dir;
								ghost_ai_state_signal(i) <= asserting;
							when asserting =>
								-- Assert the direction decision
								ghost_next_direction_signal(i) <= ghost_direction(i);

								-- Do not change direction on gaps
								if ghost_current(i) = GAP then
									null;

								-- No way to go! Reverse direction
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) = WALL and ghost_next_c(i) = WALL then
									ghost_next_direction_signal(i) <= ghost_rev_direction(i);

								-- One way to go (a, b or c)
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) = WALL and ghost_next_c(i) /= WALL then
									ghost_next_direction_signal(i) <= ghost_c_direction(i);
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) = WALL then
									ghost_next_direction_signal(i) <= ghost_b_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) = WALL and ghost_next_c(i) = WALL then
									ghost_next_direction_signal(i) <= ghost_a_direction(i);

								-- Two ways to go (b or c)
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and ghost_b_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_b_direction(i);
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and ghost_c_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_c_direction(i);
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and random_output(i) = '0' then
									ghost_next_direction_signal(i) <= ghost_b_direction(i);
								elsif ghost_next_a(i) = WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and random_output(i) = '1' then
									ghost_next_direction_signal(i) <= ghost_c_direction(i);

								-- Two ways to go (a or b)
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) = WALL and ghost_a_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_a_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) = WALL and ghost_b_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_b_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) = WALL and random_output(i) = '0' then
									ghost_next_direction_signal(i) <= ghost_a_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) = WALL and random_output(i) = '1' then
									ghost_next_direction_signal(i) <= ghost_b_direction(i);

								-- Two ways to go (a or c)
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) = WALL and ghost_next_c(i) /= WALL and ghost_a_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_a_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) = WALL and ghost_next_c(i) /= WALL and ghost_c_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_c_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) = WALL and ghost_next_c(i) /= WALL and random_output(i) = '0' then
									ghost_next_direction_signal(i) <= ghost_a_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) = WALL and ghost_next_c(i) /= WALL and random_output(i) = '1' then
									ghost_next_direction_signal(i) <= ghost_c_direction(i);

								-- Three ways to go (a, b or c)
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and ghost_a_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_a_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and ghost_b_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_b_direction(i);
								elsif ghost_next_a(i) /= WALL and ghost_next_b(i) /= WALL and ghost_next_c(i) /= WALL and ghost_c_direction(i) = ghost_ai_direction(i) and ghost_action(i) /= random then
									ghost_next_direction_signal(i) <= ghost_c_direction(i);
								end if;
								ghost_ai_state_signal(i) <= confirming_move;
							when confirming_move =>
								-- Confirming movement
								case ghost_next_direction(i) is
									when up =>
										ghost_next_x_signal(i) <= ghost_x(i);
										ghost_next_y_signal(i) <= ghost_y(i)-1;
										ghost_next_signal(i) <= ghost_north(i);
									when down =>
										ghost_next_x_signal(i) <= ghost_x(i);
										ghost_next_y_signal(i) <= ghost_y(i)+1;
										ghost_next_signal(i) <= ghost_south(i);
									when left =>
										ghost_next_x_signal(i) <= ghost_x(i)-1;
										ghost_next_y_signal(i) <= ghost_y(i);
										ghost_next_signal(i) <= ghost_west(i);
									when right =>
										ghost_next_x_signal(i) <= ghost_x(i)+1;
										ghost_next_y_signal(i) <= ghost_y(i);
										ghost_next_signal(i) <= ghost_east(i);
								end case;
								ghost_ai_state_signal(i) <= waiting;
							when waiting =>
								-- Dummy state to fill in 8 states
								ghost_ai_state_signal(i) <= moving;
							when moving =>
								-- Normal movement
								if pacman_start_time = 0 then -- Respect start time
									if ghost_next(i) = GAP then
										if ghost_next_x(i) = gap_a_x and ghost_next_y(i) = gap_a_y then
											ghost_x_signal(i) <= gap_b_x;
											ghost_y_signal(i) <= gap_b_y;
										else
											ghost_x_signal(i) <= gap_a_x;
											ghost_y_signal(i) <= gap_a_y;
										end if;
									elsif ghost_next(i) /= WALL then -- Should not occur
										ghost_x_signal(i) <= ghost_next_x(i);
										ghost_y_signal(i) <= ghost_next_y(i);
										ghost_direction_signal(i) <= ghost_next_direction(i);
									end if;
								end if;
								ghost_ai_state_signal(i) <= selecting;
						end case;
					when others => null;
				end case;
			end if;
		end process;
	end generate;

	main: process(clk_25Mhz, reset_n)
	begin
		if reset_n = '0' then
			level_speed_signal <= (others => '0');
			level_ai_signal <= (others => wander_around);
			pacman_sp_x_signal <= (others => '0');
			pacman_sp_y_signal <= (others => '0');
			pacman_change_direction_signal <= left;
			pacman_lives_signal <= (others => '0');
			pacman_pellets_signal <= (others => '0');
			pacman_score_signal <= (others => '0');
			pacman_level_signal <= (others => '0');
			ghost_pen_x_signal <= (others => '0');
			ghost_pen_y_signal <= (others => '0');
			ghost_health_signal <= (others => alive);
			ghost_collision_signal <= (others => false);
			gap_a_x_signal <= (others => '0');
			gap_a_y_signal <= (others => '0');
			gap_b_x_signal <= (others => '0');
			gap_b_y_signal <= (others => '0');
			load_splash_flags_signal <= (others => '0');
			load_map_flags_signal <= (others => '0');
			ram_address_main_signal <= (others => '0');
			ram_address_sel_signal <= '0';
			ram_0_data_in_signal <= (others => '0');
			ram_0_write_signal <= '0';
			rom_address_signal <= (others => '0');
			game_state_signal <= game_reset;
			game_process_state_signal <= process_movement;
		elsif rising_edge(clk_25Mhz) then
			case game_state is
				when game_reset =>
					game_state_signal <= game_load_splash;
				when game_load_splash =>
					load_splash_flags_signal(0) <= '1';
					game_state_signal <= game_load_map_start;
				when game_start_splash =>
					load_splash_flags_signal(0) <= '0';
					if game_start_flags = GAME_START_FLAGS_FULL then
						game_state_signal <= game_start_splash_wait;
					end if;
				when game_start_splash_wait =>
					if game_start_flags = GAME_START_FLAGS_EMPTY then
						game_state_signal <= game_splash;
					end if;
				when game_splash =>
					if game_control_start = '1' then
						game_state_signal <= game_initialize;
					end if;
				when game_initialize =>
					level_speed_signal <= LEVEL_SPEED_0;
					level_ai_signal <= LEVEL_AI_0;
					pacman_lives_signal <= conv_std_logic_vector(3, 4);
					pacman_score_signal <= (others => '0');
					pacman_level_signal <= (others => '0');
					ghost_health_signal <= (others => alive);
					game_state_signal <= game_load_map_start;
				when game_load_map_start =>
					pacman_sp_x_signal <= (others => '0');
					pacman_sp_y_signal <= (others => '0');
					pacman_pellets_signal <= (others => '0');
					ghost_pen_x_signal <= (others => '0');
					ghost_pen_y_signal <= (others => '0');
					gap_a_x_signal <= (others => '0');
					gap_a_y_signal <= (others => '0');
					gap_b_x_signal <= (others => '0');
					gap_b_y_signal <= (others => '0');
					load_map_flags_signal <= (others => '0');
					ram_address_main_signal <= (others => '1');
					ram_address_sel_signal <= '0';
					rom_address_signal <= (others => '0');
					game_state_signal <= game_load_map_step_1;
				when game_load_map_step_1 =>
					ram_address_main_signal <= rom_address;
					ram_0_data_in_signal <= rom_0_data;
					rom_address_signal <= rom_address+1;
					if rom_0_data = PELLET or rom_0_data = P_PELLET then
						pacman_pellets_signal <= pacman_pellets+1;
					end if;
					if rom_0_data = PACMAN_SP then
						load_map_flags_signal(0) <= '1';
					elsif load_map_flags(0) = '0' then
						pacman_sp_x_signal <= pacman_sp_x+1;
						if pacman_sp_x = MAP_WIDTH-1 then
							pacman_sp_x_signal <= (others => '0');
							pacman_sp_y_signal <= pacman_sp_y+1;
						end if;
					end if;
					if rom_0_data = GHOST_PEN then
						load_map_flags_signal(1) <= '1';
					elsif load_map_flags(1) = '0' then
						ghost_pen_x_signal <= ghost_pen_x+1;
						if ghost_pen_x = MAP_WIDTH-1 then
							ghost_pen_x_signal <= (others => '0');
							ghost_pen_y_signal <= ghost_pen_y+1;
						end if;
					end if;
					if rom_0_data = GAP then
						load_map_flags_signal(2) <= '1';
					elsif load_map_flags(2) = '0' then
						gap_a_x_signal <= gap_a_x+1;
						if gap_a_x = MAP_WIDTH-1 then
							gap_a_x_signal <= (others => '0');
							gap_a_y_signal <= gap_a_y+1;
						end if;
					end if;
					if rom_0_data = GAP and load_map_flags(2) = '1' then
						load_map_flags_signal(3) <= '1';
					elsif load_map_flags(3) = '0' then
						gap_b_x_signal <= gap_b_x+1;
						if gap_b_x = MAP_WIDTH-1 then
							gap_b_x_signal <= (others => '0');
							gap_b_y_signal <= gap_b_y+1;
						end if;
					end if;
					game_state_signal <= game_load_map_step_2;
				when game_load_map_step_2 =>
					ram_0_write_signal <= '1';
					game_state_signal <= game_load_map_step_3;
				when game_load_map_step_3 =>
					ram_0_write_signal <= '0';
					game_state_signal <= game_load_map_end;
				when game_load_map_end =>
					game_state_signal <= game_load_map_step_1;
					if ram_address_main = ROM_LENGTH then
						ram_address_sel_signal <= '1';
						game_state_signal <= game_start;
						if load_splash_flags(0) = '1' then
							game_state_signal <= game_start_splash;
						end if;
					end if;
				when game_start =>
					pacman_change_direction_signal <= left;
					ghost_health_signal <= (others => alive);
					if game_start_flags = GAME_START_FLAGS_FULL then
						game_state_signal <= game_start_wait;
					end if;
				when game_start_wait =>
					game_process_state_signal <= process_movement;
					if game_start_flags = GAME_START_FLAGS_EMPTY and game_start_wait_time = 0 then
						game_state_signal <= game_playing;
					end if;
				when game_playing =>
					case game_process_state is
						when process_movement =>
							-- Detect player movement
							if game_control_up = '1' then
								pacman_change_direction_signal <= up;
							elsif game_control_down = '1' then
								pacman_change_direction_signal <= down;
							elsif game_control_left = '1' then
								pacman_change_direction_signal <= left;
							elsif game_control_right = '1' then
								pacman_change_direction_signal <= right;
							end if;
							game_process_state_signal <= process_pellet;
						when process_pellet =>
							-- Detect pellet eating
							if pacman_current = PELLET or pacman_current = P_PELLET then
								game_state_signal <= game_eat_pellet_start;

							-- Detect super pellet eating
							elsif pacman_super_time = SUPER_TIME then
								for i in 0 to MAX_GHOSTS-1 loop
									if ghost_health(i) = alive then
										ghost_health_signal(i) <= weak;
									end if;
								end loop;
							end if;
							game_process_state_signal <= assert_collision;
						when assert_collision =>
							-- Detect collisions
							for i in 0 to MAX_GHOSTS-1 loop
								if ghost_health(i) = weak and pacman_super_time = 0 then
									ghost_health_signal(i) <= alive;
								elsif ghost_health(i) = dead and ghost_x(i) = ghost_pen_x and ghost_y(i) = ghost_pen_y then
									ghost_health_signal(i) <= alive;
								end if;
								case pacman_change_direction is
									when up    => ghost_collision_signal(i) <= ghost_direction(i) = down and ghost_x(i) = pacman_x and ghost_y(i) = pacman_y-1;
									when down  => ghost_collision_signal(i) <= ghost_direction(i) = up and ghost_x(i) = pacman_x and ghost_y(i) = pacman_y+1;
									when left  => ghost_collision_signal(i) <= ghost_direction(i) = right and ghost_x(i) = pacman_x-1 and ghost_y(i) = pacman_y;
									when right => ghost_collision_signal(i) <= ghost_direction(i) = left and ghost_x(i) = pacman_x+1 and ghost_y(i) = pacman_y;
								end case;
								if pacman_x = ghost_x(i) and pacman_y = ghost_y(i) then
									ghost_collision_signal(i) <= true;
								end if;
							end loop;
							game_process_state_signal <= process_collision;
						when process_collision =>
							-- Process collisions and adjust ghost health
							for i in 0 to MAX_GHOSTS-1 loop
								if ghost_collision(i) then
									case ghost_health(i) is
										when alive =>
											pacman_lives_signal <= pacman_lives-1;
											game_state_signal <= game_pacman_dead;
										when weak =>
											pacman_score_signal <= pacman_score+POINTS_GHOST;
											ghost_health_signal(i) <= dead;
										when dead => null;
									end case;
								end if;
							end loop;
							game_process_state_signal <= process_movement;
					end case;
				when game_eat_pellet_start =>
					pacman_pellets_signal <= pacman_pellets-1;
					if pacman_current = PELLET then
						pacman_score_signal <= pacman_score+POINTS_PELLET;
					else
						pacman_score_signal <= pacman_score+POINTS_P_PELLET;
					end if;
					ram_address_main_signal <= conv_std_logic_vector(MAP_WIDTH*conv_integer(pacman_y)+conv_integer(pacman_x), ROM_ADDR_LENGTH);
					ram_address_sel_signal <= '0';
					ram_0_data_in_signal <= FREE_CELL;
					game_state_signal <= game_eat_pellet_step_1;
				when game_eat_pellet_step_1 =>
					ram_0_write_signal <= '1';
					game_state_signal <= game_eat_pellet_step_2;
				when game_eat_pellet_step_2 =>
					ram_0_write_signal <= '0';
					game_state_signal <= game_eat_pellet_end;
				when game_eat_pellet_end =>
					ram_address_sel_signal <= '1';
					if pacman_current = FREE_CELL then
						game_state_signal <= game_playing;
						if pacman_pellets = 0 then
							if pacman_lives < 15 then
								pacman_lives_signal <= pacman_lives+1;
							end if;
							pacman_score_signal <= pacman_score+POINTS_MAP;
							if pacman_level < 15 then
								pacman_level_signal <= pacman_level+1;
							end if;
							game_state_signal <= game_win_map;
						end if;
					end if;
				when game_pacman_dead =>
					if animation_1_frame = ANIMATION_1_END then
						game_state_signal <= game_start;
						if pacman_lives = 0 then
							game_state_signal <= game_splash;
						end if;
					end if;
				when game_win_map =>
					case conv_integer(pacman_level) is
						when 0 =>
							level_speed_signal <= LEVEL_SPEED_0;
							level_ai_signal <= LEVEL_AI_0;
						when 1 =>
							level_speed_signal <= LEVEL_SPEED_1;
							level_ai_signal <= LEVEL_AI_1;
						when 2 =>
							level_speed_signal <= LEVEL_SPEED_2;
							level_ai_signal <= LEVEL_AI_2;
						when 3 =>
							level_speed_signal <= LEVEL_SPEED_3;
							level_ai_signal <= LEVEL_AI_3;
						when 4 =>
							level_speed_signal <= LEVEL_SPEED_4;
							level_ai_signal <= LEVEL_AI_4;
						when 5 =>
							level_speed_signal <= LEVEL_SPEED_5;
							level_ai_signal <= LEVEL_AI_5;
						when 6 =>
							level_speed_signal <= LEVEL_SPEED_6;
							level_ai_signal <= LEVEL_AI_6;
						when 7 =>
							level_speed_signal <= LEVEL_SPEED_7;
							level_ai_signal <= LEVEL_AI_7;
						when 8 =>
							level_speed_signal <= LEVEL_SPEED_8;
							level_ai_signal <= LEVEL_AI_8;
						when 9 =>
							level_speed_signal <= LEVEL_SPEED_9;
							level_ai_signal <= LEVEL_AI_9;
						when 10 =>
							level_speed_signal <= LEVEL_SPEED_10;
							level_ai_signal <= LEVEL_AI_10;
						when 11 =>
							level_speed_signal <= LEVEL_SPEED_11;
							level_ai_signal <= LEVEL_AI_11;
						when 12 =>
							level_speed_signal <= LEVEL_SPEED_12;
							level_ai_signal <= LEVEL_AI_12;
						when 13 =>
							level_speed_signal <= LEVEL_SPEED_13;
							level_ai_signal <= LEVEL_AI_13;
						when 14 =>
							level_speed_signal <= LEVEL_SPEED_14;
							level_ai_signal <= LEVEL_AI_14;
						when 15 =>
							level_speed_signal <= LEVEL_SPEED_15;
							level_ai_signal <= LEVEL_AI_15;
						when others => null;
					end case;
					if animation_2_frame = ANIMATION_2_END then
						game_state_signal <= game_load_map_start;
					end if;
			end case;
		end if;
	end process;

	register_out: process(clk_25Mhz, reset_n)
	begin
		if reset_n = '0' then
			level_speed <= (others => '0');
			level_ai <= (others => wander_around);
			pacman_x <= (others => '0');
			pacman_y <= (others => '0');
			pacman_sp_x <= (others => '0');
			pacman_sp_y <= (others => '0');
			pacman_north <= FREE_CELL;
			pacman_south <= FREE_CELL;
			pacman_west <= FREE_CELL;
			pacman_east <= FREE_CELL;
			pacman_current <= FREE_CELL;
			pacman_direction <= left;
			pacman_change_direction <= left;
			pacman_next_direction <= left;
			pacman_next_x <= (others => '0');
			pacman_next_y <= (others => '0');
			pacman_next <= FREE_CELL;
			pacman_state <= selecting;
			pacman_lives <= (others => '0');
			pacman_pellets <= (others => '0');
			pacman_score <= (others => '0');
			pacman_level <= (others => '0');
			pacman_super_time <= (others => '0');
			pacman_start_time <= (others => '0');
			ghost_x <= (others => (others => '0'));
			ghost_y <= (others => (others => '0'));
			ghost_pen_x <= (others => '0');
			ghost_pen_y <= (others => '0');
			ghost_north <= (others => FREE_CELL);
			ghost_south <= (others => FREE_CELL);
			ghost_west <= (others => FREE_CELL);
			ghost_east <= (others => FREE_CELL);
			ghost_current <= (others => FREE_CELL);
			ghost_direction <= (others => left);
			ghost_next_direction <= (others => left);
			ghost_a_direction <= (others => left);
			ghost_b_direction <= (others => left);
			ghost_c_direction <= (others => left);
			ghost_rev_direction <= (others => left);
			ghost_ai_direction <= (others => left);
			ghost_ai_selection <= (others => wander_around);
			ghost_action <= (others => random);
			ghost_target_x <= (others => (others => '0'));
			ghost_target_y <= (others => (others => '0'));
			ghost_next_x <= (others => (others => '0'));
			ghost_next_y <= (others => (others => '0'));
			ghost_next <= (others => FREE_CELL);
			ghost_next_a <= (others => FREE_CELL);
			ghost_next_b <= (others => FREE_CELL);
			ghost_next_c <= (others => FREE_CELL);
			ghost_ai_state <= (others => selecting);
			ghost_health <= (others => alive);
			ghost_collision <= (others => false);
			gap_a_x <= (others => '0');
			gap_a_y <= (others => '0');
			gap_b_x <= (others => '0');
			gap_b_y <= (others => '0');
			load_splash_flags <= (others => '0');
			load_map_flags <= (others => '0');
			game_start_flags <= (others => '0');
			game_start_wait_time <= (others => '0');
			ram_address_main <= (others => '0');
			ram_address_sel <= '0';
			ram_0_data_in <= (others => '0');
			ram_0_write <= '0';
			rom_address <= (others => '0');
			game_state <= game_reset;
			game_process_state <= process_movement;
		elsif rising_edge(clk_25Mhz) then
			level_speed <= level_speed_signal;
			level_ai <= level_ai_signal;
			pacman_x <= pacman_x_signal;
			pacman_y <= pacman_y_signal;
			pacman_sp_x <= pacman_sp_x_signal;
			pacman_sp_y <= pacman_sp_y_signal;
			pacman_north <= pacman_north_signal;
			pacman_south <= pacman_south_signal;
			pacman_west <= pacman_west_signal;
			pacman_east <= pacman_east_signal;
			pacman_current <= pacman_current_signal;
			pacman_direction <= pacman_direction_signal;
			pacman_change_direction <= pacman_change_direction_signal;
			pacman_next_direction <= pacman_next_direction_signal;
			pacman_next_x <= pacman_next_x_signal;
			pacman_next_y <= pacman_next_y_signal;
			pacman_next <= pacman_next_signal;
			pacman_state <= pacman_state_signal;
			pacman_lives <= pacman_lives_signal;
			pacman_pellets <= pacman_pellets_signal;
			pacman_score <= pacman_score_signal;
			pacman_level <= pacman_level_signal;
			pacman_super_time <= pacman_super_time_signal;
			pacman_start_time <= pacman_start_time_signal;
			ghost_x <= ghost_x_signal;
			ghost_y <= ghost_y_signal;
			ghost_pen_x <= ghost_pen_x_signal;
			ghost_pen_y <= ghost_pen_y_signal;
			ghost_north <= ghost_north_signal;
			ghost_south <= ghost_south_signal;
			ghost_west <= ghost_west_signal;
			ghost_east <= ghost_east_signal;
			ghost_current <= ghost_current_signal;
			ghost_direction <= ghost_direction_signal;
			ghost_next_direction <= ghost_next_direction_signal;
			ghost_a_direction <= ghost_a_direction_signal;
			ghost_b_direction <= ghost_b_direction_signal;
			ghost_c_direction <= ghost_c_direction_signal;
			ghost_rev_direction <= ghost_rev_direction_signal;
			ghost_ai_direction <= ghost_ai_direction_signal;
			ghost_ai_selection <= ghost_ai_selection_signal;
			ghost_action <= ghost_action_signal;
			ghost_target_x <= ghost_target_x_signal;
			ghost_target_y <= ghost_target_y_signal;
			ghost_next_x <= ghost_next_x_signal;
			ghost_next_y <= ghost_next_y_signal;
			ghost_next <= ghost_next_signal;
			ghost_next_a <= ghost_next_a_signal;
			ghost_next_b <= ghost_next_b_signal;
			ghost_next_c <= ghost_next_c_signal;
			ghost_ai_state <= ghost_ai_state_signal;
			ghost_health <= ghost_health_signal;
			ghost_collision <= ghost_collision_signal;
			gap_a_x <= gap_a_x_signal;
			gap_a_y <= gap_a_y_signal;
			gap_b_x <= gap_b_x_signal;
			gap_b_y <= gap_b_y_signal;
			load_splash_flags <= load_splash_flags_signal;
			load_map_flags <= load_map_flags_signal;
			game_start_flags <= game_start_flags_signal;
			game_start_wait_time <= game_start_wait_time_signal;
			ram_address_main <= ram_address_main_signal;
			ram_address_sel <= ram_address_sel_signal;
			ram_0_data_in <= ram_0_data_in_signal;
			ram_0_write <= ram_0_write_signal;
			rom_address <= rom_address_signal;
			game_state <= game_state_signal;
			game_process_state <= game_process_state_signal;
		end if;
	end process;
end rtl;