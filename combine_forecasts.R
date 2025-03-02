combine_forecasts <- function(folder, input_oxygen, input_temperature, output_file) {
  # Combine oxygen and temperature forecasts
  
  # Load required libraries
  library(tidyverse)
  library(glue)
  
  # Download the forecast files
  faasr_get_file(remote_folder = folder, remote_file = input_oxygen, local_file = "oxygen_fc.csv")
  faasr_get_file(remote_folder = folder, remote_file = input_temperature, local_file = "temperature_fc.csv")
  
  # Read the forecasts
  oxygen_fc <- read_csv("oxygen_fc.csv")
  temperature_fc <- read_csv("temperature_fc.csv")
  
  # Combine the forecasts
  forecast <- bind_rows(oxygen_fc, temperature_fc)
  
  # Generate the output filename following EFI naming conventions
  forecast_file <- "forecast_combined.csv"
  write_csv(forecast, forecast_file)
  
  # Create the properly named file for EFI submission
  efi_filename <- glue::glue("aquatics-{date}-benchmark_rw.csv.gz",
                             date = Sys.Date())
  write_csv(forecast, efi_filename)
  
  # Upload both files to S3
  faasr_put_file(local_file = forecast_file, remote_folder = folder, remote_file = output_file)
  faasr_put_file(local_file = efi_filename, remote_folder = folder, remote_file = efi_filename)
  
  # Log message
  log_msg <- paste0('Function combine_forecasts finished; outputs written to folder ', folder, ' in default S3 bucket')
  faasr_log(log_msg)
}