#!/usr/bin/bash

## This script will make a backup of the different tables, views and packages from an specified schema.

# 1. Define paths and variables to use.
# Note: export_user subdirectory is a defined expdp folder.
export_user='/oracle/oradata/export_user/'
date=$(date +%Y%m%d)
tmpdir="/tmp/db_objects_backup_$date"
dbuser="DBUSER"
dbpwd="DBPWD"

# 2. Apply the Oracle environment.
export ORACLE_SID=SIDPDC
export ORAENV_ASK=NO
. /oracle/product/19c/bin/oraenv

# 3. Now, let's enter on the export directory and let's start with the actual backup.
cd $export_user 
mkdir /tmp/matrix_backup_$date

# 3.1. To export the different TABLES that you want, let's first use the usual expdp that will go
# through a tables.txt file (previously created with one line per table). This will create one OCTET
# .sql binary file that will need impdp to reload.
for line in `cat /tmp/tables.txt`; do 
	expdp userid=$dbuser/$dbpwd directory=EXPORT_USER dumpfile=$line.sql TABLES=$dbuser.$line
done

# 3.2 To export the tables in a different way more readable way, we'll use the fn_gen_inserts.sql that you
# can find here: https://github.com/teopost/oracle-scripts/blob/master/fn_gen_inserts.sql
# To make it work, we'll first recompile the function and then we'll process again the tables.txt file.
# We are doing this in order to have a readable version of the tables as well as the impdp ones.
sqlplus -s $dbuser/$dbpwd @/tmp/fn_gen_inserts.sql
for line in `cat /tmp/tables.txt`; do 
sqlplus -s $dbuser/$dbpwd  << EOF
	set heading off;
	set echo off;
	Set pages 999;
	set long 90000;
	spool $tmpdir/$line.sql
	select fn_gen_inserts('select * from $line', '$line', '$dbuser') from dual;
	spool off;
EOF
done

# 3.3 To make the same but with the different view, we'll have to use the dbms_metadata
# and the get_ddl function that will get the actual pl/sql code. For this, you'll need
# a views.txt file with the same logic as the tables.txt one.
for line in `cat /tmp/views.txt`; do 
sqlplus -s $dbuser/$dbpwd  << EOF
	set heading off;
	set echo off;
	Set pages 999;
	set long 90000;
	spool $tmpdir/$line.sql
	select dbms_metadata.get_ddl('VIEW','$line','$dbuser') from dual;
	spool off;
EOF
done

# 3.4 And in the end, to do the same with packages, we'll do similar as with views.
# For this, you'll need a packages.txt file with the same logic as the tables.txt one.
for line in `cat /tmp/packages.txt`; do 
sqlplus -s BOPRD/"yas6Bp_XnD#_QmhVRy3g4_b#h"  << EOF
	set heading off;
	set echo off;
	Set pages 999;
	set long 90000;
	spool $tmpdir/$line.sql
	select dbms_metadata.get_ddl('PACKAGE','$line','BOPRD') from dual;
	spool off;
EOF
done

# 4. To end this, we'll make a few modifications of permissions and make a tar with the backup.
chmod +r $export_user/*.sql
cp $export_user/*.sql $tmpdir
rm $export_user/*.sql $export_user/export.log

cd /tmp
tar -zcvf $tmpdir.tar.gz $tmpdir
rm -rf $tmpdir

exit $?
