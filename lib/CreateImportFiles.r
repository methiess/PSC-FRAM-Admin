################
#
# Code to export a file that can be used as a template to update a particular person's catch data.
#
# Nicholas Komick
# nicholas.komick@dfo-mpo.gc.ca
# February 9, 2016
# Using: http://google-styleguide.googlecode.com/svn/trunk/google-r-style.html
#
################

rm(list=ls())   		#clean up the workspace
header <- "Create Agency Import File Tool v0.1a alpha"

# Column names: Fishery ID, Fishery Name, Time Step ID, Flag ID, Non-Selective Catch, MSF Catch, CNR Mortality


source.lib.dir <- "./lib/"
if (exists("lib.dir")) {
  source.lib.dir <- lib.dir
} 


if (exists("report.dir") == FALSE) {
  report.dir <- "./report/"
}

if (exists("data.dir") == FALSE) {
  data.dir <- "./data/"
}

source(file.path(source.lib.dir, "Util.r"))
source(file.path(source.lib.dir, "FramDb.r"))

required.packages <- c("RODBC", "dplyr")
InstallRequiredPackages(required.packages)

cmdArgs <- commandArgs(TRUE)
if(length(cmdArgs) > 0) {
  print(cmdArgs)
} else {
  cat("No command line parameters provided.\n")
}

config.file.name <- cmdArgs[1]

if (length(cmdArgs) == 0) {
  config.file.name <- "./config/create_import_config.r"
}

LoadConfigFiles(report.config.file=config.file.name)

cat(header)
cat("\n")

fram.db.conn <- odbcConnectAccess(fram.db.name)
base.fishery <- GetRunBaseFisheries(fram.db.conn, fram.run.name)

fishery.scalars <- GetFisheryScalars(fram.db.conn, fram.run.name)
fishery.scalars <- select(fishery.scalars, -one_of("fishery.name"))

odbcClose(fram.db.conn)

fishery.scalars <- left_join(base.fishery, fishery.scalars, by=c("run.id", "fishery.id", "time.step"))
arrange(fishery.scalars, run.id, fishery.id, time.step)


person.fishery <- ReadCsv("PersonFisheries.csv", data.dir, unique.col.names=c("fishery.id"))
fishery.scalars <- merge(fishery.scalars, person.fishery, by=c("fishery.id"))

fram.run.id <- unique(fishery.scalars$run.id)
#fishery.scalars <- select(fishery.scalars, -one_of("run.id"))
if (length(fram.run.id) > 1) {
  stop("ERROR - there is more then one run found, this is a major issue to debug")
}

unique.person <- unique(person.fishery$person.name)
unique.person <- unique.person[nchar(unique.person) > 0]

for (person.name in unique.person) {
  person.fishery.scalars <- fishery.scalars[tolower(fishery.scalars$person.name) == tolower(person.name),]
  person.fishery.scalars <- person.fishery.scalars[ , names(person.fishery.scalars) %notin% c("run.name", "person.name")]
  import.file.name <- sprintf("./report/%s catch.csv", person.name)
  
  import.file <- file(import.file.name, "w+")
  
  cat(paste0("Person Name:", person.name, "\n"), file = import.file)
  cat(paste0("FRAM Run Name:", fram.run.name, "\n"), file = import.file)
  cat(paste0("FRAM Run ID:", fram.run.id, "\n"), file = import.file)
  cat(paste0("FRAM DB Name:", fram.db.name, "\n"), file = import.file)
  cat("-------------------------------------------------------------\n", file = import.file)
  
  tmp.file.name <- sprintf("./report/%s.tmp", person.name)
  WriteCsv(tmp.file.name, person.fishery.scalars)
  tmp.file <- file(tmp.file.name, "r")
  catch.csv.text <- readLines(con=tmp.file)
  cat(paste0(catch.csv.text, collapse="\n"), file = import.file)
  close(tmp.file)
  unlink(tmp.file.name)
  
  close(import.file)
}


