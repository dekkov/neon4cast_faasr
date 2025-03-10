# Building and Deploying Ecological Forecasts with neon4cast and FaaSr

In this tutorial, we will run a [neon4cast package](https://github.com/eco4cast/neon4cast) example locally and deploy using a FaaSr-ready workflow. 


## Prerequisites
- A Github account
- A Github personal access token (PAT)
- Rstudio environment (either on local or cloud)
- a Minio S3 bucket

While you can use your existing GitHub PAT if you have one, it is recommended that you create a short-lived GitHub PAT token for this tutorial if you plan to use Posit Cloud. [Detailed instructions to create a PAT are available here](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic); in summary:

* In the upper-right corner of any page, click your profile photo, then click Settings.
* In the left sidebar, click Developer settings.
* In the left sidebar, click Personal access tokens (Classic).
* Click Generate new token (Classic); *note: make sure to select Classic*
* In the "Note" field, give your token a descriptive name.
* In scopes, select “workflow” and “read:org” (under admin:org). 
* Copy and paste the token; you will need to save it to a file in your computer for use in the tutorial



## Part I: Running a neon4cast example manually

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


## Part II: Automate forecast using FaaSr


### Clone the FaaSr tutorial repo

First let's clone the FaaSr tutorial repo - copy and paste this command in the terminal:

```
system('git clone https://github.com/dekkov/neon4cast_faasr.git')
```

Click on FaaSr-Tutorial folder on the lower right window (Files), then

Select More > Set as Working Directory from the drop down menu.



### Source the script that sets up FaaSr and dependences

Run one of the following commands, depending on your setup (Posit, or local Docker). Fair warning: it will take a few minutes to install all dependences:

### For Posit Cloud:

```
source('posit_setup_script')
```


### Configure Rstudio to use GitHub Token

Within Rstudio, configure the environment to use your GitHub account (replace with your username and email). Input this into the console:

```
usethis::use_git_config(user.name = "YOUR_GITHUB_USERNAME", user.email = "YOUR_GITHUB_EMAIL")
```

Now set your GitHub token as a credential for use with Rstudio - paste your token to the pop-up window that opens with this command pasted into the console:

```
credentials::set_github_pat()
```

### Configure the FaaSr secrets file with your GitHub token

Open the file named faasr_env in the editor. You need to enter your GitHub token here: replace the string "REPLACE_WITH_YOUR_GITHUB_TOKEN" with your GitHub token, and save this file. 

The secrets file stores all credentials you use for FaaSr. You will notice that this file has the pre-populated credentials (secret key, access key) to access the Minio "play" bucket.

### Configure the FaaSr JSON simple workflow template with your GitHub username

Open the file tutorial_simple.json and replace the string "YOUR_GITHUB_USERNAME" with your GitHub username, and save this file.

The JSON file stores the configuration for your workflow. We'll come back to that later.

### Register and invoke the simple workflow with GitHub Actions

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
