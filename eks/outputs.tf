output "cluster_connectivity" {
  description = "CLI command for cluster connectivity"
  value       = "aws eks update-kubeconfig --name ${module.eks.cluster_name} --region ${var.aws_region}"
}