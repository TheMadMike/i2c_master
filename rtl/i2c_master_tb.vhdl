library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_master_tb is
end entity;

architecture tb of i2c_master_tb is
    component i2c_master
    port (
        clk         : in std_logic;                     -- controller clock frequency (2 * f_transmittion)
        ce          : in std_logic;                     -- clock enable 
        reset       : in std_logic;
        go          : in std_logic;                     -- begin the transmittion
        busy        : out std_logic;                    -- '0' if the controller is in the idle state

        -- control fifo
        ctl_in    : in std_logic_vector(10 downto 0); -- control word in
        ctl_push    : in std_logic;                     -- control fifo push
        ctl_full    : out std_logic;                    -- control fifo full
        
        -- read fifo 
        rd_out     : out std_logic_vector(7 downto 0); -- read fifo word out
        rd_empty    : out std_logic;                    -- read fifo empty
        rd_pop      : in std_logic;                     -- read fifo pop

        -- i2c external
        sda         : inout std_logic;
        scl         : inout std_logic
    );
    end component;

    -- inputs
    signal clk, ce, reset, go, ctl_push, rd_pop : std_logic := '0';
    signal ctl_in : std_logic_vector(10 downto 0);
    
    -- outputs
    signal busy, ctl_full, rd_empty : std_logic;
    signal rd_out : std_logic_vector(7 downto 0);

    -- i2c bus
    signal sda, scl : std_logic;

    constant CLK_PERIOD : time := 50 ns;
    
    type ctlw_array_type is array (natural range<>) of std_logic_vector(10 downto 0);

    constant ROM : ctlw_array_type(0 to 3) := (
        b"010_1111_1111",
        b"011_1111_1111",
        b"001_1111_1111",
        b"100_0000_0001"
    );

    procedure i2c_sack(signal i2c_sda: inout std_logic; constant period : time) is
    begin
        i2c_sda <= '0';
        wait for period;
        i2c_sda <= 'H';
        report "[I2C SLAVE] ACK";
    end procedure;

    procedure i2c_slave_transmit(signal i2c_sda: inout std_logic; 
                                 constant byte : std_logic_vector(7 downto 0);
                                 constant period : time) is
    begin
        wait for period / 2;
        for i in 7 downto 0 loop
            i2c_sda <= byte(i);
            wait for period;
        end loop;
        -- release the bus
        i2c_sda <= 'H';

        report "[I2C SLAVE] SENDING: 0x" & to_hstring(byte);
    end procedure;

begin

    uut: entity work.i2c_master port map (
        clk, ce, reset, go, busy, ctl_in, 
        ctl_push, ctl_full, rd_out, rd_empty, 
        rd_pop, sda, scl
    );

    clk <= not clk after CLK_PERIOD / 2;

    process
    begin
        sda <= 'H';
        scl <= 'H';
        ce <= '1';
        ctl_push <= '1';
        for i in 0 to 3 loop
            ctl_in <= ROM(i);
            wait for CLK_PERIOD;
        end loop;
        ctl_push <= '0';
        wait for CLK_PERIOD;
        go <= '1';
        wait for CLK_PERIOD;
        go <= '0';

        wait for CLK_PERIOD * 10;
        i2c_sack(sda, CLK_PERIOD);
        
        wait for CLK_PERIOD * 9;
        i2c_sack(sda, CLK_PERIOD);
        
        wait for CLK_PERIOD * 12;
        i2c_sack(sda, CLK_PERIOD);
       
        i2c_slave_transmit(sda, x"AA", CLK_PERIOD);

        wait;
    end process;

end;
