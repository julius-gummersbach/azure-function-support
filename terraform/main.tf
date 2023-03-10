# Create a resource group
resource "azurerm_resource_group" "resource_group" {
  name = "${var.project}-${var.environment}-resource-group"
  location = var.location
}


# Create an eventhub
resource "azurerm_eventhub_namespace" "eventhub_namespace" {
  name                = "${var.project}-${var.environment}-eventhub-namespace"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  sku                 = "Standard"
  capacity            = 1
}
resource "azurerm_eventhub" "eventhub" {
  name                = "${var.project}-${var.environment}-eventhub"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  resource_group_name = azurerm_resource_group.resource_group.name
  partition_count     = 2
  message_retention   = 1
}
# Create eventhub namespace authorization rule (this provides the connection string)
resource "azurerm_eventhub_namespace_authorization_rule" "eventhub_namespace_authorization_rule_listen_send" {
  name                = "${var.project}-${var.environment}-eventhub-namespace-authorization-rule"
  namespace_name      = azurerm_eventhub_namespace.eventhub_namespace.name
  resource_group_name = azurerm_resource_group.resource_group.name
  listen              = true
  send                = true
  manage              = false
} #  End of create eventhub


# Create CosmosDB
## Create CosmosDB account
resource "azurerm_cosmosdb_account" "cosmosdb_account" {
  name                = "${var.project}-${var.environment}-cosmosdb-account"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  consistency_policy {
    consistency_level       = "Session"
  }
  geo_location {
    location          = var.location
    failover_priority = 0
  }
}
## Create CosmosDB database
resource "azurerm_cosmosdb_sql_database" "cosmosdb_sql_database" {
  name                = "${var.project}-${var.environment}-cosmosdb-sql-database"
  resource_group_name = azurerm_resource_group.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account.name
}
## Create CosmosDB container
resource "azurerm_cosmosdb_sql_container" "cosmosdb_sql_container" {
  name                = "${var.project}-${var.environment}-cosmosdb-sql-container"
  resource_group_name = azurerm_resource_group.resource_group.name
  account_name        = azurerm_cosmosdb_account.cosmosdb_account.name
  database_name       = azurerm_cosmosdb_sql_database.cosmosdb_sql_database.name
    indexing_policy {
    indexing_mode = "consistent"

    included_path {
      path = "/*"
    }
  }
  partition_key_path  = "/state"
} #  End of create CosmosDB


# Create a function app
## Create a storage account for the function app
resource "azurerm_storage_account" "storage_account" {
  # storage accounts must not have dashes in the name
  name = "${var.project}${var.environment}storage"
  resource_group_name = azurerm_resource_group.resource_group.name
  location = var.location
  account_tier = "Standard"
  account_replication_type = "LRS"
}
## Create application insights for the function app
resource "azurerm_application_insights" "application_insights" {
  name                = "${var.project}-${var.environment}-application-insights"
  location            = var.location
  resource_group_name = azurerm_resource_group.resource_group.name
  application_type    = "other"
}
## Create Service Plan for the function app
resource "azurerm_service_plan" "service_plan" {
  name                = "${var.project}-${var.environment}-service-plan"
  resource_group_name = azurerm_resource_group.resource_group.name
  location            = var.location
  os_type             = "Linux"
  sku_name            = "Y1"
}
## Create the function app itself
resource "azurerm_linux_function_app" "function_app" {
  depends_on = [
    azurerm_storage_blob.functionapp_zip_blob,
    data.azurerm_storage_account_blob_container_sas.functionapp_zip_blob_sas,
  ]
  name                       = "${var.project}-${var.environment}-function-app"
  resource_group_name        = azurerm_resource_group.resource_group.name
  location                   = var.location
  service_plan_id            = azurerm_service_plan.service_plan.id
  app_settings = {
    "WEBSITE_RUN_FROM_PACKAGE"             = "${azurerm_storage_blob.functionapp_zip_blob.url}${data.azurerm_storage_account_blob_container_sas.functionapp_zip_blob_sas.sas}",
    "APPINSIGHTS_INSTRUMENTATIONKEY"       = azurerm_application_insights.application_insights.instrumentation_key,
    "EVENTHUB_NAMESPACE_CONNECTION_STRING" = azurerm_eventhub_namespace_authorization_rule.eventhub_namespace_authorization_rule_listen_send.primary_connection_string,
    "EVENTHUB_NAME"                        = azurerm_eventhub.eventhub.name,
    "COSMOSDB_CONNECTION_STRING"           = azurerm_cosmosdb_account.cosmosdb_account.connection_strings[0],
    "DATABASE_NAME"                        = azurerm_cosmosdb_sql_database.cosmosdb_sql_database.name,
    "COLLECTION_NAME"                      = azurerm_cosmosdb_sql_container.cosmosdb_sql_container.name,
  }
  storage_account_name       = azurerm_storage_account.storage_account.name
  storage_account_access_key = azurerm_storage_account.storage_account.primary_access_key
  site_config {
    application_stack {
      python_version = "3.10"
    }
  }
} # End of create function app


# Deploy the functions
## Create Storage Container for deployment zip file
resource "azurerm_storage_container" "functionapp_storage_container" {
  name                  = "function-app"
  storage_account_name  = azurerm_storage_account.storage_account.name
  container_access_type = "private"
}
## Create a zip file of the functions
data "archive_file" "file_function_app" {
  type        = "zip"
  source_dir  = "../functionApp"
  excludes = ["local.settings.json", "getting_started.md", "__pycache__"]
  output_path = "function-app.zip"
}
## Upload the zip file to the container
resource "azurerm_storage_blob" "functionapp_zip_blob" {
  name                   = "function-app.zip"
  storage_account_name   = azurerm_storage_account.storage_account.name
  storage_container_name = azurerm_storage_container.functionapp_storage_container.name
  type                   = "Block"
  source                 = data.archive_file.file_function_app.output_path

  depends_on = [null_resource.always_run]
  lifecycle {
    replace_triggered_by = [
      null_resource.always_run  # always re-upload the zip file on terraform apply
    ]
  }
}
## Create a SAS token for the zip file
data "azurerm_storage_account_blob_container_sas" "functionapp_zip_blob_sas" {
  connection_string = azurerm_storage_account.storage_account.primary_connection_string
  container_name    = azurerm_storage_container.functionapp_storage_container.name
  
  start  = formatdate("YYYY-MM-DD", timestamp())
  expiry = formatdate("YYYY-MM-DD", timeadd(timestamp(), "${var.valid_for}"))

  permissions {
    read   = true
    add    = false
    create = false
    write  = false
    delete = false
    list   = false
  }
} # End of deploy the functions


# Sync triggers of function app
## Get function app master key for trigger syncing
data "azurerm_function_app_host_keys" "function_app_host_keys" {
  name                = azurerm_linux_function_app.function_app.name
  resource_group_name = azurerm_resource_group.resource_group.name
}
## Sync triggers of function app with https post (https://learn.microsoft.com/en-us/azure/azure-functions/functions-deployment-technologies#trigger-syncing)
data "http" "sync_triggers" {
  url    = "https://${azurerm_linux_function_app.function_app.name}.azurewebsites.net/admin/host/synctriggers?code=${data.azurerm_function_app_host_keys.function_app_host_keys.primary_key}"
  method = "POST"
} # End of sync triggers of function app


# can be used as a trigger to force a replace operation on a resource
resource "null_resource" "always_run" {
  triggers = {
    timestamp = timestamp()
  }
}
