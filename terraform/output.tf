
output "web_server_private_ip" { value = module.web_server.private_ip }
output "monitoring_server_private_ip" { value = module.monitoring_server.private_ip }
output "controller_server_private_ip" { value = module.controller_server.private_ip }
output "web_server_public_ip" { value = module.web_server.public_ip }

output "ssm_web_server" { value = "aws ssm start-session --target ${module.web_server.id}" }
output "ssm_monitoring_server" { value = "aws ssm start-session --target ${module.monitoring_server.id}" }
output "ssm_controller_server" { value = "aws ssm start-session --target ${module.controller_server.id}" }




