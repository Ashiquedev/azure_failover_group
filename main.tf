terraform {
  #required_version = "~>1.3.3"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.0.0"
    }
  }
}


provider "azurerm" {
  features {}
}

#=====resource group============



resource "azurerm_resource_group" "rg" {
  name     = "test_rg"
  location = "East US"
}