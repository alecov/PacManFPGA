library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package pacman_types is
	constant CANVAS_WIDTH     : positive := 40;
	constant CANVAS_HEIGHT    : positive := 30;
	constant MAP_WIDTH        : positive := 30;
	constant MAP_HEIGHT       : positive := 30;
	constant MAX_GHOSTS       : positive := 4;
	constant POINTS_PELLET    : positive := 10;
	constant POINTS_P_PELLET  : positive := 50;
	constant POINTS_GHOST     : positive := 100;
	constant POINTS_MAP       : positive := 1000;
	constant START_TIME       : positive := 15;
	constant START_WAIT_TIME  : positive := 10;
	constant SUPER_TIME       : positive := 60;
	constant SUPER_ALERT      : positive := 15;
	constant GHOST_SLOW       : positive := 40;
	constant GHOST_FAST       : positive := 40;
	constant ROM_LENGTH       : positive := MAP_WIDTH*MAP_HEIGHT;
	constant ROM_ADDR_LENGTH  : positive := 10; -- ceil(lg(MAP_WIDTH*MAP_HEIGHT))

	subtype pacman_cell       is std_logic_vector(2 downto 0);
	constant FREE_CELL        : pacman_cell := "000"; -- 0
	constant PELLET           : pacman_cell := "001"; -- 1
	constant P_PELLET         : pacman_cell := "010"; -- 2
	constant WALL             : pacman_cell := "011"; -- 3
	constant GHOST_WALL       : pacman_cell := "100"; -- 4
	constant GHOST_PEN        : pacman_cell := "101"; -- 5
	constant PACMAN_SP        : pacman_cell := "110"; -- 6
	constant GAP              : pacman_cell := "111"; -- 7

	subtype speed_t           is std_logic_vector(3 downto 0);
	subtype speed_base_t      is std_logic_vector(7 downto 0);
	subtype position_t        is std_logic_vector(4 downto 0);
	type direction_t          is (up, down, left, right);
	type pacman_state_t       is (selecting, moving);
	type game_process_state_t is (process_movement, process_pellet, assert_collision, process_collision);
	type ai_t                 is (wander_around, follow_pacman, run_pacman, follow_pen);
	type ai_state_t           is (selecting, analysing, acquiring, deciding, asserting, confirming_move, waiting, moving);
	type action_t             is (random, follow, run);
	type health_t             is (alive, weak, dead);
	type ghost_position_t     is array(MAX_GHOSTS-1 downto 0) of position_t;
	type ghost_adjacency_t    is array(MAX_GHOSTS-1 downto 0) of pacman_cell;
	type ghost_direction_t    is array(MAX_GHOSTS-1 downto 0) of direction_t;
	type ghost_ai_t           is array(MAX_GHOSTS-1 downto 0) of ai_t;
	type ghost_ai_state_t     is array(MAX_GHOSTS-1 downto 0) of ai_state_t;
	type ghost_action_t       is array(MAX_GHOSTS-1 downto 0) of action_t;
	type ghost_health_t       is array(MAX_GHOSTS-1 downto 0) of health_t;
	type ghost_collision_t    is array(MAX_GHOSTS-1 downto 0) of boolean;

	constant LEVEL_SPEED_0    : speed_t := conv_std_logic_vector(0, 4);
	constant LEVEL_SPEED_1    : speed_t := conv_std_logic_vector(1, 4);
	constant LEVEL_SPEED_2    : speed_t := conv_std_logic_vector(2, 4);
	constant LEVEL_SPEED_3    : speed_t := conv_std_logic_vector(3, 4);
	constant LEVEL_SPEED_4    : speed_t := conv_std_logic_vector(4, 4);
	constant LEVEL_SPEED_5    : speed_t := conv_std_logic_vector(5, 4);
	constant LEVEL_SPEED_6    : speed_t := conv_std_logic_vector(6, 4);
	constant LEVEL_SPEED_7    : speed_t := conv_std_logic_vector(7, 4);
	constant LEVEL_SPEED_8    : speed_t := conv_std_logic_vector(8, 4);
	constant LEVEL_SPEED_9    : speed_t := conv_std_logic_vector(9, 4);
	constant LEVEL_SPEED_10   : speed_t := conv_std_logic_vector(10, 4);
	constant LEVEL_SPEED_11   : speed_t := conv_std_logic_vector(11, 4);
	constant LEVEL_SPEED_12   : speed_t := conv_std_logic_vector(12, 4);
	constant LEVEL_SPEED_13   : speed_t := conv_std_logic_vector(13, 4);
	constant LEVEL_SPEED_14   : speed_t := conv_std_logic_vector(14, 4);
	constant LEVEL_SPEED_15   : speed_t := conv_std_logic_vector(15, 4);
	constant LEVEL_AI_0       : ghost_ai_t := (others => wander_around);
	constant LEVEL_AI_1       : ghost_ai_t := (follow_pacman, others => wander_around);
	constant LEVEL_AI_2       : ghost_ai_t := (follow_pacman, others => wander_around);
	constant LEVEL_AI_3       : ghost_ai_t := (follow_pacman, others => wander_around);
	constant LEVEL_AI_4       : ghost_ai_t := (follow_pacman, others => wander_around);
	constant LEVEL_AI_5       : ghost_ai_t := (follow_pacman, others => wander_around);
	constant LEVEL_AI_6       : ghost_ai_t := (follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_7       : ghost_ai_t := (follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_8       : ghost_ai_t := (follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_9       : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_10      : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_11      : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_12      : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_13      : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_14      : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, follow_pacman, others => wander_around);
	constant LEVEL_AI_15      : ghost_ai_t := (follow_pacman, follow_pacman, follow_pacman, follow_pacman, others => wander_around);
end pacman_types;