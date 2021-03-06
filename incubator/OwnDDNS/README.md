## i-MSCP OwnDDNS plugin v0.0.1

Plugin allows to manage your own DDNS service with i-MSCP.

If you install this plugin manually, make sure you install it in
gui/plugins/ - in a different folder the plugin will not work.

### LICENSE

Copyright (C) Sascha Bay <info@space2place.de>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; version 2 of the License

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

See [GPL v2](http://www.gnu.org/licenses/gpl-2.0.html "GPL v2")

### REQUIREMENTS

	Plugin compatible with i-MSCP versions >= 1.1.0.rc4.7
	Bind must be activated on i-MSCP
	Domain for your OwnDDNS must use the nameserver of your i-MSCP installation
	
### INSTALLATION AND UPDATE

**1.** Backup your current plugins/OwnDDNS/config.php

**2.** Get the plugin

	# cd /usr/local/src
	# git clone git://github.com/i-MSCP/plugins.git

**3.** Copy the plugin directory into the gui/plugins directory of your i-MSCP installation.

	# cp -fR plugins/OwnDDNS /var/www/imscp/gui/plugins

**4.** Set permissions by running:

	# perl /var/www/imscp/engine/setup/set-gui-permissions.pl

**5.** Go to the panel plugins interface, update the plugin list and activate the plugin.

### IMPORTANT
	Some FRITZ!Box models don't work with a SSL url.
	FRITZ!Box model: 3270, 7250, 7270

### AUTHORS AND CONTRIBUTORS

 - Sascha Bay <info@space2place.de> (Author)

**Thank you for using this plugin.**
