$settingsFile='conf.ini'

Get-Content $settingsFile | foreach-object -begin {$settings=@{}} -process { $k = $_.split('=',2); if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { $settings.Add($k[0], $k[1]) } }


$DBServer_SRC=$settings.Get_Item("DBServer_SRC")
$DBName_SRC=$settings.Get_Item("DBName_SRC")
$DBUser_SRC=$settings.Get_Item("DBUser_SRC")
$DBPassword_SRC=$settings.Get_Item("DBPassword_SRC")

$DBServer_TGT=$settings.Get_Item("DBServer_TGT")
$DBName_TGT=$settings.Get_Item("DBName_TGT")
$DBUser_TGT=$settings.Get_Item("DBUser_TGT")
$DBPassword_TGT=$settings.Get_Item("DBPassword_TGT")



#################################################################################################### FUNCIONES
function getTime($nil){
	$a = Get-Date
	return $a.ToShortDateString()+" "+$a.ToShortTimeString()
}


function logToFile([string]$Message){ 
	$Message=$Message.replace("`n"," ").replace("`r","")
	$FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
	"$FormattedDate $Message" | Out-File -FilePath $logFile -Append
}


function getDocumentsWithLinks($documentsCollections){
	logToFile "### Getting documents with links in target system"
	$query = "select ref_persid,actual_text from long_texts where actual_text like '%OpenDocumentViewer(%' or actual_text like '%OpenDocument(%'"

	logToFile "### $query"
	logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT"

	push-location
	$rows = Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT -Query $query
    pop-location

	foreach ($row in $rows){
		$oneDocument = New-Object System.Object
		$relatedDocuments = New-Object System.Collections.ArrayList

		$oneDocument | Add-Member -MemberType NoteProperty -Name "persid" -Value $row.ref_persid
		$oneDocument | Add-Member -MemberType NoteProperty -Name "actual_text" -Value $row.actual_text
		($row.actual_text | Select-String "/OpenDocument(Viewer)?\(([0-9]{6})(,[0-9])?\)/gs" -AllMatches) | Foreach-Object {$_.Matches} | Foreach-Object { $relatedDocuments.Add((New-Object System.Object) | Add-Member -MemberType NoteProperty -Name "id_old" -Value $_.Groups[2].Value) }
		$oneDocument | Add-Member -MemberType NoteProperty -Name "related_documents" -Value $relatedDocuments
		
		$documentsCollections.Add($oneDocument) | Out-Null
	}

	#Printing documentsCollections
	logToFile ($documentsCollections | Format-Table | Out-String)
	return $documentsCollections
}

function getRelatedDocumentsInfoFromSource($documents){
	logToFile "### Getting related documents' info from source system"

	foreach($document in $documents){
		foreach($related_document in $document.related_documents){
			$query = "select title from skeletons where id = $related_document.id_old"
			logToFile "### $query"
			logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_SRC -Database $DBName_SRC -Username $DBUser_SRC -Password $DBPassword_SRC"

			push-location
			$row = Invoke-Sqlcmd -ServerInstance $DBServer_SRC -Database $DBName_SRC -Username $DBUser_SRC -Password $DBPassword_SRC -Query $query
			pop-location

			if(-Not $row){
				logToFile "### NOT FOUND: document title in source for related_document_old_id:$related_document.id_old - parent document:$document.persid"
			}else{
				$related_document | Add-Member -MemberType NoteProperty -Name "title" -Value $row.title	
			}
		}
	}

	#Printing documentsCollections
	logToFile ($documents | Format-Table | Out-String)
	return $documentsCollections
}

function getRelatedDocumentsInfoFromTarget($documents){
	logToFile "### Getting related documents' info from target system"

	foreach($document in $documents){
		foreach($related_document in $document.related_documents){
			$query = "select top 1 id from skeletons where title = '$related_document.title'"
			logToFile "### $query"
			logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT"

			push-location
			$row = Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT -Query $query
			pop-location

			if(-Not $row){
				logToFile "### NOT FOUND: document id in target for related_document_title:$related_document.title - parent document:$document.persid"
			}else{
				$related_document | Add-Member -MemberType NoteProperty -Name "id" -Value $row.id	
			}	
		}
	}
	
	return $documentsCollections
}

function generateUpdateSentenceForDocuments($documents){
	logToFile "#### SQL Update sentences"

	foreach($document in $documents){
		foreach($related_document in $document.related_documents){
			$query = "UPDATE long_texts SET actual_text=REPLACE(actual_text,'$related_document.old_id','$related_document.id') WHERE ref_persid='$document.persid'"
			logToFile $query
		}
	}
	logToFile "####"
}



