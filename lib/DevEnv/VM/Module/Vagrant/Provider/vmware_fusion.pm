package DevEnv::VM::Module::Vagrant::Provider::vmware_fusion;
use Moose;
no warnings qw/once/;

extends 'DevEnv::VM::Module::Vagrant::Provider';

use IPC::Run;
use Path::Class;
use File::Find;

use Data::Dumper;

has 'vmware_dir' => (
    is      => 'ro',
    isa     => 'Path::Class::Dir',
	lazy    => 1,
    default => sub {
		return dir( "/Applications/VMware Fusion.app/Contents/Library/" );
    }
);

has 'vmware_disk_manager' => (
	is      => 'ro',
	isa     => 'Path::Class::File',
	lazy    => 1,
	default => sub {

		my $self = shift; return $self->vmware_dir->file( "vmware-vdiskmanager" );
	}
);

has 'vmware_run' => (
	is      => 'ro',
	isa     => 'Path::Class::File',
	lazy    => 1,
	default => sub {

		my $self = shift; return $self->vmware_dir->file( "vmrun" );
	}
);

has 'version' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	default => sub {
		my $self = shift;

		my ( $stdout, $stderr );
		IPC::Run::run
			[ $self->vmware_fusion ],
			'>',  \$stdout,
			'2>', \$stderr;

		my ( $line ) = split /\n/, $stdout;

		my ( $version_str ) =~ m/build (\d+).$/;

		return $version_str;
	}
);
sub _build_version {

}

override 'stop' => sub {

    my $self = shift;
	my %args = @_;

	my $instance_dir = $args{instance_dir}->subdir( ".vagrant/machines/default/vmware_fusion" );


#	/Volumes/SL/devenv/utils/.vagrant/machines/default/vmware_fusion

	my $vmx_file = undef;

	find(
		{
			wanted => sub {
				if ( $_ =~ m/vmx$/i ) {
					$vmx_file = $File::Find::name;
				}
			}
		},
		$instance_dir->stringify
	);

	if ( defined $vmx_file ) {

		system sprintf( '"%s" stop "%s"',
			$self->vmware_run,
			$vmx_file
		);
	}

    return 1;
};


override 'adjust_config' => sub {

	my $self   = shift;
	my $config = shift;

	my $memory = DevEnv::Tools::Convert->convert_value_to_M(
		DevEnv::Tools::Convert->convert_to_full_number( $config->{vm}{module}{Vagrant}{system}{memory} )
	);
	my $extend_drive = DevEnv::Tools::Convert->convert_value_to_G(
		DevEnv::Tools::Convert->convert_to_full_number( $config->{vm}{module}{Vagrant}{system}{extend_drive} )
	);
	my $swap = DevEnv::Tools::Convert->convert_value_to_G(
		DevEnv::Tools::Convert->convert_to_full_number( $config->{vm}{module}{Vagrant}{system}{swap} )
	);

	if ( defined $memory ) {
		$config->{vm}{module}{Vagrant}{system}{memory} = $memory;
	}
	if ( defined $extend_drive ) {
		$config->{vm}{module}{Vagrant}{system}{extend_drive} = $extend_drive . "G";
	}
	if ( defined $swap ) {
		$config->{vm}{module}{Vagrant}{system}{swap} = $swap . "G";
	}

	return $config;
};

override 'template_vars' => sub {

	my $self = shift;
	my $vars = shift;

	my $disk_manager = $self->vmware_disk_manager->stringify;
	$disk_manager =~ s#\s#\\ #g;

	$vars->{provider} = 'vmware_fusion';
	$vars->{disk_manager} = $disk_manager;

	return $vars;
};



__PACKAGE__->meta->make_immutable;

1;

