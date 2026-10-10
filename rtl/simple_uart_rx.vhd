library ieee;
use ieee.std_logic_1164.all;

-- 50 MHz, 8N1. The LEDs hold the last byte with a valid start/stop bit.
entity simple_uart_rx is
    generic (BAUD_DIV : positive := 5208);
    port (
        clk     : in  std_logic;
        reset   : in  std_logic; -- synchronous, active high
        uart_rx : in  std_logic;
        ledr    : out std_logic_vector(7 downto 0)
    );
end entity;

architecture rtl of simple_uart_rx is
    type state_t is (idle, start_bit, data_bits, stop_bit, wait_high);
    signal state         : state_t := idle;
    signal counter       : natural range 0 to BAUD_DIV - 1 := 0;
    signal bit_index     : natural range 0 to 7 := 0;
    signal rx_meta       : std_logic := '1';
    signal rx_sync       : std_logic := '1';
    signal rx_prev       : std_logic := '1';
    signal rx_data       : std_logic_vector(7 downto 0) := (others => '0');
    signal received_byte : std_logic_vector(7 downto 0) := (others => '0');
begin
    assert BAUD_DIV >= 4
        report "RX requires BAUD_DIV >= 4 for midpoint sampling"
        severity failure;
    ledr <= received_byte;

    process (clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                state         <= idle;
                counter       <= 0;
                bit_index     <= 0;
                rx_meta       <= '1';
                rx_sync       <= '1';
                rx_prev       <= '1';
                rx_data       <= (others => '0');
                received_byte <= (others => '0');
            else
                -- Only rx_sync, the second stage, feeds the receiver FSM.
                rx_meta <= uart_rx;
                rx_sync <= rx_meta;
                rx_prev <= rx_sync;

                case state is
                    when idle =>
                        counter <= 0;
                        if rx_prev = '1' and rx_sync = '0' then
                            counter <= BAUD_DIV / 2 - 1;
                            state <= start_bit;
                        end if;
                    when wait_high =>
                        -- A sustained low line after a framing error is not
                        -- another start bit. Re-arm only after idle high.
                        if rx_sync = '1' then
                            state <= idle;
                        end if;
                    when start_bit | data_bits | stop_bit =>
                        if counter = 0 then
                            counter <= BAUD_DIV - 1;
                            case state is
                                when start_bit =>
                                    if rx_sync = '0' then
                                        bit_index <= 0;
                                        state <= data_bits;
                                    else
                                        state <= idle; -- false start
                                    end if;
                                when data_bits =>
                                    rx_data(bit_index) <= rx_sync;
                                    if bit_index = 7 then
                                        state <= stop_bit;
                                    else
                                        bit_index <= bit_index + 1;
                                    end if;
                                when stop_bit =>
                                    if rx_sync = '1' then
                                        received_byte <= rx_data;
                                        state <= idle;
                                    else
                                        state <= wait_high; -- bad stop
                                    end if;
                                when others => null;
                            end case;
                        else
                            counter <= counter - 1;
                        end if;
                end case;
            end if;
        end if;
    end process;
end architecture;
