*  MACRO:        Exclude_data_using_conditions
*
*  DESCRIPTION:  Creates new data set and calculated exclusions counts 
*  
*  SOURCE:       CSCC, UNC at Chapel Hill
*
*  PROGRAMMER:   Polina Kukhareva
*
*  DATE:         02/05/2013
*
*  HISTORY:      Exclude_data_using_conditions -- Kukhareva -- 02/26/2013
*                Slight modifications for BIOS 669 macro use - Roggenkamp spring 2015
*  
*  LANGUAGE:     SAS VERSION 9.2
*
*  INPUT:        SAS data set containing binary outcome data
*
*  OUTPUT:       RTF file with flow chart, tables 1 and 2
*******************************************************************;

/*Example:
%Exclude_data_using_conditions (_DATA_IN=rq.simcox, 
_primary_exclusions=0 LT age GT 60, _NUMBER=1, _use_primary_exclusions=Yes,
_secondary_exclusions=missing(age) ~ missing(systolic_bp) ~ missing(diastolic_bp) ~ missing(ldl)  ~ missing(bmi) ~ missing(diabetes)  ~ missing(smoking)
~ missing(sex) ~ missing(treatment) ~ missing(activity) ~ missing(CV_event) ~ missing(CV_time), 
_predictors=age systolic_bp diastolic_bp ldl bmi diabetes smoking sex treatment activity stress CV_event death_event,
_categorical=diabetes smoking sex treatment activity CV_event death_event, 
_countable=stress,
_COUNT=%str(CV_event=1 ~ death_event=1),
_ID=ID,
_TITLE1=Exclude_data_using_conditions Macro for Data Exclusions) */

%macro Exclude_data_using_conditions (_DATA_IN=   /*Name of the data set containing initial data*/,
                                  _DATA_OUT=included2 /*Outputed Analysis data set*/,
                                  _USE_PRIMARY_EXCLUSIONS=No /*Are you going to use primary exclusions? Answer no or Yes*/,
                                  _PRIMARY_EXCLUSIONS=' '/*List of primary conditions separated by ~, omit it if there are no primary exclusions*/ ,
                                  _SECONDARY_EXCLUSIONS=/*List of conditions separated by ~*/ ,
                                  _NUMBER=1/*User defined word or number of the model which will appear in the name of rtf file, e.g. 1*/, 
                                  _PREDICTORS=/*List of ALL variables (including categorical, countable and continuous) to be included in table 2 separated by blanks*/, 
                                  _CATEGORICAL=_no_categorical_variables/*List of the categorical variables to be included in table 2*/, 
                                  _COUNTABLE=_no_countable_predictors/*List of variables for which we estimate median to be included in table 2*/,
                                  _RQ=exclusions/*Characters to be included in the name of output RTF file, e.g. exclusions*/,
                                  _FOOTNOTE=%str(&sysdate, &systime -- produced by macro Exclude_data_using_conditions) /*Footnote*/,
                                  _ID=ID /*ID variable*/,
                                   _odsdir=&outdir,
                                  _COUNT=/*List of conditions for which we calculate counts, for example outcomes separated by ~*/,
                                  _TITLE1=Exclude_data_using_conditions Macro/*Title which appears in the rtf file*/) / minoperator;
options nodate mprint pageno=1 mergenoby=warn MISSING=' ' validvarname=upcase orientation=portrait ;
goptions gunit=cells HSIZE=8 in VSIZE=8.5 border;
ods listing close;
ods rtf file="&_odsdir.\&_RQ._exclusion_&_NUMBER..rtf" style=analysis NOGTITLE NOGFOOTNOTE bodytitle;
ods rtf exclude all;
%let _PREDICTORS=%upcase(&_PREDICTORS);
%put _PREDICTORS= &_PREDICTORS;
%let _CATEGORICAL=%upcase(&_CATEGORICAL);
%put _CATEGORICAL= &_CATEGORICAL;
%let _COUNTABLE=%upcase(&_COUNTABLE);

/*getting ready to use the annotate facility*/

%annomac;

