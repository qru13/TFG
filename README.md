<div align="center">
  <h1>Optimització d'un Calendari Ciclista</h1>
  <p><strong>Treball de Final de Grau (TFG) - Grau en Estadística (UB-UPC)</strong></p>
</div>

Aquest repositori conté el codi, els models i l'anàlisi desenvolupats per al meu Treball de Final de Grau, on construeixo un sistema de suport a la decisió per a un equip ciclista professional (Movistar Team). L'objectiu és aplicar la **Ciència de Dades (Data Science)** i la **Investigació Operativa** per maximitzar el rendiment de l'equip.

---

## 🎯 El Problema: La lluita pels punts UCI

L'any 2019, la Unió Ciclista Internacional (UCI) va canviar el sistema de llicències, passant a valorar estrictament els mèrits esportius a través dels punts UCI[cite: 1]. Mantenir la llicència *WorldTour* (la primera divisió del ciclisme) és vital, ja que garanteix la participació en proves com el Tour de France[cite: 1]. 

Aquest sistema té una norma clau que complica la planificació: **només computen per a l'equip els punts dels seus 20 millors corredors**[cite: 1]. Per tant, assignar corredors a les curses requereix tenir en compte:
*   Les capacitats de cada ciclista (escalador, esprintador, etc.)[cite: 1].
*   La fatiga i els dies de competició[cite: 1].
*   El paper o "rol" de cada corredor dins la cursa per evitar prendre's punts entre ells[cite: 1].

---

## 🧠 Metodologia i Desenvolupament

Per donar resposta a aquest repte, el projecte s'ha dividit en tres grans etapes:

### 1. Tractament de Dades i Índex d'Aptitud (R)
*   S'han creuat les dades d'atributs físics del videojoc **Pro Cycling Manager 23** amb dades orogràfiques reals del portal **ProCyclingStats** (desnivell, quilometratge, pendents finals)[cite: 1].
*   S'ha creat un **Índex d'Aptitud** no lineal i dinàmic per puntuar cada corredor segons la cursa[cite: 1]. 

### 2. Esperança Matemàtica de Punts
*   Per transformar l'Índex d'Aptitud en probabilitat real d'èxit, s'ha utilitzat un **Model Logístic de Verhulst**[cite: 1].
*   Aquest model ajusta l'exigència de cada prova per projectar els punts esperats de cada corredor, tenint en compte la incertesa pròpia del ciclisme[cite: 1].

### 3. Model d'Optimització MILP (SAS)
Finalment, la matriu de punts alimenta un algorisme de **Programació Lineal Entera Mixta (MILP)** programat en SAS (PROC OPTMODEL)[cite: 1]. Aquest model pren la decisió final respectant restriccions del món real:
*   **Gestió de la Quota UCI:** Identifica quins 20 corredors sumaran punts i relega la resta a tasques de suport[cite: 1].
*   **Fatiga i Logística:** Evita assignar corredors a curses simultànies o viatges impossibles en dies consecutius[cite: 1].
*   **Jerarquia d'Equip:** Introdueix un factor de decaïment geomètric de punts segons si el corredor actua com a líder o com a gregari[cite: 1].

---

## 📊 Resultats Destacats

*   **Puntuació Òptima:** S'ha projectat una esperança màxima de **1.110,55 punts UCI**[cite: 1].
*   **Distribució de Pareto:** Les anàlisis han revelat que menys del 25% de la plantilla suporta més del 75% dels punts (Mas, Aranburu, Gaviria i Guerreiro)[cite: 1]. 
*   **Resiliència davant Lesions:** En simular la lesió del líder principal (Enric Mas), el model reconfigura l'equip automàticament per minimitzar la pèrdua de punts[cite: 1].

---

## 📂 Què hi ha en aquest repositori?
Aquí hi trobaràs tots els arxius del projecte (pots descarregar-los fent-hi clic):
*   `TFGdef1.1.pdf` - La memòria completa del Treball de Final de Grau.
*   Els scripts de programació en **R** (neteja i modelització) i **SAS** (optimització MILP).
*   Els arxius de dades originals.
*   Els gràfics de resultats (Anàlisi PCA, Distribució de Pareto).

---

## ✍️ Autor
**Esteve Corominas Luchanok**
*Grau en Estadística (Universitat de Barcelona - Universitat Politècnica de Catalunya)*

*Treball de Final de Grau (Convocatòria Juny 2026) dirigit per la Dra. Julia de Frutos Cachorro[cite: 1].*
