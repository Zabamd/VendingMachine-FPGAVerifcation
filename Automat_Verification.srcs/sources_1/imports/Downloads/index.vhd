library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity napoje_beh is
    Port (
              user_ok : in  STD_LOGIC;
           user_break : in  STD_LOGIC;
           user_sel : in  STD_LOGIC;
              clk : in  STD_LOGIC;
           reset : in  STD_LOGIC;
           nr_w : in STD_LOGIC;
           adres : in  STD_LOGIC_VECTOR (2 downto 0);
           dane_we : in  STD_LOGIC_VECTOR (7 downto 0);
           dane_wy : out  STD_LOGIC_VECTOR (7 downto 0);
           moneta_in : in  STD_LOGIC;
           podajnik_trig : out  STD_LOGIC; --wyjscie wyzwalania podajnika
              nr_podajnika : out  STD_LOGIC_VECTOR (1 downto 0);
           reszta_out : out  STD_LOGIC
              );             
                                           
end napoje_beh;

architecture Napoje_beh of napoje_beh is
-- mapa pamięci
constant KAWA_ile_adr : std_logic_vector(2 downto 0):= "001";
constant HERB_ile_adr :std_logic_vector(2 downto 0):= "010";
constant SOK_ile_adr :std_logic_vector(2 downto 0):= "011";
constant KAWA_cena_adr : std_logic_vector(2 downto 0):= "101";
constant HERB_cena_adr :std_logic_vector(2 downto 0):= "110";
constant SOK_cena_adr :std_logic_vector(2 downto 0):= "111";
constant STAN_adr :std_logic_vector(2 downto 0):= "000"; --adres rejestru stanu maszyny
constant MONETY_ile_adr :std_logic_vector(2 downto 0):= "100"; --adres rejestru wrzuconych monet

--rejestry
signal KAWA_ile : std_logic_vector(7 downto 0); --ile dostępnych zasobników
signal HERB_ile :std_logic_vector(7 downto 0);
signal SOK_ile :std_logic_vector(7 downto 0);
signal KAWA_cena : std_logic_vector(3 downto 0); -- cena jednego zasobnika
signal HERB_cena :std_logic_vector(3 downto 0);
signal SOK_cena :std_logic_vector(3 downto 0);
signal STAN :std_logic_vector(2 downto 0);-- rejestr stanu maszyny
signal MONETY_ile :std_logic_vector(7 downto 0); -- rejestr wrzuconych monet

--inne  
signal moc: std_logic_vector(1 downto 0);
signal napoj: std_logic_vector(1 downto 0); --01== kawa; 10 ==herbata; 11==sok
signal STAN_nast :std_logic_vector(2 downto 0);
signal naleznosc :std_logic_vector(7 downto 0);
signal napoj_gotowy :std_logic; --flaga gotowosci napoju
signal moc_tmp: std_logic_vector(1 downto 0);
signal podajnik_tmp: std_logic;

--pomocnicze linie do wykrywania zbocza sygnałow sterujących automatem
signal OK_a : std_logic;
signal OK_aa : std_logic;
signal OK_edge : std_logic;
signal sel_a : std_logic;
signal sel_aa : std_logic;
signal sel_edge : std_logic;
signal moneta_in_a : std_logic;
signal moneta_in_aa : std_logic;
signal moneta_in_edge : std_logic;
begin

