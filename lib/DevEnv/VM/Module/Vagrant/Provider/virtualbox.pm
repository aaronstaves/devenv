package DevEnv::VM::Module::Vagrant::Provider::virtualbox;
use Moose;

extends 'DevEnv::VM::Module::Vagrant::Provider';

use DevEnv::Tools::Convert;

use IPC::Run;

has 'virtualbox_file_name' => (
    is      => 'ro',
    isa     => 'Str',
    default => sub {
        return "virtualbox"
    }
);

has 'virtualbox' => (
	is      => 'ro',
	isa     => 'Str',
	lazy    => 1,
	builder => '_build_virtualbox'
);
sub _build_virtualbox {
	my $self = shift;
	return which( $self->virtualbox_file_name );
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
        [ $self->virtualbox, '--help' ],
        '>',  \$stdout,
        '2>', \$stderr;

	my ( $line ) = split /\n/, $stdout;

	my ( $version_str ) =~ m/([\d\.]+)$/;

	return $version_str;
}

override 'adjust_config' => sub {

	my $self   = shift;
	my $config = shift;

	my $memory = DevEnv::Tools::Convert->convert_value_to_M(
		DevEnv::Tools::Convert->convert_to_full_number( $config->{vm}{Vagrant}{system}{memory} )
	);
	my $extend_drive = DevEnv::Tools::Convert->convert_value_to_M(
		DevEnv::Tools::Convert->convert_to_full_number( $config->{vm}{Vagrant}{system}{extend_drive} )
	);
	my $swap = DevEnv::Tools::Convert->convert_value_to_G(
		DevEnv::Tools::Convert->convert_to_full_number( $config->{vm}{Vagrant}{system}{swap} )
	);

	if ( defined $memory ) {
		$config->{vm}{Vagrant}{system}{memory} = $memory;
	}
	if ( defined $extend_drive ) {
		$config->{vm}{Vagrant}{system}{extend_drive} = $extend_drive;
	}
	if ( defined $swap ) {
		$config->{vm}{Vagrant}{system}{swap} = $swap . "G";
	}

	return $config;
};

override 'template_vars' => sub {

	my $self = shift;
	my $vars = shift;

	$vars->{provider} = 'virtualbox';

	return $vars;
};

__PACKAGE__->meta->make_immutable;

1;

