provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "jenkins_sg_lab" {
  ingress { # Application Ports (v1 & v2)
    from_port   = 8081
    to_port     = 8082
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  name        = "jenkins-sg-lab-v2"
  description = "Allow SSH, Jenkins, and App"

  ingress { # SSH
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # Jenkins UI
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # The Node App (מהסילבוס)
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- שרת המאסטר (הקיים) ---
resource "aws_instance" "jenkins_server" {
  ami           = "ami-0e2c8caa4b6378d8c"
  instance_type = "t3.small"
  
  vpc_security_group_ids = [aws_security_group.jenkins_sg_lab.id]
  key_name               = "myfirstkey" 

  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install docker.io -y
              sudo systemctl start docker
              sudo chmod 666 /var/run/docker.sock

              # הרצת ג'נקינס
              sudo docker run -d -p 8080:8080 -p 50000:50000 \
              -v jenkins_home:/var/jenkins_home \
              -v /var/run/docker.sock:/var/run/docker.sock \
              -u root \
              --restart always \
              --name jenkins \
              jenkins/jenkins:lts

              # התקנת דוקר בתוך הקונטיינר
              sudo docker exec -u root jenkins apt-get update
              sudo docker exec -u root jenkins apt-get install -y docker.io
              EOF

  tags = {
    Name = "Jenkins-Lab-Master"
  }
}

# --- שרת הסלייב (החדש!) ---
resource "aws_instance" "jenkins_slave" {
  ami           = "ami-0e2c8caa4b6378d8c" # אותו AMI (אובונטו)
  instance_type = "t3.small"             # מספיק חזק לעבודה
  
  vpc_security_group_ids = [aws_security_group.jenkins_sg_lab.id] # משתמש באותו סקיוריטי גרופ
  key_name               = "myfirstkey"                           # משתמש באותו מפתח

  # סקריפט התקנה אוטומטי לסלייב (חוסך לך עבודה ידנית!)
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              
              # התקנת Java 17 (חובה בשביל הסלייב)
              sudo apt-get install fontconfig openjdk-17-jre -y
              
              # התקנת דוקר (כדי שיוכל לבנות אימג'ים)
              sudo apt-get install docker.io -y
              sudo systemctl start docker
              sudo chmod 666 /var/run/docker.sock
              
              # יצירת התיקייה שג'נקינס יעבוד בה
              mkdir -p /home/ubuntu/jenkins_agent
              chown ubuntu:ubuntu /home/ubuntu/jenkins_agent
              EOF

  tags = {
    Name = "Jenkins-Lab-Slave"
  }
}

output "jenkins_master_url" {
  value = "http://${aws_instance.jenkins_server.public_ip}:8080"
}

output "jenkins_slave_private_ip" {
  value = aws_instance.jenkins_slave.private_ip
  description = "Use this IP to connect the slave in Jenkins UI"
}

output "jenkins_slave_public_ip" {
  value = aws_instance.jenkins_slave.public_ip
}