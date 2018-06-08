provider "aws" {
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
  region     = "${var.aws_region}"
}

data "http" "etcd_discovery" {
  url = "https://discovery.etcd.io/new?size=#${var.etcd_instances}"
}

data "template_file" "cloud_config" {
  template = "${file("${path.module}/cloud-config.tmpl")}"

  vars {
    discovery_url = "${data.http.etcd_discovery.body}"
  }
}

resource "aws_key_pair" "default" {
  key_name = "nginx-kp"
  public_key = "${file("${var.key_path}")}"
}

resource "aws_vpc" "nginx" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_subnet" "us-east-1a-public" {
  vpc_id = "${aws_vpc.nginx.id}"
  cidr_block = "10.0.1.0/25"
  availability_zone = "us-east-1a"
}

resource "aws_security_group" "default" {
  name = "nginx-sg"
  vpc_id = "${aws_vpc.nginx.id}"
 
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 2379
    to_port = 2379
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 2380
    to_port = 2380
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 4001
    to_port = 4001
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port = 7001
    to_port = 7001
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
 
  egress {
    from_port = 0
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "cloud-config" {

  provisioner "local-exec" {
    command = "echo \"${data.template_file.cloud_config.rendered}\" > config.tmp"
  }
  
  provisioner "local-exec" {
    command = "/data/ct --platform=ec2 < config.tmp > config.ign"
  }
}

resource "aws_instance" "nginx" {

  depends_on = ["null_resource.cloud-config"]

  ami           = "ami-a32d46dc"
  instance_type = "t2.micro"
  key_name = "${aws_key_pair.default.id}"
  vpc_security_group_ids = ["${aws_security_group.default.id}"]
  subnet_id = "${aws_subnet.us-east-1a-public.id}"
  user_data = "${file("config.ign")}"
  associate_public_ip_address = true
}

resource "null_resource" "ansible-provision" {

  depends_on = ["aws_instance.nginx"]

  provisioner "local-exec" {
    command =  "echo \"[coreos]\nnginx ansible_host=${aws_instance.nginx.public_ip} ansible_port=2222 ansible_ssh_private_key_file=nginx-kp.pem\" > inventory"
  }

  provisioner "local-exec" {
    command =  "echo \"\n[coreos:vars]\nansible_ssh_user=core\nansible_python_interpreter=/home/core/bin/python\" >> inventory"
  }
  
  provisioner "local-exec" {
    command = "/ansible/bin/ansible-playbook -i inventory \"curated-templates/webservers/nginx/templates/nginx-container.yml\" --list-hosts"
  }
  
  provisioner "local-exec" {
    command = "/ansible/bin/ansible-playbook -i inventory \"curated-templates/webservers/nginx/templates/nginx-container.yml\""
  }
}

