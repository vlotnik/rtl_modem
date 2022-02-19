----------------------------------------------------------------------------------------------------------------------------------
-- author : vitaly lotnik
-- name : sin_cos_table
-- created : 23/05/2019
-- v. 2.1.1

----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, input:
----------------------------------------------------------------------------------------------------------------------------------
-- g_iraxi_dw                           iDATA
--      g_phase_dw                          phase                               [g_phase_dw - 1 : 0]
--      g_gp_dw                             general purpose data                [g_gp_dw + g_phase_dw - 1 : g_phase_dw]
--          g_gp_dw + g_phase_dw

----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, output:
----------------------------------------------------------------------------------------------------------------------------------
-- g_oraxi_dw                           oDATA
--      g_sincos_dw                         sinus                               [g_sincos_dw - 1 : 0]
--      g_sincos_dw                         cosine                              [g_sincos_dw*2 - 1 : g_sincos_dw]
--      g_gp_dw                             general purpose data                [g_gp_dw + g_sincos_dw*2 - 1 : g_sincos_dw*2]
--          g_gp_dw + g_sincos_dw*2
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

----------------------------------------------------------------------------------------------------------------------------------
--package declaration
----------------------------------------------------------------------------------------------------------------------------------
package pkg_sin_cos_table is
    constant c_total_latency : integer := 3;
end;

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.math_real.all;

library rtl_modem;

----------------------------------------------------------------------------------------------------------------------------------
-- entity declaration
----------------------------------------------------------------------------------------------------------------------------------
entity sin_cos_table is
    generic(
          g_gp_dw                       : integer := 10
        ; g_full_table                  : boolean := false
        ; g_phase_dw                    : integer := 12
        ; g_sincos_dw                   : integer := 16
        ; g_pipe_ce                     : boolean := false
        ; g_iraxi_dw                    : integer := 22
        ; g_oraxi_dw                    : integer := 42
    );
    port(
          iCLK                          : in std_logic
        ; iVALID                        : in std_logic
        ; iDATA                         : in std_logic_vector(g_iraxi_dw - 1 downto 0)
        ; oVALID                        : out std_logic
        ; oDATA                         : out std_logic_vector(g_oraxi_dw - 1 downto 0)
    );
end;

----------------------------------------------------------------------------------------------------------------------------------
-- architecture declaration
----------------------------------------------------------------------------------------------------------------------------------
architecture behavioral of sin_cos_table is
----------------------------------------------------------------------------------------------------------------------------------
-- functions declaration
----------------------------------------------------------------------------------------------------------------------------------
    function f_get_table_width return integer is
    begin
        if g_full_table then
            return g_phase_dw;
        else
            return g_phase_dw - 2;
        end if;
    end function;

----------------------------------------------------------------------------------------------------------------------------------
-- constants declaration
----------------------------------------------------------------------------------------------------------------------------------
    constant c_latency : integer := rtl_modem.pkg_sin_cos_table.c_total_latency;
    constant c_table_width : integer := f_get_table_width;

----------------------------------------------------------------------------------------------------------------------------------
-- types declaration
----------------------------------------------------------------------------------------------------------------------------------
    type t_pipe_gp is array (integer range <>) of std_logic_vector(g_gp_dw - 1 downto 0);

----------------------------------------------------------------------------------------------------------------------------------
-- ram initialization
----------------------------------------------------------------------------------------------------------------------------------
    type t_sincos_table is array (0 to 2 ** c_table_width - 1) of signed(g_sincos_dw - 1 downto 0);

    function f_get_sincos_table (sin : in boolean) return t_sincos_table is
        variable v_sincos_table : t_sincos_table;
        variable v_phase : real := 0.0;
        variable v_step : real := 1.0 / real(2 ** (g_phase_dw - 2));
        variable v_max_value : real := real(2 ** (g_sincos_dw - 1) - 1);
        variable v_sincos_real : real;
        variable v_sincos_int : integer;
        constant v_pi : real := ieee.math_real.math_pi;
    begin
        for a in 0 to 2 ** c_table_width - 1 loop
            if sin then
                -- fill sin table
                v_sincos_real := round(v_max_value * ieee.math_real.sin(v_phase * ieee.math_real.math_pi * 0.5));
            else
                -- fill cos table
                v_sincos_real := round(v_max_value * ieee.math_real.cos(v_phase * ieee.math_real.math_pi * 0.5));
            end if;
            v_sincos_int := integer(v_sincos_real);
            v_sincos_table(a) := to_signed(v_sincos_int, g_sincos_dw);
            v_phase := v_phase + v_step;
        end loop;

        return v_sincos_table;
    end;

    constant c_sintable : t_sincos_table := f_get_sincos_table(sin => true);
    constant c_costable : t_sincos_table := f_get_sincos_table(sin => false);

