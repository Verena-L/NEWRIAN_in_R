# NEWRIAN_in_R

_Background knowledge:  
Execution of the scripts is not possible without server access rights. The NEWRIAN model works from the database to the database, but could be adapted to your own individual data management._  

## 1. Pupose Of The Model  
The NEWRIAN model is used to evaluate soil samples drained in Multi-Step-Outflow (MSO) experiments, obtaining the time series of integrated water content, tension, and cumulative discharge. The objective here is to obtain the soil hydraulic parameters based on the Mualem-van Genuchten model. 
The optimization is performed by the water balance model [HYDUS 1D (PC Progress)](https://www.pc-progress.com/en/Default.aspx?H1d-downloads) and an optimization algorithm (Annealing Simplex). In HYDRUS, estimated MvG-parameters are optimized until the error between measured and modeled time series is minimal. Numerous additionally determined soil physical parameters further specify the model process and their results. All important and further information on the evaluation of the MSO experiments at Forest Research Institute Freiburg can be found in [Puhlmann et al. 2009](https://doi.org/10.1111/j.1365-2389.2009.01169.x) and [Puhlmann & Wilpert 2012](https://doi.org/10.1002/jpln.201100139).  

## 2. Local Folder Structure
The optimization runs in a parallelization and due to working with HYDRUS 1D the following local folder structures must be present additionally to all the R-scripts provided.  
* the subfolder "Hydrus_Project folder":  
This folder must contain the three input files for HYDRUS 1D. These are:
    + ATMOSPH.IN
    + PROFILE.DAT
    + Selector.in  
They will be adapted to the particular executed experiment on the soil sample during the course of the script.  
* the subfolder "PC-Progress" with the subfolder "Hydrus-1D4.xx":  
This folder structure corresponds to the extracted installation folder. However, only the exe file for executing HYDRUS 1D in R is required in it. 
    + H1D_CALC.exe

## 3. Script Structure  
The main file is "run_hydrus_in_r_parallel.R", which is the only one that has to be opened and executed. Individual subsections are processed in the additionally ten provided sub-scripts. The explanation of the NEWRIAN in R Code starts with the main file and and then moves on to the sub-files in the order in which they are called.   
### run_hydrus_inR_parallel.R
At the beginning of the main script the own local database and folder structures are defined. Individual adjustments can be made at this point. The following step defines the model parameters and the limit range for the optimization of the 6 Mualem-van-Genuchten parameters.The limit range for the MvG parameters is further restricted by information on the pore space ratios of the investigated soil sample (Total Pore Space, Water Contents at different pF Values). Depending on the number of optimization runs ("NL" default=10), sets of MvG starting parameters for optimization are selected from limit ranges.  

### select_printtimes.R



