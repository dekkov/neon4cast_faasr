# Building and Deploying Ecological Forecasts with neon4cast and FaaSr

In this tutorial, we will run a [neon4cast package](https://github.com/eco4cast/neon4cast) example locally and deploy using a FaaSr-ready workflow. 


## Prerequisites
- A Github account
- A Github personal access token (PAT)
- RStudio on Posit Cloud (recommended) or a local Docker-based installation. 
- a Minio S3 bucket (you can use the [Play Console](https://min.io/docs/minio/linux/administration/minio-console.html#minio-console) to use a public/unauthenticated server)


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
install.packages("tidyverse")
install.packages("fable")
install.packages("tsibble")
install.packages("remotes")
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

In RStudio, navigate to the neon4cast_faasr folder, then set it as the working directory (More > Set as Working Directory).



## Source the script that sets up FaaSr and dependences

Run one of the following commands, depending on your setup (Posit, or local Docker). Fair warning: it will take a few minutes to install all dependences:

## For Posit Cloud:

```
source('posit_setup_script')
```
This process can take a few minutes!

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


### Workflow Pipeline
1. getData - Invoke function:
    - Download and process aquatic dataset and upload it to S3
    - This function will act as the starting point for our workflow, invoking both oxygenForecastRandomWalk and temperatureForecastRandomWalk next.
2. The following two functions will run simultaneously:

   a. oxygenForecastRandomWalk
     - Use the filtered dataset to create Oxygen forecast using RandomWalk method and upload it to S3
     - Invoke combined forecast next.
       
    b.temperatureForecastRandomWalk
     - Use the filtered dataset to create Temperature forecast using RandomWalk method and upload it to S3
     - Invoke combined forecast next.
 3. combineForecastRandomWalk:
    - Download the 2 forecasts file from S3 to generate a combined forecast and store it in S3
    - This function doesn't invoke any function after, meaning this is the end of our workflow.



## Register and invoke the simple workflow with GitHub Actions

Now you're ready for some Action! The steps below will:

* Use the faasr function in the FaaSr library to load the neon_workflow.json and faasr_env in a list called neon4cast_tutorial
* Use the register_workflow() function to create a repository called neon4cast_faasr_actions in GitHub, and configure the workflow there using GitHub Actions
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

## Check if action is successful

Head over to the github repo `neon4cast_faasr_actions` just created by FaaSr, go to actions page to see if your actions has successfully run. 
If the runs are successful, you can explore the Console using https://play.min.io:9443. Log in with the following credentials:
```
Username: Q3AM3UQ867SPQQA43P2F
Password: zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG
```

Look for the neon4cast folder in faasr bucket, you should be able to see the forecasts you have just created.




# Part III: Build a FaaSr workflow by yourself.

## Objectives

This tutorial will help you get familiar with creating your own FaaSr functions, which means that you will created a new FaaSr workflow by yourself. We have provided you some guidance and an example file `create_oxygen_forecast_mean.R` to assist you in this part. The function is similar to the previous two we have seen, but with a modification of the method when creating a forecast. See [file](https://github.com/dekkov/neon4cast_faasr/blob/main/create_oxygen_forecast_mean.R). 



## Configure the FaaSr JSON workflow

The workflow we are aiming to create will have 2 addition functions compared to the one in previous part. Those are "oxygenForecastMean" and "temperatureForecastMean", which will create forecasts using "Mean" method (instead of "Random walk' as in part II)  on the two variables oxygen and temperature respectively. 

![image](https://github.com/user-attachments/assets/808eb754-3bd1-4d8d-a7bd-9573a701f265)



## Add function to the workflow using JSON Builder App


While you can create and edit FaaSr configuration files in any text editor, FaaSr also provides a Shiny app graphical user interface to facilitate the development of simple workflows using your browser. You can use it to edit a configuration from scratch, or from an existing JSON configuration file that you upload as a starting point, and then download the edited JSON file to your computer for use in FaaSr. [Right-click here to open the FaaSr workflow builder in another window](https://faasr.shinyapps.io/faasr-json-builder/). 

To start, you will need to download "neon_workflow.json" and upload it to the FaaSr JSON Builder, your Workflow section should represent the workflow we had in part II. Next, we will guide you through the process of adding the provided function `create_oxygen_forecast_mean.R` to this workflow. 

### oxygenForecastMean

Let's first create our function in the workflow:

1. On the left sidebar, choose `Functions` for "Select type" field.
2. For "Action Name" and "Function Name", input the following: `oxygenForecastMean` and `create_oxygen_forecast_mean`. Notice: the function name declared here should match the function name initialized in `create_oxygen_forecast_mean.R`.
3. For "Function Arguments", we need to match this field with the actual arguments in our file, which is `folder=neon4cast, input_file=blinded_aquatic.csv, output_file=oxygen_fc_mean.csv`
4. Since we won't invoke anything after this function, we can leave "Next Actions to Invoke" blank.
5. For "Function's Action Container(Optional)", input `ghcr.io/faasr/github-actions-tidyverse:1.4.1`
6. For "Repository/Path": input `dekkov/neon4cast_faasr`
7. The dependencies needed for this function should also be declared in the next 2 fields as follows: "Dependencies - Github Package for the function: tidyverts/tsibble, eco4cast/neon4cast", "Dependencies - Repository/Path for the function: neon4cast, tidyverse, tsibble, fable".
8. Click Apply

Now that we have our function, we can connect it to our workflow by invoking it after getData function.

1. Click on getData function in the workflow section.
2. In "Next Actions to Invoke" section, add `oxygenForecastMean` to the list.
3. Click apply

You should see an arrow from getData function to oxygenForecastMean, which indicates we have successfully linked the 2 functions.

### temperatureForecastMean

Now, try to follow the instructions below to create your own function and register it.

1. Create a function for forecasting temperature with the new method.
   a. Create an R script and paste the code from `create_temperature_forecast_rw.R`. Then, replace model(benchmark_rw = RW(temperature)) with `model(benchmark_rw = MEAN(temperature))`.
   b. Modify variables, function names, and file names.
   c. Save the file and push it to your repository.
2. Register the newly created function in the workflow through FaaSr JSON builder.
   a. Head over to the shiny app and select the "Functions" tab.
   b. Fill in the fields:
      - **Action name**: The name that represents your function on the workflow.
      - **Function name**: This field should match the name of the function you just created in step 1.
      - **Function FaaS Server**: Keep as default for this tutorial.
      - **Function arguments**: The arguments needed for your function.
      - **Next Actions to Invoke**: Since we won't invoke any other function now, keep it blank.
      - **Repository/Path**: Where your function file is located, which should be "your_github_username/your_repo_name"
      - **Dependencies-Github Package**: The packages needed for your function
      - **Dependencies-Repository/Path**:
   c. Click "Apply" to add the function to the workflow.
   d. In getData's "Next Actions to Invoke", add the action name and click apply to save.
3. Download the JSON file and use it in your directory.
4. Enter the following commands to your console (remember to replace "your_workflow_name" with your actual file name):

```
neon4cast_tutorial<- faasr(json_path="your_workflow_name.json", env="faasr_env")
neon4cast_tutorial$register_workflow()
```

When prompted, select "public" to create a public repository. Now run the workflow:

```
neon4cast_tutorial$invoke_workflow()
```

## Check if action is successful

Head over to the github repo `neon4cast_faasr_actions` just created by FaaSr, go to actions page to see if your actions has successfully run. 
If the runs are successful, you can explore the Console using https://play.min.io:9443. Log in with the following credentials:
```
Username: Q3AM3UQ867SPQQA43P2F
Password: zuf+tfteSlswRu7BJ86wekitnifILbZam1KYY3TG
```

Look for the neon4cast folder in faasr bucket, you should be able to see the forecasts you have just created.


# Part IV: Challenge - Create a Combine Function for the Mean Method

Now that you've built individual forecast functions using the mean method, your challenge is to create a new function to combine these forecasts.

**Steps to Complete the Challenge**
1. Create a new R script for combining the forecasts, similar to how forecasts were combined in Part I.
2. Modify your FaaSr workflow to include this new function:
   - Name it `combineForecastMean`.
   - Modify your function to merge the mean method forecast files into a single dataset.
3. Register and deploy your updated workflow
   - Add `combineForecastMean` to you JSON workflow.
   - Connect it to `oxygenForecastMean` and `temperatureForecastMean`.
   - Deploy using the same FaaSr commands as before.
4. Check Github Actions to confirm successful execution.

Here is the JSON snippet:

![image](https://github.com/user-attachments/assets/9639d723-9948-45ec-8100-5ab249e2df08)


Good luck, and have fun building your forecasting pipeline!


