This repository provides code and instructions to reproduce an issue I have with deploying code to an azure function app.
I have posted questions about this issue on [StackOverflow]() and in the [Microsoft Q&A](https://learn.microsoft.com/en-us/answers/questions/1188415/deploying-a-python-function-to-a-linux-consumption?source=docs).

## Reproduce the issue

I am using terraform to automate my deployment, which makes it easy for You to reproduce my issue.  
Using terraform, you should be able to exactly match my setup following these steps:

First, enter a unique project name in `terraform/terraform.tfvars`
After that, execute

```
cd terraform
terraform init
terraform apply
```

## Run the function locally

If you want to confirm that the function runs locally, proceed like this:
Run `terraform output -json` in the `terraform` directory.
Enter the values you get from the last command into the corresponding fields in `/functionApp/local.settings.json`.  
Then run:

```
cd ../functionApp
python -m venv .venv
.venv\scripts\activate
pip install -r requirements.txt
```

Start the [azurite](https://learn.microsoft.com/en-us/azure/storage/common/storage-use-azurite?tabs=npm) storage emulator in a seperate process.  
You can install azurite with `npm install -g azurite`.  
Run azurite with `azurite`.  
You can now run the functions. In `/functionApp` run:

```
func start
```

You can now observe in the azure portal, that new integers are added to the cosmosdb account every 5 seconds.