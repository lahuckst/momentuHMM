
#' Confidence intervals for the natural (i.e., real) parameters
#'
#' Computes the standard errors and confidence intervals on the real (i.e., natural) scale of the data stream probability distribution parameters,
#' as well as for the transition probabilities parameters. If covariates are included in the probability distributions or TPM formula, the mean values
#' of non-factor covariates are used for calculating the natural parameters. For any covariate(s) of class 'factor', then the value(s) from the first observation 
#' in the data are used.
#'
#' @param m A \code{momentuHMM} object
#' @param alpha Significance level of the confidence intervals. Default: 0.95 (i.e. 95\% CIs).
#' @param covs Data frame consisting of a single row indicating the covariate values to be used in the calculations. 
#' If none are specified (the default), the means of any covariates appearing in the model are used 
#' (unless covariate is a factor, in which case the first factor in the data is used).
#'
#' @return A list of the following objects:
#' \item{...}{List(s) of estimates ('est'), standard errors ('se'), and confidence intervals ('lower', 'upper') for the natural parameters of the data streams}
#' \item{gamma}{List of estimates ('est'), standard errors ('se'), and confidence intervals ('lower', 'upper') for the transition probabilities}
#' \item{delta}{List of estimates ('est'), standard errors ('se'), and confidence intervals ('lower', 'upper') for the initial state probabilities}
#'
#' @examples
#' # m is a momentuHMM object (as returned by fitHMM), automatically loaded with the package
#' m <- example$m
#'
#' ci1<-CIreal(m)
#' 
#' # specify 'covs'
#' ci2<-CIreal(m,covs=data.frame(cov1=mean(m$data$cov1),cov2=mean(m$data$cov2)))
#' 
#' all.equal(ci1,ci2)
#'
#' @export
#' @importFrom MASS ginv
#' @importFrom numDeriv grad
#' @importFrom utils tail
#' @importFrom Brobdingnag as.brob sum

