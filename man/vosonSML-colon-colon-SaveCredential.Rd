% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/SaveCredential.R
\name{vosonSML::SaveCredential}
\alias{vosonSML::SaveCredential}
\alias{SaveCredential}
\alias{LoadCredential}
\title{Save and load credential information}
\usage{
SaveCredential(credential, file)

LoadCredential(file)
}
\arguments{
\item{credential}{A \code{credential} object.}

\item{file}{Character string. File name to be saved to or restored from.}
}
\value{
A \code{credential} object.
}
\description{
Functions to save and load credential information. Currently, credential information will be stored as a RDS file. 
\code{SaveCredential} will return the input \code{credential}, useful for working as a filter between 
\code{Authenticate} and \code{Collect}.
}
