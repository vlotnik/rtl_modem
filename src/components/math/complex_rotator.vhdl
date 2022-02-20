----------------------------------------------------------------------------------------------------------------------------------
-- author : vitaly lotnik
-- name : complex_rotator
-- created : 12/02/2022
-- v. 0.0.0

----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, input:
-- g_iraxi_dw                           idata
--      g_sample_dw                         sample, re part                     [g_sample_dw - 1 : 0]
--      g_sample_dw                         sample, im part                     [g_sample_dw*2 - 1 : g_sample_dw]
--      g_phase_dw                          phase                               [g_phase_dw + g_sample_dw*2 - 1 : g_sample_dw*2]
--      g_gp_dw                             general purpose data                [g_gp_dw + g_phase_dw + g_sample_dw*2 - 1 : g_phase_dw + g_sample_dw*2]
--          g_gp_dw + g_phase_dw + g_sample_dw*2
----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, output:
-- g_oraxi_dw                           odata
--      g_sample_dw                         sample, re part                     [g_sample_dw - 1 : 0]
--      g_sample_dw                         sample, im part                     [g_sample_dw*2 - 1 : g_sample_dw]
--      g_gp_dw                             general purpose data                [g_gp_dw + g_sample_dw*2 - 1 : g_sample_dw*2]
--          g_gp_dw + g_sample_dw*2
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

library rtl_modem;

----------------------------------------------------------------------------------------------------------------------------------
--package declaration
----------------------------------------------------------------------------------------------------------------------------------
package complex_rotator_pkg is
    constant c_total_latency : integer :=
          rtl_modem.pkg_sin_cos_table.c_total_latency                           -- sin/cos table
        + rtl_modem.pkg_complex_multiplier.c_total_latency                      -- complex multiplier
        + 1                                                                     -- rounding
    ;
end;

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library rtl_modem;
    -- use rtl_modem.pkg_rtl_modem.all;

