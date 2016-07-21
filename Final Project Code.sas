*Outputting Log*;
PROC PRINTTO LOG='C:\Users\kevin\Desktop\Bios 669\SAS Output\Final_Project.log' NEW;
RUN;


*********************************************************************
*  Assignment:    Final Project                                
*                                                                    
*  Description:   NBA Draft Analysis
*
*  Name:          Kevin Liao
*
*  Date:          5/2/2016                                        
*------------------------------------------------------------------- 
*  Job name:      Final Project_ksliao.sas   
*
*  Purpose:       Final_Project
*
*  Language:      SAS, VERSION 9.4  
*
*  Input:         Various Mets datasets 
*
*  Output:        RTF file 
*                                                                    
********************************************************************;

%LET job=Final_Project;
%LET onyen=ksliao;
%LET outdir=C:\Users\kevin\Desktop\Bios 669\Final Project;

OPTIONS NODATE MERGENOBY=WARN LS=72 FORMCHAR="|----|+|---+=|-/\<>*" ;
FOOTNOTE3 "Job &job._&onyen run on &sysdate at &systime";

ODS RTF FILE="&outdir\&job._&onyen..RTF" BODYTITLE STYLE=JOURNAL;

Proc IML;
	Submit / R;
    	library(XML)

		years <- 2000:2015
		data <- NULL	

		for (i in years) {
		    url <- paste("http://www.basketball-reference.com/draft/NBA_", i, ".html", sep="")
		    page <- htmlTreeParse(readLines(url), useInternalNodes=T)
		    table <- readHTMLTable(page)$stats
		    table <- subset(table, Player!="Player" & College !="Totals")
		    table$Draft_Yr <- i
		    data <- rbind(data, table)
		}

	Endsubmit;

	Call ImportDatasetFromR("Work.NBA_Draft", "data");

Quit;


*Convert Character Variables to Numeric (Adapted Code from SAS Website)*;
Proc Contents Data = NBA_Draft Out = Vars(keep=name type) noprint; 
run;

Data Rename_Vars; Set Vars;                                                 
	if type=2 and name ~in ('College', 'Player', 'Tm') ;                               
	newname=trim(left(name))||"_n";                                                                               
run;

Proc SQL Noprint;                                         
	Select trim(left(name)), trim(left(newname)),             
       	   trim(left(newname))||'='||trim(left(name))         
		   Into :c_list separated by ' ', :n_list separated by ' ',  
     			:renam_list separated by ' '                         
		From Rename_Vars;                                                
quit;       

Data NBA_Draft1; Set NBA_Draft;                                                 
	Array ch(*) $ &c_list;                                    
	Array nu(*) &n_list;                                      

	Do i = 1 To dim(ch);                                      
	  nu(i)=input(ch(i), ?? 8.);	/* ?? used to suppress invalid argument to function input warning message */                                  
	End;                                                      

Rename &renam_list;                                                                                      
Drop i &c_list;                                           
run;            

*Check Variable Types*;
Proc Contents Data = NBA_Draft1;
Run;


Proc Format;
Value $ Team 'NJN' = 'Brooklyn Nets'
			 'MIN' = 'Minnesota Timberwolves'
			 'VAN', 'MEM' = 'Memphis Grizzlies'
			 'LAC' = 'Los Angelos Clippers'
			 'CHI' = 'Chicago Bulls'
			 'ORL' = 'Orlando Magic'
			 'ATL' = 'Atlanta Hawks'
			 'NOH', 'NOK' = 'New Orleans Pelicans'
			 'CLE' = 'Cleveland Cavaliers'
			 'HOU' = 'Houston Rockets'
			 'BOS' = 'Boston Celtics'
			 'DAL' = 'Dallas Mavericks'
			 'DET' = 'Detroit Pistons'
			 'MIL' = 'Milwaukee Bucks'
			 'SAC' = 'Sacramento Kings'
			 'SEA', 'OKC' = 'Oklahoma City Thunder'
			 'CHH', 'CHA' = 'Charlotte Hornets'
			 'PHI' = 'Philadelphia 76ers'
			 'TOR' = 'Toronto Raptors'
			 'NYK' = 'New York Knicks'
			 'UTA' = 'Utah Jazz'
			 'PHO' = 'Phoenix Suns'
			 'DEN' = 'Denver Nuggets'
			 'POR' = 'Portland Blazers'
			 'IND' = 'Indiana Pacers'
			 'LAL' = 'Los Angelos Lakers'
			 'WAS' = 'Washington Wizards'
			 'SAS' = 'San Antonio Spurs'
			 'MIA' = 'Miami Heat'
			 'GSW' = 'Golden State Warriors';
Run;

