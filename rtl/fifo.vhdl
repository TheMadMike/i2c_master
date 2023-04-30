library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fifo is
    generic 
    (
        FIFO_WIDTH : natural := 8;
        FIFO_DEPTH : natural := 16
    );
    port 
    (
        clk : in std_logic;
        
        we : in std_logic;
        wr_data : in std_logic_vector(FIFO_WIDTH-1 downto 0);
        full : out std_logic;

        re : in std_logic;
        rd_data : out std_logic_vector(FIFO_WIDTH-1 downto 0);
        empty : out std_logic   
    );
end fifo;

architecture Behavioral of fifo is
    type fifo_data_type is array (0 to FIFO_DEPTH-1) of std_logic_vector(FIFO_WIDTH-1 downto 0);
    signal data : fifo_data_type := (others => (others => '0'));

    signal write_index : integer range 0 to FIFO_DEPTH-1 := 0;
    signal read_index : integer range 0 to FIFO_DEPTH-1 := 0;
    signal count : integer range 0 to FIFO_DEPTH := 0;
    
    signal full_internal : std_logic := '0';
    signal empty_internal : std_logic := '1';

begin
    full_internal <= '1' when count = FIFO_DEPTH else '0';
    empty_internal <= '1' when count = 0 else '0';

    full <= full_internal;
    empty <= empty_internal;

    p_count: process (clk, we, re, count)
    begin
        if rising_edge(clk) then
            if we = '1' and re = '0' and full_internal = '0' then
                count <= count + 1;
            elsif we = '0' and re = '1' and empty_internal = '0' then
                count <= count - 1;
            end if;
        end if;
    end process;

    p_push: process (clk, we, wr_data, full_internal, write_index, data)
    begin
        if rising_edge(clk) and we = '1' then
            if full_internal = '0' then
                data(write_index) <= wr_data;
            -- synthesis translate_off
            else 
                report "FIFO: attempt to write when full!";
            -- synthesis translate_on
            end if;

            if write_index = FIFO_DEPTH-1 then
                write_index <= 0;
            else
                write_index <= write_index + 1;
            end if;
        end if;
    end process;

    p_pop: process (clk, re, empty_internal, read_index, data)
    begin
        if rising_edge(clk) and re = '1' then
            if empty_internal = '0' then
                rd_data <= data(read_index);
            -- synthesis translate_off
            else 
                report "FIFO: attempt to read when empty!";
            -- synthesis translate_on
            end if;

            if read_index = FIFO_DEPTH-1 then
                read_index <= 0;
            else
                read_index <= read_index + 1;
            end if;
        end if;
    end process;

end Behavioral;
