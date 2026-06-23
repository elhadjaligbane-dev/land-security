********************************************************************************
* TITLE: Secure Land Rights, Gender, and Agricultural Technical Efficiency in Côte d'Ivoire
* AUTHOR: El Hadj Ali Gbané (CIRES)
* DATASET: Harmonized Survey on Household Living Conditions (EHCVM 2021)
* NATIONAL STATISTICAL BODY: National Agency for Statistics (ANStat, formerly INS)
* PURPOSE: Replication Do-file (Data Consolidation, IV-2SLS, SFA, and Oaxaca-Blinder)
********************************************************************************

clear all
macro drop _all
set more off

* ==============================================================================
* 0. PATH SETTING & DIRECTORY ANONYMIZATION
* ==============================================================================
* INSTRUCTION: Change the path below to your local directory before executing.
global root "YOUR_WORKING_DIRECTORY_PATH_HERE" 

global dir_menag "$root/Fichiers_Menage_Individus"
global dir_pond  "$root/Fichiers_Ponderation" 
global dir_pauv  "$root/Fichiers_Traitement_AnalysePauvrete"

* ==============================================================================
* 1. DATA PREPARATION & CONSOLIDATION
* ==============================================================================

*** A. Extraction of Plot Manager Demographics (Module s01)
use "$dir_menag/s01_me_CIV2021.dta", clear
gen hhid = (grappe * 1000) + menage // Strict unique household identifier
gen femme_ind = (s01q01 == 2) if !missing(s01q01)
gen age_ind = 2021 - s01q03c
replace age_ind = . if s01q03c > 2021
rename s01q00a s16aq03 

keep hhid s16aq03 femme_ind age_ind
duplicates drop hhid s16aq03, force
save "$dir_menag/temp_individus.dta", replace

*** B. Agricultural Production and Harvest Aggregation (Module s16d)
use "$dir_menag/s16d_me_CIV2021.dta", clear
gen hhid = (grappe * 1000) + menage
collapse (sum) prod_totale = s16dq05c, by(hhid)
label var prod_totale "Total household crop production (kg)"
save "$dir_menag/temp_prod.dta", replace

*** C. Agricultural Input Adoption and Quantity (Module s16b)
use "$dir_menag/s16b_me_CIV2021.dta", clear
gen hhid = (grappe * 1000) + menage

* Identification based on official survey nomenclature
gen code_engrais = (s16bq01 >= 3 & s16bq01 <= 6) // Inorganic Fertilizer
gen code_semences = (s16bq01 >= 11 & s16bq01 <= 20) | (s16bq01 >= 24 & s16bq01 <= 28) // Improved Seeds

gen usage_engrais = (code_engrais == 1 & s16bq02 == 1)
gen qte_engrais_ligne = s16bq03a if usage_engrais == 1
replace qte_engrais_ligne = 0 if usage_engrais == 0
gen usage_semences = (code_semences == 1 & s16bq02 == 1)

collapse (max) adopte_engrais = usage_engrais adopte_semences = usage_semences ///
         (sum) qte_engrais = qte_engrais_ligne, by(hhid)
save "$dir_menag/temp_intrants.dta", replace

*** D. Survey Weights and Welfare Adjustments
preserve
    use "$dir_pond/ehcvm_ponderations_CIV2021.dta", clear
    gen hhid = (grappe * 1000) + menage
    duplicates drop hhid, force
    save "$dir_pond/temp_pond.dta", replace
restore

preserve
    use "$dir_pauv/ehcvm_welfare_CIV2021.dta", clear
    capture drop hhid
    gen hhid = (grappe * 1000) + menage
    duplicates drop hhid, force
    save "$dir_pauv/temp_welfare.dta", replace
restore

*** E. Main Land Module Assembly & Master Merge (Module s16a)
use "$dir_menag/s16a_me_CIV2021.dta", clear
gen hhid = (grappe * 1000) + menage

gen droit_securise = (s16aq08 == 1 | s16aq08 == 2) if !missing(s16aq08)
gen acquise_heritage = (s16aq06 == 2) if !missing(s16aq06)

collapse (sum) superficie = s16aq05 (max) titre_securise = droit_securise ///
         parcelle_heritee = acquise_heritage s16aq03, by(hhid)

drop if missing(s16aq03) | s16aq03 <= 0

* Merging all structural blocks
merge 1:1 hhid using "$dir_menag/temp_prod.dta", keep(match master) nogenerate
merge 1:1 hhid using "$dir_menag/temp_intrants.dta", keep(match master) nogenerate
merge m:1 hhid s16aq03 using "$dir_menag/temp_individus.dta", keep(match master) nogenerate
merge m:1 hhid using "$dir_pond/temp_pond.dta", keep(match master) nogenerate
merge m:1 hhid using "$dir_pauv/temp_welfare.dta", keep(match master) nogenerate

* Post-merge cleaning
replace adopte_engrais = 0 if missing(adopte_engrais)
replace adopte_semences = 0 if missing(adopte_semences)
replace qte_engrais = 0 if missing(qte_engrais)
replace prod_totale = 0 if missing(prod_totale)

