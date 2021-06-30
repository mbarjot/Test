#First of all, we have to type the 2 commented lines bellow in powershell to secure the VCenter password
#$PassKey = [byte]95,13,58,45,22,11,88,82,11,34,67,91,19,20,96,82
#"PasswordExemple" | Convertto-SecureString -AsPlainText -Force | ConvertFrom-SecureString -key $PassKey | Out-file D:\ESGI\Scripts\PassKey.txt

$Server = "172.180.0.200" #Variable that contains the IP address of the VCenter

$User = "administrator@labvmware.local" #Variable that contains the username of the VCenter

$PassKey = [byte]95,13,58,45,22,11,88,82,11,34,67,91,19,20,96,82 #Variable that contains the key to uncrypt the crypted password

#Variable that will get the crypted password in the .txt file and will uncrypt it thanks to the key
$Password = Get-Content PassKey.txt | Convertto-SecureString -Key $PassKey 

#Variable that contains the username and the password of the VCenter
$Credentials = New-Object -TypeName System.Management.Automation.PsCredential -ArgumentList ($User, $Password)

#We connect to the VCenter
Connect-VIServer -Server $Server -Credential $Credentials

$TestVCenter = @() #Variable that will contains the VMHost of the VCenter
$TestVCenter = Get-VMHost #We try to get the VMHost of the VCenter

#We will check if we are connected to the VCenter thanks to the variable $TestVCenter, if we are not, the script will end here
Do
	{
		#If the variable is not blank anymore, it means that the command Get-VMHost worked and therefore we are connected to the vcenter
		If ($TestVCenter -ne "")
		{
			break
		}
		#If the variable is still blank, it means that the command Get-VMHost did not found anything because we are not connected on VCenter
		#Therefore, we disconnect from the VCenter and we notify the technician that the script is going to exit, and we exit it 3 seconds later
		Write-Host "`nThe connection to the VCenter failed, please retry after further verifications" -ForegroundColor Red
		Write-Host "`nThe script is exiting, please wait..." -ForegroundColor Yellow
		Start-Sleep -Seconds 3
		exit
	}

#The Until command here is not very useful, but it is necessary to for proprer functioning of the Do command, I tried to make this "VCenter Check" whith only and If command
#but it did not worked and i do not know why
Until ($TestVCenter -ne "")

#The two commented lines bellow permit to create the file which contains the crypted password of the sender email, they have to be in the script for the first execution
#and can be commented for the next executions of the script

#Read-Host -AsSecureString | ConvertFrom-SecureString | out-file -FilePath mbarjot@myges.fr.securestring
#New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "mbarjot@myges.fr",(Get-Content -Path mbarjot@myges.fr.securestring | ConvertTo-SecureString)

#We put in a variable the csv that we import thanks to the command Import-CSV
$vms = Import-CSV donneeVM.csv

#We initialize the variables

$namecreated = @() #Variable that contains the name of the created VMs
$nameerror = @() #Variable that contains the name of the VMs that will encounter an error during creation
$namecancel = @() #Variable that contains the name of the VMs which the creation has been canceled
$statcreated = 0 #Variable that contains the percentage of created VMs
$staterror = 0 #Variable that contains the percentage of VMs that encountered an error during creation
$statcancel = 0 #Variable that contains the percentage of VMs which the creation has been canceled
$numcreated = 0 #Variable that contains the number of created VMs 
$numerror = 0 #Variable that contains the number of VMs that will encounter an error during creation
$numcancel = 0 #Variable that contains the number of VMs which the creation has been canceled
$numtotal = 0 #Variable that contains the number of VMs (all the VMs)
 
