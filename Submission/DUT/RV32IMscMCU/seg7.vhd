-- seg7.vhd
-- 4-bit hexadecimal -> 7-segment decoder.  (reused from Lab 4)
-- Active-LOW segment outputs (DE2-115 convention).
-- Segment order: seg_o(6..0) = g f e d c b a

LIBRARY ieee;
USE ieee.std_logic_1164.all;

ENTITY seg7 IS
	PORT (
		nibble_i : IN  STD_LOGIC_VECTOR(3 DOWNTO 0);
		seg_o    : OUT STD_LOGIC_VECTOR(6 DOWNTO 0)
	);
END seg7;

ARCHITECTURE rtl OF seg7 IS
BEGIN
	WITH nibble_i SELECT
		seg_o <= "1000000" WHEN "0000",  -- 0
		         "1111001" WHEN "0001",  -- 1
		         "0100100" WHEN "0010",  -- 2
		         "0110000" WHEN "0011",  -- 3
		         "0011001" WHEN "0100",  -- 4
		         "0010010" WHEN "0101",  -- 5
		         "0000010" WHEN "0110",  -- 6
		         "1111000" WHEN "0111",  -- 7
		         "0000000" WHEN "1000",  -- 8
		         "0010000" WHEN "1001",  -- 9
		         "0001000" WHEN "1010",  -- A
		         "0000011" WHEN "1011",  -- b
		         "1000110" WHEN "1100",  -- C
		         "0100001" WHEN "1101",  -- d
		         "0000110" WHEN "1110",  -- E
		         "0001110" WHEN "1111",  -- F
		         "1111111" WHEN OTHERS;  -- blank
END rtl;
