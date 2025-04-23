# obvious - command control and security tool

## overview

obvious is a command-line tool designed to provide granular control over command execution on Unix-like systems. It offers three distinct mechanisms to manage command execution: confirmation prompts, password protection, and command blocking. The tool integrates with your shell environment to enforce these controls.

## key features

- **command confirmation**: require explicit user confirmation before executing sensitive commands
- **password protection**: enforce password authentication for critical commands
- **command blocking**: permanently disable execution of specific commands
- **shell integration**: works with bash, zsh, and fish shells
- **hash protection**: stores password hashes instead of plaintext credentials

## installation

### termux
```bash
curl -L -o obvious.deb https://github.com/funterminal/obvious/raw/043c40f5983cf359986d35d54393dc2f06a5ce90/installs/obvious.deb && apt install ./obvious.deb
```

### debian-based systems
```bash
curl -L -o obvious.deb https://github.com/funterminal/obvious/raw/043c40f5983cf359986d35d54393dc2f06a5ce90/installs/obvious.deb && sudo dpkg -i obvious.deb
```

### other unix-like systems
```bash
sudo curl -o /usr/local/bin/obvious https://raw.githubusercontent.com/funterminal/obvious/refs/heads/main/obvious.sh && sudo chmod +x /usr/local/bin/obvious
```

## configuration files

obvious uses three configuration files to manage command execution:

1. **obvious.txt**: contains commands that require confirmation before execution
2. **obvious-password.txt**: stores password-protected commands and their SHA-256 hashes
3. **obvious-notexecute.txt**: lists commands that should be completely blocked

### initial setup

initialize the configuration files by running:
```bash
obvious setup obvious.txt
obvious setup obvious-password.txt
obvious setup obvious-notexecute.txt
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

when executed:
```bash
obvious "rm -rf /"
```
the tool will prompt for confirmation before proceeding.

### adding a password-protected command
```bash
echo "shutdown -h now:$(echo -n 'yourpassword' | sha256sum | awk '{print $1}')" >> obvious-password.txt
```

when executed:
```bash
obvious "shutdown -h now"
```
the tool will prompt for the correct password before executing.

### blocking a command
```bash
echo "reboot:" >> obvious-notexecute.txt
```

when executed:
```bash
obvious "reboot"
```
the tool will block execution and display a message.

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

## implementation details

obvious works by intercepting commands and checking them against the three control files:

1. for commands in `obvious.txt`, it prompts for user confirmation
2. for commands in `obvious-password.txt`, it verifies the password hash before execution
3. for commands in `obvious-notexecute.txt`, it blocks execution and creates shell aliases to prevent direct execution

the password verification uses SHA-256 hashing to securely store credentials. when a password is entered, it is hashed and compared against the stored hash value.

## shell integration

obvious automatically integrates with your shell by modifying the appropriate configuration file:

- bash: `~/.bashrc`
- zsh: `~/.zshrc`
- fish: `~/.config/fish/config.fish`

for blocked commands, it creates aliases that display a warning message instead of executing the command. after modifying these files, you need to restart your shell for changes to take effect.

## security considerations

- password hashes are stored using SHA-256, which provides basic protection
- configuration files should have appropriate permissions (600 recommended)
- the tool requires write access to your shell configuration file for full functionality
- commands are executed with the same privileges as the user running obvious

## license

obvious is released under the MIT License. See the `LICENSE` file for full details.

## support

for issues or feature requests, please open an issue on the project's GitHub repository.
