library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity i2c_master is
    port 
    (
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
end entity;

architecture rtl of i2c_master is
    -- FSM
    type state_type is (
        IDLE, 
        START, 
        READING, 
        WRITING, 
        ACK, 
        ACK_AWAIT, 
        S_REPEAT, 
        STOP
    );

    signal state, next_state : state_type := IDLE;
    -- end FSM
    
    -- ctl fifo internal signals
    signal ctl_pop      : std_logic := '0';
    signal ctl_out      : std_logic_vector(10 downto 0);
    signal ctl_empty    : std_logic;

    -- rd fifo internal signals
    signal rd_push      : std_logic := '0';
    signal rd_in        : std_logic_vector(7 downto 0);
    signal rd_full      : std_logic;

    -- control word constants
    constant RW_POS     : natural := 10;
    constant CTL1_POS   : natural := 9;
    constant CTL0_POS   : natural := 8;
    constant DATA_UB    : natural := 7;
    constant DATA_LB    : natural := 0;
    constant READ_VAL   : std_logic := '1';
    constant WRITE_VAL  : std_logic := '0';

    -- shift register's signals
    signal rx_reg       : std_logic_vector(7 downto 0)  := (others => '0');
    signal tx_reg       : std_logic_vector(7 downto 0)  := (others => '0');
    signal bit_count    : unsigned(3 downto 0)          := (others => '0');
    signal rd_count     : unsigned(7 downto 0)          := (others => '0');
    signal rd_bit_count : unsigned(3 downto 0)          := (others => '0');

    -- internal buffers 
    signal ctl_buffer   : std_logic_vector(10 downto 0) := (others => '0');

    -- start/stop delay
    signal delay         : std_logic         := '0';

    -- slave ack        
    signal sack          : std_logic         := '0';
begin
    -- FIFOs
    ctl_fifo: entity work.fifo 
        generic map (11, 16) 
        port map (clk, ctl_push, ctl_in, ctl_full, ctl_pop, ctl_out, ctl_empty);

    rd_fifo: entity work.fifo
        generic map (8, 16)
        port map (clk, rd_push, rd_in, rd_full, rd_pop, rd_out, rd_empty);

    rd_in <= rx_reg;

    -- busy
    busy <= '0' when state = IDLE else '1';


    -- FSM state register
    process (clk, ce, reset, state, next_state, ctl_buffer)
    begin
        if rising_edge(clk) and ce = '1' then
            if reset = '1' then
                state <= IDLE;
            else
                state <= next_state;
            end if;
        end if;
    end process;

    -- FSM state transition
    process (all)
    begin   
        next_state <= state;
        case state is
            when IDLE =>
                if go = '1' and ctl_empty = '0' then
                    next_state <= START;
                end if;

            when START =>
                if ctl_out(RW_POS) = READ_VAL and delay = '1' then
                    next_state <= READING;
                elsif delay = '1' then
                    next_state <= WRITING;
                end if;

            when READING =>
                if rd_count = unsigned( ctl_out(DATA_UB downto DATA_LB) ) then
                    next_state <= STOP;
                elsif rd_bit_count = b"1000" then
                    next_state <= ACK;
                end if;

            when ACK =>
                case ctl_buffer(CTL1_POS downto CTL0_POS) is
                    when "00" =>
                        next_state <= STOP;
                    when "01" =>
                        next_state <= READING;
                    when "10" =>
                        next_state <= WRITING;
                    when "11" =>
                        next_state <= S_REPEAT;
                    when others =>
                        next_state <= STOP;
                end case;

            when WRITING =>
                if bit_count = "0111" then
                    next_state <= ACK_AWAIT;
                end if;

            when ACK_AWAIT =>
                if sack = '1' then
                    case ctl_buffer(CTL1_POS downto CTL0_POS) is
                        when "00" =>
                            next_state <= STOP;
                        when "01" =>
                            next_state <= READING;
                        when "10" =>
                            next_state <= WRITING;
                        when "11" =>
                            next_state <= S_REPEAT;
                        when others =>
                            next_state <= STOP;
                    end case;
                end if;
            when S_REPEAT =>
                next_state <= START;

            when STOP =>
                next_state <= IDLE;
        end case;
    end process;

    -- slave ack
    process(clk, ce, sack, state, sda)
    begin
        if rising_edge(clk) and ce = '1' then
            if state = ACK_AWAIT and sda = '0' then
                sack <= '1';
            else
                sack <= '0';
            end if;
        end if;
    end process;

    -- delay
    process(clk, ce, delay, state)
    begin
        if rising_edge(clk) and ce = '1' then
            if state = START or state = STOP then
                delay <= not delay;
            else
                delay <= '0';
            end if;
        end if;
    end process;

    -- ctl pop
    ctl_pop <= '1' when ( state = ACK or (state = ACK_AWAIT and sack = '1') ) and ctl_empty = '0' else '0';
    
    -- rd push
    rd_push <= '1' when state = ACK else '0';

    -- scl
    scl <= not clk when (state = READING or state = WRITING or state = ACK or state = ACK_AWAIT) else 
           '0' when (state = START and delay = '1') 
           else 'Z';
    
    with state select
    sda <= '0'          when START,
           '0'          when STOP,
           '0'          when ACK,
           '0'          when ACK_AWAIT,
            tx_reg(7)   when WRITING,
            'Z'         when others;

    -- tx_reg
    process (clk, ce, state, ctl_out, bit_count)
    begin
        if rising_edge(clk) and ce = '1' then
            if state = WRITING then
                tx_reg <= tx_reg(6 downto 0) & '0';
                bit_count <= bit_count + 1;

            elsif state = START or state = ACK_AWAIT or state = ACK then
                tx_reg <= ctl_out(DATA_UB downto DATA_LB);
                bit_count <= (others => '0');
            end if;
        end if;
    end process;

    -- rx_reg
    process (clk, ce, state, rx_reg, ctl_out, sda, rd_bit_count, rd_count)
    begin
        if rising_edge(clk) and ce = '1' then
            if state = READING then
                rx_reg <= sda & rx_reg(7 downto 1); 
                rd_bit_count <= rd_bit_count + 1;
                if rd_bit_count = b"1000" then
                    rd_count <= rd_count + 1;
                end if;
            else
                rd_bit_count <= (others => '0');
            end if;
        end if;
    end process;

    -- ctl buffer
    process (clk, ce, state, ctl_out)
    begin
        if rising_edge(clk) and ce = '1' then
            if state = WRITING or state = READING then
                ctl_buffer <= ctl_out;
            end if;
        end if;
    end process;

end architecture;
