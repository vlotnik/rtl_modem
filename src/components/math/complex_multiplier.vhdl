----------------------------------------------------------------------------------------------------------------------------------
-- Author : Vitaly Lotnik
-- Name : complex_multiplier
-- Created : 23/05/2021
-- v. 0.0.0

-- (A + ai) * (B + Bi) = C + ci
-- A ~ iA.i
-- a ~ iA.q
-- B ~ iB.i
-- b ~ iB.q
-- C ~ iC.i
-- c ~ iC.q
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
entity complex_multiplier is
    generic(
          g_a_dw                    : integer := 25
        ; g_b_dw                    : integer := 18
        ; g_type                    : integer := 1
    );
    port(
          iCLK                      : in std_logic
        ; iV                        : in std_logic
        ; iA                        : in t_iq
        ; iB                        : in t_iq
        ; oV                        : out std_logic
        ; oC                        : out t_iq
    );
end;

----------------------------------------------------------------------------------------------------------------------------------
-- architecture declaration
----------------------------------------------------------------------------------------------------------------------------------
architecture behavioral of complex_multiplier is
----------------------------------------------------------------------------------------------------------------------------------
-- constants declaration
----------------------------------------------------------------------------------------------------------------------------------
    constant c_c_dw : integer := g_a_dw + g_b_dw + 1;

