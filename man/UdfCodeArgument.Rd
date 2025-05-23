% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/argument_types.R
\name{UdfCodeArgument}
\alias{UdfCodeArgument}
\title{UdfCodeArgument class}
\value{
Object of \code{\link[R6:R6Class]{R6::R6Class()}} is an argument that expects an UDF code or a file path.
}
\description{
Inheriting from \link{Argument} in order to represent the UDF code that will be executed in a UDF call. The script has to
be passed as a character string or as a local file path from which the script can be loaded.
}
\seealso{
\link{Array}, \link{Integer}, \link{EPSGCode}, \link{String}, \link{Number},
\link{Date}, \link{DataCube}, \link{ProcessGraphArgument},
\link{ProcessGraphParameter}, \link{OutputFormatOptions}, \link{GeoJson},
\link{Boolean}, \link{DateTime}, \link{Time}, \link{BoundingBox}, \link{Kernel},
\link{TemporalInterval}, \link{TemporalIntervals}, \link{CollectionId}, \link{OutputFormat},
\link{AnyOf}, \link{ProjDefinition}, \link{UdfCodeArgument}, \link{UdfRuntimeArgument} and
\link{UdfRuntimeVersionArgument}, \link{MetadataFilter}
}
