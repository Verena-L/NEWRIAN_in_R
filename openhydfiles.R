# total = sum Vz for t_initial

numlines = length(readLines(paste0(curfol_Hyd_loop, "Obs_Node.out")))
starnumber<-sum(stringr::str_count(readLines(paste0(curfol_Hyd_loop, "Obs_Node.out"))[1:2], "\\*"))

if (numlines != 12){
  ##chekcken ob 14 sterne im Datenstaz vorkommen, wenn ja, dann mach das???? what?
  if(starnumber<=14){
    dataNode=read.table(paste0(curfol_Hyd_loop, "Obs_Node.out"),skip=11, nrows=numlines-12)
    time_Hyd = round(dataNode[,1])
    ## Volume ######
    # last two Nodes are the ceramic plate, not the soil.
    Vz=dataNode[,1:(LZNode-2)]
    for (k in 1:(LZNode-2)){
      Vz[,k]<-((dataNode [,3*k] + dataNode[,3*(k+1)])/2)*(ZNode[k]-ZNode[k+1])
    }
    values_V_Hyd = rowSums(Vz) # jede Reihe aufummiert
  
    ## PSI  #######
    # 8th column in the Obs.Node File is the theta of the Node 3 which is the depth -1 cm
    hcol = 1 + 3*(ID_Node - 1)+1 
    values_Psi_Hyd = dataNode[,hcol]
    pF_Psi_Hyd = log10(abs(dataNode[,hcol]))

    ## Q ##########
    # Q from hydrus -> convert in cum
    values_Q_Hyd=cumsum(abs(dataNode[,length(dataNode[1,])]*c(0, diff(time_Hyd))))
    # match the data, making the times to coincide
    # if times already coincide
    if (length(time_V_lab)==length(time_Hyd)){
      if (sum(time_V_lab-time_Hyd)==0){
        V_labN = values_V_labN
        V_lab = values_V_lab
        data_V_Hyd = values_V_Hyd
      }
    }else{
        V_labN = values_V_labN
        V_lab = values_V_lab
        data_V_Hyd = values_V_Hyd[which(time_Hyd %in% time_V_lab)]
    }
    if (length(time_pF_Psi_lab)==length(time_Hyd)){
      if (sum(time_pF_Psi_lab-time_Hyd)==0){
        pF_Psi_labN = values_pF_Psi_labN
        val_pF_Psi_lab = pF_Psi_lab
        data_pF_Psi_Hyd = pF_Psi_Hyd
        data_Psi_Hyd = values_Psi_Hyd
      }
    }else{
       pF_Psi_labN = values_pF_Psi_labN
       val_pF_Psi_lab = pF_Psi_lab
       data_pF_Psi_Hyd = pF_Psi_Hyd[which(time_Hyd%in%time_pF_Psi_lab)]
       data_Psi_Hyd = values_Psi_Hyd[which(time_Hyd%in%time_pF_Psi_lab)]
    }
    
    # Q
    if (length(time_Q_lab)==length(time_Hyd)){
      if(sum(time_Q_lab-time_Hyd)==0){
        Q_labN = values_Q_labN
        Q_lab = values_Q_lab
        data_Q_Hyd = values_Q_Hyd
      }
    }else{
      Q_labN = values_Q_labN ## stimmt das wirklich
      Q_lab = values_Q_lab
      data_Q_Hyd = values_Q_Hyd[which(time_Hyd%in%time_Q_lab)]
    }
    

    
    ####################################################
    
    #  Normalization
    V_HydN = ((data_V_Hyd - V_min_lab)/(V_max_lab - V_min_lab))
    pF_Psi_HydN = ((data_pF_Psi_Hyd - pF_Psi_min_lab) / (pF_Psi_max_lab - pF_Psi_min_lab))
    Q_HydN = ((data_Q_Hyd - Q_min_lab) / (Q_max_lab - Q_min_lab))
    
   
  }else{
    V_HydN = NaN
    pF_Psi_HydN = NaN
    Q_HydN = NaN 
  }

}
