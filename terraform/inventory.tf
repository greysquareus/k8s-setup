resource "local_file" "ansible_inventory" {
  filename = "${path.module}/../ansible/inventory.ini"
  content = templatefile("${path.module}/../templates/inventory.tftpl", {
    master_ip   = aws_instance.node["master"].public_ip
    master_key  = local_sensitive_file.private_key["master"].filename
    worker_ips  = { for k, inst in aws_instance.node : k => inst.public_ip if k != "master" }
    worker_keys = { for k, f in local_sensitive_file.private_key : k => f.filename if k != "master" }
  })
}
