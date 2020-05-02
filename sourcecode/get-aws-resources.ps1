[CmdletBinding()]
Param(
   #[Parameter(Mandatory=$true)]$OpsGenieKey
   #$ResourceParsers = Import-Csv -Path ./resourceinput.csv
   # $ResourceParsers = Import-Csv -Path ./samppple.csv
   $AWSS3Flag = $true
)
begin{
    $ResourceList = @()
    try {
        Import-Module -Name AWSPowerShell.NetCore
        $AWSRegion = Get-AwsRegion
    }
    catch {
        write-host $_.Exception.Message -ForegroundColor Red
        write-host $_.Exception.ItemName -ForegroundColor Red
    }
}
process{
        $ResourceParsers = Import-Csv -Path ./resourceinput_V2.csv
        #$AWSRegion = "us-west-2"
        foreach($Region in $AWSRegion){
            try {
                Write-Host "Set AWS Location $Region" -ForegroundColor Green
                Write-Host "***************************************************************************************************"  -ForegroundColor Green          
                Write-Host " Started to Collect Resources from the Region : $Region********************************************" -ForegroundColor Green
                Write-Host "***************************************************************************************************" -ForegroundColor Green
                set-defaultawsregion $Region | Out-Null
                #Region Test
                $test = Get-EC2Subnet
                foreach($ResourceParser in $ResourceParsers){
                    Write-host "Get the AWS Resource of type : " $ResourceParser.ResourceType -ForegroundColor Yellow
                    $ResourceType = $ResourceParser.ResourceType
                    $ServiceName = $ResourceParser.'Service-Name'
                    $ResourceCommand = $ResourceParser.Command
                    $ResourceId = $ResourceParser.ResourceID
                    $Tags = $ResourceParser.Tags
                    $TagCommand = $ResourceParser.TagCommand
                    $TagResourceName = $ResourceParser.TagResourceName
                    $TagResourceLists = $ResourceParser.TagLists
                    if($ResourceType -eq "S3Bucket" -and $AWSS3Flag -eq $false){
                            Write-host "check-skip for S3" -ForegroundColor Yellow
                            continue
                    }
                    try {
                        if($Tags -eq "Indirect"){
                            #test

                            if($ResourceType -eq "S3Bucket"){
                                $AWSS3Flag = $false
                            }
                            $GetObjectswithTags = & $ResourceCommand
                            foreach($GetObjectswithTag in $GetObjectswithTags){
                                    try {
                                        $GetObjectswithTag | Add-Member -PassThru -NotePropertyName 'Tags' -NotePropertyValue @(
                                        Invoke-Expression "$TagCommand $($GetObjectswithTag.$TagResourceName)"
                                        ) | Out-Null
                                    }
                                    catch {
                                        #Write-Host "Failed to get the resource `$GetObjectswithTag : $TagCommand $($GetObjectswithTag.$TagResourceName)" -ForegroundColor Red
                                        #write-host $_.Exception.Message -ForegroundColor Red
                                        #write-host $_.Exception.ItemName -ForegroundColor Red 
                                        continue
                                    }
                            }
                            $AwsResourceProperty = $GetObjectswithTags
<#                             $AwsResourceProperty = & $ResourceCommand |
                            % {
                                try {
                                    $_ | add-member -PassThru -NotePropertyName 'Tags' -NotePropertyValue @(
                                        #get-rdstagforresource -ResourceName $_.DBInstanceArn 
                                        #Invoke-Expression "$TagCommand -ResourceName $($_.$TagResourceName)"
                                        Invoke-Expression "$TagCommand $($_.$TagResourceName)"
                                    ) 
                                }
                                catch {
                                    continue
                                }

                            } #>
                        }else {
                            $AwsResourceProperty = Invoke-Expression $ResourceCommand
                        }
                        if($ResourceType -eq "EC2Instance"){
                            foreach($AwsResource in $AwsResourceProperty){
                                if($AwsResource.Instances.Count -gt 1){
                                    <# if($AwsResource.Instances.VpcId.count -gt 1) {
                                        $Vpcid = $AwsResource.Instances.VpcId[1]
                                    } else {
                                        $Vpcid = $AwsResource.Instances.VpcId
                                    } #>
                                    $i = 0
                                    for($i -eq 0;$i -lt $AwsResource.Instances.Count; $i++){
                                        if ($i -eq 0){
                                            $VpcName = (Get-EC2Vpc -VpcId $AwsResource[$i].Instances.vpcid).Tags | ?  { $_.Key -eq "Name" } | % { $_.Value }
                                        }
                                        $VpcId = $AwsResource[$i].Instances.vpcid
                                        if($VpcName.length -eq 2){
                                            $VpcName = $VpcName[1]
                                        } else {
                                            $VpcName =$VpcName
                                        }
                                        if($VpcId.length -eq 2){
                                            $VpcId = $VpcId[1]
                                        } else {
                                            $VpcId =$VpcId
                                        }
                                        $ResourceList += [PSCustomObject][ordered]@{
                                            Service_Name = $ServiceName 
                                            ResourceType = $ResourceType
                                            ResourceID = $AwsResource.Instances.InstanceId[$i]
                                            VpcName = $VpcName
                                            Vpcid = $VpcId
                                            Region = $Region 
                                        }
                                            #Update Tags
                                            $TagLists = $TagResourceLists.split(" ")
                                            foreach($TagList in $TagLists){
                                                $PropertyName  = $TagList
                                                $PropertyValue = $AwsResource.Instances[$i].Tags | ? { $_.Key -eq $TagList } | % { $_.Value }
                                                    $ResourceList[-1] | Add-Member -PassThru -NotePropertyName $PropertyName -NotePropertyValue $PropertyValue | Out-Null
                                            } 
                                    }
                                }else{
                                    $VpcName = (Get-EC2Vpc -VpcId $AwsResource.Instances.vpcid).Tags | ?  { $_.Key -eq "Name" } | % { $_.Value }
                                    $VpcId = $AwsResource.Instances.vpcid
                                    if($VpcName.length -eq 2){
                                        $VpcName = $VpcName[1]
                                    } else {
                                        $VpcName =$VpcName
                                    }
                                    if($VpcId.length -eq 2){
                                        $VpcId = $VpcId[1]
                                    } else {
                                        $VpcId =$VpcId
                                    }
                                    $ResourceList += [PSCustomObject][ordered]@{
                                        Service_Name = $ServiceName 
                                        ResourceType = $ResourceType
                                        ResourceID = $AwsResource.Instances.InstanceId
                                        VpcName = $VpcName
                                        Vpcid = $VpcId
                                        Region = $Region                                    
                                    }
                                        #Update Tags
                                        $TagLists = $TagResourceLists.split(" ")
                                        foreach($TagList in $TagLists){
                                            $PropertyName  = $TagList
                                            $PropertyValue = $AwsResource.Instances.Tags | ? { $_.Key -eq $TagList } | % { $_.Value }
                                                $ResourceList[-1] | Add-Member -PassThru -NotePropertyName $PropertyName -NotePropertyValue $PropertyValue | Out-Null
                                        } 
                                }
                            }
                        }else {
                            foreach($AwsResource in $AwsResourceProperty){
                                if ($ResourceType -eq "RDSSDInstance"){
                                    $VpcId = $AwsResource.DBSubnetGroup.VpcId
                                    $VpcName = (Get-EC2Vpc -VpcId $AwsResource.DBSubnetGroup.vpcid).Tags | ?  { $_.Key -eq "Name" } | % { $_.Value }
                                } else {
                                    $VpcId = $AwsResource.VpcId
                                    $VpcName = (Get-EC2Vpc -VpcId $AwsResource.vpcid).Tags | ?  { $_.Key -eq "Name" } | % { $_.Value }
                                }
                                if($VpcName.length -eq 2){
                                    $VpcName = $VpcName[1]
                                } else {
                                    $VpcName =$VpcName
                                }
                                if($VpcId.length -eq 2){
                                    $VpcId = $VpcId[1]
                                } else {
                                    $VpcId =$VpcId
                                }
                                $ResourceList += [PSCustomObject][ordered]@{
                                        #ResourceID = $_.VpcId
                                        Service_Name = $ServiceName
                                        ResourceType = $ResourceType
                                        ResourceID = $AwsResource.$ResourceId
                                        VpcName = $VpcName
                                        Vpcid = $VpcId
                                        Region = $Region
                                        #Billingpod = $AwsResource.$Tags | ? { $_.Key -eq 'BILLINGPOD' } | % { $_.Value }
                                        #BusinessEntity = $AwsResource.$Tags | ? {$_.Key -eq 'BUSINESSENTITY'} | % { $_.Value}
                                        #BusinessUnit = $AwsResource.$Tags | ? {$_.Key -eq 'BUSINESSUNIT'} | % { $_.Value}
                                        #OwnerEmail = $AwsResource.$Tags | ? {$_.Key -eq 'OWNEREMAIL'} | % { $_.Value}
                                    }
                                    #Update Tags
                                    $TagLists = $TagResourceLists.split(" ")
                                    foreach($TagList in $TagLists){
                                        $PropertyName  = $TagList
                                        if($Tags -eq "Indirect" -and ($ResourceType -eq "RDSSDInstance" -or $ResourceType -eq "RDSDBCluster" -or $ResourceType -eq "Lambda" -or $ResourceType -eq "S3Bucket" -or $ResourceType -eq "RDSDBSubnetGroup")){
                                            #test
                                            $PropertyValue = $AwsResource.Tags | ? { $_.Key -eq $TagList } | % { $_.Value }
                                            
                                        }elseif($Tags -eq "Indirect"){
                                            $PropertyValue = $AwsResource.Tags.Tags | ? { $_.Key -eq $TagList } | % { $_.Value }
                                        }
                                        else{
                                            $PropertyValue = $AwsResource.$Tags | ? { $_.Key -eq $TagList } | % { $_.Value }
                                        }
                                        $ResourceList[-1] | Add-Member -PassThru -NotePropertyName $PropertyName -NotePropertyValue $PropertyValue -Force | Out-Null
                                    } 
                                    #test
                                    #break   
                            }
                        }
                    }
                    catch {
                        Write-Host "Failed to get the resource `$ResourceCommand : $ResourceCommand" -ForegroundColor Red
                        write-host $_.Exception.Message -ForegroundColor Red
                        write-host $_.Exception.ItemName -ForegroundColor Red 
                        continue
                    }
                
                }   
            Write-Host "*******************************************************************************************************"  -ForegroundColor Green          
            Write-Host "Successfully Collected Resources from the Region : $Region*********************************************" -ForegroundColor Green
            Write-Host "*******************************************************************************************************" -ForegroundColor Green
            }
            catch {
                Write-Host "Failed to get the resource from the Region : $Region" -ForegroundColor Red
                write-host $_.Exception.Message -ForegroundColor Red
                write-host $_.Exception.ItemName -ForegroundColor Red 
                continue
            }
        }
}
end{
    $ResourceList | Export-Csv -Path .\AwsResourceList_S.csv
}