#Loop that will work on each column of the csv imported previously
#Each column is a VM intended to be created
foreach ($vm in $vms)
{
	#The parameters needed to create the VM are stored in the following variables
	
	$Name = $vm.Name #Variable that contains the name of the VM
	$VMHost = $vm.VMHost #Variable that contains the IP address of the host (ESXi) where the VM must be created
	$Datastore = $vm.Datastore #Variable that contains the name of the datastore where the VM must be created
	$MemoryMB = $vm.MemoryMB #Variable that contains the amount of memory (in MB) of the VM
	$DiskMB = $vm.DiskMB #Variable that contains the size (in MB) of the VM disk
	$DiskStorageFormat = $vm.DiskStorageFormat #Variable that contains the format of the VM disk
	$NumCpu = $vm.NumCpu #Variable that contains the number of CPUs of the VM
	$CD = $vm.CD #Variable that contains if "YES" or "NO" the VM will have a CD player
	$Note = $vm.Note #Variable that contains VM creation notes
	$Version = $vm.Version #Variable that contains the version of the VM
	$Mail = $vm.Mail #Variable that contains the email address of the requestor of the VM creation, an email will be send to the address to confirm the creation of the VM
	$Error = "" #Variable that contains a blank message, this variable will be use to compare with another variable which
	#may contain an error message if the creation of the VM encounters a problem
	
	#We inform the technician that a VM is about to be created, we summarize all the parameters for the VM creation
	Write-Host "`n`nProceed with creation of a virtual machine with the following parameters :`n" -ForegroundColor Yellow
	Write-Host "Name : " -NoNewLine; Write-Host "$Name" -ForegroundColor Green
	Write-Host "VMHost : " -NoNewLine; Write-Host "$VMHost" -ForegroundColor Green
	Write-Host "Datastore : " -NoNewLine; Write-Host "$Datastore" -ForegroundColor Green
	Write-Host "MemoryMB : " -NoNewLine; Write-Host "$MemoryMB MB" -ForegroundColor Green
	Write-Host "DiskMB : " -NoNewLine; Write-Host "$DiskMB MB" -ForegroundColor Green
	Write-Host "DiskStorageFormat : " -NoNewLine; Write-Host "$DiskStorageFormat" -ForegroundColor Green
	Write-Host "NumCpu : " -NoNewLine; Write-Host "$NumCpu CPU" -ForegroundColor Green
	Write-Host "CD : " -NoNewLine; Write-Host "$CD" -ForegroundColor Green
	Write-Host "Note : " -NoNewLine; Write-Host "$Note" -ForegroundColor Green
	Write-Host "Version : " -NoNewLine; Write-Host "$Version" -ForegroundColor Green

	#The technician has to confirm if he wants to create the VM, in the case where one of the parameters is wrong he can cancel the creation
	#A variable will store what the technician wants to do
	Write-Host "`nType " -NoNewLine; Write-Host "[y] yes, " -NoNewLine -ForegroundColor Green; `
	Write-Host "[n] no " -NoNewLine -ForegroundColor Red;
	Write-Host "or " -NoNewLine; Write-Host "[q] quit " -NoNewLine -ForegroundColor DarkGray; $confirm = Read-Host "to continue/quit "
		
		#The previous variable will be analyze to see if the script can continue or not
		Do
		{
			#If what the technician typed matches what is expected, the script continues
			If (($confirm -eq "y") -or ($confirm -eq "n") -or ($confirm -eq "q") -or ($confirm -eq "yes") -or ($confirm -eq "no") -or ($confirm -eq "quit"))
			{
				break
			}
			#In the case where the technician does not type something that allows the creation/cancellation of the VM or that allows him
			#to exit the script, an error message is displayed asking to type "[y] yes, [n] no or [q] quit"
			Write-Host "`n/!\ ERROR /!\" -NoNewLine -ForegroundColor Red;
			Write-Host "`nPlease type " -NoNewLine; Write-Host "[y] yes, " -NoNewLine -ForegroundColor Green; `
			Write-Host "[n] no " -NoNewLine -ForegroundColor Red;
			Write-Host "or " -NoNewLine; Write-Host "[q] quit " -NoNewLine -ForegroundColor DarkGray; $confirm = Read-Host "to continue/quit "
		}
		
		#Until the technician type something that matches what is expected, the error message will be displayed
		Until (($confirm -eq "y") -or ($confirm -eq "n") -or ($confirm -eq "q") -or ($confirm -eq "yes") -or ($confirm -eq "no") -or ($confirm -eq "quit"))
		
		#In the case where the technician ask for the VM creation 
		if (($confirm -eq "y") -or ($confirm -eq "yes"))
		{
		
			#if the VM has to be created without a CD player
			if ($CD -eq "no")
			{
				#we try to create the VM if possible
				try
				{
					New-VM -Name $Name -VMHost $VMHost -Datastore $Datastore `
					-MemoryMB $MemoryMB  -DiskMB $DiskMB -DiskStorageFormat $DiskStorageFormat `
					-NumCpu $NumCpu -Note $Note -Version $Version -RunAsync -ErrorAction Stop
				}
				
				#otherwise, if the creation cannot be completed due to an error
				catch
				{
					#we put in the error variable created previously, the title of the error encountered stored automatically in the variable $_
					$Error="$_"
					#we display the error to the technician
					Write-Host "`n$_`n" -foregroundcolor red
				}
				
				#if the $Error variable is still blank it means that we can the VM has been created
				if ($Error -eq "")
				{
					#we notify that the creation of the VM is a success
					Write-Host "`nThe creation of the virtual machine $Name is a success." -ForegroundColor Green
				}
			}
		
			#otherwise, if the VM has to be created with a CD player 
			else
			{
				#we try to create the VM if possible
				try
				{
					New-VM -Name $Name -VMHost $VMHost -Datastore $Datastore `
					-MemoryMB $MemoryMB  -DiskMB $DiskMB -DiskStorageFormat $DiskStorageFormat `
					-NumCpu $NumCpu -CD -Note $Note -Version $Version -RunAsync -ErrorAction Stop
				}
				
				#otherwise, if the creation cannot be completed due to an error
				catch
				{
					#we put in the error variable created previously, the title of the error encountered stored automatically in the variable $_
					$Error="$_"
					#we display the error to the technician
					Write-Host "`n$_`n" -foregroundcolor red
				}
				
				#if the $Error variable is still blank it means that we can the VM has been created
				if ($Error -eq "")
				{
					#we notify the technician that the creation of the VM is a success
					Write-Host "`nThe creation of the virtual machine $Name is a success." -ForegroundColor Green
				}
			}

			#In the case where the error variable is still a blank message
			if ($Error -eq "")
			{
				#We add the name of the created VM in the variable created previously	
				$namecreated += $Name
			
				#A variable will contains the body of the HTML mail
				#The mail informs the customer that the creation of the VM he asked for is a success, that this is an automatic message and ask the customer to not respond
				#We display in the mail the name of the created VM
				$Mail_CustTrue = "<body style=background-color:#ebebeb><center><b><font color=red><h1>Dear Maxime BARJOT</h1></font></b>
				<br>
				<h2><font color=#000001>This is an automatic mail to inform you that the creation of a Virtual Machine has been a <font color=green>success</font>. Please do not reply.
				<br>
				The following VM has been created : <font color=#78a5ad>$Name</font></h2>
				<br>
				-------------------------------------------------------------------------------------------------------------------------------------------------------------
				<br>
				For more informations, please contact the technical support.
				<br>
				Best regards.<br></font></center></body>."
				
				#The mail is then send to the mail address provided in the csv
				#The following command will send the mail from the email adress provided directly in the command
				#We fill in a subject for the mail, we define the body as a HTML body, the smtp server, the port used to send the mail
				#We used the authentification file created thanks to the line 23 and 24, to permit the sender to send the mail without typing a password
				Send-MailMessage -From mbarjot@myges.fr -To $Mail -Subject "VM Creation - Success" -BodyAsHtml $Mail_CustTrue `
				-SmtpServer SMTP.office365.com -Port 587 -Credential (New-Object -TypeName System.Management.Automation.PSCredential `
				-ArgumentList "mbarjot@myges.fr",(Get-Content -Path mbarjot@myges.fr.securestring | ConvertTo-SecureString)) -UseSsl
			}
			
			#In the case where the error variable is no longer a blank message, and then contains an error message
			else
			{
				#We display an error message to inform the technician that the creation of the VM failed
				Write-Host "The creation of the VM"$Name" has failed" -ForegroundColor Red
				
				#We add the name of the VM that encounters an error in the variable created previously
				$nameerror += $Name
			
				#A variable will contains the body of the HTML mail
				#The mail informs the technician that the creation of the VM is a failure, that this is an automatic message and ask the technician to not respond
				#We display in the mail the error encountered and all the parameters of the VM that encountered an error during the creation
				$Mail_Tech = "<body style=background-color:#ebebeb><center><b><font color=red><h1>Dear Maxime BARJOT</h1></font></b>
				<br>
				<h2><font color=#000001>This is an automatic mail to inform you that the creation of the virtual machine <font color=#78a5ad>$Name</font> has <font color=red>failed</font>. Please do not reply.
				<br>
				The following issue has been found : 
				<br>
				<font color=red>$Error</font></h2>
				<br>
				<h3>The parameters of the VM are :
				<br>
				<font color=#425948>Name : $Name
				<br>
				VMHost : $VMHost
				<br>
				Datastore : $Datastore
				<br>
				MemoryMB : $MemoryMB MB
				<br>
				DiskMB : $DiskMB MB
				<br>
				DiskStorageFormat : $DiskStorageFormat
				<br>
				NumCpu : $NumCpu CPU
				<br>
				CD : $CD
				<br>
				Note : $Note
				<br>
				Version : $Version</font></h3>
				<br>
				<br>
				-------------------------------------------------------------------------------------------------------------------------------------------------------------
				<br>
				For more informations, please contact the technical support.
				<br>
				Best regards.<br></font></center></body>."
				
				#The mail is then send to the mail address of the technician
				#The following command will send the mail from the email adress provided directly in the command
				#We fill in a subject for the mail, we define the body as a HTML body, the smtp server, the port used to send the mail
				#We used the authentification file created thanks to the line 23 and 24, to permit the sender to send the mail without typing a password
				Send-MailMessage -From mbarjot@myges.fr -To $Mail -Subject "The creation of this VM failed" -BodyAsHtml $Mail_Tech `
				-SmtpServer SMTP.office365.com -Port 587 -Credential (New-Object -TypeName System.Management.Automation.PSCredential `
				-ArgumentList "mbarjot@myges.fr",(Get-Content -Path mbarjot@myges.fr.securestring | ConvertTo-SecureString)) -UseSsl
				
				#A variable will contains the body of the HTML mail
				#The mail informs the customer that the creation of the VM he asked for is a failure, that this is an automatic message and ask the customer to not respond
				#We display a message to give the name of the VM that encountered an error during the creation
				$Mail_CustFalse = "<body style=background-color:#ebebeb><center><b><font color=red><h1>Dear Maxime BARJOT</h1></font></b>
				<br>
				<h2><font color=#000001>This is an automatic mail to inform you that the creation of the virtual machine <font color=#78a5ad>$Name</font> has <font color=red>failed</font. Please do not reply.</h2>
				<br>
				-------------------------------------------------------------------------------------------------------------------------------------------------------------
				<br>
				For more informations, please contact the technical support.
				<br>
				Best regards.<br></font></center></body>."
				
				#The mail is then send to the mail address provided in the csv
				#The following command will send the mail from the email adress provided directly in the command
				#We fill in a subject for the mail, we define the body as a HTML body, the smtp server, the port used to send the mail
				#We used the authentification file created thanks to the line 23 and 24, to permit the sender to send the mail without typing a password
				Send-MailMessage -From mbarjot@myges.fr -To $Mail -Subject "VM Creation - Failure" -BodyAsHtml $Mail_CustFalse `
				-SmtpServer SMTP.office365.com -Port 587 -Credential (New-Object -TypeName System.Management.Automation.PSCredential `
				-ArgumentList "mbarjot@myges.fr",(Get-Content -Path mbarjot@myges.fr.securestring | ConvertTo-SecureString)) -UseSsl
				
			}
			
		}
			
		#In the case where the technician does no ask for the VM creation and canceled it
		elseif (($confirm -eq "n") -or ($confirm -eq "no"))
		{
			#We add the name of the canceled VM in the variable created previously
			$namecancel += $Name
			#We display a message to inform that the creation of the VM has been canceled
			Write-Host "`nThe creation of the virtual machine $Name has been canceled.`n" -ForegroundColor Red
		}
		
		#In the case where the technician wants to exit the script 
		else
		{
			#We disconnect from the VCenter
			Disconnect-VIServer -confirm:$false
			#We notify the technician that the we are disconnecting from the VCenter, and that script is going to exit, and we exit it 3 seconds later
			Write-Host "`nDisconnecting from the Vcenter..." -ForegroundColor Yellow
			Write-Host "`nThe script is exiting, please wait..." -ForegroundColor Yellow
			Start-Sleep -Seconds 3
			exit
		}
}

