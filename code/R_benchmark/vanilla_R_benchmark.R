# needs info about path and what size of data to run on
args <- commandArgs(trailingOnly = TRUE)
PATH <- args[1]
NGENES <- args[2]
NPATIENTS <- args[3]
GEO <- paste(PATH, '/GEO-', NGENES, '-', NPATIENTS, '.txt', sep="")
GO <- paste(PATH, '/GO-', NGENES, '-', NPATIENTS, '.txt', sep="")
GENES <- paste(PATH, '/GeneMetaData-', NGENES, '-', NPATIENTS, '.txt', sep="")
PATIENTS <- paste(PATH, '/PatientMetaData-', NGENES, '-', NPATIENTS, '.txt', sep="")

regression <- function()
{
  library(Matrix)
  library(data.table)
  library(bit64)

  ptm = proc.time()

  ### Data Management ops start ###

  geo <- as.data.frame(fread(GEO))
  genes <- as.data.frame(fread(GENES))
  patients <- as.data.frame(fread(PATIENTS))

  colnames(genes) <- c("id", "target", "position", "length", "function")
  colnames(geo) <- c("geneid", "patientid", "expression value")
  colnames(patients) <- c("id", "age", "gender", "zipcode", "disease", "drug response")

  sub_gmd = genes[genes$`function` < 250,]

  # convert to data tables
  colnames(sub_gmd)[1] = "geneid"
  sub_gmd_dt = data.table(sub_gmd, key="geneid")
  geo_dt = data.table(geo, key="geneid")

  # join
  A = merge(geo_dt, sub_gmd_dt)[,c("patientid", "geneid", "expression value"), with=F]

  # store as matrix
  library(reshape2)
  A = acast(A, list(colnames(A)[1], colnames(A)[2]));
  response = patients[,"drug response"]

  ### Data management ops end ###
  cat(sprintf('Regression data management: %f\n', (proc.time() - ptm)['elapsed']))


  ########## saving out processed data
  # ptm = proc.time()
  # write.table(A, file=paste("A-", NGENES, "-", NPATIENTS, ".csv", sep=""),
  #             row.names=FALSE, col.names=FALSE, sep=",", append=FALSE)
  # cat(sprintf('Saving out processed A took: %f\n', (proc.time() - ptm)['elapsed']))

  # ptm = proc.time()
  # write.table(response, file=paste("response-", NGENES, "-", NPATIENTS, ".csv", sep=""),
  #             row.names=FALSE, col.names=FALSE, sep=",", append=FALSE)
  # cat(sprintf('Saving out processed response took: %f\n', (proc.time() - ptm)['elapsed']))

  ptm = proc.time()
  # run regression
  lm.fit(x=A, y=response)
  cat(sprintf('Regression analytics: %f\n', (proc.time() - ptm)['elapsed']))
}

covariance <- function()
{
  library(Matrix)
  library(data.table)

  ptm = proc.time()

  ### Data Management ops start ###

  load(GEO)
  load(GENES)
  load(PATIENTS)

  sub_pmd = patients[patients$disease==5,]

  # convert to data tables
  colnames(sub_pmd)[1] = "patientid"
  sub_pmd_dt = data.table(sub_pmd, key="patientid")
  geo_dt = data.table(geo, key="patientid")
  gmd_dt = data.table(genes, key='id')

  # join
  A = merge(geo_dt, sub_pmd_dt)[,c("patientid", "geneid", "expression.value"), with=F]

  # store as matrix
  library(reshape2)
  A = acast(A, list(names(A)[1], names(A)[2]));
  midtm = (proc.time() - ptm)['elapsed']
  ptm = proc.time()

  # calculate covariance
  covar = cov(A)
  cat(sprintf('Covariance analytics: %f\n', (proc.time() - ptm)['elapsed']))
  ptm = proc.time()

  covar <- which(covar>0.01*(max(covar)), arr.ind=T)
  res = merge(covar, gmd_dt, by.x='row', by.y='id')
  res = merge(res, gmd_dt, by.x='col', by.y='id')

  ### Data management ops end ###
  cat(sprintf('Regression data management: %f\n', (proc.time() - ptm)['elapsed'] + midtm))
}

