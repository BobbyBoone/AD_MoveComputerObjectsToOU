# AD_MoveComputerObjectsToOU
# runs from Windows scheduler on a Windows Automation server
# Looks for new computer objects and moves to the approprite OU, based on the Computer's CIDR range
# if the computer is not found to be an EC2 instance, it is moved to the 'notfound' OU
# also updates the description field in AD with EC2 metadata, inc name tag, instance ID and IP address
# This is helpful as the default hostname in AWS is computer generated and thus meaningless