%macro add_element(x=,y=,width=,height=,text=);
%rect(&x,&y,&x+&width,&y+&height,black,1,0.4);
%let i=1;
%do %until (%qscan(&text,&i,|)=);
%label(&x+0.5,&y+&height-&i,"%qscan(&text,&i,|)",BLACK,0,0,0.9,simplex,6);
%let i=%eval(&i+1);
%end;
%mend add_element;

/*Producing a work data set*/
data base;
    set &_DATA_IN;
run;

/*Assigning values to macro variables (number of conditions in the macro call)*/

%if &_USE_PRIMARY_EXCLUSIONS=No %then %do; 
    %let _EXCLUSIONS=&_SECONDARY_EXCLUSIONS; %let number_of_primary_exclusions=0; 
%end;
%else %do; 
    %let _EXCLUSIONS= &_PRIMARY_EXCLUSIONS ~ &_SECONDARY_EXCLUSIONS;
    %let number_of_primary_exclusions=%eval(%sysfunc(countw(%str(&_PRIMARY_EXCLUSIONS),~)));
%end;
%let number_of_exclusions=%eval(%sysfunc(countw(%str(&_EXCLUSIONS),~)));
%let number_of_secondary_exclusions=%eval(%sysfunc(countw(%str(&_SECONDARY_EXCLUSIONS),~)));
%let number_of_counts=%eval(%sysfunc(countw(%str(&_COUNT),~)));

/*Creating a format which links exclusion conditions with their number*/
proc format;
    value $efmt
    %do i=1 %to &number_of_exclusions;
        E&i = "%qscan(&_EXCLUSIONS, &i,~)"
    %end;
;
    value pvalue_best
        0-<0.1=[pvalue5.3] 
        Other=[5.2] ;
run;

/*Creating primary exclusion and inclusion data sets*/                     
data included1 (drop=exc1) excluded1;
set base;
/*hierarhical counts for excluded rows*/
    if %scan(&_PRIMARY_EXCLUSIONS, 1,~) then exc1=1;
    %do i=2 %to &number_of_primary_exclusions;
           else if %scan(&_PRIMARY_EXCLUSIONS, &i,~) then exc1=&i;
    %end;
    if exc1>0 then output excluded1; else output included1;
run;

/*Creating secondary exclusion and inclusion data sets*/     
data &_DATA_OUT (drop=exc2) excluded2;
set included1;
/*hierarhical counts for excluded rows*/
    if %scan(&_secondary_EXCLUSIONS, 1,~) then exc2=1;
    %do i=2 %to &number_of_secondary_exclusions;
           else if %scan(&_secondary_EXCLUSIONS, &i,~) then exc2=&i;
    %end;
if exc2>0 then output excluded2; else output &_DATA_OUT;
run;

/*Creating exclusion and inclusion data set for both primary and secondary conditions*/   
data base_with_exc_var;
set base;
/*hierarhical counts for number of excluded rows and positive outcomes*/
    if %scan(&_EXCLUSIONS, 1,~) then do; 
        exc=1; 
        %do b=1 %to &number_of_counts;
            if %scan(&_COUNT, &b,~) then count_hier_&b.=1; 
        %end;
    end;

    %do i=2 %to &number_of_exclusions;
           else if %scan(&_EXCLUSIONS, &i,~) then do;
                exc=&i;
                %do b=1 %to &number_of_counts;
                    if %scan(&_COUNT, &b,~) then count_hier_&b.=&i; 
                %end; 
           end;              
    %end;
/*Absolute counts for number of excluded rows and positive outcomes*/
    %do a=1 %to &number_of_exclusions;
           if %scan(&_EXCLUSIONS, &a,~) then do; 
                e&a=1; 
                %do b=1 %to &number_of_counts;
                    if %scan(&_COUNT, &b,~) then count_&b._&a=1; 
                %end; 
           end;
    %end;
run;

/*Non-hierarchical counts for number of excluded rows*/
proc means data=base_with_exc_var noprint;
     var e1-e&number_of_exclusions;
     output out=excsum1 (drop=_:) sum=;
run;
proc transpose data=excsum1 out=excsum1;
run;
data excsum1;
    set excsum1;
        exc=input(substr(_NAME_,2),8.0);
        rename col1=exclusions_non_hier;