CIreal <- function(m,alpha=0.95,covs=NULL)
{
  if(!is.momentuHMM(m))
    stop("'m' must be a momentuHMM object (as output by fitHMM)")

  if(length(m$mod)<=1)
    stop("The given model hasn't been fitted.")

  if(alpha<0 | alpha>1)
    stop("alpha needs to be between 0 and 1.")

  nbStates <- length(m$stateNames)

  dist <- m$conditions$dist
  distnames <- names(dist)
  DMind <- m$conditions$DMind

  # identify covariates
  if(is.null(covs)){
    tempCovs <- m$data[1,]
    for(j in names(m$data)[which(unlist(lapply(m$data,function(x) any(class(x) %in% c("numeric","logical","Date","POSIXlt","POSIXct","difftime")))))]){
      tempCovs[[j]]<-mean(m$data[[j]],na.rm=TRUE)
    }
  } else {
    if(!is.data.frame(covs)) stop('covs must be a data frame')
    if(nrow(covs)>1) stop('covs must consist of a single row')
    if(!all(names(covs) %in% names(m$data))) stop('invalid covs specified')
    if(any(names(covs) %in% "ID")) covs$ID<-factor(covs$ID,levels=unique(m$data$ID))
    for(j in names(m$data)[which(!(names(m$data) %in% names(covs)))]){
      if(class(m$data[[j]])=="factor") covs[[j]] <- m$data[[j]][1]
      else covs[[j]]<-mean(m$data[[j]],na.rm=TRUE)
    }
    for(j in names(m$data)[which(names(m$data) %in% names(covs))]){
      if(class(m$data[[j]])=="factor") covs[[j]] <- factor(covs[[j]],levels=levels(m$data[[j]]))
      if(is.na(covs[[j]])) stop("check value for ",j)
    }    
    tempCovs <- covs[1,]
  }
  covs <- model.matrix(m$conditions$formula,m$data)
  nbCovs <- ncol(covs)-1 # substract intercept column

  # inverse of Hessian
  Sigma <- ginv(m$mod$hessian)
  
  tmPar <- m$mle[distnames]
  parindex <- c(0,cumsum(unlist(lapply(m$conditions$fullDM,ncol)))[-length(m$conditions$fullDM)])
  names(parindex) <- distnames
  for(i in distnames){
    if(!is.null(m$conditions$DM[[i]])){# & m$conditions$DMind[[i]]){
      tmPar[[i]] <- m$mod$estimate[parindex[[i]]+1:ncol(m$conditions$fullDM[[i]])]
      names(tmPar[[i]])<-colnames(m$conditions$fullDM[[i]])
    } else{
      if(m$conditions$dist[[i]] %in% angledists)
        if(!m$conditions$estAngleMean[[i]])
          tmPar[[i]] <- tmPar[[i]][-(1:nbStates)]
    }
  }
  
  Par <- list()
  lower<-list()
  upper<-list()
  se<-list()
  
  inputs <- checkInputs(nbStates,m$conditions$dist,tmPar,m$conditions$estAngleMean,m$conditions$circularAngleMean,m$conditions$zeroInflation,m$conditions$oneInflation,m$conditions$DM,m$conditions$userBounds,m$conditions$cons,m$conditions$workcons,m$stateNames)
  p<-inputs$p
  DMinputs<-getDM(tempCovs,inputs$DM,m$conditions$dist,nbStates,p$parNames,p$bounds,tmPar,m$conditions$cons,m$conditions$workcons,m$conditions$zeroInflation,m$conditions$oneInflation,m$conditions$circularAngleMean)
  fullDM<-DMinputs$fullDM
  
  for(i in distnames){
    if(!m$conditions$DMind[[i]]){
      par <- c(w2n(m$mod$estimate,p$bounds,p$parSize,nbStates,nbCovs,m$conditions$estAngleMean,m$conditions$circularAngleMean,m$conditions$stationary,m$conditions$cons,fullDM,m$conditions$DMind,m$conditions$workcons,1,dist[i],m$conditions$Bndind)[[i]])
    } else {
      par <- as.vector(t(m$mle[[i]]))
    }
    if(!(dist[[i]] %in% angledists) | (dist[[i]] %in% angledists & m$conditions$estAngleMean[[i]] & !m$conditions$Bndind[[i]])) {
      Par[[i]] <- get_CI(m$mod$estimate,par,m,parindex[[i]]+1:ncol(fullDM[[i]]),fullDM[[i]],DMind[[i]],p$bounds[[i]],m$conditions$cons[[i]],m$conditions$workcons[[i]],Sigma,m$conditions$circularAngleMean[[i]],nbStates,alpha,p$parNames[[i]],m$stateNames)
    } else {
      if(!m$conditions$estAngleMean[[i]])
        Par[[i]] <- get_CI(m$mod$estimate,par[-c(1:nbStates)],m,parindex[[i]]+1:ncol(fullDM[[i]]),fullDM[[i]],DMind[[i]],p$bounds[[i]],m$conditions$cons[[i]],m$conditions$workcons[[i]],Sigma,m$conditions$circularAngleMean[[i]],nbStates,alpha,p$parNames[[i]],m$stateNames)
      else {
        if(m$conditions$Bndind[[i]]){
          Par[[i]] <- CI_angle(m$mod$estimate,par,m,parindex[[i]]+1:ncol(fullDM[[i]]),fullDM[[i]],DMind[[i]],p$bounds[[i]],m$conditions$cons[[i]],m$conditions$workcons[[i]],Sigma,m$conditions$circularAngleMean[[i]],nbStates,alpha,p$parNames[[i]],m$stateNames)
        }
      }
    }
  }

  if(nbStates>1) {
    # identify parameters of interest
    i2 <- tail(cumsum(unlist(lapply(fullDM,ncol))),1)+1
    i3 <- i2+nbStates*(nbStates-1)*(nbCovs+1)-1
    wpar <- m$mle$beta
    quantSup <- qnorm(1-(1-alpha)/2)
    tempCovMat <- model.matrix(m$conditions$formula,tempCovs)
    est <- get_gamma(wpar,tempCovMat,nbStates)
    lower<-upper<-se<-matrix(NA,nbStates,nbStates)
    for(i in 1:nbStates){
      for(j in 1:nbStates){
        dN<-numDeriv::grad(get_gamma,wpar,covs=tempCovMat,nbStates=nbStates,i=i,j=j)
        se[i,j]<-suppressWarnings(sqrt(dN%*%Sigma[i2:i3,i2:i3]%*%dN))
        lower[i,j]<-1/(1+exp(-(log(est[i,j]/(1-est[i,j]))-quantSup*(1/(est[i,j]-est[i,j]^2))*se[i,j])))#est[i,j]-quantSup*se[i,j]
        upper[i,j]<-1/(1+exp(-(log(est[i,j]/(1-est[i,j]))+quantSup*(1/(est[i,j]-est[i,j]^2))*se[i,j])))#m$mle$gamma[i,j]+quantSup*se[i,j]
      }
    }
    Par$gamma <- list(est=est,se=se,lower=lower,upper=upper)
    dimnames(Par$gamma$est) <- dimnames(Par$gamma$se) <- dimnames(Par$gamma$lower) <- dimnames(Par$gamma$upper) <- list(m$stateNames,m$stateNames)
  }
  
  wpar<-m$mod$estimate
  foo <- length(wpar)-nbStates+2
  quantSup <- qnorm(1-(1-alpha)/2)
  lower<-upper<-se<-rep(NA,nbStates)
  for(i in 1:nbStates){
    dN<-numDeriv::grad(get_delta,wpar[foo:length(wpar)],i=i)
    se[i]<-suppressWarnings(sqrt(dN%*%Sigma[foo:length(wpar),foo:length(wpar)]%*%dN))
    lower[i]<-1/(1+exp(-(log(m$mle$delta[i]/(1-m$mle$delta[i]))-quantSup*(1/(m$mle$delta[i]-m$mle$delta[i]^2))*se[i])))#m$mle$delta[i]-quantSup*se[i]
    upper[i]<-1/(1+exp(-(log(m$mle$delta[i]/(1-m$mle$delta[i]))+quantSup*(1/(m$mle$delta[i]-m$mle$delta[i]^2))*se[i])))#m$mle$delta[i]+quantSup*se[i]
  }
  est<-matrix(m$mle$delta,nrow=1,ncol=nbStates,byrow=TRUE)
  lower<-matrix(lower,nrow=1,ncol=nbStates,byrow=TRUE)
  upper<-matrix(upper,nrow=1,ncol=nbStates,byrow=TRUE)  
  se<-matrix(se,nrow=1,ncol=nbStates,byrow=TRUE)
  Par$delta <- list(est=est,se=se,lower=lower,upper=upper)  
  colnames(Par$delta$est) <- m$stateNames
  colnames(Par$delta$se) <- m$stateNames
  colnames(Par$delta$lower) <- m$stateNames
  colnames(Par$delta$upper) <- m$stateNames

  return(Par)
}

