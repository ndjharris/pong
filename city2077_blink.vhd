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

entity city2077_blink is

	port(
		MAX10_CLK1_50	: in	std_logic;
		KEY			: in	std_logic_vector(1 downto 0); -- Reset and toggle buttons
		LEDR			: out	std_logic_vector(9 downto 0);
		HEX0			:	out std_logic_vector(7 downto 0);
		HEX1			:	out std_logic_vector(7 downto 0)
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

signal clk			: std_logic;
signal reset		: std_logic;
signal resetn		: std_logic;
signal button		: std_logic;
signal ledState	: std_logic;
signal state		: std_logic_vector(1 downto 0);
signal count		: std_logic_vector(3 downto 0);

begin
	clk <= Max10_clk1_50;
	reset <= key(1);
	resetn <= not reset;
	button <= key(0);

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
	
	bincount : counter port map(button, resetn, count);
	hexlsb 	: hexdisplay port map(count, HEX0(7 downto 0));

	ledState <= state(1);
	LEDR(0) <= ledState;
	LEDR(9 downto 6) <= count(3 downto 0);

end rtl;
