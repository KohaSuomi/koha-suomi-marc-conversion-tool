USEMARCON-RDA
========
USEMARCON-ohjelmalla käytettävä konversiosääntö MARC 21 (ISBD) -muotoisten bibliografisten ja auktoriteettitietueiden muuttamiseksi RDA-kuvailusääntöjen mukaisiksi.

Konversiopakettia käytetään Melinda- ja Asteri-tietokantojen sekä Voyager-järjestelmää käyttävien tietokantojen RDA-konversioon. Konversio suoritettiin pääsiäisviikolla 2016.

Kehitys
-------
GitHub-varannossa on nyt konversion tuotantoversio.

Viimeisimmät muutokset
-------
Ruotsinkielinen konversioversio on lisätty. Konversio tuottaa tai kääntää kaikki 336-338-kentät RDA:n mukaisiksi ruotsinkielisiksi termeiksi sekä kääntää tai avaa englannin- ja ruotsinkieliset funktiotermit tai niiden lyhenteet ruotsiksi. Ruotsinkielisen konversion voi valita muuttamalla ma21RDA_bibliografiset.ini-tiedostossa kohdan "RuleFile=ma21RDA_bibl.rul" muotoon "RuleFile=sv_ma21RDA_bibl.rul".

Käyttö
--------
Konversio ajetaan USEMARCON-ohjelmalla. Ohjelman voit ladata osoitteesta https://www.kiwi.fi/display/Marc21/USEMARCON. Lähdekoodi on saatavissa USEMARCONin GitHub-sivuilta: https://github.com/NatLibFi/usemarcon.

Kopioi konversiopaketti päätteellesi esimerkiksi "Download ZIP" -painikkeesta. Pura paketti haluamaasi sijaintiin esimerkiksi C:\Usemarcon\ -hakemiston alle. USEMARCONilla käytettävät varsinaiset konversiotiedostot ovat ma21RDA_bibliografiset.ini (bibliografisten tietueiden konversio) ja ma21RDA_auktoriteetit.ini.

Palaute
-------
marc-posti (at) helsinki.fi

===========

Description
---------
A USEMARCON rule for converting bibliographic records from MARC 21 (ISBD) to MARC 21 (RDA). Tailored for Finnish scientific libraries.
