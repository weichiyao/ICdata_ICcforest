library(ipred)
library(survival)
library(icenReg)
library(LTRCtrees)
library(ICcforest)

source("bathtub.R")
source("Interval_width_gnrt_wint.R")
source("LossFunct.R")
source("Interpolate.R")

##############################################################################################
# === Input of the function Pred_width():
##### distribtuion:
##### --- "Bat": Bathtub
##### --- "Exp": Exponential
##### --- "Lgn": Log-normal
##### --- "WI": Weibull-increasing 
##### --- "WD": Weibull-decreasing 
##### model: underlying survival relationship
##### --- 1: tree structure
##### --- 2: linear survival relationship
##### --- 3: nonlinear survival relationship
##### C.rate: right-censoring rate
##### --- 0:  0%
##### --- 1: 20%
##### --- 2: 40%
##### --- 3: 60%
##### tt: interval width, 1-G1; 3-G2; 6-G3
##### M: number of simulations

# === Output of the function Pred_width():
##### params: L2 errors of IC cforest with different values of minsplit, minprob, minbucket,
#####         with mtry set by default

Pred_funct <- function(Nn, distribution, model, C.rate, tt, M){
  C.rate0=0
  RES.L2 <- NULL
  RES.L2$params <- data.frame(matrix(0, nrow = M, ncol = 8))
  names(RES.L2$params) <- c("Def","minsplit1","minsplit2","minprob1","minprob2",
                            "minbucket1","minbucket2","Rule")
  set.seed(101)
  sampleID <- sort(sample(100000000,M))
  for (mm in 1:M){
    mm1 = sampleID[mm]
    set.seed(mm1)
    ## create the simulation dataset 
    if(model == 1){
      DATA <- IC.generate_wint(n=Nn, Dist = distribution, Censor = C.rate0, tt)
    }else{
      DATA <- Hothorn_gnrt_width_wint(n = Nn, Model.type = model, Dist = distribution, Censor = C.rate0, tt)
    }
    
    idx_inf <- (DATA$R == Inf)
    DATA$R[idx_inf] <- 999.
    
    ## make right-censoring 
    if (C.rate == 1){
      DATA$R[sample(Nn,round(Nn*0.20))]<-999.
    } else if (C.rate == 2){
      DATA$R[sample(Nn,round(Nn*0.40))]<-999.
    } else if (C.rate == 3){
      DATA$R[sample(Nn,round(Nn*0.60))]<-999.
    }
    
    ## time points of interest to evaluate the integral
    time.uniq <- unique(sort(c(DATA$T,DATA$L,DATA$R))) 
    time.uniq <- time.uniq[time.uniq <= max(DATA$T)]
    
    Formula = as.formula(Surv(L,R,type="interval2")~X1+X2+X3+X4+X5+X6+X7+X8+X9+X10)
    
    ############################## ------------ Control ------------- ##############################
    Control = list()
    ## minsplit  -- the minimum sum of weights in a node in order to be considered for splitting. 20L
    ## minbucket -- the minimum sum of weights in a terminal node. 7L
    ## minprob   -- proportion of observations needed to establish a terminal node. 0.01
    Control[[1]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = 20L, minprob = 0.01, minbucket = 7L,
                                           mincriterion = 0)
    Control[[2]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = round(Nn*0.15), minprob = 0.01, minbucket = 7L,
                                           mincriterion = 0)
    Control[[3]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = round(Nn*0.20), minprob = 0.01, minbucket = 7L,
                                           mincriterion = 0)
    Control[[4]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = 20L, minprob = 0.05, minbucket = 7L,
                                           mincriterion = 0)
    Control[[5]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = 20L, minprob = 0.10, minbucket = 7L,
                                           mincriterion = 0)
    Control[[6]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = 20L, minprob = 0.01, minbucket = round(Nn*0.06),
                                           mincriterion = 0)
    Control[[7]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = 20L, minprob = 0.01, minbucket = round(Nn*0.08),
                                           mincriterion = 0)
    Control[[8]] = partykit::ctree_control(teststat = "quad", testtype = "Univ",
                                           minsplit = round(Nn*0.15), minprob = 0.01, minbucket = round(Nn*0.06),
                                           mincriterion = 0)
    nControl = length(Control)
    
    for (j in 1:nControl){
      IC.cforest <- ICcforest(Formula, data = DATA, mtry = ceiling(sqrt(10)), Control = Control[[j]])
      print(sprintf("L2 - IC Forest %1.0f...",j))
      Pred.IC.cforest <- predict(IC.cforest, type="prob")
      L2 <- c()
      for(i in 1:nrow(DATA)){
        Km <- Pred.IC.cforest[[i]]
        Cur <- DATA[i,"Class"]
        L2 <- c(L2, Loss.func(Cur, Km, time.uniq))
      }
      RES.L2$params[mm,j] <- mean(L2)
      rm(IC.cforest)
      rm(Pred.IC.cforest)
    }
    print("=======IC.cforest for three parameters are done...") 
  }
  return(RES.L2)
}  


##### === Comparison of IC cforest with different values of minsplit, minprob, minbucket ==== ######
##### N = 200, no right-censoring, censoring interval width generated from G1
L2.Bat.m1.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Bat", model = 1, C.rate = 0, tt = 1, M = 500)
L2.Bat.m2.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Bat", model = 2, C.rate = 0, tt = 1, M = 500)
L2.Bat.m3.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Bat", model = 3, C.rate = 0, tt = 1, M = 500)
L2.Exp.m1.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Exp", model = 1, C.rate = 0, tt = 1, M = 500)
L2.Exp.m2.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Exp", model = 2, C.rate = 0, tt = 1, M = 500)
L2.Exp.m3.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Exp", model = 3, C.rate = 0, tt = 1, M = 500)
L2.lgn.m1.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Lgn", model = 1, C.rate = 0, tt = 1, M = 500)
L2.Lgn.m2.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Lgn", model = 2, C.rate = 0, tt = 1, M = 500)
L2.Lgn.m3.c0.tt1 <- Pred_funct(Nn = 200, distribution = "Lgn", model = 3, C.rate = 0, tt = 1, M = 500)
L2.WD.m1.c0.tt1 <- Pred_funct(Nn = 200, distribution = "WD", model = 1, C.rate = 0, tt = 1, M = 500)
L2.WD.m2.c0.tt1 <- Pred_funct(Nn = 200, distribution = "WD", model = 2, C.rate = 0, tt = 1, M = 500)
L2.WD.m3.c0.tt1 <- Pred_funct(Nn = 200, distribution = "WD", model = 3, C.rate = 0, tt = 1, M = 500)
L2.WI.m1.c0.tt1 <- Pred_funct(Nn = 200, distribution = "WI", model = 1, C.rate = 0, tt = 1, M = 500)
L2.WI.m2.c0.tt1 <- Pred_funct(Nn = 200, distribution = "WI", model = 2, C.rate = 0, tt = 1, M = 500)
L2.WI.m3.c0.tt1 <- Pred_funct(Nn = 200, distribution = "WI", model = 3, C.rate = 0, tt = 1, M = 500)
