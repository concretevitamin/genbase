library(data.table)
args <- commandArgs(trailingOnly = TRUE)
PATH <- args[1]
NGENES <- args[2]
NPATIENTS <- args[3]
GEO <- paste(PATH, '/GEO-', NGENES, '-', NPATIENTS, sep="")
GO <- paste(PATH, '/GO-', NGENES, '-', NPATIENTS, sep="")
GENES <- paste(PATH, '/GeneMetaData-', NGENES, '-', NPATIENTS, sep="")
PATIENTS <- paste(PATH, '/PatientMetaData-', NGENES, '-', NPATIENTS, sep="")
TXT <- '.txt'
RDATA <- '.Rdata'

geo <- fread(paste(GEO, TXT, sep=""))
save(geo, file=paste(GEO, RDATA, sep=""))

go <- fread(paste(GO, TXT, sep=""))
save(go, file=paste(GO, RDATA, sep=""))

genes <- fread(paste(GENES, TXT, sep=""))
save(genes, file=paste(GENES, RDATA, sep=""))

patients <- fread(paste(PATIENTS, TXT, sep=""))
save(patients, file=paste(PATIENTS, RDATA, sep=""))
