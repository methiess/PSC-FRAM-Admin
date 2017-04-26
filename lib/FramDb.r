################
#
# Common methods and constants for dealing with a FRAM Database
#
# Nicholas Komick
# nicholas.komick@dfo-mpo.gc.ca
# January 14, 2015
# Using: http://google-styleguide.googlecode.com/svn/trunk/google-r-style.html
#
################

kFisheryMortSqlFilename <- "./sql/FisheryMortalities.sql"
kTotalFisheryMortSqlFilename <- "./sql/TotalFisheryMortalities.sql"
kEscapementSqlFilename <- "./sql/TotalEscapement.sql"
kFramStockSqlFilename <- "./sql/FramStocks.sql"
kFramFisherySqlFilename <- "./sql/FramFisheries.sql"
kFramRunInfoSqlFilename <- "./sql/RunInfo.sql"
kFramRunTableSqlFilename <- "./sql/RunTable.sql"
kFramGetFisheryScalars <- "./sql/GetFramFisheryScalars.sql"
kFramGetRunBaseFisheries <- "./sql/GetFramRunBaseFisheries.sql"
kFramUpdateFisheryScalars <- "./sql/UpdateFramFisheryScalars.sql"
kFramGetSingleNonRetention <- "./sql/GetFramSingleNonRetention.sql"
kFramUpdateNonRetention <- "./sql/UpdateFramNonRetention.sql"
kFramInsertNonRetention <- "./sql/InsertFramNonRetention.sql"
kFramDeleteNonRetention <- "./sql/DeleteFramNonRetention.sql"
kFramBackwardEscSqlFilename <- "./sql/FramBackwardEscapement.sql"

kCohoSpeciesName <- "COHO"

kFramNonSelectiveScalarFlag <- 1
kFramNonSelectiveQuotaFlag <- 2
kFramMsfScalarFlag <- 7
kFramMsfQuotaFlag <- 8


TranslateDbColumnNames <- function(data) {
  names(data)<- gsub("_", ".", names(data)) 
  return (data)
}

RunSqlFile <- function (db.conn, file.name, variables=NA) {
  # A helper function that loads an SQL script, updates the variables in the script to values provide and
  # formats the resulting data by renames columns to common R style.
  #
  # Args:
  #   db.conn: An odbc connection to the ODBC database
  #   file.name: A file name that the SQL script is saved to
  #   variables: An R list of variables, variable names in the list are matched to ones with the same name in
  #       a format like %VARIABLENAME% (eg list(runid = 1) will replace %RUNID% in the SQL with 1)
  #
  # Returns:
  #   A data frame with query results
  #
  # Exceptions:
  #   If a variable type is found that the function can't handle (e.g. a vector), the script
  #   will throw an exception.
  #     
  file.conn <- file(file.name, "r", blocking = FALSE)
  sql.text <- paste(readLines(file.conn), collapse=" ")# empty
  close(file.conn)
  
  if (is.list(variables)) {
    var.names <- names(variables)
    
    for (var.idx in 1:length(var.names)) {
      var.name <- var.names[var.idx]
      var.value <- variables[[var.name]]
      if (is.numeric(var.value)) {
        sql.text <- gsub(paste0("%", var.name, "%"), var.value, sql.text, ignore.case=TRUE)
      } else if (is.character(var.value) || is.factor(var.value)) {
        sql.text <- gsub(paste0("%", var.name, "%"), 
                         paste0("'", as.character(var.value), "'"), 
                         sql.text, 
                         ignore.case=TRUE)
      } else {
        stop(sprintf("Unknown variable type '%s' for variable '%s' when converting in RunSqlFile", typeof(var.value), var.name))
      }
    }
  }
  
  unbound.variables <- gregexpr("%[a-z]*%", sql.text, ignore.case=TRUE)
  if (unbound.variables[[1]] > 0) {
    error.msg <- sprintf("Unbound variables found for the '%s' sql script \n", file.name)
    stop(error.msg)
  }

  data <- sqlQuery(db.conn, sql.text)
  data <- TranslateDbColumnNames(data)
  return (data)   
}

GetFramRunTable <- function (fram.db.conn, species.name) {
  # Retrieve all the FRAM runs with a run year.
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #   species.name: Limit to a specific species
  #
  # Returns:
  #   FRAM runs that have a run year specified in a dataframe
  #
  # Exceptions:
  #   None
  #    
  variables <- list(speciesname=species.name)
  data <- RunSqlFile(fram.db.conn, kFramRunTableSqlFilename, variables)
  return (data)
}

GetFramRunInfo <- function (fram.db.conn, fram.run.name) {
  # Retrieve the details about a specific FRAM run, by run name 
  #
  # Args:
  #   fram.db.conn: An ODBC connection to the FRAM database
  #   fram.run.name: The FRAM run name that details are requested for
  #
  # Returns:
  #   FRAM run details in a dataframe
  #
  # Exceptions:
  #   None
  #  
  variables <- list(runname=fram.run.name)
  data <- RunSqlFile(fram.db.conn, kFramRunInfoSqlFilename, variables)
  return (data)
}


