library(tidyverse)
library(readxl)
library(writexl)

# ==============================================================================
# 1. LLEGIM LES DADES
# ==============================================================================
path_fitxer <- "Rec23_sensevcat.xlsx" 

curses <- read_xlsx(path = path_fitxer, sheet = 1)
punts_scale <- read_xlsx(path = path_fitxer, sheet = 2)
corredors <- read_xlsx(path = path_fitxer, sheet = 4)

# Comprovació de seguretat
if (!"itt_km" %in% names(curses)) curses$itt_km <- 0

# PREPARACIÓ DELS PUNTS MÀXIMS
punts_max <- punts_scale %>%
  filter(pos == 1) %>%
  pivot_longer(cols = -pos, names_to = "pointscale", values_to = "max_punts") %>%
  select(pointscale, max_punts) %>%
  mutate(pointscale = str_trim(as.character(pointscale)))

curses <- curses %>% 
  mutate(pointscale = str_trim(as.character(pointscale))) %>%
  left_join(punts_max, by = "pointscale")

curses$indstartlist <- as.numeric(curses$indstartlist)
mitjana_startlist <- mean(curses$indstartlist, na.rm = TRUE)
if (is.na(mitjana_startlist) || is.nan(mitjana_startlist)) mitjana_startlist <- 1 

