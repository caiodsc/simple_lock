
# SimpleLock

**SimpleLock** is a simple implementation of distributed locking using Ruby and Redis, designed to prevent deadlocks and ensure that concurrent processes can be managed efficiently.

## Installation

Add the gem to your `Gemfile`:

```ruby
gem "simple_lock"
```

Then run the following command:

```bash
bundle install
```

Or, if you prefer installing it directly via terminal:

```bash
gem install simple_lock
```

## Usage

### Simple Locking

The main goal of **SimpleLock** is to provide a distributed locking mechanism. You can use the gem to ensure that only one process or thread can access a critical resource or operation at a time.

### Basic Example

```ruby
# Using the simple lock with a key and expiration time (TTL)
locked = SimpleLock.lock("my_unique_lock_key", 30)

if locked
  # Execute the critical operation
  puts "Lock acquired! Executing critical operation."
else
  # Lock couldn't be acquired, another process already has it
  puts "Failed to acquire lock, try again later."
end
```

### Using with Block

You can also use **SimpleLock** with a block, ensuring the lock will be automatically released when the block finishes, even if an exception occurs:

```ruby
SimpleLock.lock("my_unique_lock_key", 30) do |locked|
  if locked
    # Critical operation
    puts "Safe operation is running."
  else
    # Couldn't acquire the lock
    puts "Failed to acquire lock."
  end
end
```

### Unlocking

You can manually release the lock using the `unlock` method:

```ruby
SimpleLock.unlock("my_unique_lock_key")
```

## Configuration

You can configure various behaviors of the gem, such as the key prefix, retry count, retry delay, and more.

### Example Configuration:

```ruby
SimpleLock.config.key_prefix = "simple_lock:"
SimpleLock.config.retry_count = 3
SimpleLock.config.retry_delay = 200 # in milliseconds
SimpleLock.config.retry_jitter = 50 # in milliseconds
SimpleLock.config.retry_proc = Proc.new { |attempt| attempt * 100 }
```

## Features

- **Distributed locking and unlocking** with Redis.
- **Automatic retry** with increasing delay and jitter, useful for high-concurrency systems.
- **Safe unlocking** even in case of failure.
- **Low latency** and easy integration.

## Development

After cloning the repository, install dependencies:

```bash
bin/setup
```

Run tests:

```bash
rake spec
```

To interact with the code in the console:

```bash
bin/console
```

To install the gem locally:

```bash
bundle exec rake install
```

### Releasing a New Version

1. Update the version number in `lib/simple_lock/version.rb`.
2. Run the command to release the version:

```bash
bundle exec rake release
```

This will create a Git tag, push the code, and upload the `.gem` file to RubyGems.

## Contributing

Contributions are welcome! Open an issue or submit a pull request on the [GitHub repository](https://github.com/caiodsc/simple_lock).

1. Fork the project.
2. Create a new branch (`git checkout -b feature-branch`).
3. Commit your changes (`git commit -am 'Add new feature'`).
4. Push to the branch (`git push origin feature-branch`).
5. Create a new Pull Request.

## License

The gem is available as open source under the terms of the MIT License.