function getDocumentsWithAttachments(){
	logToFile "### Getting documents with attachments in target system"
	$query = "select ref_persid,actual_text from long_texts where actual_text like '%OpenDocumentViewer(%' or actual_text like '%OpenDocument(%'"

	logToFile "### $query"
	logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT"

	push-location
	$rows = Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT -Query $query
    pop-location

	$documentsCollections = New-Object System.Collections.ArrayList
	foreach ($row in $rows){
		$oneDocument = New-Object System.Object
		$relatedAttachments = New-Object System.Collections.ArrayList

		$oneDocument | Add-Member -MemberType NoteProperty -Name "persid" -Value $row.ref_persid
		$oneDocument | Add-Member -MemberType NoteProperty -Name "actual_text" -Value $row.actual_text
		($row.actual_text | Select-String "/AttmntId=([0-9]{6,7})/gs" -AllMatches) | Foreach-Object {$_.Matches} | Foreach-Object { $relatedImages.Add((New-Object System.Object) | Add-Member -MemberType NoteProperty -Name "id_old" -Value $_.Groups[2].Value) }
		$oneDocument | Add-Member -MemberType NoteProperty -Name "related_attachments" -Value $relatedAttachments
		
		$documentsCollections.Add($oneDocument) | Out-Null
	}

	#Printing documentsCollections
	logToFile ($documentsCollections | Format-Table | Out-String)
	return $documentsCollections
}

function validateIfAttachmentsAreBroken($attachments){
	logToFile "### Validating if attachments are broken attachments in target System"
	$brokenAttachments = New-Object System.Collections.ArrayList

	foreach($attachment in $attachments){
		foreach($related_attachment in $document.related_attachments){
			$query = "select id from attmnt where id = $related_attachment.id_old"
			logToFile "### $query"
			logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT"

			push-location
			$row = Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT -Query $query
			pop-location

			if(-Not $row){
				logToFile "### NO: Attachment is broken: attachment_old_id:$related_attachment.id_old - parent document:$document.persid"
				brokenAttachments.Add($related_attachment)
			}else{
				logToFile "### OK: Attachment is not broken: attachment_old_id:$related_attachment.id_old - attachment_id:$row.id - parent document:$document.persid"
			}
		}
	}

	#Printing documentsCollections
	logToFile ($brokenAttachments | Format-Table | Out-String)
	return $brokenAttachments
}

function getRelatedDocumentsAttachmentsInfoFromSource($documents){
	logToFile "### Getting related attachments' info from source system"

	foreach($document in $documents){
		foreach($related_attachment in $document.related_attachments){
			$query = "select orig_file_name,file_size from attmnt where id = $related_attachment.id_old"
			logToFile "### $query"
			logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_SRC -Database $DBName_SRC -Username $DBUser_SRC -Password $DBPassword_SRC"

			push-location
			$row = Invoke-Sqlcmd -ServerInstance $DBServer_SRC -Database $DBName_SRC -Username $DBUser_SRC -Password $DBPassword_SRC -Query $query
			pop-location

			if(-Not $row){
				logToFile "### NOT FOUND: attachment in source for attachment_old_id:$related_attachment.id_old - parent document:$document.persid"
			}else{
				$related_attachment | Add-Member -MemberType NoteProperty -Name "orig_file_name" -Value $row.orig_file_name	
				$related_attachment | Add-Member -MemberType NoteProperty -Name "file_size" -Value $row.file_size	
			}
		}
	}

	#Printing documentsCollections
	logToFile ($documents | Format-Table | Out-String)
	return $documentsCollections
}

function getRelatedAttachmentsInfoFromTarget($documents){
	logToFile "### Getting related attachments' info from target system"

	foreach($document in $documents){
		foreach($related_attachment in $document.related_attachments){
			$query = "select top 1 id from attmnt where orig_file_name = '$related_attachment.orig_file_name'"
			logToFile "### $query"
			logToFile "### Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT"

			push-location
			$row = Invoke-Sqlcmd -ServerInstance $DBServer_TGT -Database $DBName_TGT -Username $DBUser_TGT -Password $DBPassword_TGT -Query $query
			pop-location

			if(-Not $row){
				logToFile "### NOT FOUND: attachment id in target for related_attachment:$related_attachment.orig_file_name - parent document:$document.persid"
			}else{
				$related_attachment | Add-Member -MemberType NoteProperty -Name "id" -Value $row.id	
			}	
		}
	}
	
	return $documentsCollections
}

function generateUpdateSentenceForAttachments($documents){
	logToFile "#### SQL Update sentences"

	foreach($document in $documents){
		foreach($related_attachment in $document.related_attachments){
			$query = "UPDATE long_texts SET actual_text=REPLACE(actual_text,'$related_attachment.old_id','$related_attachment.id') WHERE ref_persid='$document.persid'"
			logToFile $query
		}
	}
	logToFile "####"
}


#################################################################################################### MAIN
logToFile " ## FixLinks"

try{
	$documentsWithLinks = New-Object System.Collections.ArrayList

	$documentsWithLinks = getDocumentsWithLinks
	$documentsWithLinks = getRelatedDocumentsInfoFromSource $documentsWithLinks
	$documentsWithLinks = getRelatedDocumentsInfoFromTarget $documentsWithLinks

	generateUpdateSentenceForDocuments $documentsWithLinks

	$documentsWithAttachments = New-Object System.Collections.ArrayList

	$documentsWithAttachments = getDocumentsWithAttachments 
	$documentWithBrokenAttachments = validateIfAttachmentsAreBroken $documentsWithAttachments
	$documentWithBrokenAttachments = getRelatedDocumentsAttachmentsInfoFromSource $documentWithBrokenAttachments
	$documentWithBrokenAttachments = getRelatedDocumentsInfoFromTarget $documentWithBrokenAttachments

	generateUpdateSentenceForAttachments $documentsWithLinks
}catch{
	logToFile " ## EXCEPTION ERROR"
	logToFile " ## $_"
	Write-Host $_
}


		
	
	
	
