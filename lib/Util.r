################
#
# General Utility Functions for R scripts for FRAM Admin
#
# Nicholas Komick
# nicholas.komick@dfo-mpo.gc.ca
# May 22, 2014
# Coding Style: http://google-styleguide.googlecode.com/svn/trunk/google-r-style.html
#
#
################

###____ Constants Section ____####

kNAChar <- as.character(NA)
kNANumber <- as.numeric(NA)
kUnspecified <- "Unspecified"

"%notin%" <- Negate("%in%")

prev.loaded.src.files <- c()


GetTimeStampText <- function() {
  # Provides a standardized text based time stamp for inclusion in file names
  #
  # Args:
  #   None
  #
  # Returns:
  #   A string with the current date and time
  #
  # Exceptions:
  #   None
  #  	
  current.time <- Sys.time()
  return (format(current.time, "%Y%m%d_%H%M%S"))
}

LoadSourceFile <- function (source.file.name) {
  source.fname.full <- normalizePath(source.file.name)
  if (source.fname.full %notin% prev.loaded.src.files) {
    source(source.fname.full)
  } else {
    cat(sprintf("Skip loading '%s', previously loaded.", source.file.name), sep = "\n")
  }
}

InstallRequiredPackages <- function (required.packages) {
    new.packages <- required.packages[!(required.packages %in% installed.packages()[,"Package"])]
    if(length(new.packages)) {
        install.packages(new.packages, dependencies=TRUE)
    }

    for (package.name in required.packages) {
        require(package.name, character.only = TRUE)
    }
} 

TitleCase <- function(text) {
  #Got this regex from: http://stackoverflow.com/questions/15776732/how-to-convert-a-vector-of-strings-to-title-case
  #This function could use \\E (stop capitalization) rather than \\L (start lowercase), depending on what rules you want to follow
  return (gsub("\\b([a-z])([a-z]+)", "\\U\\1\\L\\2" ,text, perl=TRUE))
}

FormatInt <- function(values) {
  fmt.values <- rep("", length(values))
  #Don't combine with else, these if statements should cascade without elses connecting them.
  if (is.factor(value)) {
    value <- as.character(value)
  }
  if (is.character(value)) {
    value <- as.numeric(value)
  }

  if (is.numeric(value)) {
    has.value <- !is.na(value)
    round.value <- round(value[has.value])
    fmt.values[has.value] <- formatC(round.value, format="d", big.mark=',')
  } else {
    stop("Unknown type for values when calling FormatInt")
  }
  
  return (fmt.values)
}

FormatDouble <- function(value, decimals) {
  fmt.value <- rep("", length(value))
  #Don't combine with else, these if statements should cascade without elses connecting them.
  if (is.factor(value)) {
    value <- as.character(value)
  }
  if (is.character(value)) {
    value <- as.numeric(value)
  }
  
  if (is.numeric(value)) {
    has.value <- !is.na(value)
    round.value <- round(value[has.value], decimals)
    if (round.value == 0) {
      fmt.value[has.value] <- "0.0"
    } else {
      fmt.value[has.value] <- formatC(round.value, digits=1, format="f")
    }
    
  } else {
    stop("Unknown type for values when calling FormatInt")
  }
  
  return (fmt.value)
}

GetTimeStampText <- function() {
	# Provides a standardized text based time stamp for inclusion in file names
	#
	# Args:
	#   None
	#
	# Returns:
	#   A string with the current date and time
	#
	# Exceptions:
	#   None
	#  	
	current.time <- Sys.time()
	return (format(current.time, "%Y%m%d_%H%M%S"))
}


WriteProtectedCsv <- function (data, file.name) {
	# A helper function for writing CSV files and setting them to readonly for protection.  
	# When writing the file, the file is first set to writable then written over then set to readonly
	#
	# Args:
	#   data: Data frame to be written to CSV file
	#   file.name: File name to write CSV file to
	#
	# Returns:
	#   None
	#
	# Exceptions:
	#   None
	#   

	Sys.chmod(file.name, mode = "0777", use_umask=TRUE)
	write.csv(data, file=file.name, row.names=FALSE)
	#Make the file read-only to prevent accidental modificaiton/deletion
	Sys.chmod(file.name, mode = "0444", use_umask=TRUE)
}


ReadCsv <- function (file.name, data.dir, unique.col.names = NA) {
  data <- read.csv(file=file.path(data.dir,file.name), header=TRUE, stringsAsFactors=FALSE)
  
  if (!is.na(unique.col.names)) {
    col.names <- names(data)
    invalid.col.names <- col.names[unique.col.names %notin% col.names]
    if (length(invalid.col.names) > 0) {
      error.msg <- paste0("The '%s' file does not contain the following column names for unique checking: ", paste(invalid.col.names, collapse=","))
      stop(error.msg)
    }
    
    uniq.data <- data[, names(data) %in% unique.col.names]
    
    if (is.data.frame(uniq.data)) {
      if (nrow(unique(uniq.data)) != nrow(uniq.data)) {
        error.msg <- sprintf("The '%s' file as non-unique data based on the following columns: ", file.name, paste(unique.col.names, collapse=","))
        stop(error.msg)        
      }
      
      if (length(unique(uniq.data)) != length(uniq.data)) {
        error.msg <- sprintf("The '%s' file as non-unique data based on the following columns: ", file.name, paste(unique.col.names, collapse=","))
        stop(error.msg)         
      }
    }
  }
  return (data)
}

WriteCsv <- function(file.name, data) {
  write.csv(data, file=file.name, row.names=FALSE, na="")
}


ValidateValueDomain <- function (values, domain, error.message="The following values are invalid:\n\n%s\n\n") {
	# A helper function for validating data within a perdefined set of possible values.  
	#
	# Args:
	#   values: The data that is to be validated 
	#   domain: The set of valid values that "values" can take on.
	#   error.message: A template of a printf message for invalid values.
	#
	# Returns:
	#   None
	#
	# Exceptions:
	#   If the values vector contains values that are not in the domain vector, then the method calls stop
	#   with an error message using the template provide in the "error.message" parameter.

	invalid.values <- values %notin% domain
	if (any(invalid.values)) {
		invalid.values <- values[invalid.values]
		invalid.values <- unique(invalid.values)
		stop(sprintf(error.message, paste(invalid.values, collapse=", ")))
	} 
}

LoadConfigFiles <- function (report.config.file="report_config.r") {
	current.dir <- normalizePath(getwd())

	if (is.na(report.config.file) == FALSE) {
		source(report.config.file)
	}	
}

