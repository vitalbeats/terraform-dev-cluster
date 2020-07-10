variable "github_username" {
    type    = string
    default = "vitalbeats-jenkins"
}

variable "github_access_token" {
    type    = string
}

variable "google_client_id" {
    type    = string
}

variable "google_client_secret" {
    type    = string
}

variable "google_client_domains" {
    type    = string
    default = "vitalbeats.com"
}

variable "pypi_username" {
    type    = string
    default = "vitalbeats"
}

variable "pypi_password" {
    type    = string
}

variable "registry_ha_secret" {
    type    = string
}

variable "pull_request_service_secret" {
    type   = string
}