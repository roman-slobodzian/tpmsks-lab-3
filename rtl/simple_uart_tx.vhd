library ieee;
use ieee.std_logic_1164.all;

-- 50 MHz, 8N1, LSB first. One synchronized active-low press sends 'H'.
entity simple_uart_tx is
    generic (BAUD_DIV : positive := 5208);
    port (
        clk     : in  std_logic;
        reset   : in  std_logic; -- synchronous, active high
        key     : in  std_logic_vector(0 downto 0);
        uart_tx : out std_logic;
        ledr    : out std_logic_vector(0 downto 0)
    );
end entity;

architecture rtl of simple_uart_tx is
    type state_t is (idle, start_bit, data_bits, stop_bit);
    signal state       : state_t := idle;
    signal counter     : natural range 0 to BAUD_DIV - 1 := 0;
    signal bit_index   : natural range 0 to 7 := 0;
    signal key_meta    : std_logic := '1';
    signal key_sync    : std_logic := '1';
    signal key_prev    : std_logic := '1';
    constant DATA_BYTE : std_logic_vector(7 downto 0) := x"48";
begin
    uart_tx <= '0' when state = start_bit else
               DATA_BYTE(bit_index) when state = data_bits else '1';
    ledr(0) <= '0' when state = idle else '1';

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state     <= idle;
                counter   <= 0;
                bit_index <= 0;
                key_meta  <= '1';
                key_sync  <= '1';
                key_prev  <= '1';
            else
                key_meta <= key(0);
                key_sync <= key_meta;
                key_prev <= key_sync;

                if state = idle then
                    counter <= 0;
                    if key_prev = '1' and key_sync = '0' then
                        state <= start_bit;
                        bit_index <= 0;
                    end if;
                elsif counter = BAUD_DIV - 1 then
                    -- Clock enable at the bit boundary; no derived clock.
                    counter <= 0;
                    case state is
                        when start_bit => state <= data_bits;
                        when data_bits =>
                            if bit_index = 7 then
                                state <= stop_bit;
                            else
                                bit_index <= bit_index + 1;
                            end if;
                        when stop_bit => state <= idle;
                        when idle => null;
                    end case;
                else
                    counter <= counter + 1;
                end if;
                -- Presses seen while busy are consumed, never queued.
            end if;
        end if;
    end process;
end architecture;
