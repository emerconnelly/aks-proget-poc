variable "ARM_CLIENT_ID" {
  type    = string
  default = ""
}

variable "ARM_CLIENT_SECRET" {
  type    = string
  default = ""

  sensitive = true
}
