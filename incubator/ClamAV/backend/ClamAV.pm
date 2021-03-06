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
# @category    iMSCP
# @package     iMSCP_Plugin
# @subpackage  ClamAV
# @copyright   Sascha Bay <info@space2place.de>
# @copyright   Rene Schuster <mail@reneschuster.de>
# @author      Sascha Bay <info@space2place.de>
# @author      Rene Schuster <mail@reneschuster.de>
# @link        http://i-mscp.net i-MSCP Home Site
# @license     http://www.gnu.org/licenses/gpl-2.0.html GPL v2

package Plugin::ClamAV;

use strict;
use warnings;

use iMSCP::Database;
use iMSCP::Debug;
use iMSCP::Dir;
use iMSCP::Execute;
use iMSCP::File;
use JSON;

use parent 'Common::SingletonClass';

=head1 DESCRIPTION

 This package provides the backend part for the i-MSCP ClamAV plugin.

=head1 PUBLIC METHODS

=over 4

=item install()

 Perform install tasks

 Return int 0 on success, other on failure

=cut

sub install
{
	my $self = shift;

	if(! -x '/usr/sbin/clamd') {
		error('Unable to find clamav daemon. Please, install the clamav and clamav-daemon packages first.');
		return 1;
	}

	if(! -x '/usr/bin/freshclam') {
		error('Unable to find freshclam daemon. Please, install the clamav-freshclam package first.');
		return 1;
	}

	if(! -x '/usr/sbin/clamav-milter') {
		error('Unable to find clamav-milter daemon. Please, install the clamav-milter package first.');
		return 1;
	}

	my $rs = $self->change();
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

	my $rs = $self->_modifyClamavMilterDefaultConfig('add');
	return $rs if $rs;

	$rs = $self->_modifyClamavMilterSystemConfig('add');
	return $rs if $rs;

	$rs = $self->_restartDaemon('clamav-milter', 'restart');
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

	my $rs = $self->change();
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
	
	my $rs = $self->_modifyPostfixMainConfig('add');
	return $rs if $rs;
	
	$rs = $self->_restartDaemonPostfix();
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
	
	my $rs = $self->_modifyPostfixMainConfig('remove');
	return $rs if $rs;
	
	$rs = $self->_restartDaemonPostfix();
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
		
	my $rs = $self->_modifyClamavMilterDefaultConfig('remove');
	return $rs if $rs;
	
	$rs = $self->_modifyClamavMilterSystemConfig('remove');
	return $rs if $rs;
	
	$rs = $self->_restartDaemon('clamav-milter', 'restart');
	return $rs if $rs;
	
	0;
}

=back

=head1 PRIVATE METHODS

=over 4

=item _init()

 Initialize plugin

 Return Plugin::ClamAV

=cut

sub _init
{
	my $self = shift;

	# Force return value from plugin module
	$self->{'FORCE_RETVAL'} = 'yes';

	if($self->{'action'} ~~ ['install', 'change', 'update', 'enable']) {
		# Loading plugin configuration
		my $rdata = iMSCP::Database->factory()->doQuery(
			'plugin_name', 'SELECT plugin_name, plugin_config FROM plugin WHERE plugin_name = ?', 'ClamAV'
		);
		unless(ref $rdata eq 'HASH') {
			error($rdata);
			return 1;
		}
		
		$self->{'config'} = decode_json($rdata->{'ClamAV'}->{'plugin_config'});
	}

	$self;
}

=item _modifyClamavMilterDefaultConfig($action)

 Modify clamav-milter default config file

 Return int 0 on success, other on failure

=cut

sub _modifyClamavMilterDefaultConfig($$)
{
	my ($self, $action) = @_;
	
	my $file = iMSCP::File->new('filename' => '/etc/default/clamav-milter');
	
	my $fileContent = $file->get();
	unless (defined $fileContent) {
		error("Unable to read /etc/default/clamav-milter");
		return 1;
	}
	
	my $clamavMilterSocketConfig = "\n# Begin Plugin::ClamAV\n";
	$clamavMilterSocketConfig .= "SOCKET_RWGROUP=postfix\n";
	$clamavMilterSocketConfig .= "# Ending Plugin::ClamAV\n";
	
	if($action eq 'add') {
		if ($fileContent =~ /^# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n/sgm) {
			$fileContent =~ s/^\n# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n/$clamavMilterSocketConfig/sgm;
		} else {
			$fileContent .= "$clamavMilterSocketConfig";
		}
	} elsif($action eq 'remove') {
		$fileContent =~ s/^\n# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n//sgm;
	}
	
	my $rs = $file->set($fileContent);
	return $rs if $rs;
	
	$rs = $file->save();
	return $rs if $rs;
	
	0;
}

