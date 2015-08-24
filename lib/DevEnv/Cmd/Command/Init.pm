package DevEnv::Cmd::Command::Init;
use Moose;

# ABSTRACT: Init the environment

extends 'DevEnv::Cmd::Command';

use FindBin;
use Path::Class;

use Data::Dumper;


sub _bash {

	my %args = @_;

	my $base_path = $args{base_path};

	print qq{export DEVENV_BASE=$base_path\n};

	my $path = $ENV{PATH};
	if ( $path !~ m/\Q$base_path\E/ ) {
		$path = "$base_path/bin:$base_path/local/bin:$path";
	}
	print qq{export PATH=$path\n};

	my $perl5lib = $ENV{PERL5LIB} // "";
	if ( $perl5lib !~ m/\Q$base_path\E/ ) {
		$perl5lib = "$base_path/lib:$base_path/local/lib/perl5:$perl5lib";
		$perl5lib =~ s/:$//;
	}
		
	print qq{export PERL5LIB=$perl5lib\n};
}

after 'execute' => sub {

	my $self = shift;

	my $base_path = Path::Class::Dir->new( $FindBin::Bin );
	$base_path = $base_path->parent;

	# TODO: Set up the correct shell

	_bash(
		base_path => $base_path
	);
};

__PACKAGE__->meta->make_immutable;

1;
