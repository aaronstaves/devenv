package DevEnv::Docker;
use Moose;

has 'config' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'config_dir' => (
	is       => 'ro',
	isa      => 'Str',
	required => 1,
);

has 'instance' => (
	is       => 'ro',
	isa      => 'Str|Undef',
);



sub start {




}

__PACKAGE__->meta->make_immutable;

1;
