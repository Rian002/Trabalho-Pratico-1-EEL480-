library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ula_4bits is
    port (
        clk         : in  std_logic;                     -- System clock
        reset       : in  std_logic;                     -- Reset button
        confirm     : in  std_logic;                     -- Confirm button
        switches    : in  std_logic_vector(3 downto 0);  -- 4-bit input switches
        leds_result : out std_logic_vector(3 downto 0);  -- Result LEDs
        led_zero    : out std_logic;                     -- Zero flag LED
        led_neg     : out std_logic;                     -- Negative flag LED
        led_carry   : out std_logic;                     -- Carry-out flag LED
        led_ovfl    : out std_logic;                     -- Overflow flag LED
        state_debug : out std_logic_vector(1 downto 0)   -- State debug LEDs
    );
end ula_4bits;

architecture behavioral of ula_4bits is
    -- State definitions
    type state_type is (S_OP, S_A, S_B, S_RESULT);
    signal state : state_type := S_OP;

    -- Input registers
    signal op_code  : std_logic_vector(3 downto 0) := (others => '0');
    signal operandA : std_logic_vector(3 downto 0) := (others => '0');
    signal operandB : std_logic_vector(3 downto 0) := (others => '0');

    -- Output/result signals
    signal result   : std_logic_vector(3 downto 0) := (others => '0');
    signal zero     : std_logic := '0';
    signal negative : std_logic := '0';
    signal carry    : std_logic := '0';
    signal overflow : std_logic := '0';

    -- Debounce signals
    signal confirm_prev : std_logic := '0';
    signal confirm_edge : std_logic := '0';

begin

    -- Debounce and edge detection for confirm button
    process(clk)
    begin
        if rising_edge(clk) then
            confirm_edge <= confirm and not confirm_prev;
            confirm_prev <= confirm;
        end if;
    end process;

    -- Main state machine
    process(clk, reset)
    begin
        if reset = '1' then
            state <= S_OP;
            op_code <= (others => '0');
            operandA <= (others => '0');
            operandB <= (others => '0');
        elsif rising_edge(clk) then
            case state is
                when S_OP =>
                    if confirm_edge = '1' then
                        op_code <= switches;
                        state <= S_A;
                    end if;

                when S_A =>
                    if confirm_edge = '1' then
                        operandA <= switches;
                        state <= S_B;
                    end if;

                when S_B =>
                    if confirm_edge = '1' then
                        operandB <= switches;
                        state <= S_RESULT;
                    end if;

                when S_RESULT =>
                    if confirm_edge = '1' then
                        state <= S_OP;
                    end if;
            end case;
        end if;
    end process;

    -- ALU logic block
    process(op_code, operandA, operandB)
        variable a_ext, b_ext, temp : unsigned(4 downto 0);
        variable result_signed : signed(4 downto 0);
    begin
        a_ext := unsigned('0' & operandA);
        b_ext := unsigned('0' & operandB);

        case op_code is
            when "0000" => -- Addition (A + B)
                temp := a_ext + b_ext;
                result_signed := signed('0' & operandA) + signed('0' & operandB);
                overflow <= result_signed(4) xor result_signed(3);

            when "0001" => -- Subtraction (A - B)
                temp := a_ext - b_ext;
                result_signed := signed('0' & operandA) - signed('0' & operandB);
                overflow <= result_signed(4) xor result_signed(3);

            when "0010" => -- Increment A
                temp := a_ext + 1;
                result_signed := signed('0' & operandA) + 1;
                overflow <= result_signed(4) xor result_signed(3);

            when "0011" => -- Decrement A
                temp := a_ext - 1;
                result_signed := signed('0' & operandA) - 1;
                overflow <= result_signed(4) xor result_signed(3);

            when "0100" => -- AND
                temp := '0' & (unsigned(operandA) and unsigned(operandB));
                overflow <= '0';

            when "0101" => -- OR
                temp := '0' & (unsigned(operandA) or unsigned(operandB));
                overflow <= '0';

            when "0110" => -- XOR
                temp := '0' & (unsigned(operandA) xor unsigned(operandB));
                overflow <= '0';

            when "0111" => -- NOT A
                temp := '0' & (not unsigned(operandA));
                overflow <= '0';

            when others =>
                temp := (others => '0');
                overflow <= '0';
        end case;

        result <= std_logic_vector(temp(3 downto 0)); -- Assign 4-bit result
        carry <= temp(4);                             -- Assign carry flag
        zero <= '1' when temp(3 downto 0) = "0000" else '0'; -- Zero flag
        negative <= temp(3);                          -- Negative flag from MSB
    end process;

    -- Output assignments
    leds_result <= result;
    led_zero <= zero;
    led_neg <= negative;
    led_carry <= carry;
    led_ovfl <= overflow;

    -- Debug state output
    with state select state_debug <=
        "00" when S_OP,
        "01" when S_A,
        "10" when S_B,
        "11" when S_RESULT;

end behavioral;