# ==============================================================================
# 2. MODEL PREDICTIU INTEGRAT: MULTIVARIABLE + SUPERVIVÈNCIA + ASÍMPTOTA K
# ==============================================================================
resultats_base <- crossing(id_corredor = corredors$id, id_cursa = curses$id) %>%
  left_join(corredors, by = c("id_corredor" = "id")) %>%
  left_join(curses, by = c("id_cursa" = "id")) %>%
  mutate(
    # A) NETEJA DE VALORS BUITS
    itt_km = as.numeric(replace_na(itt_km, 0)),
    dist = as.numeric(replace_na(dist, 160)), 
    ele = as.numeric(replace_na(ele, 0)), 
    dnxkm = as.numeric(replace_na(dnxkm, 0)),
    profscore = as.numeric(replace_na(profscore, 0)), 
    psscore25K = as.numeric(replace_na(psscore25K, 0)),
    lastkm = as.numeric(replace_na(lastkm, 0)), 
    ports = as.numeric(replace_na(ports, 0)),
    distultport = as.numeric(replace_na(distultport, 0)), 
    pave = as.numeric(replace_na(pave, 0)),
    prof = replace_na(prof, "none"),
    indstartlist = as.numeric(replace_na(indstartlist, mitjana_startlist)),
    max_punts = as.numeric(replace_na(max_punts, 0)),
    
    PL = as.numeric(replace_na(PL, 60)), MO = as.numeric(replace_na(MO, 60)),
    PAV = as.numeric(replace_na(PAV, 60)), SP = as.numeric(replace_na(SP, 60)),
    ACC = as.numeric(replace_na(ACC, 60)), RES = as.numeric(replace_na(RES, 60)),
    END = as.numeric(replace_na(END, 60)), HILLS = as.numeric(replace_na(HILLS, 60))
  ) %>%
  mutate(
    # =====================================================================
    # B) CÀLCUL DE PESOS (AMB SILENCIADOR DE HILLS A ESPRINTS)
    # =====================================================================
    w_raw_END = (dist / 100)^1.5,
    w_raw_RES = (ele / 1000)^1.5 + (profscore / 40),
    
    es_mo = profscore > 170 | prof == "mon",
    es_HILLS = !es_mo & (profscore > 50 | prof == "pch"),
    
    w_raw_MO = if_else(es_mo, (dnxkm / 4)^2 + (ports / 2) + (ele/1000)^1.5, 0),
    
    # MODIFICACIÓ 3: Càlcul de HILLS i aplicació del silenciador del 30% si és Esprint
    w_raw_HILLS_brut = if_else(es_HILLS, (profscore / 15)^1.5 + if_else(prof == "pch", 15, 0), 0),
    w_raw_HILLS = if_else(prof == "spr", w_raw_HILLS_brut * 0.3, w_raw_HILLS_brut),
    
    w_raw_ACC = (psscore25K / 15)^1.5 + (lastkm / 1.5)^2 + if_else(prof == "pch", 15, 0),
    w_raw_PAV = (pave)^2.5,
    w_raw_SP = if_else(prof == "spr", 45, 0) + if_else(distultport > 30 & profscore < 100, 10, 0),
    w_raw_PL = if_else(dnxkm < 7, 15, 0) + if_else(ele < 1500, 10, 0),
    
    suma_w_dia = w_raw_END + w_raw_RES + w_raw_MO + w_raw_HILLS + w_raw_ACC + w_raw_PAV + w_raw_SP + w_raw_PL,
    suma_w_dia = if_else(suma_w_dia == 0, 1, suma_w_dia),
    
    # =====================================================================
    # C) EFECTIVITAT BÀSICA D'ATRIBUTS (AMB CORBA ESPRINT EXPONENCIAL)
    # =====================================================================
    PAVefectiu = if_else(pave > 5 & PAV < 77, PAV - (77 - PAV) * 2, PAV),
    MOefectiu = if_else(ele > 2500 & MO < 76, MO - (76 - MO) * 1.5, MO),
    
    SP_pre = if_else(ele > 2500 & MO < 71, 0, SP),
    
    # MODIFICACIÓ 1: Creixement exponencial natural per distanciar líders de llançadors
    SPefectiu = if_else(w_raw_SP > 0 & SP_pre >= 70, 70 + (SP_pre - 70)^1.2, 
                        if_else(w_raw_SP > 0 & SP_pre < 70, SP_pre - (70 - SP_pre) * 1.5, SP_pre)),
    
    # =====================================================================
    # D) ACCELERACIÓ (RESTABLIDA COM ABANS)
    # =====================================================================
    ACC_pre_efectiu = if_else(es_mo & MO < 73, ACC - (73 - MO) * 1.5, 
                              if_else(es_HILLS & HILLS < 73, ACC - (73 - HILLS) * 1.5, ACC)),
    ACCefectiu = if_else(w_raw_ACC > 10 & ACC_pre_efectiu < 76, ACC_pre_efectiu - (76 - ACC_pre_efectiu) * 1.2, ACC_pre_efectiu),
    
    # =====================================================================
    # E) ÍNDEX D'APTITUD BRUT DEL DIA
    # =====================================================================
    S_dia_brut = (PL * (w_raw_PL / suma_w_dia)) + 
      (MOefectiu * (w_raw_MO / suma_w_dia)) + 
      (HILLS * (w_raw_HILLS / suma_w_dia)) + 
      (PAVefectiu * (w_raw_PAV / suma_w_dia)) + 
      (SPefectiu * (w_raw_SP / suma_w_dia)) + 
      (ACCefectiu * (w_raw_ACC / suma_w_dia)) + 
      (RES * (w_raw_RES / suma_w_dia)) + 
      (END * (w_raw_END / suma_w_dia)),
    
    # =====================================================================
    # F) TALL DE GRAVETAT (RESTABLIT COM ABANS)
    # =====================================================================
    Factor_Supervivencia = if_else((es_mo | ele > 3000) & MO < 71, 0.90, 
                                   if_else(es_HILLS & HILLS < 70, 0.90, 1.0)),
    S_dia = S_dia_brut * Factor_Supervivencia,
    
    # =====================================================================
    # G) CALIBRATGE ESTADÍSTIC
    # =====================================================================
    ajust_startlist = sqrt(indstartlist / mitjana_startlist),
    U_dinamic = 78.5 * (0.92 + 0.08 * ajust_startlist),
    K_dinamic = pmin(0.90, 0.20 + 0.70 * ajust_startlist),
    beta = 0.35, 
    
    prob_dia = K_dinamic / (1 + exp(-beta * (S_dia - U_dinamic))),
    Punts_Totals = round(max_punts * prob_dia, 2)
  )

# ==============================================================================
# 3. EXPORTACIÓ
# ==============================================================================
matriu_prob <- resultats_base %>%
  select(corredor = id_corredor, cursa = nom.y, prob_dia) %>%
  pivot_wider(names_from = cursa, values_from = prob_dia)

matriu_punts <- resultats_base %>%
  select(corredor = id_corredor, cursa = nom.y, Punts_Totals) %>%
  pivot_wider(names_from = cursa, values_from = Punts_Totals)

write_xlsx(matriu_prob, "Matriu_Probabilitats.xlsx")
write_xlsx(matriu_punts, "Matriu_Punts_Esperats.xlsx")

cat(">> PROCÉS FINALITZAT AMB ÈXIT!\n")


head(matriu_punts)
matriu_punts[1:4, 1:4]
