#!/bin/bash
#Order: start_instance, describe, nginx, create_target, target_instanced
ip1=""
ip2=""
id1=""
id2=""
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
#InstanceID and public IP
desc=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=erdelyi*" "Name=instance-state-name,Values=running" \
       --output text --query 'Reservations[*].Instances[*].[PublicIpAddress,InstanceId,Tags[?Key==`Name`].Value]')
while IFS=" " read -r ips
do
ezaz+="$ips "
done <<< "$desc"
ip1=$(echo $ezaz | cut -d " " -f 1)
ip2=$(echo $ezaz | cut -d " " -f 4)
id1=$(echo $ezaz | cut -d " " -f 2)
id2=$(echo $ezaz | cut -d " " -f 5)
echo "First instance IP:" $ip1 "ID:" $id1
echo "Second instance IP:" $ip2 "ID:" $id2
starter
}

install_nginx() {
read -p "How many instance:" num
if [ "$num" == 1 ]
then
    ssh -i "/home/ubuntu/host/erdelyi-tamas.pem" ubuntu@$ip1 < nginx.sh
    starter
elif [ "$num" == 2 ]
then
    ssh -i "/home/ubuntu/host/erdelyi-tamas.pem" ubuntu@$ip1 < nginx.sh
    ssh -i "/home/ubuntu/host/erdelyi-tamas.pem" ubuntu@$ip2 < nginx2.sh
    starter
fi
}

create_target() {
#Target Group OK
aws elbv2 create-target-group --name team8-targetGroup --protocol HTTP \
--target-type instance \
--port 3000 --vpc-id vpc-0a169bcf3056ea695 --health-check-port 3000 \
--health-check-enabled --health-check-path / --health-check-interval-seconds 5 \
--health-check-timeout-seconds 2 --healthy-threshold-count 2 \
--matcher HttpCode="200"
starter
}

target_instances() {
#Add instances to the target group OK
grouparn=$(aws elbv2 describe-target-groups --names team8-targetGroup | grep -i "TargetGroupArn" | cut -d '"' -f 4)

aws elbv2 register-targets --target-group-arn $grouparn \
--targets Id=$id1 Id=$id2
starter
}

loadbalancer() {
    aws ec2 create-security-group --group-name team8-loadbalance \
    --description "Load balancer for team 8" \
    --vpc-id vpc-0a169bcf3056ea695

aws elbv2 create-load-balancer --name team8-loadbalancer \
--subnets \
--security-groups 

loadbalancearn=$()

aws elbv2 create-listener --load-balancer-arn $loadbalancearn \
--protocol HTTP --port 80 \
--default-actions Type=forward,TargetGroupArn=$grouparn
starter
}

help() {
    printf "            ec2 = Starting 2 EC2 instances \n
            nginx = Start nginx on the instances \n
            describe = Describe my instances \n
            target = Creating target group \n
            ec2_target = Add instances to the target group \n
            loadbalancer = Creating application load balancer \n
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
    elif [ "$func" == "describe" ]
    then
    describe_my_instances
    elif [ "$func" == "target" ]
    then
    create_target
    elif [ "$func" == "ec2_target" ]
    then
    target_instances
    elif [ "$func" == "loadbalancer" ]
    then
    loadbalancer
    elif [ "$func" == "exit" ]
    then
    exit
    fi
}
echo "Load Balancer project"
starter