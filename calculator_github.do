


*********************************************************************************************************** 
************ UI CALCULATOR FOR MONETARY OUTCOMES  ********************************************************* 
***********************************************************************************************************

cap prog drop CALCULATOR_MONETARY
program define CALCULATOR_MONETARY
    syntax, [hqe(varname) bpe(varname) state(varname) year(varname)  hqe2(varname) aww(varname) ///
           construction(varname) hours(varname)  lackwork(varname)  quit(varname)   deflated(int 0)]
		
	******************************
	** clean inputs 	**********
	******************************

	cap drop Predict_wba
	cap drop Predict_eligibility_*
	
	*** additional inputs based on initial inputs:
	tempvar bpe_hqe_ratio
	gen `bpe_hqe_ratio' = `bpe'/`hqe'
	replace `bpe_hqe_ratio'=-1 if `hqe'==0
	
	tempvar bpe_minus_hqe
	gen `bpe_minus_hqe' = `bpe'-`hqe'


	******************************
	** call UI Rules 	**********
	******************************
	
	cap drop matching_state
	cap drop matching_year
	gen matching_state=`state'
	gen matching_year=`year'
	merge m:1 matching_state matching_year using https://github.com/pithymaxim/UIcalculator/raw/refs/heads/main/All_rules.dta, nogen keep(master match) keepusing(MON* WBA* SEP* cpi)

	** Apply deflated or not deflated rule parameters**
	
	if (`deflated') foreach var in WBA_intercept_HQE WBA_max_value WBA_min_value MON_Min_HQE_1 MON_Min_HQE_2 MON_Min_BPE_1 MON_Min_BPE_2 MON_Min_notHQE_1  	MON_Min_2HQE_1 MON_Min_2HQE_2   {
	replace `var' = `var' / cpi
	}
 
	**************************************************************************************************************
	*********** Predict wba
	**************************************************************************************************************

	**method1:2HQ
	gen Predict_wba=  min(WBA_max_value, WBA_linear_term_2HQE * `hqe2') if  WBA_calc_method_num==1 & !missing(`hqe2')
	**method2:AWW
	replace Predict_wba=  min(WBA_max_value, WBA_linear_term_AWW * `aww') if  WBA_calc_method_num==2 & !missing( `aww')
	**Method3:BPW
	replace 	Predict_wba = min(WBA_max_value, WBA_linear_term_BPE * `bpe') if WBA_calc_method_num==3 & !missing( `bpe')
	**Method4:BPW 2HQ
	replace Predict_wba=  min(WBA_max_value, min( WBA_linear_term_2HQE * `hqe2' , WBA_linear_term_BPE * `bpe')) if  WBA_calc_method_num==4 & WBA_which_method_num==3 & !missing(`hqe2') & !missing(`bpe')
	replace Predict_wba=  min(WBA_max_value, max( WBA_linear_term_2HQE * `hqe2', WBA_linear_term_BPE * `bpe')) if  WBA_calc_method_num==4 & WBA_which_method_num==2 & !missing(`hqe2') & !missing(`bpe')
	**Method5:HQW
	replace     Predict_wba = min(WBA_max_value, WBA_intercept_HQE + (WBA_linear_term_HQE * `hqe')) if WBA_calc_method_num==5 & !missing(`hqe')
	**Method6:HQW 2HQ
	replace Predict_wba=  min(WBA_max_value, min(WBA_intercept_HQE + (WBA_linear_term_HQE * `hqe') ,   WBA_linear_term_2HQE * `hqe2')) if  WBA_calc_method_num==6 & WBA_which_method_num==3 & !missing(`hqe2') & !missing(`hqe')
	replace Predict_wba=  min(WBA_max_value, max(WBA_intercept_HQE + (WBA_linear_term_HQE * `hqe') ,  WBA_linear_term_2HQE * `hqe2')) if  WBA_calc_method_num==6 & WBA_which_method_num==2 & !missing(`hqe2') & !missing(`hqe')
	replace Predict_wba= min(WBA_max_value, WBA_linear_term_2HQE * `hqe2')  if  WBA_calc_method_num==6 & WBA_which_method_num==1 & `construction' !=1 & !missing(`hqe2') & !missing(`hqe')
	replace Predict_wba= min(WBA_max_value, WBA_intercept_HQE + (WBA_linear_term_HQE * `hqe') )  if  WBA_calc_method_num==6 & WBA_which_method_num==1 & `construction' ==1 & !missing(`hqe2') & !missing(`hqe')
	**Method7:HQW BPW
	replace Predict_wba=  min(WBA_max_value, min(WBA_intercept_HQE + (WBA_linear_term_HQE * `hqe') , WBA_linear_term_BPE * `bpe')) if  WBA_calc_method_num==7 & WBA_which_method_num==3 & !missing(`bpe') & !missing(`hqe')
	replace Predict_wba=  min(WBA_max_value, max(WBA_intercept_HQE + (WBA_linear_term_HQE * `hqe') , WBA_linear_term_BPE * `bpe')) if  WBA_calc_method_num==7 & WBA_which_method_num==2 & !missing(`bpe') & !missing(`hqe')

	**** Create ratios of wba (inputs into the eligibility formulas):
	tempvar bpe_wba_ratio  hqe_wba_ratio nothqe_wba_ratio
	gen `bpe_wba_ratio' = `bpe'/Predict_wba
	gen `hqe_wba_ratio' = `hqe'/Predict_wba
	gen `nothqe_wba_ratio' = (`bpe'-`hqe')/Predict_wba

	**** Floor on wba:
	replace Predict_wba=WBA_min_value if Predict_wba<WBA_min_value

	label var Predict_wba "WBA (in $), predicted from calculator"

	**************************************************************************************************************
	*********** Predict monetary eligibility  
	**************************************************************************************************************


	*********** First method to determine monetary eligibility:
	 * Regressions are to test the impact on fit 
	local i=1
	gen Predict_eligibility_`i' = 1 if (!missing(`bpe') & !missing(MON_Min_BPE_`i')) |  (!missing(`hqe') & !missing(MON_Min_HQE_`i')) |(!missing(`hqe2') & !missing(MON_Min_2HQE_`i')) |(!missing(`bpe_minus_hqe') & !missing( MON_Two_quarters_`i')) |(!missing(`bpe_hqe_ratio') & !missing(MON_Min_BPE_HQE_ratio_`i')) |(!missing(`bpe_minus_hqe') & !missing( MON_Min_notHQE_`i')) |(!missing(`bpe_wba_ratio') & !missing(MON_Min_BPE_WBA_ratio_`i')) |(!missing(`hqe_wba_ratio') & !missing(MON_Min_HQE_WBA_ratio_`i')) |(!missing(`nothqe_wba_ratio') & !missing( MON_Min_notHQE_WBA_ratio_`i')) |(!missing(`hours') & !missing(MON_Min_hours_`i')) 
	
	* 1/Checking BPE 
	replace Predict_eligibility_`i' = 0 if (`bpe' < MON_Min_BPE_`i')  & !missing(MON_Min_BPE_`i') & !missing(`bpe')
		* 2/Checking HQE  
	replace Predict_eligibility_`i' = 0 if (`hqe' < MON_Min_HQE_`i')  & !missing(MON_Min_HQE_`i')  & !missing(`hqe')
	* 3/Checking 2hqe
	replace Predict_eligibility_`i' = 0 if (`hqe2' < MON_Min_2HQE_`i')    & !missing(MON_Min_2HQE_`i')  & !missing(`hqe2')
	* 4/Checking BPE minus HQE 
	replace Predict_eligibility_`i' = 0 if (`bpe_minus_hqe' <=0)  & MON_Two_quarters_`i' ==1 & !missing(`bpe_minus_hqe')
	* 5/Ratio BPE HQE 	
	replace Predict_eligibility_`i' = 0 if (`bpe_hqe_ratio' <=MON_Min_BPE_HQE_ratio_`i')  & !missing(MON_Min_BPE_HQE_ratio_`i') & !missing(`bpe_hqe_ratio')
	* 6/Not HQE
	replace Predict_eligibility_`i' = 0 if (`bpe_minus_hqe' < MON_Min_notHQE_`i')  & !missing(MON_Min_notHQE_`i') & !missing(`bpe_minus_hqe')
	* 7/Ratio WBA BPE
	replace Predict_eligibility_`i' = 0 if (`bpe_wba_ratio' < MON_Min_BPE_WBA_ratio_`i')  & !missing(MON_Min_BPE_WBA_ratio_`i') & !missing(`bpe_wba_ratio')
	* 8/Ratio WBA HQE
	replace Predict_eligibility_`i' = 0 if (`hqe_wba_ratio' < MON_Min_HQE_WBA_ratio_`i')  & !missing(MON_Min_HQE_WBA_ratio_`i') & !missing(`hqe_wba_ratio')
	* 9/Ratio WBA notHQE
	replace Predict_eligibility_`i' = 0 if (`nothqe_wba_ratio' < MON_Min_notHQE_WBA_ratio_`i')    & !missing(MON_Min_notHQE_WBA_ratio_`i') & !missing(`nothqe_wba_ratio')
	* 10/hours
	replace Predict_eligibility_`i' = 0 if (`hours' < MON_Min_hours_`i')    & !missing(MON_Min_hours_`i') & !missing(`hours')
			  	  
	*********** Second method to determine monetary eligibility:

	local i=2
	  
	gen Predict_eligibility_`i' = 1  if MON_Second_method==1 & (!missing(`bpe') & !missing(MON_Min_BPE_`i')) |  (!missing(`hqe') & !missing(MON_Min_HQE_`i')) |(!missing(`hqe2') & !missing(MON_Min_2HQE_`i')) |(!missing(`bpe_minus_hqe') & !missing( MON_Two_quarters_`i')) |(!missing(`bpe_hqe_ratio') & !missing(MON_Min_BPE_HQE_ratio_`i')) |(!missing(`bpe_minus_hqe') & !missing( MON_Min_notHQE_`i')) |(!missing(`bpe_wba_ratio') & !missing(MON_Min_BPE_WBA_ratio_`i')) |(!missing(`hqe_wba_ratio') & !missing(MON_Min_HQE_WBA_ratio_`i')) |(!missing(`nothqe_wba_ratio') & !missing( MON_Min_notHQE_WBA_ratio_`i')) |(!missing(`hours') & !missing(MON_Min_hours_`i')) 
 	
	* 1/Checking BPE 
	replace Predict_eligibility_`i' = 0 if (`bpe' < MON_Min_BPE_`i')  & !missing(MON_Min_BPE_`i') & !missing(`bpe')
		* 2/Checking HQE  
	replace Predict_eligibility_`i' = 0 if (`hqe' < MON_Min_HQE_`i')  & !missing(MON_Min_HQE_`i')  & !missing(`hqe')
		* 3/Checking 2hqe
	replace Predict_eligibility_`i' = 0 if (`hqe2' < MON_Min_2HQE_`i')    & !missing(MON_Min_2HQE_`i') & !missing(`hqe2')
		* 4/Checking BPE minus HQE 
	replace Predict_eligibility_`i' = 0 if (`bpe_minus_hqe' <=0)  & MON_Two_quarters_`i' ==1 & !missing(`bpe_minus_hqe')
		* 5/Ratio BPE HQE 	
	replace Predict_eligibility_`i' = 0 if (`bpe_hqe_ratio' <=MON_Min_BPE_HQE_ratio_`i')  & !missing(MON_Min_BPE_HQE_ratio_`i') & !missing(`bpe_hqe_ratio')
	* 6/Ratio WBA BPE
	replace Predict_eligibility_`i' = 0 if (`bpe_wba_ratio' < MON_Min_BPE_WBA_ratio_`i')  & !missing(MON_Min_BPE_WBA_ratio_`i') & !missing(`bpe_wba_ratio')
		* 7/Ratio WBA HQE
	replace Predict_eligibility_`i' = 0 if (`hqe_wba_ratio' < MON_Min_HQE_WBA_ratio_`i')  & !missing(MON_Min_HQE_WBA_ratio_`i') & !missing(`hqe_wba_ratio')
		* 8/Ratio WBA notHQE
	replace Predict_eligibility_`i' = 0 if (`nothqe_wba_ratio' < MON_Min_notHQE_WBA_ratio_`i')    & !missing(MON_Min_notHQE_WBA_ratio_`i') & !missing(`nothqe_wba_ratio')
		* 9/hours
	replace Predict_eligibility_`i' = 0 if (`hours' < MON_Min_hours_`i')    & !missing(MON_Min_hours_`i') & !missing(`hours')

	*********** Both methods:
	  
	gen Predict_eligibility_monetary=0
	replace Predict_eligibility_monetary=1 if Predict_eligibility_1==1  | Predict_eligibility_2==1
	replace Predict_eligibility_monetary=. if Predict_eligibility_1==. & Predict_eligibility_2==. 
	label var Predict_eligibility_monetary "Monetary eligibility (0 or 1), predicted from calculator"

 	**************************************************************************************************************
	*********** Predict monetary & separation eligibility  
	**************************************************************************************************************
	
	gen Predict_eligibility_sep=.
	replace Predict_eligibility_sep=SEP_avg_eligibility1 if `lackwork' == 1
	replace Predict_eligibility_sep=SEP_avg_eligibility2 if `quit' ==1
	replace Predict_eligibility_sep=SEP_avg_eligibility3 if `quit' ==0 &  `lackwork' ==0
	
	label var Predict_eligibility_sep "Separation eligibility chance if monetary eligible (in [0,1]), predicted from calculator"

	gen Predict_eligibility_all=Predict_eligibility_sep*Predict_eligibility_monetary
	label var Predict_eligibility_all "Eligibility chance (in [0,1]), predicted from calculator"
	
	
	**************************************************************************************************************
	* Remove the columns from the rules dataset 
	**************************************************************************************************************
	
	drop matching_year matching_state MON_Full_formula WBA_which_method MON_Min_HQE_* MON_Min_BPE_*  MON_Min_hours_* MON_Min_notHQE_* MON_Two_quarters_*           MON_Extra_Info MON_Min_2HQE_*  MON_eligibility_non_missing  MON_Second_method MON_Method MON_Method_num WBA_calc_method WBA_linear_term_AWW WBA_min_valu* WBA_max_valu* WBA_linear_term_2HQE WBA_linear_term_HQE WBA_linear_term_BPE WBA_intercept_HQ* WBA_simple_calc_method WBA_calc_method_num WBA_which_method_num Predict_eligibility_1 Predict_eligibility_2 SEP_avg_eligibility1 SEP_avg_eligibility2 SEP_avg_eligibility3  

end

