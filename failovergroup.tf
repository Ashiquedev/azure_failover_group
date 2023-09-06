resource "azurerm_storage_account" "storeacc" {
  name                      = "storeacc060923"
 resource_group_name        = azurerm_resource_group.rg.name
  location                  = azurerm_resource_group.rg.location
  account_kind              = "StorageV2"
  account_tier              = "Standard"
  account_replication_type  = "GRS"
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"
}

resource "azurerm_storage_container" "storcont" {
  name                  = "vulnerability-assessment"
  storage_account_name  = azurerm_storage_account.storeacc.name
  container_access_type = "private"
}

#====================================

resource "azurerm_mssql_server" "primarysqlserver" {
  name                = "primary-sqlserver-test"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  version = "12.0"
  administrator_login          = "sqladmin"
  administrator_login_password = "Password12345!"
}

#creating two databases in the server:

resource "azurerm_mssql_database" "db1" {
  name            = "db1"
  server_id       = azurerm_mssql_server.primarysqlserver.id
  license_type    = "LicenseIncluded"
  max_size_gb     = 1
  sku_name        = "Basic"
  threat_detection_policy {
    state = "New"
    email_account_admins = "Enabled"
    email_addresses = ["ashikdev.devops@gmail.com"]
    storage_endpoint           = azurerm_storage_account.storeacc.primary_blob_endpoint
    storage_account_access_key = azurerm_storage_account.storeacc.primary_access_key
  }
  depends_on = [
    azurerm_mssql_server.primarysqlserver
  ]
}
resource "azurerm_mssql_database" "db2" {
  name            = "db2"
  server_id       = azurerm_mssql_server.primarysqlserver.id
  license_type    = "LicenseIncluded"
  max_size_gb     = 1
  sku_name        = "Basic"
  depends_on = [
    azurerm_mssql_server.primarysqlserver
  ]
}

#Create a Secondary SQL Server (location must not be in primaryserver1)

resource "azurerm_mssql_server" "secondarysqlserver" {
  name                = "secondary-sqlserver-test"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "West US"
  version = "12.0"
  administrator_login          = "usernamess"
  administrator_login_password = "Password12345!"
}

resource "azurerm_mssql_failover_group" "sql-database-failover" {
  name      = "sql-database-failover"
  server_id = azurerm_mssql_server.primarysqlserver.id
  databases = [
    azurerm_mssql_database.db1.id,
    azurerm_mssql_database.db2.id
  ]
  partner_server {
    id = azurerm_mssql_server.secondarysqlserver.id
  }
  read_write_endpoint_failover_policy {
    mode          = "Automatic"
    grace_minutes = 60
  }
  depends_on = [azurerm_mssql_database.db1,azurerm_mssql_database.db2]
}



#=================================



resource "azurerm_mssql_server_extended_auditing_policy" "primary" {
  server_id                               = azurerm_mssql_server.primarysqlserver.id
  storage_endpoint           = azurerm_storage_account.storeacc.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.storeacc.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 30
  log_monitoring_enabled                  = true
}


resource "azurerm_mssql_server_extended_auditing_policy" "secondary" {
  server_id                               = azurerm_mssql_server.secondarysqlserver.id
  storage_endpoint           = azurerm_storage_account.storeacc.primary_blob_endpoint
  storage_account_access_key = azurerm_storage_account.storeacc.primary_access_key
  storage_account_access_key_is_secondary = false
  retention_in_days                       = 30
  log_monitoring_enabled                  = true
}

#============
resource "azurerm_mssql_server_security_alert_policy" "secalert_primary" {
  resource_group_name        = azurerm_resource_group.rg.name
  server_name                = azurerm_mssql_server.primarysqlserver.name
  state                      = "Enabled"
  email_account_admins       = true
  email_addresses            = ["ashikdev.devops@gmail.com"]
  retention_days             = 30
  storage_account_access_key = azurerm_storage_account.storeacc.primary_access_key
  storage_endpoint           = azurerm_storage_account.storeacc.primary_blob_endpoint
}

resource "azurerm_mssql_server_security_alert_policy" "secalert_secondary" {
  resource_group_name        = azurerm_resource_group.rg.name
  server_name                = azurerm_mssql_server.secondarysqlserver.name
  state                      = "Enabled"
  email_account_admins       = true
  email_addresses            = ["ashikdev.devops@gmail.com"]
  retention_days             = 30
  #disabled_alerts            = false
  storage_account_access_key = azurerm_storage_account.storeacc.primary_access_key
  storage_endpoint           = azurerm_storage_account.storeacc.primary_blob_endpoint
}