-- wpisywanie wartości do rejestrów programowalnych
reg_prog: process (reset, clk)
begin
    if reset = '1' then --aktywny reset==1
        KAWA_cena <= (others => '0');
        HERB_cena <=  (others => '0');
        SOK_cena <=  (others => '0');
        KAWA_ile <= (others => '0');
        HERB_ile <=  (others => '0');
        SOK_ile <=  (others => '0');
        naleznosc <= (others => '0');       
    elsif clk'event and clk='1' then
       if (adres = KAWA_ile_adr and nr_w = '1') then
            KAWA_ile <= dane_we; --(7 downto 0); --wpis do rejestru KAWA_ile
        elsif adres=HERB_ile_adr and nr_w = '1' then
            HERB_ile <= dane_we; --(7 downto 0); --wpis do rejestru HERB_ile
        elsif adres=SOK_ile_adr and nr_w = '1' then
            SOK_ile <= dane_we; --(7 downto 0); --wpis do rejestru SOK_ile
        elsif adres=KAWA_cena_adr and nr_w = '1' then
            KAWA_cena <= dane_we (3 downto 0); --wpis do rejestru KAWA_cena
        elsif adres=HERB_cena_adr and nr_w = '1' then
            HERB_cena <= dane_we (3 downto 0); --wpis do rejestru HERB_cena
        elsif adres=SOK_cena_adr and nr_w = '1' then
            SOK_cena <= dane_we (3 downto 0); --wpis do rejestru SOK_cena
        --end if;
        elsif STAN="010" then --w stanie PLATNOSC
            if napoj = "01" then
            naleznosc <= ("00" & (moc * KAWA_cena));
            KAWA_ile <= KAWA_ile -  moc; --zmniejszenie ilości zasobników
            elsif napoj = "10" then
            naleznosc <= ("00"&(moc * HERB_cena));
            HERB_ile <= HERB_ile -  moc;
            elsif napoj = "11" then
            naleznosc <= ("00"&(moc * SOK_cena));
            SOK_ile <= SOK_ile - moc;
            end if;
        end if;
    end if;
end process reg_prog;

-- odczyt rejestrow maszyny


dane_wy <= KAWA_ile when (adres = KAWA_ile_adr and nr_w='0')
        else HERB_ile when (adres = HERB_ile_adr and nr_w='0')
        else SOK_ile when (adres = SOK_ile_adr and nr_w='0')
        else ("0000" & KAWA_cena) when (adres = KAWA_cena_adr and nr_w='0')
        else ("0000" & HERB_cena) when (adres = HERB_cena_adr and nr_w='0')
        else ("0000" & SOK_cena) when (adres = SOK_cena_adr and nr_w='0')
        else ("00000" & STAN) when (adres=STAN_adr and nr_w='0')              
        else MONETY_ile when (adres=MONETY_ile_adr and nr_w='0')
        else  "00000000";
       

maszyna_stanow: process(STAN, OK_edge, user_break, MONETY_ile, naleznosc, napoj_gotowy) -- automat stanu, logika
--kombinacyjna, ktora "przygotowuje" odpowiednia wartosc na wejsciu (stan_nastepny) rejestru stanu    
-- na liscie wrazliwosci wymienione są WSZYSTKIE wejscia dla tej logiki
    begin
        STAN_nast <= STAN;    -- stan bieżacy "kreci sie w kolko" gdy nie ma zmian stanu       
        case STAN is
            when "000" => --RESET
                    STAN_nast <= "001";
                               
            when "001" => --WYBÓR
                if (OK_edge='1' and user_break='0') then
                    STAN_nast <= "011";
                elsif user_break='1' then
                    STAN_nast <= "001";                   
                end if;
               
            when "011" => --MOC
                if (OK_edge='1' and user_break='0') then
                    STAN_nast <= "010"; --przejdz do PŁATNOŚĆ
                elsif user_break='1' then
                    STAN_nast <= "001";        -- wroc do WYBOR   
                elsif (napoj = "01" and (KAWA_ile-moc) < 0) or  (napoj = "10" and (HERB_ile-moc)< 0)
                or (napoj = "11" and (SOK_ile-moc) < 0) then
                    STAN_nast <= "001";        -- wroc do WYBOR - nie ma tylu zasobników wybranego napoju   
                end if;
               
               
            when "010" => --PŁATNOŚĆ
                if (OK_edge='1' and user_break='0' and MONETY_ile>=naleznosc) then
                    STAN_nast <= "110"; --przejdz do PRZYGOTOWANIE
                    --napoj_gotowy <='0';
                elsif user_break='1' then
                    STAN_nast <= "100";        -- przejdz do RESZTA/ZWROT   
                end if;
               
            when "110" => --PRZYGOTOWANIE
                if napoj_gotowy='1' then
                    STAN_nast <= "100";        -- przejdz do RESZTA   
                end if;   
            when others =>
                STAN_nast <= "001"; --WYBÓR
        end case;
    
end process maszyna_stanow;


