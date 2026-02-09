# script for install packages

required_packages <- c(
  "sf", 
  "tmap",
  "spdep",
  "spatialreg",
  "dplyr",
  "ggplot2",
  "tidyr",
  "stringr"
)

install_if_missing <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  if(length(new_packages)) {
    install.packages(new_packages)
  } else {
    message("All the packages are already installed")
  }
}

install_if_missing(required_packages)
