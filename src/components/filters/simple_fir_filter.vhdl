----------------------------------------------------------------------------------------------------------------------------------
-- author : vitaly lotnik
-- name : simple_fir_filter
-- created : 12/12/2021
-- v. 0.1.2
----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, coef, input:
-- g_iraxi_dw_coef                      icoef_data
--      g_coef_dw                           coefficient
----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, data, input:
-- g_iraxi_dw                           idata
--      g_sample_dw                         sample
----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, data, output:
-- g_oraxi_dw                           odata
--      48                                  sample
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

----------------------------------------------------------------------------------------------------------------------------------
-- entity declaration
----------------------------------------------------------------------------------------------------------------------------------
entity simple_fir_filter is
    generic(
          g_nof_taps                    : integer := 32
        ; g_coef_dw                     : integer := 16
        ; g_sample_dw                   : integer := 12
        ; g_iraxi_dw_coef               : integer := 16
        ; g_iraxi_dw                    : integer := 12
        ; g_oraxi_dw                    : integer := 48
    );
    port(
          iclk                          : in std_logic
        ; icoef_rst                     : in std_logic
        ; icoef_valid                   : in std_logic
        ; icoef_data                    : in std_logic_vector(g_iraxi_dw_coef - 1 downto 0)
        ; ivalid                        : in std_logic
        ; idata                         : in std_logic_vector(g_iraxi_dw - 1 downto 0)
        ; ovalid                        : out std_logic
        ; odata                         : out std_logic_vector(g_oraxi_dw - 1 downto 0)
    );
end;

----------------------------------------------------------------------------------------------------------------------------------
-- architecture declaration
----------------------------------------------------------------------------------------------------------------------------------
architecture behavioral of simple_fir_filter is
----------------------------------------------------------------------------------------------------------------------------------
-- constants declaration
----------------------------------------------------------------------------------------------------------------------------------
    constant c_mreg_dw : integer := g_sample_dw + g_coef_dw;

----------------------------------------------------------------------------------------------------------------------------------
-- types declaration
----------------------------------------------------------------------------------------------------------------------------------
    type t_coef_array is array (natural range <>) of signed(g_coef_dw - 1 downto 0);
    type t_data_array is array (natural range <>) of signed(g_sample_dw - 1 downto 0);
    type t_mreg_array is array (natural range <>) of signed(c_mreg_dw - 1 downto 0);
    type t_signed48array is array (natural range <>) of signed(47 downto 0);

----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    -- input buffers
    signal ib_coef_rst : std_logic := '0';
    signal ib_coef_valid : std_logic := '0';
    signal ib_coef_data : signed(g_coef_dw - 1 downto 0) := (others => '0');
    signal ib_valid : std_logic := '0';
    signal ib_data : signed(g_sample_dw - 1 downto 0) := (others => '0');

    -- coefs
    signal coefs_array : t_coef_array(0 to g_nof_taps - 1) := (others => (others => '0'));

    -- fir
    signal fir_areg1 : t_data_array(0 to g_nof_taps - 1) := (others => (others => '0'));
    signal fir_areg2 : t_data_array(0 to g_nof_taps - 1) := (others => (others => '0'));
    signal fir_breg : t_coef_array(0 to g_nof_taps - 1) := (others => (others => '0'));
    signal fir_mreg : t_mreg_array(0 to g_nof_taps - 1) := (others => (others => '0'));
    signal fir_preg : t_signed48array(0 to g_nof_taps - 1) := (others => (others => '0'));

    -- output buffers
    signal ob_valid : std_logic := '0';
    signal ob_data : signed(47 downto 0) := (others => '0');

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_coef_rst                         <= icoef_rst;
    ib_coef_valid                       <= icoef_valid;
    ib_coef_data                        <= signed(icoef_data);
    ib_valid                            <= ivalid;
    ib_data                             <= signed(idata);

----------------------------------------------------------------------------------------------------------------------------------
-- process, set coefficients
----------------------------------------------------------------------------------------------------------------------------------
    p_coefs : process(iclk)
    begin
        if rising_edge(iclk) then
            if ib_coef_rst = '1' then
                coefs_array <= (others => (others => '0'));
            else
                if ib_coef_valid = '1' then
                    coefs_array <= coefs_array(1 to coefs_array'high) & ib_coef_data;
                end if;
            end if;
        end if;
    end process;

----------------------------------------------------------------------------------------------------------------------------------
-- process, fir implementation
----------------------------------------------------------------------------------------------------------------------------------
    p_fir : process(iclk)
    begin
        if rising_edge(iclk) then
            fir_breg <= coefs_array;

            if ib_valid = '1' then
                for a in 0 to g_nof_taps - 1 loop
                    if a = 0 then
                        fir_areg1(a) <= ib_data;
                    else
                        fir_areg1(a) <= fir_areg2(a - 1);
                    end if;
                    fir_areg2(a) <= fir_areg1(a);

                    fir_mreg(a) <= fir_areg2(a) * fir_breg(a);

                    if a = 0 then
                        fir_preg(a) <= resize(fir_mreg(a), 48);
                    else
                        fir_preg(a) <= resize(fir_mreg(a), 48) + fir_preg(a - 1);
                    end if;
                end loop;
            end if;
        end if;
    end process;

    ob_valid                            <= ib_valid;
    ob_data                             <= fir_preg(g_nof_taps - 1);

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    ovalid                              <= ob_valid;
    odata                               <= std_logic_vector(ob_data);

----------------------------------------------------------------------------------------------------------------------------------
end;