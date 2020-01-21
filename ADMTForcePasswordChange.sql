-- Show All the Accounts based on where  
SELECT [ObjectId]
      ,[ADsPath]
      ,[SamName]
      ,[Type]
	    ,[PasswordCopyTime]
  FROM [ADMT].[dbo].[Objects] o
  join [ADMT].[dbo].[MigratedObjects] m on m.SourceObjectId = o.ObjectId
  where ADSpath LIKE 'SOMETHING'
  order by ADsPath

-- Reset All the Accounts based on where  
  UPDATE m
   SET PasswordCopyTime = NULL
   from [ADMT].[dbo].[MigratedObjects] m
   JOIN [ADMT].[dbo].[Objects] o
     ON m.SourceObjectId = o.ObjectId
	WHERE o.ADSpath LIKE 'SOMETHING' AND
	      m.PasswordCopyTime IS NOT NULL
	      -- or specify specific object
              AND o.ObjectId = '5E4E7708-1E0A-4422-A2CC-775C3DD5913C'
