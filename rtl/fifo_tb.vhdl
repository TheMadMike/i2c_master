library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity fifo_tb is
end fifo_tb;

architecture Behavioral of fifo_tb is
    component fifo
    generic (
        FIFO_WIDTH : natural;
        FIFO_DEPTH : natural
    );
    port (
        clk : in std_logic;
        
        we : in std_logic;
        wr_data : in std_logic_vector(FIFO_WIDTH-1 downto 0);
        full : out std_logic;

        re : in std_logic;
        rd_data : out std_logic_vector(FIFO_WIDTH-1 downto 0);
        empty : out std_logic   
    );
    end component;

    -- inputs
    signal clk, we, re : std_logic := '0';
    signal wr_data : std_logic_vector(7 downto 0) := (others => '0');
    -- outputs
    signal full, empty : std_logic;
    signal rd_data : std_logic_vector(7 downto 0);

    constant CLK_PERIOD : time := 10 ns;

    type data_array is array (0 to 15) of std_logic_vector(7 downto 0);
    signal data : data_array := (x"01", x"02", x"03", x"04", others => x"FF");
begin
    uut: entity work.fifo generic map (8, 16) 
    port map (
        clk, we, wr_data, full, re, rd_data, empty
    );

    clk <= not clk after CLK_PERIOD / 2;

    process
    begin
        we <= '1';
        for i in 0 to 15 loop
            wr_data <= data(i);
            wait for CLK_PERIOD;
        end loop;
        we <= '0';

        assert full = '1' report "FIFO not full when should be";

        re <= '1';
        for i in 0 to 15 loop
            wait for CLK_PERIOD;
            assert rd_data = data(i) report "Invalid data[" & integer'image(i) & "]";
        end loop;
        re <= '0';

        assert empty = '1' report "FIFO not empty when should be";
        
        wait;
    end process;

end Behavioral;
