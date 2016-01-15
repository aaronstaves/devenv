package DevEnv::VM::Module::Vagrant::Provider::virtualbox;
use Moose;

extends 'DevEnv::VM::Module::Vagrant::Provider';

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

override 'template_vars' => sub {

	my $self = shift;

	return {

		provider => 'virtualbox'

	};
};

__PACKAGE__->meta->make_immutable;

1;

