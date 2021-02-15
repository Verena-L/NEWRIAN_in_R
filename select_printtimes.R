##########################################################################
# This skript loads the combined mesurement files, selects the print
# times for Hydrus and stores them in the final measurement file which is
# used for the inverse routine
##########################################################################

# load the RawData from the DB
con <- DBI::dbConnect(odbc(), DBName) # open the connection to the database


RawData<-tbl(con, "MSODATEN")%>%
  dplyr::filter(SAMPLE_NO ==!!LabNum)%>%
  collect()%>%
  select(time_s, kumfluss_cm, tension_hPa, WG_int_cm, Psi_hPa)%>%
  arrange(time_s)


dbDisconnect(con)

## actions, if the 0 timestamp does not exist!
if(first(RawData$time_s)!=0){
  begin<-tibble(time_s=0)%>%
    mutate(kumfluss_cm=0,
           tension_hPa=first(RawData$tension_hPa),
           WG_int_cm=first(RawData$WG_int_cm),
           Psi_hPa=first(RawData$Psi_hPa)) # create a zero timestamp, with the replacement of the first values
  RawData<-begin%>% # add it to the RawData
    bind_rows(RawData)%>%
    arrange(time_s)
  if(first(RawData$kumfluss_cm!=0)){
    RawData<-RawData%>%
      mutate(kumfluss_cm=cumsum(c(0, diff(kumfluss_cm))))%>% # recalculate Q and WG_int
      mutate(WG_int_cm=last(WG_int_cm)+kumfluss_cm)
  }
}

## fill possible data gaps in the raw Data with the minimum time interval
seq_step<-min(diff(RawData$time_s))
# eventuelle Datenlücken zunächst mal  füllen Minutenwerten füllen
LabMes<-tibble(time_s=seq(0, max(RawData$time_s), 60))%>%
  dplyr::mutate(kumfluss_cm=approx(RawData$time_s, 
                                   RawData$kumfluss_cm, time_s, rule=1)$y)%>%
  dplyr::mutate(tension_hPa=approx(RawData$time_s, 
                                   RawData$tension_hPa, time_s, rule=1)$y)%>%
  dplyr::mutate(WG_int_cm=approx(RawData$time_s, 
                                 RawData$WG_int_cm, time_s, rule=1)$y)%>%
  dplyr::mutate(Psi_hPa=approx(RawData$time_s, 
                               RawData$Psi_hPa, time_s, rule=1)$y)%>%
  filter(!time_s%in%!!RawData$time_s)%>%
  bind_rows(RawData)%>%
  arrange(time_s)%>%
  mutate(kumfluss_cm=zoo::rollapply(kumfluss_cm, width=10, FUN=mean, 
                                    align = "center", partial = TRUE))%>%
  mutate(kumfluss_cm=cumsum(c(0,diff(kumfluss_cm))))%>%
  mutate(WG_int_cm=last(WG_int_cm)+last(kumfluss_cm))%>%
  mutate(WG_int_cm=WG_int_cm-kumfluss_cm)%>%
  mutate(time_h=floor(time_s/60/60))%>%
  mutate(diff_kum=c(0,diff(kumfluss_cm)), diff_tens=c(0, diff(tension_hPa)),
         diff_wg=c(0, diff(WG_int_cm)), diff_Psi=c(0, diff(Psi_hPa)))%>%
  mutate(DST=round(Psi_hPa/10)*10)%>%
  mutate_at(c(2,4,7,9), round, 4)%>%
  mutate_at(c(3,5,8,10), round, 3)


## eliminate negative Q values and replace them by zero change at all
LabMes<-LabMes %>%
  mutate(diff_kum=case_when(diff_kum < 0.0 ~ 0, TRUE ~ diff_kum))%>%
  mutate(kumfluss_cm=cumsum(diff_kum))%>% # do not forget adding the first value, if Q at the beginning of measurement is not zero!!
  mutate(WG_int_cm=last(WG_int_cm)+last(kumfluss_cm))%>%
  mutate(WG_int_cm=WG_int_cm-kumfluss_cm)



# extract line swith high c^hanges in Psi and also the 0 time stamp,
#  this are very important lines for the inverse routine / later calculations (tens_uK-start)
highchange<-LabMes%>%
  mutate(diff=ifelse(diff_Psi<= -2 | time_s==0, 1, 0))%>%
  dplyr::filter(diff==1)%>%
  select(-diff)

## cutting the end with no change in tension or Q 
end<-LabMes%>%
  dplyr::filter(DST==min(DST))%>%
  dplyr::filter(tension_hPa<=min(Psi_hPa)+2)%>%
  group_by(time_h)%>%
  summarise_all(mean)%>%
  dplyr::filter(diff_kum<=0.001)%>%
  ungroup()

if(nrow(end)>0){
  LabMes<-LabMes%>%
    dplyr::filter(time_h<=!!min(end$time_h))
}

## The file is now corrected and will be updated locally
#write.table(RawData[,1:5], paste0(curfol_lab, "LabMes_", LabNum, ".txt"), row.names=F)


## eliminating non and small changing values
DifMes<-LabMes%>%
  dplyr::filter(!time_s%in%!!highchange$time_s)%>%
  dplyr::filter(diff_kum!=0)%>%
  dplyr::filter(abs(diff_kum)>=0.004 | abs(diff_tens)>=0.03)%>%
  bind_rows(highchange)%>%
  arrange(time_s)%>%
  select(time_s, kumfluss_cm, tension_hPa, WG_int_cm, Psi_hPa)

## fill the gaps with 10 Minute values
reduced_DifMes<-LabMes%>%
  select(time_s, kumfluss_cm, tension_hPa, WG_int_cm, Psi_hPa)%>%
  filter(time_s%in%seq(0, max(LabMes$time_s), 15*60))%>%
  filter(!time_s%in%!!DifMes$time_s)%>%
  bind_rows(DifMes)%>%
  arrange(time_s)


# cut also the full and smoothed timeline in case there was data in "end"
RawData<-LabMes%>%
  filter(time_s<=max(LabMes$time_s))%>%
  filter(time_s!=0)%>%
  select(time_s, kumfluss_cm, tension_hPa, WG_int_cm, Psi_hPa)%>%
  arrange(time_s)

LabMes<-reduced_DifMes

rm(DifMes, reduced_DifMes)

par(mfrow=c(1,2), las=1)
plot(LabMes$time_s, LabMes$tension_hPa, pch=1, col="black", xlab="time[s]", ylab="tension[hPa]", main=LabNum)
lines(RawData$time_s, RawData$tension_hPa, col="red")

plot(LabMes$time_s, LabMes$kumfluss_cm, pch=1, col="black", xlab="time[s]", ylab="Q[cm]")
lines(RawData$time_s, RawData$kumfluss_cm, col="green")
par(mfrow=c(1,1))