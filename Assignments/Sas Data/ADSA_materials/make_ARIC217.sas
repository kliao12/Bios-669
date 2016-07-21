%let job=make_ARIC217;
libname x '  some permanent location   ';
libname for669 'P:\Sakai\Sakai 2016\Course units\04 Analysis data sets and derived variables\Assignments\ADSA';


data mycore;
    set x.core;
    if Race in ('B','W');
    if (Gender='M' and 600<TotCal<4200) or
       (Gender='F' and 500<TotCal<3600);
run;


data meds;
    set x.medications;
    array codes{17} DrugCode1-DrugCode17;
    Diuretic=0;
    LipidLowerMed=0;
    do i=1 to 17;
        if '370000'<=codes{i}<='380000' then Diuretic=1;
        if codes{i} in ('390000','391000','240600') then
            LipidLowerMed=1;
    end;
    if msra02 in ('F','') and msra04aa='' then Diuretic=.;
run;


proc sort data=mycore;
    by id;
run;
proc sort data=x.measurements out=measurements;
    by id;
run;
proc sort data=meds;
    by id;
run;
proc sort data=x.nutrition out=nutrition;
    by id;
run;

data combine;
    merge mycore(in=incore)
          measurements(rename=(Magnesium=SerumMg))
          meds(drop=DrugCode1-DrugCode17)
          nutrition(rename=(Magnesium=DietMg));
    by id;
    if incore;

    if msra08f='Y' then do;
        chma16=.;
        InsulinIU=.;
    end;

    if Fast8=0 or missing(Fast8) then do;
        chma16=.;
        InsulinIU=.;
        chmx07=.;
        GlucoseIU=.;
    end;
run;

/*----------------------------------------------------------
  This is the step where most derived variables are added.
  ----------------------------------------------------------*/

data for669.ARIC217(label="Analysis data set for manuscript #217, created on &sysdate by job &job");
    set combine;

    length EmpStatus $ 10;
    if hom55='A' then EmpStatus='Homemaker';
    else if hom55 in ('B','C','G') then EmpStatus='Employed';
    else if hom55='F' then EmpStatus='Retired';
    else if hom55 in ('D','E') then EmpStatus='Unemployed';
    label EmpStatus="Participant employment status";


    if missing(DietMg) then DietMg_Group=.;
    else if DietMg<100 then DietMg_Group=1;
    else if DietMg<150 then DietMg_Group=2;
    else if DietMg<200 then DietMg_Group=3;
    else if DietMg<250 then DietMg_Group=4;
    else                    DietMg_Group=5;
    label DietMg_Group="Grouped dietary magnesium (mg)";
    

    DietMg_1000kcal=(DietMg/TotCal)*1000;
    label DietMg_1000kcal="Dietary magnesium consumption (mg) per 1000 kilocalories";
    

    AdjGlucose=chmx07;
    if missing(BloodDrawDate)=0 and
       BloodDrawDate<='15JUL1988'd then AdjGlucose=0.963*chmx07;
    label AdjGlucose="Corrected blood glucose level";
       

    if (PrevalentCHD=1 or RoseIC=1 or hom10d='Y') then CHD=1;
    else if (PrevalentCHD=0 and RoseIC=0 and hom10d='N') then CHD=0;
    else CHD=.;
    label CHD="Coronary heart disease indicator";


    nothick=nmiss(lopaav45,ropaav45,lbiaav45,
                  rbiaav45,linaav45,rinaav45);
    if nothick=5 then WallThickScore=.P;
    else if nothick=6 then WallThickScore=.N;
    else WallThickScore=mean(lopaav45,ropaav45,lbiaav45,
                             rbiaav45,linaav45,rinaav45);
    drop nothick;
    label WallThickScore="Mean carotid artery wall thickness";


    if dtia90='Y' then do;
        if dtia91='Y' then Drinker=1;
        else if dtia91='N' then Drinker=.;
        else if dtia91=' ' then Drinker=1;
    end;
    else if dtia90='N' then do;
        if dtia91='Y' then Drinker=2;
        else if dtia91='N' then Drinker=3;
        else if dtia91=' ' then Drinker=4;
    end;
    else if dtia90=' ' then do;
        if dtia91='Y' then Drinker=4;
        else if dtia91='N' then Drinker=3;
        else if dtia91=' ' then Drinker=.;
    end;
    label Drinker="Drinking status";


    if Drinker in (2,3) then Ethanol=0;
    else if Drinker=1 then do;
        if missing(dtia96) or missing(dtia97) or missing(dtia98) 
            then Ethanol=.;
        else Ethanol=(dtia96*10.8) + (dtia97*13.2) + (dtia98*15.1);
    end;
    else Ethanol=.;
    label Ethanol="Estimated alcohol consumption (grams/week)";
    

    if Gender='F' then do;
        if (Age>60 and DBP<60) or (Age<=60 and DBP<65) then LowBP=1;
        else LowBP=0;      
    end;
    else if Gender='M' then do;
        if (Age>60 and DBP<65) or (Age<=60 and DBP<70) then LowBP=1;
        else LowBP=0;
    end;
    if missing(DBP) then LowBP=.;
    label LowBP="Low blood pressure indicator";
    

    drop i;
    label Diuretic="Currently taking a diuretic"
          LipidLowerMed="Currently taking lipid lowering medication";
run;





