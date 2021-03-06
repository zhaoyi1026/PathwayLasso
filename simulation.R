##########################################################
# Pathway lasso
##########################################################

rm(list=ls())

source("functions.R")
source("ADMM_adp_functions.R")
source("VSS_adp_functions.R")

##########################################################
# parameter setting
k<-50

n<-50

p<-1

sigma20_1<-200^2
sigma20_2<-200^2

A.nz<-c(3,9,18,36,0,0,12,4)*c(c(1,-1,1,-1),c(1,1,-1,1))
B.nz<-c(12,4,2,1,4,9,0,0)*c(c(1,1,-1,1),c(1,-1,-1,1))
A<-matrix(c(A.nz,rep(0,k-length(A.nz))),nrow=1)
B<-matrix(c(B.nz,rep(0,k-length(B.nz))),ncol=1)
AB<-t(A)*B
C<-max(abs(AB))
C2<-C+A%*%B
D<-rbind(C,B)
##########################################################

##########################################################
# Pathway Lasso method parameters
phi<-2

rho<-1             # ADMM parameter
max.itr<-5000
tol<-1e-6
thred<-1e-6

thred2<-1e-3

omega.p<-c(0,0.1,1)      # omega = omega.p*lambda

# tuning parameter lambda
lambda<-c(10^c(seq(-5,-3,length.out=5),seq(-3,0,length.out=21)[-1],seq(0,2,length.out=11)[-1],seq(2,4,length.out=6)[-1])) # lambda values

# tuning parameter selection by variable selection stability
# kappa selection criterion parameter
n.rep<-5
vss.cut<-0.1
##########################################################