----------------------------------------------------------------------------------------------------------------------------------
-- entity declaration
----------------------------------------------------------------------------------------------------------------------------------
entity complex_rotator is
    generic(
          g_gp_dw                       : integer := 10
        ; g_phase_dw                    : integer := 12
        ; g_sample_dw                   : integer := 16
        ; g_sincos_dw                   : integer := 16
        ; g_conj_mult                   : boolean := false
        ; g_pipe_ce                     : boolean := false
        ; g_iraxi_dw                    : integer := 10 + 12 + 16*2
        ; g_oraxi_dw                    : integer := 10 + 16*2
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
architecture behavioral of complex_rotator is
----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    -- input
    signal ib_valid : std_logic := '0';
    signal ib_data : std_logic_vector(g_iraxi_dw - 1 downto 0) := (others => '0');

    signal ib_re : std_logic_vector(g_sample_dw - 1 downto 0) := (others => '0');
    signal ib_im : std_logic_vector(g_sample_dw - 1 downto 0) := (others => '0');
    signal ib_phase : std_logic_vector(g_phase_dw - 1 downto 0) := (others => '0');
    signal ib_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    -- signals for sin/cos table
    constant c_sincos_gp_w : integer := g_gp_dw + g_sample_dw*2;
    constant c_sincos_iraxi_dw : integer := c_sincos_gp_w + g_phase_dw;
    constant c_sincos_oraxi_dw : integer := c_sincos_gp_w + g_sincos_dw*2;
    signal isincos_clk : std_logic := '0';
    signal isincos_valid : std_logic := '0';
    signal isincos_data : std_logic_vector(c_sincos_iraxi_dw - 1 downto 0) := (others => '0');
    signal osincos_valid : std_logic := '0';
    signal osincos_data : std_logic_vector(c_sincos_oraxi_dw - 1 downto 0) := (others => '0');
    signal osincos_gp : std_logic_vector(c_sincos_gp_w - 1 downto 0) := (others => '0');

    signal sincos_sin : std_logic_vector(g_sincos_dw - 1 downto 0) := (others => '0');
    signal sincos_cos : std_logic_vector(g_sincos_dw - 1 downto 0) := (others => '0');
    signal sincos_re : std_logic_vector(g_sample_dw - 1 downto 0) := (others => '0');
    signal sincos_im : std_logic_vector(g_sample_dw - 1 downto 0) := (others => '0');
    signal sincos_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    -- signals for complex multiplier
    constant c_cmult_c_dw : integer := g_sample_dw + g_sincos_dw + 1;
    constant c_cmult_iraxi_dw : integer := g_gp_dw + g_sample_dw*2 + g_sincos_dw*2;
    constant c_cmult_oraxi_dw : integer := g_gp_dw + c_cmult_c_dw*2;
    signal icmult_clk : std_logic := '0';
    signal icmult_valid : std_logic := '0';
    signal icmult_data : std_logic_vector(c_cmult_iraxi_dw - 1 downto 0) := (others => '0');
    signal ocmult_valid : std_logic := '0';
    signal ocmult_data : std_logic_vector(c_cmult_oraxi_dw - 1 downto 0) := (others => '0');

    signal cmult_re : std_logic_vector(c_cmult_c_dw - 1 downto 0) := (others => '0');
    signal cmult_im : std_logic_vector(c_cmult_c_dw - 1 downto 0) := (others => '0');
    signal cmult_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    -- signals for rounding
    signal rnd_valid : std_logic := '0';
    signal rnd_re : std_logic_vector(c_cmult_c_dw - 1 downto 0) := (others => '0');
    signal rnd_im : std_logic_vector(c_cmult_c_dw - 1 downto 0) := (others => '0');
    signal rnd_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    -- output
    signal ob_re : std_logic_vector(g_sample_dw - 1 downto 0) := (others => '0');
    signal ob_im : std_logic_vector(g_sample_dw - 1 downto 0) := (others => '0');
    signal ob_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    signal ob_valid : std_logic := '0';
    signal ob_data : std_logic_vector(g_oraxi_dw - 1 downto 0) := (others => '0');

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_valid                            <= iVALID;
    ib_data                             <= iDATA;

    ib_re                               <= ib_data(g_sample_dw - 1 downto 0);
    ib_im                               <= ib_data(g_sample_dw*2 - 1 downto g_sample_dw);
    ib_phase                            <= ib_data(g_sample_dw*2 + g_phase_dw - 1 downto g_sample_dw*2);
    ib_gp                               <= ib_data(g_sample_dw*2 + g_phase_dw + g_gp_dw - 1 downto g_sample_dw*2 + g_phase_dw);

----------------------------------------------------------------------------------------------------------------------------------
-- component, sin/cos table
----------------------------------------------------------------------------------------------------------------------------------
    u_sincos : entity rtl_modem.sin_cos_table
    generic map(
          g_gp_dw                       => c_sincos_gp_w
        , g_phase_dw                    => g_phase_dw
        , g_sincos_dw                   => g_sincos_dw
        , g_pipe_ce                     => g_pipe_ce
        , g_iraxi_dw                    => c_sincos_iraxi_dw
        , g_oraxi_dw                    => c_sincos_oraxi_dw
    )
    port map(
          iclk                          => isincos_clk
        , ivalid                        => isincos_valid
        , idata                         => isincos_data
        , ovalid                        => osincos_valid
        , odata                         => osincos_data
    );

    isincos_clk                         <= iCLK;
    isincos_valid                       <= ib_valid;
    isincos_data                        <=
        ib_gp & ib_im & ib_re &         -- gp
        ib_phase                        -- phase
    ;

    sincos_sin                          <= osincos_data(g_sincos_dw - 1 downto 0);
    sincos_cos                          <= osincos_data(g_sincos_dw*2 - 1 downto g_sincos_dw);
    osincos_gp                          <= osincos_data(c_sincos_gp_w + g_sincos_dw*2 - 1 downto g_sincos_dw*2);

    sincos_re                           <= osincos_gp(g_sample_dw - 1 downto 0);
    sincos_im                           <= osincos_gp(g_sample_dw*2 - 1 downto g_sample_dw);
    sincos_gp                           <= osincos_gp(g_gp_dw + g_sample_dw*2 - 1 downto g_sample_dw*2);

----------------------------------------------------------------------------------------------------------------------------------
-- component, complex multiplier
----------------------------------------------------------------------------------------------------------------------------------
    u_cmult : entity rtl_modem.complex_multiplier
    generic map(
          g_gp_dw                       => g_gp_dw
        , g_a_dw                        => g_sample_dw
        , g_b_dw                        => g_sincos_dw
        , g_conj_mult                   => g_conj_mult
        , g_pipe_ce                     => g_pipe_ce
        , g_iraxi_dw                    => c_cmult_iraxi_dw
        , g_oraxi_dw                    => c_cmult_oraxi_dw
    )
    port map(
          iclk                          => icmult_clk
        , ivalid                        => icmult_valid
        , idata                         => icmult_data
        , ovalid                        => ocmult_valid
        , odata                         => ocmult_data
    );

    icmult_clk                          <= iCLK;
    icmult_valid                        <= osincos_valid;
    icmult_data                         <=
          sincos_gp
        & sincos_sin
        & sincos_cos
        & sincos_im
        & sincos_re
    ;

    cmult_re                            <= ocmult_data(c_cmult_c_dw - 1 downto 0);
    cmult_im                            <= ocmult_data(c_cmult_c_dw*2 - 1 downto c_cmult_c_dw);
    cmult_gp                            <= ocmult_data(c_cmult_c_dw*2 + g_gp_dw - 1 downto c_cmult_c_dw*2);

----------------------------------------------------------------------------------------------------------------------------------
-- process, round
----------------------------------------------------------------------------------------------------------------------------------
    p_rnd : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if g_pipe_ce = true then
                rnd_gp <= cmult_gp;
                rnd_valid <= ocmult_valid;
                -- rnd_re <= f_round(cmult_re, g_sincos_dw - 1);
                -- rnd_im <= f_round(cmult_im, g_sincos_dw - 1);
                rnd_re <= cmult_re;
                rnd_im <= cmult_im;
            else
                if ocmult_valid = '1' then
                    rnd_gp <= cmult_gp;
                    -- rnd_re <= f_round(cmult_re, g_sincos_dw - 1);
                    -- rnd_im <= f_round(cmult_im, g_sincos_dw - 1);
                    rnd_re <= cmult_re;
                    rnd_im <= cmult_im;
                end if;
            end if;
        end if;
    end process;

----------------------------------------------------------------------------------------------------------------------------------
    ob_re                               <= rnd_re(g_sample_dw + g_sincos_dw - 2 downto g_sincos_dw - 1);
    ob_im                               <= rnd_im(g_sample_dw + g_sincos_dw - 2 downto g_sincos_dw - 1);
    ob_gp                               <= rnd_gp;

    ob_valid                            <=
        rnd_valid when g_pipe_ce = true else
        ocmult_valid;
    ob_data                             <=
        ob_gp &
        ob_im &
        ob_re
    ;

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    oVALID                              <= ob_valid;
    oDATA                               <= ob_data;

----------------------------------------------------------------------------------------------------------------------------------
end;