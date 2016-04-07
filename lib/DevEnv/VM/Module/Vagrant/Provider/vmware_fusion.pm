package DevEnv::VM::Module::Vagrant::Provider::virtualbox;
use Moose;

extends 'DevEnv::VM::Module::Vagrant::Provider';

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

    my $self = shift;
	my %args = @_;

}

override 'template_vars' => sub {

	my $self = shift;

	return {

		provider => 'vmware_fusion'

	};
};

__PACKAGE__->meta->make_immutable;

1;

