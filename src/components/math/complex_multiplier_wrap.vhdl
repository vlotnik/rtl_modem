----------------------------------------------------------------------------------------------------------------------------------
-- Author : Vitaly Lotnik
-- Name : complex_multiplier_wrap
-- Created : 23/05/2021
-- v. 1.1.0
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library rtl_modem;
    use rtl_modem.pkg_rtl_modem_types.all;

----------------------------------------------------------------------------------------------------------------------------------
-- entity declaration
----------------------------------------------------------------------------------------------------------------------------------
entity complex_multiplier_wrap is
    generic(
          g_gpdw                        : integer := 10
        ; g_a_w                         : integer := 25
        ; g_b_w                         : integer := 18
        ; g_type                        : integer := 1
        ; g_conj_mult                   : boolean := false
        ; g_pipe_ce                     : boolean := false
    );
    port(
          iCLK                          : in std_logic
        ; iV                            : in std_logic
        ; iGP                           : in std_logic_vector(g_gpdw - 1 downto 0)
        ; iA_I                          : in signed(g_a_w - 1 downto 0)
        ; iA_Q                          : in signed(g_a_w - 1 downto 0)
        ; iB_I                          : in signed(g_b_w - 1 downto 0)
        ; iB_Q                          : in signed(g_b_w - 1 downto 0)
        ; OV                            : out std_logic
        ; oGP                           : out std_logic_vector(g_gpdw - 1 downto 0)
        ; oC_I                          : out signed(g_a_w + g_b_w downto 0)
        ; oC_Q                          : out signed(g_a_w + g_b_w downto 0)
    );
end;

----------------------------------------------------------------------------------------------------------------------------------
-- architecture declaration
----------------------------------------------------------------------------------------------------------------------------------
architecture behavioral of complex_multiplier_wrap is
----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    signal ib_v : std_logic;
    signal ib_gp : std_logic_vector(g_gpdw - 1 downto 0);
    signal ib_a : t_iq(i(g_a_w - 1 downto 0), q(g_a_w - 1 downto 0));
    signal ib_b : t_iq(i(g_b_w - 1 downto 0), q(g_b_w - 1 downto 0));
    signal ob_v : std_logic;
    signal ob_gp : std_logic_vector(g_gpdw - 1 downto 0);
    signal ob_c : t_iq(i(g_a_w + g_b_w downto 0), q(g_a_w + g_b_w downto 0));

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_v                                <= iV;
    ib_gp                               <= iGP;
    ib_a.i                              <= iA_I;
    ib_a.q                              <= iA_Q;
    ib_b.i                              <= iB_I;
    ib_b.q                              <= iB_Q;

----------------------------------------------------------------------------------------------------------------------------------
-- connect complex multiplier
----------------------------------------------------------------------------------------------------------------------------------
    u_dsp_cmult : entity rtl_modem.complex_multiplier
    generic map(
          g_gpdw                        => g_gpdw
        , g_a_w                         => g_a_w
        , g_b_w                         => g_b_w
        , g_type                        => g_type
        , g_conj_mult                   => g_conj_mult
        , g_pipe_ce                     => g_pipe_ce
    )
    port map(
          iCLK                          => iCLK
        , iV                            => ib_v
        , iGP                           => ib_gp
        , iA                            => ib_a
        , iB                            => ib_b
        , oV                            => ob_v
        , oGP                           => ob_gp
        , oC                            => ob_c
    );

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    oV                                  <= ob_v;
    oGP                                 <= ob_gp;
    oC_I                                <= ob_c.i;
    oC_Q                                <= ob_c.q;

----------------------------------------------------------------------------------------------------------------------------------
end;