reg: process (reset, clk)                -- rejestr stanu wewnetrznego
    begin
        if reset ='1' then
            STAN <= "001";
        elsif clk'event and clk='1' then
            STAN <= STAN_nast;            -- przy zboczu narastajacym na wyjscie rejestru (stan) przepisuje wejscie (stan_nastepny)
        end if;
end process reg;


placenie: process(moneta_in, moneta_in_edge, reset, STAN) --obsługa płacenia - licznik wrzucanych monet
begin
    if reset='1' then
    MONETY_ile <= (others => '0');
    elsif (moneta_in_edge='1' and moneta_in='1' and STAN = "010") then
        MONETY_ile <= MONETY_ile + "00000001";
    elsif STAN = "000" or STAN = "100" then
        MONETY_ile <= (others => '0');
    elsif STAN = "110" then
        MONETY_ile <= MONETY_ile -naleznosc;
    end if;
end process placenie;


reszta: process(reset, STAN) --obsługa płacenia - licznik wrzucanych monet
begin
    if reset='1' then
    reszta_out <= '0';
    elsif (STAN="100") then --stan reszta
        reszta_out <= '1';
    else 
            reszta_out <= '0';       
    end if;
end process reszta;



wybor: process(reset, user_sel, sel_edge ,STAN) --wybieranie pozycji z listy
begin
    if reset='1' then
        moc <= "01"; --domyślna moc
        napoj <= "01"; --domyślny napój
    elsif sel_edge='1' and user_sel='1' then
        if STAN = "001" then --stan WYBÓR napoju
            if napoj <= "10" then napoj <= (napoj + 1);
            elsif napoj = "11"  then napoj <= "01"; end if;
        elsif STAN = "011" then --stan WYBÓR mocy
            if moc <= "10" then moc <= (moc + 1);
            elsif moc = "11"  then moc <= "01"; end if;
        end if;
    end if;
end process wybor;


przygotuj: process(reset,clk)
begin
    if reset='1' then
        nr_podajnika <="00";
        podajnik_trig <= '0';
        podajnik_tmp <= '0';       
        moc_tmp <="00";
        napoj_gotowy <= '0';
    elsif clk'event and clk='1' then
        if STAN="110" then --stan PRZYGOTOWANIE napoju
            nr_podajnika <= napoj; --wystaw nr podajnika
            if moc_tmp < moc then
                if podajnik_tmp='0' then
                    podajnik_trig <= '1'; --wyjście aktywowane tyle razy, ile wybrana moc napoju
                    podajnik_tmp <= '1';
                else
                    podajnik_trig <= '0';
                    moc_tmp <= (moc_tmp+1);
                    podajnik_tmp <= '0';
                end if;
            elsif moc_tmp=moc then
                napoj_gotowy <= '1';            
            end if;
        else
            moc_tmp <= "00";    --w innych stanach
            napoj_gotowy <= '0';                
        end if;
    end if;

end process przygotuj;



OK_edge_finder: process (reset, clk) --wykrywanie zbocza sygnału user_OK
begin
    if reset = '1' then
        OK_a <= '0';
        OK_aa <= '0';
    elsif clk'event and clk='1' then
        OK_a <= user_OK;
        OK_aa <= OK_a;
    end if;
end process OK_edge_finder;

OK_edge <= OK_a and not OK_aa;


sel_edge_finder: process (reset, clk) --wykrywanie zbocza sygnału user_sel
begin
    if reset = '1' then
        sel_a <= '0';
        sel_aa <= '0';
    elsif clk'event and clk='1' then
        sel_a <= user_sel;
        sel_aa <= sel_a;
    end if;
end process sel_edge_finder;

sel_edge <= sel_a and not sel_aa;


moneta_in_edge_finder: process (reset, clk) --wykrywanie zbocza sygnału user_sel
begin
    if reset = '1' then
        moneta_in_a <= '0';
        moneta_in_aa <= '0';
    elsif clk'event and clk='1' then
        moneta_in_a <= moneta_in;
        moneta_in_aa <= moneta_in_a;
    end if;
end process moneta_in_edge_finder;
moneta_in_edge <= moneta_in_a and not moneta_in_aa;

end Napoje_beh;