#if the list containing the name of the created VMs is not empty
if ($namecreated -ne @())
{
	#a summary of the created VMs is displayed
	Write-Host "`nThe following(s) virtual machine(s) has been created : $namecreated" -ForegroundColor Green
}

#if the list containing the name of VMs that encountered an error is not empty
if ($nameerror -ne @())
{
	#a summary of the VMs that encountered an error is displayed
	Write-Host "`nThe following(s) virtual machine(s) could not be created due to an error : $nameerror" -ForegroundColor Red
}

#if the list containing the name of the canceled VMs is not empty
if ($namecancel -ne @())
{
	#a summary of the canceled VMs is displayed
	Write-Host "`nThe creation of the following(s) virtual machine(s) has been canceled : $namecancel" -ForegroundColor Gray
}

#we count the number of created VMs and put it in the variable created previously
$numcreated = $namecreated.Count

#we count the number of VMs that encountered an error and put it in the variable created previously
$numerror = $nameerror.Count

#we count the number of canceled VMs and put it in the variable created previously
$numcancel = $namecancel.Count

#we add the three variables seens previously to get the exact number of VMs that were supposed to be created 
$numtotal = $numcreated + $numerror + $numcancel

#we calcultate the percentage of created VMs compared to the total number of VMs
$statcreated = ($numcreated * 100) / $numtotal
#we round off the result to not have very long number 
$statcreated = [math]::Round($statcreated,2)

