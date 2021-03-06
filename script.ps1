<# Set global variables #>
param (
	[string]$Mode,
	[string]$BucketName
);
  
#
# Helper function to Import Module AWSPowershell
#
function Import-Module-AWSPowershell {
	if(Get-Module -ListAvailable -Name AWSPowershell) {
		Import-Module AWSPowershell
		Write-Host 'Success: AWS Tools imported'
	} else {
		Write-Host 'AWS Tools for Windows PowerShell not installed. Please install the latest version of the AWS Tools for Windows PowerShell and try again.'
		Write-Host 'Download location: https://aws.amazon.com/powershell/'
		Exit 255
	}
}


function Get-CloudWatchTemplate() {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string] $Mode,
    [Parameter(Mandatory=$true, Position=1)]
    [boolean] $Base,
    [Parameter(Mandatory=$true, Position=2)]
    [string] $BucketName
    )

	
    if ($Base) {
        $CloudWatchSSMConfig = (Get-SSMParameter -Name "/Config/CloudWatchAgent/Base/Windows").Value
    } else {
        if ($Mode -eq 'ssm') {
            $CloudWatchSSMConfig = (Get-SSMParameter -Name "/Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID"  -Region $env:AWS_SSM_REGION_NAME).Value
	    Write-Host "Success: Get CloudWatch configuration template from Parameter Store -Name: /Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID}"
        } else {
            Read-S3Object -BucketName $BucketName -Key "/Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID.amazon-cloudwatch-agent.json" -File $CloudWatchTempConfig -Region $env:AWS_SSM_REGION_NAME
	    Write-Host "Success: Get CloudWatch configuration template from S3 -Key: $BucketName/Config/CloudWatchAgent/Prod/${$env:AWS_SSM_INSTANCE_ID}.amazon-cloudwatch-agent.json"
            $CloudWatchSSMConfig = Get-Content $CloudWatchTempConfig
        }
    }

    return $CloudWatchSSMConfig
}


function Create-CloudWatchCustom() {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Template
    )

    Write-Host "Sucess: Create-CloudWatchCustom() -> JSON"
    return $Template
}

function Put-CloudWatchCustom() {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Mode,
    [Parameter(Mandatory=$true, Position=1)]
    [string]$Custom,
    [Parameter(Mandatory=$true, Position=2)]
    [string]$BucketName
    )

    $CloudWatchTempConfig = $env:Temp + '\CWAgent.json'
    $Custom | Set-Content $CloudWatchTempConfig
    
    
    if ($Mode -eq 'ssm') {
        Write-SSMParameter -Name "/Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID" -Value "$custom" -Type String -Overwrite $true -Region $env:AWS_SSM_REGION_NAME 
	Write-Host "Success: Put custom CloudWatch configuration template to Parameter Store -Name: /Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID"
    } else {
        Write-S3Object -BucketName $BucketName -Key "/Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID.amazon-cloudwatch-agent.json" -File $CloudWatchTempConfig -Region $env:AWS_SSM_REGION_NAME
	Write-Host "Success: Put custom CloudWatch configuration template to S3 -Key: /Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID.amazon-cloudwatch-agent.json"
    }

    Write-Host "Sucess: Put-CloudWatchCustom() -> $CloudWatchTempConfig"
    return $CloudWatchTempConfig
}

function Configure-CloudWatch() {
    param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Mode,
    [Parameter(Mandatory=$true, Position=1)]
    [string]$Config
    )

    $Cmd = "${Env:ProgramFiles}\Amazon\AmazonCloudWatchAgent\amazon-cloudwatch-agent-ctl.ps1"

    if (!(Test-Path -LiteralPath "${Cmd}")) {
        Write-Output 'CloudWatch Agent not installed.  Please install it using the AWS-ConfigureAWSPackage SSM Document.'
        Exit 1
    }

    $Params = @()

    if ($Mode -eq 'ssm') {
        $Config = "ssm:/Config/CloudWatchAgent/Prod/$env:AWS_SSM_INSTANCE_ID"
    } else {
        $Config = "file:$Config"
    }

    Write-Host "Config: $Config"
    $Params += ('-c', "${Config}")
    $Params += ('-a', 'fetch-config', '-m', 'auto', '-s')
    Write-Host "Execute: amazon-cloudwatch-agent-ctl.ps1 $Params"
    Invoke-Expression "& '${Cmd}' ${Params}"

}


function Main() {
    param(
    [string]$Mode,
    [string]$BucketName
    )
    
    Write-Output "Executing Main($Mode,$BucketName)"
    Import-Module-AWSPowershell
    $CloudWatchTemplate = Get-CloudWatchTemplate -Mode $Mode -Base $true -BucketName $BucketName
    $CloudWatchCustom = Create-CloudWatchCustom -Template $CloudWatchTemplate
    $Config = Put-CloudWatchCustom -Mode $Mode -Custom $CloudWatchCustom -BucketName $BucketName
    Configure-CloudWatch -Mode $Mode -Config "$Config"
    Write-Output "Success"
}

Main -Mode $Mode -BucketName $BucketName
Exit 0
    
