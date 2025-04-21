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
		ADC_CLK_10	: in	std_logic;
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

component paddle
    port (
      CLOCK : in  std_logic := 'X';               -- clk
      RESET : in  std_logic := 'X';               -- reset
      CH0   : out std_logic_vector(11 downto 0);  -- CH0
      CH1   : out std_logic_vector(11 downto 0);  -- CH1
      CH2   : out std_logic_vector(11 downto 0);  -- CH2
      CH3   : out std_logic_vector(11 downto 0);  -- CH3
      CH4   : out std_logic_vector(11 downto 0);  -- CH4
      CH5   : out std_logic_vector(11 downto 0);  -- CH5
      CH6   : out std_logic_vector(11 downto 0);  -- CH6
      CH7   : out std_logic_vector(11 downto 0)   -- CH7
      );
  end component paddle;
                            
  component txtScreen
--       generic(); -- pixel position
    port(
      hp, vp :    integer;
      addr   : in std_logic_vector(11 downto 0);  -- text screen ram
      data   : in std_logic_vector(7 downto 0);
      nWr    : in std_logic;
      pClk   : in std_logic;
      nblnk  : in std_logic;

      pix : out std_logic

      );
  end component;
  
signal clk			: std_logic;
signal reset		: std_logic;
signal resetn		: std_logic;
signal button		: std_logic;
signal ledState	: std_logic;
signal state		: std_logic_vector(1 downto 0);

signal plyr1lsb	: std_logic_vector(7 downto 0);
signal plyr1msb	: std_logic_vector(7 downto 0);
signal plyr2lsb	: std_logic_vector(7 downto 0);
signal plyr2msb	: std_logic_vector(7 downto 0);


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

signal paddlepos1 : std_logic_vector (11 downto 0); -- adc inputs
signal paddlepos2 : std_logic_vector (11 downto 0);
signal paddlepos3 : std_logic_vector (11 downto 0);
signal paddlepos4 : std_logic_vector (11 downto 0);

signal paddle1pos	: integer range 0 to 479 := 240;
signal paddle1sz	: integer range 0 to 100 := 40;
signal player1scr : integer := 0;
signal paddle2pos	: integer range 0 to 479 := 240;
signal paddle2sz	: integer range 0 to 100 := 40;
signal player2scr : integer := 0;

signal cycle      : integer                 := 0;  -- memory write cycle
signal charpos 	: integer range 0 to 4191 := 0;  -- character position from start of screen memory

signal txtaddress : std_logic_vector(11 downto 0);
signal txtdata    : std_logic_vector(7 downto 0);
signal wren       : std_logic;
signal txtpixel   : std_logic;

signal ball_speed_multiplier : integer range 1 to 5 := 1;
signal ball_base_speed : integer range 1 to 3 := 1;
signal speed_level : integer range 1 to 10 := 1;
signal speed_level_threshold : integer range 0 to 50 := 5;
signal ball_colour : std_logic_vector(11 downto 0) := x"FF0"; -- Yellow by default


