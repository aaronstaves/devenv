package DevEnv::Exceptions;

use Exception::Class (
	DevEnv::Exception => { 
		description => 'General Exception',
	},
	DevEnv::Exception::Config => { 
		description => 'Config Exception',
	},
	DevEnv::Exception::Docker => { 
		description => 'Docker Exception',
	},
	DevEnv::Exception::VM => { 
		description => 'VM Exception',
	}
);

1;
