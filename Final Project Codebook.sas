*Final Project Codebook*;

ODS RTF FILE="&outdir\&job._Codebook..RTF" BODYTITLE STYLE=JOURNAL;
Options MPrint;
ODS RTF STARTPAGE=NO;

%Macro Codebook;

*Character Variables*;

*Produce macro variable of character variables*;
proc sql noprint;
	select name into :charlist separated by ' '
		from dictionary.columns
			where libname='WORK' and memname='FINAL_DATA' and
 				  type='char';
quit;
%Put &charlist;


*Loop through list of character variables*;
	%let i = 1;
	%Do %Until (%scan(&charlist, &i)= );
		%Let Var = %scan(&charlist, &i);

		PROC SQL NoPrint;
			Select Count(Distinct &Var) Into: char_Distinct
				From WORK.FINAL_DATA;
		Quit;

		%If &char_Distinct < 6 %Then %Do;
			Proc Freq Data = WORK.FINAL_DATA noprint;
				Tables &Var / Missing out=&var._table;
				Title "Frequency Table for &Var (Less than 6 Unique Values)";
			Run;

			data _null_;
				dsid = open("WORK.FINAL_DATA");
				Label = VarLabel(dsid, Varnum(dsid, "&Var"));
				call symput("var_label", label);
				rc = close(dsid);
			run;

			data &Var._table1; set &Var._table;
				length variable $ 15;
				variable = "&Var";
				label = "&var_label";
				count_char = put(count, 20.);
				description = compbl(cat("N = ", count_char));
				rename &Var = frequency;
			run;

		%End;

		%Else %Do; /*Character variables with a lot of unique values*/;
			
			proc sql noprint;
				select count(distinct &var) into:unique_count
				from WORK.FINAL_DATA;
			quit;

			data _null_;
				dsid = open("WORK.FINAL_DATA");
				Label = VarLabel(dsid, Varnum(dsid, "&Var"));
				call symput("var_label", label);
				rc = close(dsid);
			run;

			Data &Var._table1;
				length Variable $ 15;
				Frequency = "Range"; Count = &unique_count;
				Variable = "&Var"; Label = "&Var_Label";
				Description = "All or most values unique";
			run;

		%End;

		%let i = %eval(&i+1);
 	%End;


*Generate macro variable of created datasets to combine*;
proc sql noprint;
	select distinct memname into: table_list separated by ' '
		from dictionary.columns
		where libname = 'WORK' and index(memname, 'TABLE1') > 0;
quit;
%Put &table_list;

*Create combined dataset of all character datasets*;
data combine_char; set &table_list;
run;



*Numeric Variables*;


*Create Macro variable of all numeric variables that are not date variables*;
proc sql noprint;
	select name into :num_list separated by ' '
		from dictionary.columns
			where libname='WORK' and memname='FINAL_DATA' and
 				  type='num' and (index(format, 'DATE')=0 and index(format, 'MMDDYY')=0);
quit;

*Loop through created list*;
	%let i = 1;
	%Do %Until (%scan(&num_list, &i)= );
		%Let Var = %scan(&num_list, &i);

		PROC SQL NoPrint;
			Select Count(Distinct &Var) Into: num_Distinct
				From WORK.FINAL_DATA;
		Quit;

		%If &num_Distinct < 6 %Then %Do;
			Proc Freq Data = WORK.FINAL_DATA noprint;
				Tables &Var / Missing out=&var._table;
				Title "Frequency Table for &Var (Less than 6 Unique Values)";
			Run;
		%End;

		%Else %Do;

			proc means data = WORK.FINAL_DATA noprint maxdec=2 noprint;
				var &Var;
				output out = &Var._1
						n = _n nmiss = _miss min = _min max = _max mean= _mean;
			run;

			data _null_;
				dsid = open("WORK.FINAL_DATA");
				Label = VarLabel(dsid, Varnum(dsid, "&Var"));
				put Label= ;
				call symput("var_label", label);
				rc = close(dsid);
			run;

			%put &var_label;


			*Create dataset with variables matching character dataset created previously*;
			*Providing N, min, max, and mean using concatenation*;
			data &Var._mean; set &Var._1;
				length variable $ 15;
				frequency = "Range";
				variable = "&Var";
				label = "&Var_label";
				description = cats("N = ", _n, ", Range = (", _min, ", ", _max, "), Mean = ", substr(_mean,1,5));
				rename _freq_ = count;
			drop _type_ _n _miss _min _max _mean;
			run; 
		%End;

		%let i = %eval(&i+1);
 	%End;


*Generate list of numeric variables to combine*;	
proc sql noprint;
	select distinct memname into: mean_list separated by ' '
		from dictionary.columns
		where libname = 'WORK' and index(memname, 'MEAN') > 0;
quit;
%Put &mean_list;

data combine_num; set &mean_list;
run;



*Combining numeric and character variable datasets*;
data all_var; set combine_num combine_char ;
run;


*Creating report*;
Proc Format;
	Value $ Frequency R = 'Range';
run;

Proc Report Data = all_var
	style(header)=[color=black backgroundcolor=very light grey ]
	style(summary)=[color=very light grey backgroundcolor=very light grey fontfamily="Times Roman" fontsize=1pt textalign=r];

	column variable label frequency description;
	define variable / "Variable" order ;
	define label / "Variable Label" order;
	define frequency/ "Variable Values" order Format=$Frequency.;
	define description / "Description" display;
	break after variable  /summarize suppress; * style={textdecoration=underline}; * suppress;

	Title 'Codebook for Dataset WORK.FINAL_DATA';
run;

%Mend;

%Codebook;

ODS RTF CLOSE;
