require 'pathname'
require 'uri'
require 'puppet/util'

Puppet::Type.newtype(:archive) do
  @doc = 'Manage archive file download, extraction, and cleanup.'

  ensurable do
    desc "whether archive file should be present/absent (default: present)"

    newvalue(:present) do
      provider.create
    end

    newvalue(:absent) do
      provider.destroy
    end

    defaultto(:present)

    # The following changes allows us to notify if the resource is being replaced
    def is_to_s(value)
      return "(#{resource[:checksum_type]})#{self.provider.archive_checksum}" if self.provider.archive_checksum
      super
    end

    def should_to_s(value)
      return "(#{resource[:checksum_type]})#{resource[:checksum]}" if self.provider.archive_checksum
      super
    end

    def change_to_s(currentvalue, newvalue)
      if currentvalue == :absent or currentvalue.nil?
        extract = resource[:extract] == :true ? "and extracted in #{resource[:extract_path]}" : ""
        cleanup = resource[:cleanup] == :true ? "with cleanup" : "without cleanup"

        if self.provider.archive_checksum
          "replace archive: #{self.provider.archive_filepath} from #{is_to_s(currentvalue)} to #{should_to_s(newvalue)}"
        else
          "download archive from #{resource[:source]} to #{self.provider.archive_filepath} #{extract} #{cleanup}"
        end
      elsif newvalue == :absent
        "remove archive: #{self.provider.archive_filepath} "
      else
        super
      end
    rescue Exception
      super
    end
  end

  newparam(:path, :namevar => true) do
    desc "archive file fully qualified file path."
    validate do |value|
      unless Puppet::Util.absolute_path? value
        raise ArgumentError, "archive path must be absolute: #{value}"
      end
    end
  end

  newparam(:filename) do
    desc "archive filename."
  end

  newparam(:extract) do
    desc "should archive be extracted after download (true|false)"
    newvalues(:true, :false)
    defaultto(:false)
  end

  newparam(:extract_path) do
    desc "target path to extract archive"
    validate do |value|
      unless Puppet::Util.absolute_path? value
        raise ArgumentError, "archive extract_path must be absolute: #{value}"
      end
    end
  end

  newparam(:extract_command) do
    desc "custom extraction command ('tar xvf example.tar.gz'), also support sprintf format ('tar xvf %s') which will be processed with the filename: sprintf('tar xvf %s', filename)"
  end

  newparam(:extract_flags) do
    desc "custom extract options, this replaces the default flags. A string such as 'xvf' for a tar file would replace the default xf flag. A hash is useful when custom flags are needed for different platforms. {'tar' => 'xzf', '7z' => 'x -aot'}."
    defaultto(:undef)
  end


  newproperty(:creates) do
    desc "if file/directory exists, will not download/extract archive"

    def should_to_s(value)
      "extracting in #{resource[:extract_path]} to create #{value}"
    end
  end

  newparam(:cleanup) do
    desc "should archive file be removed after extraction (true|false)"
    newvalues(:true, :false)
    defaultto(:true)
  end

  newparam(:source) do
    desc "archive file source, supports http|https|ftp|file uri."
    validate do |value|
      unless value =~ URI.regexp(['http', 'https', 'file', 'ftp'])
        raise ArgumentError, "invalid source url: #{value}"
      end
    end
  end

  newparam(:cookie) do
    desc "archive file download cookie."
  end

  newparam(:checksum) do
    desc "archive file checksum (match checksum_type)"
    newvalues(/\b[0-9a-f]{5,64}\b/)
  end

  newparam(:checksum_source) do
    desc "archive file checksum source (instead of specify checksum)"
  end

  newparam(:checksum_type) do
    desc "archive file checksum type (none|md5|sha1|sha2|sh256|sha384|sha512)"
    newvalues(:none, :md5, :sha1, :sha2, :sha256, :sha384, :sha512)
    defaultto(:none)
  end

  newparam(:checksum_verify) do
    desc "whether checksum be verified (true|false)"
    newvalues(:true, :false)
    defaultto(:true)
  end

  newparam(:username) do
    desc "username to download source file"
  end

  newparam(:password) do
    desc "password to download source file"
  end

  newparam(:user) do
    desc "extract command user (using this option will configure the archive file permission to 0644 so the user can read the file)."
  end

  newparam(:group) do
    desc "extract command group (using this option will configure the archive file permisison to 0644 so the user can read the file)."
  end

  autorequire(:package) do
    'faraday_middleware'
  end

  autorequire(:file) do
    Pathname.new(self[:path]).parent.to_s
  end

  autorequire(:file) do
    self[:extract_path]
  end

  validate do
    filepath = Pathname.new(self[:path])
    self[:filename] = filepath.basename.to_s
  end
end
