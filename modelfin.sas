*llegim els documents de punts i d'informació de les curses.;
proc import datafile="C:\Users\Esteve\Documents\UB\4T\TFG\Matriu_Punts_Esperats.xlsx" out=dades_punts dbms=xlsx replace; getnames=yes; run;
proc import datafile="C:\Users\Esteve\Documents\UB\4T\TFG\infocursa.xlsx" out=infocursa_raw dbms=xlsx replace; getnames=yes; run;

data infocursa_neta; set infocursa_raw; nom_cursa_sas = translate(trim(nom), '__', '- '); run;

proc contents data=dades_punts out=Noms_Columnes(keep=NAME) noprint; run; 
proc sql noprint; select quote(trim(NAME)) into :llista_curses separated by ', ' from Noms_Columnes where upcase(NAME) ne 'CORREDOR' and upcase(NAME) ne 'ID'; quit;

proc optmodel; 
    * 1. CONJUNTS I PARÀMETRES;
    set <str> CORREDORS; 
    set <str> CURSES = {&llista_curses.};
    num Punts {CORREDORS, CURSES}; 
    num Data_Cursa {CURSES}; 
    num placesmin {CURSES} init 7; 
    num placesmax {CURSES}; 
    num eswt {CURSES} init 1;
    str regio {CURSES};      

    *conjunt de rols entre 1 i 8;
    set ROLS = 1..8; 
    
    *decaiment de punts en funcio del rol;
    num Factor_Rol {r in ROLS} = 1 / (2**(r-1)); 

    *LECTURA DE DADES;
    read data dades_punts into CORREDORS=[corredor] {j in CURSES} <Punts[corredor, j]=col(j)>;
    read data infocursa_neta into [nom_cursa_sas] Data_Cursa=data regio=regio placesmin=placesmin placesmax=placesmax eswt=WT;

    *2.VARIABLES DE DECISIÓ;
    var Assignacio {CORREDORS, CURSES} binary; 
    var participacioeq {CURSES} binary;
    var Es_Top20 {CORREDORS} binary;
    var Assignacio_Top20 {CORREDORS, CURSES} binary;
    var Assignacio_Rol {CORREDORS, CURSES, ROLS} binary;

    *3.FUNCIÓ OBJECTIU;
    max Punts_Totals = sum {i in CORREDORS, j in CURSES, r in ROLS} 
                       (Punts[i,j] * Factor_Rol[r] * Assignacio_Rol[i,j,r]);

    * 4.RESTRICCIONS ;
    *Linealització Top20 ;
    con lin1 {i in CORREDORS, j in CURSES}: Assignacio_Top20[i,j] <= Assignacio[i,j];
    con lin2 {i in CORREDORS, j in CURSES}: Assignacio_Top20[i,j] <= Es_Top20[i];
    con lin3 {i in CORREDORS, j in CURSES}: Assignacio_Top20[i,j] >= Assignacio[i,j] + Es_Top20[i] - 1;

    *RESTRICCIONS DE ROL ;
    con un_rol_per_corredor_cursa {i in CORREDORS, j in CURSES}:
        sum {r in ROLS} Assignacio_Rol[i,j,r] = Assignacio_Top20[i,j];
        
    con max_un_corredor_per_rol {j in CURSES, r in ROLS}:
        sum {i in CORREDORS} Assignacio_Rol[i,j,r] <= 1;

    * Resta de restriccions operatives ;
    con quota_top20: sum {i in CORREDORS} Es_Top20[i] <= 20;
    con limit_pressupost_equip: sum {i in CORREDORS, j in CURSES} Assignacio[i,j] <= 85; *simulacio pressupostaria de l'equip;
    
    con maxcursescorr {i in CORREDORS}: sum {j in CURSES} Assignacio[i,j] <= 3;*Restriccio de fatiga;
    
    con compromis_institucional {j in CURSES: eswt[j]=1 or regio[j]="spa"}: participacioeq[j] = 1;
    con mincorcursa {j in CURSES}: sum {i in CORREDORS} Assignacio[i,j] >= placesmin[j] * participacioeq[j];
    con maxcorcursa {j in CURSES}: sum {i in CORREDORS} Assignacio[i,j] <= placesmax[j] * participacioeq[j];
    con noubiq {i in CORREDORS, j1 in CURSES, j2 in CURSES: j1 < j2 and Data_Cursa[j1] = Data_Cursa[j2] and Data_Cursa[j1] ^= .}: Assignacio[i,j1] + Assignacio[i,j2] <= 1;
    con viatge_interregional {i in CORREDORS, j1 in CURSES, j2 in CURSES: j1 < j2 and abs(Data_Cursa[j1] - Data_Cursa[j2]) = 1 and regio[j1] ne regio[j2] and Data_Cursa[j1] ^= . and Data_Cursa[j2] ^= .}: Assignacio[i,j1] + Assignacio[i,j2] <= 1;

    /* con Lesio_Mas: sum {j in CURSES} Assignacio['emas', j] = 0; */

    solve with milp; 
    
    /* =========================================================================
       EXPORTACIÓ NETA DE RESULTATS
       ========================================================================= */
    create data Taula_Alineacions from [Corredor Cursa]={i in CORREDORS, j in CURSES: Assignacio[i,j] = 1} 
        Es_Top20=(Es_Top20[i])
        Rol_Assignat=(sum{r in ROLS} r * Assignacio_Rol[i,j,r])
        Factor=(sum{r in ROLS} Factor_Rol[r] * Assignacio_Rol[i,j,r])
        Punts_Purs=(Punts[i,j])
        Punts_Nets=(sum{r in ROLS} Punts[i,j] * Factor_Rol[r] * Assignacio_Rol[i,j,r]);
    
    create data Estat_Curses from [Cursa]={j in CURSES} 
        Participa=(participacioeq[j]) 
        Places_Fisiques_Ocupades=(sum{i in CORREDORS} Assignacio[i,j]) 
        Places_Que_Puntuen=(sum{i in CORREDORS} Assignacio_Top20[i,j])
        Punts_Totals_Cursa=(sum{i in CORREDORS, r in ROLS} Punts[i,j] * Factor_Rol[r] * Assignacio_Rol[i,j,r]);

    /* Exportació de dades per a la Taula 6 i 7 (Quota UCI i Fatiga) */
    create data Estat_Plantilla from [Corredor]={i in CORREDORS} 
        Es_Top20_Final=(Es_Top20[i])
        Total_Curses=(sum{j in CURSES} Assignacio[i,j])
        Punts_Aportats=(sum{j in CURSES, r in ROLS} Punts[i,j] * Factor_Rol[r] * Assignacio_Rol[i,j,r]);
		create data Estat_Plantilla from [Corredor]={i in CORREDORS} 
        Es_Top20_Final=(Es_Top20[i])
        Total_Curses=(sum{j in CURSES} Assignacio[i,j])
        Punts_Aportats=(sum{j in CURSES, r in ROLS} Punts[i,j] * Factor_Rol[r] * Assignacio_Rol[i,j,r])
        /* Calculem els punts purs que farien si haguessin tingut rol de líder, però que no sumen per a l'equip */
        Punts_No_Sumats=(sum{j in CURSES} Punts[i,j] * Assignacio[i,j] * (1 - Es_Top20[i]));

