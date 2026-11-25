----------------------------------------------------------------------------------
-- x86_exec.vhd
-- Execution unit: executes the converted Intel 8086 instruction.
--
--   04 kk          ADD AL, kk          AL       <- AL + kk
--   02 06 aa 00    ADD AL, [00aa]      AL       <- AL + memory(aa)
--   00 06 aa 00    ADD [00aa], AL      memory(aa) <- memory(aa) + AL
--   90             NOP                 nothing
--
-- AL is the 8086 accumulator (register W of the PIC16F887).
-- The memory has 128 bytes (file registers 00h..7Fh of the PIC16F887).
-- flags = "000" & AF & OF & SF & ZF & CF
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity x86_exec is
    Port ( clk     : in  STD_LOGIC;
           rst     : in  STD_LOGIC;
           exec    : in  STD_LOGIC;                       -- '1' for one clock: execute
           x86_b0  : in  STD_LOGIC_VECTOR (7 downto 0);   -- opcode
           x86_b1  : in  STD_LOGIC_VECTOR (7 downto 0);   -- immediate value
           x86_b2  : in  STD_LOGIC_VECTOR (7 downto 0);   -- memory address
           al      : out STD_LOGIC_VECTOR (7 downto 0);
           flags   : out STD_LOGIC_VECTOR (7 downto 0));
end x86_exec;

architecture Behavioral of x86_exec is

    component x86_alu
        Port ( a      : in  STD_LOGIC_VECTOR (7 downto 0);
               b      : in  STD_LOGIC_VECTOR (7 downto 0);
               result : out STD_LOGIC_VECTOR (7 downto 0);
               cf     : out STD_LOGIC;
               zf     : out STD_LOGIC;
               sf     : out STD_LOGIC;
               ovf    : out STD_LOGIC;
               af     : out STD_LOGIC);
    end component;

    for all : x86_alu use entity work.x86_alu(Behavioral);

    constant OP_ADD_AL_IMM : std_logic_vector (7 downto 0) := x"04";
    constant OP_ADD_AL_MEM : std_logic_vector (7 downto 0) := x"02";
    constant OP_ADD_MEM_AL : std_logic_vector (7 downto 0) := x"00";

    type memory_array is array (0 to 127) of std_logic_vector (7 downto 0);
    signal memory   : memory_array := (others => x"00");

    signal al_reg   : std_logic_vector (7 downto 0) := x"00";
    signal flag_reg : std_logic_vector (7 downto 0) := x"00";

    signal mem_data : std_logic_vector (7 downto 0);     -- byte read from the memory
    signal op_b     : std_logic_vector (7 downto 0);     -- second operand of the adder
    signal sum      : std_logic_vector (7 downto 0);
    signal cf, zf, sf, ovf, af : std_logic;

begin

    -- read the memory byte at the address of the instruction
    mem_data <= memory(to_integer(unsigned(x86_b2(6 downto 0))));

    -- second operand: immediate value or memory byte
    op_b <= x86_b1 when x86_b0 = OP_ADD_AL_IMM else mem_data;

    -- the first operand is always AL
    U_ALU : x86_alu
        port map ( a => al_reg, b => op_b, result => sum,
                   cf => cf, zf => zf, sf => sf, ovf => ovf, af => af );

    process (clk)
    begin
        if rising_edge(clk) then
            if rst = '1' then
                al_reg   <= x"00";
                flag_reg <= x"00";
            elsif exec = '1' then
                if x86_b0 = OP_ADD_AL_IMM or x86_b0 = OP_ADD_AL_MEM then
                    al_reg   <= sum;                      -- destination: AL
                    flag_reg <= "000" & af & ovf & sf & zf & cf;
                elsif x86_b0 = OP_ADD_MEM_AL then
                    memory(to_integer(unsigned(x86_b2(6 downto 0)))) <= sum;   -- destination: memory
                    flag_reg <= "000" & af & ovf & sf & zf & cf;
                end if;
                -- any other opcode (NOP): nothing changes
            end if;
        end if;
    end process;

    al    <= al_reg;
    flags <= flag_reg;

end Behavioral;
