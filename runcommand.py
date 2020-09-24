#!/usr/bin/python2.7

import sys
import boto3
tstfile = open("c:/maintainOU/tstfile.txt", 'w')
instanceId = (sys.argv[1])
tstfile.write (instanceId)
print instanceId 
sm = boto3.client('ssm' )    
testCommand = sm.send_command( InstanceIds=[ instanceId ], DocumentName='AWS-RunPowerShellScript',  Parameters={ "commands":[ "c:/download/runonce.bat" ]}  )
#ssm = boto3.client('ssm' )    
#testCommand = ssm.send_command( InstanceIds=[ 'i-123123123123' ], DocumentName='AWS-RunShellScript', Comment='la la la', OutputS3BucketName='myOutputS3Bucket', OutputS3KeyPrefix='i-123123123123', Parameters={ "commands":[ "ip config" ]  } )
#print testcommand
#tstfile = open("c:/src/tstfile.txt", 'w')

print testCommand






