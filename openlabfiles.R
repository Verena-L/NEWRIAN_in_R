####################BEGINN Openlabfiles.m##########################################################

## hier wird mit den LabFiles gearbeitet, die aber bereits im Skript davor geladen wurden
LabMes_Normalized<-as.data.frame(LabMes)%>%
  dplyr::filter(!is.na(WG_int_cm) & !is.na(tension_hPa)&
                  !is.na(kumfluss_cm) & !is.na(Psi_hPa))

## V

values_V_lab = LabMes_Normalized[,4]
time_V_lab = LabMes_Normalized[,1]
V_min_lab = min(values_V_lab, na.rm=T)
V_max_lab = max(values_V_lab, na.rm=T)
values_V_labN =((values_V_lab - V_min_lab)/ (V_max_lab - V_min_lab)) # Normalisation

## PF
pF_Psi_lab = log10(abs(LabMes_Normalized[,3]))
time_pF_Psi_lab = LabMes_Normalized[,1]
pF_Psi_min_lab=min(pF_Psi_lab, na.rm=T)
pF_Psi_max_lab=max(pF_Psi_lab, na.rm=T)
values_pF_Psi_labN =((pF_Psi_lab - min(pF_Psi_lab, na.rm=T))/ (max(pF_Psi_lab, na.rm=T) - min(pF_Psi_lab, na.rm=T))) # Normalisation

## Q
values_Q_lab = LabMes_Normalized[,2]
time_Q_lab = LabMes_Normalized[,1]
Q_min_lab = min(values_Q_lab, na.rm=T)
Q_max_lab = max(values_Q_lab, na.rm=T)
values_Q_labN =((values_Q_lab - Q_min_lab) / (Q_max_lab - Q_min_lab))

###################### ENDE Openlabfiles.m ##############################################

