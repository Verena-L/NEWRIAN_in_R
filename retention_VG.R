retention_vG=function(a,n,thr,ths,pF){
  th=thr+(ths-thr)/(1+(a*(10^pF))^n)^(1-1/n)
  return(th)
}


conductivity_MvG<-function(a,n,ks,tau,pf){
  m=1-1/n
  Th=1/(1+(a*10.^pf)^n)^(1-1/n) 
  km=(10^ks)*(Th^tau)*(1-(1-Th^(1/m))^m)^2
  return(log10(km))
}


