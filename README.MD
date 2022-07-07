[Source](https://betterprogramming.pub/how-to-use-webpack-module-federation-in-react-70455086b2b0)
[Repository](https://github.com/rautio/react-micro-frontend-example)

## Terraform

### Terraform init
```
cd terraform
terraform init
tf workspace new mod-fed-poc
cd ..
```

### Terraform plan
`npm run plan -w terraform`

### Terraform apply
`npm run apply -w terraform`

### Terraform destroy plan
`npm run plan-destroy -w terraform`

### Output a secret variable
`cd terraform;terraform output create-case-api-dev-key;cd ..`

## AWS

### Recursively copy files to s3
`aws s3 cp ./host/dist s3://host-webcontent --recursive`