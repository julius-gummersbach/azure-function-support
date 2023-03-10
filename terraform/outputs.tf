# for local testing only 
output "eventhub_name" {
  value = azurerm_eventhub.eventhub.name
  description = "Event hub name"
}

# for local testing only 
output "cosmosdb_database_name" {
  value = azurerm_cosmosdb_sql_database.cosmosdb_sql_database.name
  description = "CosmosDB database name"
}

# for local testing only 
output "cosmosdb_collection_name" {
  value = azurerm_cosmosdb_sql_container.cosmosdb_sql_container.name
  description = "CosmosDB collection name"
}

# for local testing only 
# can be shown with terraform output -json
output "eventhub_namespace_connection_string" {
  value = azurerm_eventhub_namespace_authorization_rule.eventhub_namespace_authorization_rule_listen_send.primary_connection_string
  sensitive = true
  description = "Eventhub namespace connection string"
}

# for local testing only 
# can be shown with terraform output -json
output "cosmosdb_connection_string" {
  value = azurerm_cosmosdb_account.cosmosdb_account.connection_strings[0]
  sensitive = true
  description = "CosmosDB connection string"
}

# for local testing only
# can be shown with terraform output -json
output "function_app_master_key" {
  value = data.azurerm_function_app_host_keys.function_app_host_keys.primary_key
  sensitive = true
  description = "Function app _master key"
}

# for local testing only 
# can be shown with terraform output -json
output "storage_blob_sas_token" {
  value = data.azurerm_storage_account_blob_container_sas.functionapp_zip_blob_sas.sas
  sensitive = true
  description = "function zip blob sas token"
}

# for local testing only 
output "storage_account_primary_blob_endpoint" {
  value = azurerm_storage_account.storage_account.primary_blob_endpoint
  description = "Storage account primary blob endpoint"
}

# for local testing only 
output "run_from_package_ulr" {
  value = "${azurerm_storage_blob.functionapp_zip_blob.url}${data.azurerm_storage_account_blob_container_sas.functionapp_zip_blob_sas.sas}"
  sensitive = true
  description = "run from package url"
}

# for local testing only 
output "storage_account_connection_string" {
  value = azurerm_storage_account.storage_account.primary_connection_string
  sensitive = true
  description = "Storage account connection string"
}
