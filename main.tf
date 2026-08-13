provider "aws" {
  region = "us-east-1"
}

resource "aws_instance" "node" {
  for_each                    = local.nodes
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = each.value.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_tls.id]
  key_name                    = aws_key_pair.node[each.key].key_name
  associate_public_ip_address = true

  tags = {
    Name = each.key
    Role = title(each.value.role)
  }
}