GetFramStocks <- function (fram.db.conn) {
  # A helper function loading the list of FRAM stocks 
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #
  # Returns:
  #   None
  #
  # Exceptions:
  #   None
  #   
  data <- RunSqlFile(fram.db.conn, kFramStockSqlFilename)
  return (data)
}


GetFramFisheries <- function (fram.db.conn) {
  # A helper function loading the list of FRAM fisheries in the database
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #
  # Returns:
  #   None
  #
  # Exceptions:
  #   None
  #   
  data <- RunSqlFile(fram.db.conn, kFramFisherySqlFilename)
  return (data)
}

GetFramFisheryScalars <- function (fram.db.conn, fram.run.name) {
  # Get the dataframe of fishery scalars used to parameterize model runs
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #   run.name: The name of the model run you would like to retrive fishery scalars from
  #
  # Returns:
  #   A dataframe with the fishery scalars for a specific model run name
  #
  # Exceptions:
  #   None
  #
  variables <- list(runname=fram.run.name)
  data <- RunSqlFile(fram.db.conn, kFramGetFisheryScalars, variables)
  return (data)
}

#' Get the dataframe of valid fisheries and time steps from the base period of a specific model run
#'
#' @param fram.db.conn An odbc connection to the FRAM database
#' @param fram.run.name The name of the model run you would like to retrieve fisheries and timesteps from
#'
#' @return A dataframe with the fishery scalars for a specific model run name
#'
GetFramBaseFisheries <- function (fram.db.conn, fram.run.name) {

  variables <- list(runname=fram.run.name)
  data <- RunSqlFile(fram.db.conn, kFramGetRunBaseFisheries, variables)
  return (data)
}

UpdateFisheryScalars <- function (fram.db.conn, run.id, fishery.scalars) {
  # Update the fishery scalars and non retention values for an identified model run based on 
  # values in a dataframe.  The Non-Retention CNR mortalities updates more intellegently (e.g.
  # remove/adding/updating DB rows based on values provided and values within the database run)
  #
  # Args:
  #   fram.db.conn: An ODBC connection to the FRAM database
  #   run.id: The ID of the FRAM model run to update fishery scalars for
  #   fishery.scalars: The name of the model run you would like to retrive fishery scalars from
  #
  # Returns:
  #   A dataframe with the fishery scalars for a specific model run name
  #
  # Exceptions:
  #   None
  #
  
  for (row.idx in 1:nrow(fishery.scalars)) {
    variables <- list(runid = run.id,
                      fisheryid = fishery.scalars$fishery.id[row.idx],
                      timestep = fishery.scalars$time.step[row.idx],
                      fisheryflag = fishery.scalars$fishery.flag[row.idx],
                      nonselectivecatch = fishery.scalars$nonselective.catch[row.idx],
                      msfcatch = fishery.scalars$msf.catch[row.idx],
                      markreleaserate = fishery.scalars$mark.release.rate[row.idx],
                      markmisidrate = fishery.scalars$mark.missid.rate[row.idx],
                      unmarkmissidrate = fishery.scalars$unmark.missid.rate[row.idx],
                      markincidentalrate = fishery.scalars$mark.incidental.rate[row.idx])
    
    data <- RunSqlFile(fram.db.conn, kFramUpdateFisheryScalars, variables)
    
    
    cnr.mortalities <- as.numeric(fishery.scalars$cnr.mortalities[row.idx])
    
    variables <- list(runid = run.id,
                      fisheryid = fishery.scalars$fishery.id[row.idx],
                      timestep = fishery.scalars$time.step[row.idx])
    
    nonret.data <- RunSqlFile(fram.db.conn, kFramGetSingleNonRetention, variables)
    
    if (is.na(cnr.mortalities)) {
      if (nrow(nonret.data) > 0) {
        #remove the CNR Mortality entry
        variables <- list(runid = run.id,
                          fisheryid = fishery.scalars$fishery.id[row.idx],
                          timestep = fishery.scalars$time.step[row.idx])
        
        data <- RunSqlFile(fram.db.conn, kFramDeleteNonRetention, variables)       
      } else {
        #no data provided and no data in DB, so nothing to do.
      }
    } else {
      variables <- list(runid = run.id,
                        fisheryid = fishery.scalars$fishery.id[row.idx],
                        timestep = fishery.scalars$time.step[row.idx],
                        cnrmortalities = cnr.mortalities)
      if (nrow(nonret.data) > 0){
        
        if (cnr.mortalities != nonret.data$cnr.mortalities) {
          #Updating the CNR value becaues it has changed
          data <- RunSqlFile(fram.db.conn, kFramUpdateNonRetention, variables)     
        } else {
          #Value hasn't changed so do nothing.
        }
      } else {
        #Insert a new NonRetention row into the database.
        data <- RunSqlFile(fram.db.conn, kFramInsertNonRetention, variables)        
      }
    }
  }
  
  return ()
}


