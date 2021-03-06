% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/CIreal.R
\name{CIreal}
\alias{CIreal}
\title{Confidence intervals for the natural (i.e., real) parameters}
\usage{
CIreal(m, alpha = 0.95, covs = NULL)
}
\arguments{
\item{m}{A \code{momentuHMM} object}

\item{alpha}{Significance level of the confidence intervals. Default: 0.95 (i.e. 95\% CIs).}

\item{covs}{Data frame consisting of a single row indicating the covariate values to be used in the calculations. 
For any covariates that are not specified using \code{covs}, the means of the covariate(s) are used 
(unless the covariate is a factor, in which case the first factor in the data is used). By default, no covariates are specified.}
}
\value{
A list of the following objects:
\item{...}{List(s) of estimates ('est'), standard errors ('se'), and confidence intervals ('lower', 'upper') for the natural parameters of the data streams}
\item{gamma}{List of estimates ('est'), standard errors ('se'), and confidence intervals ('lower', 'upper') for the transition probabilities}
\item{delta}{List of estimates ('est'), standard errors ('se'), and confidence intervals ('lower', 'upper') for the initial state probabilities}
}
\description{
Computes the standard errors and confidence intervals on the real (i.e., natural) scale of the data stream probability distribution parameters,
as well as for the transition probabilities parameters. If covariates are included in the probability distributions or TPM formula, the mean values
of non-factor covariates are used for calculating the natural parameters. For any covariate(s) of class 'factor', then the value(s) from the first observation 
in the data are used.
}
\examples{
# m is a momentuHMM object (as returned by fitHMM), automatically loaded with the package
m <- example$m

ci1<-CIreal(m)

# specify 'covs'
ci2<-CIreal(m,covs=data.frame(cov1=mean(m$data$cov1),cov2=mean(m$data$cov2)))

all.equal(ci1,ci2)

}
