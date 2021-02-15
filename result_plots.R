## 
simpsa_results<-read.table(paste0(curfol_results, "simpsa_results_", LabNum, ".txt"), sep=" ", header=T)
colnames(simpsa_results)<-c('LabNum', 'trial', 'Year', 'Month', 'Day', 'W_15000', 'W_900', 'W_Psi', 'W_Q', 'W_V', 'Thr', 'Ths', 'alpha', 'n', 'Ks', 'tau', 'RMSE_Psi', 'RMSE_Q', 'RMSE_V', 'RMSE_WG900', 'RMSE_WG15000', 'ME_Psi', 'ME_Q', 'ME_V', 'ME_WG900', 'ME_WG15000', 'R2_Psi', 'R2_Q', 'R2_V', 'rmseQ_rmsePsi', 'rmse_1_third', 'rmse_2_third', 'rmse_3_third', 'rmseN_total')

## Frage, wenn eine Labornummer zu unterschieldichen Zeitpunkten durchgelaifen ist, welche Nummer wird dann selektiert?
simpsa_results<-simpsa_results%>%
  dplyr::filter(LabNum== !!LabNum)%>%
  distinct()

# Best Fit
simpsa_best<-simpsa_results%>%
  dplyr::filter(rmseN_total==min(rmseN_total))

#all trials in range [bestfit,1.25*bestfit]
simpsa_ran<-simpsa_results%>%
  dplyr::filter(rmseN_total<=1.25*min(rmseN_total))


LabMes_cut<-LabMes%>%
  dplyr::rename(Time=time_s, Q=kumfluss_cm, V=WG_int_cm)%>%
  mutate(Psi=log10(abs(tension_hPa)))%>%
  mutate(CALC="Lab")%>%
  select(Time, Psi, Q, V, CALC)%>%
  distinct()

Hydrus<-HYDRUSDATEN%>%
  dplyr::rename(Time=time_s, V=V_cm, Q=Q_cm, Psi=Psi_hPa)%>%
  select(Time, V, Q, Psi)%>%
  mutate(CALC="Hydrus")%>%
  mutate(Psi=log10(abs(Psi)))%>%
  dplyr::filter(Time%in% !!LabMes_cut$Time)

LabMes_cut<-LabMes_cut%>%
  dplyr::filter(Time %in% !! Hydrus$Time)

LabHyd_dif<-Hydrus%>%
  dplyr::mutate(V=!!LabMes_cut$V-V)%>%
  dplyr::mutate(Q=!!LabMes_cut$Q-Q)%>%
  dplyr::mutate(Psi=!!LabMes_cut$Psi-Psi)%>%
  mutate(CALC="diff")

BestFit<-Hydrus%>%
  rbind(LabMes_cut, LabHyd_dif)

#Volume Plot
VPlot<-ggplot(data=BestFit, aes(x=Time/3600, y=V, col=CALC))+
  geom_line(data=subset(BestFit, CALC=="Lab"))+
  geom_line(data=subset(BestFit, CALC=="Hydrus"))+
  labs(x="Duration in hours", y="V in cm", title=paste0("Labnum: ", LabNum, " -   best trial: ", simpsa_best$trial, " - RMSEn: ", round(simpsa_best$rmseN_total, 5)))+
  geom_line(data=subset(BestFit, CALC=="diff"), aes(x=Time/3600, y=V*3+1.5))+
  scale_y_continuous(limits=c(0,3),
                     sec.axis = sec_axis(~ ./3-0.5 , name = expression(paste(V[lab], " - ", V[Hydrus], " in cm", sep=""))))+
  theme_minimal()+
  theme(legend.title = element_blank(), legend.position = c(0.88,0.16),legend.text=element_text(size=9), legend.key.size = unit(3, "mm"))+
  scale_color_manual(values=c('#31B404', '#FC4E07', "#56B4E9"))