Data NBA_Draft2; Set NBA_Draft1;
Where ~Missing(Pk);

	Label Draft_YR = 'Draft Years'
		  Pk = 'Pick Number'
		  Tm = 'Team'
	  	  Player = 'Player'
	  	  College = 'College Played At'
		  Yrs = 'Years in the NBA'
		  G = 'Total Games Played'
		  MP = 'Total Minutes Played'
		  PTS = 'Total Points Scored'
		  TRB = 'Total Rebounds'
		  AST = 'Total Assists'
		  FG_ = 'Field Goal Percentage'
		  _P_ = '3 Point Percentage'
		  FT_ = 'Free Throw Percentage'
		  MP_1 = 'Minutes Played Per Game'
		  PTS_1 = 'Points Per Game'
		  TRB_1 = 'Total Rebounds Per Game'
		  AST_1 = 'Assists Per Game'
		  WS = 'Win Shares over Career'
		  WS_48 = 'Win Shares Per 48 Minutes';

	Rename MP_1 = MP_PerGame
		   PTS_1 = PTS_PerGame
		   TRB_1 = TRB_PerGame
		   AST_1 = AST_PerGame
		   _P_ = _3P_;

Drop Rk BPM VORP;
Format Tm $Team.;
Run;


*Get average WS, MP, and Pts by pick*;
Proc Means Data = NBA_Draft2 Noprint;
	Class Pk;
	Var WS MP_PerGame;
	Output out = avg_Stats
		Mean(WS_48)=mean_WS Mean(MP_PerGame)=mean_MP
		Mean(PTS_PerGame)=mean_PTS;
Run;	

Proc SQL;
	*Merge average WS, MP, and PTS by pick onto each player/pick*;
	Create Table Merged_Data As
	Select D.*, 
		   W.mean_WS, W.mean_MP, mean_PTS
	From Nba_Draft2 as D,
		 avg_Stats as W
		Where D.PK = W.PK;

	*Compute difference from average for each player's respective pick*;
	Create Table Final_Data As
	Select *, (WS_48 - mean_WS) As WS_Diff Label='Win Shares Difference',
		   (PTS_PerGame - mean_PTS) as PTS_Diff Label='Points Difference',
		   (MP_PerGame - mean_MP) as MP_Diff Label='Minutes Played Difference'
		From Merged_Data 
		Order by Draft_YR, Pk;

Quit;

*Checking creation of difference variables*;
%Macro Check_Diff(Diff= ,Orig= ,Avg= );
Proc Univariate Data = Final_Data;
	Var &Diff;
	ID &Orig &Avg;
	ODS Select Extremeobs;
Run;
%Mend;

Title 'Checking Win Shares Diff for Implausible Values';
Title2 'Original WS Should be between Roughly (-2, 2)';
%Check_Diff(Diff=WS_Diff ,Orig=WS_48, Avg=mean_WS);

Title 'Checking Points Diff for Implausible Values';
Title2 'Original Points Should be between (0, ~35)';
%Check_Diff(Diff=PTS_Diff ,Orig=PTS_PerGame, Avg=mean_PTS);

Title 'Checking Minutes Diff for Implausible Values';
Title2 'Original MP Should be between (0, 48)';
%Check_Diff(Diff=MP_Diff ,Orig=MP_PerGame, Avg=mean_MP);
Title;


*Creating macro to produce rank of players by overall pick*;
%Macro Compare_Picks(Stat= ,Label= );

/*Subquerry that for each pick, takes each statistic and counts the # of obs greater than its value to produce a rank*/;
Proc SQL;
	Create Table Best_&Stat As
		Select A.Player, A.Pk, A.&Stat,
		       (Select count(distinct B.&Stat) 			
					From Final_Data as B 
					Where B.&Stat >= A.&Stat and B.Pk = A.Pk) as Rank
		From Final_Data as A
		Where calculated Rank <=3
		Order By Pk, Rank;
Quit;

Proc Transpose Data = Best_&Stat Out = Wide_&Stat Prefix=Player;
	By Pk;
	Var Player;
Run;

Title "Report of the Top 3 Players and &Label by Pick Number";
Proc Report Data =  Wide_&Stat;	
	Columns Pk ("&Label Ranked by Pick" Player1 Player2 Player3);
	Define Pk / Display "Pick";
	Define Player1 / Display "Rank 1";
	Define Player2 / Display "Rank 2";
	Define Player3 / Display "Rank 3";
Run;
Title;

%Mend;

%Compare_Picks(Stat=MP_Diff, Label=Average Minutes Played); *Minutes Played*;
%Compare_Picks(Stat=WS_Diff, Label=Average Win Shares); *Win Shares*;
%Compare_Picks(Stat=PTS_Diff, Label=Average Points); *Points*;

ODS RTF CLOSE;


*Producing Codebook*;
%Include "C:\Users\kevin\Desktop\Bios 669\Final Project\Final Project Codebook.sas";





