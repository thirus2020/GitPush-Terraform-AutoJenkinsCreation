output "jenkins_public_ip" {
  value = aws_instance.Jenkins_Server.public_ip
}

output "jenkins_url" {
  value = "http://${aws_instance.Jenkins_Server.public_ip}:8080"
}