QPlot<-ggplot(data=BestFit, aes(x=Time/3600, y=Q, col=CALC))+
  geom_line(data=subset(BestFit, CALC=="Lab"))+
  geom_line(data=subset(BestFit, CALC=="Hydrus"))+
  labs(x="Duration in hours", y="Q in cm")+
  geom_line(data=subset(BestFit, CALC=="diff"), aes(x=Time/3600, y=Q*3+1.5))+
  scale_y_continuous(limits=c(0,3),
                     sec.axis = sec_axis(~ ./3-0.5 , name = expression(paste(Q[lab], " - ", Q[Hydrus], " in cm", sep=""))))+
  theme_minimal()+
  theme(legend.title = element_blank(), legend.position = c(0.88,0.84),
        legend.text=element_text(size=9), legend.key.size = unit(3, "mm"))+
  scale_color_manual(values=c('#31B404', '#FC4E07', "#56B4E9"))

PsiPlot<-ggplot(data=BestFit, aes(x=Time/3600, y=Psi, col=CALC))+
  geom_line(data=subset(BestFit, CALC=="Lab"))+
  geom_line(data=subset(BestFit, CALC=="Hydrus"))+
  labs(x="Duration in hours", y=expression(paste("pF in ", log[10], "(-hPa)", sep="")))+
  geom_line(data=subset(BestFit, CALC=="diff"), aes(x=Time/3600, y=Psi*3+1.5))+
  scale_y_continuous(limits=c(0,3),
                     sec.axis = sec_axis(~ ./3-0.5 , name = expression(paste(psi[lab], " - ", psi[Hyd], " in pF", sep=""))))+
  theme_minimal()+
  theme(legend.title = element_blank(), legend.position = c(0.88,0.16), 
        legend.text=element_text(size=9), legend.key.size = unit(3, "mm"))+
  scale_color_manual(values=c('#31B404', '#FC4E07', "#56B4E9"))

retention<-function(X){
  simpsa_best$Thr+(simpsa_best$Ths-simpsa_best$Thr)/(1+(simpsa_best$alpha*(10^X))^simpsa_best$n)^(1-1/simpsa_best$n)
}


conductivity<-function(X){
  m=1-1/simpsa_best$n
  Th=1/(1+(simpsa_best$alpha*10^X)^simpsa_best$n)^(1-1/simpsa_best$n)
  log10((10^simpsa_best$Ks)*(Th^simpsa_best$tau)*(1-(1-Th^(1/m))^m)^2)
}

# Calculate retention and conductivity curves
# X value range the functions will be plottet
pF=seq(0, 4.2, length.out=length(BestFit$Psi[BestFit$CALC=="Hydrus"]))
#retention curve of best fit
source(paste0(pwd, "retention_VG.R"))

th<-tibble(X=0) # wird eh überschrieben: Vorlagedata frame
km<-tibble(X=0) # wird eh überschrieben
#lower and upper 95% bounds 
for (i in 1:length(pF)){
  for(j in 1:length(simpsa_ran$trial)){
    th[i,j]=retention_vG(simpsa_ran$alpha[j],simpsa_ran$n[j],simpsa_ran$Thr[j],simpsa_ran$Ths[j],pF[i])
    km[i,j]=conductivity_MvG(simpsa_ran$alpha[j],simpsa_ran$n[j],simpsa_ran$Ks[j],simpsa_ran$tau[j],pF[i])
    
  }
}
# 95% confidence Interval
retention_confid<-tibble(X=pF)%>%
  mutate(MEAN=rowMeans(th))%>%
  mutate(SD=rowSds(as.matrix(th)))%>%
  mutate(th_low=MEAN-1.96*SD)%>%
  mutate(th_up=MEAN+1.96*SD)

conductivity_confid<-tibble(X=pF)%>%
  mutate(MEAN=rowMeans(km))%>%
  mutate(SD=matrixStats::rowSds(as.matrix(km)))%>%
  mutate(km_low=MEAN-1.96*SD)%>%
  mutate(km_up=MEAN+1.96*SD)

retentionPlot<-ggplot(retention_confid, aes(X))+
  stat_function(fun=retention, col="firebrick", size=1)+
  ylim(0,0.8)+
  xlim(0,4)+
  theme_bw()+
  labs(title="water retention", x="pF", y=expression(paste(theta, " in ", cm^3, cm^-3, sep="")))