run;
/*Non-hierarchical counts for number of excluded positive outcomes*/
%do b=1 %to &number_of_counts;
proc means data=base_with_exc_var noprint;
     var count_&b._1-count_&b._&number_of_exclusions;
     output out=count_dataset_&b (drop=_:) sum=;
run;
proc transpose data=count_dataset_&b out=count_dataset_&b;
run;
data count_dataset_&b;
    set count_dataset_&b;
        exc=input(substr(_NAME_,9),8.0);
        rename col1=count_&b;
run;
%end;

/*Hierarchical counts for number of excluded rows and positive outcomes*/
proc sql;
    create table excsum2 as
        select  exc, count(exc) as exclusions %do b=1 %to &number_of_counts; , count(count_hier_&b) as count_hierarchical_&b %end;
        from base_with_exc_var 
        where ^missing(exc)
        group by exc;
quit;


/*Merging hierarchicaly and non-hierarchicaly exclusion data*/
data excsum;
     merge excsum1 excsum2 %do b=1 %to &number_of_counts; count_dataset_&b (drop=_NAME_) %end;;
     by exc;
     length exclusion_group $9;
     if exclusions_non_hier=. then exclusions_non_hier=0;
     if exclusions=. then exclusions=0;
     %do b=1 %to &number_of_counts; 
        if count_&b=. then count_&b=0; 
        if count_hierarchical_&b=. then count_hierarchical_&b=0; 
     %end;
     if exc<=&number_of_primary_exclusions then exclusion_group='Primary';
     else if exc>%eval(&number_of_primary_exclusions) then exclusion_group='Secondary';
run;

/*Creating macro variables containing number of observations in different data sets and subgroups*/
    proc sql;
        select put(count(&_id),8.0), put(sum(exc>0),8.0), put(sum (exc<1),8.0) into :n1, :n2, :n3 from base_with_exc_var;
    quit;
    %let n1=&n1;
    %let n2=&n2;
    %let n3=&n3;
    proc sql noprint;
        select catx(' ',put(_NAME_,$efmt.),"N=",put(exclusions,8.0)) into :secondary separated by '| -'
        from excsum where exclusion_group='Secondary';
    quit;
    proc sql noprint;
        select sum(exclusions) into :secondary_sum
        from excsum where exclusion_group='Secondary';
    quit;
    %let primary= No primary exclusions;
    %let primary_sum=0;
    %if &number_of_primary_exclusions ^=0 %then %do;
        proc sql noprint;
            select catx(' ',put(_NAME_,$efmt.)," N=",put(exclusions,8.0)) into :primary separated by '| -'
            from excsum where exclusion_group='Primary';
        quit;
        proc sql noprint;
            select sum(exclusions) into :primary_sum
            from excsum where exclusion_group='Primary';
        quit;
    %end;
    %let primary= &primary;;
    %let primary_sum=&primary_sum;
    %let secondary_sum=&secondary_sum;
    %let primary_included=%eval(&n1-&primary_sum);
    %let secondary_excluded=%eval(&primary_included-&n3);

/*Creating an annoteted data set to produce a flow chart*/

data final;
length function color style $8. text $60.;
retain xsys '6' ysys '6' hsys '6' when 'a' line 1 function 'label';
%add_element(x=45,y=60,width=14,height=3,text=%str( Initial Data Set | N=&n1));
%add_element(x=2, y=%eval(52-&number_of_primary_exclusions),width=55,height=%eval(3+&number_of_primary_exclusions),text=%str(Primary Exclusions Data Set N=&primary_sum | -&primary ));
%add_element(x=72,y=52,width=22,height=3, text=%str( Primary Included Data| N=&primary_included));
%add_element(x=10, y=%eval(29-&number_of_secondary_exclusions),width=55,height=%eval(3+&number_of_secondary_exclusions),text=%str( Secondary Excluded Data N=&secondary_sum | -&secondary ));
%add_element(x=72, y=28,width=22,height=4,text=%str(Analysis Data Set |(Secondary Included Data)| N=&n3));
/*** CONNECTING LINES... ***/