quit;

/* =========================================================================
   IMPRESSIÓ DE TAULES PER AL TFG
   ========================================================================= */

/* 1. TAULA: Curses a les que ES VA */
title "1. Curses Confirmades (L'equip hi participa)";
proc print data=Estat_Curses noobs label;
    where Participa > 0.5;
    var Cursa Places_Fisiques_Ocupades Places_Que_Puntuen Punts_Totals_Cursa;
    sum Punts_Totals_Cursa;
run;
title;

/* 2. TAULA: Curses a les que NO ES VA (Descartades) */
title "2. Curses Descartades (Cost d'oportunitat)";
proc print data=Estat_Curses noobs label;
    where Participa = 0.5;
    var Cursa Punts_Totals_Cursa;
run;
title;

/* 3. TAULA: Alineació i rols per a Il Lombardia */
title "3. Alineació Tàctica: Il Lombardia";
proc sort data=Taula_Alineacions out=Lombardia_Ord; 
    by descending Punts_Nets; 
run;
proc print data=Lombardia_Ord noobs label;
    where Cursa = "Il_Lombardia";
    var Corredor Es_Top20 Rol_Assignat Factor Punts_Purs Punts_Nets;
    sum Punts_Nets;
run;
title;

/* 4. TAULA: Alineació i rols per a Paris-Roubaix */
title "4. Alineació Tàctica: Paris-Roubaix";
proc sort data=Taula_Alineacions out=Roubaix_Ord; 
    by descending Punts_Nets; 
run;
proc print data=Roubaix_Ord noobs label;
    where Cursa = "Paris_Roubaix";
    var Corredor Es_Top20 Rol_Assignat Factor Punts_Purs Punts_Nets;
    sum Punts_Nets; 
run;
title;

/* 5. TAULA: Calendaris individuals (Mas, Gaviria, Cortina) */
title "5. Planificació Individual: E. Mas, F. Gaviria, I. Garcia Cortina";
proc sort data=Taula_Alineacions out=Indiv_Ord; 
    by Corredor Cursa; 
run;
proc print data=Indiv_Ord noobs label;
    where Corredor in ("emas", "fgaviria", "igarciacortina");
    var Corredor Cursa Es_Top20 Rol_Assignat Factor Punts_Purs Punts_Nets;
    sum Punts_Nets;
run;
title;

/* 6. TAULA: Anàlisi de la Quota dels 20 (Corredors actius vs Gregaris Purs) */
title "6. Quota UCI: Corredors actius (Top 20) vs Gregaris Purs sacrificats";
proc sort data=Estat_Plantilla out=Plantilla_Ord; 
    by descending Es_Top20_Final descending Punts_Aportats; 
run;
proc print data=Plantilla_Ord noobs label;
    var Corredor Es_Top20_Final Total_Curses Punts_Aportats;
run;
title;

title "7. Corredors Fora del Top 20: Dies de competició i Punts Ocults";
proc sort data=Estat_Plantilla out=Fatiga_Ord; 
    by descending Total_Curses; 
run;
proc print data=Fatiga_Ord noobs label;
    where Es_Top20_Final = 0 and Total_Curses > 0;
    var Corredor Total_Curses Punts_No_Sumats;
    sum Punts_No_Sumats;
run;
title;

/* Exportem les taules per fer els gràfics a R o Excel */
proc export data=Taula_Alineacions 
    outfile="C:\Users\Esteve\Documents\UB\4T\TFG\Resultats_Alineacions.csv" 
    dbms=csv replace; 
run;

proc export data=Estat_Plantilla 
    outfile="C:\Users\Esteve\Documents\UB\4T\TFG\Resultats_Plantilla.csv" 
    dbms=csv replace; 
run;
