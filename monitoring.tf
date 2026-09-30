variable "alert_email" {
  description = "Adres odbiorcy alertów (demo)."
  type        = string
  default     = "student@example.com"
}

resource "azurerm_monitor_action_group" "main" {
  name                = "ag-demo"
  resource_group_name = data.azurerm_resource_group.main.name
  short_name          = "demo"
  tags                = data.azurerm_resource_group.main.tags

  email_receiver {
    name          = "student"
    email_address = var.alert_email
  }
}

resource "azurerm_monitor_activity_log_alert" "deletes" {
  name                = "alert-resource-delete"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = "global"
  scopes              = [data.azurerm_resource_group.main.id]
  description         = "Alert na usunięcie grupy zasobów."
  tags                = data.azurerm_resource_group.main.tags

  criteria {
    category       = "Administrative"
    operation_name = "Microsoft.Resources/subscriptions/resourceGroups/delete"
  }

  action {
    action_group_id = azurerm_monitor_action_group.main.id
  }
}
