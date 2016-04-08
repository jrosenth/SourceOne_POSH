		# get script location
		$scriptDirectory = Split-Path $myinvocation.mycommand.path
		$folderDefaults = join-path $scriptDirectory 'folderdefaults.xml'


	     # Make sure the input file exists...
        if (!(Test-Path -path $folderDefaults) )
        {
            throw "Folder default settings file not found: $folderDefaults"
        }

        [System.Xml.XmlDocument] $settingsxml = new-object System.Xml.XmlDocument

        $settingsxml.load($folderDefaults)      
  
		$GeneralSettings = $settingsxml.SelectSingleNode('/ES1FolderDefaults/ArchiveFolder/General')

        $ContentCache = [System.Convert]::ToBoolean($GeneralSettings.ContentCache)
		$MaxIndexSize = [System.Convert]::ToInt32($GeneralSettings.MaxIndexSize)
		$FullTextEnabled = [System.Convert]::ToBoolean($GeneralSettings.FullTextEnabled)
		$MaxVolumeSize = [System.Convert]::ToInt32($GeneralSettings.MaxVolumeSize)
		$AttachmentIndexing = [System.Convert]::ToBoolean($GeneralSettings.AttachmentIndexing)
		
        
        if ($test)
        {
            Write-Host "ContentCache is $test"
        }