----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    -- input buffers
    signal ib_v : std_logic := '0';
    signal ib_a : t_iq(i(g_a_dw - 1 downto 0), q(g_a_dw - 1 downto 0)) := ((others => '0'), (others => '0'));
    signal ib_b : t_iq(i(g_b_dw - 1 downto 0), q(g_b_dw - 1 downto 0)) := ((others => '0'), (others => '0'));

    signal pipe_v : std_logic_vector(0 to 4) := (others => '0');

    -- output buffers
    signal ob_v : std_logic := '0';
    signal ob_c : t_iq(i(c_c_dw - 1 downto 0), q(c_c_dw - 1 downto 0)) := ((others => '0'), (others => '0'));

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_v                            <= iV;
    ib_a                            <= iA;
    ib_b                            <= iB;

    pipe_v(0)                       <= ib_v;
    pipe_v(1 to pipe_v'high)        <= pipe_v(0 to pipe_v'high - 1)             when rising_edge(iCLK);

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    GEN_type_1 : if g_type = 1 generate
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    blk_type_1 : block
----------------------------------------------------------------------------------------------------------------------------------
        constant c_m_dw : integer := g_a_dw + g_b_dw;       -- multiplier

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
                : signed(c_m_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_preg
            , dsp1_preg
            , dsp2_preg
            , dsp3_preg
                : signed(c_c_dw - 1 downto 0) := (others => '0');
----------------------------------------------------------------------------------------------------------------------------------
    begin
----------------------------------------------------------------------------------------------------------------------------------
    p_main : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if pipe_v(0) = '1' then
                dsp0_areg1 <= ib_a.i;                       -- A
                dsp1_areg1 <= ib_a.q;                       -- a
                dsp2_areg1 <= ib_a.i;                       -- A
                dsp3_areg1 <= ib_a.q;                       -- a
                dsp0_breg1 <= ib_b.i;                       -- B
                dsp1_breg1 <= ib_b.q;                       -- b
                dsp2_breg1 <= ib_b.q;                       -- b
                dsp3_breg1 <= ib_b.i;                       -- B
            end if;

            if pipe_v(1) = '1' then
                dsp0_areg2 <= dsp0_areg1;                   -- A
                dsp0_breg2 <= dsp0_breg1;                   -- B
                dsp1_mreg  <= dsp1_areg1 * dsp1_breg1;      -- a x b
                dsp2_areg2 <= dsp2_areg1;                   -- A
                dsp2_breg2 <= dsp2_breg1;                   -- b
                dsp3_mreg  <= dsp3_areg1 * dsp3_breg1;      -- a x B
            end if;

            if pipe_v(2) = '1' then
                dsp0_mreg <= dsp0_areg2 * dsp0_breg2;       -- A x B
                dsp1_preg <= resize(dsp1_mreg, c_c_dw);     -- a x b
                dsp2_mreg <= dsp2_areg2 * dsp2_breg2;       -- A x b
                dsp3_preg <= resize(dsp3_mreg, c_c_dw);     -- a x B
            end if;

            if pipe_v(3) = '1' then
                dsp0_preg <=                                -- A x B - a x b
                    resize(dsp0_mreg, c_c_dw) -
                    dsp1_preg;
                dsp2_preg <=                                -- A x b + a x B
                    resize(dsp2_mreg, c_c_dw) +
                    dsp3_preg;
            end if;
        end if;
    end process;

    ob_v                            <= pipe_v(4);
    ob_c.i                          <= dsp0_preg;
    ob_c.q                          <= dsp2_preg;
----------------------------------------------------------------------------------------------------------------------------------
    end block;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    end generate;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    GEN_type_2 : if g_type = 2 generate
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    blk_type_2 : block
----------------------------------------------------------------------------------------------------------------------------------
        constant c_ad_a_dw : integer := g_a_dw + 1;         -- preadder for A
        constant c_ad_b_dw : integer := g_b_dw + 1;         -- preadder for B
        constant c_m0_dw : integer := g_b_dw + c_ad_a_dw;   -- mult for DSP0
        constant c_m1_dw : integer := g_a_dw + c_ad_b_dw;   -- mult for DSP1
        constant c_m2_dw : integer := g_b_dw + c_ad_a_dw;   -- mult for DSP0

        signal
              dsp0_areg1
            , dsp0_dreg
            , dsp1_breg1
            , dsp1_breg2
            , dsp2_areg1
            , dsp2_dreg
                : signed(g_a_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_breg1
            , dsp0_breg2
            , dsp1_areg1
            , dsp1_dreg
            , dsp2_breg1
            , dsp2_breg2
                : signed(g_b_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_adreg
            , dsp2_adreg
                : signed(c_ad_a_dw - 1 downto 0) := (others => '0');
        signal
              dsp1_adreg
                : signed(c_ad_b_dw - 1 downto 0) := (others => '0');
        signal dsp0_mreg : signed(c_m0_dw - 1 downto 0) := (others => '0');
        signal dsp1_mreg : signed(c_m1_dw - 1 downto 0) := (others => '0');
        signal dsp2_mreg : signed(c_m2_dw - 1 downto 0) := (others => '0');
        signal
              dsp0_preg
            , dsp2_preg
                : signed(c_c_dw - 1 downto 0) := (others => '0');
----------------------------------------------------------------------------------------------------------------------------------
    begin
----------------------------------------------------------------------------------------------------------------------------------
    p_main : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if pipe_v(0) = '1' then
                dsp0_breg1 <= ib_b.q;                       -- b
                dsp0_areg1 <= ib_a.i;                       -- A
                dsp0_dreg  <= ib_a.q;                       -- a
                dsp1_breg1 <= ib_a.i;                       -- A
                dsp1_areg1 <= ib_b.i;                       -- B
                dsp1_dreg  <= ib_b.q;                       -- b
                dsp2_breg1 <= ib_b.i;                       -- B
                dsp2_areg1 <= ib_a.i;                       -- A
                dsp2_dreg  <= ib_a.q;                       -- a
            end if;

            if pipe_v(1) = '1' then
                dsp0_breg2 <= dsp0_breg1;                   -- b
                dsp0_adreg <=                               -- A + a
                    resize(dsp0_areg1, c_ad_a_dw) +
                    resize(dsp0_dreg,  c_ad_a_dw);
                dsp1_breg2 <= dsp1_breg1;                   -- A
                dsp1_adreg <=                               -- B + b
                    resize(dsp1_areg1, c_ad_b_dw) +
                    resize(dsp1_dreg,  c_ad_b_dw);
                dsp2_breg2 <= dsp2_breg1;                   -- B
                dsp2_adreg <=                               -- a - A
                    resize(dsp2_dreg,  c_ad_a_dw) -
                    resize(dsp2_areg1, c_ad_a_dw);
            end if;

            if pipe_v(2) = '1' then
                dsp0_mreg <= dsp0_breg2 * dsp0_adreg;       -- b x (A + a)
                dsp1_mreg <= dsp1_breg2 * dsp1_adreg;       -- A x (B + b)
                dsp2_mreg <= dsp2_breg2 * dsp2_adreg;       -- B x (a - A)
            end if;

            if pipe_v(3) = '1' then
                dsp0_preg <=                                -- A x (B + b) - b x (A + a)
                    resize(dsp1_mreg, c_c_dw) -
                    resize(dsp0_mreg, c_c_dw);
                dsp2_preg <=                                -- A x (B + b) + B x (a - A)
                    resize(dsp1_mreg, c_c_dw) +
                    resize(dsp2_mreg, c_c_dw);
            end if;
        end if;
    end process;

    ob_v                            <= pipe_v(4);
    ob_c.i                          <= dsp0_preg;
    ob_c.q                          <= dsp2_preg;
----------------------------------------------------------------------------------------------------------------------------------
    end block;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    end generate;
--++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    oV                              <= ob_v;
    oC                              <= ob_c;

----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------
end;