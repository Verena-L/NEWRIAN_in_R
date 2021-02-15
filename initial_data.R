## schauen ob man es nochmal braucht Sys.setenv(LANG="EN")
## select all the relevant values from soil physik and ceramic plate - former LabInfo File
keramik_ks<-as.numeric(LabNrInf$Keramik_Ks_cm_s)
Tens_uK_Start<-as.numeric(first(LabMes$tension_hPa)+(4.7+tension_depth))
WG_Ende<-as.numeric(LabNrInf$WG_Ende)/100
WG_Start<-as.numeric(LabNrInf$WG_Start)/100
if(WG_Start!=round(WG_Ende+(last(LabMes$kumfluss_cm)/4),4)){
  WG_Start<-round(WG_Ende+(last(LabMes$kumfluss_cm)/4),4)
  con <- DBI::dbConnect(odbc(), "buMSIOdb")
  dbSendQuery(con, paste0("UPDATE BODENPHYSIK SET WG_Start = ", WG_Start*100, " WHERE SAMPLE_NO = ", LabNum, ";"))
  DBI::dbDisconnect(con)
}
GPV<-as.numeric(LabNrInf$GPV)/100
WG_900<-as.numeric(LabNrInf$WG_900)/100
WG_15000<-as.numeric(LabNrInf$WG_15000)/100
seq_step<-min(diff(RawData$time_s)) # minimal time interval in RawData
# prepare constant time stamp and Psi value for the ATMOSPH-IN FILE


# filter the zero value of time, cause HYDRUS can't calculate 0 timestamp and it was only needed for the calculation of Tens_uK-Start which is done!
LabMes<-LabMes%>%
  filter(time_s!=0)

# decide if WG900  will be used in the following calaculations or not
if (W_th900>0 & WG_900>0 & !is.na(WG_900)){
  th900_lab = WG_900
}else{
  th900_lab = NA;
}

# decide if WG15000  will be used in the following calaculations or not
if (W_th15000>0 & WG_15000>0 & !is.na(WG_15000)){
  th15000_lab = WG_15000
}else{
  th15000_lab = NA;
}



# LabMes File selected and cutted to important time stamps in select_printtimes.R
tMax = as.numeric(LabMes[length(LabMes$time_s), 1])
ptimes<-LabMes$time_s


#in "Selector" array we can find all lines from "Selector.in" file
#each line is a character 
#we will convert these lines in numeric parameters
#line 28 -> parameters names
#line 29 -> soil parameters value 
#line 30 -> ceramic plate parameters value
#line 33 -> time an dprint information
Selector<-readLines(paste0(curfol_Hyd, "Selector.in"))

param_ceramic=Selector[30]
param_print=Selector[33]
param_steps=Selector[37]
#create the matrix called parameters
#in this matrix, the first row are going to be the values from the soil
#parameters, the second row the values from the ceramic plate parameters

# extracting words
ceramics<-unlist(str_split(param_ceramic, "[[:blank:]]"))
ceramics<-as.numeric(ceramics[ceramics!=""])
printtimes=unlist(str_split(param_print, "[[:blank:]]"))
printtimes<-as.numeric(printtimes[printtimes!=""])

# read the initial and final time
# the final time will change in each soil saple, we should have it as a
# varibale in order to be able to change it
times = Selector[35]
tInit = unlist(str_split(times, "[[:blank:]]"))[1]
tMax = as.character(tMax)

# change lines
# get the vector to change

#!!! warum werden die soilparams erst eingelesen, extrahiert, dann nicht verändert und dann einfach wieder in die ursprüngliche Datei zurück geschrieben?
plateparam = ceramics #ceramic parameters
plateparam[5] = keramik_ks
param_print = printtimes;
param_print[8] = min(1000, length(ptimes))

# change the vectors we previously get to charachter
newline1 = sprintf('   %f    %f    %f    %f    %e    %f', plateparam[1], plateparam[2], plateparam[3], plateparam[4], plateparam[5], plateparam[6]);
newline2 = sprintf('   %6.5f    %6.5f    %5.1f    %3.2f    %3.2f    %3.2f    %3.2f    %7.0f', param_print[1], param_print[2], param_print[3], param_print[4], param_print[5], param_print[6], param_print[7], param_print[8])

#these two following variables are already charachter, just introduce the page break (\r\n)
newline3 = paste0(tInit, "    ", tMax)
# adapt the print interval to the LabDat
newline4 = sprintf("     t           10           %i       f", seq_step)

#finally replace the line in archive_sel for the corresponding new line
Selector[30] = newline1
Selector[33] = newline2
Selector[35] = newline3
Selector[37] = newline4

#long rows of print times in selector.in are porblematic --> better write in matrix format

# Hydrus allows only for 1000 explicit print steps, remaining print steps are
# in fixed time interval
# es stehen immer zwanzig Zahlen in einer Reihe der Selector.In Datei
# Ans Ende wird der Ende-String der InputDatei eingefügt
for (k in 1:min(50, ceiling(length(ptimes)/20))){
  Selector[38+k]<-str_replace_all(toString(as.character(ptimes[(20*(k-1)+1):(20*k)])), ",", "  ")
  Selector[38+k+1]<-c('*** END OF INPUT FILE SELECTOR.IN ************************************')
}

# Unvollständige Reihe in die NA-Werte eingesetzt wurden, wird gekürzt!
if(k==ceiling(length(ptimes)/20) & grepl("NA", Selector[38+k])){
  Selector[38+k]<-str_replace_all(Selector[38+k], "   NA", "")
}

