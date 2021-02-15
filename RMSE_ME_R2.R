#rmseN_total=target(PBEST) 

# %read in Hydrus results
# [V_HydN,pF_Psi_HydN,Q_HydN] = openhydfiles4;
source(paste0(pwd, "openhydfiles.R"))

# Calculate ME
ME_V = mean(V_lab - data_V_Hyd)
ME_Psi=mean(val_pF_Psi_lab - data_pF_Psi_Hyd)
ME_Q=mean(Q_lab - data_Q_Hyd)

# Calculate RMSE
N_V=length(V_lab)
RMSE_V = sqrt(sum((V_lab - data_V_Hyd)^2)/N_V)
N_Psi=length(val_pF_Psi_lab)
RMSE_Psi = sqrt((sum((val_pF_Psi_lab - data_pF_Psi_Hyd)^2))/N_Psi)
N_Q=length(Q_lab)
RMSE_Q = sqrt(sum((Q_lab - data_Q_Hyd)^2)/N_Q)

# Calculate R²

# Calculate R²
# changed accordingto Puhlnmann und Wilpert 2012, Nash-Sutcliff 
R2_V = 1-(sum((V_lab - data_V_Hyd)^2)/((N_V/(N_V-1))*(sum(V_lab^2))))
R2_Psi=1-(sum((val_pF_Psi_lab - data_pF_Psi_Hyd)^2)/((N_Psi/(N_Psi-1))*(sum(val_pF_Psi_lab^2))))
R2_Q=1-(sum((Q_lab - data_Q_Hyd)^2)/((N_Q/(N_Q-1))*(sum(Q_lab^2))))


## check Q/Psi: Provides indication of leakage during the test
rmseQ_rmsePsi<-RMSE_Q/RMSE_Psi

## calculate the rmse in thirds for the timeline, to check which part of the test could be moddeled in which quality
if (N_V==N_Q & N_V==N_Psi){
  N_third<-round(N_Q/3)
}else{
  N_third<-round(mean(N_V/3, N_Psi/3, N_Q/3))
}

# if V is not part of the evaluation process
rmse_1_third<-sqrt(sum((val_pF_Psi_lab[1:N_third] - data_pF_Psi_Hyd[1:N_third])^2)/N_third) + 
  sqrt(sum((Q_lab[1:N_third] - data_Q_Hyd[1:N_third])^2)/N_third)

rmse_2_third<-sqrt(sum((val_pF_Psi_lab[N_third:(2*N_third)] - data_pF_Psi_Hyd[N_third:(2*N_third)])^2)/N_third) + 
  sqrt(sum((Q_lab[N_third:(2*N_third)] - data_Q_Hyd[N_third:(2*N_third)])^2)/N_third)

rmse_3_third<-sqrt(sum((val_pF_Psi_lab[(2*N_third):length(val_pF_Psi_lab)] - data_pF_Psi_Hyd[(2*N_third):length(data_pF_Psi_Hyd)])^2)/N_third) + 
  sqrt(sum((Q_lab[(2*N_third):length(Q_lab)] - data_Q_Hyd[(2*N_third):length(data_Q_Hyd)])^2)/N_third)

# regarding V
if(W_V>0){
  rmse_1_third<-rmse_1_third+sqrt(sum((V_lab[1:N_third] - data_V_Hyd[1:N_third])^2)/N_third)
  rmse_2_third<-rmse_2_third+sqrt(sum((V_lab[N_third:(2*N_third)] - data_V_Hyd[N_third:(2*N_third)])^2)/N_third)
  rmse_3_third<-rmse_3_third+sqrt(sum((V_lab[(2*N_third):length(V_lab)] - data_V_Hyd[(2*N_third):length(data_V_Hyd)])^2)/N_third)
  
}