%line(52,60, 52,57.5,gray,1,2);
%line(20,57.5,83,57.5,gray,1,2);
%line(20,57.5,20,55 ,gray,1,2);
%label(20,55,'D',gray,0,0,1,Marker,B); 
%label(83,55,'D',gray,0,0,1,Marker,B); 
%label(42,32,'D',gray,0,0,1,Marker,B); 
%label(83,32,'D',gray,0,0,1,Marker,B);
%line(83,57.5,83,55 ,gray,1,2);
%line(83,52, 83,32 ,gray,1,2);
%line(42,35,83,35,gray,1,2);
%line(42,35,42,32 ,gray,1,2);
run;

data final;
    set final;
    if function in ('POLYCONT' 'POLYLINE') then do; text=''; style=''; end;
run;
ods rtf select all;

/*Producing a flow chart*/
title1 j=center height=14pt color=black font="Times Roman" "&_TITLE1";
title2 j=center height=12pt color=black font="Times Roman" 'Figure 1. Flowchart of data exclusions';
footnote1 J=right height=8pt font="Times Roman" &_FOOTNOTE;
proc gslide annotate=final;
run;
quit;
title2 j=center height=12pt color=black font="Times Roman"  'Table 1. Counts of all excluded rows and excluded rows with positive outcome by exclusion condition';
footnote1 J=left height=12pt font="Times Roman" "Initial data set &_DATA_IN contains &n1 records. After excluding &n2 records analysis data set &_DATA_OUT contains &n3 records.";
footnote3 J=right height=8pt font="Times Roman" &_FOOTNOTE;

/*Printing table 1*/
%let st=style(column)=[just=center vjust=bottom font_size=8.5 pt]
        style(header)=[just=center font_size=8.5 pt];
proc report data=excsum nowd SPANROWS;
    column exclusion_group exc _NAME_ ('Absolute Counts' exclusions_non_hier %do b=1 %to &number_of_counts; count_&b %end;) 
                                      ('Hierarchical Counts' exclusions %do b=1 %to &number_of_counts;  count_hierarchical_&b %end;); 
    define exclusion_group / 'Exclusion group' group style(column)=[just=center vjust=middle font_size=8.5 pt] style(header)=[just=center font_size=8.5 pt];
    define exc / '' display &st;
    define _NAME_ / 'Condition' display format=$efmt. style(column)=[just=left vjust=bottom font_size=8.5 pt] style(header)=[just=center font_size=8.5 pt];
    define exclusions_non_hier / 'N' display &st;
    define exclusions / 'N' analysis sum &st;
    %do b=1 %to &number_of_counts; 
        %let count_label=%scan(&_COUNT, &b,~);
            define count_&b/ "&count_label" display style(column)=[just=center vjust=bottom font_size=8.5 pt cellwidth=1.8 cm]  style(header)=[just=center font_size=8.5 pt]; 
            define count_hierarchical_&b/ "&count_label" analysis sum style(column)=[just=center vjust=bottom font_size=8.5 pt cellwidth=1.8 cm]  style(header)=[just=center font_size=8.5 pt];  
    %end;
    rbreak after / dol skip summarize;
run;



/*From this point till the end of the macro we are creating table 2*/
title2 j=center height=12pt color=black font="Times Roman" 'Table 2. Comparison of excluded and included data sets';
footnote1 J=left height=9pt font="TIMES ROMAN" 
"{Note: Values expressed as N(%), mean ± standard deviation or median (25\super th}{, 75\super th }{percentiles)}";
footnote2 J=left height=9pt font="TIMES ROMAN" 
"Note: P-value comparisons across categories are based on chi-square test of homogeneity for categorical variables; p-values for continuous variables are based on ANOVA or Kruskal-Wallis test for median";
footnote4 J=right height=9pt font="TIMES ROMAN" &_FOOTNOTE;

ods rtf exclude all;

/*Merging excluded and included data sets for secondary exclusions*/
    data secondary;
        merge &_DATA_OUT (in=in_included2) excluded2;
            by &_id;
            in_included =in_included2;
    run;
    proc sort data=secondary;
        by in_included;
    run;

/*Creating an empty data set to append some observations later*/
    proc sql noprint;
        create table table2
        (label char (100), variable char(40), missing_included num, missing_excluded num, included  char (200), excluded char (200), pvalue NUM);
    quit;

