echo off

call ./bin/setup

set IMPORT_FILE_LOG=".\log\import_post_season_file.log"
set IMPORT_FILE_CONFIG=".\config\import_post_season_config.r"

%R_HOME% --vanilla -f .\lib\ImportPostSeasonFile.r --args %IMPORT_FILE_CONFIG% > %IMPORT_FILE_LOG% 2>&1
.\bin\tail -n 30 %IMPORT_FILE_LOG%

pause
