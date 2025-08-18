output "instance_public_ips" {
  description = "Public IPs of all EC2 instances"
  value       = [for instance in aws_instance.demo : instance.public_ip]
}

output "ssh_connection_commands" {
  description = "SSH commands to connect to each instance"
  value = [
    for instance in aws_instance.demo :
    "ssh -i /mnt/c/Users/adedi/Downloads/LaptopKey ubuntu@${instance.public_ip}"
  ]
}

output "jenkins_url" {
  description = "Jenkins web UI URL (from the controller instance)"
  value       = "http://${aws_instance.demo["controller"].public_ip}:8080"
}