gen femme_gestionnaire = femme_ind
gen age_gestionnaire = age_ind
drop femme_ind age_ind

* Exclude invalid or zero surface observations
drop if superficie <= 0 | missing(superficie)

* Generate key variables & logs
gen rendement = prod_totale / superficie
gen ln_rendement = log(rendement + 1)
gen ln_superficie = log(superficie + 1)
gen age_carre = age_gestionnaire^2

label var rendement "Agricultural Yield (kg/ha)"
label var ln_rendement "Log of Agricultural Yield"
label var ln_superficie "Log of Cultivated Surface Area"
label var titre_securise "Plot land tenure status is formally secure"
label var parcelle_heritee "Plot was inherited through customary channels"

save "$root/base_complete_papier_agriculture.dta", replace

* Erase working temporary files
capture erase "$dir_menag/temp_prod.dta"
capture erase "$dir_menag/temp_intrants.dta"
capture erase "$dir_menag/temp_individus.dta"
capture erase "$dir_pond/temp_pond.dta"
capture erase "$dir_pauv/temp_welfare.dta"


* ==============================================================================
* 2. EMPIRICAL ESTIMATIONS & PERFORMANCE TESTING
* ==============================================================================
use "$root/base_complete_papier_agriculture.dta", clear
eststo clear

*** 2.1. TABLE 1: DESCRIPTIVE STATISTICS & GENDER DIFFERENCE TESTS
global vars_analyse rendement superficie titre_securise adopte_engrais adopte_semences qte_engrais age_gestionnaire

eststo Hommes: estpost summarize $vars_analyse if femme_gestionnaire == 0
eststo Femmes: estpost summarize $vars_analyse if femme_gestionnaire == 1
eststo Test: estpost ttest $vars_analyse, by(femme_gestionnaire)

* Display Table 1 in Stata Console
esttab Hommes Femmes Test, cells("mean(pattern(1 1 0)) b(pattern(0 0 1) star)") ///
    label nodepvars nonumber replace ///
    mtitles("Men" "Women" "Difference") ///
    star(* 0.10 ** 0.05 *** 0.01)


*** 2.2. TABLE 3 (Column 1): INSTRUMENTAL VARIABLES APPROACH (IV-2SLS)
* Analysis sample restricted strictly to active and productive farms
drop if rendement <= 0 | missing(rendement)

ivregress 2sls ln_rendement femme_gestionnaire adopte_engrais adopte_semences ///
    ln_superficie age_gestionnaire age_carre heduc hnation hhsize pcexp ///
    (titre_securise = parcelle_heritee), vce(robust)
eststo model_iv

* Post-estimation Identification & Specification Diagnostics
estat firststage   // Test of Instrument Strength (F-statistic)
estat endogenous   // Durbin-Wu-Hausman Test for Land Rights Endogeneity


*** 2.3. TABLE 3 (Column 2): STOCHASTIC FRONTIER ANALYSIS (SFA Model)
* Structural parameters follow Battese & Coelli (1995) heteroscedastic formulation
frontier ln_rendement adopte_engrais adopte_semences ln_superficie, ///
    uhet(femme_gestionnaire titre_securise age_gestionnaire heduc hhsize pcexp) vce(robust)
eststo model_sfa

* Predict Individual Technical Efficiency (TE) Scores
capture drop score_efficacite
predict score_efficacite, te
label var score_efficacite "Technical Efficiency Score [0-1]"

* Two-sample t-test on predicted technical efficiency scores by gender
ttest score_efficacite, by(femme_gestionnaire)


*** 2.4. APPENDIX A: ROBUSTNESS CHECK — OAXACA-BLINDER DECOMPOSITION
* Baseline weight(1) applies male coefficients as reference structure
capture ssc install oaxaca
oaxaca ln_rendement adopte_engrais adopte_semences ln_superficie age_gestionnaire ///
    age_carre heduc hnation hhsize pcexp, by(femme_gestionnaire) weight(1) vce(robust)
eststo model_oaxaca


* ==============================================================================
* 3. PROFESSIONAL EXPORTATION OF OUTPUTS
* ==============================================================================
* Export consolidated structural econometric estimates to MS Word RTF format
esttab model_iv model_sfa using "$root/Tableau_Estimations_Final.rtf", ///
    replace b(3) se(3) star(* 0.10 ** 0.05 *** 0.01) label ///
    title("Table 3: Comprehensive Econometric Estimates of Land Security and Gender on Yield") ///
    mtitle("IV-2SLS" "Frontier (SFA)") ///
    onecell nogaps compress ///
    addnotes("Notes: Robust standard errors in parentheses. *** p<0.01, ** p<0.05, * p<0.10." ///
             "Model (1) corrects for the endogeneity of land tenure using customary inheritance as an instrument." ///
             "Model (2) models technical inefficiency using the heteroscedastic Battese & Coelli (1995) specification.")

di "SUCCESS: All models estimated, verified, and exported cleanly!"