# if the original Data was longer than the new one, cut it to new length
Selector<-Selector[1:(38+k+1)]
writeLines(Selector, paste0(curfol_Hyd, "Selector.in"))


############### END EDITING SELECTOR.IN Data ############################


### BEGIN: EDITING PROFILE.dat############################################

#We have the variable Tens_uK_Start we got from the file LabNrInf, now we have to overwrite it in the file Profile.dat
# open the file
Profile<-readLines(paste0(curfol_Hyd, "Profile.dat")) # original file
# used in the next section seperating header and matrix

# Matrix is immer so lang wie die Originaldatei - die ersten 5 und die letzten 2 Zeilen
prof_matrix<-read.table(paste0(curfol_Hyd, "Profile.dat"), skip=5, nrows=length(Profile)-7)

# depth (z) of each Node -> we will use it later in target.m
ZNode = prof_matrix[,2]
LZNode = length(ZNode)

# change the values in the matrix prof_matrix to change values in column h
# values h for x=tensio_depth, is always the same (Tens_uK_Start)
# tension_depth is the point when tension in measured (usually x=-1cm)
# value of h in ceramic plate (x=-4.01 and -4.7) always are 0

## tension_depth=globale Variable; wo wird diese erstellt??
ID_Node = prof_matrix[which(prof_matrix[,2]==tension_depth),1] # Die -1 steht an dritter Stelle
# value Tens_uK_Start from LabNrInf refers to lower boundary of soil sample; 
# value needs to be transfered to 1cm measuring depth
prof_matrix[ID_Node,3]=Tens_uK_Start+(prof_matrix[length(prof_matrix[,2]),2]-tension_depth);
prof_matrix[LZNode,3]=Tens_uK_Start

#interpolate
x=c(prof_matrix[ID_Node,2], prof_matrix[LZNode-1,2])
h=c(prof_matrix[ID_Node,3], prof_matrix[LZNode-1,3])

for (i in seq(ID_Node+1, LZNode-1)){
  y=prof_matrix[i,2]
  prof_matrix[i,3]=signal::interp1(x,h,y,'linear')
  end
}


# extrapolate
yi=prof_matrix[1:(ID_Node-1),2]
prof_matrix[1:(ID_Node-1),3]= signal::interp1(x,h,yi,'linear','extrap')

# once we have change the matrix, write it to the file
# only changing the matrix Part and keep the rest unchanged
for(i in 1:nrow(prof_matrix)){
  Profile[i+5]<-sprintf('   %i     %1.2f            %1.4f       %i      %i       %1.1f           %1.1f            %1.1f           %1.1f',prof_matrix[i,1], prof_matrix[i,2], prof_matrix[i,3], prof_matrix[i,4], prof_matrix[i,5], prof_matrix[i,6], prof_matrix[i,7], prof_matrix[i,8], prof_matrix[i,9])
}

writeLines(Profile, paste0(curfol_Hyd, 'Profile.dat'))

###### END EDITING PROFILE.DAT########################################
#### BEGIN EDITING ATMOSPH.IN ###########################

# only reading the table and skipping all the header rows (9)
ATMOS<-readLines(paste0(curfol_Hyd, 'ATMOSPH.in'))
header<-ATMOS[1:9]
# Create a regular time interval between the start and end of the measurement for the lower boundary condition
tatmo<-seq(min(LabMes$time_s), max(LabMes$time_s, na.rm=T), seq_step)
# interpolate Psi using the new time vector
Psiatmo<-approx(LabMes$time_s, LabMes$Psi_hPa, tatmo, rule=2)$y
# rule=2 is for extrapolation of the start Psi value

# create new matrix of boundary condition for the Psi value
ATMOS_matrix<-as.data.frame(matrix(0, ncol=8, nrow=length(tatmo)))
#substitute the 1st and 7th column from Atmosph_matrix with 1st and 7th column from LabMesMatrix (time, Psi)
ATMOS_matrix<-ATMOS_matrix%>%
  mutate(V1=tatmo)%>% # same time column 
  mutate(V7=Psiatmo) # same tension


# open the file ATMPSH and write the new matrix Atmosph_matrix
ATMOS<-header

for (k in 1:nrow(ATMOS_matrix)){
  ATMOS[k+9]<-sprintf('    %1.2f          %i           %i          %i          %i            %i         %1.3f          %i',ATMOS_matrix[k,1], ATMOS_matrix[k,2], ATMOS_matrix[k,3], ATMOS_matrix[k,4], ATMOS_matrix[k,5], ATMOS_matrix[k,6], ATMOS_matrix[k,7], ATMOS_matrix[k,8])
  ATMOS[k+10]<-'end*** END OF INPUT FILE ATMOSPH.IN **********************************'
}


writeLines(ATMOS, paste0(curfol_Hyd, "ATMOSPH.in"))



###################### ENDE SKRIPT INITIAL_DATA_3.m##############################################

#delete all variables which are not needed any more
# variables needed after initial_data
# WG_Ende, WG_Start, GPV, LZNODE, the900_lab, th15000_lab, WG_900, WG_15000
rm(tMax, seq_step, ptimes, tInit, times, param_ceramic, param_print,param_steps, plateparam, printtimes, newline1, newline2, newline3, newline4, x, h, yi, prof_matrix, tatmo, Psiatmo, ATMOS_matrix, header, y)