##########################################################
runonce<-function(l)
{
  ##########################################################
  # Generate data
  if(file.exists(paste0(dir.data,"/RUN_",l,"_Data.RData"))==FALSE)
  {
    set.seed(100+l)
    Z<-matrix(rbinom(n,size=1,prob=0.5),ncol=1)
    dat<-sim.data_dep(n,Z,a,b,c,Delta,Xi1,Sigma2)
    M<-dat$M
    R<-dat$R
    
    colnames(M)<-paste0("M",1:k)
    dd0<-data.frame(Z=Z,M,R=R)
    
    # standardize data
    m.Z<-mean(Z)
    m.M<-apply(M,2,mean)
    m.R<-mean(R)
    sd.Z<-sd(Z)
    sd.M<-apply(M,2,sd)
    sd.R<-sd(R)
    
    Z<-scale(Z)
    M<-scale(M)
    R<-scale(R)
    dd<-data.frame(Z=Z,M,R=R)
    
    save(list=c("dd0","dd","dat","Z","M","R","m.Z","m.M","m.R","sd.Z","sd.M","sd.R"),file=paste0(dir.data,"/RUN_",l,"_Data.RData"))
  }
  ##########################################################
  
  ##########################################################
  load(paste0(dir.data,"/RUN_",l,"_Data.RData"))
  
  run.file<-paste0(dir.data,"/RUN_",l,"_",method,".RData")
  
  if(file.exists(run.file)==FALSE)
  {
    # calculate scale back multiplier
    A.pf<-sd.Z/sd.M
    B.pf<-sd.M/sd.R
    C.pf<-sd.Z/sd.R
    AB.pf<-A.pf*B.pf
    
    re<-vector("list",length=length(lambda))
    AB.es=A.estt=B.est<-matrix(NA,k,length(lambda))
    C.est<-rep(NA,length(lambda))
    
    if(method=="Lasso")
    {
      for(i in length(lambda):1)
      {
        out<-NULL
        if(i==length(lambda))
        {
          # starting from the largest lambda value
          try(out<-mediation_net_ADMM_NC(Z,M,R,lambda=0,omega=lambda[i],phi=phi,Phi1=Phi1,Phi2=Phi2,
                                         rho=rho,rho.increase=FALSE,tol=tol,max.itr=max.itr,thred=thred,Sigma1=Sigma10,Sigma2=Sigma20,trace=FALSE))
        }else
        {
          # for smaller lambda (ith lambda), use the (i+1)th lambda results as burn-in 
          try(out<-mediation_net_ADMM_NC(Z,M,R,lambda=0,omega=lambda[i],phi=phi,Phi1=Phi1,Phi2=Phi2,
                                         rho=rho,rho.increase=FALSE,tol=tol,max.itr=max.itr,thred=thred,Sigma1=Sigma10,Sigma2=Sigma20,trace=FALSE,
                                         Theta0=matrix(c(1,A.est[,i+1]*(sd.Z/sd.M)),nrow=1),D0=matrix(c(C.est[i+1]*(sd.Z/sd.R),B.est[,i+1]*(sd.M/sd.R)),ncol=1),
                                         alpha0=matrix(c(1,A.est[,i+1]*(sd.Z/sd.M)),nrow=1),beta0=matrix(c(C.est[i+1]*(sd.Z/sd.R),B.est[,i+1]*(sd.M/sd.R)),ncol=1)))
        }
        
        if(is.null(out)==FALSE)
        {
          re[[i]]<-out
          
          # scale the estimate back to the original scale
          B.est[,i]<-out$B*(sd.R/sd.M)
          C.est[i]<-out$C*(sd.R/sd.Z)
          A.est[,i]<-out$A*(sd.M/sd.Z)
          AB.est[,i]<-A.est[,i]*B.est[,i]
        }
        
        print(paste0("lambda index ",i))
      }
    }
    if(length(grep("PathLasso-",method))>0)
    {
      omega.p.idx<-as.numeric(sub("PathLasso-","",method))
      
      for(i in length(lambda):1)
      {
        out<-NULL
        if(i==length(lambda))
        {
          # starting from the largest lambda value
          try(out<-mediation_net_ADMM_NC(Z,M,R,lambda=lambda[i],omega=omega.p[omega.p.idx]*lambda[i],phi=phi,Phi1=Phi1,Phi2=Phi2,
                                         rho=rho,rho.increase=FALSE,tol=tol,max.itr=max.itr,thred=thred,Sigma1=Sigma10,Sigma2=Sigma20,trace=FALSE))
        }else
        {
          # for smaller lambda (ith lambda), use the (i+1)th lambda results as burn-in 
          try(out<-mediation_net_ADMM_NC(Z,M,R,lambda=lambda[i],omega=omega.p[omega.p.idx]*lambda[i],phi=phi,Phi1=Phi1,Phi2=Phi2,
                                         rho=rho,rho.increase=FALSE,tol=tol,max.itr=max.itr,thred=thred,Sigma1=Sigma10,Sigma2=Sigma20,trace=FALSE,
                                         Theta0=matrix(c(1,A.est[,i+1]*(sd.Z/sd.M)),nrow=1),D0=matrix(c(C.est[i+1]*(sd.Z/sd.R),B.est[,i+1]*(sd.M/sd.R)),ncol=1),
                                         alpha0=matrix(c(1,A.est[,i+1]*(sd.Z/sd.M)),nrow=1),beta0=matrix(c(C.est[i+1]*(sd.Z/sd.R),B.est[,i+1]*(sd.M/sd.R)),ncol=1)))
        }
        
        if(is.null(out)==FALSE)
        {
          re[[i]]<-out
          
          # scale the estimate back to the original scale
          B.est[,i]<-out$B*(sd.R/sd.M)
          C.est[i]<-out$C*(sd.R/sd.Z)
          A.est[,i]<-out$A*(sd.M/sd.Z)
          AB.est[,i]<-A.est[,i]*B.est[,i]
        }
        
        print(paste0("lambda index ",i))
      }
    }
    
    save(list=c("re","AB.est","A.est","B.est","C.est","A.pf","B.pf","C.pf","AB.pf"),file=run.file)
  }
  ##########################################################
}

