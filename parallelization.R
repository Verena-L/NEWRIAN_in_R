parallelization<-function(X, curfol_Hyd_loop, curfol_callH1D_loop, i2){
  dir.create(curfol_Hyd_loop, showWarnings=F)
  dir.create(curfol_callH1D_loop, showWarnings=F)

  # copy the files
  dataFiles<-c("Selector.in", "ATMOSPH.IN", "PROFILE.DAT")
  file.copy(file.path(paste0(pwd, "Hydrus_Projektordner/", STD, "/"), dataFiles, fsep= ""), curfol_Hyd_loop, overwrite = TRUE)
  dataFiles<-c("H1D_CALC.exe")
  file.copy(file.path(curfol_callH1D, dataFiles, fsep= ""), curfol_callH1D_loop, overwrite = TRUE)
  
  # function defined in the target.R Script which calculates the RMSEN_total
  # and writing the best Parameter results in Selector.in
  loop_t0=target(X)*100
  system.time(SA<-optimization::optim_sa(fun = target, start = X, trace = TRUE,
                                         lower = LB, upper = UB,
                                         control = list(t0=loop_t0, t_min=0.000001, nlimit = 6, maxgood=10, stopac=10, r = 0.96, ac_acc = 0.05, dyn_rf = TRUE)))
    
  #r = 0.96, ac_acc = 0.05
  # Abspeichern der Run-Informationen im jeweiligen Loop-Ordner
  details<-SA$trace
  png(paste0(curfol_Hyd_loop, "SA_plot_", i2, ".png"))
  plot(SA)
  dev.off()
  write.csv2(details, paste0(curfol_Hyd_loop, "details_", i2, ".csv"))
  
  gc()
  PBEST<-SA$par
  rmseN_total<-SA$function_value
  # %Calculate ME, RMSE and R2
  source(paste0(pwd, "RMSE_ME_R2.R"))
  
  ## Calculate RMSE wg900 and wg15000(WP4)
  source(paste0(pwd, "retention_VG.R"))
  
  if (W_th900>0 & th900_lab>=0 & !is.na(th900_lab)){
    th900_Hyd = retention_vG(PBEST[3],PBEST[4],PBEST[1],PBEST[2],log10(900)) 
    RMSE_WG900 = (abs(th900_lab - th900_Hyd)/th900_lab)
  }else{
    RMSE_WG900 = NA
  }
  if (W_th15000>0 & th15000_lab>=0 & !is.na(th15000_lab)){
    th15000_Hyd = retention_vG(PBEST[3],PBEST[4],PBEST[1],PBEST[2],log10(15000)) 
    RMSE_WG15000 = (abs(th15000_lab - th15000_Hyd)/th15000_lab)
  }else{
    RMSE_WG15000 = NA
  }
  
  if(!is.na(RMSE_WG900)){ME_WG900<-th900_lab - th900_Hyd}else{ME_WG900=NA}
  if(!is.na(RMSE_WG15000)){ME_WG15000<-the15000_lab - the15000_Hyd}else{ME_WG15000=NA}
  
  # store result files
  # current date as numeric sperarated in year, monath and day
  datum=as.numeric(unlist(strsplit(as.character(Sys.Date()), "-")))
  simpsa<-c(LabNum,i2,datum[1],datum[2],datum[3],W_th15000,W_th900,W_Psi,W_Q,W_V,PBEST[1],PBEST[2],PBEST[3],PBEST[4],PBEST[5],PBEST[6],RMSE_Psi,RMSE_Q,RMSE_V, RMSE_WG900, RMSE_WG15000, ME_Psi,ME_Q,ME_V,ME_WG900, ME_WG15000,R2_Psi,R2_Q,R2_V, rmseQ_rmsePsi, rmse_1_third, rmse_2_third, rmse_3_third,rmseN_total)
  
  return(simpsa)
}


