#!/usr/bin/python2.7

import boto3
from boto3.dynamodb.conditions import Key



############################################################################
# Purpose: Is run on an automation server, and pulls information from all aws accounts using Boto3
#          currently the account list is in the file, but will be moved to a dynamodb db
#          in a future version.
#          the output of this program is the creation of two files, ec2.txt and acct-name-ip.txt
#          ec2.txt gives the account, name tag, instanceID, instance type, platform, ip address, AMI image ID, 
#       keypair, state, whether it is in the scheduler, or has a backup plan
#          acct-name-ip.txt gives the account, nametag and IP address
#          This is called by maintainComputerOU.ps1 and run from a Windows Automation server
#          acct-name-ip.txt is an input to maintainComputerOU.ps1, and is used to provide ec2 metadata 
#          and is also used determine if an instance no longer exists in aws
#    
#
# Created By      : Bobby Boone
#
# Modification History  :
#         08/05/2020 - v1.0 - * Initial Version
#              
#
#
#
#Author   : Bobby Boone
#Copyright: Aflac Inc., All Rights reserved.
#



# create an STS client object that represents a live connection to the
# STS service
sts_client = boto3.client('sts')




########################################
# EC2 list all instances in an account #
########################################
def listInstances(account):

    role=":role/AWS-Enterprise-Automation"
#    print account
#    print role
    RoleArn = "arn:aws:iam::"+account+role
    #print 'RoleArn='+RoleArn
    #print '########################'
    # Call the assume_role method of the STSConnection object and pass the role
    # ARN and a role session name.
    assumed_role_object=sts_client.assume_role(
        RoleArn= RoleArn,
        RoleSessionName = "AssumeRoleSession1"
      )

    credentials=assumed_role_object['Credentials']

    ec2=boto3.resource(
       'ec2',
       aws_access_key_id=credentials['AccessKeyId'],
       aws_secret_access_key=credentials['SecretAccessKey'],
       aws_session_token=credentials['SessionToken'],
    )


    #print "  Ec2 Instances"
    #print " ---------------------------------------"
    #ec2info = defaultdict()

    for instance in ec2.instances.all():
       schedule = "Not-Scheduled"
       backupplan = "No-Backup"
       name = "NoNameTag"
       #print (instance.id, instance.private_ip_address)
       if instance.tags:
          for tag in instance.tags:
              #print "     ",  tag['Key'], tag['Value']
              if 'Name'in tag['Key']:
                  name = tag['Value']
              # is the instance scheduled vi the CCOE scheduler?
              if  tag['Key'] == 'afl-itsm-schedule-startstop':
                  schedule = 'schedule='+tag['Value']
              # is the instance scheduled via the GI scheduler?
              if  tag['Key'] == 'Schedule':
                  schedule = 'schedule='+tag['Value']
              # is the instance being backed up via AWS backup?
              if  tag['Key'] == 'BackupPlan':
                 #print "** found **"
                 backupplan = 'backupplan='+tag['Value']
              


       else:
          name = "NameTag=NULL"

       platform =  "Windows"

       #print (name, instance.id, instance.instance_type, instance.platform, instance.private_ip_address, instance.platform,instance.image_id, instance.key_pair,instance.state['Name'])

       state = str(instance.state['Name'])
       #print (dir(instance))
       if instance.platform is None:
          platform = ""
       else:
          platform = str(instance.platform)

       if instance.key_pair is None:
          keypair = ""
       else: 
          keypair = str(instance.key_pair)

       #ec2file.write(account+" , "+name+" , "+instance.id+" , "+instance.instance_type+" , "+platform+" , "+str(instance.private_ip_address)+" , "+instance.image_id+" , "+keypair+" , "+state+" , "+schedule+" , "+backupplan+"\n")
       ec2file.write(account+" , "+name+" , "+instance.id+" , "+instance.instance_type+" , "+platform+" ,-"+str(instance.private_ip_address)+"-, "+instance.image_id+" , "+keypair+" , "+state+" , "+schedule+" , "+backupplan+"\n")
       acctNameFile.write(account+" , "+name+" ,-"+str(instance.private_ip_address)+"-,"+instance.id+" \n")
    return()


testaccounts = [
  '228186319646',
  '270123770161',
  '683374124303'
  ]

#####################
#         main      #
#####################

home = "c:/maintainOU/"
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('AWS-Accounts')
ec2file = open("c:/maintainOU/ec2.txt", 'w')
acctNameFile = open(home+"acct-name-ip.txt", 'w')

#acctNameFile = open("c:/maintainOU/acct-name-ip.txt", 'w')
response = table.scan()
data = response['Items']
max = len(data)
#print max
#print data
#print(response['Items'])


for a in range (0,max):

    listInstances(data[a] ['account'])


ec2file.close()
acctNameFile.close()

