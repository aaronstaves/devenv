package DevEnv::VM::Module::Vagrant::Provider::vmware_fusion;
use Moose;

extends 'DevEnv::VM::Module::Vagrant::Provider';

use IPC::Run;

use Data::Dumper;

has 'vmware_fusion_file_name' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        return "vmware-vdiskmanager";
    }
);

has 'vmware_fusion' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_build_vmware_fusion'
);
sub _build_vmware_fusion {
	my $self = shift;

	return '/Applications/VMware Fusion.app/Contents/Library/' . $self->vmware_fusion_file_name;
}

has 'version' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_build_version'
);
sub _build_version {

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

	$vars->{provider} = 'vmware_fusion';

	return $vars;
};



__PACKAGE__->meta->make_immutable;

1;