/*We are iterating through all predictors in given order to compare their values beetween excluded and included data sets*/
%do  all_count=1 %to %sysfunc(countw(&_predictors));
    %let CHECK_VAR=%scan(&_predictors, &all_count,%str( ));
    %let CHECK_VAR=%UNQUOTE(&CHECK_VAR);
/*We calculate number, percentage and p-value using chi-square test for categorical predictors*/    
    %if &CHECK_VAR in &_categorical %then %do;
        proc sql;
            create table part1_excluded as
            select excluded2.&CHECK_VAR as label1, catx('',put(count(excluded2.&CHECK_VAR),8.0),'(', put(count(excluded2.&CHECK_VAR)/Subtotal,percent8.0),')') as excluded
            from excluded2, (select count(&CHECK_VAR) as Subtotal from excluded2)
            where ^missing(&CHECK_VAR) 
            group by excluded2.&CHECK_VAR ;
        quit;
        proc sql;
            create table part1_included as
            select included2.&CHECK_VAR as label1, catx('',put(count(included2.&CHECK_VAR),8.0),'(', put(count(included2.&CHECK_VAR)/Subtotal,percent8.0),')') as included
            from &_DATA_OUT as included2, (select count(&CHECK_VAR) as Subtotal from &_DATA_OUT)
            where ^missing(&CHECK_VAR) 
            group by included2.&CHECK_VAR ;
        quit;
        data part1 (drop=label1);
            length label $100;
            merge part1_excluded part1_included;
            by label1;
            if Vtype(label1)='C' then label=label1;
            else label=put(label1, 8.0);

        run; 
        data part1;
            set part1;
            length label $100;
                label='- '||strip(label);
        run;

        proc freq data=secondary;
            table in_included*&CHECK_VAR/chisq;
            output out=p pchi;
        run;
        %if (%sysfunc(exist(work.p)))=0 %then %do;
            data p;
                length p_pchi 8.;
            run;
        %end;
        proc sql; create table part2_included as select sum(missing(&CHECK_VAR)) as missing_included
            from &_DATA_OUT;
        run;
        proc sql; create table part2_excluded as select sum(missing(&CHECK_VAR)) as missing_excluded
            from excluded2;
        run;

        PROC TRANSPOSE DATA=secondary (OBS=1 KEEP=&CHECK_VAR) OUT=VARLABL;
            var &CHECK_VAR;
        RUN;
/* checking existence of the variable label */
        data _null_;
            dsid=open('VARLABL');
            check_VARLABL=varnum(dsid,'_Label_');
            call symput('check_label',put(check_VARLABL,best.));
        run;
        data VARLABL;
            length _label_ $40;
            set VARLABL;
                %if &check_label=0 %then %do; _Label_=' '; %end;
        run;  

        data part2;
            set  part2_included; set part2_excluded; set p (keep=p_pchi rename=(p_pchi=pvalue) );
            set VARLABL (keep=_name_  _Label_ rename=(_Label_=label _name_=variable));
        run;

        data add;
            set part2 part1 ;
        run;

        proc append BASE=table2 DATA=add force;
        run;

    %end;
/*We calculate median, IQR and p-value using Kruskal-Wallis test for median for not normally distributed continuous predictors*/    
    %else %if &CHECK_VAR in &_countable %then %do;
        proc npar1way data=secondary wilcoxon;
            var &CHECK_VAR;
            class in_included;
            output out=p Wilcoxon;
        run;
        proc univariate data=secondary noprint;
            var &CHECK_VAR;
            output out=IQR pctlpts= 25 50 75 pctlpre=&CHECK_VAR.;
            by in_included;
        run;
        data IQR; 
            format tval $50.;
            set iqr;
            tval="{"||(strip(put(&CHECK_VAR.50,5.1)))||' ('||strip(put(&CHECK_VAR.25,5.1))||', '||strip(put(&CHECK_VAR.75,5.1))||')}';
            drop &CHECK_VAR.50 &CHECK_VAR.25 &CHECK_VAR.75;
        run;
        proc transpose data=IQR out=median_p_trans; id in_included; var tval;
        run;

        PROC TRANSPOSE DATA=secondary (OBS=1 KEEP=&CHECK_VAR) OUT=VARLABL;
        RUN;
        /* checking existence of the variable label */
        data _null_;
            dsid=open('VARLABL');
            check_VARLABL=varnum(dsid,'_Label_');
            call symput('check_label',put(check_VARLABL,best.));
        run;
        data VARLABL;
            length _label_ $40;
            set VARLABL;
                %if &check_label=0 %then %do; _Label_=' '; %end;
        run;

        proc sql; 
            create table part2_included as 
            select sum(missing(&CHECK_VAR)) as missing_included
            from &_DATA_OUT;
        run;
        proc sql; create table part2_excluded as select sum(missing(&CHECK_VAR)) as missing_excluded 
            from excluded2;
        run;
        data add;
            set median_p_trans(keep=_0 _1 rename=(_0=excluded _1=included)); set p (keep=P_KW rename=(P_KW=pvalue)); 
            set VARLABL (keep=_name_ _Label_ rename=(_Label_=label _name_=variable)); set part2_included; set part2_excluded;
        run;
        proc append BASE=table2 DATA=add force;
        run;
    %end;
