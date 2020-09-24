# AD_MoveComputerObjectsToOU
# Runs from Windows scheduler on a Windows Automation server
# Looks for new AD computer objects gets IP, then moves to the approprite OU, based on the Computer's CIDR range
# Also queries EC2 metadata, and  if the computer is not found to be an EC2 instance, it is moved to the 'notfound' OU
# also updates the description field in AD with EC2 metadata, inc name tag, instance ID and IP address
# This is helpful as the default hostname in AWS is computer generated and thus meaningless
# enhancement would be to create a similar program that would traverse all OU's and perform the same task
# such that any terminatea EC2 instanced would be removed from the active OU's
