----------------------------------------------------------------------------------
-- x86_alu.vhd
-- 8-bit adder of the Intel 8086 with the flags of the ADD instruction.
--
--   result = a + b
--   CF  carry flag            carry out of bit 7
--   ZF  zero flag             result = 0
--   SF  sign flag             bit 7 of the result
--   OVF overflow flag         signed overflow
--   AF  auxiliary carry flag  carry out of bit 3 (as DC in the PIC16F887)
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity x86_alu is
    Port ( a      : in  STD_LOGIC_VECTOR (7 downto 0);
           b      : in  STD_LOGIC_VECTOR (7 downto 0);
           result : out STD_LOGIC_VECTOR (7 downto 0);
           cf     : out STD_LOGIC;
           zf     : out STD_LOGIC;
           sf     : out STD_LOGIC;
           ovf    : out STD_LOGIC;
           af     : out STD_LOGIC);
end x86_alu;

architecture Behavioral of x86_alu is
    signal sum_ext : unsigned (8 downto 0);      -- 9 bits: carry + result
    signal sum_low : unsigned (4 downto 0);      -- 5 bits: half carry + low nibble
begin

    -- 8-bit addition with carry
    sum_ext <= ('0' & unsigned(a)) + ('0' & unsigned(b));

    -- addition of the low nibbles (for the auxiliary carry)
    sum_low <= ('0' & unsigned(a(3 downto 0))) + ('0' & unsigned(b(3 downto 0)));

    -- result
    result <= std_logic_vector(sum_ext(7 downto 0));

    -- carry flag
    cf <= sum_ext(8);

    -- zero flag
    zf <= '1' when sum_ext(7 downto 0) = 0 else '0';

    -- sign flag
    sf <= sum_ext(7);

    -- overflow flag: both operands have the same sign, the result has another sign
    ovf <= (a(7) and b(7) and not sum_ext(7)) or
           (not a(7) and not b(7) and sum_ext(7));

    -- auxiliary carry flag
    af <= sum_low(4);

end Behavioral;
