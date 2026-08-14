output "ubuntu_ip_master" {
  value = aws_instance.node["master"].public_ip
}

output "worker_ips" {
  value = { for k, inst in aws_instance.node : k => inst.public_ip if k != "master" }
}

output "private_key_paths" {
  value = { for k, f in local_sensitive_file.private_key : k => f.filename }
}
