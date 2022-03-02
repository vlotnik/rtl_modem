----------------------------------------------------------------------------------------------------------------------------------
-- author : vitaly lotnik
-- name : rounder
-- created : 20/02/2022
-- v. 0.0.0

----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, input:
-- g_iraxi_dw                           idata
--      g_sample_dw*g_nof_samples           sample[0], sample[1] ...
--      g_gp_dw                             general purpose data
--          g_gp_dw + g_sample_dw*g_nof_samples

----------------------------------------------------------------------------------------------------------------------------------
-- raxi interface, output:
-- g_iraxi_dw                           odata
--      g_osample_dw*g_nof_samples          sample[0], sample[1] ...
--      g_gp_dw                             general purpose data
--          g_gp_dw + g_osample_dw*g_nof_samples
-- g_osample_dw = g_sample_dw - g_rnd_lsb + 1
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;

----------------------------------------------------------------------------------------------------------------------------------
--package declaration
----------------------------------------------------------------------------------------------------------------------------------
package pkg_rounder is
    constant c_total_latency : integer := 1;
end;

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

library rtl_modem;
    use rtl_modem.pkg_rtl_modem.all;

----------------------------------------------------------------------------------------------------------------------------------
-- entity declaration
----------------------------------------------------------------------------------------------------------------------------------
entity rounder is
    generic(
          g_gp_dw                       : integer := 10
        ; g_nof_samples                 : integer := 1
        ; g_sample_dw                   : integer := 12
        ; g_rnd_lsb                     : integer := 1
        ; g_pipe_ce                     : boolean := false
        ; g_iraxi_dw                    : integer := 10 + 12*1
        ; g_oraxi_dw                    : integer := 10 + (12 - 1 + 1)*1
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
architecture behavioral of rounder is
----------------------------------------------------------------------------------------------------------------------------------
-- constants declaration
----------------------------------------------------------------------------------------------------------------------------------
    constant c_odata_dw : integer := g_sample_dw - g_rnd_lsb + 1;

----------------------------------------------------------------------------------------------------------------------------------
-- types declaration
----------------------------------------------------------------------------------------------------------------------------------
    type t_idata_array is array (natural range <>) of std_logic_vector(g_sample_dw - 1 downto 0);
    type t_rnd_array is array (natural range <>) of std_logic_vector(g_sample_dw downto 0);
    type t_odata_array is array (natural range <>) of std_logic_vector(c_odata_dw - 1 downto 0);

----------------------------------------------------------------------------------------------------------------------------------
-- signals declaration
----------------------------------------------------------------------------------------------------------------------------------
    -- input
    signal ib_valid : std_logic := '0';
    signal ib_data : std_logic_vector(g_iraxi_dw - 1 downto 0) := (others => '0');

    signal ib_sample : t_idata_array(0 to g_nof_samples - 1) := (others => (others => '0'));
    signal ib_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    -- rounding
    signal rnd_valid : std_logic := '0';
    signal rnd_sample : t_rnd_array(0 to g_nof_samples - 1) := (others => (others => '0'));
    signal rnd_gp : std_logic_vector(g_gp_dw - 1 downto 0) := (others => '0');

    -- output
    signal ob_valid : std_logic := '0';
    signal ob_data : std_logic_vector(g_oraxi_dw - 1 downto 0) := (others => '0');

begin
----------------------------------------------------------------------------------------------------------------------------------
-- input
----------------------------------------------------------------------------------------------------------------------------------
    ib_valid                            <= iVALID;
    ib_data                             <= iDATA;

    GEN_idata : for a in 0 to g_nof_samples - 1 generate
    ib_sample(a)                        <= ib_data(g_sample_dw*(a + 1) - 1 downto g_sample_dw*a);
    end generate;
    ib_gp                               <= ib_data(g_gp_dw + g_sample_dw*g_nof_samples - 1 downto g_sample_dw*g_nof_samples);

----------------------------------------------------------------------------------------------------------------------------------
-- process, round
----------------------------------------------------------------------------------------------------------------------------------
    p_rnd : process(iCLK)
    begin
        if rising_edge(iCLK) then
            if g_pipe_ce = true then
                rnd_valid <= ib_valid;
                rnd_gp <= ib_gp;
                for a in 0 to g_nof_samples - 1 loop
                    rnd_sample(a) <= f_round(ib_sample(a), g_rnd_lsb);
                end loop;
            else
                if ib_valid = '1' then
                    rnd_gp <= ib_gp;
                    for a in 0 to g_nof_samples - 1 loop
                        rnd_sample(a) <= f_round(ib_sample(a), g_rnd_lsb);
                    end loop;
                end if;
            end if;
        end if;
    end process;

----------------------------------------------------------------------------------------------------------------------------------
    ob_valid                            <=
        rnd_valid when g_pipe_ce = true else
        ib_valid;

    GEN_odata : for a in 0 to g_nof_samples - 1 generate
    ob_data(c_odata_dw*(a + 1) - 1 downto c_odata_dw*a) <= rnd_sample(a)(g_sample_dw downto g_rnd_lsb);
    end generate;
    ob_data(g_gp_dw + c_odata_dw*g_nof_samples - 1 downto c_odata_dw*g_nof_samples) <= rnd_gp;

----------------------------------------------------------------------------------------------------------------------------------
-- output
----------------------------------------------------------------------------------------------------------------------------------
    oVALID                              <= ob_valid;
    oDATA                               <= ob_data;

----------------------------------------------------------------------------------------------------------------------------------
end;