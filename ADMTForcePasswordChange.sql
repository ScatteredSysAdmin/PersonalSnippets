-- Show All the Accounts based on where  
SELECT [ADsPath]
      ,[SamName]
      ,[Type]
	    ,[PasswordCopyTime]
  FROM [ADMT].[dbo].[Objects] o
  join [ADMT].[dbo].[MigratedObjects] m on m.SourceObjectId = o.ObjectId
  where ADSpath LIKE 'SOMETHING'
  order by ADsPath