#we calcultate the percentage of VMs that encountered an error compared to the total number of VMs
$staterror = ($numerror * 100) / $numtotal
#we round off the result to not have very long number
$staterror = [math]::Round($staterror,2)

#we calcultate the percentage of canceled VMs compared to the total number of VMs
$statcancel = ($numcancel * 100) / $numtotal
#we round off the result to not have very long number
$statcancel = [math]::Round($statcancel,2)

#A variable will contains the body of the HTML mail
#The mail informs the manager of what happened during the execution of the script, that this is an automatic message and ask the manager to not respond
#We display the exact number of VMs that the technician attempted to create, the statistics of successful/failed/canceled creation
#and give the exact number of VMs for each of theses statistics
$Mail_Manager = "<body style=background-color:#ebebeb><center><b><font color=red><h1>Dear Maxime BARJOT</h1></font></b>
<br>
<h2><font color=#000001>This is an automatic mail to give you informations about the creations of several virtual machines. Please do not reply.</font>
<br>
Number of virtual machines the script tried to create : $numtotal 
<br>
<font color=green>Percentage of successful creation : $statcreated % ($numcreated virtual machines)</font>
<br>
<font color=red>Percentage of failed creation : $staterror % ($numerror virtual machines)</font>
<br>
<font color=orange>Percentage of canceled creation : $statcancel % ($numcancel virtual machines)</font></h2>
<br>
-------------------------------------------------------------------------------------------------------------------------------------------------------------
<br>
<font color=#000001>For more informations, please contact the technical support.
<br>
Best regards.<br></font></center></body>."

#The mail is then send to the mail address of the manager
#The following command will send the mail from the email adress provided directly in the command
#We fill in a subject for the mail, we define the body as a HTML body, the smtp server, the port used to send the mail
#We used the authentification file created thanks to the line 23 and 24, to permit the sender to send the mail without typing a password
Send-MailMessage -From mbarjot@myges.fr -To $Mail -Subject "VM Creation - Summary" -BodyAsHtml $Mail_MANAGER `
-SmtpServer SMTP.office365.com -Port 587 -Credential (New-Object -TypeName System.Management.Automation.PSCredential `
-ArgumentList "mbarjot@myges.fr",(Get-Content -Path mbarjot@myges.fr.securestring | ConvertTo-SecureString)) -UseSsl

#When the script is done, we disconnect from the VCenter
Disconnect-VIServer -confirm:$false
#We notify the technician that we are disconnecting from the VCenter, and we exit the script 3 seconds later
Write-Host "`nDisconnecting from the Vcenter..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
exit