begin
	clk <= Max10_clk1_50;
	reset <= key(1);
	resetn <= not reset;
	button <= key(0);

	plyr1msb <= std_logic_vector(to_unsigned(player1scr mod 10, 8));
	plyr1lsb <= std_logic_vector(to_unsigned(player1scr / 10, 8));

	plyr2msb <= std_logic_vector(to_unsigned(player2scr mod 10, 8));
	plyr2lsb <= std_logic_vector(to_unsigned(player2scr / 10, 8));
	
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
	  process(max10_clk1_50)
  begin  -- update the display with player scores
    if (rising_edge(clk)) then
      if resetn = '1' then
        txtaddress <= "000000000000";
        txtdata    <= "00000000";
        wren       <= '0';
        cycle      <= 0;
        charpos    <= 0;
      else
        if cycle = 0 then               -- state machine for writing to text
                                     -- memory with ascii code values
          cycle      <= 1;
          wren       <= '0';
          txtAddress <= std_logic_vector(to_unsigned(charpos, txtAddress'length));
          if charpos = 2 then
            txtdata <= plyr1lsb or "00110000";  -- write p1 tens to display and convert to ascii
          elsif charpos = 3 then
            txtdata <= plyr1msb or "00110000";  -- write p1 units to display and convert to ascii
--          elsif charpos = 98 then
--            txtdata <= std_logic_vector(to_unsigned(games1, txtdata'length));  -- write p1 units to display
--          elsif charpos = 101 then
--            txtdata <= std_logic_vector(to_unsigned(games2, txtdata'length));  -- write p1 units to display
          elsif charpos = 36 then
            txtdata <= plyr2lsb or "00110000";  -- write p2 tens to display and convert to ascii
          elsif charpos = 37 then
            txtdata <= plyr2msb or "00110000";  -- write p2 units to display and convert to ascii
          else cycle <= 2;
          end if;

        elsif cycle = 1 then            -- strobe wren high for one clock
          wren  <= '1';
          cycle <= 2;
        else                  -- cycle is 2, reset cycle and increment
                        -- memory address for next
                                  -- character position
          wren  <= '0';
          cycle <= 0;
          if charpos < 1023 then
            charpos <= charpos + 1;
          else
            charpos <= 0;
          end if;
        end if;
      end if;
    end if;
  end process;
	
	-- Update Display
	
	
	process(vgaClk, Xpi, Ypi, blanking)
	begin
		-- clear
		RGB_R <= x"0";
		RGB_G <= x"0";
		RGB_B <= x"0";
		if (blanking = '1') then -- Only update display while blanking is high
			-- Draw Text
			if txtPixel = '1' then
				RGB_R <= x"f";
				RGB_G <= x"f";
				RGB_B <= x"f";            
			-- Draw Paddles
			elsif ((( Xpi> 20) AND (Xpi < 40) AND ( Ypi > (paddle1pos - paddle1sz)) AND (Ypi < (paddle1pos + paddle1sz)))
				or (( Xpi> 600) AND (Xpi < 620) AND ( Ypi > (paddle2pos - paddle2sz)) AND (Ypi < (paddle2pos + paddle2sz))))
				then
				RGB_R <= x"f";
				RGB_G <= x"f";
				RGB_B <= x"f";
				
			-- Draw the Ball with dynamic colour
			elsif ( (Xpi>ballX-ballSize/2) AND (Xpi<ballX+ballSize/2) AND 
					(Ypi>ballY-ballSize/2) AND (Ypi<ballY+ballSize/2)) then
				RGB_R <= ball_colour(11 downto 8);
				RGB_G <= ball_colour(7 downto 4);
				RGB_B <= ball_colour(3 downto 0);
				
			-- draw the playfield edges
			elsif (YPi = 50 or Ypi = 479 or (Xpi = 1 and Ypi >50) or (xpi = 639 and Ypi >50)) then
				RGB_R <= x"f";
				RGB_G <= x"f";
				RGB_B <= x"f";
				
			-- Background - add subtle colour change based on speed level
			elsif (Xpi > 0 and Xpi < 640 and Ypi > 50 and yPi < 480 ) then
				RGB_R <= x"0";
				RGB_G <= x"7";
				RGB_B <= std_logic_vector(to_unsigned(speed_level-1, 4)); -- Background gets bluer with higher levels
			elsif (Ypi >= 10 and Ypi <= 30) then
				-- Draw speed level bar
				if (Xpi >= 220 and Xpi <= 220 + (speed_level * 20) and Ypi >= 15 and Ypi <= 25) then
					-- colour the bar based on speed level
					case speed_level is
						when 1 to 3 => 
							RGB_R <= x"0";
							RGB_G <= x"f";
							RGB_B <= x"0"; -- Green for low levels
						when 4 to 6 => 
							RGB_R <= x"f";
							RGB_G <= x"f";
							RGB_B <= x"0"; -- Yellow for mid levels
						when 7 to 10 => 
							RGB_R <= x"f";
							RGB_G <= x"0";
							RGB_B <= x"0"; -- Red for high levels
						when others => 
							RGB_R <= x"f";
							RGB_G <= x"f";
							RGB_B <= x"f";
					end case;
				end if;	
			end if;
		end if;
	end process;

	
	-- move Ball - synchronised to Vsync 60Hz
	process(VSync, ballX, BallY)
	begin
		if resetn = '1' then
			ballX <= 320;
			ballY <= 240;
			ballXDir <= 1;
			ballYDir <= 1;
			ball_speed_multiplier <= 1;
			speed_level <= 1;
			ball_colour <= x"FF0"; -- Yellow
		elsif (rising_edge(VSync)) then 
			-- Calculate total score and adjust speed level
			if (player1scr + player2scr) >= speed_level * speed_level_threshold then
				if speed_level < 10 then
					speed_level <= speed_level + 1;
					
					-- Update ball colour based on speed level
					case speed_level is
						when 1 => ball_colour <= x"FF0"; -- Yellow
						when 2 => ball_colour <= x"FA0"; -- Orange
						when 3 => ball_colour <= x"F70"; -- Darker orange
						when 4 => ball_colour <= x"F50"; -- Light red
						when 5 => ball_colour <= x"F00"; -- Red
						when 6 => ball_colour <= x"F0F"; -- Magenta
						when 7 => ball_colour <= x"A0F"; -- Purple
						when 8 => ball_colour <= x"70F"; -- Violet
						when 9 => ball_colour <= x"50F"; -- Blue-violet
						when 10 => ball_colour <= x"00F"; -- Blue
						when others => ball_colour <= x"FF0"; -- Default yellow
					end case;
				end if;
			end if;
			
			-- Calculate ball speed based on speed level
			ball_speed_multiplier <= 1 + (speed_level / 3); -- Increases by 1 every 3 levels
			
			-- Move ball with dynamic speed
			for i in 1 to ball_speed_multiplier loop
				ballx <= ballx + ballXDir;
				bally <= bally + BallYDir;
			end loop;
			
			-- AI player2 control - make AI smarter at higher levels
			if speed_level <= 5 then
				-- Basic AI at lower levels
				paddle2pos <= bally;
			else
				-- Predictive AI at higher levels - tries to anticipate ball position
				if ballXDir > 0 and ballX > 320 then
					paddle2pos <= bally + (ballYDir * (600 - ballX) / 20);
				else
					paddle2pos <= bally;
				end if;
			end if;

			-- player 1 paddle hit
			if ((ballX < 40 + (ballSize /2)) and 
				((ballY >= paddle1pos - paddle1sz) and (ballY < paddle1pos + paddle1sz))) 
			then
				ballXdir <= 1;    
				ballx <= ballX + 1;
				
			-- player 2 paddle hit
			elsif ((ballX > 600 - (ballSize /2)) and 
				((ballY >= paddle2pos - paddle2sz) and (ballY < paddle2pos + paddle2sz))) 
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
			
			-- player controlled paddles
			paddle1pos <= (paddle1pos + (to_integer(unsigned(paddlepos1(11 downto 3)))))/2;
			paddle2pos <= (paddle2pos + (to_integer(unsigned(paddlepos2(11 downto 3)))))/2;
		end if;
	end process;

	
	
	
	-- Instantiate components
	
	hexlsb 	: hexdisplay port map(plyr1lsb(3 downto 0), HEX4(7 downto 0));
	hexmsb	: hexdisplay port map(plyr1msb(3 downto 0), HEX5(7 downto 0));
	hexlsb2 	: hexdisplay port map(plyr2lsb(3 downto 0), HEX0(7 downto 0));
	hexmsb2	: hexdisplay port map(plyr2msb(3 downto 0), HEX1(7 downto 0));
	display	: video_sync_generator port map( resetn, vgaClk, blanking, Hsync, Vsync, Xp, Yp );
	vgaClock	: vgaClockPLL port map( clk, vgaClk);
	paddling	: paddle
    port map (
      CLOCK => ADC_CLK_10,              --      clk.clk
      RESET => resetn,                     --    reset.reset
      CH0   => paddlepos1,              -- readings.CH0
      CH1   => paddlepos2,              --         .CH1
      CH2   => paddlepos3,              --         .CH2
      CH3   => paddlepos4               --         .CH3
--                      CH4   => CONNECTED_TO_CH4,   --         .CH4
--                      CH5   => CONNECTED_TO_CH5,   --         .CH5
--                      CH6   => CONNECTED_TO_CH6,   --         .CH6
--                      CH7   => CONNECTED_TO_CH7    --         .CH7
      );
	 txtscreenInst : component txtscreen port map (
		xPi,
		yPi,
		txtaddress,
		txtdata,
		wren,
		vgaclk,
		blanking,
		txtpixel
    );
	ledState <= state(1);
	LEDR(0) <= ledState;

end rtl;