conductivityPlot<-ggplot(conductivity_confid, aes(X))+
  stat_function(fun=conductivity, col="firebrick", size=1)+
  ylim(-20, 5)+
  xlim(0,4)+
  theme_bw()+
  labs(title="conductivity", x="pF", y=expression(paste("K in ", log[10], "(cm ", s^-1,")", sep="")))

# if more than one Run has been accepted, draw the confid-interval for both curves
if(length(simpsa_ran$trial)>1){
  retentionPlot<-retentionPlot+
    geom_ribbon(aes(ymin=th_low, ymax=th_up),alpha=0.3)
  conductivityPlot<-conductivityPlot+
    geom_ribbon(aes(ymin=km_low, ymax=km_up),alpha=0.3)
}

# Tabellen
Tab1<-simpsa_best%>%
  mutate("Total Runs"=NL)%>%
  select(`Total Runs`, W_V, W_Q, W_Psi, W_900, W_15000)

Tab2<-tibble(V=c(simpsa_best$RMSE_V, simpsa_best$ME_V),
             Psi=c(simpsa_best$RMSE_Psi, simpsa_best$ME_Psi),
             Q=c(simpsa_best$RMSE_Q, simpsa_best$ME_Q),
             WG900=c(simpsa_best$RMSE_WG900, simpsa_best$ME_WG900),
             WP4=c(simpsa_best$RMSE_WG15000, simpsa_best$ME_WG15000))%>%
  mutate_at(1:5, ~round(.,4))
row.names(Tab2)<-c("RMSE:", "ME:")

Tab3<-tibble("RMSE_1/3"=simpsa_best$rmse_1_third,
             "RMSE_2/3"=simpsa_best$rmse_2_third,
             "RMSE_3/3"=simpsa_best$rmse_3_third)%>%
  mutate_at(1:3, ~round(.,4))

Tab4<-tibble("Parameter"=c("alpha", "n", "log10(Ks)", "Theta_r", "Theta_s", "tau"),
             "Best Fit"=c(simpsa_best$alpha, simpsa_best$n, simpsa_best$Ks, 
                          simpsa_best$Thr, simpsa_best$Ths, simpsa_best$tau),
             "Min_value"=c(min(simpsa_ran$alpha), min(simpsa_ran$n), min(simpsa_ran$Ks), 
                           min(simpsa_ran$Thr), min(simpsa_ran$Ths), min(simpsa_ran$tau)),
             "Max_value"=c(max(simpsa_ran$alpha), max(simpsa_ran$n), max(simpsa_ran$Ks), 
                           max(simpsa_ran$Thr), max(simpsa_ran$Ths), max(simpsa_ran$tau)),
             "CV_value"=c(MVGPARMS$CV_alpha, MVGPARMS$CV_n, MVGPARMS$CV_log_Ks, MVGPARMS$CV_Thr, MVGPARMS$CV_Ths, MVGPARMS$CV_tau))%>%
  mutate_at(2:4, ~round(.,4))

hlay <- rbind(c(1,1,6,6),
              c(1,1,7,7),
              c(1,1,8,8),
              c(2,2,9,9),
              c(2,2,9,9),
              c(2,2,9,9),
              c(3,3,4,5),
              c(3,3,4,5),
              c(3,3,4,5))


pdf(paste0(curfol_results, "result_", LabNum, "_", simpsa_best$trial, ".pdf"), paper="a4r", width=11.69, height=8.27)
grid.arrange(VPlot, PsiPlot, QPlot, retentionPlot, conductivityPlot, tableGrob(Tab1, theme=ttheme_default(base_size = 12, padding = unit(c(3,3), "mm")), rows=NULL), tableGrob(Tab2, theme=ttheme_default(base_size = 12, padding = unit(c(3,3), "mm"))), tableGrob(Tab3, theme=ttheme_default(base_size = 12, padding = unit(c(3,3), "mm")), rows=NULL), tableGrob(Tab4, theme=ttheme_default(base_size = 12, padding = unit(c(3,3), "mm")), rows=NULL), layout_matrix=hlay)
dev.off()