get_gamma <- function(beta,covs,nbStates,i,j){
  gamma <- trMatrix_rcpp(nbStates,beta,covs)[,,1]
  gamma[i,j]
}

get_delta <- function(delta,i){
  expdelta <- exp(c(0,delta))
  if(!is.finite(sum(expdelta))){
    delta <- exp(Brobdingnag::as.brob(c(0,delta)))
    delta <- as.numeric(delta/Brobdingnag::sum(delta))
  } else {
    delta <- expdelta/sum(expdelta)
  }
  delta[i]
}

parm_list<-function(est,se,lower,upper,rnames,cnames){
  Par <- list(est=est,se=se,lower=lower,upper=upper)
  rownames(Par$est) <- rnames
  rownames(Par$se) <- rnames
  rownames(Par$lower) <- rnames
  rownames(Par$upper) <- rnames
  colnames(Par$est) <- cnames
  colnames(Par$se) <- cnames
  colnames(Par$lower) <- cnames
  colnames(Par$upper) <- cnames
  Par
}

get_CI<-function(wpar,Par,m,ind,DM,DMind,Bounds,cons,workcons,Sigma,circularAngleMean,nbStates,alpha,rnames,cnames){

  w<-wpar[ind]
  lower<-upper<-se<-numeric(nrow(DM))
  for(k in 1:nrow(DM)){
    dN<-numDeriv::grad(w2nDM,w,bounds=Bounds,DM=DM,DMind=DMind,cons=cons,workcons=workcons,nbObs=1,circularAngleMean=circularAngleMean,nbStates=nbStates,k=k)
    se[k]<-suppressWarnings(sqrt(dN%*%Sigma[ind,ind]%*%dN))
    lower[k] <- Par[k] - qnorm(1-(1-alpha)/2) * se[k]
    upper[k] <- Par[k] + qnorm(1-(1-alpha)/2) * se[k]
    #cn<-exp(qnorm(1-(1-alpha)/2)*sqrt(log(1+(se[k]/Par[k])^2)))
    #lower[k]<-Par[k]/cn
    #upper[k]<-Par[k]*cn
  }
  est<-matrix(Par,ncol=nbStates,byrow=TRUE)
  l<-matrix(lower,ncol=nbStates,byrow=TRUE)
  u<-matrix(upper,ncol=nbStates,byrow=TRUE)  
  s<-matrix(se,ncol=nbStates,byrow=TRUE)
  out <- parm_list(est,s,l,u,rnames,cnames)
  out
}

