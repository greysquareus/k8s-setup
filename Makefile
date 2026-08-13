.PHONY: plan apply wait-ssh configure up destroy

plan:
	terraform plan

apply:
	terraform apply

# Blocks until every host in the generated inventory accepts SSH.
# EC2 public_ip is known well before cloud-init/sshd are actually up,
# so ansible-playbook's first attempt would otherwise just fail.
wait-ssh:
	ansible all -i ansible/inventory.ini -m wait_for_connection -a "timeout=180"

configure: wait-ssh
	ansible-playbook -i ansible/inventory.ini ansible/site.yml

up: apply configure

destroy:
	terraform destroy
