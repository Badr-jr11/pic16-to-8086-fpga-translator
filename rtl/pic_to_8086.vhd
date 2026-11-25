----------------------------------------------------------------------------------
-- pic_to_8086.vhd
-- Converter (decoder) of PIC16F887 addition instructions to Intel 8086 code.
--
--   PIC16F887 (14-bit code)            Intel 8086 (machine code)
--   ADDLW k    11 111x kkkk kkkk  -->  ADD AL, k        04 kk
--   ADDWF f,0  00 0111 0fff ffff  -->  ADD AL, [00ff]   02 06 ff 00
--   ADDWF f,1  00 0111 1fff ffff  -->  ADD [00ff], AL   00 06 ff 00
--   any other instruction         -->  NOP              90   (error = '1')
--
-- The PIC register W corresponds to the 8086 register AL.
-- The PIC file register f corresponds to the 8086 memory byte at address 00ffh.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity pic_to_8086 is
    Port ( pic_code : in  STD_LOGIC_VECTOR (13 downto 0);
           x86_b0   : out STD_LOGIC_VECTOR (7 downto 0);
           x86_b1   : out STD_LOGIC_VECTOR (7 downto 0);
           x86_b2   : out STD_LOGIC_VECTOR (7 downto 0);
           x86_b3   : out STD_LOGIC_VECTOR (7 downto 0);
           x86_len  : out STD_LOGIC_VECTOR (2 downto 0);
           error    : out STD_LOGIC);
end pic_to_8086;

architecture Behavioral of pic_to_8086 is
begin

    process (pic_code)
    begin
        -- default: instruction is not an addition -> NOP
        x86_b0  <= x"90";
        x86_b1  <= x"00";
        x86_b2  <= x"00";
        x86_b3  <= x"00";
        x86_len <= "001";
        error   <= '1';

        if pic_code(13 downto 9) = "11111" then
            -- ADDLW k  ->  ADD AL, imm8
            x86_b0  <= x"04";
            x86_b1  <= pic_code(7 downto 0);
            x86_len <= "010";
            error   <= '0';

        elsif pic_code(13 downto 8) = "000111" then
            -- ADDWF f,d
            if pic_code(7) = '0' then
                x86_b0 <= x"02";            -- d = 0: ADD AL, [addr]
            else
                x86_b0 <= x"00";            -- d = 1: ADD [addr], AL
            end if;
            x86_b1  <= x"06";               -- ModR/M: mod=00, reg=AL, r/m=110 (direct address)
            x86_b2  <= '0' & pic_code(6 downto 0);   -- address, low byte
            x86_b3  <= x"00";               -- address, high byte
            x86_len <= "100";
            error   <= '0';
        end if;
    end process;

end Behavioral;
