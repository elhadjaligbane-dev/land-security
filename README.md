# Secure Land Rights, Gender, and Agricultural Technical Efficiency in Côte d'Ivoire

Replication material for the paper: *Secure Land Rights, Gender, and Agricultural Technical Efficiency in Côte d'Ivoire: A Combined Oaxaca-Blinder, Instrumental Variables, and Stochastic Frontier Approach*.

## Data Source
The analysis uses data from the **Harmonized Survey on Household Living Conditions (EHCVM 2021)**, compiled by the **National Agency for Statistics (ANStat)** of Côte d'Ivoire. Due to data privacy regulations, raw datasets must be requested directly from Program for the Harmonization and Modernization of Surveys on Household Living Conditions in the Member States of the WAEMU. This can be done via the following link: https://phmecv.uemoa.int/nada/index.php/auth/login/?destination=catalog/61/get-microdata   

## Contents
- `replication_script.do`: The cleaned and consolidated Stata Do-file containing data management, descriptive statistics (Table 1), IV-2SLS models (Table 3), Stochastic Frontier Analysis (Table 3), and Oaxaca-Blinder decomposition (Table 2).

## Instructions for Replication
1. Download the required raw modules (`s01`, `s16a`, `s16b`, `s16d`, welfare, and weights) from ANStat.
2. Open `replication_script.do` in Stata.
3. Modify the global macro path on line 13 to match your local directory:
   ```stata
   global root "YOUR_WORKING_DIRECTORY_PATH_HERE"
