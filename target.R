### the translation of the target3.m file ###########################
target<-function(X){
  X<-c(X[1], X[2], X[3], X[4], 10^X[5], X[6])
  # Write the Parameters X of the specific Run in the Selector.in file
  # this is the whole Change_Parameters.m File in 3 lines
  Selector<-readLines(paste0(curfol_Hyd_loop, "Selector.in"))
  Selector[29] = sprintf('   %f    %f    %f    %f    %f    %f', X[1], X[2], X[3], X[4], X[5], X[6]) # retransform alpha, n and Ks
  writeLines(Selector, paste0(curfol_Hyd_loop, "Selector.in"))
  
  
  ########### RUN HYDRUS!!!############

  setwd(curfol_callH1D_loop)
  writeLines(curfol_Hyd_loop, "LEVEL_01.DIR") # directory where the output data will be saved
  system(shQuote("H1D_CALC" , type = c("cmd")))
  system("taskkill /IM H1D_CALC.EXE",show.output.on.console=F)
  

  #####################################


  ### read in Hydrus Result Files (.OUT)
  source(paste0(pwd, "openhydfiles.R"))

    # check, if the Hyd Files could be caculated and numeric or NaN
  if(sum(is.nan(V_HydN))==0 | sum(is.nan(pF_Psi_HydN))==0 | sum(is.nan(Q_HydN))==0){
    #Calculate rmseN_V (with normalized values)
    rmseN_V = sqrt(sum((V_labN - V_HydN)^2)/length(V_labN))
    
    #calculate rmseN_Psi (with normalized values)
    rmseN_Psi = sqrt(sum((pF_Psi_labN - pF_Psi_HydN)^2)/length(pF_Psi_labN))
    
    #calculate rmseN_Q (with normalized values)
    rmseN_Q = sqrt(sum((Q_labN - Q_HydN)^2)/length(Q_labN))
    
    
    #calculate rmse_th900
    #Decide if th900_lab (which is WG_900/100) is going to be used or not:
    #if user says Y and the value is good, generate rmse_th900
    #if user says N or the value is -9999 (lost)
    #%rmse_th900 becomes  to not affect the target function
    
    source(paste0(pwd, "retention_VG.R"))
    if (W_th900>0 & th900_lab>=0 & !is.na(th900_lab)){
      th900_Hyd = retention_vG(X[3],X[4],X[1],X[2],log10(900)) 
      RMSE_WG900 = (abs(th900_lab - th900_Hyd)/th900_lab)
    }else{
      RMSE_WG900 = 0
    }
    if (W_th15000>0 & th15000_lab>=0 & !is.na(th15000_lab)){
      th15000_Hyd = retention_vG(X[3],X[4],X[1],X[2],log10(15000)) 
      RMSE_WG15000 = (abs(th15000_lab - th15000_Hyd)/th15000_lab)
    }else{
      RMSE_WG15000 = 0
    }
    
    
    ##################################################
    # target function rmseN (with normalized values)
    # W values between [0-1]
    
    rmseN_total = rmseN_Psi*W_Psi + rmseN_Q*W_Q + rmseN_V*W_V + 
                  RMSE_WG900*W_th900 + RMSE_WG15000*W_th15000
    
  }else{
    rmseN_total=NA
  }
  return(rmseN_total)
}
