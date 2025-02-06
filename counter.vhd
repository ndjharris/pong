--**Problem 2:  4-bit Binary Counter**
--
--* **Objective:** Implement a 4-bit binary counter that increments on each clock cycle. Display the count on four LEDs.
--* **VHDL Concepts:**  Clock signals, processes sensitive to clock edges, counter implementation using `if` or `when-else` statements, concurrent signal assignment.
--* **Hardware:** Four LEDs.
--* **Steps:**
--    1. Create a new VHDL project.
--    2. Define an input clock port and four output LED ports.
--    3. Use a process sensitive to the clock's rising edge.
--    4. Implement a 4-bit counter inside the process.
--    5. Assign the counter's output to the four LEDs.
--    6. Synthesize, compile, and download the design.
--    7. Verify the counter's operation.

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity counter is

	port(
			countclock 	:	in	std_logic; 
			reset			:	in std_logic;
			leds			:	out std_logic_vector(3 downto 0)
		);
end entity;

architecture rtl of counter is

signal count : integer range 0 to 15;

begin

	process (countclock, reset)
		begin
			if reset = '1' then
				count <= 0;
			elsif (rising_edge(countclock)) then -- do a count
				count <= count + 1;
			end if;
	end process;
	leds(3 downto 0) <= std_logic_vector(to_unsigned(count, 4));
end rtl;

