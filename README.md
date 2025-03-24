# Building and Deploying Ecological Forecasts with neon4cast and FaaSr

In this tutorial, we will run a [neon4cast package](https://github.com/eco4cast/neon4cast) example locally and deploy using a FaaSr-ready workflow. 


## Prerequisites
- A Github account
- A Github personal access token (PAT)
- Rstudio on either a [Posit cloud account](https://posit.cloud/) (which you can login with GitHub), or [Docker installed in your computer](https://docs.docker.com/get-started/) (You can also use your own Rstudio; however, the Posit cloud and Rocker approaches are recommended for reproducibility),
- a Minio S3 bucket (you can use the [Play Console](https://min.io/docs/minio/linux/administration/minio-console.html#minio-console) to use a public/unauthenticated server)

* You can explore the Console using https://play.min.io:9443. Log in with the following credentials:
```
Username: Q3AM3UQ867SPQQA43P2F
Password: zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG
```

While you can use your existing GitHub PAT if you have one, it is recommended that you create a short-lived GitHub PAT token for this tutorial if you plan to use Posit Cloud. [Detailed instructions to create a PAT are available here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic); in summary:

* In the upper-right corner of any page, click your profile photo, then click Settings.
* In the left sidebar, click Developer settings.
* In the left sidebar, click Personal access tokens (Classic).
* Click Generate new token (Classic); *note: make sure to select Classic*
* In the "Note" field, give your token a descriptive name.
* In scopes, select “workflow” and “read:org” (under admin:org). 
* Copy and paste the token; you will need to save it to a file in your computer for use in the tutorial



# Part I: Running a neon4cast example manually

In this part, we will download and process the target data for aquatics in order to create forecast for different variables from the target data.

### Install the development version of neon4cast
```
# install.packages("remotes")
remotes::install_github("eco4cast/neon4cast")
```
###  Load required libraries

```
library(neon4cast)
library(tidyverse)
library(fable)
library(tsibble)
```

### Download and process the target data for aquatics

```
 # Download target data
  target <- read_csv("https://data.ecoforecast.org/neon4cast-targets/aquatics/aquatics-targets.csv.gz")
  
  # Process data
  aquatic <- target %>% 
    pivot_wider(names_from = "variable", values_from = "observation") %>%
    as_tsibble(index = datetime, key = site_id)
  
  # Save the full dataset
  write_csv(aquatic %>% as_tibble(), "aquatic_full.csv")
  
  # Create blinded dataset (drop last 35 days)
  blinded_aquatic <- aquatic %>%
    filter(datetime < max(datetime) - 35) %>% 
    fill_gaps()
```


### Create forecasts

```
# A simple random walk forecast, see ?fable::RW
oxygen_fc <- blinded_aquatic %>%
  model(benchmark_rw = RW(oxygen)) %>%
  forecast(h = "35 days") %>%
  efi_format()

## also use random walk for temperature
temperature_fc <- blinded_aquatic  %>% 
  model(benchmark_rw = RW(temperature)) %>%
  forecast(h = "35 days") %>%
  efi_format_ensemble()


```

### Combine forecasts and export file to local

```
# stack into single table
forecast <- bind_rows(oxygen_fc, temperature_fc) 

## Write the forecast to a file following EFI naming conventions:
forecast_file <- glue::glue("{theme}-{date}-{team}.csv.gz",
                            theme = "aquatics", 
                            date=Sys.Date(),
                            team = "benchmark_rw")
write_csv(forecast, forecast_file)
```

# Part II: Deploy a simple FaaSr workflow.

## Objectives

In this part, we will learn how to configure the working environment and deploy a simple FaasR workflow that is prebuilt for you.

## Clone the FaaSr tutorial repo

First let's clone the FaaSr tutorial repo - copy and paste this command in the terminal:

```
system('git clone https://github.com/dekkov/neon4cast_faasr.git')
```

Click on FaaSr-Tutorial folder on the lower right window (Files), then

Select More > Set as Working Directory from the drop-down menu.



## Source the script that sets up FaaSr and dependences

Run one of the following commands, depending on your setup (Posit, or local Docker). Fair warning: it will take a few minutes to install all dependences:

## For Posit Cloud:

```
source('posit_setup_script')
```


## Configure Rstudio to use GitHub Token

Within Rstudio, configure the environment to use your GitHub account (replace with your username and email). Input this into the console:

```
usethis::use_git_config(user.name = "YOUR_GITHUB_USERNAME", user.email = "YOUR_GITHUB_EMAIL")
```

Now set your GitHub token as a credential for use with Rstudio - paste your token to the pop-up window that opens with this command pasted into the console:

```
credentials::set_github_pat()
```

## Configure the FaaSr secrets file with your GitHub token

Open the file named faasr_env in the editor. You need to enter your GitHub token here: replace the string "REPLACE_WITH_YOUR_GITHUB_TOKEN" with your GitHub token, and save this file. 

The secrets file stores all credentials you use for FaaSr. You will notice that this file has the pre-populated credentials (secret key, access key) to access the Minio "play" bucket.

## Configure the FaaSr JSON workflow

Head over to files tab and open `neon_workflow.json`. This is where we will decide the workflow for our project. Replace YOUR_GITHUB_USERNAME with your actual github username in the username of ComputeServer section. A workflow has been configured for you, shown in the image attached below. For more information, please refer to [this schema](https://github.com/FaaSr/FaaSr-package/blob/main/schema/FaaSr.schema.json).

![image](https://github.com/user-attachments/assets/da1f0143-9387-431c-b466-818ddd943d67)



## Register and invoke the simple workflow with GitHub Actions

Now you're ready for some Action! The steps below will:

* Use the faasr function in the FaaSr library to load the neon_workflow.json and faasr_env in a list called neon4cast_tutorial
* Use the register_workflow() function to create a repository called FaaSr-tutorial in GitHub, and configure the workflow there using GitHub Actions
* Use the invoke_workflow() function to invoke the execution of your workflow

Enter the following commands to your console:

```
neon4cast_tutorial<- faasr(json_path="neon_workflow.json", env="faasr_env")
neon4cast_tutorial$register_workflow()
```

When prompted, select "public" to create a public repository. Now run the workflow:

```
neon4cast_tutorial$invoke_workflow()
```




# Part III: Build a FaaSr workflow by yourself.

## Objectives

This tutorial will help you get familiar with creating your own FaaSr functions. You are provided a sample workflow in neon_workflow.json that creates a combined forecast using the Random Walk method. We will follow the same workflow as in part II using the Mean method and register it in the JSON file.


## Configure the FaaSr JSON workflow

Head over to files tab and open `neon_workflow.json`. This is where we will decide the workflow for our project. First, replace YOUR_GITHUB_USERNAME with your actual github username in the username of ComputeServer section. This tutorial will guide you to deploy a workflow as below.


<img width="980" alt="image" src="https://github.com/user-attachments/assets/478be2af-2755-48d6-9714-4a269d6383a0" />


### Function Pipeline
1. getData:
- Download and process aquatic dataset and upload it to S3
- This function will act as the starting point for our workflow, invoking both oxygenForecastMean and temperatureForecastMean next.
2. oxygenForecastMean:
- Use the filtered dataset to create Oxygen forecast using Mean method and upload it to S3
- Invoke combined forecast next.
3. temperatureForecastMean:
- Use the filtered dataset to create Temperature forecast using Mean method and upload it to S3
- Invoke combined forecast next.
4. combineForecastMean:
- Download the 2 forecasts file from S3 to generate a combined forecast and store it in S3
- This function doesn't invoke any function after, meaning this is the end of our workflow.

### Add function to the workflow JSON file
After that, navigate to the FunctionList section, you will notice the getData function has been given to you. This function will put 2 files `aquatic_full.csv` and `aquatic_blinded.csv` onto S3. The `aquatic_blinded.csv` will be needed as we create functions for oxygenForecastMean and temperatureForecastMean. 

### oxygenForecastMean
First, create an R script for to generate oxygen forecast. It will download `aquatic_blinded.csv` from S3 using the `faasr_get_file` function, generate a forecast file called `oxygen_fc_mean.csv`, and upload it back to S3 for use in the combined function with the help of `faasr_put_file`. Here’s the R script:

```
create_oxygen_forecast_mean <- function(folder, input_file, output_file) {
  # Create oxygen forecast using random walk model
  
  # Load required libraries
  library(neon4cast)
  library(tidyverse)
  library(fable)
  library(tsibble)
  
  # Download the blinded dataset
  faasr_get_file(remote_folder = folder, remote_file = input_file, local_file = "blinded_aquatic.csv")
  
  # Read the dataset and convert to tsibble
  blinded_aquatic <- read_csv("blinded_aquatic.csv") %>%
    as_tsibble(index = datetime, key = site_id)
  
  # Create oxygen forecast
  oxygen_fc <- blinded_aquatic %>%
    model(benchmark_mean = MEAN(oxygen)) %>%
    forecast(h = "35 days") %>%
    efi_format()
  
  # Save the forecast
  write_csv(oxygen_fc, "oxygen_fc_mean.csv")
  
  # Upload the forecast to S3
  faasr_put_file(local_file = "oxygen_fc_mean.csv", remote_folder = folder, remote_file = output_file)
  
  # Log message
  log_msg <- paste0('Function create_oxygen_forecast finished; output written to ', folder, '/', output_file, ' in default S3 bucket')
  faasr_log(log_msg)
}
```

Now that we have the R function, let's modify the oxygenForecastMean function in neon_workflow.json. Replace "R_FUNCTION_NAME" with create_oxygen_forecast_mean. Next, we will need to add  "input_file": "blinded_aquatic.csv" and "output_file": "temperature_fc_mean.csv" to the "Argument" section. Finally, since we want to invoke combineForecastMean next, add "InvokeNext": "combineForecastMean". Your finalized JSON function should look like this:
```
"oxygenForecastMean": {
            "FunctionName": "create_oxygen_forecast_mean",
            "FaaSServer": "My_GitHub_Account",
            "Arguments": {
                "folder": "neon4cast",
                "input_file": "blinded_aquatic.csv",
                "output_file": "oxygen_fc_mean.csv"
            },
            "InvokeNext": "combineForecastMean"
        },
```

### temperatureForecastMean

The process for temperatureForecastMean should be similar to oxygenForecastMean. Your final R script and JSON function should be as below:

create_temperature_forecast_mean.R
```
create_temperature_forecast_mean <- function(folder, input_file, output_file) {
  # Create temperature forecast using random walk model
  
  # Load required libraries
  library(neon4cast)
  library(tidyverse)
  library(fable)
  library(tsibble)
  
  # Download the blinded dataset
  faasr_get_file(remote_folder = folder, remote_file = input_file, local_file = "blinded_aquatic.csv")
  
  # Read the dataset and convert to tsibble
  blinded_aquatic <- read_csv("blinded_aquatic.csv") %>%
    as_tsibble(index = datetime, key = site_id)
  
  # Create temperature forecast
  temperature_fc <- blinded_aquatic %>%
    model(benchmark_mean = MEAN(temperature)) %>%
    forecast(h = "35 days") %>%
    efi_format_ensemble()
  
  # Save the forecast
  write_csv(temperature_fc, "temperature_fc_mean.csv")
  
  # Upload the forecast to S3
  faasr_put_file(local_file = "temperature_fc_mean.csv", remote_folder = folder, remote_file = output_file)
  
  # Log message
  log_msg <- paste0('Function create_temperature_forecast finished; output written to ', folder, '/', output_file, ' in default S3 bucket')
  faasr_log(log_msg)
}
```

JSON function
```
"temperatureForecastMean": {
            "FunctionName": "create_temperature_forecast_mean",
            "FaaSServer": "My_GitHub_Account",
            "Arguments": {
                "folder": "neon4cast",
                "input_file": "blinded_aquatic.csv",
                "output_file": "temperature_fc_mean.csv"
            },
            "InvokeNext": "combineForecastMean"
        },
```

### combineForecastMean
Create an R script for a function that combine the 2 forecasted datasets. It will download `oxygen_fc_mean.csv` and `temperature_fc_mean` from S3 using the `faasr_get_file` function, generate a combined forecast file called `forecast_combined_mean.csv`, and upload it back to S3 for use in the combined function with the help of `faasr_put_file`. Here’s the R script:

```
combine_forecasts_mean <- function(folder, input_oxygen, input_temperature, output_file) {
  # Combine oxygen and temperature forecasts
  
  # Load required libraries
  library(tidyverse)
  library(glue)
  
  # Download the forecast files
  faasr_get_file(remote_folder = folder, remote_file = input_oxygen, local_file = "oxygen_fc_mean.csv")
  faasr_get_file(remote_folder = folder, remote_file = input_temperature, local_file = "temperature_fc_mean.csv")
  
  # Read the forecasts
  oxygen_fc <- read_csv("oxygen_fc_mean.csv")
  temperature_fc <- read_csv("temperature_fc_mean.csv")
  
  # Convert both to character to ensure compatibility
  oxygen_fc$parameter <- as.character(oxygen_fc$parameter)
  temperature_fc$parameter <- as.character(temperature_fc$parameter)
  
  # For a more robust solution, ensure all common columns have the same type
  common_cols <- intersect(names(oxygen_fc), names(temperature_fc))
  for (col in common_cols) {
    # Convert both to character if they're different types
    if (!identical(class(oxygen_fc[[col]]), class(temperature_fc[[col]]))) {
      oxygen_fc[[col]] <- as.character(oxygen_fc[[col]])
      temperature_fc[[col]] <- as.character(temperature_fc[[col]])
    }
  }
  
  # Combine the forecasts
  forecast <- bind_rows(oxygen_fc, temperature_fc)
  
  # Generate the output file
  forecast_file <- "forecast_combined_mean.csv"
  write_csv(forecast, forecast_file)
  
  # Upload both files to S3
  faasr_put_file(local_file = forecast_file, remote_folder = folder, remote_file = output_file)
  
  # Log message
  log_msg <- paste0('Function combine_forecasts finished; outputs written to folder ', folder, ' in default S3 bucket')
  faasr_log(log_msg)
}
```

Now that we have the R function, we need to modify our FaaSr JSON workflow. Your output should look similar to this:

```
"combineForecastMean": {
            "FunctionName": "combine_forecasts_mean",
            "FaaSServer": "My_GitHub_Account",
            "Arguments": {
                "folder": "neon4cast",
                "input_oxygen": "oxygen_fc_mean.csv",
                "input_temperature": "temperature_fc_mean.csv",
                "output_file": "forecast_combined_mean.csv"
            }
```

### Set invoke function
Add this inside your JSON object to set getData as the invoke funtion: `"FunctionInvoke": "getData",`

### Add Package for each function

```
"FunctionGitHubPackage": {
        "get_target_data": [
            "tidyverts/tsibble",
            "eco4cast/neon4cast"
        ],
        "create_oxygen_forecast": [
            "tidyverts/tsibble",
            "eco4cast/neon4cast"
        ],
        "create_temperature_forecast": [
            "tidyverts/tsibble",
            "eco4cast/neon4cast"
        ],
        "combine_forecasts": [
            "tidyverts/tsibble",
            "eco4cast/neon4cast"
        ]
        
    },
    "FunctionCRANPackage": {
        "get_target_data": [
            "tidyverse",
            "fable"
        ],
        "create_oxygen_forecast": [
            "neon4cast", 
            "tidyverse",
            "tsibble",
            "fable"
        ],
        "create_temperature_forecast": [
            "neon4cast",
            "tidyverse",
            "tsibble",
            "fable"
        ],
        "combine_forecasts": [
            "tidyverse",
            "glue"
        ]
    },
```

## Register and invoke the simple workflow with GitHub Actions

Now you're ready for some Action! The steps below will:

* Use the faasr function in the FaaSr library to load the neon_workflow.json and faasr_env in a list called neon4cast_tutorial
* Use the register_workflow() function to create a repository called FaaSr-tutorial in GitHub, and configure the workflow there using GitHub Actions
* Use the invoke_workflow() function to invoke the execution of your workflow

Enter the following commands to your console:

```
neon4cast_tutorial<- faasr(json_path="neon_workflow.json", env="faasr_env")
neon4cast_tutorial$register_workflow()
```

When prompted, select "public" to create a public repository. Now run the workflow:

```
neon4cast_tutorial$invoke_workflow()
```
