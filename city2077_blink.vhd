-- **Problem 1: Basic LED Control**

--* **Objective:** Control a single LED on the DE10-Lite using a push-button.  The LED should toggle its state each time the button is pressed.
--* **VHDL Concepts:** Input/output ports, signals, processes, concurrent statements, `if` statements.
--* **Hardware:**  One push-button, one LED.
--* **Steps:**
--    1. Create a new VHDL project in Quartus.
--    2. Define input and output ports for the button and LED.
--   3. Use a process to monitor the button's state.
--    4. When the button is pressed, toggle the LED's output.
--    5. Synthesize, compile, and download the design to the DE10-Lite.
--    6. Test the functionality.


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity city2077_blink is

	port(
		MAX10_CLK1_50	: in	std_logic;
		KEY			: in	std_logic_vector(1 downto 0); -- Reset and toggle buttons
		LEDR			: out	std_logic_vector(9 downto 0);
		HEX0			:	out std_logic_vector(7 downto 0);
		HEX1			:	out std_logic_vector(7 downto 0);
		VGA_R			:	out Std_logic_vector(3 downto 0);
		VGA_G			:	out Std_logic_vector(3 downto 0);
		VGA_B			:	out Std_logic_vector(3 downto 0);
		VGA_HS		:	out std_logic;
		VGA_VS		:	out std_logic
		
	);

end entity;


architecture rtl of city2077_blink is

component counter is

	port(
			countclock 	:	in	std_logic; 
			reset			:	in std_logic;
			leds			:	out std_logic_vector(3 downto 0)
		);
end component;

component hexdisplay is
	
	port(
			values	: in std_logic_vector(3 downto 0);
			hexout	: out std_logic_vector(7 downto 0)
		);
end component;

component  video_sync_generator is
	port(
			reset		:	in std_logic;
			vga_clk	:	in std_logic;
			blank_n	:	out std_logic;
         HS			:	out std_logic;
         VS			:	out std_logic;
			xPos		:	out std_logic_vector(10 downto 0);
			yPos		:	out std_logic_vector(9 downto 0)
		);
end component;


component vgaClockPLL
	PORT
	(
		inclk0		: 	IN STD_LOGIC  := '0';
		c0				:	OUT STD_LOGIC 
	);
end component;


                            

signal clk			: std_logic;
signal reset		: std_logic;
signal resetn		: std_logic;
signal button		: std_logic;
signal ledState	: std_logic;
signal state		: std_logic_vector(1 downto 0);
signal count		: std_logic_vector(3 downto 0);
signal countlsb	: std_logic_vector(3 downto 0);
signal countmsb	: std_logic_vector(3 downto 0);
signal counti		: integer range 0 to 100   := 0;
signal countunits	: integer range 0 to 10   := 0;
signal counttens	: integer range 0 to 10   := 0;

signal blanking	: std_logic;
signal vgaClk		: std_logic;
signal HSync		: std_logic;
signal VSync		: std_logic;
signal RGB_R		: std_logic_vector(3 downto 0);
signal RGB_G		: std_logic_vector(3 downto 0);
signal RGB_B		: std_logic_vector(3 downto 0);

signal Xp			: std_logic_vector(10 downto 0);
signal Xpi			: integer range 0 to 639;
signal Yp			: std_logic_vector(9 downto 0);
signal Ypi			: integer range 0 to 479;



begin
	clk <= Max10_clk1_50;
	reset <= key(1);
	resetn <= not reset;
	button <= key(0);
	counti <= to_integer(unsigned(count));
	countunits <= counti mod 10;
	counttens <= counti / 10;
	countlsb <= std_logic_vector(to_unsigned(countunits, 4));
	countmsb <= std_logic_vector(to_unsigned(counttens, 4));
	Xpi <= to_integer(unsigned(Xp));
	ypi <= to_integer(unsigned(Yp));
	VGA_VS <= VSync;
	VGA_HS <= HSync;
	VGA_R	<= RGB_R;
	VGA_G	<= RGB_G;
	VGA_B	<= RGB_B;
	


	-- Logic to toggle Led state
	
	process (clk, resetn, button)
	
	
	begin

		if resetn = '1' then
			state <= "00";
		elsif (rising_edge(clk)) then -- LED off waiting for button press
			if (state = "00") then
				if (button = '1') then
					state <= "01";
				else
					state <= "00";
				end if;
			elsif (state = "01") then -- LED off button pressed waiting for button release
				if (button = '0') then
					state <= "10";
				else
					state <= "01";
				end if;
			elsif (state = "10") then -- LED on waiting for button press
				if (button = '1') then
					state <= "11";
				else
					state <= "10";
				end if;
			elsif (state = "11") then -- LED on button pressed waiting for button release
				if (button = '0') then
					state <= "00";
				else
					state <= "11";
				end if;
			end if;
		end if;
	end process;
	
	process(vgaClk, Xpi, Ypi)
	begin 
		if ( (Xpi-counti*10)> 50) AND ((Xpi-counti*10) < 100) AND ( Ypi > 50) AND (Ypi < 100)	then
			RGB_R <= x"7";
			RGB_G	<= x"0";
			RGB_B	<= x"7";
		else
			RGB_R <= x"0";
			RGB_G	<= x"0";
			RGB_B	<= x"0";
		end if;
	end process;
		
	
	bincount : counter port map(button, resetn, count);
	hexlsb 	: hexdisplay port map(countlsb, HEX0(7 downto 0));
	hexmsb	: hexdisplay port map(countmsb, HEX1(7 downto 0));
	display	: video_sync_generator port map( resetn, vgaClk, blanking, Hsync, Vsync, Xp, Yp );
	vgaClock	: vgaClockPLL port map( clk, vgaClk);

	ledState <= state(1);
	LEDR(0) <= ledState;
	LEDR(9 downto 6) <= count(3 downto 0);

end rtl;
