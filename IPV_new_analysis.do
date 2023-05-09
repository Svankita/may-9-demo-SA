/*****************************************************************************

Project				: Escaping Poverty - IPV Study
Author				: Svankita Arora
Date Created		: January 25, 2023
Date Last Modified	: 
Purpose				: Calculate duration between asset delivery and IPV survey to add as covariate to the final regression

Inputs				: Dataset with NB and WB asset delivery dates and ipv-ep_precleaning
Outputs				: Dataset with Asset delivery dates and IPV survey dates 	assetdelivery_ipvsurvey_dates.dta

******************************************************************************/

clear
set more off
version 15.1

//c EP_dir

global ipv_dofiles "04_Analysis&Results/05_IPV/02_Dofiles"
qui do "$ipv_dofiles/0_ipvs_set_globals.do"


/****************************************************************************

				Cleaning Dates for Nothern Belt Asset Delivery 

*****************************************************************************/

import excel "$dir\02_Intervention_OLD (pre May 2022)\03 EP Impl. Monitoring Tools & Data\Archive\08 Implementation Monitoring Data\EP Master Tracker_ Northern Belt.xls", sheet("Sheet1") firstrow clear 
drop if missing(hhid)



/*
Asset Delivery tracker for the Northern Belt has only date ranges within which the asset was delivered to the households and not specific dates for each household. Therefore, we will be taking the start date of asset deliveries for the first asset that each household recieves 
*/

replace Animaldelierydate = subinstr( Animaldelierydate, "12/2017 to 02/2018", "01/12/2017 to 01/02/2018", .)  // 51 observations did not have a day in the date range and so assumed to be 1st of the month 

foreach var in CropdeliveryDate Animaldelierydate AgroProcessDeliverydate{
	split `var'											
	gen `var'_start = date(`var'1, "DMY", 2017)
	format  `var'_start %td
	gen `var'_end = date(`var'3, "DMY", 2017)
	format `var'_end %td
	//drop `var'1 `var'2 `var'3
}

egen first_asset_date = rowmin(CropdeliveryDate_start Animaldelierydate_start AgroProcessDeliverydate_start)
format first_asset_date %td
lab var first_asset_date "Date of first asset delivery"

// Changing asset delivery date for control group to missing
gen treatment_asset = inlist(assigncode, 24, 25, 26, 27, 34, 35, 36, 37, 38, 39) if !mi(assigncode)
replace first_asset_date = . if !missing(first_asset_date) & treatment_asset == 0 

keep hhid heifergup assign assigncode region district first_asset_date

preserve
tempfile Asset_NB
save `Asset_NB'
restore 


/****************************************************************************

				Cleaning Dates for Middle Belt Asset Delivery 

*****************************************************************************/


import excel "X:\Box\Escaping Poverty\02_Intervention_NEW (as of May 2022)\01_Treatments\05_Livelihood_Assets\03_Asset_Selection_&_Delivery_Tracking_encrypted\02_Middle_Belt\Non-Delivered_Asset_Reasons\HeiferAsset_NA Analysis Clean.xlsx", sheet("Participant Data") firstrow allstring clear

rename (HHID HeiferorGUP Assignmentlabel Assignmentcode Region District) (hhid heifergup assign assigncode region district)

local asset GroundnutProduction CowpeaProduction CassavaProduction ploughing Seed ChemicalFungiInsecticides Fertilizer Fowls ///
			Goat Sheep Pig Vaccinnation Rawcassava AluminiumBasin RosterShieve OilPalmKernel25litres SodaAsh Rubbercontainerbig ///
			Rubbercontainersmall CausticSoda25kg Hydrometer OilPalmoil13litres Rice50kg Oil25lits SachetsTomanto Maize Millet ///
			Groundnutretail Sorghum SpaghettiIndomiboxes Cloth Fridge ChestFreezer Sandalsandslippers Drinks Balmointiment Kentecloth ///
			Butterbakingfat SecondHandClothings SmokedFishbaskets AgroChemical IceChest Electricalsparts Cassavatrading Banana ///
			Soya Flour HairProducts Alreadysewndresswears plasticbowl Saltbags basketsassortedvarieties underwarepieces Pomade ///
			Palmoil25litgallon Soap Diaperspieces Gascylinder PolyTank Gari Colanuts Sugar MilloMilk PowderedSoap BX Plantain Mat ///
			EarRingspairs LocalRice Yam CausticSoda Onion PlasticBowls LaddiesBags Rice Oil25Litres CJ CK CL Beans CN CO ///
			Plasticbowlspieces Banna KanteCloth CS CT DeepFreezer Salt CW TeaItems Butter UsedClothings DA AgroChemicalliters DC DD DE ///
			Powersoapomo Diapers DH PolyTankl Palmfruittonnes DK DL Millotin Teabagsboexes pomadesbottles creditcards DR DS SowingMachine ///
			Coalpot Sandalssndsleepers Cookingpot
			
foreach varlist in `asset'{
	gen `varlist'_date = date(`varlist', "MDY")
	format `varlist'_date %td
	replace `varlist'_date = . if `varlist'_date < date("01jan2018", "DMY")
}

/*foreach varlist in `asset'{
	qui count if missing(`varlist'_date) & !missing(`varlist')
	if r(N) > 0 di "`varlist'" %3.0f r(N)
}*/


local asset_date *_date
egen first_asset_date = rowmin(`asset_date')	// The date when the household receives their first asset is taken for further analysis 
format first_asset_date %td
lab var first_asset_date "First date of asset delivery"


/*foreach varlist in `aseet'{
	qui count if missing(`varlist'_date) & !missing(`varlist') & missing(first_date_asset)
	if r(N) > 0 di "`varlist'" %3.0f r(N)
}
*/

// Changing asset delivery date for control group to missing
destring assigncode, replace
gen treatment_asset = inlist(assigncode, 24, 25, 26, 27, 34, 35, 36, 37, 38, 39) if !mi(assigncode)
replace first_asset_date = . if !missing(first_asset_date) & treatment_asset == 0 



keep hhid heifergup assign assigncode region district first_asset_date

append using `Asset_NB', force 


/****************************************************************************

				Merging and Cleaning Dates for IPV Survey 

*****************************************************************************/

merge 1:1 hhid using "$nopii\ipv_ep_precleaning", keepusing(date) 
//drop if _merge != 3 
drop _merge
gen ipv_survey_date = date(date, "YMD")
format ipv_survey_date %td
lab var ipv_survey_date "Date of IPV survey"
drop date

gen days_asset_ipvsurvey = datediff(ipv_survey_date, first_asset_date, "day")
lab var days_asset_ipvsurvey "Days between IPV survey and receipt of first asset"

save "$nopii\assetdelivery_ipvsurvey_dates", replace