GetFramFisheryMortality <- function (fram.db.conn, run.name, run.year) {
  # A helper function loading the total mortalities for all fisheries and time steps within a FRAM model run 
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #   run.name: The name of the model run you would like to load fishery mortalities for
  #
  # Returns:
  #   A dataframe with the mortalities from the FRAM fisheries and time steps for a specific model run name
  #
  # Exceptions:
  #   The method checks the run year of the model run against a provided value, if they don't match 
  #   then the method throws an exception.
  #   
  variables <- list(runname=run.name)
  data <- RunSqlFile(fram.db.conn, kFisheryMortSqlFilename, variables)
  
  data.run.year <- unique(data$run.year)
  if (all(is.na(data$run.year))) {
    cat(sprintf("WARNING: Run name '%s' has no run year set for fishery mortality, so assume run year %d\n", run.name, run.year))
    data$run.year <- run.year
  } else if (any(data.run.year %notin% run.year)) {
    stop(sprintf("Run name '%s' has a run year that doesn't match the specified", run.name))
  }
  return (data)
}

GetFramTotalFisheryMortality <- function (fram.db.conn, run.name, run.year) {
  # A helper function loading the total mortalities for all fisheries within a FRAM model run 
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #   run.name: The name of the model run you would like to load fishery mortalities for
  #
  # Returns:
  #   A dataframe with the mortalities from the FRAM fisheries for a specific model run name
  #
  # Exceptions:
  #   The method checks the run year of the model run against a provided value, if they don't match 
  #   then the method throws an exception.
  #   
  variables <- list(runname=run.name)
  data <- RunSqlFile(fram.db.conn, kTotalFisheryMortSqlFilename, variables)

  data.run.year <- unique(data$run.year)
  if (all(is.na(data$run.year))) {
    cat(sprintf("WARNING: Run name '%s' has no run year set for fishery mortality, so assume run year %d\n", run.name, run.year))
    data$run.year <- run.year
  } else if (any(data.run.year %notin% run.year)) {
    stop(sprintf("Run name '%s' has a run year that doesn't match the specified", run.name))
  }
  return (data)
}

GetFramTotalEscapement <- function (fram.db.conn, run.name, run.year) {
  # A helper function loading the stock specific escapement from a FRAM model run 
  #
  # Args:
  #   fram.db.conn: An odbc connection to the FRAM database
  #   run.name: The name of the model run you would like to load fishery mortalities for
  #   run.year: The run year for the run name, used as a cross check when loading the data
  #
  # Returns:
  #   A dataframe with the mortalities from the FRAM fisheries for a specific model run name
  #
  # Exceptions:
  #   The method checks the run year of the model run against a provided value, if they don't match 
  #   then the method throws an exception.
  #   
  
  variables <- list(runname=run.name)
  data <- RunSqlFile(fram.db.conn, kEscapementSqlFilename, variables)

  data.run.year <- unique(data$run.year)
  if (all(is.na(data$run.year))) {
    cat(sprintf("WARNING: Run name '%s' has no run year set for escapement, so assume run year %d\n", run.name, run.year))
    data$run.year <- run.year
  } else if (any(data.run.year %notin% run.year)) {
    stop(sprintf("Run name '%s' has a run year that doesn't match the specified", run.name))
  }
  
  return (data)
}

#' A helper function retrieving the escapement values used by the backward FRAM during post-season run 
#' 
#' @param fram.db.conn An ODBC connection to the FRAM database
#' @param run.name The name of the model run you would like to retrieve backward FRAM Escapement values for
#'
#' @return A data frame with the Backward FRAM escapement data, based on the model run name provided
#'  
GetFramBackwardEscapement <- function (fram.db.conn, fram.run.name) {
 
  variables <- list(runname=fram.run.name)
  data <- RunSqlFile(fram.db.conn, kFramBackwardEscSqlFilename, variables)
  return (data)
}

LoadPscData <- function(data.dir) {
  # A function that loads the PSC stock and fishery reference tables from CSV files.  
  # The resulting tables are combined into a list
  # 
  #
  # Args:
  #   data.dir: The directory where there reference csv files are saved
  #
  # Returns:
  #   A list with the psc.stock, psc.stock.map, psc.fishery, and psc.fishery.map dataframes
  #
  # Exceptions:
  #   If any of the expected CSV files do not exist, a error is thrown.
  #    
  
  
  psc.fishery <- ReadCsv("PSCFisheries.csv", data.dir, unique.col.names=c("psc.fishery.id"))
  psc.fishery.map <- ReadCsv("PSCFisheryMap.csv", data.dir, unique.col.names=c("fram.fishery.id"))
  psc.stock <- ReadCsv("PSCStocks.csv", data.dir, unique.col.names=c("psc.stock.id"))
  psc.stock.map <- ReadCsv("PSCStockMap.csv", data.dir, unique.col.names=c("fram.stock.id"))    
  
  result.list <- list(psc.fishery = psc.fishery,
                      psc.fishery.map = psc.fishery.map,
                      psc.stock = psc.stock,
                      psc.stock.map = psc.stock.map)
  
  return (result.list)
}
