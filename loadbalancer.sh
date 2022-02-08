#!/bin/bash
#2db EC2 instance indítása
start_instances() {
aws ec2 run-instances --image-id ami-042ad9eec03638628 \
--count 1 --instance-type t2.micro --key-name erdelyi-tamas \
--security-group-ids sg-08fb876c08317c18c \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=erdelyi-tamas-nginx1}]'

aws ec2 run-instances --image-id ami-042ad9eec03638628 \
--count 1 --instance-type t2.micro --key-name erdelyi-tamas \
--security-group-ids sg-08fb876c08317c18c \
--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=erdelyi-tamas-nginx2}]'
starter
}

describe_my_instances() {
    aws ec2 describe-instances --filters "Name=tag:Name,Values=erdely*"
#Only instance IDs
    aws ec2 describe-instances --filters "Name=tag:Name,Values=erdely*" \
     --output text --query 'Reservations[*].Instances[*].InstanceId'
#InstanceID and public IP
    aws ec2 describe-instances --filters "Name=tag:Name,Values=erdelyi*" "Name=instance-state-name,Values=running" \
       --output text --query 'Reservations[*].Instances[*].[PublicIpAddress,InstanceId,Tags[?Key==`Name`].Value]'
}

install_nginx() {
read -p "How many instance:" num
if [ "$num" == 1 ]
then
    read -p "IP address:" address
    ssh -i "/e/erdelyi-tamas.pem" ubuntu@$address < nginx.sh
    starter
elif [ "$num" == 2 ]
then
    read -p "IP address 1:" address1
    read -p "IP address 2:" address2
    ssh -i "/e/erdelyi-tamas.pem" ubuntu@$address < nginx.sh
    ssh -i "/e/erdelyi-tamas.pem" ubuntu@$address2 < nginx2.sh
    starter
fi
}

create_target() {
#Target Group
aws elbv2 create-target-group --name team8-targetGroup --protocol HTTP \
--port 3000 --vpc-id vpc-0a169bcf3056ea695
starter
}

target_instances() {
#Add instances to the target group
read -p "First instance ID:" first
read -p "Second instance ID:" second
aws elbv2 register-targets --target-group-arn \
--targets Id=$first,$second
starter
}

help() {
    printf "            ec2 = Starting 2 EC2 instances \n
            nginx = Start nginx on the instances \n
            target = Creating target group \n
            ec2_target = Add instances to the target group \n
            exit = Exit the program \n"
    starter
}

starter() {
    read -p "Choose function:" func
    if [ "$func" == "help" ]
    then
    help
    elif [ "$func" == "ec2" ]
    then
    start_instances
    elif [ "$func" == "nginx" ]
    then
    install_nginx
    elif [ "$func" == "target" ]
    then
    create_target
    elif [ "$func" == "ec2_target" ]
    then
    target_instances
    elif [ "$func" == "exit" ]
    then
    exit
    fi
}
echo "Load Balancer project"
starter