runonce.KSC<-function(l)
{
  if(file.exists(paste0(dir.data,"/RUN_",l,"_Data.RData")))
  {
    load(paste0(dir.data,"/RUN_",l,"_Data.RData"))
  }else
  {
    set.seed(100+l)
    Z<-matrix(rbinom(n,size=1,prob=0.5),ncol=1)
    dat<-sim.data_dep(n,Z,a,b,c,Delta,Xi1,Sigma2)
    M<-dat$M
    R<-dat$R
    
    colnames(M)<-paste0("M",1:k)
    dd0<-data.frame(Z=Z,M,R=R)
    
    # standardize data
    m.Z<-mean(Z)
    m.M<-apply(M,2,mean)
    m.R<-mean(R)
    sd.Z<-sd(Z)
    sd.M<-apply(M,2,sd)
    sd.R<-sd(R)
    
    Z<-scale(Z)
    M<-scale(M)
    R<-scale(R)
    dd<-data.frame(Z=Z,M,R=R)
    
    save(list=c("dd0","dd","dat","Z","M","R","m.Z","m.M","m.R","sd.Z","sd.M","sd.R"),file=paste0(dir.data,"/RUN_",l,"_Data.RData"))
  }
  
  run.file<-paste0(dir.data,"/RUN_",l,"_KSC_",method,".RData")
  
  if(file.exists(run.file)==FALSE)
  {
    if(method=="Lasso")
    {
      out<-NULL
      try(out<-mediation_net_ADMM_NC_KSC(Z,M,R,zero.cutoff=zero.cutoff,n.rep=n.rep,vss.cut=vss.cut,lambda=0,omega=lambda,
                                         phi=phi,Phi1=Phi1,Phi2=Phi2,rho=rho,rho.increase=FALSE,tol=tol,max.itr=max.itr,thred=thred,
                                         Sigma1=Sigma10,Sigma2=Sigma20,trace=FALSE,Theta0=NULL,D0=NULL,alpha0=NULL,beta0=NULL))
    }
    if(length(grep("PathLasso-",method))>0)
    {
      omega.p.idx<-as.numeric(sub("PathLasso-","",method))
      
      out<-NULL
      try(out<-mediation_net_ADMM_NC_KSC(Z,M,R,zero.cutoff=zero.cutoff,n.rep=n.rep,vss.cut=vss.cut,lambda=lambda,omega=omega.p[omega.p.idx]*lambda,
                                         phi=phi,Phi1=Phi1,Phi2=Phi2,rho=rho,rho.increase=FALSE,tol=tol,max.itr=max.itr,thred=thred,
                                         Sigma1=Sigma10,Sigma2=Sigma20,trace=FALSE,Theta0=NULL,D0=NULL,alpha0=NULL,beta0=NULL))
    }
    
    save(list=c("out"),file=run.file)
  }
}
##########################################################

##########################################################
L<-200

dir.data0<-paste0(getwd(),"/phi_",phi)
if(file.exists(dir.data0)==FALSE)
{
  dir.create(dir.data0)
}

method0<-c("Lasso",paste0("PathLasso-",1:length(omega.p)))

# add dependence between mediators
rho.M<-c(-0.4,0,0.4)

for(mm in 1:length(rho.M))
{
  # Covariance matrix
  Sigma1<-matrix(0,k,k)
  set.seed(10000)
  Sigma1[upper.tri(Sigma1,diag=FALSE)]<-rho.M[mm]*sigma20_1*rbinom(length(Sigma1[upper.tri(Sigma1,diag=FALSE)]),size=1,prob=1/k)
  Sigma1<-Sigma1+t(Sigma1)
  diag(Sigma1)<-rep(sigma20_1,k)
  Sigma2<-sigma20_2
  
  Sigma<-cbind(rbind(Sigma1,rep(0,k)),c(rep(0,k),Sigma2))
  
  Sigma1.chol<-chol(Sigma1)
  Xi1<-diag(diag(Sigma1.chol)^2)
  Delta<-diag(rep(1,k))-solve(Sigma1.chol/diag(Sigma1.chol))
  
  # 
  Sigma10<-diag(rep(1,k))
  Sigma20<-matrix(1,1,1)
  
  a<-A%*%(diag(rep(1,k))-Delta)
  b<-B
  c<-C
  
  tau2<-(t(B)%*%Sigma1%*%B+Sigma2)[1,1]
  Rho<-Sigma1%*%B
  
  fname<-paste0("Sim_k",k,"_corM",rho.M[mm])
  dir.data<-paste0(dir.data0,"/",fname)
  if(file.exists(dir.data)==FALSE)
  {
    dir.create(dir.data)
  }
  
  require(parallel)
  
  for(ii in 1:length(method0))
  {
    method<-method0[ii]
    
    mclapply(1:L,runonce,mc.cores=20)
  }
  
  for(ii in 1:length(method0))
  {
    method<-method0[ii]
    
    mclapply(1:L,runonce.KSC,mc.cores=20)
  }
}
##########################################################

