----------------------------------------------------------------------------------------------------------------------------------
-- author : vitaly lotnik
-- name : complex_multiplier
-- created : 23/05/2021
-- v. 2.1.0

-- g_conj_mult = false : C_re + C_im = (A_re * B_re - A_im * B_im) + j (A_im * B_re + A_re * B_im)
-- g_conj_mult = true  : C_re + C_im = (A_re * B_re + A_im * B_im) + j (A_im * B_re - A_re * B_im)

----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, input:
----------------------------------------------------------------------------------------------------------------------------------
-- g_iraxi_dw                           iDATA
--      g_a_dw                              A_re                                [g_a_dw - 1 : 0]
--      g_a_dw                              A_im                                [g_a_dw*2 - 1 : g_a_dw]
--      g_b_dw                              B_re                                [g_b_dw + g_a_dw*2 - 1 : g_a_dw*2]
--      g_b_dw                              B_im                                [g_b_dw*2 + g_a_dw*2 - 1 : g_b_dw + g_a_dw*2]
--      g_gp_dw                             general purpose data                [g_gp_dw + g_a_dw*2 + g_b_dw*2 - 1 : g_b_dw*2 + g_a_dw*2]
--          g_gp_dw + g_a_dw*2 + g_b_dw*2
----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, output:
----------------------------------------------------------------------------------------------------------------------------------
-- g_oraxi_dw                           oDATA
--      g_a_dw + g_b_dw + 1                 C_re                                [g_a_dw + g_b_dw + 1 - 1 : 0]
--      g_a_dw + g_b_dw + 1                 C_im                                [(g_a_dw + g_b_dw + 1)*2 - 1 : g_a_dw + g_b_dw + 1]
--      g_gp_dw                             general purpose data                [g_gp_dw + (g_a_dw + g_b_dw + 1)*2 - 1 : (g_a_dw + g_b_dw + 1)*2]
--          g_gp_dw + (g_a_dw + g_b_dw + 1)*2
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

----------------------------------------------------------------------------------------------------------------------------------
--package declaration
----------------------------------------------------------------------------------------------------------------------------------
package pkg_complex_multiplier is
    constant c_total_latency : integer := 4;
