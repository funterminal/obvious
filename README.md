# obvious - command control and security tool

## overview

obvious is a command-line tool designed to provide granular control over command execution on Unix-like systems. It offers multiple mechanisms to manage command execution including confirmation prompts, password protection, command blocking, role-based access control, time-based restrictions, and temporary access grants.

## key features

- **command confirmation**: require explicit user confirmation before executing sensitive commands
- **password protection**: enforce password authentication for critical commands
- **command blocking**: permanently disable execution of specific commands
- **role-based access control**: restrict commands based on user roles
- **time-based restrictions**: limit command execution to specific time windows
- **temporary access**: grant time-limited access to blocked commands
- **shell integration**: works with bash, zsh, and fish shells
- **secure storage**: uses SHA-256 hashing for password protection
- **logging**: maintains an execution log for auditing purposes
- **backup system**: automatically backs up configuration files

## installation

```bash
curl -sSL https://raw.githubusercontent.com/funterminal/obvious/refs/heads/main/obvious.sh | sh
```

## configuration files

obvious uses several configuration files to manage command execution:

1. **obvious.txt**: contains commands that require confirmation before execution
2. **obvious-password.txt**: stores password-protected commands and their SHA-256 hashes
3. **obvious-notexecute.txt**: lists commands that should be completely blocked
4. **roles.txt**: defines role-based command permissions
5. **obvious-timeblock.txt**: specifies time restrictions for commands
6. **obvious-temp-access.txt**: tracks temporary access grants
7. **obvious.log**: records command executions with timestamps

### initial setup

Initialize configuration files by running:
```bash
obvious setup obvious.txt
obvious setup obvious-password.txt
obvious setup obvious-notexecute.txt
obvious setup roles.txt
obvious setup obvious-timeblock.txt
obvious setup obvious-temp-access.txt
```

## usage examples

### basic command execution
```bash
obvious "your-command"
```

### adding a command requiring confirmation
```bash
echo "rm -rf /" >> obvious.txt
```

When executed:
```bash
obvious "rm -rf /"
```
The tool will prompt for confirmation before proceeding.

### adding a password-protected command
```bash
echo "shutdown -h now:$(echo -n 'yourpassword' | sha256sum | awk '{print $1}')" >> obvious-password.txt
```

When executed:
```bash
obvious "shutdown -h now"
```
The tool will prompt for the correct password before executing.

### blocking a command
```bash
echo "reboot:" >> obvious-notexecute.txt
```

When executed:
```bash
obvious "reboot"
```
The tool will block execution and display a message.

### role-based access control
```bash
obvious assign-role admin "reboot,shutdown,rm -rf"
obvious assign-role user "ls,cat"
```

### time-based restrictions
```bash
echo "reboot:09:00-17:00" >> obvious-timeblock.txt
```

### temporary access
```bash
obvious enable-temp-access "reboot" "1 hour"
```

## file format examples

### obvious.txt example
```
rm -rf /
dd if=/dev/random of=/dev/sda
chmod -R 777 /
```

### obvious-password.txt example
```
shutdown -h now:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8
init 0:6cf615d5bcaac778352a8f1f3360d23f02f34ec182e259897fd6ce485d7870d4
```

### obvious-notexecute.txt example
```
reboot:
halt:
poweroff:
```

### roles.txt example
```
admin:ALL
user:ls,cat
developer:git,npm,make
```

### obvious-timeblock.txt example
```
reboot:09:00-17:00
shutdown:08:00-18:00
```

## implementation details

obvious works by intercepting commands and checking them against multiple control mechanisms:

1. For commands in `obvious.txt`, it prompts for user confirmation
2. For commands in `obvious-password.txt`, it verifies the password hash before execution
3. For commands in `obvious-notexecute.txt`, it blocks execution and creates shell aliases to prevent direct execution
4. For role-based commands, it verifies the user's role has permission
5. For time-restricted commands, it checks if execution is allowed at the current time
6. For temporary access, it verifies the access window is still valid

The password verification uses SHA-256 hashing to securely store credentials. When a password is entered, it is hashed and compared against the stored hash value.

## security considerations

- Password hashes are stored using SHA-256
- Configuration files should have appropriate permissions (600 recommended)
- The tool requires write access to your shell configuration file for full functionality
- Commands are executed with the same privileges as the user running obvious
- Log files contain sensitive information and should be protected

## license

obvious is released under the MIT License. See the `LICENSE` file for full details.

## support

For issues or feature requests, please open an issue on the project's GitHub repository.
