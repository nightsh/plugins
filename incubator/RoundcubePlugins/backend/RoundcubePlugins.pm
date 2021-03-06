#!/usr/bin/perl

# i-MSCP - internet Multi Server Control Panel
# Copyright (C) 2010-2013 by internet Multi Server Control Panel
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
#
# @category    i-MSCP
# @package     iMSCP_Plugin
# @subpackage  RoundcubePlugins
# @copyright   Rene Schuster <mail@reneschuster.de>
# @copyright   Sascha Bay <info@space2place.de>
# @author      Rene Schuster <mail@reneschuster.de>
# @author      Sascha Bay <info@space2place.de>
# @link        http://i-mscp.net i-MSCP Home Site
# @license     http://www.gnu.org/licenses/gpl-2.0.html GPL v2

package Plugin::RoundcubePlugins;

use strict;
use warnings;

use iMSCP::Database;
use iMSCP::Debug;
use iMSCP::Dir;
use iMSCP::Execute;
use iMSCP::File;
use Servers::cron;
use JSON;

use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 This package provides the backend part for the i-MSCP RoundcubePlugins plugin.

=head1 PUBLIC METHODS

=over 4

=item install()

 Perform install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
	my $self = shift;

	my $rs = $self->_installPlugins();
	return $rs if $rs;

	$rs = $self->_setPluginConfig('managesieve', 'config.inc.php');
	return $rs if $rs;

	$rs = $self->_setPluginConfig('newmail_notifier', 'config.inc.php');
	return $rs if $rs;

	$rs = $self->_setPluginConfig('pop3fetcher', 'imscp_fetchmail.php');
	return $rs if $rs;

	0;
}

=item change()

 Perform change tasks

 Return int 0 on success, other on failure

=cut

sub change
{
	my $self = shift;

	my $rs = $self->install();
	return $rs if $rs;

	0;
}

=item update()

 Perform update tasks

 Return int 0 on success, other on failure

=cut

sub update
{
	my $self = shift;

	my $rs = $self->install();
	return $rs if $rs;

	0;
}

=item enable()

 Perform enable tasks

 Return int 0 on success, other on failure

=cut

sub enable
{
	my $self = shift;
	
	my $rs = $self->_checkRoundcubePlugins();
	return $rs if $rs;
	
	0;
}

=item disable()

 Perform disable tasks

 Return int 0 on success, other on failure

=cut