=item _modifyClamavMilterSystemConfig($action)

 Modify clamav-milter system config file

 Return int 0 on success, other on failure

=cut

sub _modifyClamavMilterSystemConfig($$)
{
	my ($self, $action) = @_;
	
	my $file = iMSCP::File->new('filename' => '/etc/clamav/clamav-milter.conf');
	
	my $fileContent = $file->get();
	unless (defined $fileContent) {
		error("Unable to read /etc/clamav/clamav-milter.conf");
		return 1;
	}
	
	if($action eq 'add') {
		$fileContent =~ s/^(MilterSocket.*)/#$1/gm;
		$fileContent =~ s/^(FixStaleSocket.*)/#$1/gm;
		$fileContent =~ s/^(User.*)/#$1/gm;
		$fileContent =~ s/^(AllowSupplementaryGroups.*)/#$1/gm;
		$fileContent =~ s/^(ReadTimeout.*)/#$1/gm;
		$fileContent =~ s/^(Foreground.*)/#$1/gm;
		$fileContent =~ s/^(PidFile.*)/#$1/gm;
		$fileContent =~ s/^(ClamdSocket.*)/#$1/gm;
		$fileContent =~ s/^(OnClean.*)/#$1/gm;
		$fileContent =~ s/^(OnInfected.*)/#$1/gm;
		$fileContent =~ s/^(OnFail.*)/#$1/gm;
		$fileContent =~ s/^(AddHeader.*)/#$1/gm;
		$fileContent =~ s/^(LogSyslog.*)/#$1/gm;
		$fileContent =~ s/^(LogFacility.*)/#$1/gm;
		$fileContent =~ s/^(LogVerbose.*)/#$1/gm;
		$fileContent =~ s/^(LogInfected.*)/#$1/gm;
		$fileContent =~ s/^(LogClean.*)/#$1/gm;
		$fileContent =~ s/^(MaxFileSize.*)/#$1/gm;
		$fileContent =~ s/^(TemporaryDirectory.*)/#$1/gm;
		$fileContent =~ s/^(LogFile.*)/#$1/gm;
		$fileContent =~ s/^(LogTime.*)/#$1/gm;
		$fileContent =~ s/^(LogFileUnlock.*)/#$1/gm;
		$fileContent =~ s/^(LogFileMaxSize.*)/#$1/gm;
		$fileContent =~ s/^(MilterSocketGroup.*)/#$1/gm;
		$fileContent =~ s/^(MilterSocketMode.*)/#$1/gm;
		
		my $clamavMilterSystemConfig = "\n# Begin Plugin::ClamAV\n";
		$clamavMilterSystemConfig .= "MilterSocket " . $self->{'config'}->{'MilterSocket'} ."\n";
		$clamavMilterSystemConfig .= "FixStaleSocket " . $self->{'config'}->{'FixStaleSocket'} ."\n";
		$clamavMilterSystemConfig .= "User " . $self->{'config'}->{'User'} ."\n";
		$clamavMilterSystemConfig .= "AllowSupplementaryGroups " . $self->{'config'}->{'AllowSupplementaryGroups'} ."\n";
		$clamavMilterSystemConfig .= "ReadTimeout " . $self->{'config'}->{'ReadTimeout'} ."\n";
		$clamavMilterSystemConfig .= "Foreground " . $self->{'config'}->{'Foreground'} ."\n";
		$clamavMilterSystemConfig .= "PidFile " . $self->{'config'}->{'PidFile'} ."\n";
		$clamavMilterSystemConfig .= "ClamdSocket " . $self->{'config'}->{'ClamdSocket'} ."\n";
		$clamavMilterSystemConfig .= "OnClean " . $self->{'config'}->{'OnClean'} ."\n";
		$clamavMilterSystemConfig .= "OnInfected " . $self->{'config'}->{'OnInfected'} ."\n";
		$clamavMilterSystemConfig .= "OnFail " . $self->{'config'}->{'OnFail'} ."\n";
		$clamavMilterSystemConfig .= "AddHeader " . $self->{'config'}->{'AddHeader'} ."\n";
		$clamavMilterSystemConfig .= "LogSyslog " . $self->{'config'}->{'LogSyslog'} ."\n";
		$clamavMilterSystemConfig .= "LogFacility " . $self->{'config'}->{'LogFacility'} ."\n";
		$clamavMilterSystemConfig .= "LogVerbose " . $self->{'config'}->{'LogVerbose'} ."\n";
		$clamavMilterSystemConfig .= "LogInfected " . $self->{'config'}->{'LogInfected'} ."\n";
		$clamavMilterSystemConfig .= "LogClean " . $self->{'config'}->{'LogClean'} ."\n";
		$clamavMilterSystemConfig .= "MaxFileSize " . $self->{'config'}->{'MaxFileSize'} ."\n";
		$clamavMilterSystemConfig .= "TemporaryDirectory " . $self->{'config'}->{'TemporaryDirectory'} ."\n";
		$clamavMilterSystemConfig .= "LogFile " . $self->{'config'}->{'LogFile'} ."\n";
		$clamavMilterSystemConfig .= "LogTime " . $self->{'config'}->{'LogTime'} ."\n";
		$clamavMilterSystemConfig .= "LogFileUnlock " . $self->{'config'}->{'LogFileUnlock'} ."\n";
		$clamavMilterSystemConfig .= "LogFileMaxSize " . $self->{'config'}->{'LogFileMaxSize'} ."\n";
		$clamavMilterSystemConfig .= "MilterSocketGroup " . $self->{'config'}->{'MilterSocketGroup'} ."\n";
		$clamavMilterSystemConfig .= "MilterSocketMode " . $self->{'config'}->{'MilterSocketMode'} ."\n";
		$clamavMilterSystemConfig .= "RejectMsg " . $self->{'config'}->{'RejectMsg'} ."\n";
		$clamavMilterSystemConfig .= "# Ending Plugin::ClamAV\n";
		
		if ($fileContent =~ /^# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n/sgm) {
			$fileContent =~ s/^\n# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n/$clamavMilterSystemConfig/sgm;
		} else {
			$fileContent .= "$clamavMilterSystemConfig";
		}
	}
	elsif($action eq 'remove') {
		$fileContent =~ s/^(#)(MilterSocket.*)/$2/gm;
		$fileContent =~ s/^(#)(FixStaleSocket.*)/$2/gm;
		$fileContent =~ s/^(#)(User.*)/$2/gm;
		$fileContent =~ s/^(#)(AllowSupplementaryGroups.*)/$2/gm;
		$fileContent =~ s/^(#)(ReadTimeout.*)/$2/gm;
		$fileContent =~ s/^(#)(Foreground.*)/$2/gm;
		$fileContent =~ s/^(#)(PidFile.*)/$2/gm;
		$fileContent =~ s/^(#)(ClamdSocket.*)/$2/gm;
		$fileContent =~ s/^(#)(OnClean.*)/$2/gm;
		$fileContent =~ s/^(#)(OnInfected.*)/$2/gm;
		$fileContent =~ s/^(#)(OnFail.*)/$2/gm;
		$fileContent =~ s/^(#)(AddHeader.*)/$2/gm;
		$fileContent =~ s/^(#)(LogSyslog.*)/$2/gm;
		$fileContent =~ s/^(#)(LogFacility.*)/$2/gm;
		$fileContent =~ s/^(#)(LogVerbose.*)/$2/gm;
		$fileContent =~ s/^(#)(LogInfected.*)/$2/gm;
		$fileContent =~ s/^(#)(LogClean.*)/$2/gm;
		$fileContent =~ s/^(#)(MaxFileSize.*)/$2/gm;
		$fileContent =~ s/^(#)(TemporaryDirectory.*)/$2/gm;
		$fileContent =~ s/^(#)(LogFile.*)/$2/gm;
		$fileContent =~ s/^(#)(LogTime.*)/$2/gm;
		$fileContent =~ s/^(#)(LogFileUnlock.*)/$2/gm;
		$fileContent =~ s/^(#)(LogFileMaxSize.*)/$2/gm;
		$fileContent =~ s/^(#)(MilterSocketGroup.*)/$2/gm;
		$fileContent =~ s/^(#)(MilterSocketMode.*)/$2/gm;
		
		$fileContent =~ s/^\n# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n//sgm;
	}
	
	my $rs = $file->set($fileContent);
	return $rs if $rs;
	
	$rs = $file->save();
	return $rs if $rs;
	
	0;
}

=item _modifyPostfixMainConfig($action)

 Modify postfix main.cf config file

 Return int 0 on success, other on failure

=cut

sub _modifyPostfixMainConfig($$)
{
	my ($self, $action) = @_;
	
	my $file = iMSCP::File->new('filename' => '/etc/postfix/main.cf');
	
	my $fileContent = $file->get();
	unless (defined $fileContent) {
		error("Unable to read /etc/postfix/main.cf");
		return 1;
	}
	
	my ($stdout, $stderr);
	my $rs = execute('postconf smtpd_milters', \$stdout, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	return $rs if $rs;
	
	if($action eq 'add') {
		$stdout =~ /^smtpd_milters\s?=\s?(.*)/gm;
		my @miltersValues = split(' ', $1);

		my $milterSocket = $self->{'config'}->{'MilterSocket'};
		$milterSocket =~ s%/var/spool/postfix(.*)%$1%sgm;

		if(scalar @miltersValues >= 1) {
			$fileContent =~ s/^\t# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n//sgm;
		
			my $postfixClamavConfig = "\n\t# Begin Plugin::ClamAV\n";
			$postfixClamavConfig .= "\tunix:" . $milterSocket . "\n";
			$postfixClamavConfig .= "\t# Ending Plugin::ClamAV";
			
			$fileContent =~ s/^(smtpd_milters.*)/$1$postfixClamavConfig/gm;
		} else {
			my $postfixClamavConfig = "\n# Begin Plugins::i-MSCP\n";
			$postfixClamavConfig .= "milter_default_action = accept\n";
			$postfixClamavConfig .= "smtpd_milters = \n";
			$postfixClamavConfig .= "\t# Begin Plugin::ClamAV\n";
			$postfixClamavConfig .= "\tunix:" . $milterSocket . "\n";
			$postfixClamavConfig .= "\t# Ending Plugin::ClamAV\n";
			$postfixClamavConfig .= "non_smtpd_milters = \$smtpd_milters\n";
			$postfixClamavConfig .= "# Ending Plugins::i-MSCP\n";
			
			$fileContent .= "$postfixClamavConfig";
		}
	} 
	elsif($action eq 'remove') {
		$stdout =~ /^smtpd_milters\s?=\s?(.*)/gm;
		my @miltersValues = split(/\s+/, $1);
		
		if(scalar @miltersValues > 1) {
			$fileContent =~ s/^\t# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n//sgm;
		} 
		elsif($fileContent =~ /^\t# Begin Plugin::ClamAV.*Ending Plugin::ClamAV\n/sgm) {
			$fileContent =~ s/^\n# Begin Plugins::i-MSCP.*Ending Plugins::i-MSCP\n//sgm;
		}
	}
	
	$rs = $file->set($fileContent);
	return $rs if $rs;
	
	$rs = $file->save();
	return $rs if $rs;
	
	0;
}

=item _restartDaemon($daemon, $action)

 Restart the daemon

 Return int 0 on success, other on failure

=cut

sub _restartDaemon($$$)
{
	my ($self, $daemon, $action) = @_;
	
	my ($stdout, $stderr);
	my $rs = execute("service $daemon $action", \$stdout, \$stderr);
	debug($stdout) if $stdout;
	error($stderr) if $stderr && $rs;
	return $rs if $rs;
	
	0;
}

=item _restartDaemonPostfix()

 Restart the postfix daemon

 Return int 0 on success, other on failure

=cut

sub _restartDaemonPostfix
{
	my $self = shift;
	
    require Servers::mta;
    Servers::mta->factory()->{'restart'} = 'yes';
	
	0;
}

=back

=head1 AUTHORS

 Sascha Bay <info@space2place.de>
 Rene Schuster <mail@reneschuster.de>

=cut

1;