end;

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
entity complex_multiplier is
    generic(
          g_gp_dw                       : integer := 10
        ; g_a_dw                        : integer := 25
        ; g_b_dw                        : integer := 18
        ; g_type                        : integer := 0
        ; g_conj_mult                   : boolean := false
        ; g_pipe_ce                     : boolean := false
        ; g_iraxi_dw                    : integer := 10 + 25*2 + 18*2
        ; g_oraxi_dw                    : integer := 10 + (25 + 18 + 1)*2
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
architecture behavioral of complex_multiplier is
----------------------------------------------------------------------------------------------------------------------------------
-- constants declaration
----------------------------------------------------------------------------------------------------------------------------------
    constant lsb_i_are : integer := 0;
    constant msb_i_are : integer := g_a_dw - 1;
    constant lsb_i_aim : integer := g_a_dw;
    constant msb_i_aim : integer := g_a_dw*2 - 1;
    constant lsb_i_bre : integer := g_a_dw*2;
    constant msb_i_bre : integer := g_a_dw*2 + g_b_dw - 1;
    constant lsb_i_bim : integer := g_a_dw*2 + g_b_dw;
    constant msb_i_bim : integer := g_a_dw*2 + g_b_dw*2 - 1;
    constant lsb_i_gp  : integer := g_a_dw*2 + g_b_dw*2;
    constant msb_i_gp  : integer := g_a_dw*2 + g_b_dw*2 + g_gp_dw - 1;

    constant c_latency : integer := rtl_modem.pkg_complex_multiplier.c_total_latency;
    constant c_c_w : integer := g_a_dw + g_b_dw + 1;

----------------------------------------------------------------------------------------------------------------------------------
-- types declaration
----------------------------------------------------------------------------------------------------------------------------------
    type t_pipe_gp is array (integer range <>) of std_logic_vector(g_gp_dw - 1 downto 0);

----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    -- input buffers
    signal ib_v : std_logic := '0';
    signal ib_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');
    signal ib_a : t_iq(i(g_a_dw - 1 downto 0), q(g_a_dw - 1 downto 0)) := ((others => '0'), (others => '0'));
    signal ib_b : t_iq(i(g_b_dw - 1 downto 0), q(g_b_dw - 1 downto 0)) := ((others => '0'), (others => '0'));

    signal pipe_v : std_logic_vector(0 to c_latency) := (others => '0');
    signal pipe_gp : t_pipe_gp(0 to c_latency) := (others => (others => '0'));

    -- output buffers
    signal ob_v : std_logic := '0';
    signal ob_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');
    signal ob_c : t_iq(i(c_c_w - 1 downto 0), q(c_c_w - 1 downto 0)) := ((others => '0'), (others => '0'));

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_v                                <= iVALID;
    ib_a.i                              <= signed(iDATA(msb_i_are downto lsb_i_are));
    ib_a.q                              <= signed(iDATA(msb_i_aim downto lsb_i_aim));
    ib_b.i                              <= signed(iDATA(msb_i_bre downto lsb_i_bre));
    ib_b.q                              <= signed(iDATA(msb_i_bim downto lsb_i_bim));
    ib_gp                               <= iDATA(msb_i_gp downto lsb_i_gp);

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

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    GEN_type_0 : if g_type = 0 generate
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    blk_type_0 : block
----------------------------------------------------------------------------------------------------------------------------------
        constant c_m_w : integer := g_a_dw + g_b_dw;       -- multiplier

        signal
              dsp0_areg1
            , dsp1_areg1
            , dsp2_areg1
            , dsp3_areg1
            , dsp0_areg2
            , dsp2_areg2
                : signed(g_a_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_breg1
            , dsp1_breg1
            , dsp2_breg1
            , dsp3_breg1
            , dsp0_breg2
            , dsp2_breg2
                : signed(g_b_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_mreg
            , dsp1_mreg
            , dsp2_mreg
            , dsp3_mreg
                : signed(c_m_w - 1 downto 0) := (others => '0');
        signal
              dsp0_preg
            , dsp1_preg
            , dsp2_preg
            , dsp3_preg
                : signed(c_c_w - 1 downto 0) := (others => '0');
----------------------------------------------------------------------------------------------------------------------------------
    begin
----------------------------------------------------------------------------------------------------------------------------------
    p_main : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if pipe_v(0) = '1' then
                dsp0_areg1 <= ib_a.i;                                           -- A
                dsp1_areg1 <= ib_a.q;                                           -- a
                dsp2_areg1 <= ib_a.i;                                           -- A
                dsp3_areg1 <= ib_a.q;                                           -- a
                dsp0_breg1 <= ib_b.i;                                           -- B
                dsp1_breg1 <= ib_b.q;                                           -- b
                dsp2_breg1 <= ib_b.q;                                           -- b
                dsp3_breg1 <= ib_b.i;                                           -- B
            end if;

            if pipe_v(1) = '1' then
                dsp0_areg2 <= dsp0_areg1;                                       -- A
                dsp0_breg2 <= dsp0_breg1;                                       -- B
                dsp1_mreg  <= dsp1_areg1 * dsp1_breg1;                          -- a x b
                dsp2_areg2 <= dsp2_areg1;                                       -- A
                dsp2_breg2 <= dsp2_breg1;                                       -- b
                dsp3_mreg  <= dsp3_areg1 * dsp3_breg1;                          -- a x B
            end if;

            if pipe_v(2) = '1' then
                dsp0_mreg <= dsp0_areg2 * dsp0_breg2;                           -- A x B
                dsp1_preg <= resize(dsp1_mreg, c_c_w);                          -- a x b
                dsp2_mreg <= dsp2_areg2 * dsp2_breg2;                           -- A x b
                dsp3_preg <= resize(dsp3_mreg, c_c_w);                          -- a x B
            end if;

            if pipe_v(3) = '1' then
                if g_conj_mult = false then
                    dsp0_preg <= resize(dsp0_mreg, c_c_w) - dsp1_preg;          -- A x B - a x b
                    dsp2_preg <= resize(dsp2_mreg, c_c_w) + dsp3_preg;          -- A x b + a x B
                else
                    dsp0_preg <= dsp1_preg + resize(dsp0_mreg, c_c_w);          -- a x b + A x B
                    dsp2_preg <= dsp3_preg - resize(dsp2_mreg, c_c_w);          -- a x B - A x b
                end if;
            end if;
        end if;
    end process;

    ob_v                                <= pipe_v(c_latency);
    ob_c.i                              <= dsp0_preg;
    ob_c.q                              <= dsp2_preg;
----------------------------------------------------------------------------------------------------------------------------------
    end block;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    end generate;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    GEN_type_1 : if g_type = 1 and g_conj_mult = false generate
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    blk_type_1 : block
----------------------------------------------------------------------------------------------------------------------------------
        constant c_ad_a_w : integer := g_a_dw + 1;                              -- preadder for A
        constant c_ad_b_w : integer := g_b_dw + 1;                              -- preadder for B
        constant c_m0_w : integer := g_b_dw + c_ad_a_w;                         -- mult for DSP0
        constant c_m1_w : integer := g_a_dw + c_ad_b_w;                         -- mult for DSP1
        constant c_m2_w : integer := g_b_dw + c_ad_a_w;                         -- mult for DSP0

        signal
              dsp0_areg1
            , dsp0_dreg1
            , dsp1_breg1
            , dsp1_breg2
            , dsp2_areg1
            , dsp2_dreg1
                : signed(g_a_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_breg1
            , dsp0_breg2
            , dsp1_areg1
            , dsp1_dreg1
            , dsp2_breg1
            , dsp2_breg2
                : signed(g_b_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_adreg
            , dsp2_adreg
                : signed(c_ad_a_w - 1 downto 0) := (others => '0');
        signal dsp1_adreg : signed(c_ad_b_w - 1 downto 0) := (others => '0');
        signal dsp0_mreg : signed(c_m0_w - 1 downto 0) := (others => '0');
        signal dsp1_mreg : signed(c_m1_w - 1 downto 0) := (others => '0');
        signal dsp2_mreg : signed(c_m2_w - 1 downto 0) := (others => '0');
        signal
              dsp0_preg
            , dsp2_preg
                : signed(c_c_w - 1 downto 0) := (others => '0');
----------------------------------------------------------------------------------------------------------------------------------
    begin
----------------------------------------------------------------------------------------------------------------------------------
    p_main : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if pipe_v(0) = '1' then
                dsp0_breg1 <= ib_b.q;                                           -- b
                dsp0_areg1 <= ib_a.i;                                           -- A
                dsp0_dreg1 <= ib_a.q;                                           -- a
                dsp1_breg1 <= ib_a.i;                                           -- A
                dsp1_areg1 <= ib_b.i;                                           -- B
                dsp1_dreg1 <= ib_b.q;                                           -- b
                dsp2_breg1 <= ib_b.i;                                           -- B
                dsp2_areg1 <= ib_a.i;                                           -- A
                dsp2_dreg1 <= ib_a.q;                                           -- a
            end if;

            if pipe_v(1) = '1' then
                dsp0_breg2 <= dsp0_breg1;                                       -- b
                dsp0_adreg <=                                                   -- A + a
                    resize(dsp0_areg1, c_ad_a_w) + resize(dsp0_dreg1, c_ad_a_w);
                dsp1_breg2 <= dsp1_breg1;                                       -- A
                dsp1_adreg <=                                                   -- B + b
                    resize(dsp1_areg1, c_ad_b_w) + resize(dsp1_dreg1, c_ad_b_w);
                dsp2_breg2 <= dsp2_breg1;                                       -- B
                dsp2_adreg <=                                                   -- a - A
                    resize(dsp2_dreg1, c_ad_a_w) - resize(dsp2_areg1, c_ad_a_w);
            end if;

            if pipe_v(2) = '1' then
                dsp0_mreg <= dsp0_breg2 * dsp0_adreg;                           -- b x (A + a)
                dsp1_mreg <= dsp1_breg2 * dsp1_adreg;                           -- A x (B + b)
                dsp2_mreg <= dsp2_breg2 * dsp2_adreg;                           -- B x (a - A)
            end if;

            if pipe_v(3) = '1' then
                dsp0_preg <=                                                    -- A x (B + b) - b x (A + a)
                    resize(dsp1_mreg, c_c_w) - resize(dsp0_mreg, c_c_w);
                dsp2_preg <=                                                    -- A x (B + b) + B x (a - A)
                    resize(dsp1_mreg, c_c_w) + resize(dsp2_mreg, c_c_w);
            end if;
        end if;
    end process;

    ob_v                                <= pipe_v(c_latency);
    ob_c.i                              <= dsp0_preg;
    ob_c.q                              <= dsp2_preg;
----------------------------------------------------------------------------------------------------------------------------------
    end block;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    end generate;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    GEN_type_1_conj : if g_type = 1 and g_conj_mult = true generate
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    blk_type_1_conj : block
----------------------------------------------------------------------------------------------------------------------------------
        constant c_ad_a_w : integer := g_a_dw + 1;                              -- preadder for A
        constant c_ad_b_w : integer := g_b_dw + 1;                              -- preadder for B
        constant c_m0_w : integer := g_a_dw + c_ad_b_w;                         -- mult for DSP0
        constant c_m1_w : integer := g_b_dw + c_ad_a_w;                         -- mult for DSP1
        constant c_m2_w : integer := g_a_dw + c_ad_b_w;                         -- mult for DSP0

        signal
              dsp0_breg1
            , dsp0_breg2
            , dsp1_areg1
            , dsp1_dreg1
            , dsp2_breg1
            , dsp2_breg2
                : signed(g_a_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_areg1
            , dsp0_dreg1
            , dsp1_breg1
            , dsp1_breg2
            , dsp2_areg1
            , dsp2_dreg1
                : signed(g_b_dw - 1 downto 0) := (others => '0');
        signal dsp1_adreg : signed(c_ad_a_w - 1 downto 0) := (others => '0');
        signal
              dsp0_adreg
            , dsp2_adreg
                : signed(c_ad_b_w - 1 downto 0) := (others => '0');
        signal dsp0_mreg : signed(c_m0_w - 1 downto 0) := (others => '0');
        signal dsp1_mreg : signed(c_m1_w - 1 downto 0) := (others => '0');
        signal dsp2_mreg : signed(c_m2_w - 1 downto 0) := (others => '0');
        signal
              dsp0_preg
            , dsp2_preg
                : signed(c_c_w - 1 downto 0) := (others => '0');
----------------------------------------------------------------------------------------------------------------------------------
    begin
----------------------------------------------------------------------------------------------------------------------------------
    p_main : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if pipe_v(0) = '1' then
                dsp0_breg1 <= ib_a.q;                                           -- a
                dsp0_areg1 <= ib_b.q;                                           -- b
                dsp0_dreg1 <= ib_b.i;                                           -- B
                dsp1_breg1 <= ib_b.i;                                           -- B
                dsp1_areg1 <= ib_a.i;                                           -- A
                dsp1_dreg1 <= ib_a.q;                                           -- a
                dsp2_breg1 <= ib_a.i;                                           -- A
                dsp2_areg1 <= ib_b.i;                                           -- B
                dsp2_dreg1 <= ib_b.q;                                           -- b
            end if;

            if pipe_v(1) = '1' then
                dsp0_breg2 <= dsp0_breg1;                                       -- a
                dsp0_adreg <=                                                   -- b - B
                    resize(dsp0_areg1, c_ad_b_w) - resize(dsp0_dreg1, c_ad_b_w);
                dsp1_breg2 <= dsp1_breg1;                                       -- B
                dsp1_adreg <=                                                   -- A + a
                    resize(dsp1_areg1, c_ad_a_w) + resize(dsp1_dreg1, c_ad_a_w);
                dsp2_breg2 <= dsp2_breg1;                                       -- A
                dsp2_adreg <=                                                   -- b + B
                    resize(dsp2_dreg1, c_ad_b_w) + resize(dsp2_areg1, c_ad_b_w);
            end if;

            if pipe_v(2) = '1' then
                dsp0_mreg <= dsp0_breg2 * dsp0_adreg;                           -- a x (b - B)
                dsp1_mreg <= dsp1_breg2 * dsp1_adreg;                           -- B x (A + a)
                dsp2_mreg <= dsp2_breg2 * dsp2_adreg;                           -- A x (b + B)
            end if;

            if pipe_v(3) = '1' then
                dsp0_preg <=                                                    -- B x (A + a) + a x (b - B)
                    resize(dsp1_mreg, c_c_w) + resize(dsp0_mreg, c_c_w);
                dsp2_preg <=                                                    -- B x (A + a) - A x (b + B)
                    resize(dsp1_mreg, c_c_w) - resize(dsp2_mreg, c_c_w);
            end if;
        end if;
    end process;

    ob_v                                <= pipe_v(c_latency);
    ob_c.i                              <= dsp0_preg;
    ob_c.q                              <= dsp2_preg;
----------------------------------------------------------------------------------------------------------------------------------
    end block;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    end generate;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    oVALID                              <= ob_v;
    oDATA                               <=
        ob_gp &
        std_logic_vector(ob_c.q) &
        std_logic_vector(ob_c.i)
    ;

----------------------------------------------------------------------------------------------------------------------------------
end;