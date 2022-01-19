# backup-script

Simple script for backup management. This project contains three scripts.

- main script (script-LUCAS.sh) - performs the backup operations based on a configuration file;
- install script - this script creates the config file and copies the main script into a predefined directory. It must be executed as root.
- uninstall script - this script deletes the main script, the config file, the logs and all backups created, but not the directories since we can use an already existing directory for it. It must be executed as root.

**NOTE:** you must give execute permission to the install and uninstall scripts. The main script will be granted execution permission automatically via the install script. The uninstall script does NOT do error handling and should only be run when you are sure that the main script is installed. If the main script has already been removed, the uninstall script will not work properly.

To run the script, do the following steps:

Give permission for the install script to execute:

````bash
chmod +x isntall.sh
````

Then run the install script:

````bash
./install.sh
````

**NOTE: **if you try to run the main script directly, without running the install script, you will receive an error since the defined config file will not be found.

Running the install script, it will copy the main script to the directory '/usr/sbin' (it can be changed as you wish) and the config file will be created . After this, the main script is ready to be executed.

You can run the main script by navigating to '/usr/sbin' and typing ./script-LUCAS.sh <option>

````bash
cd /usr/sbin
./script-LUCAS.sh <option>
````

Or, if you prefer, by simple running the following command from any directory:

````bash
(cd /usr/sbin && ./script-LUCAS.sh <option>)
````

**NOTE:** the uninstall script will not be copied, if you want to, copy it manually.  