----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    -- input buffers
    signal ib_v : std_logic := '0';
    signal ib_phase : unsigned(g_phase_dw - 1 downto 0) := (others => '0');
    signal ib_gp :std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    signal pipe_v : std_logic_vector(0 to c_latency) := (others => '0');
    signal pipe_gp : t_pipe_gp(0 to c_latency) := (others => (others => '0'));

    signal
          quad                                              -- quadrant
        , quad_d                                            -- quadrant, delayed for 1 clk
            : unsigned(1 downto 0) := (others => '0');
    signal
          sinadr                                            -- address to get sin
        , cosadr                                            -- address to get cos
            : unsigned(c_table_width - 1 downto 0) := (others => '0');

    signal
          int_sin                                           -- sin value got from memory
        , int_cos                                           -- cos value got from memory
        , int_sin_d                                         -- sin value, delayd for 1 clk
        , int_cos_d                                         -- cos value, delayed for 1 clk
            : signed(g_sincos_dw - 1 downto 0) := (others => '0');

    -- output buffers
    signal ob_v : std_logic := '0';
    signal ob_gp :std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');
    signal ob_sin : signed(g_sincos_dw - 1 downto 0) := (others => '0');
    signal ob_cos : signed(g_sincos_dw - 1 downto 0) := (others => '0');

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_v                                <= iVALID;
    ib_phase                            <= unsigned(iDATA(g_phase_dw - 1 downto 0));
    ib_gp                               <= iDATA(g_gp_dw + g_phase_dw - 1 downto g_phase_dw);

    gen_solid_v : if g_pipe_ce = false generate
        pipe_v                          <= (others => ib_v);
        pipe_gp                         <= ib_gp & pipe_gp(0 to pipe_gp'high - 1) when rising_edge(iCLK) and ib_v = '1';
    end generate;

    gen_pipe_v : if g_pipe_ce = true generate
        pipe_v(0)                       <= ib_v;
        pipe_v(1 to pipe_v'high)        <= pipe_v(0 to pipe_v'high - 1)         when rising_edge(iCLK);
        pipe_gp                         <= ib_gp & pipe_gp(0 to pipe_gp'high - 1) when rising_edge(iCLK);
    end generate;

    ob_gp                               <= pipe_gp(c_latency - 1);

    sinadr                              <= ib_phase(c_table_width - 1 downto 0);
    cosadr                              <= ib_phase(c_table_width - 1 downto 0);

----------------------------------------------------------------------------------------------------------------------------------
-- process, main
----------------------------------------------------------------------------------------------------------------------------------
    p_main : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if pipe_v(0) = '1' then
                -- get quadrant
                quad <= ib_phase(g_phase_dw - 1 downto g_phase_dw - 2);
                -- get cosine/sine from quarter table
                int_sin <= c_sintable(to_integer(sinadr));
                int_cos <= c_costable(to_integer(cosadr));
            end if;

            if pipe_v(1) = '1' then
                quad_d <= quad;
                int_sin_d <= int_sin;
                int_cos_d <= int_cos;
            end if;

            if pipe_v(2) = '1' then
                if g_full_table then
                    -- full table
                    ob_sin <= int_sin_d;
                    ob_cos <= int_cos_d;
                else
                    -- quarter
                    case quad_d is
                        when "00" =>                        -- [0 ... pi/2)
                            ob_sin <= int_sin_d;
                            ob_cos <= int_cos_d;
                        when "01" =>                        -- [pi/2 ... pi)
                            ob_sin <= int_cos_d;
                            ob_cos <= not int_sin_d + 1;
                        when "10" =>                        -- [pi ... 3*pi/2)
                            ob_sin <= not int_sin_d + 1;
                            ob_cos <= not int_cos_d + 1;
                        when others =>                      -- [3*pi/2 ... 2*pi)
                            ob_sin <= not int_cos_d + 1;
                            ob_cos <= int_sin_d;
                    end case; -- mux due to quadrant
                end if;
            end if;
        end if;
    end process;

    ob_v                                <= pipe_v(c_latency);

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    oVALID                              <= ob_v;
    oDATA                               <=
          ob_gp
        & std_logic_vector(ob_cos)
        & std_logic_vector(ob_sin);

----------------------------------------------------------------------------------------------------------------------------------
end;