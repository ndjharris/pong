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
		HEX4			:	out std_logic_vector(7 downto 0);
		HEX5			:	out std_logic_vector(7 downto 0);
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

signal plyr1lsb	: std_logic_vector(3 downto 0);
signal plyr1msb	: std_logic_vector(3 downto 0);
signal plyr2lsb	: std_logic_vector(3 downto 0);
signal plyr2msb	: std_logic_vector(3 downto 0);


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

signal ballX		: integer range 0 to 639 := 320;
signal ballXdir	: integer range -1 to 1 := 1;
signal ballY		: integer range 0 to 479 := 240;
signal ballydir	: integer range -1 to 1 := 1;
signal ballSize	: integer range 1 to 100 := 20;

signal paddle1pos	: integer range 0 to 479 := 240;
signal paddle1sz	: integer range 0 to 100 := 40;
signal player1scr : integer range 0 to 21 := 0;
signal paddle2pos	: integer range 0 to 479 := 240;
signal paddle2sz	: integer range 0 to 100 := 40;
signal player2scr : integer range 0 to 21 := 0;




begin
	clk <= Max10_clk1_50;
	reset <= key(1);
	resetn <= not reset;
	button <= key(0);

	plyr1lsb <= std_logic_vector(to_unsigned(player1scr mod 10, 4));
	plyr1msb <= std_logic_vector(to_unsigned(player1scr / 10, 4));

	plyr2lsb <= std_logic_vector(to_unsigned(player2scr mod 10, 4));
	plyr2msb <= std_logic_vector(to_unsigned(player2scr / 10, 4));
	
	Xpi <= to_integer(unsigned(Xp));
	ypi <= to_integer(unsigned(Yp));
	VGA_VS <= VSync;
	VGA_HS <= HSync;
	VGA_R	<= RGB_R;
	VGA_G	<= RGB_G;
	VGA_B	<= RGB_B;
	


	-- Logic to toggle Led state
	
	process (clk, resetn, button)
	
	-- Get Inputs
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
	
	-- Update Display
	
	process(vgaClk, Xpi, Ypi, blanking)
	begin
--		-- clear
		RGB_R <= x"0";
		RGB_G	<= x"0";
		RGB_B	<= x"0";
		if (blanking = '1') then
			-- Draw Paddles
			if ((( Xpi> 20) AND (Xpi < 40) AND ( Ypi > (paddle1pos - paddle1sz)) AND (Ypi < (paddle1pos + paddle1sz)))
				or (( Xpi> 600) AND (Xpi < 620) AND ( Ypi > (paddle2pos - paddle2sz)) AND (Ypi < (paddle2pos + paddle2sz))))
				then
				RGB_R <= x"f";
				RGB_G	<= x"f";
				RGB_B	<= x"f";
				
				-- Draw the Ball
			elsif ( (Xpi>ballX-ballSize/2) AND (Xpi<ballX+ballSize/2) AND 
					  (Ypi>ballY-ballSize/2) AND (Ypi<ballY+ballSize/2))	then
				RGB_R <= x"f";
				RGB_G	<= x"f";
				RGB_B	<= x"0";
				-- draw the playfield edges
			elsif (YPi = 50 or Ypi = 479 or (Xpi = 1 and Ypi >50) or (xpi = 639 and Ypi >50)) then
				RGB_R <= x"f";
				RGB_G	<= x"f";
				RGB_B	<= x"f";
				-- Background
			elsif (Xpi > 0 and Xpi < 640 and Ypi > 50 and yPi < 480 ) then
				RGB_R <= x"0";
				RGB_G	<= x"7";
				RGB_B	<= x"0";
			end if;
		end if;
	end process;
	
	-- move Ball - synchronised to Vsync 60Hz
	process( VSync, ballX, BallY)
		begin
			if resetn = '1' then
				ballX <= 320;
				ballY <= 240;
				ballXDir <= 1;
				ballYDir <= 1;
			elsif (rising_edge(VSync)) then 
				ballx <= ballx + ballXDir;
				bally	<= bally + BallYDir;
				-- AI player2 control
				paddle2pos <= bally;

			   -- player 1 paddle hit
				if ((ballX < 40 + (ballSize /2)) and 
				((ballY >= paddle1pos - paddle1sz/2) and (ballY < paddle1pos + paddle1sz/2))) 
				then
					ballXdir <= 1;	
					ballx <= ballX + 1;
					
			   -- player 2 paddle hit
				elsif ((ballX > 600 - (ballSize /2)) and 
				((ballY >= paddle2pos - paddle2sz/2) and (ballY < paddle2pos + paddle2sz/2))) 
				then
					ballXdir <= -1;	
					ballx <= ballX - 1;
				
				-- ball hits left edge
				elsif ballX > 630 then
					ballXdir <= -1;
					ballx <= 320;
					player1scr <= player1scr + 1;
				-- ball hits right edge
				elsif ballX < 20 then
					ballXdir <= 1;
					ballx <= 320;
					player2scr <= player2scr + 1;
				end if;
				-- ball hits bottom edge
				if ballY > 470 then
					ballYdir <= -1;
				-- ball hits top edge
				elsif ballY < 60 then
					ballYdir <= 1;
				end if;
			end if;
			
	end process;
	
	
	
	-- Instantiate components
	
	hexlsb 	: hexdisplay port map(plyr1lsb, HEX4(7 downto 0));
	hexmsb	: hexdisplay port map(plyr1msb, HEX5(7 downto 0));
	hexlsb2 	: hexdisplay port map(plyr2lsb, HEX0(7 downto 0));
	hexmsb2	: hexdisplay port map(plyr2msb, HEX1(7 downto 0));
	display	: video_sync_generator port map( resetn, vgaClk, blanking, Hsync, Vsync, Xp, Yp );
	vgaClock	: vgaClockPLL port map( clk, vgaClk);

	ledState <= state(1);
	LEDR(0) <= ledState;

end rtl;
