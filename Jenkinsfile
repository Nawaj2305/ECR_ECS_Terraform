
pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'ap-south-1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Terraform Version') {
            steps {
                sh 'terraform -version'
            }
        }

        stage('Terraform Init') {
            steps {
                sh 'terraform init'
            }
        }

        stage('Terraform Validate') {
            steps {
                sh 'terraform validate'
            }
        }

        stage('Terraform Plan') {
            steps {
                sh 'terraform plan'
            }
        }

        stage('Terraform Apply') {
            steps {
                sh 'terraform apply -auto-approve'
            }
        }
        stage('Deploy To ECR') {
            steps {
                        sh """
                            cd src
                            aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 085831229262.dkr.ecr.us-east-1.amazonaws.com
                            docker tag my-ecs-app:latest 085831229262.dkr.ecr.us-east-1.amazonaws.com/my-ecs-app:latest
                            docker push 085831229262.dkr.ecr.us-east-1.amazonaws.com/my-ecs-app:latest
                            aws ecr list-images --repository-name my-ecs-app --region us-east-1
                        """
                    }
                }
           }
    }
    

    post {
        success {
            echo 'Terraform execution completed successfully!'
        }

        failure {
            echo 'Terraform pipeline failed. Check the console output.'
        }

        always {
            deleteDir()
        }
    }
}
