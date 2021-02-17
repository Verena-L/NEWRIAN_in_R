# NEWRIAN_in_R - READ ME

_Background knowledge:  
Execution of the scripts is not possible without server access rights. The NEWRIAN model works from the database to the database, but could be adapted to your own individual data management._  

## 1. script structure
The main file is "run_hydrus_in_r_parallel.R". Only this needs to be opened and executed. The ten other scripts deal with subareas, are called within the main script via source() and only have to exist in the same location. 
