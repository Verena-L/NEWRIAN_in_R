####----------------------------------------------------------------------------###
####                              NEWRIAN IN R 
####                                      
####                 Verena.Lang@forst.bwl.de - R-Version 4.0.1 64Bit
####  --------------------------------------------------------------------------###

# THIS IS THE MAIN FILE
Sys.setenv(LANG="EN")
rm(list=ls())
gc()
# remotes::install_github("shoebodh/hydrusR")
list.of.packages = c("rstudioapi", "signal", "gridExtra", "stringr", "tidyr", "dplyr", "ggplot2", "optimization","matrixStats", "foreach", "doFuture", "parallel", "readr", "odbc", "DBI", "dbplyr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) {install.packages(new.packages)}
lapply(list.of.packages, require, character.only=T)


# name of the buMSIOdb in your odbc Connection list on your hardware
DBName <- "buMSIOdb"

# save the current folder to a variable to be able to come back
# R automatically inserts a second backslash, so that the directory is right
pwd <- str_remove(rstudioapi::getSourceEditorContext()$path, "run_hydrus_in_R_parallel.R")
#pwd<-"C:/NEWRIAN_IN_R/"
# define the PROJECT name of the experiment you want to evaluate
STD<-"BZE_II"

# define your working-Folders
# Still needed, cause your working with HYDRUS 1D 
# Most of the files will be deleted or imported into the db, only the plots will remain
curfol_Hyd=paste0(pwd, "Hydrus_Projektordner/", STD, "/")
curfol_results=paste0(pwd, "Ergebnisse/", STD, "/")
curfol_callH1D=paste0(pwd, "PC-Progress/Hydrus-1D4.xx/")

# check if folders already exist, if not they will be created!
dir.create(curfol_Hyd, showWarnings=F)
dir.create(curfol_results, showWarnings=F)

# copy the input Files of the general Hydrus folder to the specific STD-Hydrus-folder
dataFiles<-c("Selector.in", "ATMOSPH.IN", "PROFILE.DAT")
file.copy(file.path(paste0(pwd, "Hydrus_Projektordner/"), dataFiles, fsep= ""), curfol_Hyd, overwrite = TRUE)

# user input parameters for weighting, modelling and experiment
NL=10
W_Psi=.5
W_Q=.2
W_V=.2
W_th900=.1
W_th15000=.0
tension_depth=-1

## BOUNDARIES FOR MVG Parameter
min_Thr=0
max_Thr=0.3
min_Ths=0.31
max_Ths=0.8
min_alpha=0.001
max_alpha=1
min_n=1.01
max_n=2.6
min_ks=-5
max_ks=1
min_tau=0
max_tau=10

## load the MODELLINFO file. JOIN with PROBENINFO checks if there is already an evaluation
con <- DBI::dbConnect(odbc(), DBName) # open the connection to the database

MODELLINFO<-tbl(con, "MODELLINFO")%>%
            left_join(tbl(con, "PROBENINFO"), by="SAMPLE_NO")%>% # combine with PROBENINFO
            collect()%>%
            dplyr::filter(PROJECT== !!STD)%>% # filter charge
            dplyr::filter(YEAR>=2020)%>%
            select(1:13) # 9only select columns of MODELLINFO

# loading the Lab-Files
PROBENINFO<-tbl(con, "PROBENINFO")%>%
  collect()%>%
  dplyr::filter(PROJECT== !!STD)%>% # select the SAMPLES with the STD Project name
  dplyr::filter(!SAMPLE_NO %in% MODELLINFO$SAMPLE_NO)
  # select only not evaluated samples

dbDisconnect(con) # close the connection to the database

## select all LabNums to evaluated
all_LabNums<-unique(PROBENINFO$SAMPLE_NO)

for (k in all_LabNums){
  LabNum=k
  # check if folders already exist, if not they will be created!
  dir.create(paste0(curfol_Hyd, LabNum, "/"), showWarnings=F)
  dir.create(paste0(curfol_callH1D, "/", LabNum, "/"), showWarnings=F)
  
  source(paste0(pwd, "select_printtimes.R")) # script to prepare the MSODATA needed in Hydrus

  ## check if all the soilphysical data of the sample and the ceramic are available
  con <- DBI::dbConnect(odbc(), DBName) # open the connection to the database

  LabNrInf<-tbl(con, "KSINFO")%>%
    dplyr::left_join(tbl(con, "BODENPHYSIK"), by="SAMPLE_NO")%>%
    collect()%>%
    dplyr::filter(SAMPLE_NO==!!LabNum)
  dbDisconnect(con)
  
  if(nrow(LabNrInf)>0){
    print(paste0("Now working with sample number ", LabNum))

    # check if there are already evaluations for this sample!
    if(nrow(MODELLINFO)>0){
      simpsa_labnum_indx<-MODELLINFO%>%
        dplyr::filter(SAMPLE_NO ==!!LabNum)%>%
        dplyr::pull(TOTAL_LOOPS)
      if(length(simpsa_labnum_indx)>0){
        iter_num=simpsa_labnum_indx # if evaluations exist, the Loop counter will sum up to former calculations
      }else{iter_num=0}
    }else{iter_num=0}
  
  ## first of all we call Initial_data to obtain the inputs from the soil sample we are working with
  source(paste0(pwd, "initial_data.R"))
  curfol_Hyd<-paste0(pwd, "Hydrus_Projektordner/", STD, "/", LabNum, "/")
  
  if(WG_Start<GPV){
    LB = c(0,WG_Start,min_alpha,min_n,min_ks,min_tau)
    UB = c(WG_Ende,GPV,max_alpha,max_n,max_ks,max_tau)
  }else if (WG_Start>=GPV){
    LB = c(0,GPV,min_alpha,min_n,min_ks,min_tau)
    UB = c(WG_Ende,WG_Start,max_alpha,max_n,max_ks,max_tau)
  }else if(WG_900>0 & !is.na(WG_900)){
    UB<-c(W_900,WG_Start,max_alpha,max_n,max_ks,max_tau)
  }else{
    LB = c(min_Thr, min_Ths,min_alpha,min_n,min_ks,min_tau)
    UB = c(max_Thr, max_Ths,max_alpha,max_n,max_ks,max_tau)
  }
  
  # random VG parameter sets
  # theta_r
  Thr=seq(1.2*LB[1], .8*UB[1], (UB[1]-LB[1])/100)
  #theta_s
  if (.9*UB[2]>LB[2]){
    Ths=seq(LB[2], .9*UB[2], (UB[2]-LB[2])/100)
  }else{
    Ths=seq(LB[2], UB[2], (UB[2]-LB[2])/100)
  }
  
  alpha=seq(1.2*abs(LB[3]), .5*UB[3],(UB[3]-LB[3])/100) # avoid large initial alpha values
  n=seq(1.2*abs(LB[4]), UB[4],(UB[4]-LB[4])/100) # avoid large initial n values
  ks=seq(-0.8*abs(LB[5]), .8*UB[5],(UB[5]-LB[5])/100)  # ks logtransform.
  tau=seq(LB[6], .8*UB[6], (UB[6]-LB[6])/100)

  
  # NL is Num of loops
  # selecting 10 random numbers in the range of 1: size of VG-Parm..
  # hier nochmal überprüfen, ob ein Vektor auch geht, oder ob es eine Matrix sein muss
  initThr=sample(1:length(Thr), NL, replace=T)
  initThs=sample(1:length(Ths), NL, replace=T)
  initalpha=sample(1:length(alpha), NL, replace=T)
  initn=sample(1:length(n), NL, replace=T)
  initks=sample(1:length(ks), NL, replace=T)
  inittau=sample(1:length(tau), NL, replace=T)
  
  #make NL Start parameter-Sets
  X0all=rbind(t(Thr[initThr]), t(Ths[initThs]), t(alpha[initalpha]), t(n[initn]), t(ks[initks]), t(tau[inittau]))
  
  
  # reading lab measurements from lab files
  source(paste0(pwd, "openlabfiles.R"))
  
  # Hier eigentliche Hydrus Simulation
  ## hier muss die SIMPSA Optimierung eingebaut werden. Es werden für alle 10 Eingangsparametersets ein Annealing Simplex an die Daten durchgeführt. Daher muss in X jeweils das abhängig vom Run gespeicherte MvGSet abgepseichert sein. Für jeden dieser Runs wird ein RMSE berechnet und dann der beste Run selektiert.
  # First the Parameter Set of the Run is written in Selector.in,
  # NextStep: Run Hydrus
  # Decision if the WG900 /WG15000 values is being used
  # Calculation of the RMSE_n values / value total
  # Loading the function for the optimization runs
  source(paste0(pwd, "target.R"))
  source(paste0(pwd, "parallelization.R"))

  doFuture::registerDoFuture()
  cl <- makeCluster(parallel::detectCores())
  plan(cluster, workers = cl)
  system.time(results<-foreach(i = seq_along(1:NL),
                      .multicombine = T,
                      .errorhandling = "pass",
                      .export = ls(globalenv()),
                      .combine = 'rbind') %dopar% {  #%dopar% do in parallel; %do%: do einzeln
                        res<-parallelization(
                          X <<- X0all[,i],
                          curfol_Hyd_loop <<-  paste0(curfol_Hyd, i, "/"), # makes the value global not local to use it in second function calls
                          curfol_callH1D_loop <<- paste0(curfol_callH1D, LabNum, "/", i, "/"),
                          i2 <<- i + as.numeric(iter_num))
                        return(res)
                      })

  stopCluster(cl)
  # unlist the results file and grep all relevant lines
  results<-as.data.frame(results[grepl(LabNum, results[,1]),])
  # unlist all the columns to write the table
  results<-data.frame(lapply(results, function(x) unlist(x)))
  
  ## save the results in the simpsa_results.file, will be used for plotting and backup
  if(length(results)>0){ # if a results is produced, write it!
    write.table(results, paste0(curfol_results, "simpsa_results_", LabNum, ".txt"), row.names = F)
  }
  
  
  # prepares and seperates the results in all the output tables ready for Import to the db
  source(paste0(pwd, "output_preparation.R"))

  # plots the results
  source(paste0(pwd, "result_plots.R"))
  
  }else{ ## closes the if clause to the LabInf Files
    print(paste0('The sample number ', labmes_cur, ' does not have associated soil physical info!'))
  }
}

