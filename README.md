# NEWRIAN_in_R

_Background knowledge:  
Execution of the scripts is not possible without server access rights. The NEWRIAN model works from the database to the database, but could be adapted to your own individual data management._  

## 1. local folder Structure
The optimization runs in a parallelization and uses the water balance model HYDUS 1D (PC Progress). Therefore, in addition to all the R scripts provided, the following folder structures must be present. 
* the subfolder "Hydrus_Project folder":  
This folder must contain the three input files for HYDRUS 1D. These are:
    + ATMOSPH.IN
    + PROFILE.DAT
    + Selector.in  
They will be adapted to the particular test during the course of the script.  
* the subfolder "PC-Progress" with the subfolder "Hydrus-1D4.xx":  
This folder structure corresponds to the extracted installation folder. However, only the exe file for executing HYDRUS 1D in R is required in it. 
    + H1D_CALC.exe

## 2. Script structure  
The main file is "run_hydrus_in_r_parallel.R". Only this needs to be opened and executed. The ten other scripts deal with subareas, are called within the main script via source() and only have to exist in the same location. 
