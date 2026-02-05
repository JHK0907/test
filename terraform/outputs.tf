# terraform/outputs.tf

output "vpc_id" {
  description = "생성된 VPC의 ID"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "생성된 Public Subnet들의 ID 리스트"
  value       = aws_subnet.public[*].id
}



output "fargate_sg_id" {

  description = "Fargate Task를 위한 Security Group ID"

  value       = aws_security_group.fargate_sg.id

}







output "ecr_repository_url" {



  description = "ECR 리포지토리의 URL"



  value       = aws_ecr_repository.web_app.repository_url



}







output "github_actions_iam_role_arn" {



  description = "GitHub Actions가 AWS에 접근할 때 사용할 IAM Role의 ARN"



  value       = aws_iam_role.github_actions_deployer.arn



}