biclustering<-function()
{
  library(Matrix)
  library(data.table)

  ptm = proc.time()

  ### Data Management ops start ###

  load(GEO)
  load(PATIENTS)

  sub_pmd = patients[patients$gender==1 & patients$age<=40,]

    # convert to data tables
  colnames(sub_pmd)[1] = "patientid"
  sub_pmd_dt = data.table(sub_pmd, key="patientid")
  geo_dt = data.table(geo, key="patientid")

  # join
  A = merge(geo_dt, sub_pmd_dt)[,c("patientid", "geneid", "expression.value"), with=F]

  # store as matrix
  library(reshape2)
  A = acast(A, list(names(A)[1], names(A)[2]));

  ### Data management ops end ###
  cat(sprintf('Regression data management: %f\n', (proc.time() - ptm)['elapsed']))
  return()
  ptm = proc.time()

  # run biclustering
  library(biclust)
  library("s4vd")
  biclust(A, method=BCssvd, K=1)
  cat(sprintf('Biclust analytics: %f\n', (proc.time() - ptm)['elapsed']))
}

svd_irlba <- function()
{
  library(Matrix)
  library(data.table)
  library(irlba)
  ptm = proc.time()

  ### Data Management ops start ###

  load(GEO)
  load(GENES)

  sub_gmd = genes[genes$func < 250,]

  # convert to data tables
  colnames(sub_gmd)[1] = "geneid"
  sub_gmd_dt = data.table(sub_gmd, key="geneid")
  geo_dt = data.table(geo, key="geneid")

  # join
  A = merge(geo_dt, sub_gmd_dt)[,c("patientid", "geneid", "expression.value"), with=F]

  # store as matrix
  library(reshape2)
  A = acast(A, list(names(A)[1], names(A)[2]));

  ### Data management ops end ###
  cat(sprintf('SVD data management: %f\n', (proc.time() - ptm)['elapsed']))
  ptm = proc.time()

  # run svd
  irlba(A, nu=50, nv=50, sigma="ls")
  cat(sprintf('SVD analytics: %f\n', (proc.time() - ptm)['elapsed']))
}

stats <- function()
{
  library(Matrix)
  library(data.table)
  library(multicore)
  library(doMC)
  library(foreach)

  ptm = proc.time()
  registerDoMC(16) # 16 cores

  ### Data Management ops start ###

  load(GEO)
  load(GO)

  # update code to start all ids at 1
  geo[,1] <- geo[,1]+1
  geo[,2] <- geo[,2]+1
  geo = geo[geo$patientid < 0.0025*max(geo$patientid),]
  go[,1] = go[,1] + 1
  go[,2] = go[,2] + 1

  # store as matrix
  library(reshape2)
  A = acast(geo, list(names(geo)[1], names(geo)[2]));
  go = sparseMatrix(go[,1], go[,2], x=go[,3])

  ### Data management ops end ###
  cat(sprintf('Stats data management: %f\n', (proc.time() - ptm)['elapsed']))
  return()
  ptm = proc.time()

  # run wilcox rank sum test
  foreach (ii=1:dim(go)[2]) %dopar%
  {
    foreach(jj=1:dim(A)[1]) %dopar%
    {
      set1 <- A[jj,(go[,ii] == 1)]
      set2 <- A[jj,(go[,ii] == 0)]
      wilcox.test(set1, set2, alternative="less")
    }
  }
  cat(sprintf('Stats analytics: %f\n', (proc.time() - ptm)['elapsed']))
}

print(paste('Regression: ', system.time(regression(), gcFirst=T)['elapsed'], sep=''));
# print(paste('SVD: ', system.time(svd_irlba(), gcFirst=T)['elapsed'], sep=''));
# print(paste('Covariance: ', system.time(covariance(), gcFirst=T)['elapsed'], sep=''));
# print(paste('Biclustering: ', system.time(biclustering(), gcFirst=T)['elapsed'], sep=''));
# print(paste('Stats: ', system.time(stats(), gcFirst=T)['elapsed'], sep=''));
