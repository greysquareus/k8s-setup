resource "tls_private_key" "node" {
  for_each  = local.nodes
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "node" {
  for_each   = local.nodes
  key_name   = "${each.key}_key"
  public_key = tls_private_key.node[each.key].public_key_openssh
}

resource "local_sensitive_file" "private_key" {
  for_each        = local.nodes
  content         = tls_private_key.node[each.key].private_key_pem
  filename        = "${path.module}/keys/${each.key}.pem"
  file_permission = "0600"
}