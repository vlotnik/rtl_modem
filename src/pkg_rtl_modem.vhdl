----------------------------------------------------------------------------------------------------------------------------------
-- author : vitaly lotnik
-- name : pkg_rtl_modem
-- created : 19/02/2022
-- v. 0.0.0
----------------------------------------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------------------------------------
-- libraries
----------------------------------------------------------------------------------------------------------------------------------
library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;

----------------------------------------------------------------------------------------------------------------------------------
--package declaration
----------------------------------------------------------------------------------------------------------------------------------
package pkg_rtl_modem is
----------------------------------------------------------------------------------------------------------------------------------
-- functions declaration
----------------------------------------------------------------------------------------------------------------------------------
    function f_round(data: in signed; lsb_number: in integer) return signed;
    function f_round(data: in std_logic_vector; lsb_number: in integer) return std_logic_vector;

----------------------------------------------------------------------------------------------------------------------------------
end;

----------------------------------------------------------------------------------------------------------------------------------
-- package body declaration
----------------------------------------------------------------------------------------------------------------------------------
package body pkg_rtl_modem is
----------------------------------------------------------------------------------------------------------------------------------
-- functions
----------------------------------------------------------------------------------------------------------------------------------
    function f_round(data : in signed; lsb_number : in integer) return signed is
        variable v_out_data : signed(data'high + 1 downto 0) := (others => '0');
        variable v_mask : signed(data'high + 1 downto 0) := (others => '0');
    begin
        case lsb_number is
            when 0 => v_out_data := resize(data, data'length + 1);
            when 1 => v_out_data := resize(data, data'length + 1);
            when others => v_mask(lsb_number - 2 downto 0) := (others => '1');
        end case;

        if (data(data'high) = '0' and lsb_number > 0) then
            v_mask := v_mask + 1;
        end if;

        v_out_data := resize(data, data'length + 1) + v_mask;

        return v_out_data;
    end function;

    function f_round(data : in std_logic_vector; lsb_number : in integer) return std_logic_vector is
        variable v_out_data : std_logic_vector(data'high + 1 downto 0) := (others => '0');
    begin
        v_out_data := std_logic_vector(f_round(signed(data), lsb_number));

        return v_out_data;
    end function;

----------------------------------------------------------------------------------------------------------------------------------
end;