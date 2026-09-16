resource "local_file" "inventory" {
  filename = "inventory.ini"
  content = templatefile("inventory.ini.tftpl", {
    web_server_ip        = module.web_server.private_ip
    monitoring_server_ip = module.monitoring_server.private_ip
    controller_server_ip = module.controller_server.private_ip
  })
}