sub disable
{
	my $self = shift;
	
	my $rs = $self->_setRoundcubePlugin('archive', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('calendar', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('libcalendaring', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('contextmenu', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('dkimstatus', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('emoticons', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('logon_page', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('managesieve', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('newmail_notifier', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('pdfviewer', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('pop3fetcher', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('tasklist', 'remove');
	return $rs if $rs;
	
	$rs = $self->_setRoundcubePlugin('zipdownload', 'remove');
	return $rs if $rs;	
	
	$rs = $self->_unregisterCronjobPop3fetcher();
	return $rs if $rs;
	
	$rs = $self->_modifyDovecotConfig('archive', 'remove');
	return $rs if $rs;
	
	$rs = $self->_modifyDovecotConfig('managesieve', 'remove');
	return $rs if $rs;
	
	$rs = $self->_restartDaemonDovecot();
	return $rs if $rs;
	
	0;
}

=item uninstall()

 Perform uninstall tasks

 Return int 0 on success, other on failure

=cut

sub uninstall
{
	my $self = shift;
	
	my $rs = $self->_removePluginFile('managesieve', 'config.inc.php');
	return $rs if $rs;
	
	$rs = $self->_removePluginFile('managesieve', 'imscp_default.sieve');
	return $rs if $rs;
	
	$rs = $self->_removePluginFile('newmail_notifier', 'config.inc.php');
	return $rs if $rs;
	
	$rs = $self->_removePlugins();
	return $rs if $rs;
	
	0;
}

=item fetchmail()

 Fetch emails from external pop3 accounts

 Return int 0 on success, other on failure

=cut

sub fetchmail
{
	my $self = shift;
	
	my $fetchmail = "$main::imscpConfig{'GUI_ROOT_DIR'}/public/tools" . $main::imscpConfig{'WEBMAIL_PATH'} . "plugins/pop3fetcher/imscp_fetchmail.php";
	
	my ($stdout, $stderr);	
	my $rs = execute("$main::imscpConfig{'CMD_PHP'} $fetchmail", \$stdout, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	return $rs if $rs;
	
	0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init()

 Initialize plugin

 Return Plugin::RoundcubePlugins

=cut

sub _init
{
	my $self = shift;
	
	# Force return value from plugin module
	$self->{'FORCE_RETVAL'} = 'yes';
	
    if($self->{'action'} ~~ ['install', 'change', 'update', 'enable', 'disable']) {
		# Loading plugin configuration
		my $rdata = iMSCP::Database->factory()->doQuery(
			'plugin_name', 'SELECT plugin_name, plugin_config FROM plugin WHERE plugin_name = ?', 'RoundcubePlugins'
		);
		unless(ref $rdata eq 'HASH') {
			error($rdata);
			return 1;
		}

		$self->{'config'} = decode_json($rdata->{'RoundcubePlugins'}->{'plugin_config'});
	}
	
	$self;
}

=item _installPlugins()

 Copy the plugins to the Roundcube Plugin folder.

 Return int 0 on success, other on failure

=cut

sub _installPlugins()
{
	my $self = shift;
	
	my $roundcubePlugin = "$main::imscpConfig{'GUI_ROOT_DIR'}/plugins/RoundcubePlugins/roundcube-plugins";
	my $configPlugin = "$main::imscpConfig{'GUI_ROOT_DIR'}/plugins/RoundcubePlugins/config-templates";
	my $pluginFolder = "$main::imscpConfig{'GUI_ROOT_DIR'}/public/tools" . $main::imscpConfig{'WEBMAIL_PATH'} . "plugins";
	
	my ($stdout, $stderr);
	my $rs = execute("$main::imscpConfig{'CMD_CP'} -fR $roundcubePlugin/* $pluginFolder/", \$stdout, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	return $rs if $rs;
	
	$rs = execute("$main::imscpConfig{'CMD_CP'} -fR $configPlugin/* $pluginFolder/", \$stdout, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	return $rs if $rs;
	
	my $panelUName = $main::imscpConfig{'SYSTEM_USER_PREFIX'} . $main::imscpConfig{'SYSTEM_USER_MIN_UID'};
	my $panelGName = $panelUName;
	
	require iMSCP::Rights;
	iMSCP::Rights->import();
	$rs = setRights(
		"$pluginFolder/",
		{ 'user' => $panelUName, 'group' => $panelGName, 'dirmode' => '0550', 'filemode' => '0440', 'recursive' => 1 }
	);
	return $rs if $rs;
	
	0;
}

=item _removePlugins()

 Remove the Plugins from the Roundcube Plugin folder.

 Return int 0 on success, other on failure

=cut

sub _removePlugins()
{
	my $self = shift;
	
	my $roundcubePlugin = "$main::imscpConfig{'GUI_ROOT_DIR'}/plugins/RoundcubePlugins/roundcube-plugins";
	my $pluginFolder = "$main::imscpConfig{'GUI_ROOT_DIR'}/public/tools" . $main::imscpConfig{'WEBMAIL_PATH'} . "plugins";
	
	foreach my $plugin (glob($roundcubePlugin . "/*")) {
		$plugin =~ s%$roundcubePlugin/(.*)%$pluginFolder/$1%gm;
		my $rs = iMSCP::Dir->new('dirname' => $plugin)->remove() if -d $plugin;
		return $rs if $rs;
	}
	
	0;
}

=item _removePluginFile($plugin, $fileName)

 Remove Plugin config file.

 Return int 0 on success, other on failure

=cut

sub _removePluginFile($$$)
{
	my ($self, $plugin, $fileName) = @_;
	
	my $removeFile = "$main::imscpConfig{'GUI_ROOT_DIR'}/public/tools" . $main::imscpConfig{'WEBMAIL_PATH'} . "plugins/$plugin/$fileName";
	
	my ($stdout, $stderr);
	my $rs = execute("$main::imscpConfig{'CMD_RM'} -f $removeFile", \$stdout, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	return $rs if $rs;
	
	0;
}

=item _setRoundcubePlugin($plugin, $action)

 Activate or deactivate the Roundcube Plugin.

 Return int 0 on success, other on failure

=cut

sub _setRoundcubePlugin($$$)
{
	my ($self, $plugin, $action) = @_;
	
	my $roundcubeMainIncFile = "$main::imscpConfig{'GUI_ROOT_DIR'}/public/tools" . $main::imscpConfig{'WEBMAIL_PATH'} . "config/main.inc.php";
	my $file = iMSCP::File->new('filename' => $roundcubeMainIncFile);
	
	my $fileContent = $file->get();
	unless (defined $fileContent) {
		error("Unable to read $roundcubeMainIncFile");
		return 1;
	}
	
	if($plugin eq 'contextmenu') {
		if($action eq 'add') {
			if($fileContent =~ /imscp_pw_changer/sgm) {
				$fileContent =~ s/'$plugin',\s+//g;
				$fileContent =~ s/'imscp_pw_changer'/'$plugin', 'imscp_pw_changer'/g;
			}
		} 
		elsif($action eq 'remove') {
			if($fileContent =~ /$plugin/sgm) {
				$fileContent =~ s/'$plugin',\s+//g;
			}
		}
	}
	elsif($plugin ~~ ['tasklist', 'pop3fetcher']) {
		if($action eq 'add') {
			if($fileContent =~ /calendar/sgm) {
				$fileContent =~ s/,\s+'$plugin'//g;
				$fileContent =~ s/'calendar'/'calendar', '$plugin'/g;
			}
			elsif($fileContent =~ /imscp_pw_changer/sgm) {
				$fileContent =~ s/'$plugin',\s+//g;
				$fileContent =~ s/imscp_pw_changer/imscp_pw_changer', '$plugin/g;
			}
		} 
		elsif($action eq 'remove') {
			if($fileContent =~ /$plugin/sgm) {
				$fileContent =~ s/,\s+'$plugin'//g;
			}
		}
	} 
	else {
		if($action eq 'add') {
			if($fileContent =~ /imscp_pw_changer/sgm) {
				$fileContent =~ s/,\s+'$plugin'//g;
				$fileContent =~ s/imscp_pw_changer/imscp_pw_changer', '$plugin/g;
			}
		} 
		elsif($action eq 'remove') {
			if($fileContent =~ /$plugin/sgm) {
				$fileContent =~ s/,\s+'$plugin'//g;
			}
		}
	}
	
	my $rs = $file->set($fileContent);
	return $rs if $rs;
	
	$rs = $file->save();
	return $rs if $rs;
	
	0;
}

=item _checkRoundcubePlugins()

 Check which Roundcube Plugins have to be activated.

 Return int 0 on success, other on failure

=cut

sub _checkRoundcubePlugins
{
	my $self = shift;
	
	my $rs = 0;
	
	if($self->{'config'}->{'archive_plugin'} eq 'yes') {	
		$rs = $self->_setRoundcubePlugin('archive', 'add');
		return $rs if $rs;
		
		$rs = $self->_modifyDovecotConfig('archive', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('archive', 'remove');
		return $rs if $rs;
		
		$rs = $self->_modifyDovecotConfig('archive', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'calendar_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('libcalendaring', 'add');
		$rs = $self->_setRoundcubePlugin('calendar', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('libcalendaring', 'remove');
		$rs = $self->_setRoundcubePlugin('calendar', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'contextmenu_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('contextmenu', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('contextmenu', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'dkimstatus_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('dkimstatus', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('dkimstatus', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'emoticons_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('emoticons', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('emoticons', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'logon_page_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('logon_page', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('logon_page', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'managesieve_plugin'} eq 'yes') {
		$rs = $self->_checkManagesieveRequirements();
		return $rs if $rs;
		
		$rs = $self->_setRoundcubePlugin('managesieve', 'add');
		return $rs if $rs;
		
		$rs = $self->_modifyDovecotConfig('managesieve', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('managesieve', 'remove');
		return $rs if $rs;
		
		$rs = $self->_modifyDovecotConfig('managesieve', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'newmail_notifier_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('newmail_notifier', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('newmail_notifier', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'pdfviewer_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('pdfviewer', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('pdfviewer', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'pop3fetcher_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('pop3fetcher', 'add');
		return $rs if $rs;
		
		$rs = $self->_registerCronjobPop3fetcher();
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('pop3fetcher', 'remove');
		return $rs if $rs;
		
		$rs = $self->_unregisterCronjobPop3fetcher();
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'tasklist_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('tasklist', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('tasklist', 'remove');
		return $rs if $rs;
	}
	
	if($self->{'config'}->{'zipdownload_plugin'} eq 'yes') {
		$rs = $self->_setRoundcubePlugin('zipdownload', 'add');
		return $rs if $rs;
	} else {
		$rs = $self->_setRoundcubePlugin('zipdownload', 'remove');
		return $rs if $rs;
	}
	
	$rs = $self->_restartDaemonDovecot();
	return $rs if $rs;
	
	0;
}

=item _setPluginConfig($plugin, $fileName)

 Set the values in the Plugin config file config.inc.php.

 Return int 0 on success, other on failure

=cut

sub _setPluginConfig($$$)
{
	my ($self, $plugin, $fileName) = @_;
	
	my $pluginFolder = "$main::imscpConfig{'GUI_ROOT_DIR'}/public/tools" . $main::imscpConfig{'WEBMAIL_PATH'} . "plugins";
	
	my $configFile = "$pluginFolder/$plugin/$fileName";
	my $file = iMSCP::File->new('filename' => $configFile);
	
	my $fileContent = $file->get();
	unless (defined $fileContent) {
		error("Unable to read $configFile");
		return 1;
	}
	
	if($plugin eq 'managesieve') {
		$fileContent =~ s%\{managesieve_default\}%$pluginFolder/$plugin/imscp_default.sieve%g;
		$fileContent =~ s/\{managesieve_script_name\}/$self->{'config'}->{'managesieve_script_name'}/g;
	}
	elsif($plugin eq 'newmail_notifier') {
		$fileContent =~ s/\{newmail_notifier_basic\}/$self->{'config'}->{'newmail_notifier_config'}->{'newmail_notifier_basic'}/g;
		$fileContent =~ s/\{newmail_notifier_sound\}/$self->{'config'}->{'newmail_notifier_config'}->{'newmail_notifier_sound'}/g;
		$fileContent =~ s/\{newmail_notifier_desktop\}/$self->{'config'}->{'newmail_notifier_config'}->{'newmail_notifier_desktop'}/g;
	}
	elsif($plugin eq 'pop3fetcher') {
		if($fileContent =~ /\{IMSCP-DATABASE\}/sgm) {
			$fileContent =~ s/\{IMSCP-DATABASE\}/$main::imscpConfig{'DATABASE_NAME'}/g;
		}
	}
	
	my $rs = $file->set($fileContent);
	return $rs if $rs;
	
	$rs = $file->save();
	return $rs if $rs;
	
	0;
}

=item _checkManagesieveRequirements()

 Check the managesieve requirements.

 Return int 0 on success, other on failure

=cut

sub _checkManagesieveRequirements
{
	my $self = shift;
	
	if(! -x '/usr/bin/sievec') {
		error('Unable to find sieve. Please, install the dovecot-sieve packages first.');
		return 1;
	}
	
	if(! -x '/usr/lib/dovecot/managesieve') {
		error('Unable to find managesieve. Please, install the dovecot-managesieve package first.');
		return 1;
	}
	
	0;
}

=item _modifyDovecotConfig($plugin, $action)

 Modify dovecot config file dovecot.conf.

 Return int 0 on success, other on failure

=cut

sub _modifyDovecotConfig($$$)
{
	my ($self, $plugin, $action) = @_;
	
	my $dovecotConfig = '/etc/dovecot/dovecot.conf';
	
	my $file = iMSCP::File->new('filename' => $dovecotConfig);
	
	my $fileContent = $file->get();
	unless (defined $fileContent) {
		error("Unable to read $dovecotConfig");
		return 1;
	}
	
	if($plugin eq 'archive') {	
		if($action eq 'add') {
			$fileContent =~ s/\n\t# Begin Plugin::RoundcubePlugin::archive.*Ending Plugin::RoundcubePlugin::archive\n//sgm;
			$fileContent =~ s/^(namespace\s+inbox\s+\{.*type\s*=\s*private)$/$1\n\n\t# Begin Plugin::RoundcubePlugin::archive\n\tmailbox Archive \{\n\t\tauto = subscribe\n\t\tspecial_use = \\Archive\n\t\}\n\t# Ending Plugin::RoundcubePlugin::archive/sgm;
		}
		elsif($action eq 'remove') {
			$fileContent =~ s/\n\t# Begin Plugin::RoundcubePlugin::archive.*Ending Plugin::RoundcubePlugin::archive\n//sgm;
		}
	}
	elsif($plugin eq 'managesieve') {
		if($action eq 'add') {
			$fileContent =~ s/^\t# Begin Plugin::RoundcubePlugin::managesieve::1st.*Ending Plugin::RoundcubePlugin::managesieve::1st\n//sgm;
			$fileContent =~ s/^(plugin\s+\{)/$1\n\t# Begin Plugin::RoundcubePlugin::managesieve::1st\n\tsieve = ~\/dovecot.sieve\n\t# Ending Plugin::RoundcubePlugin::managesieve::1st/sgm;
			
			$fileContent =~ s/^\t# Begin Plugin::RoundcubePlugin::managesieve::2nd.*Ending Plugin::RoundcubePlugin::managesieve::2nd\n/\tmail_plugins = \$mail_plugins\n/sgm;
			$fileContent =~ s/^(protocol\s+lda.*)(mail_plugins\s*=\s*\$mail_plugins)$/$1# Begin Plugin::RoundcubePlugin::managesieve::2nd\n\t$2 sieve\n\t# Ending Plugin::RoundcubePlugin::managesieve::2nd/sgm;
		}
		elsif($action eq 'remove') {
			$fileContent =~ s/^\t# Begin Plugin::RoundcubePlugin::managesieve::1st.*Ending Plugin::RoundcubePlugin::managesieve::1st\n//sgm;
			$fileContent =~ s/^\t# Begin Plugin::RoundcubePlugin::managesieve::2nd.*Ending Plugin::RoundcubePlugin::managesieve::2nd\n/\tmail_plugins = \$mail_plugins\n/sgm;
		}	
	}
	
	my $rs = $file->set($fileContent);
	return $rs if $rs;
	
	$rs = $file->save();
	return $rs if $rs;
	
	0;
}

=item _restartDaemonDovecot()

 Restart the Dovecot daemon.

 Return int 0 on success, other on failure

=cut

sub _restartDaemonDovecot
{
	my $self = shift;

	require Servers::po;
	Servers::po->factory()->{'restart'} = 'yes';

	0;
}

=item _registerCronjobPop3fetcher()

 Register pop3fetcher cronjob.

 Return int 0 on success, other on failure

=cut

sub _registerCronjobPop3fetcher
{
	my $self = shift;
	
	my $cronjobFilePath = "$main::imscpConfig{'GUI_ROOT_DIR'}/plugins/RoundcubePlugins/cronjob/cronjob_pop3fetcher.pl";
	
	my $cronjobFile = iMSCP::File->new('filename' => $cronjobFilePath);
	
	my $cronjobFileContent = $cronjobFile->get();
	unless (defined $cronjobFileContent) {
		error("Unable to read $cronjobFilePath");
		return 1;
	}
	
	require iMSCP::Templator;
	iMSCP::Templator->import();
	
	$cronjobFileContent = process(
		{ 'IMSCP_PERLLIB_PATH' => $main::imscpConfig{'ENGINE_ROOT_DIR'} . '/PerlLib' },
		$cronjobFileContent
	);
	
	my $rs = $cronjobFile->set($cronjobFileContent);
	return $rs if $rs;
	
	$rs = $cronjobFile->save();
	return $rs if $rs;
	
	Servers::cron->factory()->addTask(
		{
			'TASKID' => 'Plugin::RoundcubePlugins::pop3fetcher',
			'MINUTE' => $self->{'config'}->{'pop3fetcher_cronjob'}->{'minute'},
			'HOUR' => $self->{'config'}->{'pop3fetcher_cronjob'}->{'hour'},
			'DAY' => $self->{'config'}->{'pop3fetcher_cronjob'}->{'day'},
			'MONTH' => $self->{'config'}->{'pop3fetcher_cronjob'}->{'month'},
			'DWEEK' => $self->{'config'}->{'pop3fetcher_cronjob'}->{'dweek'},
			'COMMAND' => "$main::imscpConfig{'CMD_PERL'} $cronjobFilePath >/dev/null 2>&1"
		}
	);
	
	0;
}

=item _unregisterCronjobPop3fetcher()

 Unregister pop3fetcher cronjob.

 Return int 0 on success, other on failure

=cut

sub _unregisterCronjobPop3fetcher
{
	Servers::cron->factory()->deleteTask({ 'TASKID' => 'Plugin::RoundcubePlugins::pop3fetcher' });
}

=back

=head1 AUTHORS

 Rene Schuster <mail@reneschuster.de>
 Sascha Bay <info@space2place.de>

=cut

1;
