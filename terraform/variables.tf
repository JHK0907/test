 # terraform/variables.tf

 variable "name_prefix" {
  description = "모든 리소스 이름에 사용할 접두사"
  type        = string
  default     = "hkjung"
}

variable "aws_region" {
   description = "배포를 위한 AWS 리전"
   type        = string
   default     = "ap-northeast-2" # 서울 리전
 }

 variable "project_name" {
   description = "모든 리소스에 태깅될 프로젝트 이름"
   type        = string
   default     = "web"
 }

 variable "vpc_cidr" {
   description = "VPC에 사용할 CIDR 블록"
   type        = string
   default     = "10.0.0.0/16"
 }

 

 variable "public_subnets_cidr" {

   description = "Public Subnet에 사용할 CIDR 블록 리스트"

   type        = list(string)

   default     = ["10.0.1.0/24", "10.0.2.0/24"] # 2개의 가용 영역에 배포

 }

 

 variable "github_repo_owner" {

   description = "GitHub 리포지토리의 소유자 (조직 또는 사용자 이름)"

   type        = string

   # !!! 여기에 실제 GitHub 조직/사용자 이름을 입력하세요. !!!

   default     = "JHK0907"

 }

 

 variable "github_repo_name" {

   description = "GitHub 리포지토리의 이름"

   type        = string

   # !!! 여기에 실제 GitHub 리포지토리 이름을 입력하세요!..!!!

   default     = "test"

 }

 