CI_angle<-function(wpar,Par,m,ind,DM,DMind,Bounds,cons,workcons,Sigma,circularAngleMean,nbStates,alpha,rnames,cnames){
  
  w<-wpar[ind]
  lower<-upper<-se<-numeric(nrow(DM))
  for(k in 1:nrow(DM)){
    dN<-numDeriv::grad(w2nDMangle,w,bounds=Bounds,DM=DM,DMind=DMind,cons=cons,workcons=workcons,nbObs=1,circularAngleMean=circularAngleMean,nbStates=nbStates,k=k)
    se[k]<-suppressWarnings(sqrt(dN%*%Sigma[ind,ind]%*%dN))
    lower[k] <- Par[k] - qnorm(1-(1-alpha)/2) * se[k]
    upper[k] <- Par[k] + qnorm(1-(1-alpha)/2) * se[k]
    #cn<-exp(qnorm(1-(1-alpha)/2)*sqrt(log(1+(se[k]/Par[k])^2)))
    #lower[k]<-Par[k]/cn
    #upper[k]<-Par[k]*cn
  }
  est<-matrix(Par,ncol=nbStates,byrow=TRUE)
  l<-matrix(lower,ncol=nbStates,byrow=TRUE)
  u<-matrix(upper,ncol=nbStates,byrow=TRUE)  
  s<-matrix(se,ncol=nbStates,byrow=TRUE)
  out <- parm_list(est,s,l,u,rnames,cnames)
  out
}
  
w2nDMangle<-function(w,bounds,DM,DMind,cons,workcons,nbObs,circularAngleMean,nbStates,k){
  
  bounds[,1] <- -Inf
  bounds[which(bounds[,2]!=1),2] <- Inf
    
  foo <- length(w) - nbStates + 1
  x <- w[(foo - nbStates):(foo - 1)]
  y <- w[foo:length(w)]
  angleMean <- Arg(x + (0+1i) * y)
  kappa <- sqrt(x^2 + y^2)
  w[(foo - nbStates):(foo - 1)] <- angleMean
  w[foo:length(w)] <- kappa
  
  w2nDM(w,bounds,DM,DMind,cons,workcons,nbObs,circularAngleMean,nbStates,k)
}