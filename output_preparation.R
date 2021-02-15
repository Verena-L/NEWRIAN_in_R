## prepares the results from simulated annaeling in output-table format of the db
## after importing all the results all the files stored on the hardware will be deleted as
## well as the created and now empty folders.
# if successful: all the data has been imported from db and will be imported in the db
## only file remaining in the folder-paths will be the result graphic!

#check if there are any results from the simulated annealing process
if(length(results>0)){
  
  BEST_LOOP<-results%>%
    dplyr::filter(V34==min(V34))%>%
    pull(V2)
  
  ## 1. TABLE MODELLINFO
  MODELLINFO<-results%>%
    dplyr::select(c(1:10))%>%
    dplyr::mutate(TOTAL_LOOPS=length(V2))%>%
    dplyr::filter(V2==!!BEST_LOOP)
  
  colnames(MODELLINFO)<-c("SAMPLE_NO", "BEST_LOOP", "YEAR", "MONTH", "DAY", "WEIGHTING_WG15000", "WEIGHTING_WG900", "WEIGHTING_PSI", "WEIGHTING_Q", "WEIGHTING_V", "TOTAL_LOOPS")
  con <- DBI::dbConnect(odbc(), "buMSIOdb")
  
  odbc::dbWriteTable(conn=con, "MODELLINFO", MODELLINFO, row.names=F, append=T)
  
  #read the just imported MODELLINFO to get the automatically inserted MODELL_ID from the db!
  MODELLINFO<-tbl(con, "MODELLINFO")%>%collect()%>%filter(SAMPLE_NO==!!LabNum)%>%
      mutate(DATE=paste0(YEAR, MONTH, DAY))%>%
      filter(DATE==max(DATE, na.rm=T))
  
  ## 2. TABLE MVGPARMS
  MVGPARMS<-results%>%
    select(c(1:2, 11:16))
  
  colnames(MVGPARMS)<-c("SAMPLE_NO", "trial", "BEST_Thr", "BEST_Ths", "BEST_alpha", "BEST_n", "BEST_log_Ks", "BEST_tau")
  
  CVMVG<-MVGPARMS%>%
    group_by(SAMPLE_NO)%>%
    dplyr::summarise(CV_Thr=sd(BEST_Thr)/abs(mean(BEST_Thr))*100,
                     CV_Ths=sd(BEST_Ths)/abs(mean(BEST_Ths))*100,
                     CV_alpha=sd(BEST_alpha)/abs(mean(BEST_alpha))*100,
                     CV_n=sd(BEST_n)/abs(mean(BEST_n))*100,
                     CV_log_Ks=sd(BEST_log_Ks)/abs(mean(BEST_log_Ks))*100,
                     CV_tau=sd(BEST_tau)/abs(mean(BEST_tau))*100)%>%
    ungroup()%>%
    mutate_at(2:7, ~round(.,2))
  
  MVGPARMS<-MVGPARMS%>%
    dplyr::filter(trial==!!BEST_LOOP)%>%
    dplyr::select(-trial)%>%
    left_join(MODELLINFO%>%select(SAMPLE_NO, MODELL_ID), by="SAMPLE_NO")%>%
    left_join(CVMVG, by="SAMPLE_NO")%>%
    mutate_at(6:7, ~round(.,2))
  
  
  #ready for import:
  odbc::dbWriteTable(conn=con, "MVGPARMS", MVGPARMS, row.names=F, append=T)
  
  
  ## 3. TABLE MODELLGOF
  MODELLGOF<-results%>%
    select(1, 17:34)
  
  colnames(MODELLGOF)<-c("SAMPLE_NO", "RMSE_Psi", "RMSE_Q", "RMSE_V", "RMSE_WG900",
                         "RMSE_WG15000", "ME_Psi", "ME_Q", "ME_V", "ME_WG900", 
                         "ME_WG15000", "R2_Psi","R2_Q", "R2_V", "rmseQ_rmsePsi",
                         "rmse_1_third", "rmse_2_third", "rmse_3_third", "rmseN_total")
  
  MODELLGOF<-MODELLGOF%>%
    group_by(SAMPLE_NO)%>%
    dplyr::filter(rmseN_total==min(rmseN_total))%>%
    ungroup()%>%
    left_join(MODELLINFO%>%select(MODELL_ID, SAMPLE_NO), by="SAMPLE_NO")%>%
    mutate(R2_V=ifelse(R2_V<0, 0, R2_V))%>%
    mutate(R2_Q=ifelse(R2_Q<0, 0, R2_Q))%>%
    mutate(R2_Psi=ifelse(R2_Psi<0, 0, R2_Psi))%>%
    mutate_at(2:18, ~round(., 3))%>%
    mutate(rmseN_total=round(rmseN_total, 6))
  
  
  #ready for import:
  odbc::dbWriteTable(conn=con, "MODELLGOF", MODELLGOF, row.names=F, append=T)
  
  
  ## 4. TABLE TRIPLET
  source(paste0(pwd, "retention_VG.R"))
  TensSoll<-c(0,15,30,60,100,160,300,500,900,15000)
  

  TRIPLET<-tibble("Psi_hPa"=TensSoll,
                  "WG"=retention_vG(MVGPARMS$BEST_alpha, MVGPARMS$BEST_n, 
                                  MVGPARMS$BEST_Thr, MVGPARMS$BEST_Ths, log10(TensSoll))*100,
                 "log_Ku_cm_s"=conductivity_MvG(MVGPARMS$BEST_alpha, MVGPARMS$BEST_n,
                                              MVGPARMS$BEST_log_Ks, MVGPARMS$BEST_tau, 
                                              log10(TensSoll)),
                 "SAMPLE_NO"=MVGPARMS$SAMPLE_NO,
                 "MODELL_ID"=MVGPARMS$MODELL_ID)
  rm(TensSoll)
  
  #ready for import
  odbc::dbWriteTable(conn=con, "TRIPLET", TRIPLET, row.names=F, append=T)
  
  
  ## 5. TABLE HYDRUSDATA
  curfol_Hyd_loop<-paste0(paste0(curfol_Hyd, BEST_LOOP, "/"))
  source(paste0(pwd, "openhydfiles.R"))
  HYDRUSDATEN<-tibble("SAMPLE_NO"=MODELLINFO$SAMPLE_NO,
                      "MODELL_ID"=MODELLINFO$MODELL_ID,
                      time_s=time_Hyd,
                      V_cm=values_V_Hyd,
                      Q_cm=values_Q_Hyd,
                      Psi_hPa=values_Psi_Hyd)%>%
    mutate_at(4:5, ~round(.,4))%>%
    mutate_at(6, ~round(.,2))
  
  ## ready for import
  odbc::dbWriteTable(conn=con, "HYDRUSDATEN", HYDRUSDATEN, row.names=F, append=T)
  # closes the conncetion to the db
  dbDisconnect(con) # close the connection to the database
  
}


# delete all Files in the Hydrus-Folder to save space on hardware!
curfol_Hyd=paste0(pwd, "Hydrus_Projektordner/", STD, "/")
for (i in 1:NL){
  i2<- i + as.numeric(iter_num)
  curfol_Hyd_loop <-  paste0(curfol_Hyd, LabNum, "/", i, "/")
  do.call(file.remove, list(list.files(paste0(curfol_Hyd_loop, "/", LabNum, "/", i, "/"),                                     full.names = TRUE)))
  do.call(file.remove, list(list.files(paste0(curfol_callH1D, "/", LabNum, "/", i, "/"),                                     full.names = TRUE)))
}

# remove the empty folders
unlink(paste0("rm -r ", curfol_callH1D, "/", LabNum), recursive = T, force=T) 
unlink(paste0(pwd, "Hydrus_Projektordner/", STD, "/", LabNum), recursive = T, force=T)
unlink(paste0(curfol_callH1D, LabNum), recursive = T, force=T)
