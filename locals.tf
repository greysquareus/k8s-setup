locals {
  nodes = {
    master  = { instance_type = "t3.medium", role = "master" }
    worker1 = { instance_type = "t3.small", role = "worker" }
    worker2 = { instance_type = "t3.small", role = "worker" }
  }
}
