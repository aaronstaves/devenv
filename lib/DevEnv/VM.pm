package DevEnv::VM;
use Moose;

use Module::Loaded;

has '_vm' => (
	is  => 'ro',
	isa => 'DevEnv::VM::Module',
	handles => [
		qw/
			start
			stop
			remove
			build
		/
	]
);

sub BUILD {

	my $self = shift;
	my $args = shift;

	if ( not defined $args->{type} ) {
		die "VM type was not defined";
	}

	my $class = __PACKAGE__ . "::Module::" . $args->{type};

	if ( $args->{verbose} ) {
		print STDERR "Using class $class for VM\n";
	}

	if ( not is_loaded $class  ) {

		unless ( eval "require $class" ) {
			die "Could not load $class: $@";
		}

		$class->import();
	}

	$self->{_vm} = $class->new( %{$args} );

	return undef;
}

__PACKAGE__->meta->make_immutable;

1;
