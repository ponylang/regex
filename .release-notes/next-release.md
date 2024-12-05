## Use the native `Expand-Archive` command on Windows to extract PCRE source

Prior to this we were using 7Zip, which is installed on our CI environments but not by default on Windows, to extract the PCRE source zip file; we now use the native Windows PowerShell command.