/*We calculate mean, standard deviation and p-value using T-test for continuous predictors*/    
    %else %do;
        proc sql;
            create table table2_excluded
            as select sum(missing(&CHECK_VAR)) as missing_excluded, catx(' ','{', put(mean(&CHECK_VAR), 8.1),' \u0177\~ ',put(sqrt(var(&CHECK_VAR)),8.1),'}') as excluded
            from excluded2;
        quit;
        proc sql;
            create table table2_included as 
            select sum(missing(&CHECK_VAR)) as missing_included, catx(' ','{', put(mean(&CHECK_VAR), 8.1),' \u0177\~ ',put(sqrt(var(&CHECK_VAR)),8.1),'}') as included
            from &_DATA_OUT;
        quit;
        ods output ttests=p(keep=variable  method probt where=(method='Pooled') rename=(probt=pvalue));
            proc ttest data=secondary;
                class in_included;
                var &CHECK_VAR;
            run;
        ods output close;
        PROC TRANSPOSE DATA=secondary
            (OBS=1 KEEP=&CHECK_VAR) OUT=VARLABL;
        RUN;
        /* checking existence of the variable label */
        data _null_;
            dsid=open('VARLABL');
            check_VARLABL=varnum(dsid,'_Label_');
            call symput('check_label',put(check_VARLABL,best.));
        run;
        data VARLABL;
            length _label_ $40;
            set VARLABL;
                %if &check_label=0 %then %do; _Label_=' '; %end;
        run;
        data add;
            set table2_excluded; set table2_included; set p (keep=pvalue); set VARLABL (keep=_name_ _Label_ rename=(_Label_=label _name_=variable));
        run;
        proc append BASE=table2 DATA=add force;
        run;
    %end;
    proc datasets lib=work memtype=data;
        delete p ;
    run; quit;
%end;
/*Printing table 2*/    
ods rtf select all;
    proc report data=table2 nowd ;
        column label variable   ( 'N missing' missing_excluded missing_included) ('Descriptive Statistics' excluded included)  pvalue;
        define label / 'variable label' display style(column)=[just=left vjust=bottom font_size=8.5 pt] style(header)=[just=center font_size=8.5 pt];
        define variable / 'variable name' display style(column)=[just=left vjust=bottom font_size=8.5 pt] style(header)=[just=center font_size=8.5 pt];
        define missing_included / "included dataset/ N=&n3" display &st;
        define missing_excluded / "excluded dataset/ N=&secondary_excluded" display &st;
        define included / "included dataset/ N=&n3" display &st;
        define excluded / "excluded dataset/ N=&secondary_excluded" display &st;
        define pvalue / 'P-value' display format=pvalue_best. &st;
    run;
ods rtf exclude all;

proc datasets lib=work memtype=data;
    delete Add Base Base_with_exc_var excsum excsum1 excsum2 iqr p part1 part1_included part1_excluded part2 part2_included part2_excluded
            secondary table2 table2_excluded table2_included varlabl count_dataset_: median_p_trans;
run; quit;

ods listing;

ods rtf close;
footnote;
title;

%mend Exclude_data_using_conditions;

